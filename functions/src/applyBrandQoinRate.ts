/**
 * applyBrandQoinRate — callable (admin 전용). 브랜드 적립률(숫자)을 설정하고 산하 매장의 개별 적립률을 처리한다.
 *
 * 요청: { brandId, rate? (0.001~0.2) | clear? (true), mode: 'preserve'|'overwrite', reason?, resumeHistoryId? }
 * 응답: { changed, historyId, status, affectedCount, clearedCount, preservedCount, processedCount, totalCount,
 *         clearedValueCount, clearedInvalidCount, disabledUntouchedCount, brandDisabled }
 *
 * **이 함수는 적립 스위치(`qoinAccrualEnabled`)를 쓰지 않는다** (Q1). 쓰는 매장 필드는 `qoinAccrualRate` 삭제 1개뿐이고,
 * 스위치는 숫자와 다른 필드라 덮어쓰기가 스키마 차원에서 불가능하다. 스위치를 읽는 곳은 집계 2곳뿐이다 —
 * 산하 매장의 `disabledUntouchedCount`(보고만, 어떤 분기도 바꾸지 않는다), 브랜드 자신의 `brandDisabled`(보고만).
 * "0 이면 건너뛴다" 같은 정책 분기가 없다.
 *
 * 순서가 중요하다 (spec §4-④):
 *   1. 이력 선기록 + 브랜드 값 1 write + 브랜드 잠금 포인터 — **한 트랜잭션**. 이 1 write 로 "개별 설정이 없는 매장 전체" 의
 *      유효 적립률이 원자적으로 바뀐다. 어떤 매장도 의도 밖의 값(옛 브랜드 값 / 전역 값)을 거치지 않는다.
 *   2. (overwrite 만) 산하 매장의 개별 적립률을 ≤225건 청크로 `FieldValue.delete()` — 매장별 이력 1건과 함께 (write 2/매장).
 *      일부만 지워져도 나머지 매장은 지우기 전의 자기 값을 유지하므로 중간 상태가 없다.
 *      이미 지운 필드는 대상이 아니므로 재개(resumeHistoryId)가 멱등하다. 매장 이력 ID 가 결정적이라 중복도 없다.
 *   3. 이력 마감: completed + 실제 처리 수 (클라이언트 숫자를 믿지 않는다) + 포인터 `completed` 전이. 실패 시 partial.
 * preserve 는 1 단계 트랜잭션에서 `completed` 까지 한 번에 쓴다 (원자성 문제 자체가 없다).
 *
 * **포인터는 지우지 않는 상태 기계다** (spec §21.2): in_progress / partial / completed / superseded.
 *   - 새 적용(preserve·overwrite)이 `partial` 포인터를 발견하면 옛 이력을 `superseded` 로 마감한다 (같은 트랜잭션).
 *   - same-value + 지울 개별 설정 0 + `partial` 이면 새 이력 없이 옛 이력을 `completed(nothing_left)` 로 닫고
 *     `{ changed:false, closed:true }` 를 돌려준다 — "지울 방법이 없는 상태" 가 존재하지 않는다.
 *   - S3 가드: same-value + 포인터가 종결 상태 + `qoinBulkAt` 이 내 스캔 시작보다 뒤 → `{ changed:false, staleScan:true }`.
 *     (`partial` 은 가드에 넣지 않는다 — 실제로 남은 일이 있다.)
 * 역순(개별 설정 삭제 → 브랜드 값)이면 삭제된 매장이 잠깐 옛 값으로 떨어진다 — 금지.
 *
 * F5: 동시 실행 방지는 **브랜드 문서의 포인터**(`qoinBulkHistoryId/Status/At`)를 트랜잭션 안에서 검사해 직렬화한다
 *     (이미 읽는 문서라 read 증가 0). 재개는 포인터와 브랜드 현재 값이 이력과 일치하는지 재검증한다.
 * TRANSITIONAL(spec §20.4.5): 산하 매장·브랜드에 레거시 `qoinAccrualRate: 0` 이 있으면 정책 판단을 하지 않고
 *     `failed-precondition` 으로 멈춘다 (마이그레이션 선행).
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { BULK_STALE_MS, classifyRate, isValidCallableRate } from "./qoinRate";
import {
  BULK_IN_PROGRESS_MESSAGE,
  BULK_STATUS,
  completePartialHistoryNothingLeft,
  describeRaw,
  historyCollection,
  isBulkInProgress,
  isBulkUnfinished,
  isBulkTerminal,
  LEGACY_MESSAGE_PREFIX,
  parseReason,
  rateBeforeInfo,
  readPartialHistory,
  REGION,
  requireAdmin,
  supersedePartialHistory,
} from "./qoinAdmin";

const LOG = "[applyBrandQoinRate]";
// 매장 1건당 update 1 + 이력 create 1 = write 2. batch 500 한도 아래 (450 → 225).
const CHUNK = 225;
const PAGE = 450;
const LEGACY_IDS_MAX = 50;

// 산하 매장 조회는 `where brandId ==` 단독 + 기본(문서 ID) 정렬 + startAfter 페이징이다.
// 명시적 orderBy(documentId) 를 두지 않는다 — 에뮬레이터는 인덱스를 강제하지 않아, 복합 인덱스가 필요한 쿼리를
// 만들어도 테스트가 통과한다. 동등 필터 단독 쿼리는 자동 단일 필드 인덱스로 충분하다.

interface Request {
  brandId?: unknown;
  rate?: unknown;
  clear?: unknown;
  mode?: unknown;
  reason?: unknown;
  resumeHistoryId?: unknown;
}

interface Scan {
  total: number; // 산하 매장 수 (N)
  withOverride: number; // 개별 적립률(qoinAccrualRate 필드 존재)이 있는 매장 수 (M)
  disabledUntouched: number; // 스위치가 꺼진 매장 수 — 일괄 적용 후에도 적립되지 않는다 (보고만)
  legacyZeroIds: string[]; // TRANSITIONAL(spec §20.4.5)
  legacyZeroCount: number;
}

async function scanStores(db: admin.firestore.Firestore, brandId: string): Promise<Scan> {
  const scan: Scan = { total: 0, withOverride: 0, disabledUntouched: 0, legacyZeroIds: [], legacyZeroCount: 0 };
  let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
  for (;;) {
    let q = db
      .collection("stores")
      .where("brandId", "==", brandId)
      .select("qoinAccrualRate", "qoinAccrualEnabled")
      .limit(PAGE);
    if (cursor) q = q.startAfter(cursor);
    const page = await q.get();
    if (page.empty) break;
    for (const d of page.docs) {
      scan.total++;
      const raw = d.get("qoinAccrualRate");
      if (raw !== undefined) scan.withOverride++;
      if (d.get("qoinAccrualEnabled") === false) scan.disabledUntouched++; // 집계 목적 읽기. 분기를 바꾸지 않는다.
      if (classifyRate(raw).kind === "legacyZero") {
        scan.legacyZeroCount++;
        if (scan.legacyZeroIds.length < LEGACY_IDS_MAX) scan.legacyZeroIds.push(d.id);
      }
    }
    cursor = page.docs[page.docs.length - 1];
    if (page.size < PAGE) break;
  }
  return scan;
}

/** TRANSITIONAL(spec §20.4.5): 레거시 0 이 하나라도 있으면 정책 판단 없이 멈춘다. */
function legacyZeroGuard(scan: Scan, brandLegacy: boolean): void {
  const count = scan.legacyZeroCount + (brandLegacy ? 1 : 0);
  if (count === 0) return;
  throw new HttpsError("failed-precondition", `${LEGACY_MESSAGE_PREFIX} (${count}곳)`, {
    legacyZeroCount: count,
    storeIds: scan.legacyZeroIds,
  });
}

interface Progress {
  cleared: number;
  clearedValue: number;
  clearedInvalid: number;
  scanned: number;
}

/**
 * 산하 매장을 훑으며 개별 적립률을 지운다 + 매장별 이력 1건씩 (F2). 청크마다 이력/포인터의 진행 상태를 갱신한다.
 * 매장 이력 ID = `bulk_{bulkHistoryId}` (결정적 — 재시도·재개에도 같은 문서).
 */
async function clearOverrides(
  db: admin.firestore.Firestore,
  uid: string,
  brandRef: admin.firestore.DocumentReference,
  brandId: string,
  historyRef: admin.firestore.DocumentReference,
  base: { processed: number; clearedValue: number; clearedInvalid: number }
): Promise<Progress> {
  const prog: Progress = { cleared: 0, clearedValue: 0, clearedInvalid: 0, scanned: 0 };
  let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
  for (;;) {
    let q = db
      .collection("stores")
      .where("brandId", "==", brandId)
      .select("name", "qoinAccrualRate")
      .limit(CHUNK);
    if (cursor) q = q.startAfter(cursor);
    const page = await q.get();
    if (page.empty) break;
    prog.scanned += page.size;
    const targets = page.docs.filter((d) => d.get("qoinAccrualRate") !== undefined);
    if (targets.length > 0) {
      const batch = db.batch();
      let value = 0;
      let invalid = 0;
      for (const d of targets) {
        const raw = d.get("qoinAccrualRate");
        const cell = classifyRate(raw);
        if (cell.kind === "legacyZero") {
          // 스캔 이후에 생긴 레거시 0 (사실상 불가능) — 정책 판단 없이 멈춘다. 호출부가 partial 로 마감한다.
          throw new HttpsError("failed-precondition", LEGACY_MESSAGE_PREFIX, { legacyZeroCount: 1, storeIds: [d.id] });
        }
        const info = rateBeforeInfo(raw, cell.kind === "valid");
        if (info.beforeState === "value") value++;
        else invalid++;
        batch.update(d.ref, { qoinAccrualRate: FieldValue.delete() });
        batch.create(d.ref.collection("qoinRateHistory").doc(`bulk_${historyRef.id}`), {
          scope: "store",
          targetId: d.id,
          targetName: (d.get("name") as string | undefined) ?? "",
          field: "accrualRate",
          op: "clearByBulk",
          before: info.before,
          beforeState: info.beforeState,
          beforeRaw: info.beforeRaw,
          after: null,
          changedBy: uid,
          changedByRole: "admin",
          changedAt: FieldValue.serverTimestamp(),
          reason: null,
          source: "bulk",
          bulkHistoryId: historyRef.id,
          bulkMode: "overwrite",
        });
      }
      await batch.commit(); // 재시도로 이미 커밋된 청크는 대상(필드 존재)에서 빠지므로 중복되지 않는다.
      prog.cleared += targets.length;
      prog.clearedValue += value;
      prog.clearedInvalid += invalid;
      const now = FieldValue.serverTimestamp();
      await historyRef.update({
        processedCount: base.processed + prog.cleared,
        clearedValueCount: base.clearedValue + prog.clearedValue,
        clearedInvalidCount: base.clearedInvalid + prog.clearedInvalid,
        lastProgressAt: now,
      });
      await brandRef.update({ qoinBulkAt: now }); // 잠금 갱신 (stale 판정 기준)
    }
    cursor = page.docs[page.docs.length - 1];
    if (page.size < CHUNK) break;
  }
  return prog;
}

export const applyBrandQoinRate = onCall(
  { region: REGION, timeoutSeconds: 540 },
  async (request) => {
    const db = admin.firestore();
    const uid = await requireAdmin(db, request);

    const data = (request.data ?? {}) as Request;
    if (typeof data.brandId !== "string" || data.brandId.length === 0 || data.brandId.includes("/")) {
      throw new HttpsError("invalid-argument", "brandId required");
    }
    const brandId = data.brandId;
    if (data.mode !== "preserve" && data.mode !== "overwrite") {
      throw new HttpsError("invalid-argument", "mode must be preserve|overwrite");
    }
    const mode: "preserve" | "overwrite" = data.mode;
    const reason = parseReason(data.reason);

    const brandRef = db.collection("brands").doc(brandId);
    const histCol = historyCollection(db, "brand", brandId);

    // ── 재개 ────────────────────────────────────────────────────────────────
    if (data.resumeHistoryId !== undefined) {
      if (typeof data.resumeHistoryId !== "string" || data.resumeHistoryId.length === 0) {
        throw new HttpsError("invalid-argument", "resumeHistoryId invalid");
      }
      const historyRef = histCol.doc(data.resumeHistoryId);
      const h = await historyRef.get();
      if (!h.exists || h.get("op") !== "bulkApply" || h.get("bulkMode") !== "overwrite") {
        throw new HttpsError("not-found", "resumable history not found");
      }
      if (h.get("status") === "completed" || h.get("status") === "superseded") {
        // superseded: 그 뒤의 설정 변경이 이 기록을 마감했다 — 재개 대상이 아니다 (S2).
        throw new HttpsError("failed-precondition", "already completed");
      }
      const histAfter = (h.get("after") as number | null | undefined) ?? null;

      const scan = await scanStores(db, brandId);

      // F5-(a): 재개 재검증 + 잠금 획득 — 한 트랜잭션.
      const resume = await db.runTransaction(async (t) => {
        const snap = await t.get(brandRef);
        const hs = await t.get(historyRef);
        if (!snap.exists) throw new HttpsError("not-found", "brand not found");
        if (isBulkInProgress(snap, BULK_STALE_MS)) {
          throw new HttpsError("failed-precondition", "in progress");
        }
        if (snap.get("qoinBulkHistoryId") !== historyRef.id) {
          throw new HttpsError("failed-precondition", "브랜드 값이 그 뒤에 변경됐어요. 다시 적용하세요");
        }
        const cur = snap.get("qoinAccrualRate");
        const curValue = cur === undefined ? null : cur;
        if (curValue !== histAfter) {
          throw new HttpsError("failed-precondition", "브랜드 값이 그 뒤에 변경됐어요. 다시 적용하세요");
        }
        legacyZeroGuard(scan, classifyRate(cur).kind === "legacyZero");
        const processed = typeof hs.get("processedCount") === "number" ? (hs.get("processedCount") as number) : 0;
        t.update(historyRef, {
          status: "in_progress",
          lastProgressAt: FieldValue.serverTimestamp(),
          resumedAt: FieldValue.serverTimestamp(),
          resumeCount: FieldValue.increment(1),
        });
        t.update(brandRef, { qoinBulkStatus: BULK_STATUS.inProgress, qoinBulkAt: FieldValue.serverTimestamp() });
        return {
          processed,
          clearedValue: numOr0(hs.get("clearedValueCount")),
          clearedInvalid: numOr0(hs.get("clearedInvalidCount")),
          totalCount: hs.get("totalCount") as number | undefined,
          brandDisabled: snap.get("qoinAccrualEnabled") === false,
        };
      });
      return finishOverwrite(db, uid, brandRef, brandId, historyRef, resume, scan);
    }

    // ── 신규 ────────────────────────────────────────────────────────────────
    let after: number | null;
    if (data.clear !== undefined) {
      if (data.rate !== undefined || data.clear !== true) {
        throw new HttpsError("invalid-argument", "exactly one of rate|clear required");
      }
      after = null;
    } else {
      if (!isValidCallableRate(data.rate)) {
        throw new HttpsError("invalid-argument", "rate out of range");
      }
      after = data.rate;
    }

    // 미리 센 값 (이력의 totalCount / preserve 의 affected). 트랜잭션 밖 — 정보용이다.
    // 스캔은 트랜잭션 밖이라 오래될 수 있다. 시작 시각을 기억해 두었다가 트랜잭션 안에서 불신한다 (S3-a).
    const scanStartedAt = Date.now();
    const scan = await scanStores(db, brandId);
    const historyRef = histCol.doc(); // 재시도에도 같은 ID

    type TxResult =
      | { changed: true; brandDisabled: boolean }
      | { changed: false; brandDisabled: boolean; closed?: true; staleScan?: true };
    const txResult: TxResult = await db.runTransaction(async (t): Promise<TxResult> => {
      const snap = await t.get(brandRef);
      if (!snap.exists) throw new HttpsError("not-found", "brand not found");
      // F5: 동시 실행 방지 — 같은 문서 경합이라 Firestore 가 직렬화한다.
      if (isBulkInProgress(snap, BULK_STALE_MS)) {
        throw new HttpsError("failed-precondition", BULK_IN_PROGRESS_MESSAGE);
      }
      // partial 이 남아 있으면 옛 이력도 읽는다 — read 는 write 보다 앞서야 한다. partial 일 때만 +1 read (적립 경로 무관).
      const oldPartial = await readPartialHistory(t, snap, histCol, BULK_STALE_MS);
      const rawBefore = snap.get("qoinAccrualRate");
      legacyZeroGuard(scan, classifyRate(rawBefore).kind === "legacyZero");
      const beforeInfo = rateBeforeInfo(rawBefore, classifyRate(rawBefore).kind === "valid");
      const sameValue =
        (rawBefore === undefined && after === null) || (rawBefore !== undefined && rawBefore === after);
      const brandDisabled = snap.get("qoinAccrualEnabled") === false;

      // S3-a 가드 — 오래된 스캔 불신. 포인터가 **종결 상태**이고 그 전이 시각이 내 스캔 시작보다 뒤면, 다른 호출이 내 스캔
      // 이후에 일괄 적용을 끝까지 마쳤다는 뜻이다 → 내 withOverride 는 낡은 값이다. `partial` 은 넣지 않는다 (남은 일이 있다).
      // 실패 방향: 컨테이너 시각이 서버보다 앞서면 가드가 발동하지 않고 현행 동작으로 떨어진다. 어느 쪽이든 돈에 영향이 없다.
      if (sameValue && isBulkTerminal(snap)) {
        const at = snap.get("qoinBulkAt") as admin.firestore.Timestamp | undefined;
        if (at && at.toMillis() > scanStartedAt) {
          console.warn(`${LOG} stale scan guard fired.`, { brandId, mode, scanStartedAt, qoinBulkAt: at.toMillis() });
          return { changed: false, staleScan: true, brandDisabled };
        }
      }

      // S2: 같은 값 + 지울 개별 설정 0 + 중단(partial) 포인터 → 남은 일이 없다. 새 이력 없이 옛 이력을 닫는다.
      if (sameValue && scan.withOverride === 0 && isBulkUnfinished(snap, BULK_STALE_MS)) {
        t.update(brandRef, { qoinBulkStatus: BULK_STATUS.completed, qoinBulkAt: FieldValue.serverTimestamp() });
        completePartialHistoryNothingLeft(t, oldPartial, uid);
        return { changed: false, closed: true, brandDisabled };
      }

      // 값이 같고 지울 개별 설정도 없으면 할 일이 없다 (결과 불명 후 재시도 안전).
      if (sameValue && (mode === "preserve" || scan.withOverride === 0)) {
        return { changed: false, brandDisabled };
      }

      const base = {
        scope: "brand",
        targetId: brandId,
        targetName: (snap.get("name") as string | undefined) ?? "",
        field: "accrualRate",
        before: beforeInfo.before,
        beforeState: beforeInfo.beforeState,
        beforeRaw: beforeInfo.beforeRaw,
        after,
        changedBy: uid,
        changedByRole: "admin",
        changedAt: FieldValue.serverTimestamp(),
        reason,
        source: "bulk",
        op: "bulkApply",
        bulkMode: mode,
        totalCount: scan.withOverride,
        disabledUntouchedCount: scan.disabledUntouched,
        brandDisabled,
      };

      const brandWrite: Record<string, unknown> = {};
      if (!sameValue) brandWrite.qoinAccrualRate = after === null ? FieldValue.delete() : after;
      // partial 뒤의 새 적용은 옛 이력을 같은 트랜잭션에서 마감한다 (S2). 포인터는 새 시도의 것으로 교체된다.
      supersedePartialHistory(t, oldPartial, uid, historyRef.id);
      if (mode === "preserve") {
        // preserve 도 `completed` 포인터를 남긴다 (S2 ⑤) — 삭제하지 않는다.
        t.update(brandRef, {
          ...brandWrite,
          qoinBulkHistoryId: historyRef.id,
          qoinBulkStatus: BULK_STATUS.completed,
          qoinBulkAt: FieldValue.serverTimestamp(),
        });
        t.set(historyRef, {
          ...base,
          affectedCount: scan.total - scan.withOverride,
          clearedCount: 0,
          clearedValueCount: 0,
          clearedInvalidCount: 0,
          preservedCount: scan.withOverride,
          processedCount: 0,
          status: "completed",
          lastProgressAt: FieldValue.serverTimestamp(),
        });
      } else {
        // overwrite: 잠금 포인터를 같은 write 로 건다.
        t.update(brandRef, {
          ...brandWrite,
          qoinBulkHistoryId: historyRef.id,
          qoinBulkStatus: BULK_STATUS.inProgress,
          qoinBulkAt: FieldValue.serverTimestamp(),
        });
        t.set(historyRef, {
          ...base,
          affectedCount: 0,
          clearedCount: 0,
          clearedValueCount: 0,
          clearedInvalidCount: 0,
          preservedCount: 0,
          processedCount: 0,
          status: "in_progress",
          lastProgressAt: FieldValue.serverTimestamp(),
        });
      }
      return { changed: true, brandDisabled };
    });

    if (!txResult.changed) {
      console.info(`${LOG} noop.`, { brandId, mode, closed: txResult.closed === true, staleScan: txResult.staleScan === true });
      return {
        changed: false,
        ...(txResult.closed ? { closed: true } : {}),
        ...(txResult.staleScan ? { staleScan: true } : {}),
        historyId: null,
        affectedCount: 0,
        clearedCount: 0,
        preservedCount: 0,
        processedCount: 0,
        totalCount: scan.withOverride,
        clearedValueCount: 0,
        clearedInvalidCount: 0,
        disabledUntouchedCount: scan.disabledUntouched,
        brandDisabled: txResult.brandDisabled,
        status: "completed",
      };
    }

    if (mode === "preserve") {
      console.info(`${LOG} applied preserve.`, { brandId, uid, scan });
      return {
        changed: true,
        historyId: historyRef.id,
        affectedCount: scan.total - scan.withOverride,
        clearedCount: 0,
        preservedCount: scan.withOverride,
        processedCount: 0,
        totalCount: scan.withOverride,
        clearedValueCount: 0,
        clearedInvalidCount: 0,
        disabledUntouchedCount: scan.disabledUntouched,
        brandDisabled: txResult.brandDisabled,
        status: "completed",
      };
    }
    return finishOverwrite(
      db,
      uid,
      brandRef,
      brandId,
      historyRef,
      {
        processed: 0,
        clearedValue: 0,
        clearedInvalid: 0,
        totalCount: scan.withOverride,
        brandDisabled: txResult.brandDisabled,
      },
      scan
    );
  }
);

function numOr0(v: unknown): number {
  return typeof v === "number" && Number.isFinite(v) ? v : 0;
}

/** overwrite 의 2~3 단계: 개별 적립률 청크 삭제 → 이력 마감 + 잠금 해제. 실패 시 partial 로 마감하고 에러를 던진다. */
async function finishOverwrite(
  db: admin.firestore.Firestore,
  uid: string,
  brandRef: admin.firestore.DocumentReference,
  brandId: string,
  historyRef: admin.firestore.DocumentReference,
  base: {
    processed: number;
    clearedValue: number;
    clearedInvalid: number;
    totalCount: number | undefined;
    brandDisabled: boolean;
  },
  scan: Scan
) {
  try {
    const prog = await clearOverrides(db, uid, brandRef, brandId, historyRef, base);
    const processed = base.processed + prog.cleared;
    const clearedValue = base.clearedValue + prog.clearedValue;
    const clearedInvalid = base.clearedInvalid + prog.clearedInvalid;
    const batch = db.batch();
    batch.update(historyRef, {
      status: "completed",
      affectedCount: prog.scanned, // 이번 실행이 훑은 산하 매장 수 = 새 값을 따르게 된 매장 수
      clearedCount: processed,
      clearedValueCount: clearedValue,
      clearedInvalidCount: clearedInvalid,
      processedCount: processed,
      lastProgressAt: FieldValue.serverTimestamp(),
    });
    // 마감: 포인터를 지우지 않고 `completed` 로 전이한다 (S2). historyId 는 마지막 시도를 계속 가리키고,
    // qoinBulkAt 은 이 전이 시각이다 (S3-a 가드의 기준).
    batch.update(brandRef, {
      qoinBulkStatus: BULK_STATUS.completed,
      qoinBulkAt: FieldValue.serverTimestamp(),
    });
    await batch.commit();
    console.info(`${LOG} applied overwrite.`, { brandId, scanned: prog.scanned, cleared: processed });
    return {
      changed: true,
      historyId: historyRef.id,
      affectedCount: prog.scanned,
      clearedCount: processed,
      preservedCount: 0,
      processedCount: processed,
      totalCount: base.totalCount ?? processed,
      clearedValueCount: clearedValue,
      clearedInvalidCount: clearedInvalid,
      disabledUntouchedCount: scan.disabledUntouched,
      brandDisabled: base.brandDisabled,
      status: "completed",
    };
  } catch (e) {
    console.error(`${LOG} partial. brandId:`, brandId, describeRaw((e as Error)?.message ?? e));
    try {
      const b = db.batch();
      b.update(historyRef, { status: "partial", lastProgressAt: FieldValue.serverTimestamp() });
      b.update(brandRef, { qoinBulkStatus: BULK_STATUS.partial, qoinBulkAt: FieldValue.serverTimestamp() });
      await b.commit();
    } catch (e2) {
      console.error(`${LOG} failed to mark partial. historyId:`, historyRef.id, e2);
    }
    if (e instanceof HttpsError) throw e; // 레거시 가드 등 의미 있는 에러는 그대로
    throw new HttpsError("internal", "bulk apply interrupted; resume with resumeHistoryId");
  }
}

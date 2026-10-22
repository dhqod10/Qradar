/**
 * applyBrandQoinRate — callable (admin 전용). 브랜드 적립률을 설정하고 산하 매장의 개별 설정을 처리한다.
 *
 * 요청: { brandId, rate? (0 = 적립 안 함) | clear? (true), mode: 'preserve'|'overwrite',
 *         reason?, resumeHistoryId? }
 * 응답: { affectedCount, clearedCount, preservedCount, processedCount, totalCount, status, historyId, changed }
 *
 * 순서가 중요하다 (spec §4-④):
 *   1. 이력 선기록 + 브랜드 값 1 write — **한 트랜잭션**. 이 1 write 로 "개별 설정이 없는 매장 전체" 의
 *      유효 적립률이 원자적으로 바뀐다. 어떤 매장도 의도 밖의 값(옛 브랜드 값 / 전역 값)을 거치지 않는다.
 *   2. (overwrite 만) 산하 매장의 개별 설정을 ≤450건 청크로 `FieldValue.delete()`.
 *      일부만 지워져도 나머지 매장은 지우기 전의 자기 값을 유지하므로 중간 상태가 없다.
 *      이미 지운 필드를 또 지우는 건 no-op 이므로 재개(resumeHistoryId)가 멱등하다.
 *   3. 이력 마감: completed + 실제 처리 수 (클라이언트 숫자를 믿지 않는다). 실패 시 partial.
 *
 * preserve 는 1 단계 트랜잭션에서 `completed` 까지 한 번에 쓴다 (원자성 문제 자체가 없다).
 * 역순(개별 설정 삭제 → 브랜드 값)이면 삭제된 매장이 잠깐 옛 값으로 떨어진다 — 금지.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { BULK_STALE_MS, isValidCallableRate } from "./qoinRate";
import { historyCollection, parseReason, REGION, requireAdmin } from "./qoinAdmin";

const LOG = "[applyBrandQoinRate]";
const CHUNK = 450; // Firestore batch 500 한도 아래
const PAGE = 450;

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
  withOverride: number; // 개별 설정(qoinAccrualRate 필드 존재)이 있는 매장 수 (M)
}

async function scanStores(db: admin.firestore.Firestore, brandId: string): Promise<Scan> {
  let total = 0;
  let withOverride = 0;
  let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
  for (;;) {
    let q = db
      .collection("stores")
      .where("brandId", "==", brandId)
      .orderBy(admin.firestore.FieldPath.documentId())
      .select("qoinAccrualRate")
      .limit(PAGE);
    if (cursor) q = q.startAfter(cursor);
    const page = await q.get();
    if (page.empty) break;
    for (const d of page.docs) {
      total++;
      if (d.get("qoinAccrualRate") !== undefined) withOverride++;
    }
    cursor = page.docs[page.docs.length - 1];
    if (page.size < PAGE) break;
  }
  return { total, withOverride };
}

/**
 * 산하 매장을 훑으며 개별 설정을 지운다. 지운 수와 훑은 매장 수를 돌려준다.
 * 청크마다 이력의 processedCount 를 갱신한다.
 */
async function clearOverrides(
  db: admin.firestore.Firestore,
  brandId: string,
  historyRef: admin.firestore.DocumentReference,
  alreadyProcessed: number
): Promise<{ cleared: number; scanned: number }> {
  let cleared = 0;
  let scanned = 0;
  let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
  for (;;) {
    let q = db
      .collection("stores")
      .where("brandId", "==", brandId)
      .orderBy(admin.firestore.FieldPath.documentId())
      .select("qoinAccrualRate")
      .limit(CHUNK);
    if (cursor) q = q.startAfter(cursor);
    const page = await q.get();
    if (page.empty) break;
    scanned += page.size;
    const targets = page.docs.filter((d) => d.get("qoinAccrualRate") !== undefined);
    if (targets.length > 0) {
      const batch = db.batch();
      for (const d of targets) batch.update(d.ref, { qoinAccrualRate: FieldValue.delete() });
      await batch.commit();
      cleared += targets.length;
      await historyRef.update({
        processedCount: alreadyProcessed + cleared,
        lastProgressAt: FieldValue.serverTimestamp(),
      });
    }
    cursor = page.docs[page.docs.length - 1];
    if (page.size < CHUNK) break;
  }
  return { cleared, scanned };
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
      const status = h.get("status");
      if (status === "completed") {
        throw new HttpsError("failed-precondition", "already completed");
      }
      if (status === "in_progress" && !isStale(h)) {
        throw new HttpsError("failed-precondition", "in progress");
      }
      const processed = typeof h.get("processedCount") === "number" ? (h.get("processedCount") as number) : 0;
      await historyRef.update({ status: "in_progress", lastProgressAt: FieldValue.serverTimestamp() });
      return finishOverwrite(db, brandId, historyRef, processed, h.get("totalCount") as number | undefined);
    }

    // ── 신규 ────────────────────────────────────────────────────────────────
    let after: number | null;
    if (data.clear !== undefined) {
      if (data.rate !== undefined || data.clear !== true) {
        throw new HttpsError("invalid-argument", "exactly one of rate|clear required");
      }
      after = null;
    } else {
      if (!isValidCallableRate(data.rate, true)) {
        throw new HttpsError("invalid-argument", "rate out of range");
      }
      after = data.rate;
    }

    // 동시 실행 방지: 최근 갱신이 있는 in_progress 가 있으면 거부.
    const running = await histCol.where("status", "==", "in_progress").get();
    if (running.docs.some((d) => !isStale(d))) {
      throw new HttpsError("failed-precondition", "another bulk apply is in progress");
    }

    // 미리 센 값 (이력의 totalCount / preserve 의 affected). 트랜잭션 밖 — 정보용이다.
    const scan = await scanStores(db, brandId);
    const historyRef = histCol.doc(); // 재시도에도 같은 ID

    const txResult = await db.runTransaction(async (t) => {
      const snap = await t.get(brandRef);
      if (!snap.exists) throw new HttpsError("not-found", "brand not found");
      const rawBefore = snap.get("qoinAccrualRate");
      const before: number | null = typeof rawBefore === "number" ? rawBefore : null;
      const sameValue =
        (rawBefore === undefined && after === null) || (rawBefore !== undefined && rawBefore === after);

      // 값이 같고 지울 개별 설정도 없으면 할 일이 없다 (결과 불명 후 재시도 안전).
      if (sameValue && (mode === "preserve" || scan.withOverride === 0)) {
        return { changed: false as const };
      }

      const base = {
        scope: "brand",
        targetId: brandId,
        targetName: (snap.get("name") as string | undefined) ?? "",
        field: "accrualRate",
        before,
        after,
        changedBy: uid,
        changedByRole: "admin",
        changedAt: FieldValue.serverTimestamp(),
        reason,
        source: "bulk",
        op: "bulkApply",
        bulkMode: mode,
        totalCount: scan.withOverride,
      };

      if (!sameValue) {
        t.update(brandRef, { qoinAccrualRate: after === null ? FieldValue.delete() : after });
      }
      if (mode === "preserve") {
        t.set(historyRef, {
          ...base,
          affectedCount: scan.total - scan.withOverride,
          clearedCount: 0,
          preservedCount: scan.withOverride,
          processedCount: 0,
          status: "completed",
          lastProgressAt: FieldValue.serverTimestamp(),
        });
      } else {
        t.set(historyRef, {
          ...base,
          affectedCount: 0,
          clearedCount: 0,
          preservedCount: 0,
          processedCount: 0,
          status: "in_progress",
          lastProgressAt: FieldValue.serverTimestamp(),
        });
      }
      return { changed: true as const };
    });

    if (!txResult.changed) {
      console.info(`${LOG} noop.`, { brandId, mode });
      return {
        changed: false,
        historyId: null,
        affectedCount: 0,
        clearedCount: 0,
        preservedCount: 0,
        processedCount: 0,
        totalCount: scan.withOverride,
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
        status: "completed",
      };
    }
    return finishOverwrite(db, brandId, historyRef, 0, scan.withOverride);
  }
);

/** overwrite 의 2~3 단계: 개별 설정 청크 삭제 → 이력 마감. 실패 시 partial 로 마감하고 에러를 던진다. */
async function finishOverwrite(
  db: admin.firestore.Firestore,
  brandId: string,
  historyRef: admin.firestore.DocumentReference,
  alreadyProcessed: number,
  totalCount: number | undefined
) {
  try {
    const { cleared, scanned } = await clearOverrides(db, brandId, historyRef, alreadyProcessed);
    const processed = alreadyProcessed + cleared;
    await historyRef.update({
      status: "completed",
      affectedCount: scanned, // 이번 실행이 훑은 산하 매장 수 = 새 값을 따르게 된 매장 수
      clearedCount: processed,
      processedCount: processed,
      lastProgressAt: FieldValue.serverTimestamp(),
    });
    console.info(`${LOG} applied overwrite.`, { brandId, scanned, cleared: processed });
    return {
      changed: true,
      historyId: historyRef.id,
      affectedCount: scanned,
      clearedCount: processed,
      preservedCount: 0,
      processedCount: processed,
      totalCount: totalCount ?? processed,
      status: "completed",
    };
  } catch (e) {
    console.error(`${LOG} partial. brandId:`, brandId, e);
    try {
      await historyRef.update({ status: "partial", lastProgressAt: FieldValue.serverTimestamp() });
    } catch (e2) {
      console.error(`${LOG} failed to mark partial. historyId:`, historyRef.id, e2);
    }
    throw new HttpsError("internal", "bulk apply interrupted; resume with resumeHistoryId");
  }
}

/** in_progress 가 BULK_STALE_MS 넘게 갱신이 없으면 중단된 것으로 본다. */
function isStale(h: admin.firestore.DocumentSnapshot): boolean {
  const ts = h.get("lastProgressAt") as admin.firestore.Timestamp | undefined;
  if (!ts) return true;
  return Date.now() - ts.toMillis() > BULK_STALE_MS;
}

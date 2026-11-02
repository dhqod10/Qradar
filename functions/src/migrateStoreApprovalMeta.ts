/**
 * migrateStoreApprovalMeta — 임시 마이그레이션 callable (admin 전용). payment_server_authority M1 (spec §16, §17 ③).
 * **임시 자산이다.** 완료 후 수일 뒤 정리 커밋으로 삭제한다 (배포 ⑪).
 *
 * 결제 게이트(canSellNow)가 켜지기 **전에** stores 를 정상화한다 — 안 하면 legacy 매장이 전부 결제 거부된다 (spec §8.1).
 *   ⓐ `status` 가 부재한 문서 → 'approved' 를 명시적으로 쓴다 (StoreModel 은 부재를 approved 로 읽어 왔다 — 현재 동작 보존)
 *   ⓑ `status=='approved'` 인데 `approvedAt` 이 없는 문서 → approvedAt 백필 (createdAt, 없으면 서버 시각; 판정은 "존재 여부"만 본다)
 *   ⓒ 이상치 감사 (자동 정리 금지 — 목록으로 보고하고 **멈춘다**):
 *        anomalies   : status != 'approved' && approvedAt != null && approvedBy == null  (§5-4 🔴 create 경로로 심긴 값일 수 있다)
 *        invalid     : status 가 approved/pending/rejected 밖의 값
 *   ⓓ `willBeRejected` (T-1 F-01) — **백필을 가정한 뒤에도** canSellNow 가 false 인 매장 `{id,name,status,hasApprovedAt}`.
 *        게이트 ⑥ 전에 "어느 매장이 막힌다" 를 눈으로 확인하는 유일한 수단이다. status/hasApprovedAt 는 백필 **후** 값이다.
 *   ⓔ 모호 건 감사 (F-02 / spec §6.8) — 목록만 보고한다. **자동으로 고치지 않고, 실행을 막지도 않는다**
 *        (ⓔ 는 배포 차단 조건이 아니다 — §6.5 전이 제약이 있다는 전제, spec §6.8 마지막 블록):
 *        ambiguousRejected      : status=='rejected' && approvedAt != null  (반려가 approvedAt 을 덮어써서 "승인 후 반려" 와 "반려만" 을 구분할 수 없다)
 *        ambiguousSelfRegress   : status=='pending' && rejectedReason != null && approvedAt != null  (F-02 self-regress 흔적 —
 *                                 approvedBy 가 admin 값으로 남아 ⓒ(approvedBy==null 기준)가 못 잡는다)
 *   ※ ⓒ(anomalies/invalid)만 실행을 멈춘다. ⓓⓔ 는 dry-run·실행 응답 양쪽에 같은 모양으로 실린다.
 *
 * 입력 { dryRun?: boolean = true } — dry-run 이 기본이다. 실행(dryRun:false)은 anomalies/invalid 가 비어 있을 때만 쓴다.
 * 실행하면 `migrationHistory/{autoId}` 1건에 영향 범위(대상 수)를 남긴다 (audit_trail §4-5).
 */
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { REGION, requireAdmin } from "./qoinAdmin";
import { canSellNow } from "./storeSellability";

export interface StoreMigrationPlan {
  setStatusApproved: string[];
  backfillApprovedAt: string[];
  anomalies: string[];
  invalid: Array<{ id: string; status: unknown }>;
  /** ⓓ 백필 후에도 canSellNow 가 false 인 매장. status/hasApprovedAt 은 백필 후 값. */
  willBeRejected: Array<{ id: string; name: string | null; status: unknown; hasApprovedAt: boolean }>;
  /** ⓔ status=='rejected' && approvedAt != null 전건. */
  ambiguousRejected: Array<{ id: string; name: string | null }>;
  /** ⓔ status=='pending' && rejectedReason != null && approvedAt != null. */
  ambiguousSelfRegress: Array<{ id: string; name: string | null }>;
}

/** 순수 분류 — 단위 테스트 대상. 입력은 [id, data] 쌍. */
export function planStoreMigration(docs: Array<[string, Record<string, unknown>]>): StoreMigrationPlan {
  const plan: StoreMigrationPlan = {
    setStatusApproved: [], backfillApprovedAt: [], anomalies: [], invalid: [],
    willBeRejected: [], ambiguousRejected: [], ambiguousSelfRegress: [],
  };
  for (const [id, d] of docs) {
    const status = d.status;
    const name = typeof d.name === "string" ? d.name : null;
    // ⓔ — 현재 값 기준(백필은 approved/부재 문서만 건드리므로 rejected/pending 의 approvedAt 은 백필 전후 같다).
    if (status === "rejected" && d.approvedAt != null) plan.ambiguousRejected.push({ id, name });
    if (status === "pending" && d.rejectedReason != null && d.approvedAt != null) plan.ambiguousSelfRegress.push({ id, name });
    const hasStatus = Object.prototype.hasOwnProperty.call(d, "status") && status !== undefined && status !== null;
    if (!hasStatus) {
      plan.setStatusApproved.push(id);
      // 부재 → approved 로 쓰는 문서는 approvedAt 도 같이 필요하다.
      if (d.approvedAt == null) plan.backfillApprovedAt.push(id);
      continue;
    }
    if (status !== "approved" && status !== "pending" && status !== "rejected") {
      plan.invalid.push({ id, status });
      continue;
    }
    if (status === "approved" && d.approvedAt == null) plan.backfillApprovedAt.push(id);
    if (status !== "approved" && d.approvedAt != null && d.approvedBy == null) plan.anomalies.push(id);
  }
  // ⓓ — 백필을 가정한 뒤의 상태로 같은 canSellNow(판정 함수 중복 생성 금지)를 돌린다.
  const statusWritten = new Set(plan.setStatusApproved);
  const approvedAtWritten = new Set(plan.backfillApprovedAt);
  for (const [id, d] of docs) {
    const status = statusWritten.has(id) ? "approved" : d.status;
    const hasApprovedAt = approvedAtWritten.has(id) || d.approvedAt != null;
    if (!canSellNow({ rawStatus: typeof status === "string" ? status : null, hasApprovedAt, temporaryClosed: false, scheduleClosedNow: false })) {
      plan.willBeRejected.push({ id, name: typeof d.name === "string" ? d.name : null, status: status ?? null, hasApprovedAt });
    }
  }
  return plan;
}

export const migrateStoreApprovalMeta = onCall({ region: REGION, timeoutSeconds: 540 }, async (request) => {
  const db = admin.firestore();
  const adminUid = await requireAdmin(db, request);
  const dryRun = (request.data as { dryRun?: unknown } | undefined)?.dryRun !== false;

  const snap = await db.collection("stores").get();
  const plan = planStoreMigration(snap.docs.map((d) => [d.id, d.data()] as [string, Record<string, unknown>]));
  const report = { dryRun, total: snap.size, ...plan };

  if (dryRun) return report;
  if (plan.anomalies.length > 0 || plan.invalid.length > 0) {
    throw new HttpsError("failed-precondition", "이상치가 있어 멈췄어요. 목록을 확인하세요.", {
      anomalies: plan.anomalies,
      invalid: plan.invalid,
    });
  }

  const byId = new Map(snap.docs.map((d) => [d.id, d]));
  const writes: Array<[string, Record<string, unknown>]> = [];
  const touched = new Set([...plan.setStatusApproved, ...plan.backfillApprovedAt]);
  for (const id of touched) {
    const d = byId.get(id)!;
    const patch: Record<string, unknown> = {};
    if (plan.setStatusApproved.includes(id)) patch.status = "approved";
    if (plan.backfillApprovedAt.includes(id)) patch.approvedAt = d.get("createdAt") ?? FieldValue.serverTimestamp();
    writes.push([id, patch]);
  }
  for (let i = 0; i < writes.length; i += 400) {
    const batch = db.batch();
    for (const [id, patch] of writes.slice(i, i + 400)) batch.update(db.collection("stores").doc(id), patch);
    await batch.commit();
  }
  await db.collection("migrationHistory").add({
    name: "migrateStoreApprovalMeta",
    executedBy: adminUid,
    executedAt: FieldValue.serverTimestamp(),
    total: snap.size,
    setStatusApproved: plan.setStatusApproved.length,
    backfillApprovedAt: plan.backfillApprovedAt.length,
    anomalies: 0,
    // ⓓⓔ 는 목록만 보고한다(자동 수정 없음) — 실행 시점에 몇 건이 보고 대상이었는지만 남긴다.
    willBeRejected: plan.willBeRejected.length,
    ambiguousRejected: plan.ambiguousRejected.length,
    ambiguousSelfRegress: plan.ambiguousSelfRegress.length,
  });
  return { ...report, written: writes.length };
});

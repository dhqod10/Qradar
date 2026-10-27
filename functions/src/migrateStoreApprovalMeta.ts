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
 *
 * 입력 { dryRun?: boolean = true } — dry-run 이 기본이다. 실행(dryRun:false)은 anomalies/invalid 가 비어 있을 때만 쓴다.
 * 실행하면 `migrationHistory/{autoId}` 1건에 영향 범위(대상 수)를 남긴다 (audit_trail §4-5).
 */
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { REGION, requireAdmin } from "./qoinAdmin";

export interface StoreMigrationPlan {
  setStatusApproved: string[];
  backfillApprovedAt: string[];
  anomalies: string[];
  invalid: Array<{ id: string; status: unknown }>;
}

/** 순수 분류 — 단위 테스트 대상. 입력은 [id, data] 쌍. */
export function planStoreMigration(docs: Array<[string, Record<string, unknown>]>): StoreMigrationPlan {
  const plan: StoreMigrationPlan = { setStatusApproved: [], backfillApprovedAt: [], anomalies: [], invalid: [] };
  for (const [id, d] of docs) {
    const status = d.status;
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
  });
  return { ...report, written: writes.length };
});

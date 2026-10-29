/**
 * backfillAvailableMainCategories — admin 전용 callable (store_category_optout Phase B, spec §12.2).
 *
 * 전 매장의 `availableMainCategories` 를 전량 재계산한다. **임시 자산이 아니다** — 트리거 누락/신규 매장 시드/정합 재조정용 상시 도구
 * (멱등: 여러 번 돌려도 같은 결과). `migrateStoreApprovalMeta` 구조를 따른다.
 *
 * 입력 { dryRun?: boolean = true } — dryRun 은 쓰기 0, 변경될 매장의 before/after 를 리포트한다.
 * 실행(dryRun:false)은 400건 청크 배치로 쓰고 `migrationHistory/{autoId}` 1건에 affected/total 을 남긴다 (audit_trail §4-5/§4-6).
 */
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { onCall } from "firebase-functions/v2/https";
import { RawDoc } from "./menuVisibility";
import { REGION, requireAdmin } from "./qoinAdmin";
import { commitPlans, loadActiveCodes, newShared, planStores } from "./recomputeAvailableCategories";

export const backfillAvailableMainCategories = onCall({ region: REGION, timeoutSeconds: 540 }, async (request) => {
  const db = admin.firestore();
  const adminUid = await requireAdmin(db, request);
  const dryRun = (request.data as { dryRun?: unknown } | undefined)?.dryRun !== false;

  const snap = await db.collection("stores").get();
  const shared = newShared(await loadActiveCodes(db));
  const plans = await planStores(db, snap.docs.map((d) => ({ id: d.id, data: d.data() as RawDoc })), shared);
  const changed = plans.filter((p) => p.changed);
  const report = {
    dryRun,
    total: snap.size,
    affected: changed.length,
    changes: changed.map((p) => ({ id: p.storeId, before: Array.isArray(p.before) ? p.before : null, after: p.after })),
  };
  if (dryRun) return report;

  await commitPlans(db, plans);
  await db.collection("migrationHistory").add({
    name: "backfillAvailableMainCategories",
    executedBy: adminUid,
    executedAt: FieldValue.serverTimestamp(),
    total: snap.size,
    affected: changed.length,
  });
  return report;
});

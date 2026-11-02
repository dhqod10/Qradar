/**
 * backfillStoreSearchKeywords — admin 전용 callable (search_keyword_enhancement, spec §0 D6).
 *
 * 전 매장의 `searchKeywords` 를 (매장명 + 브랜드명 + menuCategories) 에서 전량 재계산한다. 상시 정합 도구(멱등).
 * 입력 { dryRun?: boolean = true } — dryRun 은 쓰기 0. 실행은 400건 청크 배치 + `migrationHistory` 1건 (audit_trail §4-5).
 */
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { onCall } from "firebase-functions/v2/https";
import { RawDoc } from "./menuVisibility";
import { REGION, requireAdmin } from "./qoinAdmin";
import { commitPlans, planStores } from "./recomputeSearchKeywords";

export const backfillStoreSearchKeywords = onCall({ region: REGION, timeoutSeconds: 540 }, async (request) => {
  const db = admin.firestore();
  const adminUid = await requireAdmin(db, request);
  const dryRun = (request.data as { dryRun?: unknown } | undefined)?.dryRun !== false;

  const snap = await db.collection("stores").get();
  const plans = await planStores(db, snap.docs.map((d) => ({ id: d.id, data: d.data() as RawDoc })), new Map());
  const changed = plans.filter((p) => p.changed);
  const report = {
    dryRun,
    total: snap.size,
    affected: changed.length,
    sample: changed.slice(0, 20).map((p) => ({
      id: p.storeId,
      beforeCount: Array.isArray(p.before) ? p.before.length : null,
      afterCount: p.after.length,
    })),
  };
  if (dryRun) return report;

  await commitPlans(db, plans);
  await db.collection("migrationHistory").add({
    name: "backfillStoreSearchKeywords",
    executedBy: adminUid,
    executedAt: FieldValue.serverTimestamp(),
    total: snap.size,
    affected: changed.length,
  });
  return report;
});

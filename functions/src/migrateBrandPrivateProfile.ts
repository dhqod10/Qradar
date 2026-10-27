/**
 * migrateBrandPrivateProfile — 임시 마이그레이션 callable (admin 전용). payment_server_authority M2 (spec §16, §17 ⑤⑨).
 * **임시 자산이다.** 완료 후 수일 뒤 정리 커밋으로 삭제한다 (배포 ⑪).
 *
 * 2단계 (먼저 지우면 구버전 앱의 brand 정보 화면이 빈다 — 복사와 제거를 분리한다):
 *   stage 'copy'    (배포 ⑤) : 부모의 brandKey + PII 5개를 `brands/{id}/private/profile` 로 **복사**하고
 *                              `brandKeys/{key}` (문서 ID = 키) 를 만든다. 부모 필드는 지우지 않는다.
 *   stage 'cleanup' (배포 ⑨) : private 에 값이 모두 있고 부모와 같을 때만 부모의 6개 필드를 제거한다. ⑧(Rules-B+C) 이후,
 *                              구버전 앱이 없음을 확인한 뒤에만 실행한다.
 * 입력 { stage: 'copy'|'cleanup', dryRun?: boolean = true }. 무효 값(형식 불일치 brandKey, 키 충돌, 복사 불일치)이 하나라도 있으면
 * 실행을 거부하고 목록을 돌려준다 (자동 변환 금지 — 멈추고 보고). 실행하면 `migrationHistory` 1건.
 */
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { REGION, requireAdmin } from "./qoinAdmin";
import { BRAND_KEY_RE } from "./brandKeyCore";

export const PII_FIELDS = ["businessRegistrationNumber", "representativeName", "contactName", "contactPhone", "headOfficeAddress"] as const;
const MOVED = ["brandKey", ...PII_FIELDS] as const;

type Raw = Record<string, unknown>;
const present = (v: unknown) => v !== undefined && v !== null && v !== "";

export interface CopyPlan {
  copy: Array<{ brandId: string; fields: Record<string, unknown>; brandKey: string | null }>;
  invalid: Array<{ brandId: string; reason: string }>;
}

/** stage copy 순수 분류. existingPrivate: brandId → private/profile 데이터, existingKeys: key → brandId. */
export function planBrandCopy(
  brands: Array<[string, Raw]>,
  existingPrivate: Map<string, Raw>,
  existingKeys: Map<string, string>
): CopyPlan {
  const plan: CopyPlan = { copy: [], invalid: [] };
  const seen = new Map<string, string>();
  for (const [brandId, d] of brands) {
    const fields: Record<string, unknown> = {};
    for (const f of MOVED) if (present(d[f])) fields[f] = d[f];
    if (Object.keys(fields).length === 0) continue;
    let brandKey: string | null = null;
    if (present(d.brandKey)) {
      const k = d.brandKey;
      if (typeof k !== "string" || !BRAND_KEY_RE.test(k)) {
        plan.invalid.push({ brandId, reason: "brandKey 형식 불일치" });
        continue;
      }
      const owner = existingKeys.get(k) ?? seen.get(k);
      if (owner && owner !== brandId) {
        plan.invalid.push({ brandId, reason: `brandKey 가 다른 브랜드(${owner})와 중복` });
        continue;
      }
      seen.set(k, brandId);
      brandKey = k;
    }
    // private 에 이미 있는 값은 덮지 않는다 (CF/본인이 쓴 값이 더 최신일 수 있다).
    const prior = existingPrivate.get(brandId) ?? {};
    const toWrite: Record<string, unknown> = {};
    for (const [f, v] of Object.entries(fields)) if (!present(prior[f])) toWrite[f] = v;
    plan.copy.push({ brandId, fields: toWrite, brandKey });
  }
  return plan;
}

export interface CleanupPlan {
  clean: string[];
  invalid: Array<{ brandId: string; reason: string }>;
}

/** stage cleanup 순수 분류: 부모에 남은 이동 대상 필드가 있는 브랜드 중, private 와 값이 모두 같은 것만 제거 대상. */
export function planBrandCleanup(brands: Array<[string, Raw]>, privates: Map<string, Raw>): CleanupPlan {
  const plan: CleanupPlan = { clean: [], invalid: [] };
  for (const [brandId, d] of brands) {
    const left = MOVED.filter((f) => f in d);
    if (left.length === 0) continue;
    const p = privates.get(brandId);
    if (!p) {
      plan.invalid.push({ brandId, reason: "private/profile 없음" });
      continue;
    }
    const mismatch = left.filter((f) => present(d[f]) && p[f] !== d[f]);
    if (mismatch.length > 0) plan.invalid.push({ brandId, reason: `private 와 값 불일치: ${mismatch.join(",")}` });
    else plan.clean.push(brandId);
  }
  return plan;
}

export const migrateBrandPrivateProfile = onCall({ region: REGION, timeoutSeconds: 540 }, async (request) => {
  const db = admin.firestore();
  const adminUid = await requireAdmin(db, request);
  const d = (request.data ?? {}) as { stage?: unknown; dryRun?: unknown };
  if (d.stage !== "copy" && d.stage !== "cleanup") throw new HttpsError("invalid-argument", "stage must be copy|cleanup");
  const dryRun = d.dryRun !== false;

  const brandSnap = await db.collection("brands").get();
  const brands = brandSnap.docs.map((s) => [s.id, s.data()] as [string, Raw]);
  const privSnaps = await db.getAll(...brandSnap.docs.map((s) => s.ref.collection("private").doc("profile")));
  const privates = new Map<string, Raw>();
  privSnaps.forEach((p, i) => {
    if (p.exists) privates.set(brandSnap.docs[i].id, p.data() as Raw);
  });

  if (d.stage === "copy") {
    const keySnap = await db.collection("brandKeys").get();
    const existingKeys = new Map(keySnap.docs.map((k) => [k.id, String(k.get("brandId"))]));
    const plan = planBrandCopy(brands, privates, existingKeys);
    const report = { stage: "copy", dryRun, total: brandSnap.size, toCopy: plan.copy.length, invalid: plan.invalid };
    if (dryRun) return report;
    if (plan.invalid.length > 0) throw new HttpsError("failed-precondition", "무효 값이 있어 멈췄어요.", { invalid: plan.invalid });
    for (const c of plan.copy) {
      const privRef = db.collection("brands").doc(c.brandId).collection("private").doc("profile");
      const patch: Record<string, unknown> = { ...c.fields };
      if (c.brandKey && !present(privates.get(c.brandId)?.brandKey)) patch.brandKey = c.brandKey;
      if (Object.keys(patch).length > 0) await privRef.set(patch, { merge: true });
      if (c.brandKey && !existingKeys.has(c.brandKey)) {
        await db.collection("brandKeys").doc(c.brandKey).create({ brandId: c.brandId, issuedAt: FieldValue.serverTimestamp(), issuedBy: adminUid });
        await db.collection("brands").doc(c.brandId).collection("keyHistory").add({
          brandKey: c.brandKey, previousKey: null, changedBy: adminUid, changedByRole: "admin", source: "migration", op: "migrate",
          changedAt: FieldValue.serverTimestamp(),
        });
      }
    }
    await db.collection("migrationHistory").add({
      name: "migrateBrandPrivateProfile:copy", executedBy: adminUid, executedAt: FieldValue.serverTimestamp(),
      total: brandSnap.size, copied: plan.copy.length,
    });
    return { ...report, written: plan.copy.length };
  }

  const plan = planBrandCleanup(brands, privates);
  const report = { stage: "cleanup", dryRun, total: brandSnap.size, toClean: plan.clean.length, invalid: plan.invalid };
  if (dryRun) return report;
  if (plan.invalid.length > 0) throw new HttpsError("failed-precondition", "무효 값이 있어 멈췄어요.", { invalid: plan.invalid });
  for (const id of plan.clean) {
    const patch: Record<string, unknown> = {};
    for (const f of MOVED) patch[f] = FieldValue.delete();
    await db.collection("brands").doc(id).update(patch);
  }
  await db.collection("migrationHistory").add({
    name: "migrateBrandPrivateProfile:cleanup", executedBy: adminUid, executedAt: FieldValue.serverTimestamp(),
    total: brandSnap.size, cleaned: plan.clean.length,
  });
  return { ...report, written: plan.clean.length };
});

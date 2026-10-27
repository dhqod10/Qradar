/**
 * lookupBrandByKey — callable (로그인 사용자). brandKey 로 승인된 브랜드를 O(1) 단건 조회한다.
 * payment_server_authority B1 (spec §10.3). `brands.brandKey` 는 이제 비공개(`private/profile`)라 클라이언트 쿼리가 불가능하다.
 *
 *  - 입력 `brandKey` 는 서버에서 `^BR-[A-Z2-9]{8}$` 재검증 (클라 정규식을 권위로 삼지 않는다)
 *  - brandKeys/{key} → brandId → brands/{brandId}.status == 'approved'
 *  - 반환 `{ brandId, name, logoUrl }` **만** — PII·brandKey 를 되돌려주지 않는다
 *  - 미존재와 미승인을 **같은 응답**(`not-found`)으로 돌린다 (열거 오라클 방지)
 *  - rate limit: uid 당 분당 N회 초과 → `resource-exhausted` + Cloud Logging
 */
import * as admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { REGION } from "./qoinAdmin";
import { BRAND_KEY_RE } from "./brandKeyCore";

export const LOOKUP_LIMIT_PER_MINUTE = 10;
const NOT_FOUND_MSG = "브랜드를 찾을 수 없어요. 키를 다시 확인해주세요";

export interface LookupPorts {
  /** 호출 1건을 센다. 창(분) 안의 누적 횟수를 돌려준다 (이번 호출 포함). */
  countCall(uid: string, nowMs: number): Promise<number>;
  getKeyBrandId(key: string): Promise<string | null>;
  getBrand(brandId: string): Promise<{ status?: unknown; name?: unknown; logoUrl?: unknown } | null>;
}

export async function lookupBrandByKeyCore(
  ports: LookupPorts,
  args: { uid: string; brandKey: unknown; nowMs: number }
): Promise<{ brandId: string; name: string; logoUrl: string }> {
  const n = await ports.countCall(args.uid, args.nowMs);
  if (n > LOOKUP_LIMIT_PER_MINUTE) {
    console.warn("[lookupBrandByKey] rate limit exceeded", { uid: args.uid, n });
    throw new HttpsError("resource-exhausted", "조회를 너무 많이 시도했어요. 잠시 후 다시 시도해주세요");
  }
  if (typeof args.brandKey !== "string" || !BRAND_KEY_RE.test(args.brandKey)) {
    // 형식 불일치도 미매칭과 같은 응답 — 형식이 맞는 키만 존재 여부가 갈리는 것을 숨긴다.
    throw new HttpsError("not-found", NOT_FOUND_MSG);
  }
  const brandId = await ports.getKeyBrandId(args.brandKey);
  const brand = brandId ? await ports.getBrand(brandId) : null;
  if (!brandId || !brand || brand.status !== "approved") {
    throw new HttpsError("not-found", NOT_FOUND_MSG);
  }
  return {
    brandId,
    name: typeof brand.name === "string" ? brand.name : "",
    logoUrl: typeof brand.logoUrl === "string" ? brand.logoUrl : "",
  };
}

export function makeFirestoreLookupPorts(db: admin.firestore.Firestore): LookupPorts {
  return {
    async countCall(uid, nowMs) {
      const ref = db.collection("brandKeyLookupLimits").doc(uid);
      return db.runTransaction(async (t) => {
        const snap = await t.get(ref);
        const start = snap.exists ? Number(snap.get("windowStartMs")) : 0;
        const inWindow = snap.exists && nowMs - start < 60_000;
        const count = (inWindow ? Number(snap.get("count")) : 0) + 1;
        t.set(ref, { windowStartMs: inWindow ? start : nowMs, count });
        return count;
      });
    },
    async getKeyBrandId(key) {
      const s = await db.collection("brandKeys").doc(key).get();
      const id = s.exists ? s.get("brandId") : null;
      return typeof id === "string" && id.length > 0 ? id : null;
    },
    async getBrand(brandId) {
      const s = await db.collection("brands").doc(brandId).get();
      return s.exists ? (s.data() as Record<string, unknown>) : null;
    },
  };
}

export const lookupBrandByKey = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "login required");
  const brandKey = (request.data as { brandKey?: unknown } | undefined)?.brandKey;
  return lookupBrandByKeyCore(makeFirestoreLookupPorts(admin.firestore()), { uid, brandKey, nowMs: Date.now() });
});

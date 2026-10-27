/**
 * issueBrandKey — callable (admin 전용). brandKey 를 **서버에서** 발급한다 (payment_server_authority B1, spec §10.3).
 *
 * 왜 서버인가: 지금까지 클라이언트가 `where brandKey==` 쿼리로 "비었나" 보고 brandKey 를 썼다 — 검사와 실행이 분리된
 * 쿼리 기반 유일성이라 경쟁 조건에서 중복이 가능했고 이력도 없었다. brandKey 는 가맹 신청의 권한 근거라 **권한 값**이다.
 *
 * 한 트랜잭션 (tryIssue):
 *   ① brandKeys/{key} create  — 문서 ID = 키 → **유일성이 구조로 보장**된다 (이미 있으면 충돌)
 *   ② brands/{id}/private/profile.brandKey 쓰기
 *   ③ brands/{id}/keyHistory/{autoId} 1건 (changedBy = admin uid)
 * 멱등: 이미 키가 있으면 새로 만들지 않고 그 키를 돌려준다 (승인 재시도·pending 회귀 후 재승인 모두 안전).
 *
 * 요청: { brandId } → 응답: { brandKey, alreadyIssued }
 */
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { REGION, requireAdmin } from "./qoinAdmin";
import { BRAND_KEY_RE, generateBrandKey } from "./brandKeyCore";

export type TryIssueResult =
  | { kind: "issued" }
  | { kind: "already"; brandKey: string }
  | { kind: "collision" }
  | { kind: "brand_not_found" };

export interface IssuePorts {
  /** 위 ①②③ 을 원자적으로 시도한다. */
  tryIssue(brandId: string, key: string, adminUid: string): Promise<TryIssueResult>;
  generateKey(): string;
}

export const MAX_ISSUE_ATTEMPTS = 5;

export async function issueBrandKeyCore(
  ports: IssuePorts,
  args: { brandId: string; adminUid: string }
): Promise<{ brandKey: string; alreadyIssued: boolean }> {
  for (let i = 0; i < MAX_ISSUE_ATTEMPTS; i++) {
    const key = ports.generateKey();
    const r = await ports.tryIssue(args.brandId, key, args.adminUid);
    if (r.kind === "issued") return { brandKey: key, alreadyIssued: false };
    if (r.kind === "already") return { brandKey: r.brandKey, alreadyIssued: true };
    if (r.kind === "brand_not_found") throw new HttpsError("not-found", "brand not found");
    // collision → 다른 키로 재시도
  }
  throw new HttpsError("aborted", "brandKey 발급에 실패했어요. 다시 시도해주세요");
}

export function makeFirestoreIssuePorts(db: admin.firestore.Firestore): IssuePorts {
  return {
    generateKey: generateBrandKey,
    async tryIssue(brandId, key, adminUid) {
      return db.runTransaction(async (t): Promise<TryIssueResult> => {
        const brandRef = db.collection("brands").doc(brandId);
        const privRef = brandRef.collection("private").doc("profile");
        const keyRef = db.collection("brandKeys").doc(key);
        const [brandSnap, privSnap, keySnap] = await Promise.all([t.get(brandRef), t.get(privRef), t.get(keyRef)]);
        if (!brandSnap.exists) return { kind: "brand_not_found" };
        const existing = privSnap.exists ? privSnap.get("brandKey") : undefined;
        if (typeof existing === "string" && BRAND_KEY_RE.test(existing)) return { kind: "already", brandKey: existing };
        if (keySnap.exists) return { kind: "collision" };
        t.create(keyRef, { brandId, issuedAt: FieldValue.serverTimestamp(), issuedBy: adminUid });
        t.set(privRef, { brandKey: key }, { merge: true });
        t.set(brandRef.collection("keyHistory").doc(), {
          brandKey: key,
          previousKey: null,
          changedBy: adminUid,
          changedByRole: "admin",
          source: "callable",
          op: "issue",
          changedAt: FieldValue.serverTimestamp(),
        });
        return { kind: "issued" };
      });
    },
  };
}

export const issueBrandKey = onCall({ region: REGION }, async (request) => {
  const db = admin.firestore();
  const adminUid = await requireAdmin(db, request);
  const raw = (request.data as { brandId?: unknown } | undefined)?.brandId;
  if (typeof raw !== "string" || raw.length === 0 || raw.includes("/")) {
    throw new HttpsError("invalid-argument", "brandId required");
  }
  const r = await issueBrandKeyCore(makeFirestoreIssuePorts(db), { brandId: raw, adminUid });
  console.info("[issueBrandKey]", r.alreadyIssued ? "already" : "issued", { brandId: raw });
  return r;
});

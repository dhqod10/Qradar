/**
 * claimSubmittedBrand — callable (로그인 사용자). 내가 제출한 브랜드를 내 계정에 연결한다 (`users/{uid}.brandId` 설정).
 *
 * brand_authorization_hardening D1: `users.brandId` 는 브랜드 트리와 산하 매장의 쓰기 권한을 결정하는 **권한 값**이라
 * 클라이언트가 쓸 수 없다 (Rules 화이트리스트에서 제거). 이 함수가 유일한 쓰기 경로이며 Admin SDK 로 쓴다.
 *
 * 요청: { brandId: string }
 * 응답: { changed: boolean, brandId: string }
 *
 * 한 트랜잭션:
 *   1. brands/{brandId} 읽기 — 없으면 `not-found`
 *   2. brands/{brandId}.submittedBy == uid 아니면 `permission-denied`   ← 핵심 검증
 *   3. users/{uid} 읽기
 *        이미 brandId == 요청값          → noop `{ changed:false }` (멱등 — 이력 추가 없음)
 *        이미 다른 값이 들어 있음         → `failed-precondition` "이미 다른 브랜드에 연결된 계정이에요"
 *        role != 'brand'                  → `failed-precondition`
 *   4. users/{uid}.brandId 쓰기 + users/{uid}/roleHistory/{autoId} 1건 (audit_trail §4 — 값과 이력은 같은 트랜잭션)
 *
 * 멱등이고 재시도 가능하다. 교정(잘못 연결된 계정)은 admin 전용이다 (D4) — 이 함수는 기존 값을 절대 덮지 않는다.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { REGION } from "./qoinAdmin";

const LOG = "[claimSubmittedBrand]";

/**
 * 실패 사유를 기계가 읽을 수 있게 싣는다. 같은 `failed-precondition` 이라도 "이미 다른 브랜드에 연결" 과 "브랜드 계정이 아님" 은
 * 화면이 다르게 말해야 한다 (3차: 코드만으로 분류하면 role 불일치가 "이미 연결" 로 오분류된다).
 * `details.reason` 이 정본이고, 실기기에서 details 가 Map 으로 오지 않을 수 있어(spec §21.9-5) message 끝에 `[reason]` 도 싣는다.
 */
export type ClaimReason = "already_linked" | "not_brand_account" | "not_submitter" | "brand_not_found";
function claimError(
  code: "not-found" | "permission-denied" | "failed-precondition",
  reason: ClaimReason,
  message: string
): HttpsError {
  return new HttpsError(code, `${message} [${reason}]`, { reason });
}

export const claimSubmittedBrand = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "login required");

  const raw = (request.data as { brandId?: unknown } | undefined)?.brandId;
  if (typeof raw !== "string" || raw.length === 0 || raw.includes("/")) {
    throw new HttpsError("invalid-argument", "brandId required");
  }
  const brandId = raw;

  const db = admin.firestore();
  const brandRef = db.collection("brands").doc(brandId);
  const userRef = db.collection("users").doc(uid);
  const historyRef = userRef.collection("roleHistory").doc(); // 재시도에도 같은 ID

  const changed = await db.runTransaction(async (t) => {
    const brandSnap = await t.get(brandRef);
    if (!brandSnap.exists) throw claimError("not-found", "brand_not_found", "brand not found");
    if (brandSnap.get("submittedBy") !== uid) {
      throw claimError("permission-denied", "not_submitter", "not the submitter of this brand");
    }
    const userSnap = await t.get(userRef);
    const current = userSnap.exists ? userSnap.get("brandId") : undefined;
    if (current === brandId) return false;
    if (typeof current === "string" && current.length > 0) {
      throw claimError("failed-precondition", "already_linked", "이미 다른 브랜드에 연결된 계정이에요");
    }
    if (!userSnap.exists || userSnap.get("role") !== "brand") {
      throw claimError("failed-precondition", "not_brand_account", "브랜드 계정이 아니에요");
    }
    t.update(userRef, { brandId });
    t.set(historyRef, {
      field: "brandId",
      before: null,
      after: brandId,
      changedBy: uid,
      changedByRole: "self",
      source: "callable",
      changedAt: FieldValue.serverTimestamp(),
    });
    return true;
  });

  console.info(`${LOG} ${changed ? "linked" : "noop"}.`, { uid, brandId });
  return { changed, brandId };
});

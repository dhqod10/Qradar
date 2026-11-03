/**
 * 소셜 재가입 시 탈퇴(익명화)된 users 문서 재활성화 (account_deletion §0-9).
 * kakao_/naver_ uid 는 결정적이라 같은 소셜 계정으로 재가입하면 같은 uid 가 되살아난다.
 * `deleted == true` 문서를 만나면 깨끗한 신규 상태로 **재초기화**한다 (set, merge 아님 — 익명화 잔여 필드 제거).
 * 이전 이력은 accountDeletionHistory / qoinTransactions(소멸 원장) 에 남아 있다 (balance==Σamount 유지: 잔액 0).
 * 클라이언트는 `deleted` 를 지울 수 없다 (Rules self-update 화이트리스트) → 토큰 발급 CF 가 Admin SDK 로 수행한다.
 */
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";

export async function reactivateIfDeleted(
  db: admin.firestore.Firestore,
  uid: string,
  provider: "kakao" | "naver"
): Promise<boolean> {
  const ref = db.collection("users").doc(uid);
  return db.runTransaction(async (t) => {
    const snap = await t.get(ref);
    if (!snap.exists || snap.get("deleted") !== true) return false;
    t.set(ref, {
      uid,
      provider,
      role: "customer",
      createdAt: FieldValue.serverTimestamp(),
      reactivatedAt: FieldValue.serverTimestamp(),
    });
    return true;
  });
}

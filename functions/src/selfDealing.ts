/**
 * 자기거래(self-dealing) 판정 — prelaunch_security_bundle spec "핵심 공통 개념".
 *
 * 신뢰원은 `stores/{id}.ownerId` / `.brandId` 하나뿐이다. 주문·카트의 brandId 는 클라이언트 값이라 쓰지 않는다.
 *   isSelfDealing(uid, store) = (store.ownerId == uid) OR (store.brandId 유효 AND buyer 가 그 brandId 의 보유자)
 *
 * Rules(firestore.rules)의 `isStoreOwner` / `isBrandHolder` 와 **같은 규칙의 TS 포팅**이다 (canSellNow 와 같은 패턴).
 * 브랜드 보유자 = `users/{uid}.role == 'brand' && users/{uid}.brandId == store.brandId` (공백 brandId 매칭 차단).
 * 규칙을 바꾸면 Rules 도 함께 바꾼다 (drift 주의).
 *
 * 한계: 같은 계정 경로만 막는다. 부계정은 못 막는다 — orderSignals(Layer2) 가 사후 탐지용 신호를 남긴다.
 *
 * 잠정(사용자 검토 대기): D-2 브랜드 보유자 포함.
 */

import * as admin from "firebase-admin";

export type SelfDealingMatch = "owner" | "brandHolder";

/** 매장 문서의 브랜드 ID. 비어있지 않은 문자열만 유효 (isBrandHolder 의 공백 매칭 차단과 같다). */
export function validBrandId(v: unknown): string | null {
  return typeof v === "string" && v.length > 0 ? v : null;
}

/** 순수 판정 — buyer 는 brandId 가 유효할 때만 필요하다. */
export function matchSelfDealing(
  uid: string,
  store: { ownerId?: unknown; brandId?: unknown },
  buyer?: { role?: unknown; brandId?: unknown } | null
): SelfDealingMatch | null {
  if (typeof store.ownerId === "string" && store.ownerId.length > 0 && store.ownerId === uid) return "owner";
  const brandId = validBrandId(store.brandId);
  if (brandId === null || !buyer) return null;
  return buyer.role === "brand" && buyer.brandId === brandId ? "brandHolder" : null;
}

/**
 * Firestore 포함 판정. `users/{uid}` 는 매장에 유효 brandId 가 있고 점주 일치가 아닐 때만 읽는다 (개인 매장은 추가 read 0).
 * 읽기 실패는 예외 — 호출자가 정책(거절 fail-closed / 트리거 재시도)을 정한다.
 */
export async function findSelfDealing(
  db: admin.firestore.Firestore,
  uid: string,
  store: { ownerId?: unknown; brandId?: unknown }
): Promise<SelfDealingMatch | null> {
  const byOwner = matchSelfDealing(uid, store, null);
  if (byOwner) return byOwner;
  if (validBrandId(store.brandId) === null) return null;
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists) return null;
  return matchSelfDealing(uid, store, snap.data() ?? null);
}

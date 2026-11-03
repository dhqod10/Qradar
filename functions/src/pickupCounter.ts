/**
 * 픽업 주문번호 발급 (order_pickup_number).
 *
 * 매장·일별(KST) 순번. 카운터 문서 `stores/{storeId}/pickupCounters/{yyyyMMdd}` 의 ID 가 KST 날짜라서
 * 날짜가 바뀌면 새 문서가 1부터 시작한다 (스케줄러 불필요). 클라이언트는 이 컬렉션을 읽지도 쓰지도 못한다 (Rules `if false`).
 *
 * 반드시 **트랜잭션 안에서** 호출한다. 읽기(`tx.get`) 후 `tx.set` 하므로, 같은 트랜잭션의 다른 읽기는 이 호출 **전**에 끝내야 한다
 * (Firestore 트랜잭션은 쓰기 이후 읽기 금지). 트랜잭션이 abort 되면 카운터도 증가하지 않는다 (오펀 번호 없음).
 */

import type * as admin from "firebase-admin";

const KST_OFFSET_MS = 9 * 60 * 60 * 1000;

/** 순간(Date)을 KST 달력 날짜 `yyyyMMdd` 로. 서버(UTC) 시계와 무관하게 Asia/Seoul 기준. */
export function kstDateKey(at: Date): string {
  const k = new Date(at.getTime() + KST_OFFSET_MS);
  const y = k.getUTCFullYear();
  const m = String(k.getUTCMonth() + 1).padStart(2, "0");
  const d = String(k.getUTCDate()).padStart(2, "0");
  return `${y}${m}${d}`;
}

/** 다음 번호 계산 (순수). current 가 없거나 유효한 양의 정수가 아니면 0 으로 보고 1 부터. */
export function nextPickupNumber(current: unknown): number {
  return typeof current === "number" && Number.isInteger(current) && current > 0 ? current + 1 : 1;
}

/**
 * 카운터를 읽어 +1 하고 카운터 문서를 set 한 뒤 발급 번호를 반환한다.
 * @param counterRef `stores/{storeId}/pickupCounters/{yyyyMMdd}` 참조
 */
export async function allocatePickupNumber(
  tx: admin.firestore.Transaction,
  counterRef: admin.firestore.DocumentReference,
  updatedAt: unknown
): Promise<number> {
  const snap = await tx.get(counterRef);
  const next = nextPickupNumber(snap.data()?.current);
  tx.set(counterRef, { current: next, updatedAt });
  return next;
}

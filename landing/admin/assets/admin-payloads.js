/* ============================================================================
   승인/반려 payload — Firebase SDK 를 import 하지 않는 순수 모듈 (node 로 검증 가능).

   필드 집합은 앱의 것을 **그대로 옮긴 것**이다. 값을 새로 정하지 않는다.
     - 매장 승인/반려 : lib/data/models/store_model.dart  StoreModel.approveFields / rejectFields
     - 브랜드 승인    : lib/data/repositories/brand_repository_impl.dart  approveBrand  (172-185)
     - 브랜드 반려    : lib/data/repositories/brand_repository_impl.dart  rejectBrand   (190-199)
   앱이 바뀌면 이 파일을 같이 고쳐야 한다 (두 곳이 갈라질 수 있다는 것이 Q1=B 의 알려진 비용).

   금지선 (firestore.rules touchesQoinManaged() — stores:338, brands:535 의 allow update 맨 앞):
     Qoin 관리 필드가 payload 에 하나라도 섞이면 admin 전권 분기까지 포함해 update 전체가 거부된다.
   매장 반려는 rejectedAt 에 쓴다. approvedAt 은 승인 행위에서만 쓴다 — 반려가 approvedAt 에 쓰면
   결제 게이트 canSellNow 의 승인 이력 판정이 오염된다 (payment_server_authority §6.8 / F-02).

   assertPayload 는 개발 중 실수를 즉시 터뜨리는 방어선이다. 보안 장치가 아니다 — 권위는 Rules 다.
   ========================================================================== */

/** firestore.rules qoinManagedFields() 와 같은 집합 (docs/processes/data_ownership.md §2.11.1). */
export const QOIN_MANAGED_FIELDS = Object.freeze([
  'qoinAccrualRate', 'qoinAccrualEnabled', 'qoinBulkHistoryId', 'qoinBulkStatus', 'qoinBulkAt',
]);

/** 액션별로 보낼 수 있는 키의 정확한 집합. 이 밖의 키는 거부한다. */
export const PAYLOAD_SHAPES = Object.freeze({
  brandApprove: ['status', 'approvedBy', 'approvedAt', 'rejectedReason', 'updatedAt'],
  brandReject:  ['status', 'approvedBy', 'rejectedReason', 'updatedAt'],
  storeApprove: ['status', 'approvedBy', 'approvedAt', 'rejectedReason', 'updatedAt'],
  storeReject:  ['status', 'approvedBy', 'rejectedAt', 'rejectedReason', 'updatedAt'],
});

function requireUid(uid) {
  if (typeof uid !== 'string' || uid.length === 0) throw new Error('approvedBy 는 로그인 uid 여야 해요');
  return uid;
}

function requireReason(reason) {
  const v = typeof reason === 'string' ? reason.trim() : '';
  if (v.length === 0) throw new Error('반려 사유가 비어 있어요');
  return v; // trim 한 값을 저장한다
}

/** @param ts  serverTimestamp 함수 (SDK 센티널 생성기). 순수성을 위해 주입받는다. */
export function brandApprovePayload(adminUid, ts) {
  return {
    status: 'approved',
    approvedBy: requireUid(adminUid),
    approvedAt: ts(),
    rejectedReason: null,
    updatedAt: ts(),
  };
}

export function brandRejectPayload(adminUid, reason, ts) {
  return {
    status: 'rejected',
    approvedBy: requireUid(adminUid), // 앱과 동일: 심사자 uid (필드명이 사실과 다르지만 앱 계약이다)
    rejectedReason: requireReason(reason),
    updatedAt: ts(),
  };
}

export function storeApprovePayload(adminUid, ts) {
  return {
    status: 'approved',
    approvedBy: requireUid(adminUid),
    approvedAt: ts(),
    rejectedReason: null,
    updatedAt: ts(),
  };
}

export function storeRejectPayload(adminUid, reason, ts) {
  return {
    status: 'rejected',
    approvedBy: requireUid(adminUid),
    rejectedAt: ts(),
    rejectedReason: requireReason(reason),
    updatedAt: ts(),
  };
}

/** 키 집합이 정확히 일치하고 Qoin 관리 필드가 없는지 확인한다. 어긋나면 throw. */
export function assertPayload(action, payload) {
  const shape = PAYLOAD_SHAPES[action];
  if (!shape) throw new Error(`알 수 없는 액션: ${action}`);
  const keys = Object.keys(payload);
  for (const k of keys) {
    if (QOIN_MANAGED_FIELDS.includes(k)) throw new Error(`Qoin 관리 필드는 보낼 수 없어요: ${k}`);
    if (!shape.includes(k)) throw new Error(`허용되지 않은 필드: ${k}`);
  }
  for (const k of shape) {
    if (!keys.includes(k)) throw new Error(`필수 필드 누락: ${k}`);
  }
  if (action === 'storeReject' && keys.includes('approvedAt')) {
    throw new Error('매장 반려는 approvedAt 에 쓰지 않아요');
  }
  return payload;
}

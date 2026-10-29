/* ============================================================================
   쓰기 payload 정의 + 가드 — Firebase SDK 를 import 하지 않는 순수 모듈 (node 로 검증 가능).

   필드 집합은 앱의 것을 **그대로 옮긴 것**이다. 값을 새로 정하지 않는다.
     - 매장 승인/반려 : lib/data/models/store_model.dart  StoreModel.approveFields / rejectFields
     - 브랜드 승인    : lib/data/repositories/brand_repository_impl.dart  approveBrand
     - 매장 운영/핵심 : StoreModel.toFirestoreForOperationUpdate / toFirestoreForCoreUpdate
     - 메뉴 / 오버라이드 : lib/data/models/{menu_item_model,menu_override_model}.dart 및 각 repository_impl
   앱이 바뀌면 이 파일을 같이 고쳐야 한다 (두 곳이 갈라질 수 있다는 것이 알려진 비용이다).

   [Rules 줄번호 = 데이터]
   각 액션의 `rules` 문자열은 근거가 되는 firestore.rules 줄번호(2026-10-29, 859줄 기준)다. 주석이 아니라 데이터로 둔다.
   Rules 가 바뀌면 이 문자열이 낡고, 그것이 재검토 신호다.

   [가드의 위치]
   assertPayload 는 개발 중 실수를 즉시 터뜨리는 방어선이다. **보안 장치가 아니다 — 권위는 Rules 다.**
   Rules 의 거부는 permission-denied 하나로 뭉쳐 와서 어떤 필드가 문제였는지 알려 주지 않는다.
   이 가드의 값은 "Rules 가 거부할 payload 를 전송 전에 알려 주는 것" 이다.

   [🔴 approvedAt]
   approvedAt / approvedBy / rejectedAt 는 권한 값이다 (결제 게이트 canSellNow 의 입력).
   이 파일에서 이 키를 쓰는 payload 는 admin 승인/반려와 owner.storeCoreResubmit(null 클리어) 둘뿐이다.
   ========================================================================== */

/** firestore.rules qoinManagedFields() 와 같은 집합 (rules:97-101, docs/processes/data_ownership.md §2.11.1). */
export const QOIN_MANAGED_FIELDS = Object.freeze([
  'qoinAccrualRate', 'qoinAccrualEnabled', 'qoinBulkHistoryId', 'qoinBulkStatus', 'qoinBulkAt',
]);

/**
 * 전역 금지 집합 — 액션과 무관하게 **항상** 검사한다 (spec §5.1 / §6.2).
 * Qoin 관리 5개 + CF 전담 파생 필드 + 권한 값. 콘솔의 어떤 payload 에도 넣지 않는다.
 *   availableMainCategories : onAvailableCategoriesWritten 계열 CF 전담 (stores create 금지 rules:352-353)
 *   averageScore/reviewCount: onReviewWritten CF 전담
 *   qoinBalance             : onOrderQoinSettled CF 전담
 *   brandKey                : issueBrandKey CF 전담 (private/profile 쓰기 금지 rules:621-626)
 *   role                    : 역할 부여/변경 UI 는 만들지 않는다 (spec §3-N3). users 문서는 이 콘솔이 쓰지 않는다.
 */
export const GLOBAL_FORBIDDEN = Object.freeze([
  ...QOIN_MANAGED_FIELDS,
  'availableMainCategories', 'averageScore', 'reviewCount', 'qoinBalance', 'brandKey', 'role',
]);

const APPROVAL_META = Object.freeze(['approvedBy', 'approvedAt', 'rejectedAt']);
const ISPENDING = ['status 는 pending 만', (p) => p.status === 'pending'];

/**
 * 액션별 shape.
 *   mode      'exact'  : allowed 의 키가 정확히 모두 있어야 한다 (Rules hasOnly / 키 누락이 조용한 데이터 결함이 되는 경우)
 *             'subset' : allowed 의 부분집합이면 된다 (Rules onlyChangedFields — 값이 바뀐 키만 센다)
 *   required  subset 모드에서도 반드시 있어야 하는 키
 *   forbidden 이 액션에서 특별히 금지하는 키 (allowed 에 없으면 어차피 거부되지만, 의도를 데이터로 남긴다)
 *   invariants [설명, fn(payload, ctx)] — 값 검사. false 면 throw
 */
function shape(o) {
  return Object.freeze({
    mode: o.mode || 'subset',
    allowed: Object.freeze([...o.allowed]),
    required: Object.freeze([...(o.required || [])]),
    forbidden: Object.freeze([...(o.forbidden || [])]),
    invariants: Object.freeze([...(o.invariants || [])]),
    rules: o.rules,
  });
}

/* ── 공통 키 묶음 ──────────────────────────────────────────────────────────── */
const MENU_CORE = ['name', 'description', 'mainCategory', 'subCategoryId', 'basePrice', 'optionGroupRefs', 'optionGroupRefIds'];
const MENU_OPS_MASTER = ['visible', 'tags', 'displayOrder', 'imageUrl', 'disabledOptionGroupIds', 'disabledOptionItemIds', 'updatedAt'];
const MENU_OPS_STORE = ['visible', 'soldOut', 'displayOrder', 'tags', 'imageUrl', 'disabledOptionGroupIds', 'disabledOptionItemIds', 'updatedAt'];
const MENU_CREATE_KEYS = [
  'name', 'imageUrl', 'description', 'mainCategory', 'subCategoryId', 'basePrice', 'optionGroupRefs', 'optionGroupRefIds',
  'soldOut', 'displayOrder', 'createdAt', 'scope', 'brandId', 'tags', 'visible', 'disabledOptionGroupIds',
  'disabledOptionItemIds', 'status', 'submittedBy', 'submittedAt', 'updatedAt',
];
const MENU_CREATE_REQUIRED = [
  'name', 'imageUrl', 'mainCategory', 'basePrice', 'optionGroupRefs', 'optionGroupRefIds', 'soldOut', 'displayOrder',
  'createdAt', 'scope', 'tags', 'visible', 'disabledOptionGroupIds', 'disabledOptionItemIds', 'updatedAt',
];
const SUBCAT_KEYS = ['mainCategory', 'name', 'displayOrder', 'active', 'scope', 'brandId', 'storeId', 'normalizedName', 'createdAt', 'updatedAt'];
const OPTGROUP_KEYS = ['name', 'selectionType', 'required', 'items', 'displayOrder', 'active', 'createdAt', 'updatedAt'];
const STORE_OPS_KEYS = ['phone', 'description', 'notice', 'excludedMainCategories', 'businessHours', 'temporaryClosed', 'closedDates', 'imageUrls', 'imageUrl', 'updatedAt'];
const PII_KEYS = ['businessRegistrationNumber', 'representativeName', 'contactName', 'contactPhone', 'headOfficeAddress'];

/** 액션 → shape. 키는 `<role>.<action>`. */
export const PAYLOAD_SHAPES = Object.freeze({
  /* ── admin (승인/반려 — exact: 필드가 승인 이력의 계약이다) ─────────────────── */
  'admin.brandApprove': shape({ mode: 'exact', allowed: ['status', 'approvedBy', 'approvedAt', 'rejectedReason', 'updatedAt'], rules: 'firestore.rules:570-572 (brands update, admin 전권 :571)' }),
  'admin.brandReject': shape({ mode: 'exact', allowed: ['status', 'approvedBy', 'rejectedReason', 'updatedAt'], rules: 'firestore.rules:570-572' }),
  'admin.storeApprove': shape({ mode: 'exact', allowed: ['status', 'approvedBy', 'approvedAt', 'rejectedReason', 'updatedAt'], rules: 'firestore.rules:363-366 (stores update, admin 전권)' }),
  'admin.storeReject': shape({ mode: 'exact', allowed: ['status', 'approvedBy', 'rejectedAt', 'rejectedReason', 'updatedAt'], forbidden: ['approvedAt'], rules: 'firestore.rules:363-366' }),

  /* ── brand ─────────────────────────────────────────────────────────────── */
  // 운영 폼: 로고·회사명만 (핵심 키·승인 메타 금지). W-B1
  'brand.brandOperation': shape({
    allowed: ['logoUrl', 'companyName', 'updatedAt'], required: ['updatedAt'],
    forbidden: ['name', 'description', 'status', 'submittedBy', 'submittedAt', 'rejectedReason', 'createdAt', ...APPROVAL_META],
    rules: 'firestore.rules:578-604 (isBrandSelfUpdate: onlyChangedFields, brandKey/approvedBy/approvedAt/createdAt 변경 금지)',
  }),
  // 핵심 폼: name/description 변경 + status pending 회귀. 승인 메타·brandKey·createdAt 은 보내지 않는다. W-B1
  'brand.brandCore': shape({
    allowed: ['name', 'description', 'status', 'submittedBy', 'submittedAt', 'rejectedReason', 'updatedAt'],
    required: ['status', 'submittedBy', 'submittedAt', 'updatedAt'],
    forbidden: ['logoUrl', 'companyName', 'createdAt', ...APPROVAL_META],
    invariants: [ISPENDING, ['submittedBy 는 본인 uid', (p, c) => typeof c.uid === 'string' && p.submittedBy === c.uid]],
    rules: 'firestore.rules:578-604 (status pending 만 :588-592, submittedBy 본인 uid 만 :596-599)',
  }),
  'brand.privateProfileUpdate': shape({
    allowed: PII_KEYS, rules: 'firestore.rules:624-626 (private/profile update: onlyChangedFields(PII 5개))',
  }),
  // Rules 는 hasOnly(5키) — 키 부분집합이면 통과한다 (spec 은 exact 로 적었으나 선택 필드를 생략할 수 있어야 한다)
  'brand.privateProfileCreate': shape({
    allowed: PII_KEYS, rules: 'firestore.rules:621-623 (private/profile create: keys().hasOnly(PII 5개))',
  }),
  'brand.masterMenuCreate': shape({
    allowed: MENU_CREATE_KEYS, required: MENU_CREATE_REQUIRED.concat(['brandId', 'status', 'submittedBy', 'submittedAt']),
    forbidden: [...APPROVAL_META, 'rejectedReason'],
    invariants: [ISPENDING, ['scope 는 brand', (p) => p.scope === 'brand'], ['brandId 는 내 브랜드', (p, c) => !!c.brandId && p.brandId === c.brandId]],
    rules: 'firestore.rules:640 (brands/menuItems create: isBrandHolder && noSelfApproveOnCreate :73-77)',
  }),
  'brand.masterMenuCore': shape({
    allowed: [...MENU_CORE, 'status', 'submittedBy', 'submittedAt', 'rejectedReason', 'updatedAt'],
    required: ['status', 'submittedBy', 'submittedAt', 'updatedAt'],
    forbidden: ['createdAt', 'visible', 'tags', 'displayOrder', 'imageUrl', 'soldOut', ...APPROVAL_META],
    invariants: [ISPENDING],
    rules: 'firestore.rules:641 (update: isBrandHolder && noSelfApproveOnUpdate :82-90). approvedBy/approvedAt 는 보존 — "수정 대기" 판정에 쓰인다',
  }),
  'brand.masterMenuOperation': shape({
    allowed: MENU_OPS_MASTER, required: ['updatedAt'],
    forbidden: [...MENU_CORE, 'status', 'submittedBy', 'submittedAt', 'createdAt', 'soldOut', ...APPROVAL_META],
    rules: 'firestore.rules:641 (status/승인 메타 무변경 → noSelfApproveOnUpdate 통과)',
  }),
  // 가격 오버라이드 제출. 승인 메타·soldOut·disabledOption* 은 update 에서 보내지 않아 보존된다.
  'brand.overrideSubmitUpdate': shape({
    allowed: ['priceOverride', 'excluded', 'status', 'submittedBy', 'submittedAt', 'rejectedReason', 'updatedBy', 'updatedAt'],
    required: ['excluded', 'status', 'submittedBy', 'submittedAt', 'rejectedReason', 'updatedBy', 'updatedAt'],
    forbidden: ['soldOut', 'disabledOptionGroupIds', 'disabledOptionItemIds', ...APPROVAL_META],
    invariants: [ISPENDING, ['updatedBy 는 brand', (p) => p.updatedBy === 'brand']],
    rules: 'firestore.rules:522-526 (menuOverrides update: isBrandHolder && noSelfApproveOnUpdate)',
  }),
  'brand.overrideSubmitCreate': shape({
    allowed: ['masterMenuItemId', 'storeId', 'brandId', 'priceOverride', 'excluded', 'soldOut', 'disabledOptionGroupIds', 'disabledOptionItemIds', 'status', 'submittedBy', 'submittedAt', 'updatedBy', 'updatedAt'],
    required: ['masterMenuItemId', 'storeId', 'brandId', 'excluded', 'soldOut', 'disabledOptionGroupIds', 'disabledOptionItemIds', 'status', 'submittedBy', 'submittedAt', 'updatedBy', 'updatedAt'],
    forbidden: [...APPROVAL_META],
    invariants: [ISPENDING, ['updatedBy 는 brand', (p) => p.updatedBy === 'brand']],
    rules: 'firestore.rules:518-521 (menuOverrides create: isBrandHolder && noSelfApproveOnCreate)',
  }),
  'brand.storeOnlyMenuCreate': shape({
    allowed: MENU_CREATE_KEYS, required: MENU_CREATE_REQUIRED.concat(['brandId', 'status', 'submittedBy', 'submittedAt']),
    forbidden: [...APPROVAL_META, 'rejectedReason'],
    invariants: [ISPENDING, ['scope 는 store', (p) => p.scope === 'store']],
    rules: 'firestore.rules:483-486 (stores/menuItems create: 브랜드 분기 noSelfApproveOnCreate)',
  }),
  'brand.storeOnlyMenuCore': shape({
    allowed: [...MENU_CORE, 'status', 'submittedBy', 'submittedAt', 'rejectedReason', 'updatedAt'],
    required: ['status', 'submittedBy', 'submittedAt', 'updatedAt'],
    forbidden: ['createdAt', 'visible', 'tags', 'displayOrder', 'imageUrl', 'soldOut', ...APPROVAL_META],
    invariants: [ISPENDING],
    rules: 'firestore.rules:487-490 (update: 브랜드 분기 noSelfApproveOnUpdate)',
  }),
  'brand.storeOnlyMenuOperation': shape({
    allowed: MENU_OPS_STORE, required: ['updatedAt'],
    forbidden: [...MENU_CORE, 'status', 'submittedBy', 'submittedAt', 'createdAt', ...APPROVAL_META],
    rules: 'firestore.rules:487-490',
  }),
  'brand.subCategory': shape({ allowed: SUBCAT_KEYS, required: ['mainCategory', 'name', 'displayOrder', 'active', 'scope', 'brandId', 'normalizedName', 'updatedAt'], invariants: [['scope 는 brand', (p) => p.scope === 'brand']], rules: 'firestore.rules:646-651 (brands/subCategories: isAdmin || isBrandHolder)' }),
  'brand.optionGroup': shape({ allowed: OPTGROUP_KEYS, required: ['name', 'selectionType', 'required', 'items', 'displayOrder', 'active', 'updatedAt'], forbidden: ['scope', 'brandId'], invariants: [['브랜드 selectionType 은 single|multi', (p) => p.selectionType === 'single' || p.selectionType === 'multi']], rules: 'firestore.rules:653-658 (brands/optionGroups)' }),
  'brand.activeToggle': shape({ mode: 'exact', allowed: ['active', 'updatedAt'], rules: 'firestore.rules:646-658' }),

  /* ── owner ─────────────────────────────────────────────────────────────── */
  // 운영 폼 (W-O14): status 회귀 없음. 핵심 키·승인 메타 금지.
  'owner.storeOperation': shape({
    allowed: STORE_OPS_KEYS, required: ['updatedAt'],
    forbidden: ['name', 'address', 'location', 'menuCategories', 'businessRegistrationNumber', 'status', 'submittedBy', 'submittedAt', 'ownerId', 'brandId', 'createdAt', ...APPROVAL_META, 'rejectedReason'],
    rules: 'firestore.rules:386-421 (isStoreOwnerFieldUpdate 화이트리스트)',
  }),
  // 핵심 폼 (W-O15): status pending 회귀. 승인 메타는 넣지 않는다 — 🔴 approvedAt 을 건드리면 canSellNow 가 흔들린다.
  'owner.storeCore': shape({
    allowed: ['name', 'businessRegistrationNumber', 'status', 'submittedBy', 'submittedAt', 'updatedAt'],
    required: ['status', 'submittedBy', 'submittedAt', 'updatedAt'],
    forbidden: [...STORE_OPS_KEYS.filter((k) => k !== 'updatedAt'), 'address', 'location', 'menuCategories', 'ownerId', 'brandId', 'createdAt', ...APPROVAL_META, 'rejectedReason'],
    invariants: [ISPENDING, ['submittedBy 는 본인 uid', (p, c) => typeof c.uid === 'string' && p.submittedBy === c.uid]],
    rules: 'firestore.rules:386-421 (status pending 만 :402-406, 승인 메타 null 클리어만 :407-420)',
  }),
  // 🔴 rejected 매장 전용. 서버 재읽기로 rejected 를 확인한 경우에만 만든다 (console-data.js submitStoreCore 트랜잭션).
  'owner.storeCoreResubmit': shape({
    mode: 'exact',
    allowed: ['name', 'businessRegistrationNumber', 'status', 'submittedBy', 'submittedAt', 'updatedAt', 'approvedBy', 'approvedAt', 'rejectedAt', 'rejectedReason'],
    invariants: [
      ISPENDING,
      ['승인 메타는 null 클리어만', (p) => p.approvedBy === null && p.approvedAt === null && p.rejectedAt === null && p.rejectedReason === null],
      ['submittedBy 는 본인 uid', (p, c) => typeof c.uid === 'string' && p.submittedBy === c.uid],
    ],
    rules: 'firestore.rules:373-380 (leavingRejectedClearsApproval) + :386-421',
  }),
  'owner.personalMenuCreate': shape({
    allowed: MENU_CREATE_KEYS.filter((k) => !['brandId', 'submittedBy', 'submittedAt'].includes(k)).concat(['status']),
    required: MENU_CREATE_REQUIRED.concat(['status']),
    forbidden: ['brandId', 'submittedBy', 'submittedAt', ...APPROVAL_META, 'rejectedReason'],
    invariants: [['개인 매장 메뉴는 scope store / status approved', (p) => p.scope === 'store' && p.status === 'approved']],
    rules: 'firestore.rules:483-486 (stores/menuItems create: isStoreOwner — 필드 제한 없음)',
  }),
  // W-O2: 앱은 createdAt 을 넣어 매 수정마다 리셋한다 (§11.3-ⓒ). 콘솔은 넣지 않는다.
  'owner.personalMenuUpdate': shape({
    allowed: [...MENU_CORE, 'imageUrl', 'tags', 'visible', 'soldOut', 'displayOrder', 'disabledOptionGroupIds', 'disabledOptionItemIds', 'updatedAt'],
    required: ['updatedAt'],
    forbidden: ['createdAt', 'scope', 'brandId', 'status', 'submittedBy', 'submittedAt', ...APPROVAL_META],
    rules: 'firestore.rules:487-490',
  }),
  // W-O3: 노출/품절 토글은 이 8키 경로 (앱처럼 핵심 전체 update 를 쏘지 않는다 — §11.3-ⓔ)
  'owner.personalMenuOperation': shape({
    allowed: MENU_OPS_STORE, required: ['updatedAt'],
    forbidden: [...MENU_CORE, 'createdAt', 'status', 'scope', 'brandId'],
    rules: 'firestore.rules:487-490',
  }),
  // W-O5: 품절 토글은 3키만. disabledOption* 을 같이 보내면 옵션 비활성 설정이 덮여 지워진다 (앱 결함 §11.3-ⓐ).
  'owner.overrideSoldOut': shape({
    mode: 'exact', allowed: ['soldOut', 'updatedBy', 'updatedAt'],
    forbidden: ['disabledOptionGroupIds', 'disabledOptionItemIds'],
    invariants: [['soldOut 은 boolean', (p) => typeof p.soldOut === 'boolean'], ['updatedBy 는 owner', (p) => p.updatedBy === 'owner']],
    rules: 'firestore.rules:522-526 (점주 분기 onlyChangedFields 5키)',
  }),
  // W-O6: 4키. disabledOptionItemIds 원소는 복합 id `{groupId}_{itemId}`.
  'owner.overrideOptionDisable': shape({
    mode: 'exact', allowed: ['disabledOptionGroupIds', 'disabledOptionItemIds', 'updatedBy', 'updatedAt'],
    forbidden: ['soldOut'],
    invariants: [['updatedBy 는 owner', (p) => p.updatedBy === 'owner']],
    rules: 'firestore.rules:522-526',
  }),
  // W-O7: 16키 정확 일치. masterMenuItemId 누락은 Rules 거부가 아니라 조용한 데이터 결함(cascade 누락)이다. (Q2)
  'owner.overrideCreate': shape({
    mode: 'exact',
    allowed: ['masterMenuItemId', 'storeId', 'brandId', 'priceOverride', 'excluded', 'soldOut', 'disabledOptionGroupIds', 'disabledOptionItemIds', 'status', 'submittedBy', 'submittedAt', 'approvedBy', 'approvedAt', 'rejectedReason', 'updatedBy', 'updatedAt'],
    invariants: [
      ['status approved 는 priceOverride null + excluded false 일 때만 (ownerOverrideCreateOk)', (p) => p.status !== 'approved' || (p.priceOverride === null && p.excluded === false)],
      ['approvedBy/approvedAt 은 null', (p) => p.approvedBy === null && p.approvedAt === null],
      ['updatedBy 는 owner', (p) => p.updatedBy === 'owner'],
    ],
    rules: 'firestore.rules:518-521 (create: isStoreOwner && ownerOverrideCreateOk :506-513)',
  }),
  'owner.subCategory': shape({ allowed: SUBCAT_KEYS, required: ['mainCategory', 'name', 'displayOrder', 'active', 'scope', 'storeId', 'normalizedName', 'updatedAt'], invariants: [['scope 는 store', (p) => p.scope === 'store']], rules: 'firestore.rules:470-478 (stores/subCategories: isStoreOwner)' }),
  'owner.optionGroup': shape({ allowed: OPTGROUP_KEYS, required: ['name', 'selectionType', 'required', 'items', 'displayOrder', 'active', 'updatedAt'], forbidden: ['scope', 'storeId'], invariants: [['selectionType 은 single|multi (서버 optionPricing.ts 는 multi 외를 single 로 읽는다 — spec 의 multiple 은 오기)', (p) => p.selectionType === 'single' || p.selectionType === 'multi']], rules: 'firestore.rules:534-540 (stores/optionGroups)' }),
  'owner.activeToggle': shape({ mode: 'exact', allowed: ['active', 'updatedAt'], rules: 'firestore.rules:470-540' }),
});

/** 이전 이름(역할 접두 없는 admin 액션) 호환. */
const LEGACY = Object.freeze({
  brandApprove: 'admin.brandApprove', brandReject: 'admin.brandReject',
  storeApprove: 'admin.storeApprove', storeReject: 'admin.storeReject',
});

/**
 * payload 검사. 어긋나면 throw. 통과하면 payload 를 그대로 돌려준다.
 * @param {string} action  `<role>.<action>`
 * @param {object} payload
 * @param {object} [ctx]   { uid, brandId } — invariants 가 본인 uid 등을 검사할 때 쓴다
 */
export function assertPayload(action, payload, ctx = {}) {
  const name = LEGACY[action] || action;
  const sh = PAYLOAD_SHAPES[name];
  if (!sh) throw new Error(`알 수 없는 액션: ${action}`);
  if (payload === null || typeof payload !== 'object' || Array.isArray(payload)) throw new Error('payload 는 객체여야 해요');
  const keys = Object.keys(payload);
  if (keys.length === 0) throw new Error('빈 payload 는 보낼 수 없어요');
  for (const k of keys) {
    if (GLOBAL_FORBIDDEN.includes(k)) throw new Error(`전역 금지 필드는 보낼 수 없어요: ${k}`);
    if (sh.forbidden.includes(k)) throw new Error(`이 액션에서 금지된 필드: ${k} (${name})`);
    if (!sh.allowed.includes(k)) throw new Error(`허용되지 않은 필드: ${k} (${name})`);
    if (payload[k] === undefined) throw new Error(`undefined 값은 보낼 수 없어요: ${k}`);
  }
  if (sh.mode === 'exact') {
    for (const k of sh.allowed) if (!keys.includes(k)) throw new Error(`필수 필드 누락: ${k} (${name})`);
  }
  for (const k of sh.required) if (!keys.includes(k)) throw new Error(`필수 필드 누락: ${k} (${name})`);
  if (name === 'admin.storeReject' && keys.includes('approvedAt')) throw new Error('매장 반려는 approvedAt 에 쓰지 않아요');
  for (const [desc, fn] of sh.invariants) {
    if (!fn(payload, ctx)) throw new Error(`불변식 위반: ${desc} (${name})`);
  }
  return payload;
}

/* ============================================================================
   빌더 — sdk = { ts: serverTimestamp 함수, del: deleteField 함수 } 를 주입받는다 (순수성).
   ========================================================================== */

function requireUid(uid) {
  if (typeof uid !== 'string' || uid.length === 0) throw new Error('uid 가 필요해요');
  return uid;
}

function requireReason(reason) {
  const v = typeof reason === 'string' ? reason.trim() : '';
  if (v.length === 0) throw new Error('반려 사유가 비어 있어요');
  return v;
}

/** 값이 null/'' 이면 필드 삭제, 아니면 trim 한 문자열. */
const strOrDel = (v, del) => (typeof v === 'string' && v.trim() !== '' ? v.trim() : del());

/* ── admin (이관 — 기능 변경 없음) ────────────────────────────────────────── */
export function brandApprovePayload(adminUid, ts) {
  return { status: 'approved', approvedBy: requireUid(adminUid), approvedAt: ts(), rejectedReason: null, updatedAt: ts() };
}
export function brandRejectPayload(adminUid, reason, ts) {
  // 앱과 동일: 심사자 uid (필드명이 사실과 다르지만 앱 계약이다)
  return { status: 'rejected', approvedBy: requireUid(adminUid), rejectedReason: requireReason(reason), updatedAt: ts() };
}
export function storeApprovePayload(adminUid, ts) {
  return { status: 'approved', approvedBy: requireUid(adminUid), approvedAt: ts(), rejectedReason: null, updatedAt: ts() };
}
export function storeRejectPayload(adminUid, reason, ts) {
  return { status: 'rejected', approvedBy: requireUid(adminUid), rejectedAt: ts(), rejectedReason: requireReason(reason), updatedAt: ts() };
}

/* ── brand ────────────────────────────────────────────────────────────────── */
/** @param {{logoUrl?:string, companyName?:string}} changes 바뀐 키만 */
export function brandOperationPayload(changes, { ts }) {
  const out = {};
  if ('logoUrl' in changes) out.logoUrl = changes.logoUrl;
  if ('companyName' in changes) out.companyName = (changes.companyName || '').trim();
  out.updatedAt = ts();
  return out;
}

/** @param {{name?:string, description?:string|null}} changes 바뀐 키만. 승인 메타·brandKey·createdAt 은 보내지 않는다. */
export function brandCorePayload(changes, uid, { ts, del }) {
  const out = {};
  if ('name' in changes) out.name = (changes.name || '').trim();
  if ('description' in changes) out.description = strOrDel(changes.description, del);
  out.status = 'pending';
  out.submittedBy = requireUid(uid);
  out.submittedAt = ts();
  out.rejectedReason = null; // 재제출 — 이전 반려 사유를 남기지 않는다 (merge 로 남는 앱 동작을 복제하지 않는다)
  out.updatedAt = ts();
  return out;
}

/** 선택 필드(headOfficeAddress / representativeName)를 비우면 필드 삭제. 필수 3개는 문자열 그대로. */
export function privateProfilePayload(changes, { del }) {
  const out = {};
  for (const k of PII_KEYS) {
    if (!(k in changes)) continue;
    const v = changes[k];
    const optional = k === 'headOfficeAddress' || k === 'representativeName';
    out[k] = optional ? strOrDel(v, del) : (v || '').trim();
  }
  return out;
}

/**
 * 메뉴 입력 → Firestore 맵 (핵심 필드). 마스터/점포 한정/개인 공통.
 * 엔티티명 mainCategoryCode → Firestore 키는 mainCategory (키 함정). optionGroupRefs 와 optionGroupRefIds 를 둘 다 쓴다.
 */
function menuCoreFields(f, { del }, onlyKeys) {
  const out = {};
  const want = (k) => !onlyKeys || onlyKeys.includes(k);
  if (want('name')) out.name = (f.name || '').trim();
  if (want('description')) out.description = strOrDel(f.description, del);
  if (want('mainCategory')) out.mainCategory = f.mainCategory;
  if (want('subCategoryId')) out.subCategoryId = f.subCategoryId ? f.subCategoryId : del();
  if (want('basePrice')) out.basePrice = f.basePrice;
  if (want('optionGroupRefs')) {
    out.optionGroupRefs = (f.optionGroupRefs || []).map((r) => ({ scope: r.scope, id: r.id }));
    out.optionGroupRefIds = out.optionGroupRefs.map((r) => r.id).filter((id) => id);
  }
  return out;
}

/**
 * 메뉴 등록 payload (create). scope: 'brand'(마스터) | 'store'(점포 한정 또는 개인).
 * @param {object} f   { name, imageUrl, description, mainCategory, subCategoryId, basePrice, optionGroupRefs, displayOrder, tags, visible, disabledOptionGroupIds, disabledOptionItemIds }
 * @param {object} c   { scope, brandId?, uid, status:'pending'|'approved' }
 */
export function menuCreatePayload(f, c, sdk) {
  const { ts } = sdk;
  const core = menuCoreFields(f, sdk);
  const desc = typeof f.description === 'string' ? f.description.trim() : '';
  const out = {
    name: core.name, imageUrl: f.imageUrl || '',
    ...(desc !== '' ? { description: desc } : {}),
    mainCategory: core.mainCategory,
    ...(f.subCategoryId ? { subCategoryId: f.subCategoryId } : {}),
    basePrice: core.basePrice, optionGroupRefs: core.optionGroupRefs, optionGroupRefIds: core.optionGroupRefIds,
    soldOut: !!f.soldOut, displayOrder: f.displayOrder || 0, createdAt: ts(), scope: c.scope,
    tags: f.tags || [], visible: f.visible !== false,
    disabledOptionGroupIds: f.disabledOptionGroupIds || [], disabledOptionItemIds: f.disabledOptionItemIds || [],
    status: c.status, updatedAt: ts(),
  };
  if (c.brandId) out.brandId = c.brandId;
  if (c.status === 'pending') { out.submittedBy = requireUid(c.uid); out.submittedAt = ts(); }
  return out;
}

/** 마스터/점포 한정 핵심 수정 (pending 회귀). 바뀐 핵심 키만 + status/submittedBy/submittedAt. 승인 메타·createdAt 은 보내지 않는다. */
export function menuCorePayload(changed, uid, sdk) {
  const keys = [];
  for (const k of ['name', 'description', 'mainCategory', 'subCategoryId', 'basePrice']) if (k in changed) keys.push(k);
  if ('optionGroupRefs' in changed) keys.push('optionGroupRefs');
  const out = menuCoreFields(changed, sdk, keys);
  out.status = 'pending';
  out.submittedBy = requireUid(uid);
  out.submittedAt = sdk.ts();
  out.rejectedReason = null;
  out.updatedAt = sdk.ts();
  return out;
}

/** 개인 매장 메뉴 수정 — approved 유지, 바뀐 키만 + updatedAt. createdAt 금지 (W-O2). */
export function personalMenuUpdatePayload(changed, sdk) {
  const out = {};
  const coreKeys = [];
  for (const k of ['name', 'description', 'mainCategory', 'subCategoryId', 'basePrice']) if (k in changed) coreKeys.push(k);
  if ('optionGroupRefs' in changed) coreKeys.push('optionGroupRefs');
  Object.assign(out, menuCoreFields(changed, sdk, coreKeys));
  for (const k of ['imageUrl', 'tags', 'visible', 'soldOut', 'displayOrder', 'disabledOptionGroupIds', 'disabledOptionItemIds']) if (k in changed) out[k] = changed[k];
  out.updatedAt = sdk.ts();
  return out;
}

/** 운영 수정 (마스터 5 + disabledOption* / 점포 한정·개인 8). 바뀐 키만. */
export function menuOperationPayload(changed, { ts }, keyset) {
  const out = {};
  for (const k of keyset) if (k !== 'updatedAt' && k in changed) out[k] = changed[k];
  out.updatedAt = ts();
  return out;
}
export const MASTER_OPS_KEYS = MENU_OPS_MASTER;
export const STORE_MENU_OPS_KEYS = MENU_OPS_STORE;

/** 가격 오버라이드 제출 — 기존 문서 update. priceOverride 가 비면 필드 삭제 (마스터 가격 사용). soldOut, disabledOption 계열, 승인 메타는 보내지 않아 보존된다. */
export function overrideSubmitUpdatePayload({ priceOverride, excluded }, uid, { ts, del }) {
  const out = {};
  if (priceOverride === null || priceOverride === undefined) out.priceOverride = del(); else out.priceOverride = priceOverride;
  out.excluded = !!excluded;
  out.status = 'pending';
  out.submittedBy = requireUid(uid);
  out.submittedAt = ts();
  out.rejectedReason = null; // set(merge) 라 이전 반려 사유가 남는 앱 동작을 복제하지 않는다
  out.updatedBy = 'brand';
  out.updatedAt = ts();
  return out;
}

/** 가격 오버라이드 제출 — 문서 부재(not-found) 시 create. 키 masterMenuItemId 는 문서 ID 와 같은 값을 필드로도 둔다. */
export function overrideSubmitCreatePayload({ masterMenuItemId, storeId, brandId, priceOverride, excluded }, uid, { ts }) {
  const out = {
    masterMenuItemId, storeId, brandId,
    excluded: !!excluded, soldOut: false, disabledOptionGroupIds: [], disabledOptionItemIds: [],
    status: 'pending', submittedBy: requireUid(uid), submittedAt: ts(), updatedBy: 'brand', updatedAt: ts(),
  };
  if (priceOverride !== null && priceOverride !== undefined) out.priceOverride = priceOverride;
  return out;
}

/* ── owner ────────────────────────────────────────────────────────────────── */
/**
 * 매장 운영 정보 — 바뀐 키만 + updatedAt (DV-12). imageUrl 은 imageUrls 가 바뀔 때만 함께.
 * @param {object} changes  { phone?, description?, notice?, excludedMainCategories?, businessHours?|null, temporaryClosed?, closedDates?(Date[]), imageUrls? }
 * @param {object} sdk      { ts, del, toTs(Date) }
 */
export function storeOperationPayload(changes, { ts, del, toTs }, fallbackImageUrl = '') {
  const out = {};
  if ('phone' in changes) out.phone = (changes.phone || '').trim();
  if ('description' in changes) out.description = strOrDel(changes.description, del);
  if ('notice' in changes) out.notice = strOrDel(changes.notice, del);
  if ('excludedMainCategories' in changes) out.excludedMainCategories = changes.excludedMainCategories;
  if ('businessHours' in changes) {
    const h = changes.businessHours;
    out.businessHours = h ? { openTime: h.openTime, closeTime: h.closeTime, closedDays: h.closedDays || [] } : del();
  }
  if ('temporaryClosed' in changes) out.temporaryClosed = !!changes.temporaryClosed;
  if ('closedDates' in changes) out.closedDates = changes.closedDates.map((d) => toTs(d));
  if ('imageUrls' in changes) {
    out.imageUrls = changes.imageUrls;
    out.imageUrl = changes.imageUrls.length > 0 ? changes.imageUrls[0] : fallbackImageUrl;
  }
  out.updatedAt = ts();
  return out;
}

/**
 * 매장 핵심 정보. `resubmit` 은 **서버에서 다시 읽은 status === 'rejected'** 일 때만 true 여야 한다 (DV-5).
 * @returns {{action:string, payload:object}}
 */
export function storeCorePayload(changes, uid, { ts }, { resubmit = false } = {}) {
  const out = {};
  if ('name' in changes) out.name = (changes.name || '').trim();
  if ('businessRegistrationNumber' in changes) {
    const v = (changes.businessRegistrationNumber || '').trim();
    out.businessRegistrationNumber = v === '' ? null : v; // 앱과 동일: 비우면 null
  }
  out.status = 'pending';
  out.submittedBy = requireUid(uid);
  out.submittedAt = ts();
  out.updatedAt = ts();
  if (resubmit) {
    // exact 모드라 name / businessRegistrationNumber 도 있어야 한다 — 호출자가 현재 값을 채워 넘긴다.
    out.approvedBy = null; out.approvedAt = null; out.rejectedAt = null; out.rejectedReason = null;
    return { action: 'owner.storeCoreResubmit', payload: out };
  }
  return { action: 'owner.storeCore', payload: out };
}

export const overrideSoldOutPayload = (soldOut, { ts }) => ({ soldOut: !!soldOut, updatedBy: 'owner', updatedAt: ts() });

/** disabledOptionItemIds 원소는 복합 id `{groupId}_{itemId}` — 호출자가 만들어 넘긴다. */
export const overrideOptionDisablePayload = (groupIds, itemIds, { ts }) =>
  ({ disabledOptionGroupIds: [...groupIds], disabledOptionItemIds: [...itemIds], updatedBy: 'owner', updatedAt: ts() });

export function overrideCreatePayload({ masterMenuItemId, storeId, brandId, soldOut = false, disabledOptionGroupIds = [], disabledOptionItemIds = [] }, uid, { ts }) {
  return {
    masterMenuItemId, storeId, brandId, priceOverride: null, excluded: false, soldOut,
    disabledOptionGroupIds, disabledOptionItemIds, status: 'approved',
    submittedBy: requireUid(uid), submittedAt: ts(), approvedBy: null, approvedAt: null, rejectedReason: null,
    updatedBy: 'owner', updatedAt: ts(),
  };
}

/* ── 서브 카테고리 / 옵션 그룹 (brand · owner 공통 모양) ───────────────────── */
export function subCategoryPayload(f, c, { ts }) {
  const out = {
    mainCategory: f.mainCategory, name: (f.name || '').trim(), displayOrder: f.displayOrder || 0, active: f.active !== false,
    scope: c.scope, normalizedName: (f.name || '').trim().toLowerCase(), updatedAt: ts(),
  };
  if (c.scope === 'brand') out.brandId = c.brandId; else out.storeId = c.storeId;
  if (c.isNew) out.createdAt = ts();
  return out;
}

/** 옵션 그룹. scope/brandId 는 문서에 저장하지 않는다 (경로가 scope). */
export function optionGroupPayload(f, c, { ts }) {
  const out = {
    name: (f.name || '').trim(), selectionType: f.selectionType, required: !!f.required,
    items: (f.items || []).map((i) => ({ id: i.id, label: (i.label || '').trim(), priceDelta: i.priceDelta || 0 })),
    displayOrder: f.displayOrder || 0, active: f.active !== false, updatedAt: ts(),
  };
  if (c.isNew) out.createdAt = ts();
  return out;
}

export const activeTogglePayload = (active, { ts }) => ({ active: !!active, updatedAt: ts() });

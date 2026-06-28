# spec.md — security_rules_drift_fix

## 발견된 drift

### 1. brands `isBrandSelfUpdate` — 필드 화이트리스트 불일치

`BrandRepositoryImpl.upsertBrand` 의 기존 brand 수정 분기는 핵심 필드(name/description) 변경 시
`BrandModel.toFirestore()` 전체를 `_dataSource.set()` 으로 전송한다.

전송되는 필드 중 기존 `onlyChangedFields` 화이트리스트에 누락된 것:
- 승인 메타 회귀: `status` (→ pending), `submittedBy`, `submittedAt`, `rejectedReason`
- BrandEntity 추가 필드: `companyName`, `businessRegistrationNumber`, `contactName`, `contactPhone`, `headOfficeAddress`, `representativeName`

결과: brand 본인이 name/description 등 핵심 필드를 수정하면 Rules 거부 → silent fail.

### 2. stores `isStoreOwnerFieldUpdate` / `isStoreOwnerBrandUpdate` — 동일 패턴

`StoreRepositoryImpl.updateStoreCoreFields` → `StoreModel.toFirestoreForCoreUpdate()` 가 전송하는 필드:
- `name`, `address`, `location`, `menuCategories`, `businessRegistrationNumber`
- `status` (→ pending), `submittedBy`, `submittedAt`, `updatedAt`
- 재제출(T3) 시: `approvedBy`, `approvedAt`, `rejectedReason` (null 클리어)

기존 화이트리스트에 누락된 것: `status`, `submittedBy`, `submittedAt`, `businessRegistrationNumber`,
`approvedBy`, `approvedAt`, `rejectedReason`

결과: 점주가 매장 핵심 필드 수정 시 Rules 거부 → silent fail.

## 수정 목표

1. 화이트리스트에 실제 전송 필드를 모두 추가.
2. 보안 강화: 자기 승격 차단(`status` → `'pending'` 만 허용).
3. 보안 강화: `brandKey` / `approvedBy` / `approvedAt` / `createdAt` / `ownerId` / `brandId` 등
   immutable 또는 admin-only 필드는 명시적 차단.

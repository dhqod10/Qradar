# implementation.md — security_rules_drift_fix

## 수정 파일

- `firestore.rules`

## 수정 내용

### A. `isBrandSelfUpdate` (brands/{brandId} update 분기)

**수정 전 화이트리스트:**
```
['name', 'imageUrl', 'description', 'phone', 'address',
 'businessHours', 'updatedAt', 'tags', 'logoUrl']
```

**수정 후 화이트리스트:**
```
['name', 'logoUrl', 'description', 'phone', 'address',
 'businessHours', 'updatedAt', 'tags',
 'status', 'submittedBy', 'submittedAt', 'rejectedReason',
 'companyName', 'businessRegistrationNumber',
 'contactName', 'contactPhone', 'headOfficeAddress', 'representativeName']
```

**추가된 보안 조건:**
1. status 자기 승격 차단: `status` 변경 시 `'pending'` 만 허용.
2. immutable 필드 명시적 차단: `brandKey`, `approvedBy`, `approvedAt`, `createdAt` 변경 불가.

### B. `isStoreOwnerFieldUpdate` (stores/{storeId} 점주 update 분기)

**수정 전 화이트리스트:**
```
['name', 'imageUrl', 'location', 'phone', 'address',
 'description', 'menuCategories', 'businessHours',
 'isOpen', 'updatedAt', 'notice', 'tags']
```

**수정 후 화이트리스트:**
```
['name', 'imageUrl', 'location', 'phone', 'address',
 'description', 'menuCategories', 'businessHours',
 'isOpen', 'updatedAt', 'notice', 'tags',
 'temporaryClosed', 'closedDates', 'imageUrls',
 'status', 'submittedBy', 'submittedAt',
 'businessRegistrationNumber',
 'approvedBy', 'approvedAt', 'rejectedReason']
```

**추가된 보안 조건:**
1. status 자기 승격 차단: `status` 변경 시 `'pending'` 만 허용.
2. `approvedBy` / `approvedAt` 는 null 클리어(T3 재제출)만 허용, 값 직접 설정 불가.

### C. `isStoreOwnerBrandUpdate` (stores/{storeId} brand holder update 분기)

`isStoreOwnerFieldUpdate` 와 동일한 화이트리스트 + 동일한 보안 조건 적용.

---

## 검증 시나리오

| 시나리오 | 예상 결과 | Rules 분기 |
|---|---|---|
| brand 본인이 logoUrl 만 수정 | 통과 | `isBrandSelfUpdate` |
| brand 본인이 name 수정 (status=pending 회귀 포함) | 통과 | `isBrandSelfUpdate` |
| brand 본인이 companyName 수정 | 통과 | `isBrandSelfUpdate` |
| brand 본인이 status='approved' 로 set 시도 | 거부 | status 승격 차단 조건 |
| brand 본인이 brandKey 수정 시도 | 거부 | immutable 필드 차단 |
| brand 본인이 approvedBy 수정 시도 | 거부 | immutable 필드 차단 |
| owner 본인이 매장 핵심 필드 수정 (status=pending 회귀 포함) | 통과 | `isStoreOwnerFieldUpdate` |
| owner 본인이 businessRegistrationNumber 수정 | 통과 | `isStoreOwnerFieldUpdate` |
| owner 본인이 T3 재제출 (approvedBy=null 클리어) | 통과 | `isStoreOwnerFieldUpdate` |
| owner 본인이 status='approved' 로 set 시도 | 거부 | status 승격 차단 조건 |
| owner 본인이 ownerId 수정 시도 | 거부 | 화이트리스트 미포함 |
| brand holder 가 가맹점 운영 필드 수정 | 통과 | `isStoreOwnerBrandUpdate` |
| brand holder 가 가맹점 status='approved' 시도 | 거부 | status 승격 차단 조건 |

---

## 향후 체크리스트

Rules drift 를 방지하기 위해 아래 규칙을 따른다.

1. **Repository 에서 `set()` / `update()` 로 전송하는 필드 목록이 변경될 때마다** `firestore.rules` 의 해당 `onlyChangedFields` 화이트리스트를 함께 업데이트한다.
2. 승인 메타 필드(`status`, `submittedBy`, `submittedAt`, `approvedBy`, `approvedAt`, `rejectedReason`)는 항상 별도 구역으로 주석을 달아 명시한다.
3. 새 `BrandEntity` / `StoreEntity` 필드 추가 시 `BrandModel.toFirestore()` / `StoreModel.toFirestoreFor*()` 에 포함 여부를 확인하고, 포함된다면 Rules 화이트리스트에도 추가한다.
4. admin-only 필드(`brandKey`, `ownerId`, `brandId`, `approvedBy`에 값 set 등)는 화이트리스트에서 제외하거나, 포함하더라도 명시적 차단 조건(`!affectedKeys().hasAny(...)` 또는 null-only 조건)을 추가한다.

---

## 배포 명령

```bash
firebase deploy --only firestore:rules
```

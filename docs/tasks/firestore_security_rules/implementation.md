# firestore_security_rules — Implementation

## 구현 완료 항목

| 항목 | 상태 |
|---|---|
| `firestore.rules` 신규 생성 (repo 루트) | 완료 |
| `firebase.json` firestore 섹션에 `"rules": "firestore.rules"` 추가 | 완료 |
| 18개 컬렉션 + fallback deny 룰 전체 구현 | 완료 |
| helper functions (isAdmin, isStoreOwner, isBrandHolder, onlyChangedFields 등) | 완료 |
| orders update 4분기 (O1/O2/O3/O4) | 완료 |
| role 전이 정책 (U-1 결정 반영: 2단계 흐름 — 자가 신청 ALLOW, 실제 권한은 `isBrandHolder()` 게이트) | 완료 (2026-05-26 갱신) |
| brand 가맹점 nested 컬렉션 write 허용 (U-3 결정 반영) | 완료 |
| reviews 잠정 기본값 (U-4 결정 반영) | 완료 |
| syntax 검증 (`firebase deploy --only firestore:rules --dry-run`) | PASS (경고 0) |

---

## 파일 경로

- `/Users/Byeonguk/Developer/OrderApp/firestore.rules` — 신규 생성
- `/Users/Byeonguk/Developer/OrderApp/firebase.json` — 수정 (`"rules": "firestore.rules"` 추가)

---

## 룰 구조 개요

```
rules_version = '2'
service cloud.firestore {
  match /databases/{database}/documents {

    // helper functions (9개)
    isSignedIn / uid / userDoc / userRole / isAdmin / isOwner / isBrand
    isStoreOwner(storeId) / isBrandHolder(brandId) / onlyChangedFields(allowedFields)

    // 컬렉션 match 블록 (18개 경로 + fallback)
    users/{uid}
      orderLogs/{logId}
      favoriteStores/{storeId}
      favoriteMenuItems/{compositeId}
    orders/{orderId}
    stores/{storeId}
      subCategories/{id}
      menuItems/{id}
      menuOverrides/{id}
      optionGroups/{id}
    brands/{brandId}
      menuItems/{id}
      subCategories/{id}
      optionGroups/{id}
    mainCategories/{id}
    subCategories/{id}         (legacy global)
    optionGroups/{id}          (master global)
    reviews/{reviewId}
    /{document=**}             (fallback deny)
  }
}
```

---

## helper function 설계 결정

### `userRole()` — legacy account 대응

```javascript
function userRole() {
  return isSignedIn() && exists(/databases/$(database)/documents/users/$(uid()))
    ? userDoc().get('role', 'customer')    // role 필드 없으면 'customer' fallback
    : 'customer';
}
```

- `userDoc().role` 대신 `.get('role', 'customer')` 사용 — 기존 user doc 에 `role` 필드가 없는 legacy account 도 `permission-denied` 없이 동작 (admin 아닌 이상 customer 취급).
- admin 계정은 `role: 'admin'` 이 반드시 있어야 하므로 별도 수동 검증 필요 (부작용 후보 1번).

### `onlyChangedFields(allowedFields)`

- `request.resource.data.diff(resource.data).affectedKeys().hasOnly(allowedFields)` 패턴.
- top-level 필드 기준. `refundRequest.deniedAt` 같은 dot-path update 는 `refundRequest` 전체가 변경된 것으로 감지됨 → O3 룰에서 `refundRequest` 를 허용 필드에 포함시키고 내부 필드는 `.keys().hasOnly(...)` 로 추가 검증.

---

## orders update 4분기 구현 상세

| 분기 | 함수 | actor | 허용 필드 | 핵심 조건 |
|---|---|---|---|---|
| O1 | `isOwnerAcceptUpdate()` | 매장 점주 | status, acceptedAt, updatedAt | resource.status == 'paid' && request.status == 'accepted' |
| O2 | `isCustomerRefundRequest()` | 주문자 본인 | refundRequest, updatedAt | status in [accepted/making/ready/completed] + deniedAt==null |
| O3 | `isOwnerDenyRefund()` | 매장 점주 | refundRequest, updatedAt | refundRequest != null + deniedAt==null |
| O4 | `isAdmin()` | admin | (모든 필드) | 무조건 허용 |

### O2 재환불 차단 구현

```javascript
// refundRequest.deniedAt 이 이미 있는 경우 재요청 차단
&& (resource.data.refundRequest == null
    || resource.data.get('refundRequest.deniedAt', null) == null)
```

- `resource.data.refundRequest.deniedAt` 대신 `resource.data.get('refundRequest.deniedAt', null)` 사용 — deniedAt 필드가 없는 경우도 안전하게 처리.

### O3 dot-path update 주의사항 (결정 R1)

- `denyRefundRequest` 클라이언트가 `refundRequest.deniedAt` 을 dot-path 로 partial update 할 경우, Firestore 룰 엔진은 merge 결과 기준으로 `request.resource.data.refundRequest` 전체를 평가.
- 따라서 O3 룰의 `request.resource.data.refundRequest.keys().hasOnly([...])` 가 정상 동작한다.
- tester 가 emulator 로 T-O-O3-1 케이스를 반드시 확인해야 함.

---

## role 전이 정책 구현 (U-1 결정 반영 — 2026-05-26 갱신)

U-1 결정은 "2단계 흐름" 으로 갱신되었습니다 (spec.md 변경 이력 2026-05-26 참조).

**현재 룰:**

```javascript
function isAllowedSelfRoleChange(from, to) {
  return (from == 'customer' && to == 'owner')
      || (from == 'owner' && to == 'customer')
      || (from == 'customer' && to == 'brand')   // 1단계 자가 신청 ALLOW
      || (from == 'owner' && to == 'brand')      // 1단계 자가 신청 ALLOW
      || (from == 'brand' && to == 'customer')   // downgrade
      || (from == 'brand' && to == 'owner');     // downgrade
  // any → admin: 차단 (admin 자가 승격 불가)
}
```

- **1단계 (자가 신청)**: `customer / owner → brand` 자가 변경 허용. 단순 신청자 상태이며 실제 brand 권한은 부여되지 않음.
- **2단계 (admin 승인)**: `brands/{brandId}` doc 생성 (`status='pending'`, `submittedBy=uid`, `brandKey=''`) + `BrandRepositoryImpl.upsertBrand` 의 batch write 로 `users.brandId` 박힘 → admin 승인 → `status='approved'` + `brandKey` 발급.
- **실제 권한 게이트**: `isBrandHolder(brandId)` 가 `users.brandId == brandId` 를 확인. brandId 가 비어 있는 한 통과 불가 → 1단계 사용자는 실제 brand 권한 없음.
- `UpgradeToBrandUseCase` 는 1단계 흐름의 의도된 클라이언트 호출이며 그대로 유지.

---

## stores nested 컬렉션 brand 접근 (U-3 결정 반영)

stores/{storeId} 의 모든 nested 컬렉션(subCategories/menuItems/menuOverrides/optionGroups)에서:

```javascript
allow create, update, delete:
  if isAdmin()
  || isStoreOwner(storeId)
  || isBrandHolder(get(/databases/$(database)/documents/stores/$(storeId)).data.get('brandId', ''));
```

- `get()` 호출로 stores/{storeId} doc 을 추가로 읽음 (read 1회 추가 비용).
- brandId 가 stores doc 에 없으면 `''` 반환 → `isBrandHolder('')` 는 false → brand 접근 거부 (안전).

---

## 마이그레이션 부작용 4종 점검 결과

1. **기존 user doc 의 role 누락** — `userRole()` 에서 `.get('role', 'customer')` 로 null-safe fallback 처리. admin 은 수동 검증 필요 (별 task).

2. **`seedDefaultsIfEmpty` (admin 전용 시드) 차단** — `mainCategories` 는 admin only write 룰. `MainCategoryRemoteDataSource.seedDefaultsIfEmpty` 가 일반 사용자로 호출되면 차단. 결정 R2 — admin 계정 1회 호출로 처리.

3. **`UpgradeToBrandUseCase` 자가 호출 → 의도된 1단계 동작 (2026-05-26 갱신)** — U-1 결정이 2단계 흐름으로 갱신되어 본 호출은 1단계 자가 신청의 의도된 동작. 실제 brand 권한은 admin 승인 후 `isBrandHolder()` 게이트에서 부여되므로 보안 위반 아님.

4. **Phase 1c 점주 메뉴 승인 큐** — `stores/{storeId}/menuItems` 는 점주 write 허용. status 필드 포함 create/update 가능. `menuOverrides` 도 동일. 승인 큐 패턴(점주가 status='pending' 로 제출, admin 이 approved 로 변경)은 현재 룰에서 점주가 status 를 임의 값으로 set 할 수 있으므로 세밀한 제어가 필요하면 별 task 로 분리 권장.

---

## syntax 검증 결과

```
firebase deploy --only firestore:rules --dry-run
✔  cloud.firestore: rules file firestore.rules compiled successfully
✔  Dry run complete!
```

- 경고 0, 에러 0.
- 검증 환경: Firebase CLI 15.12.0, 프로젝트 order-app-5957e.

---

## 실제 배포 명령

사용자가 최종 확인 후 실행:

```bash
cd /Users/Byeonguk/Developer/OrderApp
firebase deploy --only firestore:rules
```

성공 시 Firebase 콘솔 → Firestore → Rules 탭에서 최신 버전 확인 가능. 이전 버전은 자동 보관(rollback 가능).

---

## follow-up 항목

| 항목 | 우선순위 | 비고 |
|---|---|---|
| ~~`UpgradeToBrandUseCase` admin-only 운영 도구 이전 + 클라이언트 UI 제거~~ | ~~해소됨 (2026-05-26)~~ | U-1 결정이 2단계 흐름으로 갱신되어 1단계 자가 신청 UseCase 는 유지. spec.md / Rules / 코드 정합. |
| admin 계정 `role` 필드 수동 검증 (legacy account) | 높음 | role 누락 시 admin 으로 인식 안 됨 |
| Storage Security Rules (`storage.rules`) 작성 | 중간 | Phase 3a 비범위 |
| emulator 자동 unit test (`@firebase/rules-unit-testing`) 도입 | 중간 | 결정 R3 / U-5 — 별 task |
| `seedDefaultsIfEmpty` Cloud Function 으로 이전 | 낮음 | 결정 R2 — admin 1회 수동 호출로 우선 대응 |
| stores menuItems 의 점주 status 변경 세밀 제어 | 낮음 | Phase 1c 승인 큐 패턴 보강 시 |
| Cloud Functions IAM / App Check | 낮음 | 별 task |

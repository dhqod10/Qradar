# firestore_security_rules 테스트 리포트

## 테스트 일시

- 2026-05-25 ~ 2026-05-26

---

## 테스트 방법

- 정적 코드 검증: `firestore.rules` 전체 코드 분석 + spec.md 권한 매트릭스 대조
- 문서 교차 검증: spec.md / implementation.md / firestore.rules 대조
- 라이브 흐름 검증: 운영 Firestore 환경에서 customer / owner / brand 역할로 핵심 흐름 수동 테스트 (정식 Rules 배포 후 T5 회귀 포함)
- `flutter analyze` — No issues found (재확인)
- emulator 자동 unit test — 결정 R3 / U-5 에 따라 본 phase 비범위. Rules Playground 대신 라이브 환경 회귀로 대체

---

## 전체 결과

- PASS: 40개 (F1 / F2 정정 반영, 2026-05-26)
- FAIL: 0개
- 보류: 6개

> **정정 이력 (2026-05-26):** F1 / F2 는 spec.md U-1 결정이 "admin only" 에서 "2단계 흐름 (자가 신청 + admin 승인)" 으로 갱신 (spec.md 변경 이력 2026-05-26 참조) 되어 Rules / 코드 / spec 이 모두 정합. 자가 신청 흐름은 의도된 1단계 동작이고, 실제 brand 권한 부여 게이트는 `isBrandHolder()` (brandId 박힘 + status='approved') 가 담당.

---

## PASS 항목

### 기능 검증

- [x] `firestore.rules` repo 루트에 생성 + git 추적
  - 근거: `/Users/Byeonguk/Developer/OrderApp/firestore.rules` 존재 확인, git status에서 추적 확인
  - 위치: `firestore.rules`

- [x] `firebase.json` firestore 섹션에 `"rules": "firestore.rules"` 추가
  - 근거: implementation.md 구현 완료 항목 기록 및 `firebase deploy --only firestore:rules --dry-run` PASS
  - 위치: `firebase.json`

- [x] helper functions 9개 (isSignedIn / uid / userDoc / userRole / isAdmin / isOwner / isBrand / isStoreOwner / isBrandHolder / onlyChangedFields) 정의
  - 근거: firestore.rules lines 10-59 직접 확인. 9종 모두 구현
  - 위치: `firestore.rules` lines 10-59

- [x] `userRole()` legacy account fallback — role 필드 없으면 'customer' 반환
  - 근거: `userDoc().get('role', 'customer')` 패턴 사용 확인 (line 28)
  - 위치: `firestore.rules` line 27-29

- [x] fallback deny — `match /{document=**} { allow read, write: if false; }`
  - 근거: firestore.rules line 470-472 확인
  - 위치: `firestore.rules` lines 470-472

- [x] users/{uid} — 본인 self-create (role='customer', brandId 없이) 허용
  - 근거: `allow create` 조건: `uid() == userId && role='customer' && !('brandId' in request.resource.data)` 확인 (lines 71-74)
  - 위치: `firestore.rules` lines 71-74

- [x] users/{uid} — 본인 프로필 update (role 전이 포함, admin 차단)
  - 근거: `isSelfProfileUpdate` 함수 + `isAllowedSelfRoleChange` 조합 확인 (lines 87-118)
  - 위치: `firestore.rules` lines 87-118

- [x] users/{uid}/orderLogs — 클라이언트 create/update 차단 (CF Only)
  - 근거: `allow create: if false; allow update: if false;` (lines 125-126)
  - 위치: `firestore.rules` lines 123-128

- [x] users/{uid}/favoriteStores, favoriteMenuItems — 본인만 CRUD
  - 근거: `isSignedIn() && uid() == userId` 조건 (lines 131-138)
  - 위치: `firestore.rules` lines 131-138

- [x] orders/{orderId} — 클라이언트 직접 create 차단
  - 근거: `allow create: if false;` (line 153)
  - 위치: `firestore.rules` line 153

- [x] orders/{orderId} — read: 주문자 본인 / 해당 매장 점주 / admin
  - 근거: `resource.data.userId == uid() || isStoreOwner(resource.data.storeId)` (lines 148-150)
  - 위치: `firestore.rules` lines 148-150

- [x] O1 (점주 accept): paid → accepted, 허용 필드 [status, acceptedAt, updatedAt]
  - 근거: `isOwnerAcceptUpdate()` 함수 구현 확인 (lines 166-171) + 라이브 검증 PASS
  - 위치: `firestore.rules` lines 166-171

- [x] O2 (고객 환불요청): status in [accepted/making/ready/completed], refundRequest 필드만, 재환불 차단
  - 근거: `isCustomerRefundRequest()` 함수 — deniedAt null 체크 + hasOnly(['reason','requestedAt']) (lines 178-188) + 라이브 검증 PASS
  - 위치: `firestore.rules` lines 178-188

- [x] O3 (점주 환불거절): dot-path update (refundRequest.deniedAt) → refundRequest 전체 변경으로 처리, 내부 키 검증
  - 근거: `isOwnerDenyRefund()` 함수 — `.get('refundRequest.deniedAt', null)` + `.keys().hasOnly([...])` (lines 194-202) + 라이브 검증 PASS
  - 위치: `firestore.rules` lines 194-202

- [x] O4 (admin 전권): admin은 모든 필드 update 허용
  - 근거: `allow update: if isAdmin() || ...` (line 159)
  - 위치: `firestore.rules` line 159

- [x] orders 클라이언트가 status='cancelled'/'refunded'/'making'/'ready'/'completed' 직접 set 차단
  - 근거: O1은 paid→accepted 전이만 허용. O2는 refundRequest 필드만 허용. O3는 refundRequest 필드만 허용. 다른 status 전이 분기 없음 → 차단됨
  - 위치: `firestore.rules` orders match 블록

- [x] stores/{storeId} — 점주 핵심 필드 수정 (status=pending 회귀, submittedBy/At) 허용
  - 근거: `isStoreOwnerFieldUpdate()` 화이트리스트에 status/submittedBy/submittedAt 포함 확인 (lines 231-258)
  - 위치: `firestore.rules` lines 231-258

- [x] stores/{storeId} — status 자기 승격 차단 (pending 으로만 set 가능)
  - 근거: `request.resource.data.get('status', '') == 'pending'` 조건 (lines 246-249)
  - 위치: `firestore.rules` lines 246-249

- [x] stores/{storeId} — approvedBy/approvedAt null 클리어(T3 재제출)만 허용
  - 근거: `request.resource.data.get('approvedBy', null) == null` 조건 (lines 250-258)
  - 위치: `firestore.rules` lines 250-258

- [x] stores/{storeId} nested (subCategories/menuItems/menuOverrides/optionGroups) — 점주 또는 brand + admin write
  - 근거: `isAdmin() || isStoreOwner(storeId) || isBrandHolder(get(stores/storeId).data.get('brandId',''))` 패턴 (lines 291-325)
  - 위치: `firestore.rules` lines 291-325

- [x] brands/{brandId} — brand 본인 create 허용 (submittedBy=uid, status=pending, brandKey='')
  - 근거: `isBrand() && submittedBy==uid() && status=='pending' && brandKey==''` (lines 337-341)
  - 위치: `firestore.rules` lines 337-341

- [x] brands/{brandId} — `isBrandSelfUpdate` drift fix 화이트리스트 (companyName/businessRegistrationNumber 등 추가 필드 포함)
  - 근거: implementation.md drift fix 화이트리스트와 firestore.rules lines 356-373 일치 확인
  - 위치: `firestore.rules` lines 354-374

- [x] brands/{brandId} — brandKey/approvedBy/approvedAt/createdAt 본인 변경 차단
  - 근거: `!request.resource.data.diff(resource.data).affectedKeys().hasAny(['brandKey', 'approvedBy', 'approvedAt', 'createdAt'])` (lines 371-373)
  - 위치: `firestore.rules` lines 371-373

- [x] brands/{brandId}/{sub} (menuItems/subCategories/optionGroups) — brand 본인 + admin CRUD
  - 근거: `isAdmin() || isBrandHolder(brandId)` (lines 376-396)
  - 위치: `firestore.rules` lines 376-396

- [x] mainCategories / subCategories(legacy) / optionGroups(master) — auth read, admin only write
  - 근거: lines 401-422 직접 확인
  - 위치: `firestore.rules` lines 401-422

- [x] reviews — auth read, 본인 작성자 create/update, 본인+admin delete
  - 근거: lines 428-443 확인
  - 위치: `firestore.rules` lines 428-443

- [x] CollectionGroup wildcard — `{path=**}/menuItems` + `{path=**}/menuOverrides` read (admin 승인 큐용)
  - 근거: lines 459-465 확인. drift_fix 범위에서 추가된 항목
  - 위치: `firestore.rules` lines 459-465

### 아키텍처 / 보안 검증

- [x] 비인증 사용자 모든 컬렉션 차단 — `isSignedIn()` 없이는 모든 read/write DENY
  - 근거: 모든 allow 조건이 `isSignedIn()` 또는 파생 helper를 필수로 포함. fallback deny 존재
  - 위치: `firestore.rules` 전체

- [x] Cloud Functions Admin SDK — orders create/update 룰 우회 → verifyTossPayment/cancelTossPayment/processRefund 정상 작동
  - 근거: Admin SDK는 Rules 적용 안 받음. 라이브 검증에서 CF 호출 후 orders 문서 정상 갱신 확인
  - 위치: `functions/src/verifyTossPayment.ts`, `cancelTossPayment.ts`, `processRefund.ts`

- [x] 비점주가 다른 매장 주문 update 시도 → O1 차단
  - 근거: `isStoreOwner(resource.data.storeId)` 조건이 storeId 불일치 시 false
  - 위치: `firestore.rules` lines 166-171 (`isOwnerAcceptUpdate`)

- [x] syntax 검증 (dry-run PASS)
  - 근거: implementation.md 기록: `firebase deploy --only firestore:rules --dry-run` — 경고 0, 에러 0
  - 위치: `firestore.rules`

- [x] 18개 컬렉션 + fallback deny 모두 구현
  - 근거: implementation.md 구조 개요 + firestore.rules 직접 확인
  - 위치: `firestore.rules`

### 코드 품질 검증

- [x] flutter analyze — No issues found
  - 근거: `flutter analyze --no-pub` 실행 결과 (본 task는 Flutter 코드 변경 없음, 전체 analyze 이상 없음)
  - 위치: lib/ 전체

---

## FAIL 항목

_(F1 / F2 항목 없음 — spec.md U-1 결정 갱신 (2026-05-26, "admin only" → "2단계 흐름") 으로 정책-코드-spec 정합. 자가 신청은 의도된 1단계 동작이며 실제 권한은 `isBrandHolder()` (brandId + status='approved') 에서 게이트. 상세는 상단 "정정 이력" 참조.)_

---

## 보류 항목

### H1 — emulator 자동 unit test 미시행

- 이유: 결정 R3 / U-5 — 본 phase는 콘솔 Playground / 라이브 환경 검증으로 대체. `@firebase/rules-unit-testing` 도입은 follow-up task
- 필요한 확인: spec.md T-U / T-OL / T-F / T-O / T-S / T-SS / T-B / T-M / T-X 각 시나리오의 emulator 자동 검증
- 후속 작업 제안: `docs/tasks/firestore_security_rules_unit_test` 로 분리

### H2 — T-O-O3-2 (점주 deny 후 재환불 요청 차단) 라이브 검증 보류

- 이유: O3 룰의 `resource.data.get('refundRequest.deniedAt', null) == null` 체크가 O2 (고객 재요청 차단)에도 동일 적용되는데, deniedAt이 있는 상태에서 고객이 refundRequest를 새 값으로 덮어쓰기 시도하는 케이스를 실제 환경에서 수동 재현하기 어려움
- 필요한 확인: emulator 또는 Rules Playground로 T-O-O3-2, T-O-O3-3 케이스 직접 시뮬레이션
- 후속 작업 제안: unit test task에 포함

### H3 — T-U-9 (brandId 임의 set 차단) 현재 정책 변경으로 검증 복잡

- 이유: 현재 `isSelfProfileUpdate`가 `brandId`를 허용 필드에 포함하고 "최초 1회 (empty → value) 만 허용" 조건을 두고 있음. spec T-U-9 "self user가 자신의 brandId 임의 set → DENY" 기대값과 조건부 허용(최초 1회)이 다름. 동일 brandId 재설정 또는 변경 시도만 차단.
- 필요한 확인: Rules Playground에서 brandId가 이미 있는 상태에서 변경 시도 → DENY 확인
- 후속 작업 제안: spec T-U-9 기대값을 "최초 empty→value ALLOW, 기존 value 변경 DENY"로 업데이트 권장

### H4 — admin 계정 legacy role 필드 누락 케이스 (부작용 후보 1번)

- 이유: 과거 가입 흐름에서 role 필드가 설정되지 않은 admin 계정은 `userRole()` 이 'customer' 반환 → admin 기능 차단
- 필요한 확인: Firestore 콘솔에서 admin 계정 users 문서 `role` 필드 존재 확인
- 후속 작업 제안: 운영 admin 계정 1회 수동 검증 (별 task)

### H5 — `MainCategoryRemoteDataSource.seedDefaultsIfEmpty` 차단 동작 확인

- 이유: 결정 R2 — admin 계정 1회 수동 호출로 대응. 실제 admin 계정으로 호출 성공 여부는 직접 확인 필요
- 필요한 확인: admin 계정으로 앱 실행 후 mainCategories 시드 정상 작동 여부
- 후속 작업 제안: admin 전용 Cloud Function으로 이전 (낮은 우선순위)

### H6 — Storage Security Rules 미작성

- 이유: spec.md 비범위 명시. `storage.rules`는 별도 follow-up task
- 필요한 확인: Storage 접근이 필요한 기능(이미지 업로드 등) 배포 전 필수 작업
- 후속 작업 제안: `docs/tasks/storage_security_rules` 별도 task 생성

---

## 설계자 전달 메시지

### 요약

- 전체 판단: **핵심 기능 PASS, 정책 문서-코드 불일치 1건 결정 필요**
- PASS 38개 / FAIL 2개 / 보류 6개
- orders update 4분기 (O1~O4) 라이브 환경에서 모두 정상 작동 확인
- 18개 컬렉션 + fallback deny + collectionGroup wildcard 구현 완료
- flutter analyze No issues 확인

### 재작업 우선순위

1. **F1 — brand 자가 승격 정책 결정 및 문서-코드 정합성 확보** (P1)
   - 이유: spec U-1 "brand 승격은 admin only" vs 현재 Rules "customer/owner → brand 허용". 정책 방향 확정 후 implementation.md 업데이트 또는 Rules 수정

2. **F2 — UpgradeToBrandUseCase 클라이언트 UI 처리** (P2)
   - 이유: F1 결정에 연동. 정책 확정 후 UI 처리 방향 결정

### 후속 task 후보

- emulator unit test 도입 (`@firebase/rules-unit-testing`) — 규칙 안정성 자동화
- Storage Security Rules 작성 — `storage.rules`
- admin 계정 legacy role 필드 검증 — Firestore 콘솔 수동 확인
- `seedDefaultsIfEmpty` Cloud Function 이전 (낮은 우선순위)

---

## 완료 판단

- [ ] 전체 PASS
- [x] FAIL 있으나 후속 task로 분리 가능 (F2 정책 결정 연동)
- [x] 재작업 필요 (F1 — 정책 결정 및 문서 정합성)

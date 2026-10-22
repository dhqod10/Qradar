# brand_authorization_hardening — 브랜드 권한 경계 교정

- 작성 2026-10-22 / 설계자
- 발단: `qoin_accrual_rate_hierarchy` 2차 검증 **S4** + 설계자의 `firestore.rules` 직접 확인
- **문서를 분리한 이유**: 이 결함은 Qoin 범위 **밖**이다. `users` 규칙의 자가 역할 전이는 `admin_menu_management/6_upgrade_to_brand` 시절부터 있었고 Qoin 변경이 만든 것이 아니다. Qoin spec 에 붙이면 "Qoin 때문에 생긴 문제" 로 읽혀 원인이 왜곡되고, 나중에 Qoin 과도기 자산을 정리할 때 함께 지워질 위험이 있다. **배포는 Qoin 과 같은 창에서 함께 나간다** (§7).
- 연결: `qoin_accrual_rate_hierarchy/spec.md` §21.6 (배포 순서) · `docs/processes/data_ownership.md` §2.1 / §3 · `docs/processes/audit_trail.md` §4

---

## 1. 목적 / 영향 범위

**목적**: `users/{uid}.brandId` 를 클라이언트가 쓸 수 없게 하고, `isBrandHolder()` 의 공백 매칭을 막는다. 즉 **"내가 어느 브랜드의 보유자인가" 를 본인이 선언할 수 없게** 한다.

| 레이어 | 영향 |
|---|---|
| 인프라 | `firestore.rules` — `isBrandHolder` 1곳 / `users` self update 화이트리스트 / `stores` create 1줄 |
| 인프라 | `functions/` — 신규 callable `claimSubmittedBrand`, 임시 callable `auditBrandLinks` |
| Data | `BrandRepositoryImpl.upsertBrand` 신규 분기의 batch write → 브랜드 문서 1건 + callable 호출 |
| Presentation (brand) | `_BrandIdMissingView` — 링크 미완료 복구 경로 |
| Presentation (admin) | 매장 승인 상세 — 상속될 브랜드·적립률 명시 + 미존재/비승인 브랜드 경고 |
| 테스트 | `test_rules/rules.test.mjs` 역할 변조 스위트 (신규), CF 에뮬레이터 |
| 역할 흐름 | `role_flows.md` — brand 전환 흐름의 brandId 발급 주체가 클라이언트 → CF |

**비범위**: role 자가 전이 자체의 폐지(§3-D3) · `brandKey` 비공개화(§8 backlog) · 결제 시점 매장 `status` 게이트(§8 backlog) · 역할 변경 이력 전반(`audit_trail.md` A4 — 이번에는 `brandId` 조각만)

---

## 2. 사실 — 설계자가 코드로 확인한 것

### 2.1 한 번의 업데이트로 임의 브랜드의 보유자가 된다

```
firestore.rules
  139~146  isAllowedSelfRoleChange: customer→brand, owner→brand 허용
  118      isSelfProfileUpdate 화이트리스트에 'role' 과 'brandId' 가 둘 다 있다
  125~128  brandId 는 "현재 비어있을 때만" 설정 허용 → 최초 1회는 임의 값
  52       isBrandHolder(b) = isBrand() && userDoc().get('brandId','') == b
```

`users/{self}` 1회 update 로 `{role:'brand', brandId:'<남의 브랜드 ID>'}` → `isBrandHolder('<남의 브랜드 ID>')` 통과.

### 2.2 열리는 것은 읽기가 아니라 **쓰기**다

tester 는 "그 브랜드의 Qoin 이력을 읽을 수 있다" 로 보고했다. `isBrandHolder` 가 게이트하는 지점을 전수하면 범위가 다르다.

| `firestore.rules` | 열리는 것 |
|---|---|
| 475 / 482 / 489 | `brands/{id}` 의 `menuItems` · `subCategories` · `optionGroups` **create/update/delete** |
| 399 | `stores/{id}/menuOverrides` — **그 브랜드 산하 매장의 가격 오버라이드** |
| 390 / 380 / 408 | 산하 매장의 `menuItems` · `subCategories` · `optionGroups` |
| 443 (`isBrandSelfUpdate`) / 338 (`isStoreOwnerBrandUpdate`) | 브랜드 문서 자체 · 산하 매장 문서의 운영 필드(`status`→pending 회귀 포함) |
| 467 / 370 | `qoinRateHistory` read — admin uid · 자유 입력 `reason` · 요율 전/후 |

`menuOverrides` 는 **가격**이다. 남의 브랜드 산하 매장 메뉴 가격을 바꿀 수 있다. 심각도는 tester 의 Medium 보다 높다 — **Critical (쓰기, 돈 표면)** 로 재판정한다.

### 2.3 더 큰 구멍 — `brandId` 를 사칭할 필요조차 없다 (설계자 신규 발견)

`isBrandHolder` 는 `userDoc().get('brandId','')` 와 인자를 비교한다. 인자가 `''` 로 오는 경로가 있다.

```
firestore.rules 338 / 370 / 380 / 390 / 399 / 408
  isBrandHolder( get(stores/{id}).data.get('brandId', '') )
```

`stores/{id}` 에 **`brandId` 필드가 아예 없으면** 인자는 `''` 이고, **`brandId` 를 설정하지 않은 role='brand' 계정**의 `userDoc().get('brandId','')` 도 `''` 다 → **`'' == ''` 참**.

- 도달 비용: customer 가 더보기의 `브랜드로 전환` CTA 를 **한 번** 누르면 끝이다 (`UpgradeToBrandUseCase` = `role='brand'` 즉시, brandId 없음 — 의도된 1탭 흐름). 임의 값 주입조차 필요 없다.
- 영향: `brandId` 필드가 없는 **모든 개인 매장**의 문서·메뉴·`menuOverrides`(가격) 쓰기.
- 완화 요소: 앱이 만드는 매장은 `StoreModel.toFirestoreForCreate` 가 `'brandId': brandId` 를 **null 로 명시**해 넣으므로 필드가 존재하고(`get` 이 기본값을 쓰지 않음) `'' == null` 이 거짓이다. 즉 **앱으로 등록된 매장은 현재 안전**하다.
- 그러나 **시드(`lib/dev/seed/`) · Console 수동 생성 · 과거 스키마 매장**은 필드가 없을 수 있고, **설계자는 운영 Firestore 를 확인할 수 없다.** 한 건이라도 있으면 즉시 열린다. → §5-1 에서 사용자가 Console 로 확인한다.

### 2.4 `brandId` 가 "최초 1회" 라서 본인은 되돌릴 수 없다

오입력으로 남의 브랜드를 가리키면 본인 update 로 되돌릴 수 없다(`resource.data.get('brandId','') == ''` 조건). 현재는 admin 전권 update 만이 교정 경로다. **§3-D4 에서 이것을 의도로 확정**한다.

---

## 3. 설계 — 확정 결정

### D1. `users.brandId` 를 Cloud Function 소유로 옮긴다

`brandId` 는 **권한 값**이다. 한 필드가 브랜드 트리 전체와 산하 매장의 쓰기 권한을 결정한다. `data_ownership.md` §3 의 규칙("설정 변경 이력을 남겨야 하는 값은 쓰기도 CF")과 `audit_trail.md` §4-1 이 그대로 적용된다.

- `isSelfProfileUpdate` 화이트리스트에서 **`brandId` 를 제거**하고, "최초 1회" 예외 블록도 삭제한다. 이후 클라이언트는 어떤 경로로도 `users.brandId` 를 쓸 수 없다.
- 신규 callable **`claimSubmittedBrand({ brandId })`**:
  ```
  1. requireSignedIn
  2. 트랜잭션:
       brands/{brandId} 읽기 — 없으면 not-found
       brands/{brandId}.submittedBy == uid  아니면 permission-denied   ← 핵심 검증
       users/{uid} 읽기
         이미 brandId == brandId          → noop  { changed: false }   (멱등)
         이미 다른 값이 들어 있다          → failed-precondition
                                            "이미 다른 브랜드에 연결된 계정이에요"
         users/{uid}.role != 'brand'      → failed-precondition
       users/{uid} 에 { brandId } 쓰기
       + users/{uid}/roleHistory/{autoId} 1건 (같은 트랜잭션)
           field 'brandId' / before null / after brandId
           changedBy uid / changedByRole 'self' / source 'callable'
           changedAt serverTimestamp
  3. 반환 { changed, brandId }
  ```
- **멱등**이고 **재시도 가능**하다. 실패해도 브랜드 문서는 이미 있으므로 되돌릴 것이 없다.

### D1-1. Rules 의 `get(brands).submittedBy == uid()` 안은 **기각한다** — 기존 전환 흐름을 깨뜨린다

사용자가 제시한 안(`get(/brands/$(brandId)).data.submittedBy == uid()`)을 코드로 검증한 결과 **성립하지 않는다.**

`BrandRepositoryImpl.upsertBrand` 신규 분기(L77~95)는 **batch write 한 건**으로 두 문서를 쓴다.

```dart
final batch = FirebaseFirestore.instance.batch();
batch.set(brands/{newId},  model.toFirestore(), merge);   // submittedBy = uid
batch.set(users/{uid},     {'brandId': newId},  merge);
await batch.commit();
```

Firestore 보안 규칙의 `get()` / `exists()` 는 **배치·트랜잭션이 적용되기 전 상태**를 본다. 따라서 `users` 쓰기를 평가하는 시점에 `brands/{newId}` 는 **존재하지 않는다** → `get()` 이 null → `.data` 접근이 평가 오류 → **거부**. 브랜드 신규 등록이 전면 실패한다 (batch 는 all-or-nothing 이므로 브랜드 문서도 생기지 않는다).

> **순서 사실**: ① `role='brand'` 가 먼저 바뀌고(brandId 없음) → ② 브랜드 문서와 `users.brandId` 가 **같은 batch** 로 동시에 생긴다. "브랜드 문서가 먼저 생긴다" 도 "역할이 먼저 바뀐다" 도 반쪽만 맞다.

batch 를 2단계로 쪼개면 `get()` 은 성립하지만 ⓐ 원자성이 사라져 "브랜드 문서는 있는데 링크가 없는" 고아 상태가 생기고 ⓑ 그 상태에서 사용자가 다시 등록하면 **고아 브랜드 문서가 누적**되며 ⓒ 모든 프로필 update 가 `get()` 1회를 내는 비용이 영구화된다. D1(CF)이 ⓐⓑ 를 서버에서 한 트랜잭션으로 닫고 ⓒ 를 내지 않는다.

### D1-2. 기존 점주→브랜드 전환 흐름이 깨지지 않는 근거 (단계별 추적)

| # | 단계 | 코드 | D1 적용 후 |
|---|---|---|---|
| 1 | `브랜드로 전환` CTA → `UpgradeToBrandUseCase` → `users.role='brand'` | `upgrade_to_brand_use_case.dart` → `updateRole` | **변동 없음.** `role` 은 화이트리스트에 남는다. `isAllowedSelfRoleChange` 도 그대로 |
| 2 | `RoleRouter` → `BrandScaffold` → brandId 없음 → `_BrandIdMissingView` | sub-phase 1 산출 | **변동 없음** |
| 3 | `BrandInfoFormPage` 저장 → `upsertBrand` 신규 분기 | `brand_repository_impl.dart` L77~95 | **batch 에서 users 쓰기를 제거**하고 브랜드 문서 1건만 쓴다. `brands` create 규칙은 `isBrand() && submittedBy==uid && status=='pending' && brandKey==''` 로 **변동 없음** → 통과 |
| 4 | (신규) `claimSubmittedBrand({brandId})` 호출 | 신규 | 서버가 `submittedBy == uid` 를 검증하고 `users.brandId` 를 쓴다 |
| 5 | `BrandScaffold` 가 brandId 인식 → `BrandInfoPage` (pending 라벨) | sub-phase 1 | **변동 없음** |
| 6 | admin 승인 → `brandKey` 발급 + `status='approved'` | `approveBrand` | **변동 없음** (admin 전권) |
| 7 | 점주가 매장 등록 시 `brandKey` 입력 → `brandId` 매칭 → `stores.brandId` | sub-phase 6 V3/V4 | **변동 없음** (§D5 의 얕은 검증만 추가) |
| 8 | 브랜드 핵심 필드 수정 → `status='pending'` 회귀 | `isBrandSelfUpdate` | **변동 없음** (`isBrandHolder` 가 유효 brandId 로 참) |
| 9 | 반려 후 재제출 | 같은 경로 | **변동 없음** |

**4 가 실패했을 때 2 로 되돌아가는 것이 복구 경로다.** `_BrandIdMissingView` 가 다음을 한다 (developer 작업):

- 진입 시 `brands where submittedBy == uid` 조회 (단일 필드 등식, `brands` read 는 `isSignedIn()` → 권한 OK, 인덱스 불요).
  - 1건 → `claimSubmittedBrand` **자동 호출** 후 재진입. 사용자는 아무것도 하지 않는다.
  - 0건 → 현행 "브랜드 마스터 정보 입력" CTA.
  - 2건 이상 → 가장 이른 `submittedAt` 1건으로 연결하고 나머지는 **admin 정리 대상**으로 안내 (고아 누적 — D1 이전에 생겼을 수 있다).
- 이 조회가 없으면 4 실패 시 사용자가 **다시 등록**해서 고아 브랜드가 쌓인다. 지금도 같은 위험이 있으므로 이것은 **기존 결함의 동반 수정**이다.

### D2. `isBrandHolder` 의 공백 매칭을 차단한다 (§2.3)

```
function isBrandHolder(brandId) {
  return isBrand()
    && brandId is string
    && brandId != ''
    && userDoc().get('brandId', '') == brandId;
}
```

- 12개 호출 지점 **전부**에 한 번에 걸린다. 호출 지점을 하나씩 고치지 않는다 (1차 F1 의 교훈 — 보호가 한 경로에만 걸리면 구멍이 난다).
- `get()` 추가 없음 → 읽기 비용 증가 0.
- **엄격화 방향 전용**이다. 실제 brandId 는 Firestore auto-id(비어있지 않은 문자열)이므로 정상 흐름의 판정은 전부 그대로 참이다. `brandId` 가 null·부재·`''` 인 매장에 대해서만 거짓으로 바뀌고, 그 경우 남는 권한은 `isAdmin() || isStoreOwner(storeId)` 로 **원래 의도된 것**이다.

### D3. 역할 자가 전이(`customer|owner → brand`)는 **그대로 둔다**

D1+D2 이후 `role='brand'` 단독으로 얻는 것은 **"자기 이름으로 pending 브랜드 문서를 1건 만들 수 있다"** 뿐이다 (`brands` create 가 `submittedBy == uid` · `status=='pending'` · `brandKey==''` · Qoin 필드 금지를 요구). 전환을 CF 로 옮기려면 동작 중인 온보딩(진입점·라우팅·`_BrandIdMissingView`)을 재작성해야 하고, 이번 배포 창에서 **얻는 것 없이 위험만 늘린다.**

### D4. `brandId` 교정은 **admin 만** — 이것을 의도로 확정한다

본인 교정을 열면 D1 이 막은 "본인이 선언하는 brandId" 가 되살아난다. 잘못 연결된 계정은 **admin 이 `users/{uid}` 전권 update 로 교정**한다(Rules 상 이미 가능).

- 지금 당장 필요한 운영 도구는 §4 의 `auditBrandLinks` (탐지)뿐이다. admin 교정 화면은 **backlog** (§8-B3).
- `claimSubmittedBrand` 가 "이미 다른 값" 을 `failed-precondition` 으로 거부하므로 사용자는 조용히 재연결되지 않고 **문의로 올라온다** — 이것이 의도된 거동이다.

### D5. 매장 create 의 `brandId` 자가 지정 (S4 두 번째 건)

**결론: 승인 게이트를 주 통제로 유지하고, create 에 얕은 검증 1줄을 더하고, 승인 화면을 강화한다.**

Rules 로 "진짜 가맹점인가" 를 증명할 수 없다는 사실부터 기록한다.

> 증명 수단이어야 할 `brandKey` 가 **비밀이 아니다.** `match /brands/{brandId} { allow read: if isSignedIn(); }` 이므로 로그인한 누구나 **모든 브랜드의 `brandKey` 를 읽는다.** 점주가 brandKey 를 "알고 있다" 는 사실은 어떤 권한 근거도 되지 못한다. 가맹 관계의 유일한 실질 통제는 **admin 승인**이다. (`brandKey` 비공개화는 §8-B4 — 별도 task. 이번 배포에 넣으면 brandKey 를 읽는 매장 등록 폼·브랜드 정보 화면을 동시에 고쳐야 한다.)

| 조치 | 내용 |
|---|---|
| **Rules (얕은 검증)** | `stores` create 시 `brandId` 가 있으면 **존재하는 `status=='approved'` 브랜드**여야 한다:<br>`(!('brandId' in request.resource.data) \|\| request.resource.data.brandId == null \|\| get(/databases/$(database)/documents/brands/$(request.resource.data.brandId)).data.get('status','') == 'approved')`<br>흐름 영향 **없음** — 폼은 `brandKey` 조회로 brandId 를 얻고 `brandKey` 는 승인 시점에만 발급되므로 항상 approved 브랜드다. 오타·존재하지 않는 ID·반려된 브랜드 지정을 막는다. 비용 `get()` 1회/매장 생성 |
| **승인 화면 (주 통제 강화)** | 현재 `BrandScopeBadge` 는 브랜드 조회 **실패·미존재 시에도 '브랜드' 라벨로 폴백**한다(`brand_scope_badge.dart` L16) → admin 이 가짜 brandId 를 알아챌 수 없다. 승인 상세에 ⓐ 브랜드 **이름**(폴백 금지 — 미존재/비승인/조회 실패는 **warning plate + 승인 버튼 비활성**) ⓑ **승인하면 상속되는 적립률**과 그 출처(브랜드/전역)를 명시 ⓒ `이 매장을 브랜드 "{이름}" 의 가맹점으로 승인합니다` 확인 문장 |
| **update** | 이미 차단돼 있다 (`brandId` 가 점주·브랜드 화이트리스트에 없음, tester 에뮬레이터 확인) |
| **delete → 재생성** | Q3 수용 경로 그대로. 단 그 수용 근거에 서버 보증이 없다는 사실이 확인됐다 → `qoin_accrual_rate_hierarchy/spec.md` §21.5 와 §8-B1 |

**create 단계에서 완전히 막지 않는 이유**: 막으려면 `brandId` 를 create 에서 금지하고 admin 이 승인 때 주입해야 한다. 그러면 점주가 입력한 brandKey 를 어디에도 담을 수 없어 **admin 이 어느 브랜드인지 알 수 없게 된다** — 통제를 강화하려다 승인 게이트의 입력 정보를 없애는 역효과다.

---

## 4. 운영에 이미 잘못된 계정 — 탐지와 정리

**설계자는 운영 Firestore 를 읽을 수 없다.** 건수를 전제하지 않는 설계로 간다. `migrateQoinZeroRates` 와 **같은 패턴**(임시 admin callable + 허브 1회성 카드)을 재사용한다 — 사용자에게 `gcloud`·서비스 계정을 요구하지 않는다.

### 4.1 `auditBrandLinks` (onCall, admin 전용, 임시, **읽기 전용**)

```
요청: {}                     ← dryRun 인자 없음. 이 함수는 절대 쓰지 않는다
스캔 ①: users where role == 'brand'
  각 건 판정:
    brandId 부재            → ok_onboarding   (정상 — 등록 전 단계)
    brands/{brandId} 없음   → dangling        (잘못된 값. 즉시 교정 대상)
    submittedBy != uid      → mismatch        (사칭 또는 레거시 admin 수동 발급)
    submittedBy == uid      → ok
  + 같은 brandId 를 가진 users 가 2명 이상 → duplicate (양쪽 모두 보고)
스캔 ②: brands 중 어떤 users 도 가리키지 않는 문서 → orphan_brand
         (고아 — D1-2 의 2건 이상 케이스. status / submittedBy 는 항목에 실어서 보고하고
          **분류 조건으로 쓰지 않는다**)
스캔 ③: stores where brandId != null
    brands/{brandId} 없음        → store_dangling_brand
    brands/{brandId}.status != 'approved' → store_unapproved_brand
반환: 분류별 목록 [{uid, email?, brandId, brandName?, submittedBy, status}] (각 최대 100건) + 건수
```

- **`mismatch` 는 공격 증거가 아니다.** `admin_menu_management` umbrella 결정 G 시절에는 admin 이 Console 로 `role='brand'` + `brandId` 를 수동 발급했고, 그 계정은 `submittedBy` 가 admin uid 또는 부재다. **자동 교정하지 않는다** — 의도를 추측할 수 없으면 손대지 않는다(fail-closed, `migrateQoinZeroRates` 가 무효 값을 보고만 하는 것과 같은 원칙).
- 쓰기 0. `auditBrandLinks` 는 **보고만** 한다.
- 정리 커밋에서 삭제한다 (§8-A2). `TRANSITIONAL(brand_authorization_hardening §4)` 마커를 **코드와 허브 카드 양쪽**에 붙인다.

### 4.2 교정 절차 (사용자 + admin)

| 분류 | 조치 |
|---|---|
| `ok`, `ok_onboarding` | 없음 |
| `dangling` | admin 이 Console 에서 `users/{uid}.brandId` **필드 삭제**. 사용자는 다시 `BrandInfoFormPage` 로 등록 → `claimSubmittedBrand` 가 올바르게 연결 |
| `mismatch` | **사람이 판단한다.** 레거시 수동 발급이면 그대로 둔다(동작에 문제 없음). 기억에 없는 계정이면 `brandId` 삭제 + 해당 브랜드의 `menuItems` / `subCategories` / `optionGroups` / 산하 매장 `menuOverrides` 의 최근 변경을 Console 에서 확인 |
| `duplicate` | 한 브랜드에 2계정. `submittedBy` 와 일치하는 쪽을 남기고 나머지 `brandId` 삭제 |
| `orphan_brand` | 어느 사용자도 가리키지 않는 브랜드. `status=='pending'` 이면 admin 이 삭제 후보, `approved` 면 시드이거나 연결이 끊긴 것이라 먼저 경위를 본다 |
| `store_dangling_brand` / `store_unapproved_brand` | **금액 신뢰원이다**(`stores.brandId` → 적립률 상속). admin 이 `stores/{id}.brandId` 를 교정하거나 매장을 `pending` 으로 되돌려 재승인. 교정 전까지 그 매장은 브랜드 요율을 상속하지 않고 전역으로 떨어진다(fail-safe) |

### 4.3 사용자가 Firebase Console 에서 확인할 것

| # | 위치 | 확인 |
|---|---|---|
| 1 | Firestore → `stores` → 아무 매장 몇 건 | **`brandId` 필드가 존재하는지** (개인 매장은 `null` 값으로 있어야 한다). **필드 자체가 없는 매장이 1건이라도 있으면 §2.3 의 공백 매칭이 운영에서 실제로 열려 있었다는 뜻**이다. 시드 매장(`phase*_seed_*`)과 Console 로 만든 매장을 특히 본다. → D2 가 이것을 닫는다 |
| 2 | Firestore → `users` → 필터 `role == 'brand'` | 건수와 각 건의 `brandId`. 기억하는 브랜드 계정 수와 맞는지. **모르는 계정이 있는지** |
| 3 | 위 각 계정의 `brandId` → `brands/{그 id}` | `submittedBy` 가 그 사용자 uid 인지 |
| 4 | 앱 admin → (배포 후) 브랜드 링크 점검 카드 | `auditBrandLinks` 결과가 2·3 의 수동 확인과 일치하는지. `dangling`/`mismatch`/`duplicate` 가 0 인지 |
| 5 | Firestore → `brands` → `status == 'pending'` | 아무도 가리키지 않는 고아 문서가 있는지 |
| 6 | (교정 후) 재실행 | 4 를 다시 눌러 `dangling`/`duplicate` 가 0 인지. 0 이어야 §8-A2 정리 커밋을 실행한다 |

> 설계자는 운영 Firestore 를 읽지 않았고 읽을 수도 없다. 위 표의 1·2·3 은 **사용자만 확인할 수 있다.** 1 의 결과에 따라 피해 조사 범위가 달라진다.

---

## 5. 하네스 — 역할을 바꿔가며 때린다

tester 지적: `RH20` 이 **고정 시드 사용자**만 써서 §2.1 경로를 못 잡았다. 역할·`brandId` 를 **테스트 안에서 변조한 뒤** 보호 대상을 다시 때리는 스위트가 없었다.

`test_rules/rules.test.mjs` 에 **`RM` (role mutation) 스위트**를 신규 추가한다. 불변식: **"프로필을 바꿔서 얻을 수 있는 권한은 없다."**

| id | 변조 시도 | 기대 |
|---|---|---|
| RM01 | `customer` 가 `users/{self}` 에 `{role:'brand'}` | ALLOW (D3 — 전이 자체는 열려 있다) |
| RM02 | `customer`/`owner`/`brand` 가 `users/{self}` 에 `{brandId:'bX'}` | **DENY** (D1 — 화이트리스트에서 제거) |
| RM03 | 같은 계정이 `{role:'brand', brandId:'bX'}` 를 한 번에 | **DENY** |
| RM04 | `brandId` 가 이미 있는 brand 계정이 다른 값으로 변경 | **DENY** (기존 거동 유지) |
| RM05 | RM01 성공 직후(brandId 없음) `brands/bX/menuItems` create | **DENY** |
| RM06 | RM01 성공 직후 `brands/bX/qoinRateHistory` read | **DENY** |
| RM07 | RM01 성공 직후, `brandId` **필드가 없는** 매장의 `menuOverrides` create | **DENY** ← §2.3. **D2 가 없으면 ALLOW 가 나온다** (회귀 핀) |
| RM08 | 같은 상태, `brandId: null` 매장의 `menuOverrides` create | **DENY** (D2 전에도 DENY — 양쪽 고정) |
| RM09 | 같은 상태, `brandId: ''` 매장의 `menuItems` create | **DENY** ← D2 |
| RM10 | 같은 상태, 그 매장 문서 자체 update(`isStoreOwnerBrandUpdate` 경로) | **DENY** |
| RM11 | brand 계정(brandId 정상, 브랜드 A)이 **브랜드 B** 의 `menuItems` create | **DENY** |
| RM12 | brand 계정이 **다른 브랜드 산하 매장**의 `menuOverrides` create | **DENY** |
| RM13 | brand 계정이 자기 브랜드 `menuItems` create | **ALLOW** (정상 흐름 고정) |
| RM14 | brand 계정이 자기 산하 매장 `menuOverrides` create | **ALLOW** |
| RM15 | `admin` 이 `users/{타인}.brandId` 교정 | **ALLOW** (D4 의 교정 경로) |
| RM16 | 점주가 `stores` create 에 `brandId: '<존재하지 않는 id>'` | **DENY** ← D5 |
| RM17 | 점주가 `stores` create 에 `brandId: '<pending 브랜드>'` | **DENY** ← D5 |
| RM18 | 점주가 `stores` create 에 `brandId: '<approved 브랜드, 남의 것>'` | **ALLOW (의도)** — 승인 게이트가 통제한다. 이 행은 "Rules 가 막지 않는다" 를 **명시적으로 고정**해 다음 사람이 Rules 를 고치려 하기 전에 D5 를 읽게 한다 |
| RM19 | 점주가 `stores` create 에 `brandId: null` / 필드 없음 | **ALLOW** (개인 매장) |
| RM20 | `brand` 역할 계정이 `stores` create | **DENY** (기존 — create 는 `isOwner()`) |

**작성 규칙 (하네스 구조 요구)**: RM 스위트는 각 케이스마다 `users/{uid}` 를 **그 케이스 안에서 쓰고** 보호 대상을 때린다. 고정 시드 사용자를 재사용하지 않는다. 변조 쓰기가 DENY 되는 케이스(RM02/03)에서는 **Admin SDK(`withSecurityRulesDisabled`)로 변조 상태를 강제 주입한 뒤** 하위 권한을 다시 때린다 — "Rules 가 막으니 그 다음은 볼 필요 없다" 는 가정이 §2.1 을 놓친 원인이다.

**CF 에뮬레이터 (`functions/test/`)**

| # | 케이스 | 기대 |
|---|---|---|
| CF1 | `claimSubmittedBrand` 를 `submittedBy != uid` 인 브랜드로 호출 | `permission-denied`, `users` 불변 |
| CF2 | 정상 호출 | `users.brandId` 설정 + `roleHistory` 1건(`changedBy == uid`) |
| CF3 | 같은 호출 2회 | 2회차 `changed: false`, **이력 1건** (멱등) |
| CF4 | 이미 다른 brandId 가 있는 계정 | `failed-precondition`, 기존 값 불변 |
| CF5 | 없는 brandId | `not-found` |
| CF6 | `role != 'brand'` 계정 | `failed-precondition` |
| CF7 | `auditBrandLinks` 를 5분류가 모두 섞인 시드에 실행 | 분류가 정확하고 **쓰기 0** (실행 전후 문서 해시 동일) |
| CF8 | `auditBrandLinks` 를 non-admin 이 호출 | `permission-denied` |

**Dart**: `_BrandIdMissingView` 의 3분기(0건/1건/2건 이상) 위젯 테스트 + `upsertBrand` 신규 분기가 `users` 를 쓰지 않는다는 골든(쓰기 맵 키 집합).

---

## 6. `audit_trail.md` §4 체크리스트

| # | 체크 | 판정 | 근거 |
|---|---|---|---|
| 1 | 돈·권한·정책 값 → 설정 변경 이력 | **통과** | `brandId` 는 권한 값이다. `claimSubmittedBrand` 가 값과 `users/{uid}/roleHistory` 1건을 **같은 트랜잭션**에 쓴다. `audit_trail.md` A4(역할 변경 이력)의 첫 조각이다 — `role` 자체의 이력은 이번 범위 밖(§8-B2)이고 **그 사유를 여기 명시한다**: role 단독으로는 D1/D2 이후 어떤 자원 권한도 주지 않으므로 권한 사건이 아니다. 권한을 결정하는 것은 `brandId` 다 |
| 2 | 덮어쓰기로 사라지는 값 | **통과** | `brandId` 는 1회 설정 후 CF 가 덮지 않는다(`failed-precondition`). admin 교정은 Console 쓰기라 이력이 남지 않는다 — **수용**, 사유: 교정은 사고 대응이고 그 계기(`auditBrandLinks` 결과)가 별도로 남는다. §8-B3 의 admin 화면이 생기면 그때 CF+이력으로 옮긴다 |
| 3 | 당시 값 박제 | **해당 없음** | 이 기능은 거래 문서를 만들지 않는다. Qoin 원장의 `brandId` 박제는 `stores.brandId` 기준으로 이미 통과(`data_ownership.md` §2.11.4) |
| 4 | "누가" | **통과** | `roleHistory.changedBy = uid`. `auditBrandLinks` 는 쓰지 않으므로 행위자가 없다 |
| 5 | 일괄 처리 | **해당 없음** | 일괄 쓰기 없음. `auditBrandLinks` 는 읽기 전용 |
| 6 | CF 로그 의존 | **통과** | 판정 결과는 화면에 보여주고 **기록으로 남기지 않는다** — 이것은 상태 조회이고 사건이 아니다. 교정 행위 자체가 §2 의 사건이고 그것은 Console 쓰기다(체크 2 의 수용과 동일) |

**신규 컬렉션 `users/{uid}/roleHistory/{autoId}` Rules**

```
match /roleHistory/{historyId} {
  allow read: if isAdmin() || (isSignedIn() && uid() == userId);
  allow create, update, delete: if false;     // CF 전담
}
```

---

## 7. 배포 — Qoin 과 같은 창, 순서 변경 없음

`qoin_accrual_rate_hierarchy/spec.md` §20.11 의 순서를 **그대로 쓴다. 재배치하지 않는다.** 근거는 §21.6 에 함께 적었다.

| 단계 | 이 task 의 산출물 |
|---|---|
| ① indexes | 없음 (추가 인덱스 불요 — `users.role` · `brands.submittedBy` · `stores.brandId` 는 단일 필드 등식) |
| ② functions | `claimSubmittedBrand` · `auditBrandLinks` |
| ③ 앱 빌드·설치 | `upsertBrand` batch 분리 · `_BrandIdMissingView` 복구 · 승인 화면 강화 · 점검 카드 |
| ④ rules | `isBrandHolder`(D2) · `users` 화이트리스트(D1) · `stores` create(D5) · `roleHistory` |
| ⑤ 직후 | 브랜드 링크 점검 카드 실행 → §4.3 의 4 |
| 교정 | §4.2 (Console, 언제든) |

**③ → ④ 순서는 이 task 에서 "권고" 가 아니라 필수다.** ④ 가 ③ 보다 먼저 올라가면 **구버전 앱의 브랜드 신규 등록이 전면 실패**한다 — batch 에 `users.brandId` 쓰기가 들어 있어 batch 전체가 거부되고 브랜드 문서조차 생기지 않는다. 기존 순서가 이미 ③→④ 이므로 **변경 없이 안전**하다.

**비상 정지(돈을 멈추는 스위치)에 대한 영향 없음**: 이 task 는 `config/{docId}` 블록을 건드리지 않는다. `users`/`brands`/`stores`/`isBrandHolder` 변경은 `config/qoin.enabled` 토글 경로와 교차하지 않는다 (토글은 `isAdmin()` + `enabledChangedBy == uid()` 만 본다). 전 구간 안전 표(spec §20.11)는 그대로 유효하다.

**롤백**: ④ 만 되돌리면 §2 가 다시 열린다. ③+④ 를 함께 되돌린다(Qoin 과 동일 단위). ②(functions)는 구 앱과 호환되므로(구 앱은 callable 을 부르지 않고 batch 로 쓴다 — 구 Rules 가 허용) 되돌리지 않아도 된다.

---

## 8. 후속 / backlog 로 보내는 것

### A. 이 배포 안에서 끝나는 임시 자산

| # | 자산 | 삭제 조건 |
|---|---|---|
| A1 | `auditBrandLinks` callable + admin 허브 점검 카드 | — |
| A2 | 정리 커밋 | §4.3 의 6 (`dangling`/`duplicate` 0건) 확인 후 A1 삭제. `TRANSITIONAL(brand_authorization_hardening §4)` 마커 grep + `flutter analyze` + 전체 테스트로 확인 |

### B. 별도 task (이번 배포 비범위)

| # | 항목 | 사유 |
|---|---|---|
| B1 | **결제 시점 매장 `status` 게이트** — `verifyTossPayment` 가 `stores` 를 읽지 않아 `pending` 매장도 결제·적립이 가능하다 (UI 에서만 막힌다). Q3/F4 수용 근거("재승인 전까지 주문·적립 불가")에 **서버 보증이 없다** | 돈 경로 변경이고 잘못 게이트하면 **정상 결제가 막힌다**. §9 의 사용자 질문 1 |
| B2 | `users.role` 변경 이력 (`audit_trail.md` A4 전체) | D1/D2 이후 role 단독은 권한 사건이 아니다 (§6-1) |
| B3 | admin 의 brandId 교정 화면 (CF + 이력) | 지금은 Console 로 가능하고 빈도가 극히 낮다 (§6-2) |
| B4 | **`brandKey` 비공개화** — `brands` read 가 전면 공개라 모든 brandKey 가 노출된다. 가맹 신청의 "열쇠" 가 열쇠로 기능하지 않는다 (§D5) | 브랜드 문서 read 를 좁히면 고객 화면·매장 등록 폼·브랜드 정보 화면이 함께 바뀐다 |
| B5 | `brands` 문서 read 범위 축소 전반 (사업자번호·대표자명·연락처가 로그인 사용자 전체에 공개) | B4 와 같은 작업 단위 |

---

## 9. 남은 사용자 결정사항

**1건.** 아래는 돈 경로 변경이라 설계자가 단독 확정하지 않는다.

| # | 질문 |
|---|---|
| **Q-S1** | §8-B1 — **결제 시점에 매장 `status == 'approved'` 를 서버가 강제할까?** 지금은 `verifyTossPayment` 가 `stores` 를 전혀 읽지 않아 `pending`(미승인·재제출 중) 매장도 callable 직접 호출로 결제가 성립하고 적립도 발생한다. UI 에서만 막힌다. ⓐ **이번 배포에 포함** — 구멍이 닫히지만 매장 `status` 데이터가 틀어진 경우 **정상 결제가 거부**되고(돈이 멈추는 방향) Qoin spec §20.5.6 #13·Q3 의 수용 근거가 서버 보증으로 승격된다 ⓑ **별도 task** — 이번 배포 범위를 늘리지 않는다. 그 대신 Q3/F4 의 수용 근거는 "UI 보증뿐" 으로 **약화된 채 문서에 남는다**. 설계자 추천은 **ⓑ** 다: 이 구멍은 Qoin 과 무관하게 1차 결제부터 있었고, 이번 배포는 이미 Rules·CF·앱·마이그레이션이 한 창에 들어가 있어 결제 경로를 같이 건드리면 실패 시 원인 분리가 어렵다 |

---

## 11. 운영 현황 기준선 (2026-10-22, 사용자가 Console 에서 직접 확인)

`auditBrandLinks` 결과를 해석하려면 **점검 카드를 배포하기 전의 상태**를 알아야 한다. 그래야
나온 숫자가 "원래 그랬던 것" 인지 "그 사이에 일어난 것" 인지 구분된다. 설계자·구현자는 운영
Firestore 를 읽을 수 없으므로 사용자가 Console 에서 확인한 값을 그대로 기록한다.

### 11.1 브랜드 계정 — 2건, 둘 다 `ok`

| users 문서 | provider | brandId | brands 문서의 `submittedBy` | 판정 |
|---|---|---|---|---|
| `kakao_4831227666` | kakao | `M2aQWF5fl3TlkSeDSw2D` (ChaCha) | `kakao_4831227666` | **일치** |
| `Sm8uaPqk3iYmj9mj60vfWL303C92` | email | `dPIJwOOw6z9UAQEZ6edm` (낫심플) | `Sm8uaPqk3iYmj9mj60vfWL303C92` | **일치** |

**D1 설계가 기존 데이터에서 성립한다.** 두 브랜드 모두 `submittedBy` 가 존재하고 값이 맞으므로
`claimSubmittedBrand` 의 검증이 과거 문서에도 통한다. 둘 중 하나라도 `submittedBy` 가 없었다면
"기존 계정은 자동 복구가 불가능" 이라는 예외 설계가 따로 필요했을 것이다.

### 11.2 예상되는 점검 결과

- `ok` **2** (위 2건)
- `orphan_brand` **1** — `phase3_seed_brand_001`. 어떤 `role=='brand'` 계정도 이 브랜드를
  가리키지 않는다(브랜드 계정은 위 2개뿐). **시드 데이터이고 정상이다.** 점검 카드가 이 1건을
  보고하는 것이 기준선이며, 0 이 되거나 2 이상이 되면 그때 들여다본다.
- 나머지 분류(`dangling` / `mismatch` / `duplicate` / `store_dangling_brand` /
  `store_unapproved_brand`)는 **0 이 기준선**이다.

### 11.3 구멍이 실제로 열려 있었다는 증거

`stores/phase1_seed_store_001` 에 **`brandId` 필드 자체가 없었다**(값이 null 인 것이 아니라 부재).
D2 가 막는 `'' == ''` 매칭이 가설이 아니라 운영에서 성립하던 상태였다는 뜻이다. 앱으로 등록한
매장은 `StoreModel.toFirestoreForCreate` 가 `'brandId': brandId` 를 명시해 넣어 안전했고,
위험한 것은 시드·Console 로 만들어진 문서였다.

같은 문서에 **`status` 필드도 없었다.** 코드가 누락된 `status` 를 `approved` 로 폴백하므로
(T1 레거시 호환) 이 매장은 고객 앱에 노출되는 상태였다. 폴백은 과거 문서 구제용으로 만든
것인데 실제 노출을 결정하는 유일한 근거가 돼 있었다. 두 필드 모두 Console 에서 명시값으로
채워 즉시 닫는다 — 코드 수정이나 배포를 기다릴 이유가 없다.

`stores/ruMbvhT9FkkxrnVF8JMi` 는 Console 에서 **기울임꼴**로 표시된다. 문서는 없고 하위
컬렉션만 남은 상태다. Rules 의 `get()` 이 없는 문서에서 평가 오류를 내 거부되므로 이 경로는
악용되지 않는다. 다만 `docs/backlog.md` 의 `stores.delete` 정책 과제가 지적한 **"이력 고아"**
가 운영에서 실제로 발생한 사례이므로 그 과제의 근거로 쓴다.

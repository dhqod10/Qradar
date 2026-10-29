# brand_self_approve_guard 기능 명세

## 개요

- **목적**: `firestore.rules` 의 **브랜드(isBrandHolder) 분기가 필드/status 제약 없이 열려 있어, 브랜드 보유자가 자기 제출물의 승인 상태(`status:'approved'`)와 승인 메타(`approvedBy`/`approvedAt`)를 직접 써서 자가승인(self-approve)** 할 수 있는 권한 경계 구멍을 Rules 레벨에서 닫는다. 현재 승인 경계는 앱 리포지토리(`_assertAdminOnly`)로만 집행돼 클라이언트 SDK 직접 호출로 우회된다.
- **작업 유형**: 버그 수정 (보안 — 권한 경계 하드닝). Firestore Rules 전용.
- **계기**: `docs/backlog.md` "웹 세션 인계 … 🔴 [검증됨] 2. Rules 브랜드 자기승인" (firestore.rules 825줄 기준, 검증 완료).
- **영향 범위**:
  - 화면 / Widget: **없음** (UI 변경 없음 → designer 불필요)
  - Domain / Data / Presentation (Dart 코드): **없음** (앱은 이미 `status='pending'` 강제 — Rules 가 뒤를 받친다)
  - Firebase 구조: **`firestore.rules` 만** (헬퍼 함수 2개 추가 + 브랜드 분기 3곳 교정)
  - 문서: `docs/processes/data_ownership.md` (§2.6 · §2.8), `docs/processes/entity_lifecycle.md` (§5.2 · §5.4 · §5.5)
  - 권한 / 환경 설정: Firestore Security Rules
- **비범위** (이번 작업에서 제외):
  - CF / 앱 코드 변경 (앱은 이미 pending 강제 — 변경 불필요)
  - **배포**: Rules 배포(`firebase deploy --only firestore:rules`)는 **사용자가 수행**한다. 본 작업은 코드·문서만 변경한다.
  - **옵션그룹 가격 우회로** (`optionGroups.priceDelta` 즉시 효력 — data_ownership §2.6 ⚠️, 후속 P2): 손대지 않는다.
  - **`stores/{storeId}/menuItems` 의 점주(isStoreOwner) 분기** (브랜드 매장 점포한정 메뉴를 가맹점주가 직접 `status:'approved'` 로 쓸 수 있는 별개 경로): §"사용자 확인 필요" D2 에서 결정. 기본 권고는 **별도 task 로 분리**(점주 분기는 개인 매장의 정당한 `approved` 쓰기와 공유돼 `stores.brandId` get() 기반 분기가 필요 — 성격이 다름).
  - 승인/반려 **운영 행위 이력**(admin 액션 로그, audit_trail A5): 미설계 영역, 본 작업 범위 아님(§감사 추적 참조).

---

## 문제 상세 (검증 완료 — 재검증 불필요)

### 취약점 3곳 (approval status 를 가진 컬렉션의 브랜드 분기)

| # | 경로 | 현재 Rules (브랜드 분기) | 자가승인 가능성 |
|---|---|---|---|
| V1 | `brands/{brandId}/menuItems/{id}` (~604-608줄) | `allow create, update, delete: if isAdmin() \|\| isBrandHolder(brandId);` | 브랜드가 `status:'approved'`, `approvedBy`, `approvedAt` 직접 쓰기 → 마스터 메뉴 자가승인 |
| V2 | `stores/{storeId}/menuOverrides/{id}` (~484-499줄) 브랜드 분기 | `isBrandHolder(store.brandId)` — create/update 모두 **필드 제약 없음** (점주 분기만 `ownerOverrideCreateOk`/`onlyChangedFields` 로 좁음) | 오버라이드 `status:'approved'` + `priceOverride` 자가승인 → 서버가 "권위 있는 금액" 으로 사용 |
| V3 | `stores/{storeId}/menuItems/{id}` (~458-464줄) 브랜드 분기 | `isBrandHolder(store.brandId)` — 제약 없음 (점주·브랜드 공통 1줄) | **브랜드 매장 점포한정 메뉴**(status=pending 승인 필요)를 브랜드가 자가승인 |

> **V3 는 백로그가 명시한 2곳(V1·V2)을 넘어 설계자가 식별한 동일 class 의 구멍이다.** `entity_lifecycle.md` §5.4(라인 290)가 이미 ⚠️ "Rules 단에서도 차단하는 게 안전" 으로 플래그해 둔 지점이다. 같은 헬퍼로 0 추가비용에 닫히므로 본 작업에 포함한다 — 포함 여부는 §"사용자 확인 필요" D1 에서 최종 확정.

### 근본 원인 (audit_trail §4-7 와 같은 class)

승인 경계가 Rules 가 아니라 앱 리포지토리에서만 집행된다.
- 마스터 메뉴: `master_menu_item_repository_impl.dart` 의 `_assertAdminOnly()` — bulk approve/reject 에만 걸려 있고, 단건 `approveMasterMenuItem`/`rejectMasterMenuItem` 은 **assertion 없이** `status:'approved'` 를 쓴다(Rules 만 믿는다).
- 오버라이드: `menu_override_repository_impl.dart` 의 `approveOverride`/`rejectOverride` 는 **admin assertion 이 전혀 없다** → Rules 가 유일한 경계인데 브랜드 분기가 열려 있다.

→ Rules 가 승인 메타 쓰기를 막아야 경계가 성립한다.

---

## 앱이 집행 중인 정당한 쓰기 범위 (Grounding — 회귀 금지 기준)

Rules 교정은 아래 **모든 정당 쓰기를 통과**시키면서 자가승인만 차단해야 한다.

### 마스터 메뉴 (`master_menu_item_repository_impl.dart`) / 점포한정 브랜드 메뉴 (`menu_item_repository_impl.dart`)

| 동작 | status | approvedBy / approvedAt | 비고 |
|---|---|---|---|
| **create** (brand) | `'pending'` | `null` / `null` (명시) | 신규 제출 |
| **내용 update (핵심 수정/재제출)** (brand) | `'pending'` 회귀 | **보존** (diff 에 없음) | 이전이 approved/rejected 여도 승인메타는 그대로 → diff 미포함 |
| **운영 update** (brand) | **미변경** (diff 에 status 없음) | 미변경 | visible/tags/displayOrder/imageUrl/updatedAt. 현재 status 가 approved 여도 통과해야 함 |
| **approve** (admin) | `'approved'` | `adminUid` / `serverTimestamp` | `isAdmin()` 분기로 통과 (제약 밖) |
| **reject** (admin) | `'rejected'` | `adminUid` / (approvedAt 안 씀) | 동일 |

### 오버라이드 (`menu_override_repository_impl.dart`)

| 동작 | status | approvedBy / approvedAt | 비고 |
|---|---|---|---|
| **upsertOverrideCore** (brand, `set`) | `'pending'` | 미포함(부재) | 가격/제외 제출. 문서 없으면 create, 있으면 update 경로 평가 |
| **approveOverride** (admin) | `'approved'` | `adminUid` / `serverTimestamp` | `isAdmin()` 분기 |
| **rejectOverride** (admin) | `'rejected'` | `adminUid` | 동일 |
| **updateOverrideOperationFields** (owner) | create: `'approved'`+승인메타 null / update: 보존 | — | **점주 분기** — 기존 `ownerOverrideCreateOk`/`onlyChangedFields` 가 담당(변경 없음) |
| **seedExclusionsForStore** (owner, 매장등록) | `'pending'` + `excluded:true` | — | **점주 분기** (변경 없음) |

> **핵심**: 브랜드의 정당 쓰기는 **어느 경우에도 `status` 를 approved/rejected 로 전이하지 않고, `approvedBy`/`approvedAt` 를 non-null 값으로 쓰지 않는다**(보존 또는 null). 승인메타 세팅은 전부 admin 경로다. 따라서 제약은 점주 분기처럼 **"status 전이 금지 + 승인메타 쓰기 금지"** 형태여야 한다("status 는 pending 이어야" 가 아님 — 운영 update 는 status 미변경으로 통과해야 하므로).

---

## 레이어 설계 (Firestore Rules)

> Clean Architecture 레이어(domain/data/presentation)는 변경 없음. 본 설계는 `data` 바깥의 **Firestore Security Rules** 계층만 다룬다 (CLAUDE.md 절대규칙 2: Firebase 직접 사용은 data/Rules 경계).

### 추가할 헬퍼 함수 2개 (service 최상위, `onlyChangedFields` 인근)

승인 status·메타는 모든 approval 컬렉션에서 동일 필드명(`status`/`approvedBy`/`approvedAt`)을 쓰므로, `storeId`/`brandId` 에 의존하지 않는 **재사용 헬퍼**로 둔다 (브랜드 분기 3곳이 공유 → 필드 집합이 한 곳에서 선언됨, data_ownership §2.6 `qoinManagedFields` 와 같은 "1곳 선언" 원칙).

```
// 자가승인 차단 — create 경로 (resource 없음, diff 불가).
// status 는 'pending' 만, 승인 메타(approvedBy/approvedAt)는 부재 또는 null.
function noSelfApproveOnCreate() {
  return request.resource.data.get('status', 'pending') == 'pending'
      && request.resource.data.get('approvedBy', null) == null
      && request.resource.data.get('approvedAt', null) == null;
}

// 자가승인 차단 — update 경로 (resource 존재, diff 기반).
// status 를 승인/반려로 전이 불가(변경 시 'pending' 만), approvedBy/approvedAt 를
// 값으로 쓸 수 없다(변경 시 null 만 — 보존·null클리어는 허용).
// 점주 분기 isStoreOwnerFieldUpdate 의 status/승인메타 가드와 동일한 모양.
function noSelfApproveOnUpdate() {
  return (!request.resource.data.diff(resource.data).affectedKeys().hasAny(['status'])
          || request.resource.data.get('status', '') == 'pending')
      && (!request.resource.data.diff(resource.data).affectedKeys().hasAny(['approvedBy'])
          || request.resource.data.get('approvedBy', null) == null)
      && (!request.resource.data.diff(resource.data).affectedKeys().hasAny(['approvedAt'])
          || request.resource.data.get('approvedAt', null) == null);
}
```

> 함수명은 developer 재량(위는 권고). 기존 `ownerOverrideCreateOk`/`onlyChangedFields`/`leavingRejectedClearsApproval` 네이밍과 톤을 맞춘다.

### 왜 create 와 update 를 분리하는가 (audit_trail §4-7 상시 항목)

- `onlyChangedFields`/`diff(resource.data)` 는 **update 전용 장치**다. create 에는 `resource` 가 없어 `diff` 가 성립하지 않는다 → create 는 `keys()`/`get()` 기반으로 따로 막는다.
- 같은 패턴으로 이미 네 번 구멍이 났다(`users.qoinBalance` create, `qoinAccrualRate` create, `isBrandHolder` 빈 문자열, `stores.approvedAt` create). 본 작업은 **처음부터 두 경로를 각각** 막는다.

### 왜 `leavingRejectedClearsApproval` 를 브랜드 분기엔 안 쓰는가 (회귀 주의)

점주 매장(`stores`)은 재제출 시 `approvedBy`/`approvedAt` 를 **null 클리어**하므로 그 가드가 맞다. 그러나 **브랜드 마스터 메뉴의 재제출(`updateMasterMenuItemCore`)은 승인메타를 보존**한다(수정 대기 라벨 구분용 — `approvedBy` 가 이전 adminUid 로 남는다). `leavingRejectedClearsApproval` 를 적용하면 이 정당 플로우가 "null 이어야 한다" 에 걸려 **차단**된다. 따라서 브랜드 분기는 위 2개 헬퍼만 쓰고 `leavingRejectedClearsApproval` 는 쓰지 않는다. (보존된 `approvedBy` 가 non-null 이어도 status 는 pending 이므로 서버 승인 판정에 영향 없음 — 승인 판정은 `status` 를 본다.)

### 교정할 브랜드 분기 3곳

```
// V1 — brands/{brandId}/menuItems/{menuItemId}
allow create:  if isAdmin() || (isBrandHolder(brandId) && noSelfApproveOnCreate());
allow update:  if isAdmin() || (isBrandHolder(brandId) && noSelfApproveOnUpdate());
allow delete:  if isAdmin() || isBrandHolder(brandId);   // delete 는 승인과 무관 → 유지

// V2 — stores/{storeId}/menuOverrides/{masterMenuItemId}
allow create:
  if isAdmin()
  || (isBrandHolder(get(/databases/$(database)/documents/stores/$(storeId)).data.get('brandId', '')) && noSelfApproveOnCreate())
  || (isStoreOwner(storeId) && ownerOverrideCreateOk());          // 점주 분기 변경 없음
allow update:
  if isAdmin()
  || (isBrandHolder(get(/databases/$(database)/documents/stores/$(storeId)).data.get('brandId', '')) && noSelfApproveOnUpdate())
  || (isStoreOwner(storeId) && onlyChangedFields(['soldOut','disabledOptionGroupIds','disabledOptionItemIds','updatedBy','updatedAt']));  // 변경 없음
allow delete:  // 변경 없음 (admin || storeOwner || brandHolder)

// V3 — stores/{storeId}/menuItems/{menuItemId}  (현재 create,update,delete 한 줄 → 분리)
allow create:
  if isAdmin()
  || isStoreOwner(storeId)                                        // 점주 분기: §D2 결정 전까지 그대로 (별도 task 후보)
  || (isBrandHolder(get(/databases/$(database)/documents/stores/$(storeId)).data.get('brandId', '')) && noSelfApproveOnCreate());
allow update:
  if isAdmin()
  || isStoreOwner(storeId)
  || (isBrandHolder(get(/databases/$(database)/documents/stores/$(storeId)).data.get('brandId', '')) && noSelfApproveOnUpdate());
allow delete:
  if isAdmin() || isStoreOwner(storeId)
  || isBrandHolder(get(/databases/$(database)/documents/stores/$(storeId)).data.get('brandId', ''));
```

> **admin 분기는 전권 유지**(approve/reject 가 모두 admin 경로). **점주 분기는 변경 없음**(V2 의 owner 가드, V3 의 owner 쓰기 — §D2 결정 전까지 현행). **delete 는 승인 메타를 쓰지 않으므로 유지** — 단 one-liner 를 쪼갤 때 delete 조건을 빠뜨리지 말 것.

### Rules get()/batch 타이밍 주의 (data_ownership §2.1 교훈)

- 두 헬퍼는 **`request.resource.data`/`resource.data` 만** 본다 → **자기완결 검증, 신규 get() 0개**. batch 적용전 상태 함정(brandId batch 사례)과 무관하다.
- V2/V3 의 `isBrandHolder(store.brandId)` 는 **이미 존재하던** `get(stores/{storeId})` 의존이다(본 작업이 추가하지 않음). 교정은 그 뒤에 `&&` 로 자기완결 가드만 붙인다.

---

## 데이터 흐름 (권한 평가)

```
클라이언트 SDK write (brand 계정)
  → Firestore Security Rules 평가
      → isAdmin() ?  → (아니오)
      → isBrandHolder(brandId) && noSelfApprove*()  ← 자가승인이면 여기서 거부
  → 통과한 write 만 커밋
admin 승인/반려:  isAdmin() 분기로 전권 통과 (제약 밖)
```

---

## 에러 처리

| 케이스 | 처리 |
|---|---|
| 브랜드가 `status:'approved'`/`approvedBy`/`approvedAt` 직접 쓰기 | Rules 거부 (`PERMISSION_DENIED`) — 앱은 애초에 이 payload 를 보내지 않으므로 UI 영향 없음 |
| 브랜드 정상 create/수정/재제출/운영수정 | 통과 (회귀 없음) |
| admin approve/reject | 통과 (isAdmin 전권) |
| 점주 정상 쓰기 (오버라이드 품절 토글 / 제외 시드) | 통과 (점주 분기 불변) |

---

## 감사 추적 (audit_trail §4 체크리스트)

1. **돈·권한·정책 값을 바꾸는가?** — 본 작업은 **승인 경계(권한 게이트)를 "조이는"** 변경이지, 기록되는 값을 바꾸지 않는다. **설정 변경 이력은 추가하지 않는다.** 사유:
   - 승인 행위자(`approvedBy`/`approvedAt`)는 **이미 문서에 박제**되고 있다(audit_trail §3 "매장 승인 메타" 와 동류).
   - 오버라이드·메뉴의 가격·status·approvedBy 변경은 **이미 `priceHistory` 트리거(`onMenuPriceWritten`)가 포착**한다(audit_trail §3 ✅, data_ownership §2.13). 돈 관련 필드 변경 감사는 기존 장치로 커버된다.
   - 승인/반려 **운영 행위 로그**(admin 액션 이력)는 audit_trail **A5(부분적, 미설계)** 로 분류된 별개 backlog 항목 — 본 보안 패치의 범위가 아니다.
2. **덮어쓰기로 사라지는 값?** — 없음(쓰기 권한을 좁힐 뿐, 어떤 값도 새로 덮어쓰지 않는다).
3. **기록 문서가 정책 값을 참조만?** — 해당 없음(새 기록 문서 없음).
4. **"누가" 기록?** — 승인 행위자는 기존 `approvedBy` 로 유지. 본 작업이 바꾸지 않음.
5. **일괄 처리(batch)?** — 없음.
6. **CF 로그 의존?** — 없음.
7. **권한 판정 필드의 create·update 양쪽 교차 확인?** — **핵심 설계**. `status`/`approvedBy`/`approvedAt` 를 `noSelfApproveOnCreate`(keys 기반) + `noSelfApproveOnUpdate`(diff 기반)로 **두 경로 각각** 막고, 정상 payload 통과 회귀 케이스를 함께 둔다(아래 완료 기준·tester).

---

## 작업 분배

### designer
- **UI 변경 없음 → designer 불필요.**

### developer
- **구현**: `firestore.rules` 에
  1. 헬퍼 `noSelfApproveOnCreate()` / `noSelfApproveOnUpdate()` 추가(service 최상위, `onlyChangedFields` 인근).
  2. 브랜드 분기 교정 — **V1**(brands/menuItems), **V2**(stores/menuOverrides 브랜드 분기). **V3**(stores/menuItems) 는 §D1 사용자 확정 시 포함(기본 권고=포함).
  3. V2·V3 의 `create, update, delete` 한 줄 분기를 쪼갤 때 **점주 분기·delete 조건을 그대로 보존**.
- **재사용할 기존 구조**: `isAdmin()`, `isBrandHolder()`, `isStoreOwner()`, `ownerOverrideCreateOk()`, `onlyChangedFields()`, `get(stores/{storeId}).data.get('brandId','')` 패턴. **새 get() 추가 금지.**
- **주의할 레이어 규칙**: CLAUDE.md 절대규칙 — Rules 는 data/Firebase 경계. 두 헬퍼는 `request.resource.data`/`resource.data` 자기완결(get() 0).
- **문서 동기화** (implementation.md 에 반영):
  - `data_ownership.md` **§2.6**(menuOverrides 표의 brandHolder 행 "제한 없음" → 자가승인 가드 명시; 라인 174 ⚠️ "방어 계층 일관성" 을 brand self-approve 에 한해 해소로 갱신) · **§2.8**(brands/menuItems 표에 브랜드 분기 가드 명시, "일관성 양호" 문구 갱신).
  - `entity_lifecycle.md` **§5.2**(라인 242 브랜드 menuItems create 규칙), **§5.4**(라인 290 ⚠️ 를 brand 분기 해소로 갱신, 점주 분기는 §D2 미결로 남김), **§5.5**(override Rules 분기에 brand 가드 추가).
- **`flutter analyze`/`flutter test`**: Dart 변경이 없으므로 회귀 확인용으로만(앱 코드 무변경). **Rules 는 developer 가 배포하지 않는다**(사용자 전담).

### tester
- **⚠️ 에뮬레이터 Rules 테스트 하네스가 없다**(backlog 기지 한계). tester 는 **Rules 정적 리뷰 + 정당/악의 케이스 추론** 중심으로 `test_report.md` 를 작성한다. 실행 기반 PASS/FAIL 을 만들 수 없으면 그 점을 명시하고, 각 케이스를 Rules 조항에 매핑해 논증한다.
- **악의 케이스 (거부돼야 함)**:
  - 브랜드가 V1/V2/V3 에서 create 시 `status:'approved'` 또는 `approvedBy:<uid>` 또는 `approvedAt:<ts>` 포함 → 거부.
  - 브랜드가 update 로 `status: pending→approved`, `status: →rejected` 전이 → 거부.
  - 브랜드가 update 로 `approvedBy`/`approvedAt` 를 non-null 값으로 set → 거부.
- **정당 케이스 (통과해야 함 — 회귀 금지)**:
  - 브랜드 create: `status:'pending'`, 승인메타 null → 통과.
  - 브랜드 내용 update(핵심 수정): `status→'pending'`, `submittedBy/At` 갱신, `approvedBy/At` **보존(diff 미포함)** → 통과.
  - 브랜드 재제출(rejected→pending): 승인메타 보존 → 통과 (`leavingRejectedClearsApproval` 미적용 확인).
  - 브랜드 운영 update: visible/soldOut 등만 변경, **현재 status 가 approved 여도 status 미변경 → 통과**.
  - 오버라이드: 브랜드 `upsertOverrideCore`(priceOverride+pending) create/update → 통과. 점주 품절 토글 upsert / 제외 시드 → 통과(점주 분기 불변).
  - admin approve/reject (V1/V2/V3) → 통과.
- **회귀 점검 포인트(기존 시나리오)**: `admin_menu_management`(마스터 메뉴 승인/반려), `store_category_optout`(오버라이드 제외 시드), `payment_price_authority`(PPA-1*/2*/3* 점주 오버라이드 가드), 브랜드 마스터 메뉴 생성·수정·재제출·운영수정·옵션그룹·가격오버라이드 플로우.
- **범위 확인**: V3 포함 여부(§D1), stores/menuItems 점주 분기 미포함(§D2)이 코드와 일치하는지 교차 확인.

---

## 사용자 확인 필요 (결정사항)

- **D1 — V3(`stores/{storeId}/menuItems`) 브랜드 분기 포함?** 백로그 검증 2곳(V1·V2)을 넘어 설계자가 식별한 **동일 class 의 구멍**이다(브랜드 매장 점포한정 메뉴를 브랜드가 자가승인). 같은 헬퍼로 0 추가비용에 닫히고, `entity_lifecycle.md §5.4` 가 이미 ⚠️ 로 지목해 둔 지점이다. **권고: 포함.** (제외 원하면 V1·V2 만 교정.)
- **D2 — `stores/{storeId}/menuItems` 의 점주(isStoreOwner) 분기는 이번에 손대지 않는다.** 가맹점주가 브랜드 매장 점포한정 메뉴(status=pending)를 Rules 상 직접 쓸 수 있어(앱 repo 는 role 로 막지만 Rules 는 아님) `status:'approved'` 자가승인 여지가 있다. 그러나 이 분기는 **개인 매장 점주의 정당한 `status:'approved'` 쓰기와 공유**되어, 구분하려면 `get(stores).brandId` 기반 분기(개인 vs 브랜드 매장)가 필요하다 — 성격이 다른 설계다. **권고: 별도 task 로 분리.** (backlog 에 등재 권고.)

---

## 완료 기준

- [ ] `firestore.rules` 에 `noSelfApproveOnCreate`/`noSelfApproveOnUpdate`(또는 동등) 추가.
- [ ] V1·V2 (및 D1 확정 시 V3) 브랜드 분기에 create/update 가드 적용, 점주 분기·delete·admin 전권 보존.
- [ ] 신규 get() 0개 — 두 헬퍼 자기완결 검증.
- [ ] 정당 플로우 회귀 없음(브랜드 create/수정/재제출/운영수정, 점주 오버라이드, admin approve/reject) — tester 논증.
- [ ] 악의 케이스(브랜드 자가승인 3종) 거부 — tester 논증.
- [ ] `data_ownership.md` §2.6·§2.8, `entity_lifecycle.md` §5.2·§5.4·§5.5 동기화.
- [ ] `implementation.md` 작성 완료.
- [ ] `test_report.md` 작성 완료 (하네스 부재 → 정적 리뷰 기반 명시).
- [ ] **Rules 배포는 사용자(`firebase deploy --only firestore:rules`)** — 체크리스트에 배포 안내 포함, developer/tester 는 배포하지 않음.

# 브랜드 권한 경계 교정 — 테스트 리포트 (1차)

검증 대상: 커밋 `7f5db1c` (D1·D2·D5 + 게이트 + 점검 callable·카드). 기준: `spec.md` · `design.md` · `implementation.md`, `docs/processes/data_ownership.md`.
방법: architect 가 이미 재실행한 자동 테스트(analyze 0 / flutter 447 / TS 86 / CF 97 / Rules 332 / flow 27, RM07 핀)는 **재실행하지 않았다.** 테스트가 못 보는 것만 봤다 — 에뮬레이터(Firestore + Functions)에 임시 스크립트(저장소 밖, 종료 후 삭제)로 벡터를 직접 쏘고, 코드를 독립 열거했다. 운영 Firestore 는 읽지도 쓰지도 않았다. 코드 수정·배포·commit 없음.

결과: **PASS 항목 다수 / FAIL 2 (Low, Low-Medium) / 보류 3 / 배포 차단 0.** 점주→브랜드 전환 전 구간은 깨지지 않는다.

## FAIL

### F-S1. [Low] `brands.submittedBy` 를 그 브랜드의 보유자가 임의 uid 로 바꿀 수 있어 `claimSubmittedBrand` 의 "소유 증명" 이 제3자에게 양도된다

- D1 의 전제는 "`brands.submittedBy == uid` 가 이 브랜드를 내가 제출했다는 증명" 이다. 그런데 `isBrandSelfUpdate` 의 화이트리스트에 `submittedBy` 가 있어(핵심 필드 수정 시 재제출 메타용) **보유자가 값을 아무 uid 로 쓸 수 있다.**
- 재현(에뮬레이터): 보유자 H 가 자기 브랜드의 `submittedBy` 를 아직 브랜드에 연결되지 않은 `role:'brand'` 계정 A 의 uid 로 update → 성공. A 가 `claimSubmittedBrand(H 의 브랜드)` → `{changed:true}` → A 가 그 브랜드의 `menuItems` 를 쓰기 성공.
- 영향: 외부 공격자의 권한 상승은 아니다(H 가 이미 보유자). 그러나 A 가 **동의 없이** 연결될 수 있다 — 게이트가 `submittedBy == uid` 인 브랜드가 1건이면 **사용자 조작 0 으로 자동 claim** 하므로, A 가 브랜드 탭을 여는 순간 남의 브랜드의 보유자가 되고 D4(교정은 admin 전용)에 따라 A 는 스스로 풀 수 없다. 좌석 공유·괴롭힘 경로.
- D1 이전에는 A 가 자기 `brandId` 를 아무 값으로 쓸 수 있었으므로 **순 개선**이다. 그러나 "증명 필드가 제3자가 쓸 수 있는 필드" 라는 구조는 이번 교정이 닫으려던 것과 같은 계열이다.
- 수정안: `isBrandSelfUpdate` 에서 `submittedBy` 변경을 "본인 uid 로의 설정만" 허용(`request.resource.data.get('submittedBy','') == uid()` 또는 diff 없음). 앱은 재제출 시 자기 uid 를 쓰므로 정상 흐름과 호환. 하네스에 RM 케이스 1개 추가.

### F-S2. [Low-Medium] `brandId` 는 있으나 브랜드 문서가 없는 계정(dangling)에 `브랜드 등록하기` 버튼이 남아 있어 고아 브랜드를 양산한다 — 게이트 밖의 두 번째 등록 진입점

- `BrandScaffold` 게이트는 `brandId` 가 **없는** 경우만 다룬다. `brandId` 가 있고 문서가 없으면(= `auditBrandLinks` 의 `dangling` 분류) `BrandInfoPage` 의 `myBrandProvider` 가 null → `_EmptyView` "**아직 브랜드가 등록되지 않았어요**" + `브랜드 등록하기` 버튼 → `BrandInfoFormPage(brand:null)` push.
- 결과(코드 + CF 에뮬레이터 대조): 등록 → `brands` 문서 create 성공 → `claimSubmittedBrand` 는 `users.brandId` 가 이미 다른 값이라 `failed-precondition`(스위치 `catch` 가 삼킴) → 폼은 push 된 라우트라 `_isEditMode == false` 분기에서 pop 도 안 되고(`ref.invalidate(brandLinkGateProvider)` 는 이 경로에선 마운트된 게이트가 없어 무의미) → 사용자는 같은 화면에서 다시 저장 가능 → **저장할 때마다 고아 브랜드 1건.**
- 문구도 거짓이다: 이 계정은 브랜드에 연결돼 있고 문서만 사라졌다.
- spec §4.2 의 dangling 조치("admin 이 `users.brandId` 삭제 → 사용자는 다시 `BrandInfoFormPage` 로 등록")는 **admin 교정 이후** 시나리오만 가정한다. 교정 전 구간의 화면이 설계 인벤토리(design §1, "브랜드 연결 상태") 4행에 없다 — R2 인벤토리 누락.
- 기준선(`dangling = 0`)에서는 현재 해당 계정이 없어 지금 터지지는 않는다. 브랜드 문서 삭제(admin 전용)가 한 번 일어나면 열린다.
- 수정안: `_EmptyView` 를 `brandId` 보유 여부로 분기 — 보유 시 "연결된 브랜드를 찾지 못했어요. 관리자에게 문의해 주세요"(등록 버튼 없음). 가드 테스트의 "폼은 한 곳" 단언을 `BrandInfoFormPage(brand: null)` **lib 전체 grep** 으로 확장(현재는 `brand_id_missing_view.dart` 한 파일만 봐서 두 번째 호출 지점 `brand_info_page.dart:439` 를 못 잡는다).

## 확인한 것 (PASS)

### 1. 점주→브랜드 전환 전 구간 — PASS (배포 가능 판정)
- `test_rules/flow.test.mjs` 는 **실제 `firestore.rules`**(rules-unit-testing 클라이언트 SDK)와 **실제 `claimSubmittedBrand`**(Functions 에뮬레이터 HTTP)를 같은 세션에서 이어 호출한다. 점주·고객 두 출신 각각 10단계(전환 → 권한 0 → 구방식 batch 거부·고아 0 → 신방식 브랜드 1건 → 제출자 조회 → claim·멱등 → 권한 정상 → 승인 → 가맹 매장 등록(D5) → 핵심 수정 pending 회귀 → 반려·재제출 → 자기 brandId 변경 거부).
- 하네스 쓰기 맵이 실제 앱과 어긋나는지 대조: `BrandModel.toFirestore` 는 `set(merge:true)` 로 `submittedBy`·`status:'pending'`·`brandKey:''` 등을 보내고 Qoin 관리 필드는 보내지 않는다(Rules 의 brands create 조건과 합치). 역할 전환은 `UserRemoteDataSource` 의 `update({'role': role})` 한 줄로 flow 1단계와 동일. 앱이 `users.brandId` 를 쓰는 경로는 `lib/data` 에 없다(grep + 가드).
- 리전: `BrandRemoteDataSource` 가 `asia-northeast3`, CF `REGION` 과 일치.

### 2. `claimSubmittedBrand` — PASS (에뮬레이터 직접 호출)
| 케이스 | 결과 |
|---|---|
| 내 pending 브랜드 | `{changed:true}` |
| 같은 호출 재시도 | `{changed:false}` (멱등) |
| **5동시 호출** | `changed:true` 1건 + `roleHistory` **문서 정확히 1건** |
| 남의 승인 브랜드 / `submittedBy` 부재 브랜드 | `PERMISSION_DENIED` |
| 이미 다른 브랜드에 연결된 계정 | `FAILED_PRECONDITION` |
| `role != 'brand'` | `FAILED_PRECONDITION` |
| `brandId: ''` 인 brand 계정 | 미연결로 보고 연결 성공 |
| 없는 브랜드 / `a/b` / 비로그인 | `NOT_FOUND` / `INVALID_ARGUMENT` / `UNAUTHENTICATED` |
- 보류 H-S3: Dart `_classify` 가 모든 `failed-precondition` 을 `alreadyLinked`("이 계정은 이미 다른 브랜드에 연결돼 있어요")로 매핑한다. CF 는 `role != 'brand'` 에도 같은 코드를 쓰므로 그 드문 경우 문구가 틀리고 재시도 버튼도 없다. `not-found`(브랜드 삭제) 는 `retryable` 이라 무한 재시도 가능.

### 3. D1·D2·D5 벡터 직접 타격 — 전부 의도대로 (약 30건; 예상과 다르게 나온 1건은 내 프로브의 시드 오류였고 정정 후 재확인)
- `users.brandId` 쓰기: 자가 update / `set merge` / `role+brandId` 동시 / full replace / dotted / 타 uid 문서 / `roleHistory` 위조 batch / 본인 문서 삭제 → 전부 거부.
- 브랜드 문서: 남의 브랜드 `submittedBy` 변경·`set merge` 덮어쓰기·하위 컬렉션 쓰기 거부, 타인 uid 로 `submittedBy` 위조한 create 거부, 본인 pending create 허용.
- D2 공백 매칭: `brandId` 필드 부재·`''`·`null` 매장에 대해 `role:'brand'`(brandId 없음) 계정의 `menuOverrides` 쓰기·매장 핵심/운영 필드 update·`qoinRateHistory` 읽기 거부.
- D5: pending 브랜드·없는 브랜드·`''`·숫자·`status` 필드 없는 브랜드 지정 거부, `null` 허용, 남의 approved 브랜드 지정은 허용(RM18 로 의도 고정), 생성 후 `brandId` 변경 거부, `status:'approved'` 로 create 거부.

### 4. 21번째 경로 — 새 보호 필드 경로는 없다. 단 증명 필드 양도(F-S1)가 있다
- 2차에서 센 20경로(보호 필드 5 × {stores, brands} × {create, update})는 이번 커밋이 필드를 늘리지 않았고 `firestore.rules` 의 해당 블록은 `7f5db1c` 에서 변하지 않았다(Rules 변경은 선행 커밋 `85dd417`/`db75d7a` 에 들어갔다). 그대로 20.
- 이번 task 의 권한 값 `users.brandId` 와 `stores.brandId` 의 쓰기 도달 경로를 처음부터 다시 열거: `users` create(`'brandId' in` 금지) / update(admin 전권 · self 화이트리스트에 없음) / delete(admin) / `claimSubmittedBrand`(Admin SDK) · `stores` create(D5) / update(admin · 점주 운영 필드 — brandId 불변 · 브랜드 보유자 분기 — brandId 제외) / delete(점주·admin, 삭제 후 재생성은 pending 시작·D5 통과 필요). **직접 쓰기 경로는 닫혀 있다.** 21번째 "필드 쓰기" 경로는 없다.
- 단 `claimSubmittedBrand` 가 믿는 `brands.submittedBy` 에는 쓰기 경로가 하나 더 있다(보유자 self-update) → F-S1. 이게 사실상 21번째 경로(증명 값 변조)다.

### 5. `auditBrandLinks` 쓰기 0 — PASS
- 코드: Firestore 쓰기 호출 없음(`.set(`·`.add(` 매치는 전부 `Map`/`Set`). 요청 인자 자체를 읽지 않는다. `requireAdmin` 선행.
- 에뮬레이터: 비-admin `PERMISSION_DENIED`, 비로그인 `UNAUTHENTICATED`. (developer 의 CF7 은 호출 전후 문서 지문 동일을 이미 단언한다 — 재실행 안 함.)
- Dart 쪽 데이터소스도 callable 하나뿐.

### 6. 운영 기준선(§11) 대조 — PASS (구현 쪽), 해석 주의 1건
- 기준선 모사(brand 계정 2 = 제출자 일치, 브랜드 3개 중 시드 1개 미참조, 매장 일부): `ok 2` · `orphan_brand` = 미참조 브랜드 · 나머지 0 으로 분류됨을 코드 읽기 + 에뮬레이터 소규모 모사로 확인. `duplicate` 계정은 `ok` 에서 제외(이중 계수 없음).
- `orphan_brand` 정의는 구현(미참조 전부 + status 동봉)이 §4.2 의 조치 대상(pending 미참조)을 포함하므로 맞고 **spec §4.1 문장이 틀렸다** (Qoin 3차 리포트 작업표 #3).
- **해석 주의(H-S4):** `status` 필드가 없는 브랜드를 가리키는 매장은 `store_unapproved_brand` 로 분류된다(화면·Rules 와 일치, 정상). 시드 브랜드 `phase3_seed_brand_001` 이 `status` 를 안 갖고 그 브랜드를 가리키는 시드 매장이 있으면 기준선 0 이 아니라 1 로 나온다 — 구현 오류가 아니라 시드 데이터 상태다.

### 7. 게이트 `BrandIdMissingView` — PASS
조회 전·실패·연결 실패에서 폼 없음(위젯 테스트 + 코드), 진입당 자동 claim 1회, 2건 이상은 가장 이른 `submittedAt` 1건 + SnackBar. 가드 테스트는 `brand_id_missing_view.dart` 에서만 폼 호출 1건을 단언한다(F-S2 가 보여주듯 다른 파일의 호출은 못 본다).
- 보류 H-S5: `BrandScaffold` 는 프로필 스트림이 **로딩 중**(`asData?.value == null`)이어도 `brandId == null` 로 보고 게이트를 그린다. 정상 브랜드 계정도 앱 시작 직후 한 프레임 동안 게이트 화면(과 조회·멱등 claim 1회)을 거친다. 이전엔 같은 조건에서 등록 폼이 깜박였으므로 퇴행은 아니다. `submittedAt` 은 핵심 필드 수정 때마다 갱신돼 "가장 이른" 의 의미가 흔들릴 수 있다(`createdAt` 이 더 안정적).

## 보류
- H-S3 claim 오류 매핑(위), H-S4 기준선 해석(위), H-S5 게이트 깜박임·정렬 기준(위).

## 우선순위
1. F-S2 (등록 버튼) — 화면 분기 하나 + 가드 확장.
2. F-S1 (`submittedBy` 양도) — Rules 한 줄 + RM 케이스. 배포 전에 닫는 편이 낫지만 차단 사유는 아니다.
3. H-S3.

## 배포 판단
점주→브랜드 전환 전 구간은 실제 Rules + 실제 CF 로 끝까지 통과한다. D1·D2·D5 의 직접 쓰기 경로는 닫혀 있고 점검 callable 은 쓰기 0 이다. **배포를 막는 FAIL 없음.** F-S1·F-S2 는 같은 창에서 닫기를 권고한다.

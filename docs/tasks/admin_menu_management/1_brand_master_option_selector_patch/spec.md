# sub-phase 1 — 마스터 메뉴 옵션 그룹 선택 UI 보강 (patch)

> **상태**: APPROVED — architect 작성 완료
>
> **본 patch 의 위상**: sub-phase 1 (`1_brand_master`) 가 완료된 후 발견된 **누락된 UI 연결**을 보강하는 후속 작업. sub-phase 1 의 spec / design / implementation / test_report 와 결정사항(특히 결정 J, S2)은 그대로 유지하며, 본 patch 는 그 결정을 충족시키기 위해 빠진 UI 와 provider 만 추가한다.
>
> **상위 단일 진실원**:
> - 데이터 모델 / 결정 1~12 / 결정 A~F / 결정 G/H/I → [`../spec.md`](../spec.md)
> - 결정 J (핵심/운영 필드 분리), S2 (마스터 메뉴 옵션 그룹 scope=master 만 허용), 마스터 메뉴 폼 구조 → [`../1_brand_master/spec.md`](../1_brand_master/spec.md)
>
> **이 patch 는 새 결정을 만들지 않는다**. 위의 단일 진실원을 그대로 따른다.

---

## 개요

- **목적**: brand 의 마스터 메뉴 등록/편집 폼([`master_menu_form_page.dart`](../../../../lib/presentation/brand/master_menu/master_menu_form_page.dart)) 에 **옵션 그룹 다중 선택 UI** 를 추가해 등록/수정 시 `optionGroupRefs` 를 사용자가 직접 구성할 수 있게 한다. 동시에 brand 측에 owner 와 동등한 `masterOptionGroupsProvider` 를 추가한다.
- **작업 유형**: 기존 기능 수정 (UI 연결 보강 — 누락된 위젯 통합 + provider 1개 추가)
- **배경 / 누락 사실**:
  1. sub-phase 1 에서 [`OptionGroupSelector`](../../../../lib/presentation/brand/master_menu/widgets/option_group_selector.dart) 위젯은 작성됐으나 `master_menu_form_page.dart` 가 **import 도 안 했고 폼에 배치도 안 됐다**.
  2. 폼 line 181 의 `optionGroupRefs: baseItem?.optionGroupRefs ?? []` 로 인해 **수정 모드에서는 기존 값 보존, 신규 등록 모드에서는 항상 빈 배열** 이 저장된다. 사용자가 옵션 그룹을 선택할 UI 자체가 없다.
  3. owner 측에는 [`masterOptionGroupsProvider`](../../../../lib/presentation/owner/providers/owner_store_menu_providers.dart#L81) 가 만들어져 있지만, brand 측에는 동등 provider 가 없다.
  4. Firestore `optionGroups/{id}` 에 master 시드 (`og_master_shot`, `og_master_syrup`, `og_master_temperature`) 가 들어있지만 brand 폼에서 선택할 수단이 없어 비활용 상태.
- **상위 결정과의 관계**:
  - sub-phase 1 의 **검증 항목** "옵션 그룹 picker 에서 store scope 미노출" (1_brand_master/spec.md L546) 이 검증 불가능했다. 본 patch 가 이를 충족시킨다.
  - sub-phase 1 의 **S2 (마스터 메뉴 옵션 그룹 참조 가드)** — UI 단계에서 store scope 미노출 + Repository 단계에서 `optionGroupRefs.every(scope==master)` 검증의 두 방어선 중, 후자(Repository)는 이미 구현됐고 전자(UI)가 누락 상태였다. 본 patch 가 UI 방어선을 채운다.
  - sub-phase 1 의 **결정 J (핵심/운영 필드 분리)** — `optionGroupRefs` 는 핵심 필드. 폼에서 사용자가 옵션 그룹을 변경하면 `_hasCoreFieldChange` ([`master_menu_form_page.dart` L118-122](../../../../lib/presentation/brand/master_menu/master_menu_form_page.dart#L118)) 가 이를 감지해 `updateMasterMenuItemCore` 분기로 가서 status=pending 회귀가 일어나야 한다. 본 patch 는 이 흐름을 그대로 살리며 추가 변경을 하지 않는다.
  - sub-phase 5 (점주 옵션/품절 토글) 는 마스터 메뉴에 옵션 그룹이 실제로 묶여 있어야 검증 가능하므로, 본 patch 가 sub-phase 5 진입 조건이 된다.
- **영향 범위**:
  - 화면: `MasterMenuFormPage` 1개. 등록/수정/복제 모드 모두 영향. 다른 brand 화면 / admin 화면 / customer / owner 화면 변경 없음.
  - Domain: 변경 없음 (`MenuItemEntity.optionGroupRefs` / `OptionGroupRef` / `OptionScope` 그대로 사용).
  - Data: 변경 없음. 기존 `OptionRemoteDataSource.fetchAllMaster()` 재사용. `MasterMenuItemRepositoryImpl` 의 S2 검증도 그대로.
  - Presentation:
    - **신규**: 마스터 옵션 그룹 stream/future provider 1개 (위치는 아래 [레이어 설계](#레이어-설계) 의 결정사항 참조).
    - **수정**: `MasterMenuFormPage` — import 추가 + `_selectedOptionGroupIds` 상태 추가 + initState prefill + build 본문에 `OptionGroupSelector` 배치 + submit 시 `optionGroupRefs` 매핑.
  - 라우팅 / 권한 / 환경 설정: 변경 없음.
  - 테스트: sub-phase 1 회귀 (status pending 회귀 / 핵심 필드 분리) + sub-phase 5 진입 가능성 확인.
- **비범위**:
  - 옵션 그룹 CRUD UI (등록/편집/삭제) → sub-phase 7 (별도 phase `admin_option_group_management`).
  - master 옵션 그룹의 brandId 분리 정책 → sub-phase 7 에서 결정.
  - store-scope 옵션 그룹 (마스터 메뉴 폼은 master scope 만. owner 측 매장 메뉴 폼은 master + store 양쪽 — 본 patch 는 마스터 메뉴 폼만 다룬다).
  - 옵션 그룹 빈 상태에서의 신규 등록 가이드 다이얼로그 → 후속 UX 개선.
  - `optionGroupRefs` 의 displayOrder 재정렬 UI → 추후 결정.

---

## 의존 phase / 진입 조건

- **의존 phase**: `1_brand_master` 완료 (현재 완료. spec/design/implementation/test_report 모두 존재).
- **진입 조건**:
  - sub-phase 1 의 마스터 메뉴 폼 / Repository / UseCase 가 정상 동작.
  - Firestore `optionGroups/{id}` 에 master 시드 데이터 1건 이상 존재 (`og_master_shot`, `og_master_syrup`, `og_master_temperature` 시딩 완료 — 본 patch 검증 단계에서도 활용).

---

## 요구사항

### 기능 요구사항

- [ ] brand 의 `MasterMenuFormPage` 에서 master 옵션 그룹 목록을 불러와 다중 선택할 수 있다.
- [ ] 등록 모드: 선택된 옵션 그룹 ID 들이 `optionGroupRefs: [{scope:'master', id}]` 로 변환되어 Repository 에 전달된다.
- [ ] 수정 모드: 기존 `optionGroupRefs` 가 폼 진입 시 prefill 되고, 사용자가 선택을 바꾸면 변경된 결과가 저장된다.
- [ ] 복제 모드: 원본의 `optionGroupRefs` 가 prefill 되고 사용자가 자유롭게 수정/저장 가능하다.
- [ ] 변경 감지 정합성: `_hasCoreFieldChange` 가 옵션 그룹 ID 셋 변경을 감지해 `updateMasterMenuItemCore` (status=pending 회귀) 로 분기한다 — 이 동작은 이미 구현되어 있으므로 회귀가 발생하지 않아야 한다.
- [ ] S2 (마스터 메뉴 옵션 그룹 scope=master 만 허용) — 폼에 store scope 옵션 그룹은 절대 노출하지 않는다. `OptionGroupSelector(storeId: null)` 호출로 `_buildWithSections()` 분기가 트리거되지 않게 한다.

### UI 요구사항

- [ ] 폼 본문에 "옵션 그룹" 섹션 헤더 + `OptionGroupSelector` 배치.
- [ ] 배치 위치는 designer 가 확정 (잠정안: 카테고리 ↔ 태그 사이 또는 노출 순서 ↔ 폼 끝 사이 — designer 결정).
- [ ] 빈 상태: master 옵션 그룹이 0건이면 `OptionGroupSelector` 의 기본 메시지 ("등록된 옵션 그룹이 없어요") 그대로 표시. 별도 다이얼로그/CTA 없음 (본 patch 비범위).
- [ ] 로딩 상태: `masterOptionGroupsProvider` 가 `loading` 인 동안 폼은 그대로 표시하되 옵션 그룹 영역만 스켈레톤/플레이스홀더 또는 미세 로딩 인디케이터 (디자이너 결정. 잠정안: 인디케이터 없이 빈 영역 후 자연스럽게 채워짐 — owner 패턴과 동일).
- [ ] 에러 상태: provider 가 error 면 옵션 그룹 영역에 "옵션 그룹을 불러오지 못했어요" 메시지 + 재시도 버튼 (필요 시 디자이너 결정. 잠정안: owner 와 동일하게 빈 배열로 fallback — 명시적 에러 UI 없음).

### 상태 요구사항

- [ ] loading: `masterOptionGroupsProvider` 의 `AsyncLoading` — 위 UI 요구사항.
- [ ] error: `AsyncError` — 위 UI 요구사항.
- [ ] empty: master 옵션 그룹 0건 — 위 UI 요구사항.

---

## 데이터 모델

### Entity / DTO 변경 없음

- `MenuItemEntity.optionGroupRefs: List<OptionGroupRef>` — 기존 그대로 사용.
- `OptionGroupRef({required OptionScope scope, required String id})` — 기존 그대로.
- `OptionScope { master, store }` — 기존 그대로. 본 patch 는 항상 `master` 로만 매핑.

### Firestore

- 변경 없음. `optionGroups/{id}` (master) 컬렉션 그대로 읽기.
- `brands/{brandId}/menuItems/{menuItemId}.optionGroupRefs` — 변경 없음. S2 의 scope=master 보장.

---

## 레이어 설계

### Domain

변경 없음.

### Data

변경 없음. 기존 `OptionRemoteDataSource.fetchAllMaster()` ([`option_remote_data_source.dart` L43-49](../../../../lib/data/datasources/remote/option_remote_data_source.dart#L43)) 재사용.

### Presentation

#### 신규 Provider

**위치 결정**: 별도 파일 `brand_option_providers.dart` 를 신규 생성하지 않고, 기존 `brand_master_menu_providers.dart` 에 추가한다.

- **이유**:
  1. 마스터 메뉴 폼이 유일한 사용처. 다른 brand 화면이 마스터 옵션 그룹을 직접 사용하는 케이스가 없다 (sub-phase 7 의 옵션 그룹 CRUD 는 별도 phase 이며 그때 `brand_option_providers.dart` 를 신규 분리해도 늦지 않다).
  2. owner 측 [`owner_store_menu_providers.dart` L78-95](../../../../lib/presentation/owner/providers/owner_store_menu_providers.dart#L78) 도 같은 패턴 — 옵션 그룹 provider 를 menu provider 파일과 같이 둠.
  3. brand 측은 마스터 메뉴 외에는 옵션 그룹을 쓸 일이 없으므로 별도 파일로 분리하면 오히려 진입 비용이 늘어난다.

```dart
// lib/presentation/brand/providers/brand_master_menu_providers.dart 에 추가

import 'package:qradar/data/datasources/remote/option_remote_data_source.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';

// ── DataSource ────────────────────────────────────────────────────────────
//
// 본 파일에 옵션 DataSource provider 를 두는 게 위 (1) 의 단일 사용처 원칙과 정합.
// 동일 instance 를 다른 곳에서 공유할 필요 없음 (sub-phase 7 진입 시 brand_di_providers
// 또는 신규 brand_option_providers 로 승격 가능).
final _brandOptionRemoteDataSourceProvider =
    Provider<OptionRemoteDataSource>((_) => OptionRemoteDataSource());

// ── 옵션 그룹 ─────────────────────────────────────────────────────────────

/// 전역(master) 옵션 그룹 목록. 마스터 메뉴 폼의 OptionGroupSelector 에 사용.
///
/// owner 측 masterOptionGroupsProvider 와 동일 패턴.
/// brand 측에서는 master scope 만 사용 (S2 — 마스터 메뉴 옵션 그룹은 master 만 허용).
final brandMasterOptionGroupsProvider =
    FutureProvider<List<OptionGroupEntity>>((ref) async {
  final ds = ref.watch(_brandOptionRemoteDataSourceProvider);
  final models = await ds.fetchAllMaster();
  return models.map((m) => m.toEntity()).toList(growable: false);
});
```

> **명명 결정**: `masterOptionGroupsProvider` (owner 측과 동일 이름) 이 아니라 **`brandMasterOptionGroupsProvider`** 로 한다.
>
> - 이유: import alias 없이 두 provider 가 같은 이름이면 정적분석 / 자동완성에서 혼동 위험. brand 측은 brand 라는 prefix 로 명시적으로 분리.
> - owner 측 `masterOptionGroupsProvider` 는 그대로 유지 — 본 patch 는 owner 코드 무변경.

#### 수정 Page — `MasterMenuFormPage`

[`lib/presentation/brand/master_menu/master_menu_form_page.dart`](../../../../lib/presentation/brand/master_menu/master_menu_form_page.dart) 에 다음 변경을 가한다.

##### 변경 1. import 추가

```dart
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/presentation/brand/master_menu/widgets/option_group_selector.dart';
```

##### 변경 2. 상태 필드 추가

```dart
class _MasterMenuFormPageState extends ConsumerState<MasterMenuFormPage> {
  // 기존 필드 ...

  // 신규: 선택된 옵션 그룹 ID 목록 (S2 — 항상 master scope)
  List<String> _selectedOptionGroupIds = [];
}
```

##### 변경 3. initState prefill

```dart
@override
void initState() {
  super.initState();
  final source = widget.editItem ?? widget.sourceForClone;
  // 기존 prefill ...

  // 신규: optionGroupRefs prefill — 등록 모드면 빈 배열, 수정/복제 모드면 source 의 ID 추출
  _selectedOptionGroupIds =
      source?.optionGroupRefs.map((r) => r.id).toList() ?? [];
}
```

##### 변경 4. build 본문에 `OptionGroupSelector` 배치

```dart
// build() 내부
final masterGroups =
    ref.watch(brandMasterOptionGroupsProvider).asData?.value ?? [];

// ...

// 폼 본문 섹션 추가 (구체 위치는 designer 결정)
_divider(),
_sectionLabel('옵션 그룹'),
const SizedBox(height: 8),
OptionGroupSelector(
  optionGroups: masterGroups,
  // storeId 누락 → master only 분기 (S2 보장)
  selectedIds: _selectedOptionGroupIds,
  onChanged: (ids) => setState(() => _selectedOptionGroupIds = ids),
),
```

> **호출 시 `storeId` 미전달 — S2 보장**: `OptionGroupSelector` 는 `storeId == null` 이면 `_buildWithSections()` 분기 없이 master only 리스트만 렌더링한다 ([`option_group_selector.dart` L48-69](../../../../lib/presentation/brand/master_menu/widgets/option_group_selector.dart#L48)). 본 patch 는 storeId 를 절대 전달하지 않는다.

##### 변경 5. submit 시 `optionGroupRefs` 매핑

기존 line 181 의 `optionGroupRefs: baseItem?.optionGroupRefs ?? [],` 를 다음으로 교체.

```dart
optionGroupRefs: _selectedOptionGroupIds
    .map((id) => OptionGroupRef(scope: OptionScope.master, id: id))
    .toList(),
```

> **호환성 가드**: `OptionGroupRef` / `OptionScope` 는 `lib/domain/entities/option_group_entity.dart` 에 정의되어 있으므로 import 추가 필요. 매핑 시 항상 `master` scope 강제 — Repository 의 S2 검증과 이중 방어선.

##### 변경 6. `_hasCoreFieldChange` 회귀 영향 확인 — 변경 없음

[L118-122](../../../../lib/presentation/brand/master_menu/master_menu_form_page.dart#L118) 의 옵션 그룹 변경 감지 로직은 이미 ID 셋 비교를 한다. 본 patch 가 `optionGroupRefs` 를 실제로 변경할 수 있게 만들었으므로, 변경이 감지되면 `updateMasterMenuItemCore` 분기로 가서 status=pending 회귀가 일어난다 — sub-phase 1 결정 J 의 의도대로.

> **혼합 케이스 동작**: 한 폼에서 optionGroupRefs (핵심) + visible (운영) 을 동시에 변경 → `_hasCoreFieldChange` true → `updateMasterMenuItemCore` 우선. sub-phase 1 의 결정과 동일.

#### 수정하지 않는 항목

- `MasterMenuFormPage` 의 nav / appbar / submit 버튼 / 가격 변경 다이얼로그 / 이미지 업로드 / 카테고리 / 태그 / visibility / displayOrder — 변경 없음.
- `master_menu_list_page.dart` / `master_menu_detail_page.dart` — 변경 없음. 이미 `optionGroupRefs` 를 노출함.
- owner / customer / admin 화면 — 변경 없음.

---

## 데이터 흐름

### 마스터 메뉴 등록 (옵션 그룹 선택)

```text
MasterMenuFormPage 진입 (등록 모드)
  → ref.watch(brandMasterOptionGroupsProvider)
  → OptionRemoteDataSource.fetchAllMaster()
  → optionGroups/{id} 컬렉션 fetch
  → List<OptionGroupEntity> (scope=master)
  → OptionGroupSelector 에 표시
  → 사용자 다중 선택 → _selectedOptionGroupIds 갱신
  → submit
  → optionGroupRefs = [{scope:'master', id}, ...] 매핑
  → CreateMasterMenuItemUseCase
  → MasterMenuItemRepositoryImpl: scope=master 검증 (S2) 통과 + status=pending 강제
  → Firestore brands/{brandId}/menuItems/{newId} set
```

### 마스터 메뉴 수정 (옵션 그룹 변경 — 핵심 필드 회귀)

```text
MasterMenuFormPage 진입 (수정 모드, editItem 전달)
  → initState: _selectedOptionGroupIds = editItem.optionGroupRefs.map((r) => r.id)
  → 사용자 옵션 그룹 추가/제거
  → submit
  → 변경 필드 분석: _hasCoreFieldChange (optionGroupRefs ID 셋 다름) → true
  → 가격 변경이 함께 있으면 가격 변경 다이얼로그 (기존 흐름)
  → updateMasterMenuItemCoreUseCaseProvider
  → MasterMenuItemRepository.updateMasterMenuItemCore
  → Firestore: status=pending 회귀, submittedBy/At 갱신, approvedBy/At 보존
  → admin 승인 큐 진입 → "수정 대기" 라벨
```

### 마스터 메뉴 수정 (옵션 그룹 무변경, 운영 필드만 변경)

```text
사용자가 옵션 그룹은 그대로 두고 visible 만 토글
  → submit → _hasCoreFieldChange false, _hasOperationFieldChange true
  → updateMasterMenuItemOperationUseCaseProvider (status 보존, 즉시 반영)
```

이 흐름은 sub-phase 1 에서 이미 구현됨. 본 patch 가 변경하지 않는다.

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| `brandMasterOptionGroupsProvider` 로딩 중 | `OptionGroupSelector` 영역 비어있음 (owner 패턴 동일). 폼 자체는 즉시 사용 가능 |
| `brandMasterOptionGroupsProvider` 에러 (네트워크) | `asData?.value ?? []` 폴백. 옵션 그룹 영역에 "등록된 옵션 그룹이 없어요" 메시지 (기본 OptionGroupSelector empty UI) |
| master 옵션 그룹 0건 | `OptionGroupSelector` 의 빈 상태 메시지 그대로. 등록은 옵션 없이도 진행 가능 (sub-phase 1 비즈니스 규칙) |
| 사용자가 선택한 옵션 그룹이 동시에 삭제됨 (sub-phase 7 진입 후 가능) | sub-phase 7 의 cascade 정책에 따름 — 본 patch 비범위 |
| 옵션 그룹 ID 셋 변경 → status=pending 회귀 | 사용자 안내: 기존 가격 변경 다이얼로그 흐름 외 추가 다이얼로그 없음. 제출 후 SnackBar "수정 사항이 검토 대기 중입니다" (기존 흐름 그대로) |
| S2 위반 (Firestore 에 직접 store scope ref 가 박힘) | UI 단계에서 발생 불가 (`storeId` 미전달). Repository 가 `ArgumentError` 로 차단. 본 patch 가 만드는 시나리오는 아님 |

---

## 작업 분배

### designer 호출 — **필요 (권장)**

UI 변경이 있으나 작은 범위. 다만 다음은 designer 가 확정해야 한다.

- **UI 변경 필요 여부**: O
- **디자인 산출물**: `docs/tasks/admin_menu_management/1_brand_master_option_selector_patch/design.md`
- **전달할 사항**:
  1. `OptionGroupSelector` 의 폼 내 **배치 위치** — 후보:
     - (A) 카테고리 ↔ 태그 사이 (메뉴 정체성 그룹화 — 카테고리/옵션이 함께 신원을 결정)
     - (B) 노출 순서 ↔ 폼 끝 사이 (운영 항목 뒤, 추가 입력 그룹화)
     - (C) 가격 ↔ 카테고리 사이 (가격/옵션 인접 배치 — 옵션이 가격 변동 요소이므로)
     - architect 잠정 추천: (A) — 옵션 그룹은 "이 메뉴는 어떤 옵션을 가지는가" 라는 신원 정의에 가깝고, 결정 J 에서도 핵심 필드로 분류되어 있다.
  2. 섹션 헤더 라벨 — 잠정 "옵션 그룹". owner 폼과 동일 라벨 사용 권장.
  3. 빈 상태 / 로딩 / 에러 마이크로카피 — owner 패턴과 일관되게 가져갈지, brand 한정 카피를 만들지 결정.
  4. (선택) 옵션 그룹이 0건일 때 admin 에게 옵션 그룹 시드 요청을 안내하는 텍스트를 추가할지 결정 — 본 patch 비범위로 잠정 처리.

### developer 호출

designer 완료 후. 의존 순서: Provider 추가 → Page 통합.

- **구현 항목**:
  1. `brand_master_menu_providers.dart` 에 `_brandOptionRemoteDataSourceProvider` + `brandMasterOptionGroupsProvider` 추가.
  2. `master_menu_form_page.dart` 에 import + `_selectedOptionGroupIds` 상태 + initState prefill + build 본문 `OptionGroupSelector` 배치 + submit 시 `optionGroupRefs` 매핑.
  3. `flutter analyze` 0 issue.
- **재사용할 기존 구조**:
  - owner 측 `masterOptionGroupsProvider` 패턴 ([`owner_store_menu_providers.dart` L81-86](../../../../lib/presentation/owner/providers/owner_store_menu_providers.dart#L81)).
  - owner 측 `OptionGroupSelector` 통합 패턴 ([`owner_store_menu_form_page.dart` L455-462](../../../../lib/presentation/owner/store_menu/owner_store_menu_form_page.dart#L455)).
  - 기존 `OptionRemoteDataSource.fetchAllMaster()`.
  - 기존 `_hasCoreFieldChange` (옵션 그룹 ID 셋 비교) — 변경 없이 동작.
- **주의할 레이어 규칙**:
  - `OptionRemoteDataSource` 는 data 레이어 — provider 에서만 import. presentation 의 다른 위치에서 직접 사용 X.
  - `OptionGroupRef` / `OptionScope` 는 domain 레이어 — UI 가 직접 import OK (단방향 — presentation → domain).
  - 매핑 시 항상 `OptionScope.master` 강제 (본 patch 의 핵심 invariant — S2 보장).
- **build_runner 영향**: 없음 (freezed/json_serializable 갱신 없음).

### tester 호출

developer 완료 후. `test_report.md` 작성.

---

## 검증 항목 (tester 가 확인할 PASS/FAIL 후보)

### 신규 기능

- [ ] **신규 등록 + 옵션 그룹 선택**: 마스터 메뉴 신규 등록 시 옵션 그룹 다중 선택이 가능하다. 저장 후 Firestore `brands/{brandId}/menuItems/{newId}.optionGroupRefs` 에 `[{scope:'master', id}]` 가 저장된다.
- [ ] **수정 모드 prefill**: 기존 마스터 메뉴 (옵션 그룹 1건 이상 묶인 메뉴) 를 수정 모드로 열면 OptionGroupSelector 가 해당 옵션 그룹들을 선택 상태로 표시한다.
- [ ] **수정 모드 — 옵션 그룹 변경 → 핵심 필드 회귀**: 수정 모드에서 옵션 그룹을 추가/제거 후 저장하면 `_hasCoreFieldChange` 가 true 가 되고, `updateMasterMenuItemCore` 가 호출되어 Firestore status 가 `pending` 으로 회귀한다 (`approvedBy/At` 보존).
- [ ] **수정 모드 — 옵션 그룹 무변경**: 옵션 그룹은 그대로 두고 visible 만 토글하면 `_hasCoreFieldChange` false, `updateMasterMenuItemOperation` 호출, status 보존.
- [ ] **혼합 변경**: 옵션 그룹 추가 + visible 토글 동시 → 핵심 필드 우선 → `updateMasterMenuItemCore` → status=pending 회귀.
- [ ] **복제 모드 prefill**: 복제 모드에서 원본의 옵션 그룹이 prefill 되고, 수정 가능. 저장 시 신규 메뉴로 생성됨.
- [ ] **빈 상태**: master 옵션 그룹 0건일 때 `OptionGroupSelector` 의 빈 상태 메시지 ("등록된 옵션 그룹이 없어요") 가 표시된다. 폼은 옵션 없이 저장 가능.
- [ ] **S2 가드 (UI)**: `OptionGroupSelector` 가 store scope 옵션 그룹을 노출하지 않는다 (storeId 미전달 → master only 분기 트리거).
- [ ] **S2 가드 (Repository)**: 만약 누군가 임의로 `optionGroupRefs` 에 `scope:'store'` 를 박아서 호출해도 Repository 가 `ArgumentError` 로 차단 (sub-phase 1 회귀 확인).
- [ ] **옵션 그룹 적용 후 customer / owner 측 머지**: brand 가 옵션 그룹을 묶어 등록 + admin 승인 → 매장(brand 매장) 에 자동 동기화 → owner 의 매장 메뉴 리스트에서 해당 메뉴가 옵션과 함께 노출 → customer 측 매장 메뉴 상세에서 옵션 선택 UI 가 동작 (sub-phase 5 진입 가능 검증).

### 회귀 (sub-phase 1 무영향)

- [ ] sub-phase 1 의 마스터 메뉴 등록 / 수정 / 복제 / 삭제 회귀 테스트 통과.
- [ ] 결정 J — 핵심/운영 필드 분리 동작 회귀:
  - 핵심 필드 (name / basePrice / mainCategoryCode / subCategoryId / description / **optionGroupRefs**) 변경 시 status=pending 회귀.
  - 운영 필드 (visible / tags / displayOrder / imageUrl) 변경 시 status 보존.
- [ ] 가격 변경 다이얼로그 (basePrice 변경 시) 동작 그대로.
- [ ] admin 승인 큐 — "수정 대기" 라벨이 옵션 그룹 변경된 메뉴에도 정상 노출.
- [ ] customer / owner / 시드 매장 무영향.
- [ ] `flutter analyze` 0 issue.

### 사용자 검증 (수동)

- [ ] **점주 매장 자동 동기화**: brand 가 옵션 그룹을 묶어 마스터 메뉴 등록 → admin 승인 → 같은 brand 의 매장 (점주 화면) 의 매장 메뉴 리스트에 해당 메뉴가 옵션과 함께 자동으로 동기화되어 노출.
- [ ] **점주 옵션 토글 (sub-phase 5 진입 가능 확인)**: 점주가 매장 메뉴 상세 → 옵션 그룹의 특정 옵션을 비활성 토글 → customer 측에서 해당 옵션이 비활성 표시. (sub-phase 5 의 본격 검증은 별도지만, 본 patch 가 sub-phase 5 의 진입 조건을 충족시키는지 확인하는 smoke test).

---

## 결정 J 와의 관계 (재서술 X — 단일 진실원 그대로)

`optionGroupRefs` 는 sub-phase 1 의 결정 J 에서 **핵심 필드** 로 분류됐다 (단일 진실원: [`../1_brand_master/spec.md` L92](../1_brand_master/spec.md)). 본 patch 는 이 분류를 그대로 따르며 추가 결정을 만들지 않는다.

- 폼의 `_hasCoreFieldChange` 가 옵션 그룹 ID 셋 변경을 이미 감지 ([L118-122](../../../../lib/presentation/brand/master_menu/master_menu_form_page.dart#L118)) — 본 patch 가 그 입력값을 실제로 채워 넣는 것뿐.
- Repository 의 `updateMasterMenuItemCore` 분기 (status=pending 회귀 + 승인 메타 보존) — 변경 없음.
- admin 승인 큐의 "수정 대기" 라벨 (`approvedAt != null` 시) — 변경 없음.

본 patch 후의 정상 동작은 sub-phase 1 검증 항목 "[ ] 마스터 메뉴 핵심 필드 변경 ... → status=pending 회귀 + approvedBy/At 보존" 에 **`optionGroupRefs` 변경 케이스가 비로소 검증 가능해진다**. sub-phase 1 의 test_report.md 에서 이 항목이 PASS 처리됐는지는 tester 가 재확인.

---

## 사용자 확인이 필요한 결정사항

architect 가 잠정 결정한 항목 — 사용자 / designer 가 확정해야 한다.

1. **provider 위치**: `brand_master_menu_providers.dart` 에 같이 두는 안 (architect 잠정안). 별도 `brand_option_providers.dart` 신규 생성하는 안도 가능. → **확정 필요**.
2. **provider 이름**: `brandMasterOptionGroupsProvider` (architect 잠정안). owner 측 `masterOptionGroupsProvider` 와 동일 이름으로 가도 import alias 로 충돌 회피 가능. → **확정 필요**.
3. **OptionGroupSelector 폼 내 배치 위치**: 카테고리 ↔ 태그 사이 (architect 잠정 추천) / 노출 순서 ↔ 폼 끝 사이 / 가격 ↔ 카테고리 사이. → **designer 확정**.
4. **빈 상태 / 에러 UX**: 기본 OptionGroupSelector empty UI 만 사용 (architect 잠정안) / 별도 안내 CTA 추가. → **designer 확정**.

---

## 완료 기준

- [ ] `spec.md` (본 문서) 확정
- [ ] `design.md` 작성 완료 (designer)
- [ ] `implementation.md` 작성 완료 (developer)
- [ ] `test_report.md` 작성 완료 (tester) — PASS 또는 보류 사유 명시
- [ ] brand 의 `MasterMenuFormPage` 에서 옵션 그룹 다중 선택 + 저장 동작
- [ ] sub-phase 1 회귀 0 (status pending 회귀 / 결정 J 핵심 필드 분리 / customer / owner 무영향)
- [ ] sub-phase 5 진입 조건 충족 (옵션 묶인 마스터 메뉴 → 점주 매장 자동 동기화 → 옵션 토글 가능)
- [ ] `flutter analyze` 0 issue

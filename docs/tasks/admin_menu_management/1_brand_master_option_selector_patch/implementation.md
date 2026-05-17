# sub-phase 1 옵션 selector 보강 patch — 구현 기록

> **상태**: 구현 완료
> **flutter analyze**: 0 issues

---

## 구현된 파일 / 메서드 목록

### 수정된 파일

| 파일 | 변경 유형 | 핵심 내용 |
|---|---|---|
| `lib/presentation/brand/providers/brand_master_menu_providers.dart` | 추가 | `_brandOptionRemoteDataSourceProvider` + `brandMasterOptionGroupsProvider` |
| `lib/presentation/brand/master_menu/master_menu_form_page.dart` | 수정 | import 추가 + 상태 필드 + initState prefill + build OptionGroupSelector 배치 + submit 매핑 |

---

## 핵심 변경 diff 요약

### 1. `brand_master_menu_providers.dart` — provider 2개 추가

```dart
// import 추가
import 'package:qradar/data/datasources/remote/option_remote_data_source.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';

// 파일 끝에 추가
final _brandOptionRemoteDataSourceProvider =
    Provider<OptionRemoteDataSource>((_) => OptionRemoteDataSource());

final brandMasterOptionGroupsProvider =
    FutureProvider<List<OptionGroupEntity>>((ref) async {
  final ds = ref.watch(_brandOptionRemoteDataSourceProvider);
  final models = await ds.fetchAllMaster();
  return models.map((m) => m.toEntity()).toList(growable: false);
});
```

- `_brandOptionRemoteDataSourceProvider`: private — 마스터 메뉴 폼 단일 사용처 전용
- `brandMasterOptionGroupsProvider`: owner 측 `masterOptionGroupsProvider` 패턴 동일. prefix 로 충돌 회피

### 2. `master_menu_form_page.dart` — 5곳 변경

**import 추가 (3개)**
```dart
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/entities/option_scope.dart';
import 'package:qradar/presentation/brand/master_menu/widgets/option_group_selector.dart';
```

**상태 필드 추가**
```dart
// 선택된 옵션 그룹 ID 목록 (S2 — 항상 master scope)
List<String> _selectedOptionGroupIds = [];
```

**initState prefill 추가** (기존 `_visible` 초기화 다음)
```dart
_selectedOptionGroupIds =
    source?.optionGroupRefs.map((r) => r.id).toList() ?? [];
```

**build 본문 — 카테고리 ↔ 태그 사이에 섹션 추가**
```dart
_divider(),
_sectionLabel('옵션 그룹'),
const SizedBox(height: 8),
OptionGroupSelector(
  optionGroups: ref
      .watch(brandMasterOptionGroupsProvider)
      .asData
      ?.value ?? [],
  selectedIds: _selectedOptionGroupIds,
  onChanged: (ids) => setState(() => _selectedOptionGroupIds = ids),
),
```

**submit 매핑 교체** (기존 `optionGroupRefs: baseItem?.optionGroupRefs ?? []`)
```dart
optionGroupRefs: _selectedOptionGroupIds
    .map((id) => OptionGroupRef(scope: OptionScope.master, id: id))
    .toList(),
```

---

## 설계 결정 반영 확인

| 결정 | 내용 | 반영 여부 |
|---|---|---|
| S2 (master scope 강제) | `storeId` 미전달 → `OptionGroupSelector` master only 분기. 매핑 시 `OptionScope.master` 강제 | 완료 |
| 결정 J (핵심 필드 회귀) | `_hasCoreFieldChange` L118-122 는 변경 없음. 본 patch 가 `_selectedOptionGroupIds` 를 실제로 채워 기존 로직이 동작하게 함 | 완료 (변경 없음) |
| 로딩/에러 fallback | `asData?.value ?? []` — 별도 UI 분기 없음 (designer 결정) | 완료 |
| 배치 위치 | 카테고리 ↔ 태그 사이 (designer 확정 안 A) | 완료 |
| provider 위치 | `brand_master_menu_providers.dart` 에 통합 (단일 사용처 원칙) | 완료 |
| `_canSubmit` 변경 없음 | 옵션 그룹은 선택 필드 | 완료 (변경 없음) |
| `_hasCoreFieldChange` 변경 없음 | 기존 ID 셋 비교 로직 그대로 재사용 | 완료 (변경 없음) |

---

## 테스트 포인트

### 자동 검증 가능 항목 (코드 레벨)

- `brandMasterOptionGroupsProvider` 가 `FutureProvider<List<OptionGroupEntity>>` 타입이며 `OptionRemoteDataSource.fetchAllMaster()` 를 호출하는지
- `OptionGroupSelector` 호출 시 `storeId` 파라미터가 없는지 (S2 보장)
- submit 매핑에서 `OptionScope.master` 가 하드코딩되어 있는지
- `_hasCoreFieldChange` 가 변경되지 않았는지 (L118-122 동일)

### 실기기 검증 항목 (사용자 수동)

1. **신규 등록 + 옵션 그룹 선택**
   - `MasterMenuFormPage` (등록 모드) 진입 → 옵션 그룹 섹션이 카테고리 아래, 태그 위에 표시
   - `og_master_shot`, `og_master_syrup`, `og_master_temperature` 3건이 CheckboxListTile 로 노출
   - 복수 선택 후 제출 → Firestore `brands/{brandId}/menuItems/{newId}.optionGroupRefs` 에 `[{scope:'master', id}]` 저장 확인

2. **수정 모드 prefill**
   - 옵션 그룹이 묶인 메뉴를 수정 모드로 열면 해당 옵션 그룹이 체크된 상태로 표시

3. **수정 모드 — 옵션 그룹 변경 → 핵심 필드 회귀 (결정 J)**
   - 옵션 그룹 추가/제거 후 저장 → SnackBar "수정 사항이 검토 대기 중입니다"
   - Firestore `status` 가 `pending` 으로 변경, `approvedBy/At` 보존 확인

4. **수정 모드 — 옵션 그룹 무변경, 운영 필드만 변경**
   - 옵션 그룹 그대로 + visible 토글 후 저장 → SnackBar "즉시 반영되었습니다"
   - Firestore `status` 보존 확인

5. **복제 모드 prefill**
   - 복제 모드에서 원본 옵션 그룹 prefill 확인 + 수정 후 저장 → 신규 메뉴 생성

6. **빈 상태**
   - Firestore master 옵션 그룹 0건 시 "등록된 옵션 그룹이 없어요" 표시, 폼 제출 가능

7. **S2 가드 (UI)**
   - store scope 옵션 그룹이 목록에 노출되지 않음 확인

8. **혼합 변경**
   - 옵션 그룹 추가 + visible 토글 동시 → 핵심 필드 우선 → `updateMasterMenuItemCore` 호출 → status=pending 회귀

---

## 미구현 / 보류 항목

| 항목 | 사유 |
|---|---|
| 옵션 그룹 빈 상태 admin 안내 CTA | spec 비범위. 후속 UX 개선 |
| "X개 선택됨" 헤더 배지 | design 결정 — 추가 안 함 (CheckboxListTile 으로 충분) |
| `displayOrder` 재정렬 UI | spec 비범위. 추후 결정 |
| 옵션 그룹 CRUD UI | sub-phase 7 (`admin_option_group_management`) |

---

## flutter analyze 결과

```
Analyzing OrderApp...
No issues found! (ran in 4.5s)
```

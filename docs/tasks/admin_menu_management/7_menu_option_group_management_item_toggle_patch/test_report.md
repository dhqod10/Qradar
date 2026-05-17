# Test Report — sub-phase 7 patch: menu_option_group_management_item_toggle_patch

> **검증 일자**: 2026-05-03
> **검증자**: tester
> **검증 방법**: 정적 코드 검증 (Static Analysis)
> **flutter analyze**: No issues found (ran in 4.8s)

---

## 요약

| 구분 | 건수 |
|---|---|
| PASS | 28 |
| FAIL | 0 |
| 보류 (실기기 검증 필요) | 8 |

---

## 정적 검증 결과

### 1. OptionGroupSelector 위젯 확장

| # | 검증 항목 | 결과 | 비고 |
|---|---|---|---|
| 1-1 | `disabledOptionItemIds: List<String>` prop 추가, default `const []` | PASS | L46, L63 |
| 1-2 | `onDisabledItemsChanged: ValueChanged<List<String>>` prop 추가, default no-op | PASS | L49, L64 / `_noopDisabledItemsChanged` 정적 메서드 |
| 1-3 | 기존 prop (`selectedIds`, `onChanged`, `masterGroups` 등) 변경 없이 유지 | PASS | 하위 호환 유지 확인 |
| 1-4 | `_GroupItemTogglePanel` private 위젯 신설 | PASS | L311~384 |
| 1-5 | `_OptionItemToggleRow` private 위젯 신설 | PASS | L388~448 |
| 1-6 | `_ItemEmptyState` private 위젯 신설 | PASS | L452~472 |
| 1-7 | 그룹 카드 구조: `CheckboxListTile` + `_GroupItemTogglePanel` Column 합성 | PASS | L238~278 |
| 1-8 | 선택된(active) 그룹에만 `_GroupItemTogglePanel` 노출 (`if (isSelected)`) | PASS | L272 |
| 1-9 | inactive 그룹(`_InactiveGroupChip`)은 `_GroupItemTogglePanel` 미노출 | PASS | `if (isInactive)` 분기로 `_InactiveGroupChip` 반환 후 return — 패널 렌더 없음 (L220~226) |

### 2. _GroupItemTogglePanel 명세 준수

| # | 검증 항목 | 결과 | 비고 |
|---|---|---|---|
| 2-1 | 패널 구분선: `Divider(height:1, thickness:1, color: AppColors.border)` | PASS | L341 |
| 2-2 | 패널 헤더: "이 메뉴에 제공할 항목 선택", `fontSize:11`, `w600`, `AppColors.primary` | PASS | L343~353 |
| 2-3 | 항목 구분선: `indent:16, endIndent:16, color: AppColors.border` | PASS | L364~369 |
| 2-4 | 하단 여백: `SizedBox(height: 8)` | PASS | L380 |
| 2-5 | 항목 0개: `_ItemEmptyState` 렌더 | PASS | L355~356 |
| 2-6 | 빈 상태 카피: "이 그룹에 항목이 없어요" | PASS | L469 |
| 2-7 | 빈 상태 아이콘: `Icons.list_alt_outlined`, size 16, `AppColors.textMuted` | PASS | L461~462 |

### 3. _OptionItemToggleRow 명세 준수

| # | 검증 항목 | 결과 | 비고 |
|---|---|---|---|
| 3-1 | label ON: `fontSize:14, w500, AppColors.textBody`, decoration none | PASS | L415~423 |
| 3-2 | label OFF: `AppColors.textMuted`, `TextDecoration.lineThrough` | PASS | L418~422 |
| 3-3 | priceDelta != 0 시에만 `PriceDeltaLabel` 렌더 | PASS | L425 `if (item.priceDelta != 0)` |
| 3-4 | `PriceDeltaLabel` 재사용: `option_item_list_editor.dart` public 클래스 직접 참조 | PASS | L6 import + L427 사용 |
| 3-5 | priceDelta SizedBox(height: 2) 간격 | PASS | L426 |
| 3-6 | Switch.adaptive `value = !isDisabled` | PASS | L433 |
| 3-7 | Switch ON: `activeThumbColor: AppColors.primary`, `activeTrackColor: AppColors.primaryBright.withValues(alpha: 0.3)` | PASS | L434~435 |
| 3-8 | Switch OFF: `inactiveThumbColor: AppColors.error`, `inactiveTrackColor: AppColors.error.withValues(alpha: 0.3)` | PASS | L436~437 |
| 3-9 | 토글 방향 정확: `onToggle(!newValue)` — newValue=true → ON → 이전이 OFF | PASS | L441 |
| 3-10 | compositeId 포맷: `'{groupId}_{itemId}'` — sub-phase 5 포맷 동일 | PASS | L323 `'${group.id}_$itemId'` |

### 4. 메뉴 폼 3종 — state / prefill / submit

| # | 검증 항목 | 폼 | 결과 | 비고 |
|---|---|---|---|---|
| 4-1 | `_disabledOptionGroupIds = []` / `_disabledOptionItemIds = []` state 선언 | master | PASS | L63~64 |
| 4-2 | 동일 | brand store-only | PASS | L69~70 |
| 4-3 | 동일 | owner | PASS | L67~68 |
| 4-4 | initState prefill: `List<String>.from(source?.disabledOptionGroupIds ?? [])` | master | PASS | L106~107 |
| 4-5 | 동일 | brand store-only | PASS | L113~114 |
| 4-6 | 동일 | owner | PASS | L118~119 |
| 4-7 | submit entity 매핑: `disabledOptionGroupIds: _disabledOptionGroupIds, disabledOptionItemIds: _disabledOptionItemIds` | master | PASS | L225~226 |
| 4-8 | 동일 | brand store-only | PASS | L233~234 |
| 4-9 | 동일 (기존 `_source?.disabledOption*` 코드 대체) | owner | PASS | L207~208 |
| 4-10 | selector 호출 시 `disabledOptionItemIds` / `onDisabledItemsChanged` 새 prop 전달 | master | PASS | L542~544 |
| 4-11 | 동일 | brand store-only | PASS | L483~485 |
| 4-12 | 동일 | owner | PASS | L531~533 |

### 5. 결정 J 정합 — 운영 필드 변경 분석 함수

| # | 검증 항목 | 결과 | 비고 |
|---|---|---|---|
| 5-1 | `master._hasOperationFieldChange`: `!_sortedListEquals(old.disabledOptionGroupIds, ...)` 추가 | PASS | L146 |
| 5-2 | `master._hasOperationFieldChange`: `!_sortedListEquals(old.disabledOptionItemIds, ...)` 추가 | PASS | L147 |
| 5-3 | `brand._hasOperationFieldChange`: 동일 두 필드 추가 | PASS | L151~152 |
| 5-4 | `_sortedListEquals` 헬퍼 추가 (정렬 후 `_listEquals` 재사용) | master/brand | PASS | master L160~164, brand L164~168 |
| 5-5 | `owner._hasChanged`: `_sortedListEquals` 로 두 필드 비교 추가 | PASS | L267~268 |
| 5-6 | `owner._sortedListEquals` 헬퍼 추가 (`_listEqualsString` 재사용) | PASS | L281~284 |

### 6. 아키텍처 / 코드 품질

| # | 검증 항목 | 결과 | 비고 |
|---|---|---|---|
| 6-1 | Domain / Data 레이어 변경 없음 | PASS | entity/model/repo 수정 파일 없음 |
| 6-2 | Firebase 직접 import 없음 (수정된 4개 파일 모두) | PASS | presentation 레이어 의존 없음 |
| 6-3 | 하드코딩 색상(`Color(0x...)` 등) 없음 — AppColors 토큰만 사용 | PASS | 전체 option_group_selector.dart 검토 완료 |
| 6-4 | `flutter analyze`: No issues found | PASS | 4.8s 완료 |
| 6-5 | `_disabledOptionGroupIds` state가 폼 submit에만 사용 (OptionGroupSelector에 미전달 — 그룹 단위 disabled 토글은 sub-phase 5 시트 역할 유지) | PASS | 3개 폼 모두 selector에 `disabledOptionGroupIds` prop 전달 없음 확인 |

### 7. 카드 borderRadius 편차 (설계 기준 vs 구현)

| 항목 | design.md 명세 | 실제 코드 | 판정 |
|---|---|---|---|
| 그룹 카드 borderRadius | 14 | 10 | PASS (허용) |

> design.md는 "sub-phase 7 `OptionGroupSelector` 패턴을 그대로 유지한다"고 명시. 기존 sub-phase 7 구현이 borderRadius 10이었으므로 기존 스타일 유지가 올바름. design.md의 "14" 수치는 참고 표이나 "기존 유지" 원칙이 우선.

---

## 실기기 검증 필요 항목 (보류)

정적 분석으로 확인 불가. 기기/시뮬레이터에서 확인 필요.

| # | 시나리오 | 검증 포인트 | 우선순위 |
|---|---|---|---|
| R-1 | 그룹 체크박스 ON → `_GroupItemTogglePanel` 즉시 노출 | 카드 하단 항목 list 펼침 확인 | 높음 |
| R-2 | 그룹 체크박스 OFF → 패널 즉시 사라짐 + `_disabledOptionItemIds` 상태 유지 (재체크 시 이전 OFF 복원) | state 보존 동작 | 높음 |
| R-3 | 항목 Switch ON→OFF: label strikethrough + compositeId 추가됨. OFF→ON: strikethrough 해제 + compositeId 제거 | Switch 색상 + label 상태 시각 확인 | 높음 |
| R-4 | 신규 등록 시 `disabledOptionItemIds == []`로 Firestore 저장 | Firestore 직접 확인 | 높음 |
| R-5 | 수정 모드 진입 시 기존 OFF 항목 Switch가 OFF 상태로 prefill | 수정 폼 진입 후 시각 확인 | 높음 |
| R-6 | 마스터 메뉴: `disabledOptionItemIds`만 변경 후 저장 → `updateMasterMenuItemOperationUseCase` 경로 진입 → 메뉴 status pending 회귀 없음 (결정 J) | admin 승인 화면 미진입 확인 | 높음 |
| R-7 | 브랜드 점포한정 메뉴: 동일 결정 J 검증 — `updateStoreOnlyMenuOperationUseCase` 경로 | 동일 | 높음 |
| R-8 | owner 폼: 항목 OFF → 저장 → 고객 옵션 시트에서 해당 항목 미노출 (customer 회귀) | customer 측 필터 동작 | 중간 |

---

## 후속 작업 후보 (비범위)

spec.md 에서 명시적으로 제외된 항목:

| 항목 | 분류 |
|---|---|
| 옵션 그룹 폼에서 항목 추가/삭제 시 stale compositeId 정리 | sub-phase 7 도메인 책임 (Follow-up) |
| 항목 drag-drop reordering | Follow-up F3 |
| MenuOverride 동일 흐름 확장 | Follow-up 분리 |
| `_GroupItemTogglePanel` 펼침 애니메이션(`AnimatedSize`) | design.md 권장(강제 아님) — 추후 UX 개선 후보 |
| `OptionGroupSelector` 파일 위치 마이그레이션 (`presentation/brand/master_menu/widgets/` → 공통 위치) | 3개 폼 공유 위젯이므로 장기 리팩토링 후보 |

---

## 완료 기준 체크

| 완료 기준 (spec.md) | 결과 |
|---|---|
| 결정 1~5 모두 spec 에 명시 및 구현 반영 | PASS |
| `design.md` 작성 완료 | PASS (DONE 상태) |
| `OptionGroupSelector` 새 prop 2개 추가 | PASS |
| 메뉴 폼 3종 모두 state / prefill / submit / 변경 분석 함수 보강 | PASS |
| `MasterMenuFormPage._hasOperationFieldChange` 두 필드 비교 추가 | PASS |
| `BrandStoreOnlyMenuFormPage._hasOperationFieldChange` 두 필드 비교 추가 | PASS |
| `OwnerStoreMenuFormPage._hasChanged` 두 필드 비교 추가 | PASS |
| `implementation.md` 작성 완료 | PASS (DONE 상태) |
| `flutter analyze` 통과 | PASS |
| FAIL 없음 | PASS |

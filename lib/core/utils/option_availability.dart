import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/entities/option_scope.dart';
import 'package:qradar/domain/entities/option_selection_type.dart';

// 옵션 선택 가능 판정 (payment_price_authority spec §4-1 사실 5, §15).
//
// `OptionRepositoryImpl.getOptionGroupsForMenuItem` 안에 있던 규칙을 **그대로 추출**한 순수 함수다 (동작 변경 없음).
// 서버 `functions/src/optionPricing.ts` 가 이것의 포팅이며 `test_fixtures/option_availability_contract.json` 으로
// 양방향 고정된다. 이 파일은 Firebase·Flutter 비의존이다.
//
// 규칙:
//  1. `active == false` 그룹은 제외한다.
//  2. 점주가 끈 그룹(`disabledGroupIds`)은 통째로 제외한다.
//  3. 항목은 composite 키 `{groupId}_{itemId}` 가 `disabledItemIds` 에 있으면 제외한다.
//
// 제약 필드는 `selectionType`(single/multi) 와 `required` 뿐이다 (수량 상한 없음).

/// 선택 위반의 종류. 서버 `optionIssues[].kind` 와 같은 문자열이다 ([asString]).
enum OptionIssueKind {
  /// 그룹 문서가 없거나(유령 ref) 그룹에 그 항목이 없다.
  missing,

  /// 점주가 그룹 또는 항목을 껐다.
  disabled,

  /// 그룹이 `active == false`.
  inactive,

  /// 선택한 그룹이 메뉴의 `optionGroupRefs` 에 없다.
  notInRefs,

  /// `required` 그룹에 선택이 없다.
  requiredEmpty,

  /// `single` 그룹에 2개 이상 선택했다.
  multiInSingle,

  /// 같은 (그룹, 항목)을 두 번 선택했다. 음수 `priceDelta` 를 반복해 가격을 깎는 경로를 막는다.
  duplicate;

  String get asString => name;
}

class OptionIssue {
  const OptionIssue({required this.groupId, this.itemId, required this.kind});

  final String groupId;

  /// 그룹 단위 위반(`requiredEmpty` / `multiInSingle`)이면 null.
  final String? itemId;
  final OptionIssueKind kind;
}

/// [validateSelection] 의 결과. [priceDeltas] 는 **위반 없이 해석된** 선택 항목의 가격 증감이며
/// 합산은 `cart_pricing.dart computeLinePrice` 한 곳에서만 한다.
class OptionSelectionCheck {
  const OptionSelectionCheck({required this.issues, required this.priceDeltas});

  final List<OptionIssue> issues;
  final List<int> priceDeltas;

  bool get isValid => issues.isEmpty;
}

/// (scope, id) 로 그룹 문서를 가리키는 키. 읽기 결과 map 의 키로 쓴다.
String optionRefKey(OptionScope scope, String id) => '${scope.asString}:$id';

/// 항목 비활성 composite 키 `{groupId}_{itemId}` 매칭 — **판정(읽기) 쪽 조립은 Dart 에서 이 함수 1곳뿐이다** (grep 가드).
/// 비활성 키를 *쓰는* 점주·브랜드 화면 3곳이 같은 형식을 만든다 — 가드의 허용 목록에 사유와 함께 적혀 있다.
bool isOptionItemDisabled(
  String groupId,
  String itemId,
  Set<String> disabledItemIds,
) => disabledItemIds.contains('${groupId}_$itemId');

enum _GroupState { selectable, inactive, disabled }

_GroupState _groupState(OptionGroupEntity g, Set<String> disabledGroupIds) {
  if (!g.active) return _GroupState.inactive;
  if (disabledGroupIds.contains(g.id)) return _GroupState.disabled;
  return _GroupState.selectable;
}

/// 고객에게 보여 줄 수 있는(=선택 가능한) 그룹·항목만 남긴다. 입력 순서를 유지한다.
List<OptionGroupEntity> resolveSelectableOptions({
  required Iterable<OptionGroupEntity> groups,
  Set<String> disabledGroupIds = const {},
  Set<String> disabledItemIds = const {},
}) {
  final out = <OptionGroupEntity>[];
  for (final group in groups) {
    if (_groupState(group, disabledGroupIds) != _GroupState.selectable) {
      continue;
    }
    if (disabledItemIds.isEmpty) {
      out.add(group);
      continue;
    }
    final items = group.items
        .where((i) => !isOptionItemDisabled(group.id, i.id, disabledItemIds))
        .toList(growable: false);
    out.add(group.copyWith(items: items));
  }
  return out;
}

/// 카트 라인 하나의 옵션 선택이 **지금 유효한가**를 판정한다 (spec R4).
///
/// - [refs]: 그 메뉴의 `optionGroupRefs`
/// - [groupsByRefKey]: [optionRefKey] → 읽은 그룹 (문서가 없으면 null/부재)
/// - [selected]: 카트가 선언한 선택 (groupId, itemId)
///
/// 위반이 하나라도 있으면 [OptionSelectionCheck.issues] 가 비어 있지 않다. 서버는 이를 거절로, 클라이언트 재가격은
/// 안내로 쓴다.
OptionSelectionCheck validateSelection({
  required List<OptionGroupRef> refs,
  required Map<String, OptionGroupEntity?> groupsByRefKey,
  Set<String> disabledGroupIds = const {},
  Set<String> disabledItemIds = const {},
  required List<({String groupId, String itemId})> selected,
}) {
  OptionGroupRef? refOf(String groupId) {
    for (final r in refs) {
      if (r.id == groupId) return r;
    }
    return null;
  }

  OptionGroupEntity? groupOf(OptionGroupRef r) =>
      groupsByRefKey[optionRefKey(r.scope, r.id)];

  final issues = <OptionIssue>[];
  final deltas = <int>[];
  final counts = <String, int>{};
  final seen = <String>{};

  for (final sel in selected) {
    final ref = refOf(sel.groupId);
    if (ref == null) {
      issues.add(
        OptionIssue(
          groupId: sel.groupId,
          itemId: sel.itemId,
          kind: OptionIssueKind.notInRefs,
        ),
      );
      continue;
    }
    final group = groupOf(ref);
    if (group == null) {
      issues.add(
        OptionIssue(
          groupId: sel.groupId,
          itemId: sel.itemId,
          kind: OptionIssueKind.missing,
        ),
      );
      continue;
    }
    final state = _groupState(group, disabledGroupIds);
    if (state != _GroupState.selectable) {
      issues.add(
        OptionIssue(
          groupId: sel.groupId,
          itemId: sel.itemId,
          kind: state == _GroupState.inactive
              ? OptionIssueKind.inactive
              : OptionIssueKind.disabled,
        ),
      );
      continue;
    }
    final item = group.items.where((i) => i.id == sel.itemId).firstOrNull;
    if (item == null) {
      issues.add(
        OptionIssue(
          groupId: sel.groupId,
          itemId: sel.itemId,
          kind: OptionIssueKind.missing,
        ),
      );
      continue;
    }
    if (isOptionItemDisabled(group.id, item.id, disabledItemIds)) {
      issues.add(
        OptionIssue(
          groupId: sel.groupId,
          itemId: sel.itemId,
          kind: OptionIssueKind.disabled,
        ),
      );
      continue;
    }
    if (!seen.add('${sel.groupId}\u0000${sel.itemId}')) {
      issues.add(
        OptionIssue(
          groupId: sel.groupId,
          itemId: sel.itemId,
          kind: OptionIssueKind.duplicate,
        ),
      );
      continue;
    }
    counts[group.id] = (counts[group.id] ?? 0) + 1;
    deltas.add(item.priceDelta);
  }

  // 그룹 단위 제약: 선택 가능한 그룹만 본다 (끈 그룹의 required 는 요구할 수 없다).
  final checked = <String>{};
  for (final ref in refs) {
    if (!checked.add(ref.id)) continue;
    final group = groupOf(ref);
    if (group == null) continue;
    if (_groupState(group, disabledGroupIds) != _GroupState.selectable) {
      continue;
    }
    final n = counts[group.id] ?? 0;
    if (group.required && n == 0) {
      issues.add(
        OptionIssue(groupId: group.id, kind: OptionIssueKind.requiredEmpty),
      );
    }
    if (group.selectionType == OptionSelectionType.single && n > 1) {
      issues.add(
        OptionIssue(groupId: group.id, kind: OptionIssueKind.multiInSingle),
      );
    }
  }

  return OptionSelectionCheck(issues: issues, priceDeltas: deltas);
}

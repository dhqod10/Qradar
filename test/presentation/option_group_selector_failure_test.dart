import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/entities/option_scope.dart';
import 'package:qradar/domain/entities/option_selection_type.dart';
import 'package:qradar/presentation/brand/master_menu/widgets/option_group_selector.dart';
import 'package:qradar/presentation/common/async_value_log.dart';

OptionGroupEntity _group(String id, String name) => OptionGroupEntity(
      id: id,
      scope: OptionScope.brand,
      brandId: 'b1',
      name: name,
      selectionType: OptionSelectionType.single,
    );

Future<void> _pump(
  WidgetTester t, {
  List<OptionGroupEntity> brandGroups = const [],
  Set<OptionScope> failed = const {},
}) async {
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: OptionGroupSelector(
            brandGroups: brandGroups,
            failedScopes: failed,
            selectedIds: const [],
            onChanged: (_) {},
            onNavigateToBrandOptionGroups: () {},
          ),
        ),
      ),
    ),
  );
  await t.pump();
}

void main() {
  // 회귀: 브랜드 옵션 그룹 조회에 복합 인덱스(active + displayOrder)가 없어 쿼리가 계속
  // 실패했는데, 화면은 `?? []` 때문에 "옵션 그룹이 없어요" 라는 평범한 빈 상태로만 보였다.
  // 브랜드가 그룹을 만들어도 메뉴에 붙일 수 없는 고장이 빈 데이터처럼 위장됐다.
  group('옵션 그룹 — 없음과 못 불러옴을 구분한다', () {
    testWidgets('정말 없을 때: 만들러 가라고 안내한다', (t) async {
      await _pump(t);
      expect(find.text('옵션 그룹이 없어요'), findsOneWidget);
      expect(find.text('옵션 그룹을 불러오지 못했어요'), findsNothing);
    });

    testWidgets('불러오지 못했을 때: 빈 상태로 위장하지 않는다', (t) async {
      await _pump(t, failed: {OptionScope.brand});
      expect(find.text('옵션 그룹을 불러오지 못했어요'), findsOneWidget);
      // 섹션은 각자 제 상태를 말한다 — 기본 옵션은 정말 없고(빈 상태),
      // 브랜드 옵션은 못 불러온 것(실패)이라 문구가 서로 다르다.
      expect(find.text('옵션 그룹이 없어요'), findsOneWidget);
    });

    testWidgets('모든 스코프가 실패하면 빈 상태 문구는 없다', (t) async {
      await _pump(t, failed: {OptionScope.master, OptionScope.brand});
      expect(find.text('옵션 그룹을 불러오지 못했어요'), findsNWidgets(2));
      expect(find.text('옵션 그룹이 없어요'), findsNothing);
    });

    testWidgets('불러온 그룹이 있으면 실패 문구가 뜨지 않는다', (t) async {
      await _pump(t, brandGroups: [_group('g1', '샷 추가')]);
      expect(find.text('샷 추가'), findsOneWidget);
      expect(find.text('옵션 그룹을 불러오지 못했어요'), findsNothing);
    });
  });

  group('asDataOrLog — 실패를 빈 값으로 뭉개지 않는다', () {
    test('데이터는 그대로 통과', () {
      expect(asDataOrLog(const AsyncValue.data([1, 2]), 't'), [1, 2]);
    });

    test('에러는 null — 호출부가 "없음" 과 구분할 수 있다', () {
      final v = AsyncValue<List<int>>.error(StateError('index missing'),
          StackTrace.empty);
      expect(asDataOrLog(v, 't'), isNull);
    });

    test('로딩도 null (아직 모른다)', () {
      expect(asDataOrLog(const AsyncValue<List<int>>.loading(), 't'), isNull);
    });
  });
}

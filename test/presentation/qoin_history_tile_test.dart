import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/presentation/common/providers/qoin_rate_providers.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_history_page.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_history_tile.dart';

/// 이력 신규 행 3종 (design §18-7) + N8 (뷰어 역할로 링크 분기).
void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));
  final now = DateTime(2026, 10, 22, 15);

  QoinRateChangeEntity change({
    QoinRateField field = QoinRateField.accrualRate,
    QoinRateChangeOp op = QoinRateChangeOp.set,
    QoinRateChangeSource source = QoinRateChangeSource.callable,
    double? beforeRate,
    double? afterRate,
    bool? beforeEnabled,
    bool? afterEnabled,
    QoinBeforeState? beforeState,
    String? bulkHistoryId,
    String? reason,
    String? changedBy = 'adminuid1234',
    double? migratedFromRate,
    String? beforeRaw,
    int? disabledUntouched,
    bool? brandDisabled,
    QoinRateScope scope = QoinRateScope.store,
  }) => QoinRateChangeEntity(
    id: 'h1',
    scope: scope,
    targetId: 's1',
    targetName: '강남점',
    field: field,
    beforeRate: beforeRate,
    afterRate: afterRate,
    beforeEnabled: beforeEnabled,
    afterEnabled: afterEnabled,
    beforeState: beforeState,
    beforeRaw: beforeRaw,
    bulkHistoryId: bulkHistoryId,
    migratedFromRate: migratedFromRate,
    changedBy: changedBy,
    changedAt: DateTime(2026, 10, 22, 14, 35),
    reason: reason,
    source: source,
    op: op,
    disabledUntouchedCount: disabledUntouched,
    brandDisabled: brandDisabled,
  );

  Widget host(
    QoinRateChangeEntity c,
    QoinHistoryViewer v, {
    void Function(QoinRateChangeEntity)? onBrand,
  }) => ProviderScope(
    overrides: [
      qoinChangerNameProvider.overrideWith((ref, uid) => Stream.value('김관리')),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: QoinRateHistoryTile(
            change: c,
            viewer: v,
            now: now,
            onOpenBrandHistory: onBrand,
          ),
        ),
      ),
    ),
  );

  testWidgets('(a) accrualEnabled: 사용 → 사용 안 함 + 적립 사용 여부 알약', (t) async {
    await t.pumpWidget(
      host(
        change(
          field: QoinRateField.accrualEnabled,
          afterEnabled: false,
          beforeState: QoinBeforeState.absent,
          reason: '점검 기간 동안 중단',
        ),
        QoinHistoryViewer.admin,
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('사용'), findsOneWidget);
    expect(find.text('사용 안 함'), findsOneWidget);
    expect(find.text('적립 사용 여부'), findsOneWidget);
    expect(find.textContaining('사유: 점검 기간 동안 중단'), findsOneWidget);
  });

  testWidgets('(a) 다시 켠 경우: 사용 안 함 → 사용 (clear, after null)', (t) async {
    await t.pumpWidget(
      host(
        change(
          field: QoinRateField.accrualEnabled,
          op: QoinRateChangeOp.clear,
          beforeEnabled: false,
          afterEnabled: null,
        ),
        QoinHistoryViewer.owner,
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('사용 안 함'), findsOneWidget);
    expect(find.text('사용'), findsOneWidget);
  });

  testWidgets('(a) 비bool 이전 값은 확인 필요', (t) async {
    await t.pumpWidget(
      host(
        change(
          field: QoinRateField.accrualEnabled,
          afterEnabled: false,
          beforeState: QoinBeforeState.invalid,
        ),
        QoinHistoryViewer.admin,
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('확인 필요'), findsOneWidget);
  });

  testWidgets('(b) migration: 이전 알약 + 4행 문장, 사유 줄 숨김, 변경자 (이전 작업)', (t) async {
    await t.pumpWidget(
      host(
        change(
          field: QoinRateField.accrualEnabled,
          source: QoinRateChangeSource.migration,
          afterEnabled: false,
          migratedFromRate: 0,
          reason: '적립률 0% → 적립 사용 안 함 이전 (Q1)',
        ),
        QoinHistoryViewer.admin,
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('이전'), findsOneWidget);
    expect(find.text('예전 설정 ‘적립률 0%’ 가 ‘사용 안 함’ 으로 옮겨졌어요'), findsOneWidget);
    expect(find.textContaining('사유:'), findsNothing);
    expect(find.textContaining('(이전 작업)'), findsOneWidget);
  });

  group('(c) clearByBulk — N8: 링크는 뷰어 역할로 분기', () {
    QoinRateChangeEntity clear() => change(
      op: QoinRateChangeOp.clearByBulk,
      source: QoinRateChangeSource.bulk,
      beforeRate: 0.05,
      beforeState: QoinBeforeState.value,
      bulkHistoryId: 'brandHist',
    );

    testWidgets('문장은 모두에게: 5% → 설정 없음 + 알약 + 4행', (t) async {
      await t.pumpWidget(host(clear(), QoinHistoryViewer.owner));
      await t.pumpAndSettle();
      expect(find.text('5%'), findsOneWidget);
      expect(find.text('설정 없음'), findsOneWidget);
      expect(find.text('일괄 적용으로 초기화'), findsOneWidget);
      expect(find.text('브랜드 일괄 적용으로 개별 설정이 지워졌어요'), findsOneWidget);
    });

    testWidgets('admin: 링크가 있고 콜백을 부른다', (t) async {
      QoinRateChangeEntity? got;
      await t.pumpWidget(
        host(clear(), QoinHistoryViewer.admin, onBrand: (c) => got = c),
      );
      await t.pumpAndSettle();
      expect(find.text('브랜드 이력에서 보기'), findsOneWidget);
      await t.tap(find.text('브랜드 이력에서 보기'));
      expect(got?.bulkHistoryId, 'brandHist');
    });

    testWidgets('해당 브랜드의 brand 보유자: 링크가 있다', (t) async {
      await t.pumpWidget(
        host(clear(), QoinHistoryViewer.brand, onBrand: (_) {}),
      );
      await t.pumpAndSettle();
      expect(find.text('브랜드 이력에서 보기'), findsOneWidget);
    });

    testWidgets('가맹점주(owner): 콜백이 주어져도 링크도 chevron 도 탭 타깃도 없다 (Rules 가 거부)', (
      t,
    ) async {
      await t.pumpWidget(
        host(clear(), QoinHistoryViewer.owner, onBrand: (_) {}),
      );
      await t.pumpAndSettle();
      expect(find.text('브랜드 이력에서 보기'), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('bulkHistoryId 가 없으면 admin 이어도 링크만 숨긴다', (t) async {
      final c = change(
        op: QoinRateChangeOp.clearByBulk,
        source: QoinRateChangeSource.bulk,
        beforeRate: 0.05,
      );
      await t.pumpWidget(host(c, QoinHistoryViewer.admin, onBrand: (_) {}));
      await t.pumpAndSettle();
      expect(find.text('브랜드 일괄 적용으로 개별 설정이 지워졌어요'), findsOneWidget);
      expect(find.text('브랜드 이력에서 보기'), findsNothing);
    });

    testWidgets('무효였던 값: 확인 필요 + admin 에게만 beforeRaw', (t) async {
      final c = change(
        op: QoinRateChangeOp.clearByBulk,
        source: QoinRateChangeSource.bulk,
        beforeState: QoinBeforeState.invalid,
        beforeRaw: '3',
        bulkHistoryId: 'x',
      );
      await t.pumpWidget(host(c, QoinHistoryViewer.admin));
      await t.pumpAndSettle();
      expect(find.text('확인 필요'), findsOneWidget);
      expect(find.text('값 "3"'), findsOneWidget);
      await t.pumpWidget(host(c, QoinHistoryViewer.owner));
      await t.pumpAndSettle();
      expect(find.text('값 "3"'), findsNothing);
    });
  });

  testWidgets('브랜드 일괄 행: brandDisabled 가 K 줄보다 우선, K 줄은 그리지 않는다', (t) async {
    final c =
        change(
          scope: QoinRateScope.brand,
          op: QoinRateChangeOp.bulkApply,
          source: QoinRateChangeSource.bulk,
          afterRate: 0.05,
          disabledUntouched: 3,
          brandDisabled: true,
        ).copyWith(
          bulkMode: QoinBulkMode.overwrite,
          status: QoinBulkStatus.completed,
          affectedCount: 12,
          clearedCount: 3,
        );
    await t.pumpWidget(host(c, QoinHistoryViewer.admin));
    await t.pumpAndSettle();
    expect(find.text('브랜드가 사용 안 함이라 산하 매장 전체의 적립이 시작되지 않았어요'), findsOneWidget);
    expect(find.textContaining('적립 사용 안 함 3곳'), findsNothing);
  });

  testWidgets('브랜드 일괄 행: K>0 이고 브랜드는 켜져 있으면 K 줄', (t) async {
    final c =
        change(
          scope: QoinRateScope.brand,
          op: QoinRateChangeOp.bulkApply,
          source: QoinRateChangeSource.bulk,
          afterRate: 0.05,
          disabledUntouched: 3,
        ).copyWith(
          bulkMode: QoinBulkMode.preserve,
          status: QoinBulkStatus.completed,
          affectedCount: 12,
        );
    await t.pumpWidget(host(c, QoinHistoryViewer.admin));
    await t.pumpAndSettle();
    expect(find.text('적립 사용 안 함 3곳은 적립이 시작되지 않았어요'), findsOneWidget);
  });

  testWidgets('globalEnabled 와 미지의 op 는 앱이 죽지 않고 한 줄 폴백', (t) async {
    await t.pumpWidget(
      host(
        change(
          field: QoinRateField.globalEnabled,
          scope: QoinRateScope.global,
          beforeEnabled: true,
          afterEnabled: false,
          source: QoinRateChangeSource.appDirect,
        ),
        QoinHistoryViewer.admin,
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('적립 중'), findsOneWidget);
    expect(find.text('적립 중단됨'), findsOneWidget);
    await t.pumpWidget(
      host(
        change(
          op: QoinRateChangeOp.unknown,
          source: QoinRateChangeSource.unknown,
        ),
        QoinHistoryViewer.admin,
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('알 수 없는 변경'), findsOneWidget);
  });

  group('QoinRateHistoryPage — N8 뷰어 분기 + 연결 강조', () {
    final storeRow = change(
      op: QoinRateChangeOp.clearByBulk,
      source: QoinRateChangeSource.bulk,
      beforeRate: 0.05,
      bulkHistoryId: 'brandHist',
    );
    final brandRow = QoinRateChangeEntity(
      id: 'brandHist',
      scope: QoinRateScope.brand,
      targetId: 'b1',
      targetName: 'Q브루어리',
      field: QoinRateField.accrualRate,
      afterRate: 0.06,
      changedBy: 'adminuid1234',
      changedAt: DateTime(2026, 10, 22, 14, 35),
      source: QoinRateChangeSource.bulk,
      op: QoinRateChangeOp.bulkApply,
      bulkMode: QoinBulkMode.overwrite,
      status: QoinBulkStatus.completed,
      affectedCount: 4,
      clearedCount: 1,
    );

    Widget page(QoinHistoryViewer v) => ProviderScope(
      overrides: [
        qoinRateHistoryProvider.overrideWith(
          (ref, key) => Stream.value(
            key.scope == QoinRateScope.brand ? [brandRow] : [storeRow],
          ),
        ),
      ],
      child: MaterialApp(
        home: QoinRateHistoryPage(
          scope: QoinRateScope.store,
          targetId: 's1',
          targetName: '강남점',
          viewer: v,
          brandId: v == QoinHistoryViewer.brand ? 'b1' : null,
          brandName: 'Q브루어리',
        ),
      ),
    );

    testWidgets('owner 의 매장 이력: clearByBulk 문장만, 링크/탭 타깃 없음', (t) async {
      await t.pumpWidget(page(QoinHistoryViewer.owner));
      await t.pumpAndSettle();
      expect(find.text('브랜드 일괄 적용으로 개별 설정이 지워졌어요'), findsOneWidget);
      expect(find.text('브랜드 이력에서 보기'), findsNothing);
    });

    testWidgets('해당 브랜드 보유자: 링크 -> 브랜드 이력 페이지 + 일괄 행 강조', (t) async {
      await t.pumpWidget(page(QoinHistoryViewer.brand));
      await t.pumpAndSettle();
      await t.tap(find.text('브랜드 이력에서 보기'));
      await t.pumpAndSettle();
      expect(find.text('브랜드 "Q브루어리" 전체 의 변경 이력'), findsOneWidget);
      final highlighted = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.color != null &&
            w.color!.a > 0 &&
            w.color!.a < 0.2,
      );
      expect(highlighted, findsWidgets, reason: 'bulkHistoryId 행 배경 강조');
      // 2초 뒤 원복.
      await t.pump(const Duration(seconds: 3));
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_results.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_rate_edit_form.dart';

Widget host(Widget child) => ProviderScope(
  child: MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  ),
);

EffectiveQoinRate eff({
  QoinRateSetting store = QoinRateSetting.absent,
  QoinRateSetting brand = QoinRateSetting.absent,
  QoinRateSetting? global,
  bool hasBrand = true,
}) => resolveEffectiveQoinRate(
  store: store,
  brand: brand,
  global: global ?? QoinRateSetting.valid(0.03),
  hasBrand: hasBrand,
);

/// 긴 폼이 한 화면에 들어가도록 테스트 화면을 키운다 (스크롤 밖 탭 방지).
void bigScreen(WidgetTester t) {
  t.view.physicalSize = const Size(800, 3000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Finder saveButton(String label) => find.widgetWithText(ElevatedButton, label);

bool enabled(WidgetTester t, String label) =>
    t.widget<ElevatedButton>(saveButton(label)).onPressed != null;

void main() {
  group('전역 폼 — 100배 오입력 방어선', () {
    Future<void> pump(WidgetTester t, {List<QoinRateSubmission>? sink}) async {
      bigScreen(t);
      await t.pumpWidget(
        host(
          QoinRateEditForm(
            scope: QoinRateScope.global,
            current: QoinRateSetting.valid(0.03),
            effective: eff(hasBrand: false),
            saveLabel: '전역 기본값 저장',
            onSubmit: (s) async => sink?.add(s),
          ),
        ),
      );
    }

    testWidgets('초기값은 서버 값(3), 변경 없으니 저장 비활성', (t) async {
      await pump(t);
      expect(find.widgetWithText(TextField, '3'), findsOneWidget);
      expect(enabled(t, '전역 기본값 저장'), isFalse);
    });

    testWidgets('0.03 -> 하한 에러, 저장 비활성', (t) async {
      await pump(t);
      await t.enterText(find.byType(TextField).first, '0.03');
      await t.pump();
      expect(find.textContaining('이상 입력해주세요'), findsOneWidget);
      expect(enabled(t, '전역 기본값 저장'), isFalse);
    });

    testWidgets('30 -> 상한 에러, 0 -> 하한 에러', (t) async {
      await pump(t);
      await t.enterText(find.byType(TextField).first, '30');
      await t.pump();
      expect(find.textContaining('까지 입력할 수 있어요'), findsOneWidget);
      expect(enabled(t, '전역 기본값 저장'), isFalse);
      await t.enterText(find.byType(TextField).first, '0');
      await t.pump();
      expect(find.textContaining('이상 입력해주세요'), findsOneWidget);
      expect(enabled(t, '전역 기본값 저장'), isFalse);
    });

    testWidgets('5 입력 -> 저장 -> 확인 다이얼로그 첫 줄 "전역 기본값", 현재→변경, 환산 -> 확인 후 제출', (
      t,
    ) async {
      final sink = <QoinRateSubmission>[];
      await pump(t, sink: sink);
      await t.enterText(find.byType(TextField).first, '5');
      await t.pump();
      expect(enabled(t, '전역 기본값 저장'), isTrue);
      await t.tap(saveButton('전역 기본값 저장'));
      await t.pumpAndSettle();
      expect(find.text('전역 기본값'), findsWidgets);
      expect(find.text('적립률을 변경할까요?'), findsOneWidget);
      expect(find.text('3%'), findsWidgets);
      expect(find.text('5%'), findsWidgets);
      expect(find.textContaining('300 Q → 500 Q'), findsOneWidget);
      await t.tap(find.text('변경하기'));
      await t.pumpAndSettle();
      expect(sink, hasLength(1));
      expect(sink.single.value, isA<QoinRateValueRate>());
      expect((sink.single.value as QoinRateValueRate).tenths, 50);
    });

    testWidgets('10% 이상 입력 시 인상 경고가 보인다 / 같은 값이면 경고 없음', (t) async {
      await pump(t);
      await t.enterText(find.byType(TextField).first, '10');
      await t.pump();
      await t.tap(saveButton('전역 기본값 저장'));
      await t.pumpAndSettle();
      expect(find.textContaining('2배 이상이거나 10% 이상'), findsOneWidget);
    });

    testWidgets('취소하면 제출하지 않는다', (t) async {
      final sink = <QoinRateSubmission>[];
      await pump(t, sink: sink);
      await t.enterText(find.byType(TextField).first, '5');
      await t.pump();
      await t.tap(saveButton('전역 기본값 저장'));
      await t.pumpAndSettle();
      await t.tap(find.text('취소'));
      await t.pumpAndSettle();
      expect(sink, isEmpty);
    });
  });

  group('매장 폼 — 설정 방식 3택', () {
    Future<void> pump(
      WidgetTester t, {
      QoinRateSetting current = QoinRateSetting.absent,
      QoinRateSetting? brand,
      List<QoinRateSubmission>? sink,
    }) async {
      bigScreen(t);
      await t.pumpWidget(
        host(
          QoinRateEditForm(
            scope: QoinRateScope.store,
            targetName: '강남점',
            brandName: 'Q브루어리',
            current: current,
            effective: eff(
              store: current,
              brand: brand ?? QoinRateSetting.valid(0.05),
            ),
            saveLabel: '매장 설정 저장',
            onSubmit: (s) async => sink?.add(s),
          ),
        ),
      );
    }

    testWidgets('상속 상태: 라디오 1 선택, 따르게 될 실제 값이 보이고 입력란은 없다', (t) async {
      await pump(t);
      expect(find.text('브랜드 "Q브루어리" 의 5% 를 따라요'), findsOneWidget);
      expect(
        find.byType(TextField),
        findsOneWidget,
        reason: '사유 입력란만 (비활성 입력란 금지)',
      );
      expect(enabled(t, '매장 설정 저장'), isFalse, reason: '이미 상속 상태');
    });

    testWidgets('직접 설정을 고르면 입력란이 펼쳐지고, 0 은 하한 에러', (t) async {
      await pump(t);
      await t.tap(find.text('직접 설정'));
      await t.pump();
      expect(find.byType(TextField), findsNWidgets(2));
      await t.enterText(find.byType(TextField).first, '0');
      await t.pump();
      expect(find.textContaining('이상 입력해주세요'), findsOneWidget);
      expect(enabled(t, '매장 설정 저장'), isFalse);
    });

    testWidgets('적립 안 함 (0%) 은 라디오로만: 저장 -> 중단 다이얼로그(환불 회수 안내) -> Stop 제출', (
      t,
    ) async {
      final sink = <QoinRateSubmission>[];
      await pump(t, sink: sink);
      await t.tap(find.text('적립 안 함 (0%)'));
      await t.pump();
      expect(enabled(t, '매장 설정 저장'), isTrue);
      await t.tap(saveButton('매장 설정 저장'));
      await t.pumpAndSettle();
      expect(
        find.text('매장 "강남점"'),
        findsOneWidget,
        reason: '확인 다이얼로그 첫 줄 = 범위 + 대상명',
      );
      expect(find.text('적립을 중단할까요?'), findsOneWidget);
      expect(find.textContaining('환불 회수는 계속돼요'), findsOneWidget);
      expect(find.textContaining('500 Q → 적립 없음'), findsOneWidget);
      await t.tap(find.text('적립 중단'));
      await t.pumpAndSettle();
      expect(sink.single.value, isA<QoinRateValueStop>());
    });

    testWidgets('이미 0% 인 매장: 적립 안 함 카드가 선택된 상태, 저장 비활성', (t) async {
      await pump(t, current: QoinRateSetting.zero);
      expect(enabled(t, '매장 설정 저장'), isFalse);
    });

    testWidgets('브랜드가 0% 면 상속 설명에 0% 상속이 보인다', (t) async {
      await pump(t, brand: QoinRateSetting.zero);
      expect(find.text('브랜드 "Q브루어리" 의 설정(적립 안 함)을 따라요'), findsOneWidget);
    });

    testWidgets('상위 값이 무효면 상속 카드가 비활성 + 문구', (t) async {
      await pump(t, brand: QoinRateSetting.invalid);
      expect(find.text('상위 설정을 확인할 수 없어요'), findsOneWidget);
    });

    testWidgets('직접 5% 였다가 상속으로 되돌리기: 변경 쪽에 따르게 될 실제 값(브랜드 상속)이 나온다', (
      t,
    ) async {
      final sink = <QoinRateSubmission>[];
      await pump(t, current: QoinRateSetting.valid(0.1), sink: sink);
      await t.tap(find.text('상위 설정 따르기'));
      await t.pump();
      await t.tap(saveButton('매장 설정 저장'));
      await t.pumpAndSettle();
      expect(find.text('설정을 지우고 상위 설정을 따르게 할까요?'), findsOneWidget);
      expect(find.text('매장 설정'), findsOneWidget, reason: '현재 캡션');
      expect(find.text('브랜드 상속'), findsOneWidget, reason: '변경 캡션');
      await t.tap(find.text('되돌리기'));
      await t.pumpAndSettle();
      expect(sink.single.value, isA<QoinRateValueInherit>());
    });
  });

  group('브랜드 폼 — 일괄 적용 (H5)', () {
    Future<void> pump(
      WidgetTester t, {
      AsyncValue<QoinBulkStats>? stats,
      List<QoinRateSubmission>? sink,
    }) async {
      bigScreen(t);
      await t.pumpWidget(
        host(
          QoinRateEditForm(
            scope: QoinRateScope.brand,
            targetName: 'Q브루어리',
            current: QoinRateSetting.absent,
            effective: eff(),
            saveLabel: '브랜드 설정 저장',
            bulkStats:
                stats ??
                const AsyncValue.data(
                  QoinBulkStats(total: 12, overridden: 3, overriddenStopped: 1),
                ),
            onSubmit: (s) async => sink?.add(s),
          ),
        ),
      );
      await t.tap(find.text('직접 설정'));
      await t.pump();
      await t.enterText(find.byType(TextField).first, '5');
      await t.pump();
    }

    testWidgets('산하 매장 정보 로딩 중에는 저장 불가', (t) async {
      await pump(t, stats: const AsyncValue.loading());
      expect(find.text('산하 매장 정보를 불러오는 중이에요'), findsOneWidget);
      expect(enabled(t, '브랜드 설정 저장'), isFalse);
    });

    testWidgets('산하 매장 에러에서는 저장 불가 + 다시 시도', (t) async {
      await pump(t, stats: AsyncValue.error('x', StackTrace.empty));
      expect(find.text('산하 매장을 불러오지 못했어요'), findsOneWidget);
      expect(enabled(t, '브랜드 설정 저장'), isFalse);
    });

    testWidgets('개별 설정 0곳이면 모드 선택이 없고 preserve 로 제출', (t) async {
      final sink = <QoinRateSubmission>[];
      await pump(
        t,
        stats: const AsyncValue.data(
          QoinBulkStats(total: 4, overridden: 0, overriddenStopped: 0),
        ),
        sink: sink,
      );
      expect(find.text('개별 설정 덮어쓰기'), findsNothing);
      await t.tap(saveButton('브랜드 설정 저장'));
      await t.pumpAndSettle();
      expect(find.text('브랜드 "Q브루어리" 전체'), findsOneWidget);
      expect(find.text('산하 매장 4곳 모두에 적용돼요'), findsOneWidget);
      await t.tap(find.text('변경하기'));
      await t.pumpAndSettle();
      expect(sink.single.mode, QoinBulkMode.preserve);
    });

    testWidgets('기본은 보존: 확인 다이얼로그에 영향 매장 수, 체크박스 없음', (t) async {
      final sink = <QoinRateSubmission>[];
      await pump(t, sink: sink);
      expect(find.text('개별 설정 보존'), findsOneWidget);
      await t.tap(saveButton('브랜드 설정 저장'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('산하 매장 12곳 중 개별 설정이 없는 9곳에 적용돼요'),
        findsOneWidget,
      );
      expect(find.textContaining('개별 설정이 있는 3곳은 그대로 유지돼요'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      await t.tap(find.text('변경하기'));
      await t.pumpAndSettle();
      expect(sink.single.mode, QoinBulkMode.preserve);
    });

    testWidgets('덮어쓰기: 영향 수 + 적립 안 함 재활성 + 재설정 안내가 확인 전에 보이고, 체크 전엔 실행 불가', (
      t,
    ) async {
      final sink = <QoinRateSubmission>[];
      await pump(t, sink: sink);
      await t.tap(find.text('개별 설정 덮어쓰기'));
      await t.pump();
      await t.tap(saveButton('브랜드 설정 저장'));
      await t.pumpAndSettle();
      expect(find.text('개별 설정 3곳이 지워져요'), findsOneWidget);
      expect(find.textContaining('그중 적립 안 함 1곳도 다시 적립해요'), findsOneWidget);
      expect(find.text('되돌리려면 매장마다 다시 설정해야 해요'), findsOneWidget);
      final exec = find.widgetWithText(ElevatedButton, '덮어쓰고 적용');
      expect(
        t.widget<ElevatedButton>(exec).onPressed,
        isNull,
        reason: '체크 전 비활성',
      );
      await t.tap(find.byType(Checkbox));
      await t.pump();
      expect(t.widget<ElevatedButton>(exec).onPressed, isNotNull);
      await t.tap(exec);
      await t.pumpAndSettle();
      expect(sink.single.mode, QoinBulkMode.overwrite);
    });

    testWidgets('체크박스 상태는 다이얼로그를 열 때마다 미체크로 시작', (t) async {
      await pump(t);
      await t.tap(find.text('개별 설정 덮어쓰기'));
      await t.pump();
      await t.tap(saveButton('브랜드 설정 저장'));
      await t.pumpAndSettle();
      await t.tap(find.byType(Checkbox));
      await t.pump();
      await t.tap(find.text('취소'));
      await t.pumpAndSettle();
      await t.tap(saveButton('브랜드 설정 저장'));
      await t.pumpAndSettle();
      expect(t.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    });
  });
}

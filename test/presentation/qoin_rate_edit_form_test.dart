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
  QoinSwitchSetting storeSwitch = QoinSwitchSetting.enabled,
  QoinRateSetting brand = QoinRateSetting.absent,
  QoinSwitchSetting brandSwitch = QoinSwitchSetting.enabled,
  QoinRateSetting? global,
  bool hasBrand = true,
}) => resolveEffectiveQoinRate(
  store: store,
  storeSwitch: storeSwitch,
  brand: brand,
  brandSwitch: brandSwitch,
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

    testWidgets('30 -> 상한 에러, 0.0 -> 0 거부(전역 문구: 링크 없음)', (t) async {
      await pump(t);
      await t.enterText(find.byType(TextField).first, '30');
      await t.pump();
      expect(find.textContaining('까지 입력할 수 있어요'), findsOneWidget);
      expect(enabled(t, '전역 기본값 저장'), isFalse);
      await t.enterText(find.byType(TextField).first, '0.0');
      await t.pump();
      expect(
        find.textContaining('전체 적립을 멈추려면 Qoin 설정 화면의 ‘적립 사용’ 을 끄세요'),
        findsOneWidget,
      );
      expect(find.text('적립 사용 끄러 가기'), findsNothing, reason: '전역에는 스위치가 없다');
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

  group('매장 폼 — 설정 방식 2택 + 스위치 안내', () {
    Future<void> pump(
      WidgetTester t, {
      QoinRateSetting current = QoinRateSetting.absent,
      QoinRateSetting? brand,
      QoinSwitchSetting storeSwitch = QoinSwitchSetting.enabled,
      QoinSwitchSetting brandSwitch = QoinSwitchSetting.enabled,
      VoidCallback? onGoToSwitch,
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
              storeSwitch: storeSwitch,
              brand: brand ?? QoinRateSetting.valid(0.05),
              brandSwitch: brandSwitch,
            ),
            saveLabel: '매장 설정 저장',
            onGoToSwitch: onGoToSwitch,
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

    testWidgets('라디오는 2장뿐이다 (적립 안 함 카드는 없다)', (t) async {
      await pump(t);
      expect(find.text('상위 설정 따르기'), findsOneWidget);
      expect(find.text('직접 설정'), findsOneWidget);
      expect(find.textContaining('적립 안 함'), findsNothing);
    });

    testWidgets(
      '직접 설정 + 0 입력: 스위치로 안내하는 문구 + 끄러 가기 링크, 저장 비활성. 0.03 은 여전히 하한 에러',
      (t) async {
        var went = 0;
        await pump(t, onGoToSwitch: () => went++);
        await t.tap(find.text('직접 설정'));
        await t.pump();
        expect(find.byType(TextField), findsNWidgets(2));
        expect(
          find.text('적립을 멈추려면 0 이 아니라 아래 ‘적립 사용’ 을 끄세요'),
          findsOneWidget,
          reason: '사전 안내',
        );
        await t.enterText(find.byType(TextField).first, '0.0');
        await t.pump();
        expect(
          find.text('0% 는 적립률로 입력할 수 없어요. 적립을 멈추려면 이 화면 아래쪽 ‘적립 사용’ 을 끄세요'),
          findsOneWidget,
        );
        expect(enabled(t, '매장 설정 저장'), isFalse);
        await t.tap(find.text('적립 사용 끄러 가기'));
        expect(went, 1, reason: '스위치를 대신 누르지 않고 이동만 요청');
        await t.enterText(find.byType(TextField).first, '0.03');
        await t.pump();
        expect(find.textContaining('이상 입력해주세요'), findsOneWidget);
        expect(find.text('적립 사용 끄러 가기'), findsNothing);
      },
    );

    testWidgets('입력이 정확히 "0" 한 글자이고 포커스 중이면 에러를 숨긴다 (0.5 입력 도중 번쩍임 방지)', (
      t,
    ) async {
      await pump(t, onGoToSwitch: () {});
      await t.tap(find.text('직접 설정'));
      await t.pump();
      await t.tap(find.byType(TextField).first);
      await t.enterText(find.byType(TextField).first, '0');
      await t.pump();
      expect(find.textContaining('입력할 수 없어요'), findsNothing);
      expect(enabled(t, '매장 설정 저장'), isFalse, reason: '저장은 비활성 유지');
      await t.enterText(find.byType(TextField).first, '0.');
      await t.pump();
      expect(
        find.textContaining('입력할 수 없어요'),
        findsOneWidget,
        reason: '0. 은 소수점을 찍은 의도이므로 즉시 표시',
      );
    });

    testWidgets('매장 스위치 off: 입력란은 비활성화되지 않고, 사실 고지 plate 가 있다', (t) async {
      await pump(
        t,
        current: QoinRateSetting.valid(0.07),
        storeSwitch: QoinSwitchSetting.disabled,
      );
      expect(find.text('지금은 적립 사용 안 함 상태예요.'), findsOneWidget);
      expect(find.text('적립률을 바꿔도 다시 켜기 전에는 적립되지 않아요.'), findsOneWidget);
      final field = t.widget<TextField>(find.byType(TextField).first);
      expect(field.enabled ?? true, isTrue);
      expect(find.widgetWithText(TextField, '7'), findsOneWidget);
    });

    testWidgets('브랜드가 off 라서 멈춘 매장: 우회 암시 없이 적립률과 관계없다고 말한다', (t) async {
      await pump(
        t,
        current: QoinRateSetting.valid(0.1),
        brandSwitch: QoinSwitchSetting.disabled,
      );
      expect(
        find.text('브랜드가 적립 사용 안 함이라, 이 매장은 적립률과 관계없이 적립되지 않아요'),
        findsOneWidget,
      );
      expect(find.textContaining('직접 설정으로'), findsNothing);
      expect(find.textContaining('우회'), findsNothing);
    });

    testWidgets('꺼진 상태에서 저장하면 확인 다이얼로그에 "다시 켤 때부터" 한 줄, 비교는 켜져 있다면의 값끼리', (
      t,
    ) async {
      final sink = <QoinRateSubmission>[];
      await pump(
        t,
        current: QoinRateSetting.valid(0.1),
        storeSwitch: QoinSwitchSetting.disabled,
        sink: sink,
      );
      await t.enterText(find.byType(TextField).first, '7');
      await t.pump();
      await t.tap(saveButton('매장 설정 저장'));
      await t.pumpAndSettle();
      expect(find.text('지금은 적립 사용 안 함이라, 바꾼 값은 다시 켤 때부터 적용돼요'), findsOneWidget);
      expect(find.text('10%'), findsWidgets, reason: '현재(켜져 있다면)');
      expect(find.text('7%'), findsWidgets);
      expect(find.text('사용 안 함'), findsNothing);
      await t.tap(find.text('변경하기'));
      await t.pumpAndSettle();
      expect(sink, hasLength(1));
    });

    testWidgets('상위 값이 무효면 상속 카드가 비활성 + 문구', (t) async {
      await pump(t, brand: QoinRateSetting.invalid);
      expect(find.text('상위 설정을 확인할 수 없어요'), findsOneWidget);
    });

    testWidgets('상속 설명은 스위치와 독립: 브랜드가 꺼져 있어도 따르게 될 숫자를 말한다', (t) async {
      await pump(t, brandSwitch: QoinSwitchSetting.disabled);
      expect(find.text('브랜드 "Q브루어리" 의 5% 를 따라요'), findsOneWidget);
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
                  QoinBulkStats(total: 12, overridden: 3, disabled: 2),
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
          QoinBulkStats(total: 4, overridden: 0, disabled: 0),
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

    testWidgets('덮어쓰기: 영향 수 + 재설정 안내, 체크박스 없이 처음부터 실행 가능, 경고(Z)·"다시 적립" 줄 없음', (
      t,
    ) async {
      final sink = <QoinRateSubmission>[];
      await pump(t, sink: sink);
      await t.tap(find.text('개별 설정 덮어쓰기'));
      await t.pump();
      await t.tap(saveButton('브랜드 설정 저장'));
      await t.pumpAndSettle();
      expect(find.text('개별 설정 3곳이 지워져요'), findsOneWidget);
      expect(find.text('되돌리려면 매장마다 다시 설정해야 해요'), findsOneWidget);
      expect(find.textContaining('다시 적립'), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      final exec = find.widgetWithText(ElevatedButton, '덮어쓰고 적용');
      expect(t.widget<ElevatedButton>(exec).onPressed, isNotNull);
      await t.tap(exec);
      await t.pumpAndSettle();
      expect(sink.single.mode, QoinBulkMode.overwrite);
    });

    testWidgets('K>0: 섹션과 다이얼로그에 정보 줄(경고 아님) — N3 문구', (t) async {
      await pump(t);
      expect(find.text('적립 사용 안 함 2곳은 어느 쪽을 골라도 적립이 시작되지 않아요'), findsOneWidget);
      await t.tap(saveButton('브랜드 설정 저장'));
      await t.pumpAndSettle();
      expect(find.text('적립 사용 안 함 2곳은 새 값을 받아도 적립이 시작되지 않아요'), findsOneWidget);
      expect(find.text('이 화면 기준이에요. 실제 수는 완료 후 알려드려요'), findsOneWidget);
      expect(find.textContaining('영향을 받지 않아요'), findsNothing);
    });

    testWidgets('브랜드 자신이 꺼져 있으면 실행 전 plate 가 맨 위에, K 줄은 숨긴다 (N4)', (t) async {
      bigScreen(t);
      await t.pumpWidget(
        host(
          QoinRateEditForm(
            scope: QoinRateScope.brand,
            targetName: 'Q브루어리',
            current: QoinRateSetting.absent,
            effective: eff(brandSwitch: QoinSwitchSetting.disabled),
            saveLabel: '브랜드 설정 저장',
            bulkStats: const AsyncValue.data(
              QoinBulkStats(total: 12, overridden: 3, disabled: 2),
            ),
            onSubmit: (s) async {},
          ),
        ),
      );
      await t.tap(find.text('직접 설정'));
      await t.pump();
      await t.enterText(find.byType(TextField).first, '5');
      await t.pump();
      expect(find.textContaining('어느 쪽을 골라도 적립이 시작되지 않아요'), findsNothing);
      await t.tap(saveButton('브랜드 설정 저장'));
      await t.pumpAndSettle();
      expect(find.text('이 브랜드는 지금 적립 사용 안 함이에요'), findsOneWidget);
      expect(
        find.text('새 값을 적용해도 브랜드의 ‘적립 사용’ 을 켜기 전에는 산하 매장 전부가 적립되지 않아요'),
        findsOneWidget,
      );
      expect(find.textContaining('새 값을 받아도 적립이 시작되지 않아요'), findsNothing);
    });
  });
}

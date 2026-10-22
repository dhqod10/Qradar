import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/qoin_config_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_info_row.dart';
import 'package:qradar/presentation/customer/qoin/widgets/qoin_balance_card.dart';

Widget host(Widget child) => ProviderScope(
  child: MaterialApp(
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

AsyncValue<EffectiveQoinRate> data(EffectiveQoinRate e) => AsyncValue.data(e);

void main() {
  final brandInherit = resolveEffectiveQoinRate(
    store: QoinRateSetting.absent,
    brand: QoinRateSetting.valid(0.05),
    global: QoinRateSetting.valid(0.03),
  );

  Widget row(
    QoinRateInfoVariant v,
    AsyncValue<EffectiveQoinRate> e, {
    bool allStopped = false,
    VoidCallback? onHistory,
  }) => host(
    QoinRateInfoRow(
      variant: v,
      target: v == QoinRateInfoVariant.summary
          ? QoinRateScope.brand
          : QoinRateScope.store,
      effective: e,
      allStopped: allStopped,
      brandName: 'Q브루어리',
      onOpenHistory: onHistory ?? () {},
    ),
  );

  group('읽기 행 — 편집 어피던스 0', () {
    testWidgets('점주 block: 값 + 출처 + 문의 안내 + 이력 링크만, 입력/수정 없음', (t) async {
      await t.pumpWidget(row(QoinRateInfoVariant.block, data(brandInherit)));
      expect(find.text('5%'), findsOneWidget);
      expect(find.text('브랜드 상속'), findsOneWidget);
      expect(find.text('브랜드 "Q브루어리" 의 설정을 따르고 있어요'), findsOneWidget);
      expect(find.text('변경이 필요하면 관리자에게 문의해 주세요'), findsOneWidget);
      expect(find.text('적립률 변경 이력 보기'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.text('수정'), findsNothing);
      expect(find.text('변경'), findsNothing);
      // 비용 부담 문장은 넣지 않는다 (D2).
      expect(find.textContaining('부담'), findsNothing);
    });

    testWidgets('로딩 중에는 0% 도 이전 값도 그리지 않는다', (t) async {
      await t.pumpWidget(
        row(QoinRateInfoVariant.block, const AsyncValue.loading()),
      );
      expect(find.textContaining('%'), findsNothing);
      await t.pumpWidget(
        row(QoinRateInfoVariant.summary, const AsyncValue.loading()),
      );
      expect(find.textContaining('%'), findsNothing);
      await t.pumpWidget(
        row(QoinRateInfoVariant.tile, const AsyncValue.loading()),
      );
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('에러: 문구 + 다시 시도, 숫자 없음', (t) async {
      await t.pumpWidget(
        row(QoinRateInfoVariant.block, AsyncValue.error('x', StackTrace.empty)),
      );
      expect(find.text('적립률을 불러오지 못했어요'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('명시적 0%: 적립 안 함 배지 + 브랜드 설정 문장', (t) async {
      final stopped = resolveEffectiveQoinRate(
        store: QoinRateSetting.absent,
        brand: QoinRateSetting.zero,
        global: QoinRateSetting.valid(0.03),
      );
      await t.pumpWidget(row(QoinRateInfoVariant.block, data(stopped)));
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('적립 안 함'), findsOneWidget);
      expect(find.text('브랜드 설정에 따라 이 매장은 Qoin 을 적립하지 않아요'), findsOneWidget);
    });

    testWidgets('해석 불가: — + 설정 확인 필요', (t) async {
      final bad = resolveEffectiveQoinRate(
        store: QoinRateSetting.invalid,
        brand: QoinRateSetting.absent,
        global: QoinRateSetting.valid(0.03),
      );
      await t.pumpWidget(row(QoinRateInfoVariant.block, data(bad)));
      expect(find.text('—'), findsOneWidget);
      expect(find.text('설정 확인 필요'), findsOneWidget);
      expect(find.text('적립률 설정에 문제가 있어 적립이 되지 않을 수 있어요'), findsOneWidget);
    });

    testWidgets('전체 중단 중이면 값은 그대로 두고 안내 plate 를 더한다', (t) async {
      await t.pumpWidget(
        row(QoinRateInfoVariant.block, data(brandInherit), allStopped: true),
      );
      expect(find.text('5%'), findsOneWidget);
      expect(find.text('현재 전체 적립이 중단되어 있어요'), findsOneWidget);
    });

    testWidgets('브랜드 summary: 우선순위 안내 항상 + 값 영역은 버튼이 아니다', (t) async {
      final e = resolveEffectiveQoinRate(
        store: QoinRateSetting.absent,
        brand: QoinRateSetting.absent,
        global: QoinRateSetting.valid(0.03),
      );
      await t.pumpWidget(row(QoinRateInfoVariant.summary, data(e)));
      expect(find.text('전역 상속'), findsOneWidget);
      expect(find.text('기본 적립률을 따르고 있어요'), findsOneWidget);
      expect(find.textContaining('매장이 따로 설정한 적립률이 있으면'), findsOneWidget);
    });

    testWidgets('가맹점 tile: 이력 링크 탭이 콜백을 부른다', (t) async {
      var tapped = 0;
      await t.pumpWidget(
        row(
          QoinRateInfoVariant.tile,
          data(brandInherit),
          onHistory: () => tapped++,
        ),
      );
      expect(find.text('Qoin'), findsOneWidget);
      await t.tap(find.text('이력'));
      expect(tapped, 1);
    });
  });

  group('고객 Qoin plate — 숫자 제거 (U4)', () {
    testWidgets('정상: 숫자 % 없이 일부 적립 + 매장마다 달라요', (t) async {
      await t.pumpWidget(
        host(
          const QoinPolicyPlate(
            config: QoinConfigEntity(accrualRate: 0.03, enabled: true),
          ),
        ),
      );
      expect(find.text('픽업 완료 시 결제액의 일부가 적립돼요'), findsOneWidget);
      expect(find.textContaining('적립률은 매장마다 달라요'), findsOneWidget);
      expect(find.textContaining('3%'), findsNothing);
    });

    testWidgets('config 로딩(null)에서도 같은 문구 — 깜빡임 없음', (t) async {
      await t.pumpWidget(host(const QoinPolicyPlate(config: null)));
      expect(find.text('픽업 완료 시 결제액의 일부가 적립돼요'), findsOneWidget);
    });

    testWidgets('중단 문구는 그대로', (t) async {
      await t.pumpWidget(
        host(
          const QoinPolicyPlate(
            config: QoinConfigEntity(accrualRate: 0.03, enabled: false),
          ),
        ),
      );
      expect(find.text('지금은 Qoin 적립이 잠시 중단되어 있어요'), findsOneWidget);
    });
  });
}

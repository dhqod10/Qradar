import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_rate_chain.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_reenable_hint.dart';

/// `다시 켜면 …` 문장은 위젯이 아니라 resolver 를 한 번 더 돌린 결과다 (design §18-3 / §18-13-2).
/// D(브랜드 꺼짐)가 A(개별 적립률) 보다 먼저 맞는 것은 resolver 가 스위치 단계를 숫자 단계 앞에 두기 때문이다.
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

void main() {
  final off = QoinSwitchSetting.disabled;

  group('QoinReenableHint.of — 매장 화면', () {
    test('B: 매장만 꺼짐, 브랜드 5% -> 브랜드 5% 가 적용', () {
      final h = QoinReenableHint.of(
        eff(storeSwitch: off, brand: QoinRateSetting.valid(0.05)),
        target: QoinRateScope.store,
      )!;
      expect(h.kind, QoinReenableKind.brandRate);
      expect(h.headline, '다시 켜면 브랜드 5% 가 적용돼요');
      expect(h.sub, '끄기 전 값이 아니라 지금의 요율이에요');
      expect(h.dialogSub, '끄기 전에 어떤 값이었는지와 관계없이 지금의 요율이에요');
    });

    test('C: 브랜드 적립률 없음 -> 전역 기본값', () {
      final h = QoinReenableHint.of(
        eff(storeSwitch: off),
        target: QoinRateScope.store,
      )!;
      expect(h.kind, QoinReenableKind.globalRate);
      expect(h.headline, '다시 켜면 전역 기본값 3% 가 적용돼요');
    });

    test('A: 매장 개별 적립률 7% 가 남아 있고 브랜드가 켜져 있으면 그 숫자가 적용', () {
      final h = QoinReenableHint.of(
        eff(
          store: QoinRateSetting.valid(0.07),
          storeSwitch: off,
          brand: QoinRateSetting.valid(0.05),
        ),
        target: QoinRateScope.store,
      )!;
      expect(h.kind, QoinReenableKind.storeOwnRate);
      expect(h.headline, '다시 켜면 이 매장의 개별 적립률 7% 가 적용돼요');
    });

    test('D 가 A 를 앞선다 (N4): 개별 적립률이 있어도 브랜드가 꺼져 있으면 켜도 적립되지 않는다', () {
      final h = QoinReenableHint.of(
        eff(
          store: QoinRateSetting.valid(0.07),
          storeSwitch: off,
          brand: QoinRateSetting.valid(0.05),
          brandSwitch: off, // R24: 둘 다 꺼짐
        ),
        target: QoinRateScope.store,
      )!;
      expect(h.kind, QoinReenableKind.brandStillOff);
      expect(h.headline, '다시 켜도 브랜드가 사용 안 함이라 적립되지 않아요');
      expect(h.sub, '브랜드의 ‘적립 사용’ 도 켜야 해요');
      expect(h.headline.contains('개별'), isFalse);
    });

    test('E: 켜도 설정에 문제가 있다 (전역 부재)', () {
      final h = QoinReenableHint.of(
        eff(storeSwitch: off, global: QoinRateSetting.absent),
        target: QoinRateScope.store,
      )!;
      expect(h.kind, QoinReenableKind.invalid);
      expect(h.headline, '다시 켜도 적립률 설정에 문제가 있어 적립되지 않을 수 있어요');
    });

    test('브랜드가 꺼져서 멈춘 매장(매장 스위치는 켜짐): 우회 암시 없이 브랜드를 켜라고 말한다', () {
      final h = QoinReenableHint.of(
        eff(
          store: QoinRateSetting.valid(0.1),
          brand: QoinRateSetting.valid(0.05),
          brandSwitch: off,
        ),
        target: QoinRateScope.store,
      )!;
      expect(h.kind, QoinReenableKind.brandBlocksStore);
      expect(h.headline, '브랜드가 사용 안 함이라 이 매장은 적립하지 않아요');
      expect(
        h.sub,
        '브랜드의 ‘적립 사용’ 을 켜야 이 매장이 적립해요 · 브랜드를 켜면 이 매장의 개별 적립률 10% 가 적용돼요',
      );
      expect(h.sub!.contains('직접 설정'), isFalse);
    });

    test('켜져 있으면 null (고지 없음)', () {
      expect(QoinReenableHint.of(eff(), target: QoinRateScope.store), isNull);
    });
  });

  group('QoinReenableHint.of — 브랜드 화면 (A 없음)', () {
    test('B / C / E', () {
      final b = QoinReenableHint.of(
        eff(brand: QoinRateSetting.valid(0.05), brandSwitch: off),
        target: QoinRateScope.brand,
      )!;
      expect(b.headline, '다시 켜면 브랜드 5% 가 적용돼요');
      final c = QoinReenableHint.of(
        eff(brandSwitch: off),
        target: QoinRateScope.brand,
      )!;
      expect(c.headline, '다시 켜면 전역 기본값 3% 가 적용돼요');
      final e = QoinReenableHint.of(
        eff(brandSwitch: off, global: QoinRateSetting.invalid),
        target: QoinRateScope.brand,
      )!;
      expect(e.kind, QoinReenableKind.invalid);
    });
  });

  group('사슬 위젯은 같은 문장을 그린다', () {
    Future<void> pump(WidgetTester t, EffectiveQoinRate e, QoinRateScope s) =>
        t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: QoinRateChain(effective: e, target: s),
            ),
          ),
        );

    testWidgets('R24 (둘 다 꺼짐): 매장 줄이 이기고 브랜드 줄은 가려짐, 하단은 D', (t) async {
      await pump(
        t,
        eff(
          store: QoinRateSetting.valid(0.07),
          storeSwitch: off,
          brand: QoinRateSetting.valid(0.05),
          brandSwitch: off,
        ),
        QoinRateScope.store,
      );
      expect(find.text('사용 안 함'), findsNWidgets(2));
      expect(find.text('적용 중'), findsOneWidget);
      expect(find.text('(가려짐)'), findsOneWidget);
      expect(find.text('개별 적립률 7% 가 설정돼 있어요'), findsOneWidget);
      expect(find.text('다시 켜도 브랜드가 사용 안 함이라 적립되지 않아요'), findsOneWidget);
      expect(find.text('5%'), findsNothing, reason: '꺼진 줄은 숫자를 보이지 않는다');
    });

    testWidgets('브랜드만 꺼짐: 10% 가 적용 중으로 보이는 행은 존재하지 않는다 (N4)', (t) async {
      await pump(
        t,
        eff(
          store: QoinRateSetting.valid(0.1),
          brand: QoinRateSetting.valid(0.05),
          brandSwitch: off,
        ),
        QoinRateScope.store,
      );
      expect(find.text('적용 중'), findsOneWidget);
      // 적용 중 pill 은 브랜드 줄에 있고, 매장 10% 는 (가려짐).
      expect(find.text('10%'), findsOneWidget);
      expect(find.text('(가려짐)'), findsOneWidget);
      expect(find.text('브랜드가 사용 안 함이라 이 매장은 적립하지 않아요'), findsOneWidget);
    });

    testWidgets('켜져 있으면 하단 고지 블록이 없다', (t) async {
      await pump(
        t,
        eff(brand: QoinRateSetting.valid(0.05)),
        QoinRateScope.store,
      );
      expect(find.textContaining('다시 켜'), findsNothing);
      expect(find.text('5%'), findsOneWidget);
    });
  });
}

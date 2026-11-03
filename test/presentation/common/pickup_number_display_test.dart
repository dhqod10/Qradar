import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/presentation/common/widgets/pickup_number_display.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('number == null 이면 아무것도 그리지 않는다 (hero/badge)', (t) async {
    for (final v in [PickupNumberVariant.hero, PickupNumberVariant.badge]) {
      await t.pumpWidget(
        _wrap(PickupNumberDisplay(number: null, variant: v)),
      );
      expect(find.byType(Text), findsNothing);
    }
  });

  testWidgets('hero: 제로패딩 없이 숫자 + 라벨 + 캡션', (t) async {
    await t.pumpWidget(
      _wrap(
        const PickupNumberDisplay(
          number: 3,
          variant: PickupNumberVariant.hero,
          caption: '매장에서 이 번호를 보여주세요',
        ),
      ),
    );
    expect(find.text('3'), findsOneWidget);
    expect(find.text('픽업 번호'), findsOneWidget);
    expect(find.text('매장에서 이 번호를 보여주세요'), findsOneWidget);
  });

  testWidgets('badge: 4자리도 오버플로 없이 렌더', (t) async {
    await t.pumpWidget(
      _wrap(
        const PickupNumberDisplay(
          number: 1234,
          variant: PickupNumberVariant.badge,
        ),
      ),
    );
    expect(find.text('1234'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('inline: #N · suffix, null 이면 suffix 만', (t) async {
    await t.pumpWidget(
      _wrap(
        const PickupNumberDisplay(
          number: 3,
          variant: PickupNumberVariant.inline,
          inlineSuffix: '3분 전',
        ),
      ),
    );
    expect(find.text('#3 · 3분 전', findRichText: true), findsOneWidget);
    await t.pumpWidget(
      _wrap(
        const PickupNumberDisplay(
          number: null,
          variant: PickupNumberVariant.inline,
          inlineSuffix: '3분 전',
        ),
      ),
    );
    expect(find.text('3분 전'), findsOneWidget);
    expect(find.textContaining('#'), findsNothing);
  });
}

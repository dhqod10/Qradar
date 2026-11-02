import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/domain/entities/business_hours.dart';
import 'package:qradar/presentation/owner/my_store/widgets/weekly_schedule_editor.dart';

Widget _host(
  BusinessHours? value,
  ValueChanged<BusinessHours?> onChanged, {
  bool required = false,
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: WeeklyScheduleEditor(
        value: value,
        onChanged: onChanged,
        required: required,
      ),
    ),
  ),
);

class _Holder extends StatefulWidget {
  const _Holder({required this.initial, this.required = false, required this.sink});
  final BusinessHours? initial;
  final bool required;
  final List<BusinessHours?> sink;
  @override
  State<_Holder> createState() => _HolderState();
}

class _HolderState extends State<_Holder> {
  late BusinessHours? v = widget.initial;
  @override
  Widget build(BuildContext context) => _host(v, (h) {
    widget.sink.add(h);
    setState(() => v = h);
  }, required: widget.required);
}

void main() {
  testWidgets('미설정(null): 시간 제한 없음 안내 + 설정하기 -> 월~금 09~18 기본', (tester) async {
    final sink = <BusinessHours?>[];
    await tester.pumpWidget(_Holder(initial: null, sink: sink));
    expect(find.textContaining('시간 제한 없이 주문을 받아요'), findsOneWidget);
    await tester.tap(find.text('영업 스케줄 설정하기'));
    await tester.pumpAndSettle();
    final h = sink.last!;
    expect(h.weeklyHours.keys.toList()..sort(), [1, 2, 3, 4, 5]);
    expect(h.weeklyHours[1], WeeklyScheduleEditor.defaultDay);
    expect(find.text('월~금 09:00–18:00 · 토·일 휴무'), findsOneWidget);
    expect(find.text('평일'), findsOneWidget);
  });

  testWidgets('필수(등록): 스케줄 사용 안 함 버튼이 없고 필수 안내가 보인다', (tester) async {
    await tester.pumpWidget(
      _Holder(initial: null, required: true, sink: <BusinessHours?>[]),
    );
    expect(find.textContaining('설정하지 않으면 등록할 수 없어요'), findsOneWidget);
    expect(find.text('스케줄 사용 안 함'), findsNothing);
  });

  testWidgets('토요일 스위치 켜기 -> 09:00~18:00, 요약 갱신 / 전체 휴무 경고', (tester) async {
    final sink = <BusinessHours?>[];
    await tester.pumpWidget(
      _Holder(
        initial: BusinessHours(
          weeklyHours: {
            for (var d = 1; d <= 5; d++)
              d: WeeklyScheduleEditor.defaultDay,
          },
        ),
        sink: sink,
      ),
    );
    // 평일 / 토 / 일 3행 -> Switch 3개. 토 = 두번째.
    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(3));
    await tester.tap(switches.at(1));
    await tester.pumpAndSettle();
    expect(sink.last!.weeklyHours[6], WeeklyScheduleEditor.defaultDay);
    expect(find.text('월~토 09:00–18:00 · 일 휴무'), findsOneWidget);

    // 평일 끄기 + 토 끄기 -> 전체 휴무 경고
    await tester.tap(find.byType(Switch).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();
    expect(sink.last!.weeklyHours, isEmpty);
    expect(find.text('모든 요일이 휴무예요'), findsOneWidget);
  });

  testWidgets('시작 == 종료 행은 오류 문구 + hasInvalidRow', (tester) async {
    const bad = BusinessHours(
      weeklyHours: {1: BusinessDayHours(open: '09:00', close: '09:00')},
    );
    expect(WeeklyScheduleEditor.hasInvalidRow(bad), isTrue);
    await tester.pumpWidget(_Holder(initial: bad, sink: <BusinessHours?>[]));
    expect(find.textContaining('시작과 종료 시간이 같아요'), findsOneWidget);
  });

  testWidgets('자정 넘김 행: 익일 힌트', (tester) async {
    const night = BusinessHours(
      weeklyHours: {6: BusinessDayHours(open: '22:00', close: '02:00')},
    );
    await tester.pumpWidget(_Holder(initial: night, sink: <BusinessHours?>[]));
    expect(find.text('다음날 02:00까지 영업해요'), findsOneWidget);
  });
}

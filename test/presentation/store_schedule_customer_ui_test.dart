import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/entities/business_hours.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/store_grade.dart';
import 'package:qradar/domain/entities/user_location.dart';
import 'package:qradar/presentation/common/store_open_state.dart';
import 'package:qradar/presentation/customer/cart/cart_line_availability.dart';
import 'package:qradar/presentation/customer/cart/widgets/cart_availability_banner.dart';
import 'package:qradar/presentation/customer/home/widgets/store_card.dart';
import 'package:qradar/presentation/customer/order/store/widgets/store_menu_header.dart';

StoreEntity _store({BusinessHours? hours, bool tempClosed = false}) =>
    StoreEntity(
      id: 's1',
      name: '강남점',
      imageUrl: '',
      location: const UserLocation(latitude: 37.5, longitude: 127.0),
      grade: StoreGrade.c,
      averageScore: 0,
      reviewCount: 0,
      menuCategories: const [],
      createdAt: DateTime(2026, 1, 1),
      businessHours: hours,
      temporaryClosed: tempClosed,
    );

// 모든 요일 영업 시간 구간이 "현재 시각과 절대 겹치지 않는" 스케줄을 만들 수 없으므로
// 24시간(00:00~23:59) 영업 / 전체 휴무 두 극단으로 상태를 결정론적으로 만든다.
final _always = BusinessHours(
  weeklyHours: {
    for (var d = 1; d <= 7; d++)
      d: const BusinessDayHours(open: '00:00', close: '23:59'),
  },
);
const _never = BusinessHours(weeklyHours: {});

/// 개점·폐점 경계를 넘기는 상황을 만들기 위한 보통의 영업 스케줄 (매일 09:00~18:00).
final _nineToSix = BusinessHours(
  weeklyHours: {
    for (var d = 1; d <= 7; d++)
      d: const BusinessDayHours(open: '09:00', close: '18:00'),
  },
);

/// 분 틱을 한 번 흘리고 화면에 반영될 때까지 기다린다.
/// StreamProvider 가 새 값을 AsyncData 로 바꾸는 데 한 프레임, 그걸 받아 다시 그리는 데
/// 또 한 프레임이 든다 — pump 한 번만 하면 직전 값이 그대로 보인다.
Future<void> _emitTick(WidgetTester t, StreamController<DateTime> tick, DateTime at) async {
  tick.add(at);
  await t.pump();
  await t.pump();
}

Future<void> _pumpHeader(WidgetTester t, StoreEntity s) async {
  await t.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: StoreMenuHeader(
              store: s,
              isFavorite: false,
              onFavoriteTap: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await t.pump();
}

void main() {
  group('매장 상세 헤더 (공용 StoreOpenState)', () {
    testWidgets('스케줄 미설정(null): 영업 상태 표시 없음 (기존 매장 회귀 0)', (t) async {
      await _pumpHeader(t, _store());
      expect(find.text('영업 중'), findsNothing);
      expect(find.text('정기 휴무'), findsNothing);
      expect(find.text('영업시간 아님'), findsNothing);
      expect(find.text('마감'), findsNothing);
    });

    testWidgets('전체 휴무(빈 맵): 정기 휴무 배지', (t) async {
      await _pumpHeader(t, _store(hours: _never));
      expect(find.text('정기 휴무'), findsOneWidget);
    });

    testWidgets('24시간 스케줄: 영업 중 · 까지', (t) async {
      await _pumpHeader(t, _store(hours: _always));
      expect(find.textContaining('영업 중'), findsOneWidget);
      expect(find.textContaining('23:59까지'), findsOneWidget);
    });

    testWidgets('임시 휴업은 스케줄보다 우선', (t) async {
      await _pumpHeader(t, _store(hours: _never, tempClosed: true));
      expect(find.text('임시 휴업중'), findsOneWidget);
      expect(find.text('정기 휴무'), findsNothing);
    });
  });

  group('홈 카드 영업상태 배지 (Q5)', () {
    Future<void> pump(WidgetTester t, StoreEntity s) => t.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: Scaffold(body: StoreOpenBadge(store: s))),
      ),
    );

    testWidgets('미설정 = 표시 없음', (t) async {
      await pump(t, _store());
      expect(find.byType(Text), findsNothing);
    });
    testWidgets('휴무 / 임시 휴업 / 영업 중', (t) async {
      await pump(t, _store(hours: _never));
      expect(find.text('정기 휴무'), findsOneWidget);
      await pump(t, _store(hours: _never, tempClosed: true));
      expect(find.text('임시 휴업'), findsOneWidget);
      await pump(t, _store(hours: _always));
      expect(find.text('영업 중'), findsOneWidget);
    });

    // 회귀: 예전에는 배지가 `DateTime.now()` 로 한 번만 계산해, 앱을 켜 둔 채 개점 시각을
    // 넘기면 열린 매장이 계속 `영업시간 아님` 으로 보였다. 하단 탭 전환이 위젯을 살려 두는
    // 탓에 홈을 들락거려도 다시 그려지지 않았다. 이제 상세 화면들과 같은 분 틱을 구독한다.
    testWidgets('개점 시각을 넘기면 다시 그리지 않아도 배지가 바뀐다', (t) async {
      final tick = StreamController<DateTime>.broadcast();
      addTearDown(tick.close);

      await t.pumpWidget(
        ProviderScope(
          overrides: [minuteTickProvider.overrideWith((ref) => tick.stream)],
          child: MaterialApp(
            home: Scaffold(body: StoreOpenBadge(store: _store(hours: _nineToSix))),
          ),
        ),
      );

      // 개점 1분 전 — 닫혀 있다.
      await _emitTick(t, tick, DateTime(2026, 11, 26, 8, 59));
      expect(find.text('영업시간 아님'), findsOneWidget);
      expect(find.text('영업 중'), findsNothing);

      // 09:00 을 넘기면 **같은 위젯이** 스스로 바뀐다 (pumpWidget 을 다시 부르지 않는다).
      await _emitTick(t, tick, DateTime(2026, 11, 26, 9, 1));
      expect(find.text('영업 중'), findsOneWidget);
      expect(find.text('영업시간 아님'), findsNothing);

      // 폐점도 마찬가지다.
      await _emitTick(t, tick, DateTime(2026, 11, 26, 18, 1));
      expect(find.text('영업시간 아님'), findsOneWidget);
      expect(find.text('영업 중'), findsNothing);
    });

    testWidgets('임시 휴업은 틱과 무관하게 우선한다', (t) async {
      final tick = StreamController<DateTime>.broadcast();
      addTearDown(tick.close);

      await t.pumpWidget(
        ProviderScope(
          overrides: [minuteTickProvider.overrideWith((ref) => tick.stream)],
          child: MaterialApp(
            home: Scaffold(
              body: StoreOpenBadge(
                store: _store(hours: _nineToSix, tempClosed: true),
              ),
            ),
          ),
        ),
      );

      await _emitTick(t, tick, DateTime(2026, 11, 26, 12, 0)); // 영업시간 한복판
      expect(find.text('임시 휴업'), findsOneWidget);
      expect(find.text('영업 중'), findsNothing);
    });
  });

  testWidgets('카트 배너 storeClosedSchedule: 다음 영업 시각 포함/생략', (t) async {
    expect(
      CartAvailabilityBanner.titleOf(CartBannerVariant.storeClosedSchedule),
      '지금은 매장이 문을 닫았어요',
    );
    expect(
      CartAvailabilityBanner.bodyOf(
        CartBannerVariant.storeClosedSchedule,
        nextOpenText: '내일(수) 09:00',
      ),
      contains('다음 영업: 내일(수) 09:00.'),
    );
    expect(
      CartAvailabilityBanner.bodyOf(CartBannerVariant.storeClosedSchedule),
      isNot(contains('다음 영업')),
    );
  });
}

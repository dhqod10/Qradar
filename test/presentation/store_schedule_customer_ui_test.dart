import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/entities/business_hours.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/store_grade.dart';
import 'package:qradar/domain/entities/user_location.dart';
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
      MaterialApp(home: Scaffold(body: StoreOpenBadge(store: s))),
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

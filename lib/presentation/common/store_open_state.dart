import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/utils/store_schedule_format.dart';
import 'package:qradar/core/utils/store_sellability.dart';
import 'package:qradar/domain/entities/store_entity.dart';

/// 매장 영업 상태의 화면 공용 입력 (store_business_schedule design §3.0).
///
/// 판정은 `core/utils/store_sellability.dart` 의 [evaluateStoreOpenState] **한 곳**이다 (UI 전용 시간 계산 금지).
/// 기기 시계는 표시·선검증용이며 권위가 아니다 — 서버가 신뢰 시계로 최종 판정한다.
StoreOpenState storeOpenStateOf(StoreEntity store, DateTime now) =>
    evaluateStoreOpenStateAt(
      weeklyHours: store.businessHours?.scheduleInput,
      closedDates: store.closedDates,
      instant: now,
    );

/// 매 분 경계마다 [DateTime.now] 를 흘려 보내는 틱. 영업 시작/종료 시각을 넘으면 화면이 자동 갱신된다.
/// - 구독자가 없으면(autoDispose) 타이머가 취소된다 → 화면 dispose 시 자동 정리.
/// - 앱 resume 시 즉시 한 번 더 흘려 보내 재계산한다.
final minuteTickProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  Timer? timer;

  void schedule() {
    timer?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
    timer = Timer(next.difference(now), () {
      if (controller.isClosed) return;
      controller.add(DateTime.now());
      schedule();
    });
  }

  controller.add(DateTime.now());
  schedule();
  final lifecycle = AppLifecycleListener(
    onResume: () {
      if (controller.isClosed) return;
      controller.add(DateTime.now());
      schedule();
    },
  );
  ref.onDispose(() {
    timer?.cancel();
    lifecycle.dispose();
    controller.close();
  });
  return controller.stream;
});

/// 위젯 build 에서 쓰는 영업 상태. 시간에 영향받는 매장(스케줄 또는 특정 날짜 휴무가 있는 매장)일 때만 분 틱을 구독한다.
StoreOpenState watchStoreOpenState(WidgetRef ref, StoreEntity store) {
  final timeSensitive =
      store.businessHours != null || store.closedDates.isNotEmpty;
  final now = timeSensitive
      ? (ref.watch(minuteTickProvider).value ?? DateTime.now())
      : DateTime.now();
  return storeOpenStateOf(store, now);
}

/// 닫힘 상태 문구 (손님 화면 공용 — store_business_schedule design §3.2, §3.3). 서버 문자열은 쓰지 않는다.
class StoreClosedCopy {
  StoreClosedCopy._();

  /// 메뉴 상세 하단 버튼 라벨.
  static String buttonLabel(StoreOpenKind kind) =>
      kind == StoreOpenKind.regularHoliday
          ? '오늘은 휴무일이에요'
          : '지금은 영업시간이 아니에요';

  /// 배너 (제목, 본문).
  static ({String title, String body}) banner(
    StoreOpenState s,
    String todayDateKey,
  ) {
    final next = formatNextOpen(s.nextOpenAt, todayDateKey);
    if (next == null) {
      return (
        title: s.kind == StoreOpenKind.regularHoliday
            ? '오늘은 휴무일이에요'
            : '지금은 영업시간이 아니에요',
        body: '메뉴는 볼 수 있지만 지금은 주문을 받지 않아요.',
      );
    }
    if (s.kind == StoreOpenKind.regularHoliday) {
      return (
        title: '오늘은 휴무일이에요',
        body: '다음 영업: $next. 메뉴는 볼 수 있지만 주문은 영업일에 할 수 있어요.',
      );
    }
    final beforeOpen = s.nextOpenAt!.substring(0, 10) == todayDateKey;
    if (beforeOpen && s.todayRange != null) {
      return (
        title: '지금은 영업시간이 아니에요',
        body: '오늘 ${s.todayRange}에 영업해요. 메뉴는 볼 수 있지만 주문은 영업시간에 할 수 있어요.',
      );
    }
    return (
      title: '오늘 영업이 끝났어요',
      body: '다음 영업: $next. 메뉴는 볼 수 있지만 주문은 영업을 시작한 뒤에 할 수 있어요.',
    );
  }
}

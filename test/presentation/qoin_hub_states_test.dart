import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/qoin_bulk_banner.dart';
import 'package:qradar/domain/entities/qoin_config_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/admin/qoin/admin_qoin_settings_page.dart';
import 'package:qradar/presentation/admin/qoin/providers/qoin_admin_providers.dart';
import 'package:qradar/presentation/common/providers/qoin_config_providers.dart';
import 'package:qradar/presentation/common/providers/qoin_rate_providers.dart';

/// 허브 3상태 (H-3): partial 배너 / 최근 변경은 로딩·에러·없음·데이터를 서로 다르게 그린다.
/// 에러 때 사라지는 것("중단 없음" 과 "알 수 없음" 이 같아 보임)이 tester 가 결함으로 판정한 H-3 이다.
void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  final cfg = QoinConfigEntity(
    accrualRate: 0.03,
    accrualRateSetting: QoinRateSetting.valid(0.03),
    enabled: true,
  );
  BrandEntity brand(
    String id,
    String name, {
    QoinBulkStatus? status,
    DateTime? at,
    QoinSwitchSetting sw = QoinSwitchSetting.enabled,
  }) => BrandEntity(
    id: id,
    name: name,
    status: EntityApprovalStatus.approved,
    qoinBulkStatus: status,
    qoinBulkHistoryId: status == null ? null : 'h',
    qoinBulkAt: at,
    qoinAccrualEnabled: sw,
  );

  Widget app({
    Stream<List<BrandEntity>>? brands,
    Stream<List<QoinRateChangeEntity>>? history,
  }) => ProviderScope(
    overrides: [
      qoinConfigProvider.overrideWith((ref) => Stream.value(cfg)),
      qoinAdminBrandsProvider.overrideWith(
        (ref) => brands ?? Stream.value(<BrandEntity>[]),
      ),
      qoinAdminStoresProvider.overrideWith(
        (ref) => Stream.value(<StoreEntity>[]),
      ),
      qoinAllRateHistoryProvider.overrideWith(
        (ref, limit) => history ?? Stream.value(<QoinRateChangeEntity>[]),
      ),
    ],
    child: const MaterialApp(home: AdminQoinSettingsPage()),
  );

  void big(WidgetTester t) {
    t.view.physicalSize = const Size(800, 4000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  group('partial 배너 — 포인터 기반 3상태', () {
    testWidgets('로딩: skeleton 이 보인다 (배너도 "없음" 도 아니다)', (t) async {
      big(t);
      await t.pumpWidget(app(brands: const Stream.empty()));
      await t.pump();
      expect(find.text('일괄 적용 상태를 확인하고 있어요'), findsNothing);
      expect(find.bySemanticsLabel('일괄 적용 상태를 확인하고 있어요'), findsOneWidget);
      expect(find.text('끝나지 않은 일괄 적용이 있어요'), findsNothing);
      expect(find.text('일괄 적용 상태를 확인하지 못했어요'), findsNothing);
    });

    testWidgets('에러: 에러 배너 + 다시 시도 — 조용히 사라지지 않는다', (t) async {
      big(t);
      await t.pumpWidget(
        app(brands: Stream<List<BrandEntity>>.error(StateError('x'))),
      );
      await t.pumpAndSettle();
      expect(find.text('일괄 적용 상태를 확인하지 못했어요'), findsOneWidget);
      expect(
        find.text('끝나지 않은 일괄 적용이 있는지 알 수 없어요. 브랜드별 적립률에서 직접 확인해주세요'),
        findsOneWidget,
      );
      expect(find.text('다시 시도'), findsWidgets);
      expect(find.text('끝나지 않은 일괄 적용이 있어요'), findsNothing);
    });

    testWidgets('없음(스트림 정상 + 미완료 0건): 아무것도 그리지 않는다', (t) async {
      big(t);
      await t.pumpWidget(app(brands: Stream.value([brand('b1', 'A')])));
      await t.pumpAndSettle();
      expect(find.text('끝나지 않은 일괄 적용이 있어요'), findsNothing);
      expect(find.text('일괄 적용 상태를 확인하지 못했어요'), findsNothing);
      expect(find.bySemanticsLabel('일괄 적용 상태를 확인하고 있어요'), findsNothing);
    });

    testWidgets('데이터: partial 브랜드 1건 -> 브랜드명, 2건 -> 외 n건', (t) async {
      big(t);
      await t.pumpWidget(
        app(
          brands: Stream.value([
            brand('b1', 'Q브루어리', status: QoinBulkStatus.partial),
            brand('b2', '카페온', status: QoinBulkStatus.partial),
            brand('b3', '정상'),
          ]),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('끝나지 않은 일괄 적용이 있어요'), findsOneWidget);
      expect(find.text('브랜드 "Q브루어리" 외 1건'), findsOneWidget);
    });

    testWidgets('S2: 포인터가 종결(completed / superseded)이면 허브 배너가 없다 — 옛 이력이 partial 이어도', (t) async {
      big(t);
      await t.pumpWidget(
        app(
          brands: Stream.value([
            brand('b1', '종결됨', status: QoinBulkStatus.completed),
            brand('b2', '마감됨', status: QoinBulkStatus.superseded),
          ]),
          history: Stream.value(const <QoinRateChangeEntity>[]),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('끝나지 않은 일괄 적용이 있어요'), findsNothing);
      expect(find.text('일괄 적용 상태를 확인하지 못했어요'), findsNothing);
    });

    testWidgets('이력 쿼리가 에러여도 포인터 배너는 그대로 보인다 (인덱스 미배포와 독립)', (t) async {
      big(t);
      await t.pumpWidget(
        app(
          brands: Stream.value([
            brand('b1', 'A', status: QoinBulkStatus.partial),
          ]),
          history: Stream<List<QoinRateChangeEntity>>.error(
            StateError('index'),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('끝나지 않은 일괄 적용이 있어요'), findsOneWidget);
    });

    test('resolveBulkBanner: partial / 오래된 in_progress 만 미완료', () {
      final now = DateTime(2026, 10, 22, 12);
      expect(
        resolveBulkBanner(
          brand('a', 'a', status: QoinBulkStatus.partial),
          now,
        ).isUnfinished,
        isTrue,
      );
      expect(
        resolveBulkBanner(
          brand(
            'a',
            'a',
            status: QoinBulkStatus.inProgress,
            at: now.subtract(const Duration(minutes: 6)),
          ),
          now,
        ).isUnfinished,
        isTrue,
      );
      expect(
        resolveBulkBanner(
          brand(
            'a',
            'a',
            status: QoinBulkStatus.inProgress,
            at: now.subtract(const Duration(minutes: 1)),
          ),
          now,
        ).isUnfinished,
        isFalse,
      );
      expect(resolveBulkBanner(brand('a', 'a'), now).isUnfinished, isFalse);
    });
  });

  group('최근 변경 부제 — 로딩 / 에러 / 없음 / 데이터', () {
    testWidgets('에러: 이력을 불러오지 못했어요 + 다시 시도 (이력 화면을 열지 않는다)', (t) async {
      big(t);
      await t.pumpWidget(
        app(history: Stream<List<QoinRateChangeEntity>>.error(StateError('x'))),
      );
      await t.pumpAndSettle();
      expect(find.text('이력을 불러오지 못했어요'), findsOneWidget);
      expect(find.text('변경 이력이 없어요'), findsNothing);
      await t.tap(find.text('다시 시도').last);
      await t.pump();
      expect(find.text('변경 이력'), findsOneWidget, reason: '허브에 그대로 머문다');
    });

    testWidgets('없음: 에러와 다른 문구', (t) async {
      big(t);
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      expect(find.text('변경 이력이 없어요'), findsOneWidget);
      expect(find.text('이력을 불러오지 못했어요'), findsNothing);
    });

    testWidgets('로딩: 에러/없음 문구가 아니다', (t) async {
      big(t);
      await t.pumpWidget(app(history: const Stream.empty()));
      await t.pump();
      expect(find.text('변경 이력이 없어요'), findsNothing);
      expect(find.text('이력을 불러오지 못했어요'), findsNothing);
      expect(find.text('변경 이력'), findsOneWidget);
    });
  });
}

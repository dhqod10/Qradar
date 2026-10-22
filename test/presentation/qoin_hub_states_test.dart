// TRANSITIONAL(spec §20.4.5): 이 파일은 임시 마이그레이션 카드·use case·repository·결과 엔티티를 import 하는 그룹을 가진다.
// 정리 커밋에서 '임시 마이그레이션 카드' 그룹과 해당 import 를 삭제한다 (안 그러면 컴파일이 깨진다 — 가드 테스트가 이 파일을 목록으로 소유한다).
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
import 'package:qradar/domain/entities/qoin_zero_migration_result.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/usecases/migrate_qoin_zero_rates_use_case.dart';
import 'package:qradar/presentation/admin/qoin/admin_qoin_settings_page.dart';
import 'package:qradar/presentation/admin/qoin/providers/qoin_admin_providers.dart';
import 'package:qradar/presentation/admin/qoin/widgets/admin_qoin_migration_card.dart';
import 'package:qradar/presentation/common/providers/qoin_config_providers.dart';
import 'package:qradar/presentation/common/providers/qoin_rate_providers.dart';
import 'package:qradar/domain/repositories/qoin_zero_migration_repository.dart';

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

  group('임시 마이그레이션 카드 — dry-run -> 실행 -> 결과', () {
    final target = QoinZeroMigrationResult(
      dryRun: true,
      zeroStores: const [
        QoinMigrationTarget(id: 's1', name: '강남점'),
        QoinMigrationTarget(id: 's2', name: '판교점'),
      ],
      zeroBrands: const [QoinMigrationTarget(id: 'b1', name: 'Q브루어리')],
      invalidStores: const [
        QoinMigrationTarget(id: 's9', name: '신촌점', raw: '"3"'),
      ],
      invalidBrands: const [
        QoinMigrationTarget(id: 'b9', name: '카페온', raw: '0.5'),
      ],
      migrated: 0,
      skipped: 0,
    );

    Widget host(_FakeMigration m) => ProviderScope(
      overrides: [
        qoinZeroMigrationUseCaseProvider.overrideWithValue(
          MigrateQoinZeroRatesUseCase(m),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: AdminQoinMigrationCard()),
        ),
      ),
    );

    testWidgets('idle -> 확인 중 -> 확인 결과(목록+무효 값 plate) -> 다이얼로그 -> 결과', (
      t,
    ) async {
      final m = _FakeMigration();
      await t.pumpWidget(host(m));
      expect(find.text('Qoin 설정 이전'), findsOneWidget);
      expect(find.text('임시'), findsOneWidget);
      expect(m.calls, isEmpty, reason: '열기만 해서는 호출하지 않는다');

      final c = Completer<QoinZeroMigrationResult>();
      m.next = () => c.future;
      await t.tap(find.text('대상 확인하기'));
      await t.pump();
      expect(find.text('대상을 확인하고 있어요'), findsOneWidget);
      c.complete(target);
      await t.pumpAndSettle();
      expect(m.calls, [true], reason: 'dryRun: true 로 호출');
      expect(find.text('매장 2곳 · 브랜드 1곳'), findsOneWidget);
      expect(find.text('· 강남점'), findsOneWidget);
      expect(find.text('· 브랜드 Q브루어리'), findsOneWidget);
      expect(find.text('확인이 필요한 값 2곳'), findsOneWidget);
      expect(find.textContaining('값 "3"'), findsOneWidget);
      expect(find.textContaining('값 0.5'), findsOneWidget);
      expect(find.text('이전 실행'), findsOneWidget);

      m.next = () => Future.value(
        const QoinZeroMigrationResult(
          dryRun: false,
          zeroStores: [],
          zeroBrands: [],
          invalidStores: [],
          invalidBrands: [],
          migrated: 3,
          skipped: 0,
        ),
      );
      await t.tap(find.text('이전 실행'));
      await t.pumpAndSettle();
      expect(find.text('Qoin 설정을 이전할까요?'), findsOneWidget);
      expect(
        find.text('매장 2곳 · 브랜드 1곳의 ‘적립률 0%’ 를 지우고 ‘적립 사용 안 함’ 으로 바꿔요'),
        findsOneWidget,
      );
      await t.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('이전 실행'),
        ),
      );
      await t.pumpAndSettle();
      expect(m.calls, [true, false]);
      expect(find.text('이전을 마쳤어요'), findsOneWidget);
      expect(find.text('옮긴 곳 3곳'), findsOneWidget);
      expect(find.text('건너뛴 곳 0곳'), findsNothing, reason: '0 이면 숨김');
    });

    testWidgets('대상 0건: 이전할 대상이 없어요 + 다시 확인만 (실행 버튼 없음)', (t) async {
      final m = _FakeMigration()
        ..next = () => Future.value(
          const QoinZeroMigrationResult(
            dryRun: true,
            zeroStores: [],
            zeroBrands: [],
            invalidStores: [],
            invalidBrands: [],
            migrated: 0,
            skipped: 0,
          ),
        );
      await t.pumpWidget(host(m));
      await t.tap(find.text('대상 확인하기'));
      await t.pumpAndSettle();
      expect(find.text('이전할 대상이 없어요'), findsOneWidget);
      expect(find.text('다시 확인'), findsOneWidget);
      expect(find.text('이전 실행'), findsNothing);
    });

    testWidgets('확인 실패: 실행 버튼 없음 + 다시 시도', (t) async {
      final m = _FakeMigration()..next = () => Future.error(StateError('x'));
      await t.pumpWidget(host(m));
      await t.tap(find.text('대상 확인하기'));
      await t.pumpAndSettle();
      expect(find.text('대상을 확인하지 못했어요'), findsOneWidget);
      expect(find.text('이전 실행'), findsNothing);
      expect(find.text('다시 시도'), findsOneWidget);
    });

    testWidgets('실행 실패: 곧바로 재실행 버튼을 주지 않고 dry-run 으로 돌아가게 한다', (t) async {
      final m = _FakeMigration()..next = () => Future.value(target);
      await t.pumpWidget(host(m));
      await t.tap(find.text('대상 확인하기'));
      await t.pumpAndSettle();
      m.next = () => Future.error(StateError('boom'));
      await t.tap(find.text('이전 실행'));
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('이전 실행'),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('이전 결과를 확인하지 못했어요'), findsOneWidget);
      expect(find.text('이미 일부가 옮겨졌을 수 있어요. 대상을 다시 확인해 주세요'), findsOneWidget);
      expect(find.text('이전 실행'), findsNothing, reason: '재실행 버튼 없음');
      expect(find.text('대상 다시 확인하기'), findsOneWidget);
    });
  });

  group('마이그레이션 카드 raw 표시 (describeRaw 타입 보존)', () {
    test('서버가 보낸 JSON 표기는 따옴표를 더하지 않고 그대로 보인다', () {
      for (final raw in [
        '"3"', // 문자열 3
        '0.5',
        '-1',
        'true',
        'false',
        'null',
        '[1,2]',
        '{"a":1}',
        'NaN',
        'Infinity',
        '(absent)',
      ]) {
        expect(AdminQoinMigrationCard.formatRaw(raw), raw, reason: raw);
      }
    });
    test('잘린(100자) 문자열·배열도 그대로, 해석 불가 문자열만 따옴표', () {
      final long = '"${'a' * 99}';
      expect(AdminQoinMigrationCard.formatRaw(long), long);
      expect(AdminQoinMigrationCard.formatRaw('[1,2,3'), '[1,2,3');
      expect(AdminQoinMigrationCard.formatRaw('hello'), '"hello"');
      expect(AdminQoinMigrationCard.formatRaw(null), 'null');
    });
  });
}

class _FakeMigration implements QoinZeroMigrationRepository {
  final List<bool> calls = [];
  Future<QoinZeroMigrationResult> Function()? next;

  @override
  Future<QoinZeroMigrationResult> migrate({required bool dryRun}) {
    calls.add(dryRun);
    return next?.call() ?? Future.error(StateError('no stub'));
  }
}

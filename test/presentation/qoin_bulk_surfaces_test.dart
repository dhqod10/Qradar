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
import 'package:qradar/domain/entities/qoin_rate_results.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/store_grade.dart';
import 'package:qradar/domain/entities/user_location.dart';
import 'package:qradar/domain/repositories/qoin_rate_repository.dart';
import 'package:qradar/domain/usecases/apply_brand_qoin_rate_use_case.dart';
import 'package:qradar/domain/usecases/set_qoin_accrual_enabled_use_case.dart';
import 'package:qradar/domain/usecases/set_qoin_accrual_rate_use_case.dart';
import 'package:qradar/presentation/admin/qoin/admin_qoin_brand_rate_edit_page.dart';
import 'package:qradar/presentation/admin/qoin/admin_qoin_global_rate_page.dart';
import 'package:qradar/presentation/admin/qoin/providers/qoin_admin_providers.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_accrual_switch_card.dart';
import 'package:qradar/presentation/brand/providers/brand_info_providers.dart';
import 'package:qradar/presentation/common/providers/qoin_config_providers.dart';
import 'package:qradar/presentation/common/providers/qoin_di_providers.dart';
import 'package:qradar/presentation/common/providers/qoin_rate_providers.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_history_list.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_history_tile.dart';

/// 2차 검증 FAIL S1(판정 출처) · S2(종결 상태) · S3-b(`changed` 소비)의 화면 회귀 핀.
/// PROBE1: 포인터 partial + 이력 읽기 실패 -> 배너·버튼이 있어야 한다.
/// PROBE3: 포인터 종결 + 옛 이력 partial -> 배너·버튼이 없어야 한다.

class _Repo implements QoinRateRepository {
  QoinBulkApplyResult? apply;
  QoinRateSetResult? set;
  QoinAccrualEnabledResult? sw;
  final List<Map<String, Object?>> applies = [];

  @override
  Future<QoinBulkApplyResult> applyBrandRate({
    required String brandId,
    double? rate,
    bool clear = false,
    required QoinBulkMode mode,
    String? reason,
    String? resumeHistoryId,
  }) async {
    applies.add({'brandId': brandId, 'rate': rate, 'resume': resumeHistoryId});
    return apply!;
  }

  @override
  Future<QoinRateSetResult> setRate({
    required QoinRateScope scope,
    String? targetId,
    double? rate,
    bool clear = false,
    String? reason,
  }) async => set!;

  @override
  Future<QoinAccrualEnabledResult> setAccrualEnabled({
    required QoinRateScope scope,
    required String targetId,
    required bool enabled,
    String? reason,
  }) async => sw!;

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

StoreEntity _store(String id, {String? brandId, QoinRateSetting? rate}) =>
    StoreEntity(
      id: id,
      name: id,
      imageUrl: '',
      location: const UserLocation(latitude: 0, longitude: 0),
      grade: StoreGrade.c,
      averageScore: 0,
      reviewCount: 0,
      menuCategories: const [],
      createdAt: DateTime(2026),
      address: '',
      brandId: brandId,
      qoinAccrualRate: rate ?? QoinRateSetting.absent,
      status: EntityApprovalStatus.approved,
    );

BrandEntity _brand({
  QoinBulkStatus? status,
  String? historyId = 'h1',
  DateTime? at,
  QoinRateSetting? rate,
}) => BrandEntity(
  id: 'bA',
  name: 'Q브루어리',
  status: EntityApprovalStatus.approved,
  qoinAccrualRate: rate ?? QoinRateSetting.valid(0.05),
  qoinBulkStatus: status,
  qoinBulkHistoryId: status == null ? null : historyId,
  qoinBulkAt: at ?? DateTime.now(),
);

QoinRateChangeEntity _hist(
  String id, {
  QoinBulkStatus? status,
  int? total,
  int? processed,
  String? closedReason,
  String? supersededByUid,
}) => QoinRateChangeEntity(
  id: id,
  scope: QoinRateScope.brand,
  targetId: 'bA',
  targetName: 'Q브루어리',
  field: QoinRateField.accrualRate,
  beforeRate: 0.03,
  afterRate: 0.05,
  changedBy: 'adminuid1234',
  changedAt: DateTime.now().subtract(const Duration(hours: 1)),
  lastProgressAt: DateTime.now().subtract(const Duration(hours: 1)),
  source: QoinRateChangeSource.bulk,
  op: QoinRateChangeOp.bulkApply,
  bulkMode: QoinBulkMode.overwrite,
  status: status,
  affectedCount: 4,
  clearedCount: processed ?? 0,
  processedCount: processed,
  totalCount: total,
  closedReason: closedReason,
  supersededByUid: supersededByUid,
);

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  group('resolveBulkBanner — 판정 단일 함수', () {
    final now = DateTime(2026, 10, 22, 12);
    test('partial -> 중단 (historyId 를 싣는다)', () {
      final b = resolveBulkBanner(
        _brand(status: QoinBulkStatus.partial, at: now),
        now,
      );
      expect([b.kind, b.historyId], [QoinBulkBannerKind.partial, 'h1']);
      expect(b.isUnfinished, isTrue);
    });
    test('in_progress: 5분 안 = 없음, 5분 초과 = stale 중단, 시각 없음 = stale', () {
      expect(
        resolveBulkBanner(
          _brand(
            status: QoinBulkStatus.inProgress,
            at: now.subtract(const Duration(minutes: 4)),
          ),
          now,
        ).isUnfinished,
        isFalse,
      );
      final stale = resolveBulkBanner(
        _brand(
          status: QoinBulkStatus.inProgress,
          at: now.subtract(const Duration(minutes: 6)),
        ),
        now,
      );
      expect(stale.isStale, isTrue);
    });
    test('completed · superseded · null(구버전 미지 코드 포함) = 없음', () {
      for (final s in [
        QoinBulkStatus.completed,
        QoinBulkStatus.superseded,
        null,
      ]) {
        expect(
          resolveBulkBanner(_brand(status: s, at: now), now).isUnfinished,
          isFalse,
          reason: '$s',
        );
      }
    });
    test('미지 코드는 null — 구버전 앱이 새 종결 코드를 만나도 "중단 없음" 으로 읽는다', () {
      expect(QoinBulkStatus.fromCode('completed'), QoinBulkStatus.completed);
      expect(QoinBulkStatus.fromCode('superseded'), QoinBulkStatus.superseded);
      expect(QoinBulkStatus.fromCode('something_new'), isNull);
      expect(QoinBulkStatus.fromCode(null), isNull);
    });
  });

  group('resolveHistoryRow — 이력 행 상태', () {
    final now = DateTime.now();
    QoinBulkBanner ptr(QoinBulkBannerKind k, String id) =>
        QoinBulkBanner(k, historyId: id);
    test('partial 문서 + 포인터 partial 이 이 문서 -> 중단 + 재개 가능', () {
      final r = resolveHistoryRow(
        _hist('h1', status: QoinBulkStatus.partial),
        pointer: ptr(QoinBulkBannerKind.partial, 'h1'),
        now: now,
      );
      expect([r.kind, r.canResume], [QoinHistoryRowKind.unfinished, true]);
    });
    test('PROBE3: partial 문서인데 포인터가 종결/다른 시도 -> 종결 줄, 재개 불가', () {
      for (final p in [
        QoinBulkBanner.none,
        ptr(QoinBulkBannerKind.partial, 'other'),
      ]) {
        final r = resolveHistoryRow(
          _hist('h1', status: QoinBulkStatus.partial),
          pointer: p,
          now: now,
        );
        expect(r.kind, QoinHistoryRowKind.superseded);
        expect(r.canResume, isFalse);
      }
    });
    test('브랜드를 못 읽으면(pointer null) plate 는 그리되 버튼은 숨긴다', () {
      final r = resolveHistoryRow(
        _hist('h1', status: QoinBulkStatus.partial),
        pointer: null,
        now: now,
      );
      expect([r.kind, r.canResume], [QoinHistoryRowKind.unfinished, false]);
    });
    test('superseded / completed(nothing_left) / completed', () {
      expect(
        resolveHistoryRow(
          _hist('h', status: QoinBulkStatus.superseded),
          pointer: null,
          now: now,
        ).kind,
        QoinHistoryRowKind.superseded,
      );
      expect(
        resolveHistoryRow(
          _hist(
            'h',
            status: QoinBulkStatus.completed,
            closedReason: 'nothing_left',
          ),
          pointer: null,
          now: now,
        ).kind,
        QoinHistoryRowKind.closedNothingLeft,
      );
      expect(
        resolveHistoryRow(
          _hist('h', status: QoinBulkStatus.completed),
          pointer: null,
          now: now,
        ).kind,
        QoinHistoryRowKind.plain,
      );
    });
  });

  group('브랜드 편집 페이지 — 포인터가 판정, 이력은 수치만', () {
    final cfg = QoinConfigEntity(
      accrualRate: 0.03,
      accrualRateSetting: QoinRateSetting.valid(0.03),
      enabled: true,
    );
    late _Repo repo;
    setUp(() => repo = _Repo());

    Widget app(
      BrandEntity brand, {
      Future<QoinRateChangeEntity?> Function()? doc,
      Stream<List<QoinRateChangeEntity>>? history,
    }) => ProviderScope(
      overrides: [
        qoinConfigProvider.overrideWith((ref) => Stream.value(cfg)),
        qoinAdminBrandsProvider.overrideWith((ref) => Stream.value([brand])),
        qoinAdminStoresProvider.overrideWith(
          (ref) => Stream.value([
            _store('s1', brandId: 'bA'),
            _store('s2', brandId: 'bA', rate: QoinRateSetting.valid(0.1)),
          ]),
        ),
        brandByIdProvider.overrideWith((ref, id) => Stream.value(brand)),
        // 이력 스트림은 판정에 쓰이지 않는다. 에러로 만들어도 배너는 그대로여야 한다.
        qoinRateHistoryProvider.overrideWith(
          (ref, key) =>
              history ??
              Stream<List<QoinRateChangeEntity>>.error(StateError('x')),
        ),
        qoinBulkHistoryDocProvider.overrideWith(
          (ref, key) => doc != null ? doc() : Future.value(null),
        ),
        applyBrandQoinRateUseCaseProvider.overrideWithValue(
          ApplyBrandQoinRateUseCase(repo),
        ),
        setQoinAccrualEnabledUseCaseProvider.overrideWithValue(
          SetQoinAccrualEnabledUseCase(repo),
        ),
      ],
      child: const MaterialApp(home: AdminQoinBrandRateEditPage(brandId: 'bA')),
    );

    void big(WidgetTester t) {
      t.view.physicalSize = const Size(800, 4200);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
    }

    testWidgets(
      'PROBE1: 포인터 partial + 이력 스트림 에러 + 수치 읽기 실패 -> 배너·이어서 적용 있음, 수치만 생략',
      (t) async {
        big(t);
        await t.pumpWidget(
          app(
            _brand(status: QoinBulkStatus.partial),
            doc: () => Future.error(StateError('rules')),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('일부 매장에는 아직 적용되지 않았어요'), findsOneWidget);
        expect(find.text('이어서 적용'), findsOneWidget);
        expect(
          find.textContaining('남은 매장은 이전 개별 설정을 계속 쓰고 있어요'),
          findsOneWidget,
        );
        expect(find.textContaining('곳 중'), findsNothing, reason: '수치 문구는 생략');
        expect(find.text('이어서 적용하면 남은 매장만 처리돼요.'), findsOneWidget);
        // 에러 표시를 따로 더하지 않는다 (부가 정보라 소음이 된다).
        expect(find.textContaining('불러오지 못했어요'), findsNothing);
        // 새 적립률 줄은 이력이 아니라 브랜드 문서의 현재 값에서 온다.
        expect(find.textContaining('이미 5% 로 바뀌었어요'), findsOneWidget);
        expect(find.textContaining('이 안내는 저절로 사라져요'), findsOneWidget);
      },
    );

    testWidgets('수치 읽기 로딩 중에도 배너를 즉시 그린다 (수치를 기다리지 않는다)', (t) async {
      big(t);
      final never = Completer<QoinRateChangeEntity?>();
      await t.pumpWidget(
        app(_brand(status: QoinBulkStatus.partial), doc: () => never.future),
      );
      await t.pump();
      await t.pump();
      expect(find.text('일부 매장에는 아직 적용되지 않았어요'), findsOneWidget);
      expect(find.text('이어서 적용'), findsOneWidget);
      expect(find.textContaining('곳 중'), findsNothing);
    });

    testWidgets('수치 읽기 성공: 처리 7 / 전체 12 -> 남은 5곳', (t) async {
      big(t);
      await t.pumpWidget(
        app(
          _brand(status: QoinBulkStatus.partial),
          doc: () async => _hist(
            'h1',
            status: QoinBulkStatus.partial,
            total: 12,
            processed: 7,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.textContaining('개별 설정 12곳 중 7곳까지 처리했고, 남은 5곳은'),
        findsOneWidget,
      );
      expect(find.text('이어서 적용하면 남은 5곳만 처리돼요.'), findsOneWidget);
    });

    testWidgets(
      'PROBE3: 포인터 completed/superseded + 옛 이력이 partial -> 배너·버튼 없음',
      (t) async {
        for (final s in [QoinBulkStatus.completed, QoinBulkStatus.superseded]) {
          big(t);
          await t.pumpWidget(
            app(
              _brand(status: s),
              history: Stream.value([
                _hist('h1', status: QoinBulkStatus.partial),
              ]),
              doc: () async =>
                  _hist('h1', status: QoinBulkStatus.partial, total: 3),
            ),
          );
          await t.pumpAndSettle();
          expect(find.text('일부 매장에는 아직 적용되지 않았어요'), findsNothing, reason: '$s');
          expect(find.text('이어서 적용'), findsNothing, reason: '$s');
          await t.pumpWidget(const SizedBox());
        }
      },
    );

    testWidgets('stale in_progress: 제목이 달라지고 이어서 적용은 유지', (t) async {
      big(t);
      await t.pumpWidget(
        app(
          _brand(
            status: QoinBulkStatus.inProgress,
            at: DateTime.now().subtract(const Duration(minutes: 10)),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('적용이 중간에 멈춘 것으로 보여요'), findsOneWidget);
      expect(find.text('이어서 적용'), findsOneWidget);
    });

    Future<void> submitBulk(WidgetTester t) async {
      await t.tap(find.text('직접 설정'));
      await t.pump();
      await t.enterText(find.byType(TextField).first, '5');
      await t.pump();
      await t.tap(find.widgetWithText(ElevatedButton, '브랜드 설정 저장'));
      await t.pumpAndSettle();
    }

    testWidgets('changed:false -> "이미 같은 값이에요" 안내 카드. 적용 결과 카드·카운트·성공 문구 없음', (
      t,
    ) async {
      big(t);
      repo.apply = const QoinBulkApplyResult(
        changed: false,
        status: QoinBulkStatus.completed,
        affectedCount: 0,
        clearedCount: 0,
        preservedCount: 0,
        processedCount: 0,
        totalCount: 3,
      );
      await t.pumpWidget(app(_brand(rate: QoinRateSetting.absent)));
      await t.pumpAndSettle();
      await submitBulk(t);
      await t.tap(find.text('변경하기'));
      await t.pumpAndSettle();
      expect(repo.applies, hasLength(1));
      expect(find.text('이미 같은 값이에요'), findsOneWidget);
      expect(find.text('새 적립률 5% 가 이미 설정돼 있어서 바뀐 것이 없어요'), findsOneWidget);
      for (final banned in [
        '적용을 마쳤어요',
        '일부만 적용됐어요',
        '적용된 매장',
        '초기화된 개별 설정',
        '이력 보기',
      ]) {
        expect(find.textContaining(banned), findsNothing, reason: banned);
      }
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsNothing);
      expect(find.text('끝나지 않은 일괄 적용은 처리가 끝나 있어서 닫았어요'), findsNothing);
    });

    testWidgets(
      'changed:false + closed:true -> 안내 + "닫았어요" 한 줄 / staleScan:true 는 "다시 시도" 로 구분해 말한다',
      (t) async {
        big(t);
        repo.apply = const QoinBulkApplyResult(
          changed: false,
          closed: true,
          status: QoinBulkStatus.completed,
          affectedCount: 0,
          clearedCount: 0,
          preservedCount: 0,
          processedCount: 0,
          totalCount: 0,
        );
        await t.pumpWidget(app(_brand(rate: QoinRateSetting.absent)));
        await t.pumpAndSettle();
        await submitBulk(t);
        await t.tap(find.text('변경하기'));
        await t.pumpAndSettle();
        expect(find.text('이미 같은 값이에요'), findsOneWidget);
        expect(find.text('끝나지 않은 일괄 적용은 처리가 끝나 있어서 닫았어요'), findsOneWidget);
        expect(find.textContaining('마쳤어요'), findsNothing);
        await t.tap(find.byIcon(Icons.close_rounded).first);
        await t.pump();

        // staleScan -> "같은 값" 이 아니라 "다시 시도" 로 말한다 (3차 F-1: 의도한 초기화가 안 됐을 수 있다). 성공 동사·카운트 없음.
        repo.apply = const QoinBulkApplyResult(
          changed: false,
          staleScan: true,
          status: QoinBulkStatus.completed,
          affectedCount: 0,
          clearedCount: 0,
          preservedCount: 0,
          processedCount: 0,
          totalCount: 0,
        );
        await t.tap(find.widgetWithText(ElevatedButton, '브랜드 설정 저장'));
        await t.pumpAndSettle();
        await t.tap(find.text('변경하기'));
        await t.pumpAndSettle();
        expect(find.text('방금 다른 곳에서 먼저 처리됐을 수 있어요'), findsOneWidget);
        expect(
          find.text('개별 설정이 그대로 남아 있을 수 있어요. 이 브랜드를 다시 확인하고 한 번 더 시도해 주세요'),
          findsOneWidget,
        );
        expect(find.text('이미 같은 값이에요'), findsNothing);
        for (final banned in [
          '변경했어요',
          '적용했어요',
          '마쳤어요',
          '시작했어요',
          '중단했어요',
          '적용된 매장',
          '이력 보기',
        ]) {
          expect(find.textContaining(banned), findsNothing, reason: banned);
        }
        expect(find.byIcon(Icons.check_circle_outline_rounded), findsNothing);
      },
    );

    testWidgets('changed:true 는 기존 결과 카드 (+ 배너가 떠 있었다면 마감 고지)', (t) async {
      big(t);
      repo.apply = const QoinBulkApplyResult(
        changed: true,
        status: QoinBulkStatus.completed,
        affectedCount: 2,
        clearedCount: 1,
        preservedCount: 0,
        processedCount: 1,
        totalCount: 1,
        historyId: 'h9',
      );
      await t.pumpWidget(
        app(
          _brand(status: QoinBulkStatus.partial, rate: QoinRateSetting.absent),
        ),
      );
      await t.pumpAndSettle();
      await submitBulk(t);
      await t.tap(find.text('변경하기'));
      await t.pumpAndSettle();
      expect(find.text('적용을 마쳤어요'), findsOneWidget);
      expect(find.text('이미 같은 값이에요'), findsNothing);
      expect(find.text('끝나지 않았던 일괄 적용 안내는 이 변경으로 마감됐어요'), findsOneWidget);
    });

    testWidgets('이어서 적용 확인 다이얼로그: 수치를 모르면 숫자 없이 말한다', (t) async {
      big(t);
      await t.pumpWidget(app(_brand(status: QoinBulkStatus.partial)));
      await t.pumpAndSettle();
      await t.tap(find.text('이어서 적용'));
      await t.pumpAndSettle();
      expect(find.text('남은 매장의 개별 설정이 지워져요'), findsOneWidget);
    });
  });

  group('스위치 · 단건 적립률 — changed 를 먼저 본다', () {
    late _Repo repo;
    setUp(() => repo = _Repo());

    Widget switchHost(QoinRateScope scope, QoinSwitchSetting setting) =>
        ProviderScope(
          overrides: [
            setQoinAccrualEnabledUseCaseProvider.overrideWithValue(
              SetQoinAccrualEnabledUseCase(repo),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: QoinAccrualSwitchCard(
                  scope: scope,
                  targetId: 'x1',
                  targetName: scope == QoinRateScope.brand ? 'Q브루어리' : '강남점',
                  switchSetting: setting,
                  effective: resolveEffectiveQoinRate(
                    store: QoinRateSetting.absent,
                    brand: QoinRateSetting.valid(0.05),
                    global: QoinRateSetting.valid(0.03),
                    storeSwitch: scope == QoinRateScope.store
                        ? setting
                        : QoinSwitchSetting.enabled,
                    brandSwitch: scope == QoinRateScope.brand
                        ? setting
                        : QoinSwitchSetting.enabled,
                  ),
                  bulkBannerOpen: true,
                ),
              ),
            ),
          ),
        );

    testWidgets('끄기 요청인데 이미 꺼짐(changed:false) -> "이미 … 상태예요", "중단했어요" 없음', (
      t,
    ) async {
      repo.sw = const QoinAccrualEnabledResult(
        before: false,
        after: false,
        changed: false,
      );
      await t.pumpWidget(
        switchHost(QoinRateScope.store, QoinSwitchSetting.enabled),
      );
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      await t.tap(find.text('적립 중단'));
      await t.pumpAndSettle();
      expect(find.text('이 매장은 이미 적립 사용 안 함 상태예요. 바뀐 것이 없어요'), findsOneWidget);
      expect(find.textContaining('중단했어요'), findsNothing);
      expect(find.textContaining('시작했어요'), findsNothing);
    });

    testWidgets('켜기 요청인데 이미 켜짐 (브랜드) -> "이 브랜드는 이미 적립 사용 중이에요"', (t) async {
      repo.sw = const QoinAccrualEnabledResult(
        before: null,
        after: null,
        changed: false,
        closed: true,
      );
      await t.pumpWidget(
        switchHost(QoinRateScope.brand, QoinSwitchSetting.disabled),
      );
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      await t.tap(find.text('적립 시작'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('이 브랜드는 이미 적립 사용 중이에요. 바뀐 것이 없어요'),
        findsOneWidget,
      );
      expect(
        find.textContaining('끝나지 않은 일괄 적용은 처리가 끝나 있어서 닫았어요'),
        findsOneWidget,
      );
      expect(find.textContaining('다시 시작했어요'), findsNothing);
    });

    testWidgets('changed:true 브랜드 스위치 + 배너가 떠 있었다 -> 성공 문구 + 마감 고지', (t) async {
      repo.sw = const QoinAccrualEnabledResult(
        before: null,
        after: false,
        changed: true,
      );
      await t.pumpWidget(
        switchHost(QoinRateScope.brand, QoinSwitchSetting.enabled),
      );
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      await t.tap(find.text('적립 중단'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('이 브랜드의 적립을 중단했어요. 끝나지 않았던 일괄 적용 안내는 이 변경으로 마감됐어요'),
        findsOneWidget,
      );
    });

    testWidgets('전역 적립률: changed:false -> 성공 문구 없이 안내만', (t) async {
      t.view.physicalSize = const Size(800, 3000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      repo.set = const QoinRateSetResult(
        before: 0.05,
        after: 0.05,
        changed: false,
      );
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            qoinConfigProvider.overrideWith(
              (ref) => Stream.value(
                QoinConfigEntity(
                  accrualRate: 0.03,
                  accrualRateSetting: QoinRateSetting.valid(0.03),
                  enabled: true,
                ),
              ),
            ),
            qoinAdminStoresProvider.overrideWith((ref) => Stream.value([])),
            qoinAdminBrandsProvider.overrideWith((ref) => Stream.value([])),
            setQoinAccrualRateUseCaseProvider.overrideWithValue(
              SetQoinAccrualRateUseCase(repo),
            ),
          ],
          child: const MaterialApp(home: AdminQoinGlobalRatePage()),
        ),
      );
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, '5');
      await t.pump();
      await t.tap(find.widgetWithText(ElevatedButton, '전역 기본값 저장'));
      await t.pumpAndSettle();
      await t.tap(find.text('변경하기'));
      await t.pumpAndSettle();
      expect(find.text('이미 같은 값이에요. 바뀐 것이 없어요'), findsOneWidget);
      expect(find.textContaining('변경했어요'), findsNothing);
    });
  });

  group('이력 행 — 종결 상태 (S2)', () {
    Widget host(
      QoinRateChangeEntity c, {
      BrandEntity? brand,
      Stream<BrandEntity?>? brandStream,
      QoinHistoryViewer viewer = QoinHistoryViewer.admin,
      void Function(QoinRateChangeEntity)? onResume,
    }) => ProviderScope(
      overrides: [
        brandByIdProvider.overrideWith(
          (ref, id) => brandStream ?? Stream.value(brand),
        ),
        qoinChangerNameProvider.overrideWith((ref, uid) => Stream.value('김관리')),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: QoinRateHistoryList(
              items: [c],
              viewer: viewer,
              now: DateTime.now(),
              onResume: onResume,
            ),
          ),
        ),
      ),
    );

    testWidgets('partial 문서 + 포인터가 이 문서의 partial -> plate + 이어서 적용 (admin)', (
      t,
    ) async {
      QoinRateChangeEntity? resumed;
      await t.pumpWidget(
        host(
          _hist('h1', status: QoinBulkStatus.partial, total: 3, processed: 1),
          brand: _brand(status: QoinBulkStatus.partial),
          onResume: (c) => resumed = c,
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('1곳까지 처리했고 남은 곳이 있어요'), findsOneWidget);
      await t.tap(find.text('이어서 적용'));
      expect(resumed?.id, 'h1');
    });

    testWidgets('PROBE3: partial 문서 + 포인터 superseded -> plate·버튼 없음, 종결 줄', (
      t,
    ) async {
      await t.pumpWidget(
        host(
          _hist('h1', status: QoinBulkStatus.partial, total: 3, processed: 1),
          brand: _brand(status: QoinBulkStatus.superseded),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('이어서 적용'), findsNothing);
      expect(find.textContaining('남은 곳이 있어요'), findsNothing);
      expect(find.text('이후 변경으로 마감됐어요'), findsOneWidget);
    });

    testWidgets(
      'superseded 문서: 종결 줄 + (admin 에게) 관리자 uid 끝4, 점주·브랜드에게는 uid 없음',
      (t) async {
        final c = _hist(
          'h1',
          status: QoinBulkStatus.superseded,
          supersededByUid: 'adminuid9876',
        );
        await t.pumpWidget(
          host(c, brand: _brand(status: QoinBulkStatus.superseded)),
        );
        await t.pumpAndSettle();
        expect(find.text('이후 변경으로 마감됐어요 · 관리자 9876'), findsOneWidget);
        await t.pumpWidget(
          host(
            c,
            brand: _brand(status: QoinBulkStatus.superseded),
            viewer: QoinHistoryViewer.brand,
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('이후 변경으로 마감됐어요'), findsOneWidget);
      },
    );

    testWidgets('completed + nothing_left: 종결 줄', (t) async {
      await t.pumpWidget(
        host(
          _hist(
            'h1',
            status: QoinBulkStatus.completed,
            closedReason: 'nothing_left',
          ),
          brand: _brand(status: QoinBulkStatus.completed),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('남은 개별 설정이 없어 마감됐어요'), findsOneWidget);
    });

    testWidgets('브랜드 읽기 로딩 중에도 partial 행은 plate 를 그리되 버튼은 없다 (포인터를 모르므로)', (
      t,
    ) async {
      final never = StreamController<BrandEntity?>();
      addTearDown(never.close);
      await t.pumpWidget(
        host(
          _hist('h1', status: QoinBulkStatus.partial, total: 3, processed: 1),
          brandStream: never.stream,
        ),
      );
      await t.pump();
      expect(
        find.textContaining('1곳까지 처리했고 남은 곳이 있어요'),
        findsNothing,
        reason: '버튼 없는 형태: reader 문구',
      );
      expect(find.text('일부 매장에 아직 적용되지 않았어요'), findsOneWidget);
      expect(find.text('이어서 적용'), findsNothing);
    });
  });
}

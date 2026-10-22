import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/qoin_config_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/user_location.dart';
import 'package:qradar/domain/entities/store_grade.dart';
import 'package:qradar/presentation/admin/qoin/admin_qoin_brand_rate_edit_page.dart';
import 'package:qradar/presentation/admin/qoin/admin_qoin_brand_rates_page.dart';
import 'package:qradar/presentation/admin/qoin/admin_qoin_global_rate_page.dart';
import 'package:qradar/presentation/admin/qoin/admin_qoin_rate_history_page.dart';
import 'package:qradar/presentation/admin/qoin/admin_qoin_settings_page.dart';
import 'package:qradar/presentation/admin/qoin/admin_qoin_store_rate_edit_page.dart';
import 'package:qradar/presentation/admin/qoin/admin_qoin_store_rates_page.dart';
import 'package:qradar/presentation/admin/qoin/providers/qoin_admin_providers.dart';
import 'package:qradar/presentation/brand/providers/brand_info_providers.dart';
import 'package:qradar/presentation/common/providers/qoin_config_providers.dart';
import 'package:qradar/presentation/common/providers/qoin_rate_providers.dart';

/// 관리자 Qoin 화면 스모크: 실제 데이터 모양으로 그려서 예외/오버플로 없이 핵심 문구가 보이는지 본다.
/// (Firebase 없이 provider 를 override 한다.)
StoreEntity store(
  String id,
  String name, {
  String? brandId,
  QoinRateSetting rate = QoinRateSetting.absent,
  QoinSwitchSetting enabled = QoinSwitchSetting.enabled,
  EntityApprovalStatus status = EntityApprovalStatus.approved,
}) => StoreEntity(
  id: id,
  name: name,
  imageUrl: '',
  location: const UserLocation(latitude: 0, longitude: 0),
  grade: StoreGrade.c,
  averageScore: 0,
  reviewCount: 0,
  menuCategories: const [],
  createdAt: DateTime(2026),
  address: '서울 강남구 $name',
  brandId: brandId,
  qoinAccrualRate: rate,
  qoinAccrualEnabled: enabled,
  status: status,
);

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  final brandA = BrandEntity(
    id: 'bA',
    name: 'Q브루어리',
    status: EntityApprovalStatus.approved,
    qoinAccrualRate: QoinRateSetting.valid(0.05),
    // 중단된 일괄 적용 포인터 — 허브 배너·브랜드 목록 태그의 근거 (이력 쿼리가 아니다).
    qoinBulkHistoryId: 'h1',
    qoinBulkStatus: QoinBulkStatus.partial,
    qoinBulkAt: DateTime(2026, 10, 22),
  );
  const brandB = BrandEntity(
    id: 'bB',
    name: '카페온',
    status: EntityApprovalStatus.pending,
  );
  final stores_ = [
    store('s1', '강남점', brandId: 'bA'),
    store('s2', '역삼점', brandId: 'bA', rate: QoinRateSetting.valid(0.1)),
    store('s3', '개인카페'),
    store('s4', '카페온 본점', brandId: 'bB', status: EntityApprovalStatus.pending),
    store('s5', '멈춘점', brandId: 'bA', enabled: QoinSwitchSetting.disabled),
  ];
  final now = DateTime.now();
  final history = <QoinRateChangeEntity>[
    QoinRateChangeEntity(
      id: 'h1',
      scope: QoinRateScope.brand,
      targetId: 'bA',
      targetName: 'Q브루어리',
      field: QoinRateField.accrualRate,
      beforeRate: 0.03,
      afterRate: 0.05,
      changedBy: 'adminuid1234',
      changedAt: now.subtract(const Duration(hours: 1)),
      reason: '10월 프로모션',
      source: QoinRateChangeSource.bulk,
      op: QoinRateChangeOp.bulkApply,
      bulkMode: QoinBulkMode.overwrite,
      status: QoinBulkStatus.partial,
      affectedCount: 4,
      clearedCount: 1,
      processedCount: 1,
      totalCount: 3,
      lastProgressAt: now.subtract(const Duration(hours: 1)),
    ),
    QoinRateChangeEntity(
      id: 'h2',
      scope: QoinRateScope.global,
      targetId: 'qoin',
      targetName: '전역 기본값',
      field: QoinRateField.globalEnabled,
      beforeEnabled: true,
      afterEnabled: false,
      source: QoinRateChangeSource.direct,
      op: QoinRateChangeOp.set,
      changedAt: now.subtract(const Duration(days: 2)),
    ),
    QoinRateChangeEntity(
      id: 'h3',
      scope: QoinRateScope.store,
      targetId: 's2',
      targetName: '역삼점',
      field: QoinRateField.accrualRate,
      beforeRate: null,
      afterRate: 0.1,
      changedBy: 'adminuid1234',
      changedAt: now.subtract(const Duration(days: 3)),
      source: QoinRateChangeSource.callable,
      op: QoinRateChangeOp.set,
    ),
  ];
  const cfg = QoinConfigEntity(
    accrualRate: 0.03,
    accrualRateSetting: QoinRateSetting.absent, // 아래에서 valid 로 교체
    enabled: true,
  );
  final cfgOk = cfg.copyWith(accrualRateSetting: QoinRateSetting.valid(0.03));

  Widget app(Widget page) => ProviderScope(
    overrides: [
      qoinConfigProvider.overrideWith((ref) => Stream.value(cfgOk)),
      qoinAdminBrandsProvider.overrideWith(
        (ref) => Stream.value([brandA, brandB]),
      ),
      qoinAdminStoresProvider.overrideWith((ref) => Stream.value(stores_)),
      qoinAllRateHistoryProvider.overrideWith(
        (ref, limit) => Stream.value(history),
      ),
      qoinRateHistoryProvider.overrideWith(
        (ref, key) => Stream.value(
          history.where((c) => c.targetId == key.targetId).toList(),
        ),
      ),
      brandByIdProvider.overrideWith(
        (ref, id) =>
            Stream.value(id == 'bA' ? brandA : (id == 'bB' ? brandB : null)),
      ),
      qoinChangerNameProvider.overrideWith((ref, uid) => Stream.value('김관리')),
    ],
    child: MaterialApp(home: page),
  );

  void big(WidgetTester t) {
    t.view.physicalSize = const Size(800, 4000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  testWidgets('허브: 전역 카드 + 비상 정지 캡션 + 범위 타일 + partial 배너 + 부제', (t) async {
    big(t);
    await t.pumpWidget(app(const AdminQoinSettingsPage()));
    await t.pumpAndSettle();
    expect(find.text('Qoin 설정'), findsOneWidget);
    expect(find.text('3%'), findsOneWidget);
    expect(find.text('전역 기본값 변경'), findsOneWidget);
    expect(find.textContaining('전체 비상 정지예요'), findsOneWidget);
    expect(find.text('끝나지 않은 일괄 적용이 있어요'), findsOneWidget);
    expect(find.text('브랜드별 적립률'), findsOneWidget);
    expect(find.text('브랜드 2곳 · 개별 설정 1곳'), findsOneWidget);
    expect(find.text('매장 5곳 · 사용 안 함 1곳'), findsOneWidget);
    expect(find.textContaining('최근 변경'), findsOneWidget);
    // 허브에는 적립률 입력란이 없다 (전역 입력은 별도 페이지).
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('전역 편집: 범위 밴드 + 입력란 + 라디오 없음', (t) async {
    big(t);
    await t.pumpWidget(app(const AdminQoinGlobalRatePage()));
    await t.pumpAndSettle();
    expect(find.text('적용 범위'), findsOneWidget);
    expect(find.text('전역 기본값'), findsWidgets);
    expect(find.text('상위 설정 따르기'), findsNothing);
    expect(find.textContaining('적립 안 함'), findsNothing);
    expect(find.text('전역 기본값 저장'), findsOneWidget);
  });

  testWidgets('브랜드 목록: 승인 전 포함 + 상태 배지 + 값/출처 + 적용 중단됨', (t) async {
    big(t);
    await t.pumpWidget(app(const AdminQoinBrandRatesPage()));
    await t.pumpAndSettle();
    expect(find.text('Q브루어리'), findsOneWidget);
    expect(find.text('카페온'), findsOneWidget);
    expect(find.text('브랜드 설정'), findsOneWidget);
    expect(find.text('전역 상속'), findsOneWidget);
    expect(find.text('적용 중단됨'), findsOneWidget);
    expect(find.text('산하 매장 3곳 · 개별 설정 1곳'), findsOneWidget);
    // 검색
    await t.enterText(find.byType(TextField), '카페');
    await t.pump();
    expect(find.text('Q브루어리'), findsNothing);
  });

  testWidgets('브랜드 편집: 밴드 + partial 배너(이어서 적용) + 사슬 + 설정 방식', (t) async {
    big(t);
    await t.pumpWidget(app(const AdminQoinBrandRateEditPage(brandId: 'bA')));
    await t.pumpAndSettle();
    expect(find.text('브랜드 "Q브루어리" 전체'), findsOneWidget);
    expect(find.text('산하 매장 3곳 · 개별 설정 1곳'), findsOneWidget);
    expect(find.text('일부 매장에는 아직 적용되지 않았어요'), findsOneWidget);
    expect(find.text('이어서 적용'), findsOneWidget);
    expect(find.text('지금 적용되는 값'), findsOneWidget);
    expect(find.text('설정 방식'), findsOneWidget);
    expect(find.text('브랜드 설정 저장'), findsOneWidget);
    // 스위치 카드는 저장 버튼 아래 독립 섹션.
    expect(find.text('이 브랜드 적립 사용'), findsOneWidget);
    final saveY = t.getTopLeft(find.text('브랜드 설정 저장')).dy;
    final switchY = t.getTopLeft(find.text('이 브랜드 적립 사용')).dy;
    expect(switchY, greaterThan(saveY));
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('매장 목록: 필터 칩 라벨 = 배지 라벨, 매장 수, 적립 안 함 칩으로 점검', (t) async {
    big(t);
    await t.pumpWidget(app(const AdminQoinStoreRatesPage()));
    await t.pumpAndSettle();
    expect(find.text('매장 5곳'), findsOneWidget);
    for (final label in ['전체', '매장 설정', '브랜드 상속', '전역 상속', '사용 안 함']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    await t.tap(find.widgetWithText(InkWell, '사용 안 함').first);
    await t.pumpAndSettle();
    expect(find.text('매장 1곳'), findsOneWidget);
    expect(find.text('멈춘점'), findsOneWidget);
    expect(find.text('매장에서 중단'), findsOneWidget, reason: '배지는 출처를 진다');
  });

  testWidgets('매장 편집: 소속 밴드 + 3줄 사슬 + 상속 설명(따르게 될 실제 값)', (t) async {
    big(t);
    await t.pumpWidget(app(const AdminQoinStoreRateEditPage(storeId: 's1')));
    await t.pumpAndSettle();
    expect(find.text('매장 "강남점"'), findsOneWidget);
    expect(find.text('Q브루어리 소속 매장'), findsOneWidget);
    expect(find.text('브랜드 "Q브루어리" 의 5% 를 따라요'), findsOneWidget);
    expect(find.text('매장 설정 저장'), findsOneWidget);
    expect(find.text('이 매장 적립 사용'), findsOneWidget);
    // 켜져 있으면 "다시 켜면" 고지가 없다.
    expect(find.textContaining('다시 켜'), findsNothing);
  });

  testWidgets('매장 편집: 스위치 off 매장 — 사슬이 사용 안 함 + 다시 켜면 고지, 카드는 꺼짐', (t) async {
    big(t);
    await t.pumpWidget(app(const AdminQoinStoreRateEditPage(storeId: 's5')));
    await t.pumpAndSettle();
    expect(find.text('사용 안 함'), findsWidgets);
    expect(find.text('다시 켜면 브랜드 5% 가 적용돼요'), findsOneWidget);
    expect(find.text('끄기 전 값이 아니라 지금의 요율이에요'), findsOneWidget);
    expect(find.text('지금은 적립 사용 안 함 상태예요.'), findsOneWidget);
    expect(t.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('매장 편집: 없는 매장 -> 찾을 수 없어요', (t) async {
    big(t);
    await t.pumpWidget(app(const AdminQoinStoreRateEditPage(storeId: 'ghost')));
    await t.pumpAndSettle();
    expect(find.text('매장을 찾을 수 없어요'), findsOneWidget);
  });

  testWidgets('이력: 일괄 메타 + 변경자 이름 + 직접 수정 + 설정 없음 → 값 + 필터', (t) async {
    big(t);
    await t.pumpWidget(app(const AdminQoinRateHistoryPage()));
    await t.pumpAndSettle();
    expect(find.text('일괄 적용'), findsOneWidget);
    expect(find.text('개별 설정 덮어쓰기'), findsOneWidget);
    expect(find.textContaining('김관리'), findsWidgets);
    expect(find.textContaining('변경자 알 수 없음 (직접 수정)'), findsOneWidget);
    expect(find.text('설정 없음'), findsOneWidget);
    expect(find.text('적립 중'), findsOneWidget);
    expect(find.text('적립 중단됨'), findsOneWidget);
    expect(find.text('이어서 적용'), findsOneWidget);
    // 미완료 필터
    await t.tap(find.text('미완료 적용'));
    await t.pumpAndSettle();
    expect(find.text('일괄 적용'), findsOneWidget);
    expect(find.text('설정 없음'), findsNothing);
  });

  testWidgets('이력: 허브 배너 진입 시 미완료 적용 필터가 선택된 채로 열린다', (t) async {
    big(t);
    await t.pumpWidget(
      app(const AdminQoinRateHistoryPage(unfinishedOnly: true)),
    );
    await t.pumpAndSettle();
    expect(find.text('일괄 적용'), findsOneWidget);
    expect(find.text('역삼점'), findsNothing);
  });

  // ── 로딩 중에는 숫자(0% / 이전 값)를 그리지 않는다 ─────────────────────────────
  Widget loadingApp(
    Widget page, {
    bool config = true,
    bool brands = true,
    bool stores = true,
  }) => ProviderScope(
    overrides: [
      qoinConfigProvider.overrideWith(
        (ref) => config ? const Stream.empty() : Stream.value(cfgOk),
      ),
      qoinAdminBrandsProvider.overrideWith(
        (ref) => brands ? const Stream.empty() : Stream.value([brandA, brandB]),
      ),
      qoinAdminStoresProvider.overrideWith(
        (ref) => stores ? const Stream.empty() : Stream.value(stores_),
      ),
      qoinAllRateHistoryProvider.overrideWith(
        (ref, limit) => const Stream.empty(),
      ),
      brandByIdProvider.overrideWith((ref, id) => const Stream.empty()),
    ],
    child: MaterialApp(home: page),
  );

  testWidgets('허브: config 로딩 중 전역 값 / 버튼 / 스위치를 그리지 않는다, 진입 타일은 즉시', (t) async {
    big(t);
    await t.pumpWidget(loadingApp(const AdminQoinSettingsPage()));
    await t.pump();
    // 임시 마이그레이션 카드 설명의 `0%` 는 적립률이 아니다 — 1 이상으로 시작하는 % 값(적립률)만 본다.
    expect(find.textContaining(RegExp(r'[1-9]\d*(\.\d)?%')), findsNothing);
    expect(find.text('전역 기본값 변경'), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('브랜드별 적립률'), findsOneWidget);
    expect(find.text('매장별 적립률'), findsOneWidget);
    expect(find.text('변경 이력'), findsOneWidget);
  });

  testWidgets('매장 목록: 3소스 중 하나라도 로딩이면 목록 전체가 skeleton (숫자 없음)', (t) async {
    big(t);
    // 매장·브랜드는 준비됐고 전역 config 만 로딩.
    await t.pumpWidget(
      loadingApp(const AdminQoinStoreRatesPage(), brands: false, stores: false),
    );
    await t.pump();
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('강남점'), findsNothing);
  });

  testWidgets('브랜드 목록: 로딩 중 숫자 없음', (t) async {
    big(t);
    await t.pumpWidget(
      loadingApp(const AdminQoinBrandRatesPage(), config: false, stores: false),
    );
    await t.pump();
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('브랜드 편집: 산하 매장 로딩 중에는 저장 불가', (t) async {
    big(t);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          qoinConfigProvider.overrideWith((ref) => Stream.value(cfgOk)),
          qoinAdminBrandsProvider.overrideWith(
            (ref) => Stream.value([brandA, brandB]),
          ),
          qoinAdminStoresProvider.overrideWith((ref) => const Stream.empty()),
          qoinAllRateHistoryProvider.overrideWith(
            (ref, limit) => Stream.value(history),
          ),
          qoinRateHistoryProvider.overrideWith(
            (ref, key) => Stream.value(const []),
          ),
          brandByIdProvider.overrideWith((ref, id) => Stream.value(brandA)),
        ],
        child: const MaterialApp(
          home: AdminQoinBrandRateEditPage(brandId: 'bA'),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('산하 매장 정보를 불러오는 중이에요'), findsWidgets);
    final save = find.widgetWithText(ElevatedButton, '브랜드 설정 저장');
    expect(t.widget<ElevatedButton>(save).onPressed, isNull);
  });
}

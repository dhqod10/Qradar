import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/qoin_config_entity.dart';
import 'package:qradar/domain/entities/store_brand_link.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/store_grade.dart';
import 'package:qradar/domain/entities/user_entity.dart';
import 'package:qradar/domain/entities/user_location.dart';
import 'package:qradar/domain/repositories/store_repository.dart';
import 'package:qradar/domain/usecases/approve_store_use_case.dart';
import 'package:qradar/presentation/admin/approval/admin_store_approval_detail_page.dart';
import 'package:qradar/presentation/admin/providers/admin_store_approval_providers.dart';
import 'package:qradar/presentation/admin/widgets/brand_scope_badge.dart';
import 'package:qradar/presentation/brand/providers/brand_info_providers.dart';
import 'package:qradar/presentation/common/providers/qoin_config_providers.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';

/// brand_authorization_hardening D5: 매장 승인 화면이 가맹 관계의 유일한 실질 통제다.
/// 이름 폴백(`브랜드`)이 없고, 미존재 / 미승인 / 조회 실패는 서로 다른 경고이며, 승인 버튼은 fail-closed 로 꺼진다.

StoreEntity _store({String? brandId, String id = 's1'}) => StoreEntity(
  id: id,
  name: '강남점',
  imageUrl: '',
  location: const UserLocation(latitude: 0, longitude: 0),
  grade: StoreGrade.c,
  averageScore: 0,
  reviewCount: 0,
  menuCategories: const [],
  createdAt: DateTime(2026),
  address: '서울',
  brandId: brandId,
  status: EntityApprovalStatus.pending,
);

BrandEntity _brand({
  EntityApprovalStatus status = EntityApprovalStatus.approved,
  QoinRateSetting? rate,
  QoinSwitchSetting? sw,
}) => BrandEntity(
  id: 'bA',
  name: 'Q브루어리',
  status: status,
  qoinAccrualRate: rate ?? QoinRateSetting.valid(0.05),
  qoinAccrualEnabled: sw ?? QoinSwitchSetting.enabled,
);

class _FakeAuth extends AuthNotifier {
  @override
  Future<UserEntity?> build() async => null;
}

class _StoreRepo implements StoreRepository {
  final List<String> approved = [];
  @override
  Future<void> approveStore(String storeId, String adminUid) async {
    approved.add(storeId);
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

void main() {
  group('resolveStoreBrandLink — 분류 단일 함수', () {
    test('개인 매장 (brandId null / 빈 값)', () {
      for (final id in [null, '']) {
        final l = resolveStoreBrandLink(
          brandId: id,
          lookup: const BrandLookupLoading(),
        );
        expect(l.kind, StoreBrandLinkKind.personal);
        expect(l.approveEnabled, isTrue);
        expect(l.hasBrand, isFalse);
      }
    });
    test('6분류 x 승인 버튼 (personal / approved 에서만 켜진다)', () {
      StoreBrandLink r(BrandLookup l) =>
          resolveStoreBrandLink(brandId: 'bA', lookup: l);
      final cases = <(BrandLookup, StoreBrandLinkKind, bool, String?)>[
        (
          const BrandLookupLoading(),
          StoreBrandLinkKind.checking,
          false,
          '브랜드를 확인하고 있어요',
        ),
        (
          const BrandLookupFailed(),
          StoreBrandLinkKind.lookupFailed,
          false,
          '브랜드를 확인한 뒤 승인할 수 있어요',
        ),
        (
          const BrandLookupLoaded(null),
          StoreBrandLinkKind.missing,
          false,
          '존재하지 않는 브랜드라 승인할 수 없어요',
        ),
        (
          BrandLookupLoaded(_brand(status: EntityApprovalStatus.pending)),
          StoreBrandLinkKind.unapproved,
          false,
          '승인되지 않은 브랜드라 승인할 수 없어요',
        ),
        (
          BrandLookupLoaded(_brand(status: EntityApprovalStatus.rejected)),
          StoreBrandLinkKind.unapproved,
          false,
          '승인되지 않은 브랜드라 승인할 수 없어요',
        ),
        (BrandLookupLoaded(_brand()), StoreBrandLinkKind.approved, true, null),
      ];
      for (final (lookup, kind, enabled, reason) in cases) {
        final l = r(lookup);
        expect(l.kind, kind);
        expect(l.approveEnabled, enabled, reason: '$kind');
        expect(l.approveDisabledReason, reason, reason: '$kind');
      }
    });
  });

  group('resolveInheritedRate — 승인하면 따르게 될 적립률', () {
    final g3 = QoinRateSetting.valid(0.03);
    test('브랜드 값이 있으면 브랜드', () {
      final r = resolveInheritedRate(brand: _brand(), global: g3);
      expect(r.kind, InheritedRateKind.brand);
      expect(r.sentence, '승인하면 브랜드 "Q브루어리" 의 적립률 5% 를 따라요');
      expect(r.sub, '이 매장은 이 값으로 Qoin 을 적립해요');
    });
    test('브랜드 값 없음 -> 전역', () {
      final r = resolveInheritedRate(
        brand: _brand(rate: QoinRateSetting.absent),
        global: g3,
      );
      expect(r.kind, InheritedRateKind.global);
      expect(r.sentence, '승인하면 전역 기본값 3% 를 따라요');
      expect(r.sub, '브랜드에 따로 정한 적립률이 없어요');
    });
    test('브랜드 스위치 off -> 이 매장도 적립되지 않는다 (N4)', () {
      final r = resolveInheritedRate(
        brand: _brand(sw: QoinSwitchSetting.disabled),
        global: g3,
      );
      expect(r.kind, InheritedRateKind.brandDisabled);
      expect(r.sentence, '브랜드가 적립 사용 안 함이라 이 매장도 적립되지 않아요');
    });
    test('무효 -> 문제 안내 (상위로 폴백하지 않는다)', () {
      expect(
        resolveInheritedRate(
          brand: _brand(rate: QoinRateSetting.invalid),
          global: g3,
        ).kind,
        InheritedRateKind.invalid,
      );
      expect(
        resolveInheritedRate(
          brand: _brand(rate: QoinRateSetting.absent),
          global: QoinRateSetting.absent,
        ).kind,
        InheritedRateKind.invalid,
      );
    });
  });

  group('승인 상세 화면', () {
    late _StoreRepo repo;
    late int brandSubs;
    setUp(() {
      repo = _StoreRepo();
      brandSubs = 0;
    });

    Widget app(
      StoreEntity store, {
      Stream<BrandEntity?> Function()? brand,
      Stream<QoinConfigEntity?>? cfg,
    }) => ProviderScope(
      overrides: [
        authProvider.overrideWith(_FakeAuth.new),
        watchStoreByIdForAdminProvider.overrideWith(
          (ref, id) => Stream.value(store),
        ),
        brandByIdProvider.overrideWith((ref, id) {
          brandSubs++;
          return (brand ?? () => Stream.value(null))();
        }),
        qoinConfigProvider.overrideWith(
          (ref) =>
              cfg ??
              Stream.value(
                QoinConfigEntity(
                  accrualRate: 0.03,
                  accrualRateSetting: QoinRateSetting.valid(0.03),
                  enabled: true,
                ),
              ),
        ),
        adminApproveStoreUseCaseProvider.overrideWithValue(
          ApproveStoreUseCase(repo),
        ),
      ],
      child: MaterialApp(home: AdminStoreApprovalDetailPage(store: store)),
    );

    void big(WidgetTester t) {
      t.view.physicalSize = const Size(800, 3000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
    }

    Finder approveBtn() => find.widgetWithText(ElevatedButton, '승인');
    bool approveEnabled(WidgetTester t) =>
        t.widget<ElevatedButton>(approveBtn()).onPressed != null;
    bool rejectEnabled(WidgetTester t) =>
        t
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '반려'))
            .onPressed !=
        null;

    testWidgets('승인된 브랜드: 이름 + 승인됨 + 상속 적립률 문장, 버튼 활성, 탭 -> 확인 문장 -> 승인', (
      t,
    ) async {
      big(t);
      await t.pumpWidget(
        app(_store(brandId: 'bA'), brand: () => Stream.value(_brand())),
      );
      await t.pumpAndSettle();
      expect(find.text('소속 브랜드'), findsOneWidget);
      expect(find.text('Q브루어리'), findsOneWidget);
      expect(find.text('승인됨'), findsOneWidget);
      expect(find.text('승인하면 브랜드 "Q브루어리" 의 적립률 5% 를 따라요'), findsOneWidget);
      expect(find.text('브랜드: Q브루어리'), findsOneWidget, reason: '상단 배지');
      expect(approveEnabled(t), isTrue);

      await t.tap(approveBtn());
      await t.pumpAndSettle();
      // 확인 문장 + 블록과 글자 그대로 같은 상속 문장
      expect(find.text('이 매장을 브랜드 "Q브루어리" 의 가맹점으로 승인합니다'), findsOneWidget);
      expect(find.text('승인하면 브랜드 "Q브루어리" 의 적립률 5% 를 따라요'), findsNWidgets(2));
      expect(find.text('승인하면 이 매장은 브랜드 메뉴와 적립률을 적용받아요'), findsOneWidget);

      await t.tap(find.text('취소'));
      await t.pumpAndSettle();
      expect(repo.approved, isEmpty, reason: '취소하면 승인하지 않는다');

      await t.tap(approveBtn());
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(of: find.byType(Dialog), matching: find.text('승인')),
      );
      await t.pumpAndSettle();
      expect(repo.approved, ['s1']);
    });

    testWidgets('브랜드 값 없음 -> 전역 기본값 문장', (t) async {
      big(t);
      await t.pumpWidget(
        app(
          _store(brandId: 'bA'),
          brand: () => Stream.value(_brand(rate: QoinRateSetting.absent)),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('승인하면 전역 기본값 3% 를 따라요'), findsOneWidget);
      expect(find.text('브랜드에 따로 정한 적립률이 없어요'), findsOneWidget);
    });

    testWidgets('미승인 브랜드: 경고 plate + 승인 비활성 + 반려 활성 + 사유 한 줄 + 배지 "브랜드 미승인"', (
      t,
    ) async {
      big(t);
      await t.pumpWidget(
        app(
          _store(brandId: 'bA'),
          brand: () =>
              Stream.value(_brand(status: EntityApprovalStatus.pending)),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('아직 승인되지 않은 브랜드예요'), findsOneWidget);
      expect(find.text('브랜드 미승인'), findsOneWidget);
      expect(find.text('승인되지 않은 브랜드라 승인할 수 없어요'), findsOneWidget);
      expect(find.textContaining('브랜드 ID  bA'), findsOneWidget);
      expect(approveEnabled(t), isFalse);
      expect(rejectEnabled(t), isTrue);
      await t.tap(approveBtn(), warnIfMissed: false);
      await t.pumpAndSettle();
      expect(repo.approved, isEmpty);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('존재하지 않는 브랜드: 가짜 이름 없이 "존재하지 않는" 경고 + ID, 승인 비활성', (t) async {
      big(t);
      await t.pumpWidget(
        app(_store(brandId: 'ghost123'), brand: () => Stream.value(null)),
      );
      await t.pumpAndSettle();
      expect(find.text('존재하지 않는 브랜드예요'), findsOneWidget);
      expect(find.text('브랜드 확인 필요'), findsOneWidget);
      expect(find.textContaining('브랜드 ID  ghost123'), findsOneWidget);
      expect(find.text('존재하지 않는 브랜드라 승인할 수 없어요'), findsOneWidget);
      expect(find.text('브랜드'), findsNothing, reason: "'브랜드' 이름 폴백 금지");
      expect(find.textContaining('브랜드: 브랜드'), findsNothing);
      expect(approveEnabled(t), isFalse);
      expect(rejectEnabled(t), isTrue);
    });

    testWidgets('조회 실패: "확인하지 못했어요"(없음과 다른 문구) + 다시 시도 + 승인 비활성', (t) async {
      big(t);
      await t.pumpWidget(
        app(
          _store(brandId: 'bA'),
          brand: () => Stream.error(StateError('network')),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('브랜드를 확인하지 못했어요'), findsOneWidget);
      expect(find.text('존재하지 않는 브랜드예요'), findsNothing);
      expect(find.text('브랜드 확인 필요'), findsOneWidget);
      expect(find.text('브랜드를 확인한 뒤 승인할 수 있어요'), findsOneWidget);
      expect(find.text('브랜드'), findsNothing);
      expect(approveEnabled(t), isFalse);
      final before = brandSubs;
      await t.tap(find.text('다시 시도'));
      await t.pumpAndSettle();
      expect(brandSubs, greaterThan(before), reason: '다시 시도는 브랜드를 다시 구독한다');
    });

    testWidgets('조회 중: 이름을 미리 그리지 않는다 + 승인 비활성 + "브랜드 확인 중"', (t) async {
      big(t);
      final c = StreamController<BrandEntity?>();
      addTearDown(c.close);
      await t.pumpWidget(app(_store(brandId: 'bA'), brand: () => c.stream));
      await t.pump();
      await t.pump();
      expect(find.text('브랜드 확인 중'), findsOneWidget);
      expect(find.text('브랜드를 확인하고 있어요'), findsOneWidget);
      expect(find.text('Q브루어리'), findsNothing);
      expect(find.text('브랜드'), findsNothing);
      expect(approveEnabled(t), isFalse);
    });

    testWidgets('개인 매장: 브랜드 블록 없음, 승인 활성, 확인 다이얼로그 없이 즉시 처리', (t) async {
      big(t);
      await t.pumpWidget(app(_store()));
      await t.pumpAndSettle();
      expect(find.text('소속 브랜드'), findsNothing);
      expect(find.text('개인 매장'), findsOneWidget);
      expect(approveEnabled(t), isTrue);
      await t.tap(approveBtn());
      await t.pumpAndSettle();
      expect(repo.approved, ['s1']);
    });

    testWidgets('적립률 읽기(전역 설정) 실패는 승인을 막지 않는다 — 비어 있음을 숨기지 않는다', (t) async {
      big(t);
      await t.pumpWidget(
        app(
          _store(brandId: 'bA'),
          brand: () => Stream.value(_brand(rate: QoinRateSetting.absent)),
          cfg: Stream<QoinConfigEntity?>.error(StateError('cfg')),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('적립률을 확인하지 못했어요'), findsOneWidget);
      expect(approveEnabled(t), isTrue);
      await t.tap(approveBtn());
      await t.pumpAndSettle();
      // 확인 다이얼로그는 상속 문장 없이도 열린다
      expect(find.text('이 매장을 브랜드 "Q브루어리" 의 가맹점으로 승인합니다'), findsOneWidget);
    });
  });

  group('BrandScopeBadge — 목록·상세 공용 4상태', () {
    // 상태마다 새 ProviderScope (이미 만든 provider 를 재사용하지 않도록 key 를 바꾼다).
    Widget host(Stream<BrandEntity?> s) => ProviderScope(
      key: UniqueKey(),
      overrides: [brandByIdProvider.overrideWith((ref, id) => s)],
      child: const MaterialApp(
        home: Scaffold(body: BrandScopeBadge(brandId: 'bA')),
      ),
    );

    testWidgets('승인됨 / 미승인 / 없음 / 실패 / 로딩', (t) async {
      await t.pumpWidget(host(Stream.value(_brand())));
      await t.pumpAndSettle();
      expect(find.text('브랜드: Q브루어리'), findsOneWidget);
      await t.pumpWidget(
        host(Stream.value(_brand(status: EntityApprovalStatus.rejected))),
      );
      await t.pumpAndSettle();
      expect(find.text('브랜드 미승인'), findsOneWidget);
      await t.pumpWidget(host(Stream.value(null)));
      await t.pumpAndSettle();
      expect(find.text('브랜드 확인 필요'), findsOneWidget);
      await t.pumpWidget(host(Stream.error(StateError('x'))));
      await t.pumpAndSettle();
      expect(find.text('브랜드 확인 필요'), findsOneWidget);
      expect(find.text('브랜드'), findsNothing);
      final c = StreamController<BrandEntity?>();
      addTearDown(c.close);
      await t.pumpWidget(host(c.stream));
      await t.pump();
      expect(find.text('브랜드 확인 중'), findsOneWidget);
    });
  });
}

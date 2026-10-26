import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/constants/grade_thresholds.dart';
import 'package:qradar/core/constants/menu_categories.dart';
import 'package:qradar/domain/entities/user_location.dart';
import 'package:qradar/data/datasources/remote/master_menu_item_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/menu_item_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/menu_override_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/store_remote_data_source.dart';
import 'package:qradar/data/models/menu_item_model.dart';
import 'package:qradar/data/models/menu_override_model.dart';
import 'package:qradar/data/models/store_model.dart';
import 'package:qradar/data/repositories/master_menu_item_repository_impl.dart';
import 'package:qradar/data/repositories/menu_item_repository_impl.dart';
import 'package:qradar/data/repositories/menu_override_repository_impl.dart';
import 'package:qradar/data/repositories/store_repository_impl.dart';
import 'package:qradar/domain/entities/main_category_entity.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_search_hit_entity.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/entities/option_scope.dart';
import 'package:qradar/domain/entities/option_selection_type.dart';
import 'package:qradar/domain/repositories/option_repository.dart';
import 'package:qradar/presentation/brand/providers/brand_di_providers.dart';
import 'package:qradar/presentation/customer/cart/providers/cart_providers.dart';
import 'package:qradar/presentation/customer/home/providers/home_providers.dart';
import 'package:qradar/presentation/customer/order/favorites/providers/favorites_providers.dart';
import 'package:qradar/presentation/customer/order/menu/menu_item_detail_page.dart';
import 'package:qradar/presentation/customer/order/menu/providers/menu_detail_providers.dart';
import 'package:qradar/presentation/customer/order/store/providers/main_category_providers.dart';
import 'package:qradar/presentation/customer/order/store/providers/store_menu_providers.dart';
import 'package:qradar/presentation/customer/order/store/store_menu_page.dart';
import 'package:qradar/presentation/customer/search/providers/search_providers.dart';
import 'package:qradar/presentation/customer/search/search_page.dart';

/// 2차 개정(spec §15) 회귀 — **Firestore 데이터 소스만 대체**하고 리포지토리 · provider · 화면은 전부 실제 코드.
/// (1차 사각지대: provider 를 override 하면 whenData 변환 · 자동 재시도 · 전역 상태 · 머지 규칙이 실행되지 않는다.)
Stream<List<MainCategoryEntity>> _cats() =>
    Stream.value(const [MainCategoryEntity(id: 'coffee', label: '커피')]);

void main() {
  late _World w;
  setUp(() => w = _World());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        storeRepositoryProvider.overrideWithValue(w.storeRepo),
        userLocationProvider.overrideWith(_FixedLocation.new),
        menuItemRepositoryProvider.overrideWithValue(w.menuRepo),
        masterMenuItemRepositoryProvider.overrideWithValue(w.masterRepo),
        searchMenuOverrideRepositoryProvider.overrideWithValue(w.overrideRepo),
        mainCategoriesActiveProvider.overrideWith((ref) => _cats()),
        optionRepositoryProvider.overrideWithValue(w.options),
        cartProvider.overrideWith((ref) => Stream.value(null)),
        favoriteStoreIdsProvider.overrideWith(
          (ref) => Stream.value(const <String>{}),
        ),
        subCategoriesForStoreProvider.overrideWith(
          (ref, key) => Stream.value(const []),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<List<MenuSearchHitEntity>> search(
    ProviderContainer c,
    String q,
  ) async {
    c.listen(searchViewModelProvider, (_, _) {});
    c.read(searchQueryProvider.notifier).set(q);
    await c.read(menuSearchIndexProvider.future);
    await settle();
    return c.read(searchViewModelProvider).menu.rows;
  }

  group('2단계 검증 — 매장이 실제로 제공하는 메뉴 (U1) · 가격 · 품절', () {
    test('approved excluded 는 결과에서 빠지고, pending excluded 는 무시되어 남는다', () async {
      w.addBrandStore('s1', 0.5); // approved excluded
      w.addBrandStore('s2', 1.0); // pending excluded (승인 전 -> 적용 안 됨)
      w.addBrandStore('s3', 1.5); // override 없음
      w.overrides['s1'] = [_ov('m1', 's1', 'approved', excluded: true)];
      w.overrides['s2'] = [_ov('m1', 's2', 'pending', excluded: true)];
      final rows = await search(container(), '아이스');
      expect(rows.map((r) => r.storeId), ['s2', 's3']);
    });

    test(
      '가격: approved priceOverride 만 반영, pending 은 마스터 가격 / 품절은 status 무관 즉시',
      () async {
        w.addBrandStore('s1', 0.5);
        w.addBrandStore('s2', 1.0);
        w.addBrandStore('s3', 1.5);
        w.overrides['s1'] = [_ov('m1', 's1', 'approved', price: 3500)];
        w.overrides['s2'] = [
          _ov('m1', 's2', 'pending', price: 1, soldOut: true),
        ];
        w.overrides['s3'] = [_ov('m1', 's3', 'approved', soldOut: true)];
        final rows = {
          for (final r in await search(container(), '아이스')) r.storeId: r,
        };
        expect(rows['s1']!.basePrice, 3500);
        expect(rows['s1']!.soldOut, isFalse);
        expect(rows['s2']!.basePrice, 4000, reason: '승인 전 priceOverride 는 무시');
        expect(rows['s2']!.soldOut, isTrue, reason: '운영 필드는 즉시');
        expect(rows['s3']!.basePrice, 4000);
        expect(rows['s3']!.soldOut, isTrue);
      },
    );

    test('R1: 2단계가 끝나기 전에는 1단계 행을 그리지 않는다 — 로딩 -> 검증된 행으로 한 번만 전이', () async {
      w.addBrandStore('s1', 0.5);
      w.addBrandStore('s2', 1.0);
      w.overrides['s1'] = [_ov('m1', 's1', 'approved', excluded: true)];
      final gate = w.gateOverrides();
      final c = container();
      final seen = <(SearchView, int)>[];
      c.listen(
        searchViewModelProvider,
        (_, v) => seen.add((v.view, v.menu.rows.length)),
      );
      c.read(searchQueryProvider.notifier).set('아이스');
      await c.read(menuSearchIndexProvider.future);
      await settle();
      // 1단계는 끝났고 2단계는 대기 중: 행 0, 상태는 메뉴 로딩
      var vm = c.read(searchViewModelProvider);
      expect(vm.menu.rows, isEmpty);
      expect(
        {
          SearchView.s3StoresMenuLoading,
          SearchView.s8NoStoresMenuLoading,
          SearchView.s1StoreLoading,
        }.contains(vm.view),
        isTrue,
        reason: '${vm.view}',
      );
      gate.complete();
      await settle();
      vm = c.read(searchViewModelProvider);
      expect(vm.menu.rows.map((r) => r.storeId), ['s2']);
      // 행이 떴다가 줄어든 적이 없다: 어느 시점에도 s1(excluded)이 행으로 나온 상태가 없다.
      expect(seen.every((e) => e.$2 <= 1), isTrue, reason: '$seen');
    });

    test('R6: 검증 못 한 매장의 행은 그리지 않는다(가격만 비우지 않는다) + 부분 실패', () async {
      w.addBrandStore('s1', 0.5);
      w.addBrandStore('s2', 1.0);
      w.failOverrides.add('s1');
      final c = container();
      await search(c, '아이스');
      // 검증 실패는 자동 재시도 1회(0.8초) 이후에 확정된다 — 그동안은 행을 그리지 않는다(R1).
      await Future<void>.delayed(const Duration(seconds: 2));
      final vm = c.read(searchViewModelProvider);
      final rows = vm.menu.rows;
      expect(rows.map((r) => r.storeId), ['s2']);
      expect(vm.menu.isPartial, isTrue);
      // 질의가 매장 이름에는 맞지 않으므로 s9 (+ 부분 실패 줄). 매장이 일치하면 s7.
      expect(vm.view, SearchView.s9NoStoresMenuData);
    });

    test('2단계 전멸 + 개인 매장 행 없음 -> 메뉴 전체 에러(s6/s11)', () async {
      w.addBrandStore('s1', 0.5);
      w.addBrandStore('s2', 1.0);
      w.failOverrides.addAll(['s1', 's2']);
      final c = container();
      c.listen(searchViewModelProvider, (_, _) {});
      c.read(searchQueryProvider.notifier).set('아이스');
      await c.read(menuSearchIndexProvider.future);
      await settle();
      // 실제 재시도 타이머(0.8초 1회)가 지난 뒤에 확정된다
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(
        {
          SearchView.s6StoresMenuError,
          SearchView.s11NoStoresMenuError,
        }.contains(c.read(searchViewModelProvider).view),
        isTrue,
        reason: '${c.read(searchViewModelProvider).view}',
      );
    });

    test('R4: 일치 브랜드 매장이 상한(10)을 넘으면 가까운 10곳만 읽고 truncated', () async {
      for (var i = 0; i < 14; i++) {
        w.addBrandStore('s$i', 0.1 + i * 0.1);
      }
      final c = container();
      final rows = await search(c, '아이스');
      expect(
        w.overrideFetches,
        hasLength(GradeThresholds.menuSearchVerifyStoreLimit),
      );
      expect(rows.map((r) => r.storeId).toSet(), {
        for (var i = 0; i < 10; i++) 's$i',
      });
      final vm = c.read(searchViewModelProvider);
      expect(vm.menu.fanOutTruncated, isTrue);
      expect(vm.menu.isTruncated, isTrue);
    });

    test('교차 일치: 검색 행 가격 == 매장 카드 가격 == 상세 가격 (품절도 같은 판정)', () async {
      w.addBrandStore('s1', 0.5);
      w.overrides['s1'] = [
        _ov('m1', 's1', 'approved', price: 3500, soldOut: true),
      ];
      final c = container();
      final row = (await search(c, '아이스')).single;

      final card = (await w.menuRepo.watchByStore('s1', brandId: 'b1').first)
          .singleWhere((m) => m.id == 'm1');
      final detail = (await w.menuRepo
          .watchById(storeId: 's1', menuItemId: 'm1')
          .first)!;
      expect(row.basePrice, 3500);
      expect(card.basePrice, row.basePrice);
      expect(detail.basePrice, row.basePrice);
      expect([row.soldOut, card.soldOut, detail.soldOut], everyElement(isTrue));
    });
  });

  group('자동 상세 직행 · 품절 상세 · _DeletedView — 실제 화면 (단순 전환 버전)', () {
    Future<ProviderContainer> pumpStore(
      WidgetTester tester, {
      String? autoOpen,
      String? initial = 'coffee',
      bool pushAsInitialRoute = true,
    }) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = container();
      final store = (await w.storeRepo.getById('s1'))!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            home: StoreMenuPage(
              store: store,
              initialMainCategoryCode: initial,
              highlightMenuItemId: autoOpen,
              autoOpenMenuItemId: autoOpen,
            ),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      return c;
    }

    testWidgets('판매 중: 상세가 매장 화면 위에 한 번 열리고, 뒤로 나온 뒤 다시 열리지 않는다', (
      tester,
    ) async {
      w.addBrandStore('s1', 0.5);
      w.overrides['s1'] = [_ov('m1', 's1', 'approved', price: 3500)];
      await pumpStore(tester, autoOpen: 'm1');
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemDetailPage), findsOneWidget);
      expect(
        find.text('3,500원'),
        findsWidgets,
        reason: '상세 가격 = override 적용 가격',
      );

      // 뒤로 -> 매장 화면 (강조 카드 유지)
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).last);
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemDetailPage), findsNothing);
      expect(find.byType(StoreMenuPage), findsOneWidget);
      // 다시 열리지 않는다
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(MenuItemDetailPage), findsNothing);
      // 매장 카드 가격 = 상세 가격 (같은 3,500원)
      expect(find.text('3,500원'), findsOneWidget);
    });

    testWidgets('매장 목록에 없는 메뉴(excluded)는 상세를 올리지 않고 띠가 알린다', (tester) async {
      w.addBrandStore('s1', 0.5);
      w.overrides['s1'] = [_ov('m1', 's1', 'approved', excluded: true)];
      await pumpStore(tester, autoOpen: 'm1');
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemDetailPage), findsNothing);
      expect(find.text('이 매장에서는 판매하지 않는 메뉴일 수 있어요'), findsOneWidget);
    });

    testWidgets('품절: 상세가 열리고 품절 표시 · 담기 비활성 · 토스트 없음 (필수 옵션 미선택이어도)', (
      tester,
    ) async {
      w.addBrandStore('s1', 0.5);
      w.overrides['s1'] = [_ov('m1', 's1', 'approved', soldOut: true)];
      w.options.groups = [
        const OptionGroupEntity(
          id: 'g1',
          scope: OptionScope.master,
          name: '샷',
          selectionType: OptionSelectionType.single,
          required: true,
        ),
      ];
      await pumpStore(tester, autoOpen: 'm1');
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemDetailPage), findsOneWidget);
      expect(find.text('지금은 품절이에요. 다시 판매되면 담을 수 있어요'), findsOneWidget);
      final btn = find.widgetWithText(ElevatedButton, '품절');
      expect(btn, findsOneWidget);
      expect(tester.widget<ElevatedButton>(btn).onPressed, isNull);
      await tester.tap(btn, warnIfMissed: false);
      await tester.pump();
      expect(
        find.byType(SnackBar),
        findsNothing,
        reason: '품절이면 "필수 옵션을 선택해 주세요" 토스트 금지',
      );
      expect(find.widgetWithText(ElevatedButton, '담기'), findsNothing);
    });

    testWidgets('D9: 매장 화면의 품절 카드도 탭하면 상세로 간다', (tester) async {
      w.addBrandStore('s1', 0.5);
      w.overrides['s1'] = [_ov('m1', 's1', 'approved', soldOut: true)];
      await pumpStore(tester, initial: 'coffee');
      expect(find.byType(MenuItemDetailPage), findsNothing);
      await tester.tap(find.text('아이스 아메리카노'));
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemDetailPage), findsOneWidget);
      expect(find.text('지금은 품절이에요. 다시 판매되면 담을 수 있어요'), findsOneWidget);
    });

    testWidgets('상세에서 보는 도중 excluded 가 되면 _DeletedView: 문구 + 매장 메뉴 보기(pop)', (
      tester,
    ) async {
      w.addBrandStore('s1', 0.5);
      w.overrides['s1'] = [_ov('m1', 's1', 'approved', price: 3500)];
      await pumpStore(tester, autoOpen: 'm1');
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemDetailPage), findsOneWidget);
      // 실시간: override 가 excluded 로 바뀐다 -> 상세 스트림이 null
      w.pushOverride('s1', 'm1', _ov('m1', 's1', 'approved', excluded: true));
      await tester.pumpAndSettle();
      expect(find.text('이 매장에서는 판매하지 않는 메뉴예요'), findsOneWidget);
      expect(find.text('메뉴가 내려갔거나 판매가 중단됐을 수 있어요'), findsOneWidget);
      await tester.tap(find.text('매장 메뉴 보기'));
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemDetailPage), findsNothing);
      expect(find.byType(StoreMenuPage), findsOneWidget);
    });

    testWidgets('검색 행 탭 -> 매장 화면 -> 상세. 뒤로 2회 -> 검색 화면(질의 유지), 상세 재열림 없음', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      w.addBrandStore('s1', 0.5);
      w.overrides['s1'] = [_ov('m1', 's1', 'approved', price: 3500)];
      final c = container();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: SearchPage()),
        ),
      );
      await tester.enterText(find.byType(TextField), '아이스');
      await tester.pump(const Duration(milliseconds: 300));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      // 행: 가격(override 적용) 이 매장 카드·상세와 같은 문자열
      expect(find.text('3,500원'), findsOneWidget);
      await tester.tap(find.text('아이스 아메리카노'));
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemDetailPage), findsOneWidget);
      expect(find.text('3,500원'), findsWidgets);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).last);
      await tester.pumpAndSettle();
      expect(find.byType(StoreMenuPage), findsOneWidget);
      expect(find.byType(MenuItemDetailPage), findsNothing);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).last);
      await tester.pumpAndSettle();
      expect(find.byType(SearchPage), findsOneWidget);
      expect(find.byType(StoreMenuPage), findsNothing);
      expect(find.byType(MenuItemDetailPage), findsNothing);
      expect(c.read(searchQueryProvider), '아이스');
    });

    group('전환 (design §13-4)', () {
      Future<(ProviderContainer, Finder)> openFromSearch(
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = const Size(800, 3000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final c = container();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: c,
            child: const MaterialApp(home: SearchPage()),
          ),
        );
        await tester.enterText(find.byType(TextField), '아이스');
        await tester.pump(const Duration(milliseconds: 300));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        return (
          c,
          find.descendant(
            of: find.byType(StoreMenuPage, skipOffstage: false),
            matching: find.byType(AnimatedOpacity, skipOffstage: false),
            skipOffstage: false,
          ),
        );
      }

      double storeOpacity(WidgetTester tester, Finder f) =>
          tester.widget<AnimatedOpacity>(f.first).opacity;

      testWidgets(
        '정상: 상세가 덮을 때까지 매장 화면은 그려지지 않고(shimmer 없음) 검색 화면이 계속 보인다',
        (tester) async {
          w.addBrandStore('s1', 0.5);
          final (_, opacity) = await openFromSearch(tester);
          await tester.tap(find.text('아이스 아메리카노'));
          var sawDetail = false;
          for (var i = 0; i < 40; i++) {
            await tester.pump(const Duration(milliseconds: 16));
            if (find
                .byType(StoreMenuPage, skipOffstage: false)
                .evaluate()
                .isEmpty) {
              // 라우트가 아직 온스테이지가 아닌 프레임 — 그려지지 않는다는 뜻이므로 통과
              expect(i, lessThan(3), reason: '3프레임 뒤에는 라우트가 있어야 한다');
              continue;
            }
            if (find.byType(MenuItemDetailPage).evaluate().isNotEmpty) {
              sawDetail = true;
              final secondary = ModalRoute.of(
                tester.element(find.byType(StoreMenuPage, skipOffstage: false)),
              )!.secondaryAnimation!;
              if (secondary.status != AnimationStatus.completed) {
                expect(
                  storeOpacity(tester, opacity),
                  0,
                  reason: '상세가 덮기 전에는 매장 화면을 그리지 않는다 (frame $i)',
                );
                // 검색 화면은 계속 그려진다 (opaque: false)
                expect(
                  find.byType(SearchPage, skipOffstage: false),
                  findsOneWidget,
                );
              }
            } else {
              expect(storeOpacity(tester, opacity), 0, reason: 'frame $i');
            }
          }
          expect(sawDetail, isTrue);
          await tester.pumpAndSettle();
          expect(find.byType(MenuItemDetailPage), findsOneWidget);

          // 상세 -> 뒤로: 완성된 매장 화면이 드러난다
          await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).last);
          await tester.pumpAndSettle();
          expect(find.byType(MenuItemDetailPage), findsNothing);
          expect(storeOpacity(tester, opacity), 1);
          expect(find.text('아이스 아메리카노'), findsWidgets);
        },
        variant: const TargetPlatformVariant({
          TargetPlatform.android,
          TargetPlatform.iOS,
        }),
      );

      testWidgets('매장에 없는 메뉴: 상세 없이 매장 화면이 페이드 인 + 띠', (tester) async {
        w.addBrandStore('s1', 0.5);
        final (c, opacity) = await openFromSearch(tester);
        // 검색 이후 매장이 메뉴를 내렸다 (L4: 세션 캐시된 행)
        w.overrides['s1'] = [_ov('m1', 's1', 'approved', excluded: true)];
        await tester.tap(find.text('아이스 아메리카노'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
        await tester.pump(const Duration(milliseconds: 20));
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();
        expect(find.byType(MenuItemDetailPage), findsNothing);
        expect(storeOpacity(tester, opacity), 1);
        expect(find.text('이 매장에서는 판매하지 않는 메뉴일 수 있어요'), findsOneWidget);
        expect(c, isNotNull);
      });

      testWidgets('느린 네트워크: 250ms 후 스크림, 3초 넘으면 중단하고 기존 매장 화면(shimmer)을 보인다', (
        tester,
      ) async {
        w.addBrandStore('s1', 0.5);
        final (_, opacity) = await openFromSearch(tester);
        w.masterGate = Completer<void>(); // 매장 메뉴 스트림이 도착하지 않는다
        await tester.tap(find.text('아이스 아메리카노'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.bySemanticsLabel('메뉴로 이동하고 있어요'),
          findsNothing,
          reason: '250ms 안에는 아무것도 보이지 않는다',
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.bySemanticsLabel('메뉴로 이동하고 있어요'), findsOneWidget);
        expect(storeOpacity(tester, opacity), 0);
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          storeOpacity(tester, opacity),
          1,
          reason: '3초 폴백: 기존 매장 화면 상태를 보인다',
        );
        expect(find.byType(MenuItemDetailPage), findsNothing);
      });
    });

    testWidgets('상세의 override 스트림 실패는 마스터 가격으로 폴백하지 않고 에러 화면', (tester) async {
      w.addBrandStore('s1', 0.5);
      w.failOverrideDoc = true;
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = container();
      final store = (await w.storeRepo.getById('s1'))!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(
            home: MenuItemDetailPage(
              storeId: 's1',
              storeName: '매장',
              menuItemId: 'm1',
            ),
          ),
        ),
      );
      expect(store.id, 's1');
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('메뉴를 불러오지 못했어요'), findsOneWidget);
      expect(
        find.text('4,000원'),
        findsNothing,
        reason: '마스터 가격으로 조용히 폴백하면 안 된다',
      );
    });
  });
}

// ── fixtures ───────────────────────────────────────────────────────────────

MenuOverrideModel _ov(
  String masterId,
  String storeId,
  String status, {
  bool excluded = false,
  int? price,
  bool soldOut = false,
}) => MenuOverrideModel(
  masterMenuItemId: masterId,
  storeId: storeId,
  brandId: 'b1',
  priceOverride: price,
  excluded: excluded,
  soldOut: soldOut,
  status: status,
);

class _FixedLocation extends UserLocationNotifier {
  @override
  Future<UserLocation> build() async => const UserLocation(
    latitude: GradeThresholds.defaultLatitude,
    longitude: GradeThresholds.defaultLongitude,
  );
}

class _World {
  final stores = <StoreModel>[];
  final overrides = <String, List<MenuOverrideModel>>{};
  final failOverrides = <String>{};
  final overrideFetches = <String>[];
  final _overrideDocControllers =
      <String, StreamController<MenuOverrideModel?>>{};
  bool failOverrideDoc = false;
  Completer<void>? _gate;

  /// 설정하면 마스터 메뉴 스트림이 이 시점까지 emit 하지 않는다 (느린 네트워크 모사).
  Completer<void>? masterGate;

  final options = _Options();

  late final _storeDs = _StoreDs(this);
  late final _menuDs = _MenuDs();
  late final _masterDs = _MasterDs(this);
  late final _ovDs = _OvDs(this);

  late final storeRepo = StoreRepositoryImpl(_storeDs);
  late final menuRepo = MenuItemRepositoryImpl(
    _menuDs,
    masterMenuDataSource: _masterDs,
    menuOverrideDataSource: _ovDs,
    storeRemoteDataSource: _storeDs,
  );
  late final masterRepo = MasterMenuItemRepositoryImpl(
    _masterDs,
    currentUidGetter: () => '',
    currentBrandIdGetter: () => null,
  );
  late final overrideRepo = MenuOverrideRepositoryImpl(_ovDs);

  void addBrandStore(String id, double km) {
    stores.add(
      StoreModel(
        id: id,
        name: '강남점 $id',
        imageUrl: '',
        latitude: GradeThresholds.defaultLatitude + km / 111.0,
        longitude: GradeThresholds.defaultLongitude,
        averageScore: 4,
        reviewCount: 1,
        menuCategories: const [MenuCategories.defaultSelected],
        createdAt: DateTime(2026),
        brandId: 'b1',
      ),
    );
  }

  Completer<void> gateOverrides() => _gate = Completer<void>();

  /// 열려 있는 상세/목록의 override 단건 스트림에 새 값을 흘린다 (실시간 변경).
  void pushOverride(String storeId, String masterId, MenuOverrideModel o) {
    overrides[storeId] = [o];
    _overrideDocControllers['$storeId/$masterId']?.add(o);
  }
}

class _StoreDs implements StoreRemoteDataSource {
  _StoreDs(this.w);
  final _World w;
  @override
  Future<List<StoreModel>> fetchAll({int limit = 100}) async => w.stores;
  @override
  Future<StoreModel?> getById(String id) async =>
      w.stores.where((s) => s.id == id).firstOrNull;
  @override
  Stream<StoreModel?> watchById(String id) =>
      Stream.value(w.stores.where((s) => s.id == id).firstOrNull);
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

const _m2 = MenuItemModel(
  id: 'm2',
  storeId: '',
  name: '라떼',
  mainCategory: 'coffee',
  basePrice: 4500,
  status: 'approved',
  scope: 'brand',
);

const _m1 = MenuItemModel(
  id: 'm1',
  storeId: '',
  name: '아이스 아메리카노',
  mainCategory: 'coffee',
  basePrice: 4000,
  status: 'approved',
  scope: 'brand',
);

class _MenuDs implements MenuItemRemoteDataSource {
  @override
  Future<List<MenuItemModel>> fetchByStore(String storeId) async => const [];
  @override
  Stream<List<MenuItemModel>> streamByStore(String storeId) =>
      Stream.value(const []);
  @override
  Stream<MenuItemModel?> streamById({
    required String storeId,
    required String menuItemId,
  }) => Stream.value(null);
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _MasterDs implements MasterMenuItemRemoteDataSource {
  _MasterDs([this.world]);
  final _World? world;

  @override
  Future<List<MenuItemModel>> fetchAllByBrand(String brandId) async => [
    _m1,
    _m2,
  ];
  @override
  Stream<List<MenuItemEntity>> watchAllByBrand(String brandId) {
    final items = [_m1.toEntity(), _m2.toEntity()];
    final gate = world?.masterGate;
    return gate == null
        ? Stream.value(items)
        : Stream.fromFuture(gate.future.then((_) => items));
  }

  @override
  Stream<MenuItemModel?> streamById(String brandId, String menuItemId) =>
      Stream.value(
        menuItemId == 'm1' ? _m1 : (menuItemId == 'm2' ? _m2 : null),
      );
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _OvDs implements MenuOverrideRemoteDataSource {
  _OvDs(this.w);
  final _World w;

  @override
  Future<List<MenuOverrideModel>> fetchByStore(String storeId) async {
    w.overrideFetches.add(storeId);
    if (w._gate != null) await w._gate!.future;
    if (w.failOverrides.contains(storeId)) throw StateError('boom $storeId');
    return w.overrides[storeId] ?? const [];
  }

  @override
  Stream<List<MenuOverrideModel>> streamByStore(String storeId) =>
      Stream.value(w.overrides[storeId] ?? const []);

  @override
  Stream<MenuOverrideModel?> streamByStoreAndMaster(
    String storeId,
    String masterId,
  ) {
    if (w.failOverrideDoc) return Stream.error(StateError('permission'));
    final c = w._overrideDocControllers.putIfAbsent(
      '$storeId/$masterId',
      () => StreamController<MenuOverrideModel?>.broadcast(),
    );
    final initial = (w.overrides[storeId] ?? const [])
        .where((o) => o.masterMenuItemId == masterId)
        .firstOrNull;
    return Stream<MenuOverrideModel?>.multi((ctrl) {
      ctrl.add(initial);
      final sub = c.stream.listen(ctrl.add);
      ctrl.onCancel = sub.cancel;
    });
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _Options implements OptionRepository {
  List<OptionGroupEntity> groups = const [];
  @override
  Future<List<OptionGroupEntity>> getOptionGroupsForMenuItem(
    MenuItemEntity menuItem, {
    Set<String> disabledGroupIds = const {},
    Set<String> disabledItemIds = const {},
  }) async => groups;
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

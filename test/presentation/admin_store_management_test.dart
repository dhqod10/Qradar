import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/errors/store_deletion_exception.dart';
import 'package:qradar/domain/entities/store_deletion.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/store_grade.dart';
import 'package:qradar/domain/entities/user_location.dart';
import 'package:qradar/domain/repositories/store_deletion_repository.dart';
import 'package:qradar/domain/usecases/admin_delete_store_use_case.dart';
import 'package:qradar/presentation/admin/providers/admin_store_deletion_providers.dart';
import 'package:qradar/presentation/admin/store_management/admin_store_delete_page.dart';
import 'package:qradar/presentation/admin/store_management/admin_store_list_page.dart';

/// payment_server_authority D1 design §7: admin 매장 목록(4상태) + 삭제 화면(활성 조건·비활성 박스·실패·경쟁).
StoreEntity _store(String id, String name, {String address = '서울시'}) =>
    StoreEntity(
      id: id,
      name: name,
      imageUrl: '',
      location: const UserLocation(latitude: 37, longitude: 127),
      grade: StoreGrade.c,
      averageScore: 0,
      reviewCount: 0,
      menuCategories: const ['커피'],
      createdAt: DateTime(2026),
      ownerId: 'owner-$id',
      address: address,
    );

void main() {
  group('AdminStoreListPage', () {
    Widget app(Stream<List<StoreEntity>> s) => ProviderScope(
      overrides: [adminAllStoresProvider.overrideWith((ref) => s)],
      child: const MaterialApp(home: AdminStoreListPage()),
    );

    testWidgets('loading: 스켈레톤 6개', (t) async {
      final c = StreamController<List<StoreEntity>>();
      addTearDown(c.close);
      await t.pumpWidget(app(c.stream));
      await t.pump();
      expect(
        find.byKey(const ValueKey('adminStoreList.loading')),
        findsOneWidget,
      );
      expect(find.text('매장 목록을 불러오지 못했어요'), findsNothing);
    });

    testWidgets('error: 문구 + 다시 시도 -> 재구독', (t) async {
      var calls = 0;
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            adminAllStoresProvider.overrideWith((ref) {
              calls++;
              return calls == 1
                  ? Stream.error(StateError('boom'))
                  : Stream.value([_store('a', '가게')]);
            }),
          ],
          child: const MaterialApp(home: AdminStoreListPage()),
        ),
      );
      await t.pump();
      await t.pump();
      expect(find.text('매장 목록을 불러오지 못했어요'), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
      await t.tap(find.text('다시 시도'));
      await t.pump();
      await t.pump();
      expect(find.text('가게'), findsOneWidget);
    });

    testWidgets('empty(매장 0건)', (t) async {
      await t.pumpWidget(app(Stream.value(const [])));
      await t.pump();
      await t.pump();
      expect(find.text('등록된 매장이 없어요'), findsOneWidget);
    });

    testWidgets('data + 검색: 이름 부분 일치, 결과 0건이면 검색 empty 문구', (t) async {
      await t.pumpWidget(
        app(Stream.value([_store('a', '강남점'), _store('b', '역삼점')])),
      );
      await t.pump();
      await t.pump();
      expect(find.text('강남점'), findsOneWidget);
      expect(find.text('역삼점'), findsOneWidget);
      expect(find.text('개인 매장'), findsNWidgets(2));

      await t.enterText(
        find.byKey(const ValueKey('adminStoreList.search')),
        '강남',
      );
      await t.pump();
      expect(find.text('강남점'), findsOneWidget);
      expect(find.text('역삼점'), findsNothing);

      await t.enterText(
        find.byKey(const ValueKey('adminStoreList.search')),
        '없는이름',
      );
      await t.pump();
      expect(find.text("'없는이름' 와 일치하는 매장이 없어요"), findsOneWidget);
      expect(find.text('검색어를 지우면 전체 목록이 보여요'), findsOneWidget);
    });
  });

  group('adminStoreDisplayName', () {
    test('개인 매장은 이름, 브랜드 매장은 "브랜드 지점"', () {
      final personal = _store('a', '강남점');
      expect(adminStoreDisplayName(personal, 'Q'), '강남점');
      final brand = personal.copyWith(brandId: 'b1');
      expect(adminStoreDisplayName(brand, 'Q'), 'Q 강남점');
      expect(
        adminStoreDisplayName(brand, null),
        '강남점',
        reason: '브랜드 이름을 모르면 지어내지 않는다',
      );
      expect(adminStoreDisplayName(brand, ''), '강남점');
    });
  });

  group('canDeleteStore 활성 조건', () {
    const ok = StoreDeletionPreview(affected: StoreDeletionAffected());
    bool can({
      StoreDeletionPreview? preview = ok,
      String reason = '폐업 확인',
      String confirm = '가게',
      bool deleting = false,
    }) => canDeleteStore(
      preview: preview,
      reason: reason,
      confirmInput: confirm,
      expectedName: '가게',
      deleting: deleting,
    );

    test('전부 충족하면 true', () => expect(can(), isTrue));
    test(
      '영향 범위 로드 실패/로딩(null) -> false (fail-closed)',
      () => expect(can(preview: null), isFalse),
    );
    test('진행 중인 주문 1건 이상 -> false', () {
      expect(
        can(
          preview: const StoreDeletionPreview(
            affected: StoreDeletionAffected(inFlightOrders: 1),
          ),
        ),
        isFalse,
      );
    });
    test('사유 trim 후 2자 미만 -> false', () {
      expect(can(reason: ' a '), isFalse);
      expect(can(reason: ''), isFalse);
      expect(can(reason: ' ab '), isTrue);
    });
    test('이름은 앞뒤 공백만 무시하고 정확히 일치해야 한다', () {
      expect(can(confirm: '  가게 '), isTrue);
      expect(can(confirm: '가'), isFalse);
      expect(can(confirm: '가 게'), isFalse);
      expect(can(confirm: ''), isFalse);
    });
    test('삭제 중 / 이미 삭제됨 -> false', () {
      expect(can(deleting: true), isFalse);
      expect(
        can(
          preview: const StoreDeletionPreview(
            affected: StoreDeletionAffected(),
            alreadyDeleted: true,
          ),
        ),
        isFalse,
      );
    });
  });

  group('AdminStoreDeletePage', () {
    late _Repo repo;
    setUp(() => repo = _Repo());

    Widget app(Future<StoreDeletionPreview> Function(int call) preview) {
      var calls = 0;
      return ProviderScope(
        overrides: [
          storeDeletionPreviewProvider.overrideWith(
            (ref, id) => preview(++calls),
          ),
          adminDeleteStoreUseCaseProvider.overrideWithValue(
            AdminDeleteStoreUseCase(repo),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  ctx,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        AdminStoreDeletePage(store: _store('s1', '가게')),
                  ),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> open(WidgetTester t, Widget w) async {
      t.view.physicalSize = const Size(900, 2600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(w);
      await t.tap(find.text('열기'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
    }

    Future<void> fill(
      WidgetTester t, {
      String reason = '폐업 확인',
      String name = '가게',
    }) async {
      await t.enterText(
        find.byKey(const ValueKey('storeDelete.reason')),
        reason,
      );
      await t.enterText(
        find.byKey(const ValueKey('storeDelete.confirm')),
        name,
      );
      await t.pump();
    }

    bool submitEnabled(WidgetTester t) =>
        t
            .widget<ElevatedButton>(
              find.byKey(const ValueKey('storeDelete.submit')),
            )
            .onPressed !=
        null;

    const zero = StoreDeletionPreview(affected: StoreDeletionAffected());

    testWidgets('로딩 중에는 스켈레톤이고 삭제 버튼이 꺼져 있다', (t) async {
      final c = Completer<StoreDeletionPreview>();
      await open(t, app((_) => c.future));
      expect(
        find.byKey(const ValueKey('storeDelete.affectedLoading')),
        findsOneWidget,
      );
      await fill(t);
      expect(submitEnabled(t), isFalse);
    });

    testWidgets(
      '영향 범위 에러: 문구 + 다시 불러오기, 사유·이름을 채워도 삭제 불가(fail-closed). 재시도하면 복구',
      (t) async {
        await open(
          t,
          app(
            (call) => call == 1
                ? Future.error(
                    const StoreDeletionException(StoreDeletionFailure.failed),
                  )
                : Future.value(zero),
          ),
        );
        expect(find.text('영향 범위를 불러오지 못했어요'), findsOneWidget);
        await fill(t);
        expect(submitEnabled(t), isFalse);

        await t.tap(find.text('다시 불러오기'));
        await t.pump();
        await t.pump();
        expect(find.text('영향 범위를 불러오지 못했어요'), findsNothing);
        expect(submitEnabled(t), isTrue);
      },
    );

    testWidgets('전부 0 이면 0 을 숨기지 않고 표시하고, 사유·이름이 맞아야 활성', (t) async {
      await open(t, app((_) => Future.value(zero)));
      expect(find.text('0개'), findsNWidgets(4)); // 메뉴·오버라이드·하위 카테고리·옵션 그룹
      expect(find.text('0건'), findsNWidgets(2)); // 적립률 이력·진행 중인 주문
      expect(find.text('0장'), findsOneWidget);
      expect(find.text('진행 중인 주문'), findsOneWidget);
      expect(find.text('삭제 이력(매장 정보 스냅샷 포함)이 1건 남아요.'), findsOneWidget);
      expect(submitEnabled(t), isFalse);
      await fill(t, reason: 'a');
      expect(submitEnabled(t), isFalse, reason: '사유 1자');
      await fill(t, name: '다른 가게');
      expect(submitEnabled(t), isFalse, reason: '이름 불일치');
      await fill(t);
      expect(submitEnabled(t), isTrue);
    });

    testWidgets(
      '진행 중인 주문 n>=1: 비활성 박스 + 이유 + 다시 불러오기, 모든 입력을 채워도 삭제 불가, 강제 종결 버튼 없음',
      (t) async {
        await open(
          t,
          app(
            (_) => Future.value(
              const StoreDeletionPreview(
                affected: StoreDeletionAffected(inFlightOrders: 3),
              ),
            ),
          ),
        );
        expect(
          find.byKey(const ValueKey('storeDelete.inFlightBox')),
          findsOneWidget,
        );
        expect(find.text('진행 중인 주문이 3건 있어요'), findsOneWidget);
        expect(find.text('모두 완료·취소된 뒤에 삭제할 수 있어요.'), findsOneWidget);
        expect(find.text('지금 삭제하면 그 주문의 취소·환불을 처리할 수 없게 돼요.'), findsOneWidget);
        expect(find.text('3건'), findsOneWidget);
        await fill(t);
        expect(submitEnabled(t), isFalse);
        expect(find.textContaining('강제'), findsNothing);
      },
    );

    testWidgets('삭제 성공: 사유 trim 후 전달, 화면 pop + 스낵바', (t) async {
      await open(t, app((_) => Future.value(zero)));
      await fill(t, reason: '  폐업 확인  ', name: ' 가게 ');
      await t.tap(find.byKey(const ValueKey('storeDelete.submit')));
      await t.pumpAndSettle();
      expect(repo.deleted, [('s1', '폐업 확인')]);
      expect(find.byType(AdminStoreDeletePage), findsNothing);
      expect(find.text('삭제했어요. 삭제 이력이 기록됐어요'), findsOneWidget);
    });

    testWidgets('삭제 중: 진행 문구 + 입력 차단, 뒤로가기 차단', (t) async {
      repo.gate = Completer<void>();
      await open(t, app((_) => Future.value(zero)));
      await fill(t);
      await t.tap(find.byKey(const ValueKey('storeDelete.submit')));
      await t.pump();
      expect(find.text('삭제하는 중이에요. 잠시만 기다려 주세요'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(t.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
      expect(submitEnabled(t), isFalse);
      repo.gate!.complete();
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
    });

    testWidgets('삭제 실패(중간 실패): 이어서 진행 안내 박스, 입력값 보존, 원시 예외 문자열 없음, 재시도 가능', (
      t,
    ) async {
      repo.error = const StoreDeletionException(
        StoreDeletionFailure.failed,
        code: 'internal',
      );
      await open(t, app((_) => Future.value(zero)));
      await fill(t);
      await t.tap(find.byKey(const ValueKey('storeDelete.submit')));
      await t.pump();
      await t.pump();
      expect(
        find.byKey(const ValueKey('storeDelete.failureBox')),
        findsOneWidget,
      );
      expect(find.text('삭제가 중간에 멈췄어요'), findsOneWidget);
      expect(
        find.text('같은 매장을 다시 삭제하면 이어서 진행돼요. 삭제 이력은 중복 기록되지 않아요.'),
        findsOneWidget,
      );
      expect(find.textContaining('StoreDeletionException'), findsNothing);
      expect(find.textContaining('internal'), findsNothing);
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('storeDelete.reason')))
            .controller!
            .text,
        '폐업 확인',
      );
      expect(submitEnabled(t), isTrue);

      repo.error = null;
      await t.tap(find.byKey(const ValueKey('storeDelete.submit')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(repo.deleted.length, 2);
    });

    testWidgets(
      '경쟁 변형: 0건이었는데 실행 시 거부 -> "방금 새 주문" 박스 (일반 실패 박스 아님), 다시 불러오기가 재조회',
      (t) async {
        repo.error = const StoreDeletionException(
          StoreDeletionFailure.inFlightOrders,
          code: 'failed-precondition',
        );
        await open(
          t,
          app(
            (call) => Future.value(
              call == 1
                  ? zero
                  : const StoreDeletionPreview(
                      affected: StoreDeletionAffected(inFlightOrders: 1),
                    ),
            ),
          ),
        );
        await fill(t);
        await t.tap(find.byKey(const ValueKey('storeDelete.submit')));
        await t.pump();
        await t.pump();
        expect(
          find.byKey(const ValueKey('storeDelete.raceBox')),
          findsOneWidget,
        );
        expect(find.text('방금 새 주문이 들어왔어요. 다시 확인해 주세요.'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('storeDelete.failureBox')),
          findsNothing,
        );
        expect(
          t
              .widget<TextField>(
                find.byKey(const ValueKey('storeDelete.confirm')),
              )
              .controller!
              .text,
          '가게',
        );

        await t.tap(find.text('다시 불러오기'));
        await t.pump();
        await t.pump();
        // 재조회 결과(1건)가 반영돼 일반 가드 박스가 뜬다.
        expect(find.text('진행 중인 주문이 1건 있어요'), findsOneWidget);
        expect(submitEnabled(t), isFalse);
      },
    );

    testWidgets('이미 삭제됨: 미리보기가 alreadyDeleted / not-found 면 전용 화면', (t) async {
      await open(
        t,
        app(
          (_) => Future.value(
            const StoreDeletionPreview(
              affected: StoreDeletionAffected(),
              alreadyDeleted: true,
            ),
          ),
        ),
      );
      expect(find.text('이미 삭제된 매장이에요'), findsOneWidget);
      expect(find.text('이 매장 삭제'), findsNothing);
      await t.tap(find.text('목록으로'));
      await t.pumpAndSettle();
      expect(find.byType(AdminStoreDeletePage), findsNothing);
    });

    testWidgets('이미 삭제됨: 실행 결과 alreadyDeleted / not-found', (t) async {
      repo.result = const StoreDeletionResult(alreadyDeleted: true);
      await open(t, app((_) => Future.value(zero)));
      await fill(t);
      await t.tap(find.byKey(const ValueKey('storeDelete.submit')));
      await t.pump();
      await t.pump();
      expect(find.text('이미 삭제된 매장이에요'), findsOneWidget);
    });

    testWidgets('미리보기 not-found 도 이미 삭제됨 화면', (t) async {
      await open(
        t,
        app(
          (_) => Future.error(
            const StoreDeletionException(StoreDeletionFailure.notFound),
          ),
        ),
      );
      expect(find.text('이미 삭제된 매장이에요'), findsOneWidget);
    });
  });
}

class _Repo implements StoreDeletionRepository {
  final List<(String, String)> deleted = [];
  Object? error;
  Completer<void>? gate;
  StoreDeletionResult result = const StoreDeletionResult(deletionId: 'd1');

  @override
  Future<StoreDeletionPreview> preview(String storeId) =>
      throw UnimplementedError('provider override 가 대신한다');

  @override
  Future<StoreDeletionResult> delete(
    String storeId, {
    required String reason,
  }) async {
    deleted.add((storeId, reason));
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return result;
  }
}

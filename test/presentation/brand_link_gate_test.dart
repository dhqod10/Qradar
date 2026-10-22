import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/errors/brand_claim_exception.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/repositories/brand_repository.dart';
import 'package:qradar/domain/usecases/claim_submitted_brand_use_case.dart';
import 'package:qradar/domain/usecases/fetch_my_submitted_brands_use_case.dart';
import 'package:qradar/presentation/brand/brand_id_missing_view.dart';
import 'package:qradar/presentation/brand/brand_info/brand_info_form_page.dart';
import 'package:qradar/presentation/brand/brand_info/brand_info_page.dart';
import 'package:qradar/presentation/brand/providers/brand_info_providers.dart';
import 'package:qradar/presentation/brand/providers/brand_link_gate_provider.dart';

/// brand_authorization_hardening D1-2: `brandId` 없는 brand 계정의 게이트.
/// 불변: 조회가 끝나기 전이나 실패했을 때 등록 폼을 그리지 않는다 (같은 브랜드 재등록 -> 고아 브랜드).
class _Repo implements BrandRepository {
  Future<List<BrandEntity>> Function() lookup = () async => [];
  Future<void> Function(String id) claim = (id) async {};
  final List<String> claims = [];
  int lookups = 0;

  @override
  Future<List<BrandEntity>> fetchMySubmittedBrands() {
    lookups++;
    return lookup();
  }

  @override
  Future<void> claimSubmittedBrand(String brandId) {
    claims.add(brandId);
    return claim(brandId);
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

BrandEntity _b(String id, String name) => BrandEntity(id: id, name: name);

/// 진행 표시기(무한 애니메이션)가 있는 화면이라 pumpAndSettle 대신 유한 프레임만 돌린다.
Future<void> frames(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late _Repo repo;
  setUp(() => repo = _Repo());

  Widget app() => ProviderScope(
    overrides: [
      fetchMySubmittedBrandsUseCaseProvider.overrideWithValue(
        FetchMySubmittedBrandsUseCase(repo),
      ),
      claimSubmittedBrandUseCaseProvider.overrideWithValue(
        ClaimSubmittedBrandUseCase(repo),
      ),
    ],
    child: const MaterialApp(home: BrandIdMissingView()),
  );

  bool formShown() => find.byType(BrandInfoFormPage).evaluate().isNotEmpty;

  testWidgets('조회 중: 확인 중 화면, 폼 없음, 로그아웃만 있다', (t) async {
    final c = Completer<List<BrandEntity>>();
    repo.lookup = () => c.future;
    await t.pumpWidget(app());
    await t.pump();
    await t.pump();
    expect(find.text('브랜드 정보를 확인하고 있어요'), findsOneWidget);
    expect(formShown(), isFalse);
    expect(find.text('로그아웃'), findsOneWidget);
    expect(repo.claims, isEmpty);
    c.complete([]);
    await frames(t);
  });

  testWidgets('0건: 등록 폼 (claim 호출 없음)', (t) async {
    repo.lookup = () async => [];
    await t.pumpWidget(app());
    await frames(t);
    expect(formShown(), isTrue);
    expect(find.text('브랜드 등록'), findsWidgets);
    expect(repo.claims, isEmpty);
  });

  testWidgets('조회 실패: 폼으로 떨어지지 않는다 + 다시 시도 -> 성공하면 자동 연결', (t) async {
    repo.lookup = () => Future.error(StateError('network'));
    await t.pumpWidget(app());
    await frames(t);
    expect(find.text('브랜드 정보를 확인하지 못했어요'), findsOneWidget);
    expect(
      find.text('이미 등록한 브랜드가 있을 수 있어서, 확인되기 전에는 새로 등록할 수 없어요'),
      findsOneWidget,
    );
    expect(find.text('계속 안 되면 관리자에게 문의해 주세요'), findsOneWidget);
    expect(formShown(), isFalse);
    expect(find.textContaining('새로 등록하기'), findsNothing);
    expect(repo.claims, isEmpty);

    repo.lookup = () async => [_b('b1', '내 브랜드')];
    final hold = Completer<void>();
    repo.claim = (id) => hold.future;
    await t.tap(find.text('다시 시도'));
    await t.pump();
    await t.pump();
    expect(find.text('브랜드를 연결하고 있어요'), findsOneWidget);
    expect(find.text('잠시만 기다려 주세요'), findsOneWidget);
    expect(repo.claims, ['b1']);
    hold.complete();
    await frames(t);
    expect(formShown(), isFalse);
  });

  testWidgets('1건: 자동 claim 정확히 1회 (사용자 조작 0), 성공 후에도 폼은 그리지 않는다', (t) async {
    repo.lookup = () async => [_b('b1', '내 브랜드')];
    await t.pumpWidget(app());
    await frames(t);
    expect(repo.claims, ['b1']);
    expect(formShown(), isFalse);
    expect(find.text('브랜드를 연결하고 있어요'), findsOneWidget);
    // 시간이 지나도 다시 부르지 않는다.
    await t.pump(const Duration(seconds: 30));
    expect(repo.claims, ['b1']);
    expect(find.byType(SnackBar), findsNothing, reason: '1건이면 SnackBar 없음');
  });

  testWidgets('2건 이상: 첫 번째(가장 이른) 브랜드로 연결 + 성공 직후 SnackBar 에 이름', (t) async {
    repo.lookup = () async => [_b('early', '먼저 만든'), _b('late', '나중에 만든')];
    await t.pumpWidget(app());
    await frames(t);
    expect(repo.claims, ['early']);
    expect(
      find.text('브랜드 "먼저 만든" 에 연결했어요. 같은 계정으로 등록된 브랜드가 더 있어서 관리자가 확인할 거예요'),
      findsOneWidget,
    );
  });

  testWidgets('연결 실패(retryable): 폼 없음, 새로 등록 버튼 없음, 다시 연결만. 자동 재호출 없음', (
    t,
  ) async {
    repo.lookup = () async => [_b('b1', '내 브랜드')];
    repo.claim = (id) =>
        Future.error(const BrandClaimException(BrandClaimFailure.retryable));
    await t.pumpWidget(app());
    await frames(t);
    expect(find.text('브랜드 연결을 마치지 못했어요'), findsOneWidget);
    expect(
      find.text('등록한 브랜드 "내 브랜드" 은 그대로 있어요. 다시 등록하지 않아도 돼요'),
      findsOneWidget,
    );
    expect(formShown(), isFalse);
    expect(find.textContaining('새로 등록'), findsNothing);
    expect(find.text('다시 연결'), findsOneWidget);
    await t.pump(const Duration(seconds: 30));
    expect(repo.claims, ['b1'], reason: '실패 후 사용자 조작 없이 반복하지 않는다');

    repo.claim = (id) async {};
    await t.tap(find.text('다시 연결'));
    await frames(t);
    expect(repo.claims, ['b1', 'b1']);
    expect(find.text('브랜드를 연결하고 있어요'), findsOneWidget);
  });

  testWidgets('연결 실패 + 2건 이상: 어느 브랜드로 시도했는지 말한다', (t) async {
    repo.lookup = () async => [_b('a', '첫째'), _b('b', '둘째'), _b('c', '셋째')];
    repo.claim = (id) =>
        Future.error(const BrandClaimException(BrandClaimFailure.retryable));
    await t.pumpWidget(app());
    await frames(t);
    expect(
      find.text('등록한 브랜드가 3개 있어요. 가장 먼저 등록한 "첫째" 으로 연결을 시도했어요'),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('이미 다른 브랜드에 연결됨: 재시도 버튼 없음 (D4 — 교정은 admin 전담)', (t) async {
    repo.lookup = () async => [_b('b1', '내 브랜드')];
    repo.claim = (id) => Future.error(
      const BrandClaimException(BrandClaimFailure.alreadyLinked),
    );
    await t.pumpWidget(app());
    await frames(t);
    expect(find.text('이 계정은 이미 다른 브랜드에 연결돼 있어요'), findsOneWidget);
    expect(find.text('관리자에게 문의해 주세요. 직접 바꿀 수는 없어요'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(formShown(), isFalse);
  });

  testWidgets('내 브랜드가 아님(permission-denied): 재시도 버튼 없음', (t) async {
    repo.lookup = () async => [_b('b1', '내 브랜드')];
    repo.claim = (id) =>
        Future.error(const BrandClaimException(BrandClaimFailure.notSubmitter));
    await t.pumpWidget(app());
    await frames(t);
    expect(find.text('이 브랜드는 내 계정으로 등록한 브랜드가 아니에요'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('계정 역할 불일치(not_brand_account): "이미 연결" 이 아닌 별도 문구, 재시도 버튼 없음', (
    t,
  ) async {
    repo.lookup = () async => [_b('b1', '내 브랜드')];
    repo.claim = (id) => Future.error(
      const BrandClaimException(BrandClaimFailure.notBrandAccount),
    );
    await t.pumpWidget(app());
    await frames(t);
    expect(find.text('브랜드 계정이 아니에요'), findsOneWidget);
    expect(find.text('이 계정은 이미 다른 브랜드에 연결돼 있어요'), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets(
    '브랜드 문서 없음(not-found): 같은 claim 을 되풀이하지 않고 "다시 확인" 으로 재조회 -> 0건이면 등록 폼',
    (t) async {
      repo.lookup = () async => [_b('b1', '내 브랜드')];
      repo.claim = (id) => Future.error(
        const BrandClaimException(BrandClaimFailure.brandMissing),
      );
      await t.pumpWidget(app());
      await frames(t);
      expect(find.text('등록한 브랜드를 찾을 수 없어요'), findsOneWidget);
      expect(find.text('다시 연결'), findsNothing, reason: '무한 재시도 금지');
      expect(find.text('다시 확인'), findsOneWidget);
      expect(repo.claims, ['b1']);
      repo.lookup = () async => []; // 브랜드가 실제로 지워짐
      await t.tap(find.text('다시 확인'));
      await frames(t);
      expect(repo.claims, ['b1'], reason: '재조회만 했다');
      expect(formShown(), isTrue);
    },
  );

  test(
    '실패 분류: 같은 failed-precondition 도 사유로 구분 / 사유 없으면 재시도 가능 / message 토큰도 읽는다',
    () {
      BrandClaimFailure c(String code, {String? reason}) =>
          BrandClaimException.classify(code, reason: reason);
      expect(
        c('failed-precondition', reason: 'already_linked'),
        BrandClaimFailure.alreadyLinked,
      );
      expect(
        c('failed-precondition', reason: 'not_brand_account'),
        BrandClaimFailure.notBrandAccount,
      );
      expect(
        c('failed-precondition'),
        BrandClaimFailure.retryable,
        reason: '사유를 모르는 precondition 을 "이미 연결" 로 단정하지 않는다',
      );
      expect(c('permission-denied'), BrandClaimFailure.notSubmitter);
      expect(c('not-found'), BrandClaimFailure.brandMissing);
      expect(c('unavailable'), BrandClaimFailure.retryable);
      expect(c('internal'), BrandClaimFailure.retryable);
      expect(
        BrandClaimException.reasonFromMessage(
          '브랜드 계정이 아니에요 [not_brand_account]',
        ),
        'not_brand_account',
      );
      expect(BrandClaimException.reasonFromMessage('no token'), isNull);
      expect(
        const BrandClaimException(BrandClaimFailure.retryable).isTerminal,
        isFalse,
      );
      expect(
        const BrandClaimException(BrandClaimFailure.brandMissing).isTerminal,
        isTrue,
      );
    },
  );

  testWidgets('등록 폼이 브랜드를 만든 직후 게이트를 다시 평가한다: 폼이 내려가고 방금 만든 브랜드가 연결된다', (
    t,
  ) async {
    // 처음엔 0건 -> 폼. 사용자가 저장하면(여기서는 invalidate 로 모사) 그 사이 브랜드가 생겼다.
    repo.lookup = () async => [];
    await t.pumpWidget(app());
    await frames(t);
    expect(formShown(), isTrue);

    repo.lookup = () async => [_b('new1', '방금 만든')];
    final container = ProviderScope.containerOf(
      t.element(find.byType(BrandInfoFormPage)),
    );
    container.invalidate(brandLinkGateProvider);
    await frames(t);
    expect(formShown(), isFalse, reason: '폼이 남아 있으면 같은 브랜드를 다시 저장할 수 있다');
    expect(repo.claims, ['new1']);
  });

  testWidgets(
    'F-S2: brandId 는 있는데 브랜드 문서가 없는 계정(BrandInfoPage) — 등록 버튼이 없다 (두 번째 등록 진입점 제거)',
    (t) async {
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            myBrandProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: const MaterialApp(home: Scaffold(body: BrandInfoPage())),
        ),
      );
      await frames(t);
      expect(find.text('연결된 브랜드를 찾지 못했어요'), findsOneWidget);
      expect(find.text('브랜드 등록하기'), findsNothing);
      expect(find.text('아직 브랜드가 등록되지 않았어요'), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(formShown(), isFalse);
    },
  );
}

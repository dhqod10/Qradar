import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/errors/brand_key_lookup_exception.dart';
import 'package:qradar/domain/entities/brand_key_lookup.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/store_grade.dart';
import 'package:qradar/domain/entities/user_location.dart';
import 'package:qradar/domain/entities/user_entity.dart';
import 'package:qradar/domain/repositories/brand_repository.dart';
import 'package:qradar/domain/usecases/lookup_brand_by_key_use_case.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/owner/my_store/store_core_form_page.dart';
import 'package:qradar/presentation/owner/providers/owner_providers.dart';

/// payment_server_authority B1 design §5.4: brandKey 조회 결과 3경우가 필드 아래 인라인 에러로 분리된다.
/// 불변: 네트워크·서버 실패 문구가 "키가 틀렸다" 로 읽히지 않는다. 다이얼로그를 쓰지 않는다. 서버 문자열 노출 없음.
class _Auth extends AuthNotifier {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(uid: 'owner1', provider: 'email');
}

class _BrandRepo implements BrandRepository {
  Object? error;
  int calls = 0;
  @override
  Future<BrandKeyLookup> lookupBrandByKey(String brandKey) async {
    calls++;
    if (error != null) throw error!;
    return const BrandKeyLookup(brandId: 'b1', name: 'Q');
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

StoreEntity get _store => StoreEntity(
  id: 's1',
  name: '강남점',
  imageUrl: '',
  location: const UserLocation(latitude: 37.5, longitude: 127.0),
  grade: StoreGrade.c,
  averageScore: 0,
  reviewCount: 0,
  menuCategories: const ['커피'],
  createdAt: DateTime(2026),
  ownerId: 'owner1',
  address: '서울시 강남구',
);

void main() {
  late _BrandRepo repo;
  setUp(() => repo = _BrandRepo());

  Future<void> submitWithKey(WidgetTester t, String key) async {
    t.view.physicalSize = const Size(900, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          ownerLookupBrandByKeyUseCaseProvider.overrideWithValue(
            LookupBrandByKeyUseCase(repo),
          ),
        ],
        child: MaterialApp(home: StoreCoreFormPage(existing: _store)),
      ),
    );
    await t.pump();
    // 제출은 `ref.read(authProvider)` 가 값을 가진 뒤에만 진행한다 — 미리 해소해 둔다.
    await ProviderScope.containerOf(
      t.element(find.byType(StoreCoreFormPage)),
    ).read(authProvider.future);
    await t.tap(find.byType(SwitchListTile));
    await t.pump(const Duration(milliseconds: 300));
    await t.enterText(find.widgetWithText(TextFormField, '브랜드 키'), key);
    await t.pump();
    await t.tap(find.text('검토 요청 보내기'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
  }

  testWidgets('미매칭: 승인 대기 가능성을 정적 문구로 알린다. 다이얼로그 없음', (t) async {
    repo.error = const BrandKeyLookupException(BrandKeyLookupFailure.notFound);
    await submitWithKey(t, 'BR-ABCDEFGH');
    expect(find.text(brandKeyNotFoundMessage), findsOneWidget);
    expect(
      brandKeyNotFoundMessage,
      '브랜드를 찾을 수 없어요. 키를 다시 확인해 주세요. 키가 맞다면 브랜드가 승인 대기 중일 수 있어요',
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('네트워크·서버 실패: 미매칭과 다른 문구 (키가 틀렸다고 오해시키지 않는다)', (t) async {
    repo.error = const BrandKeyLookupException(BrandKeyLookupFailure.failed);
    await submitWithKey(t, 'BR-ABCDEFGH');
    expect(find.text('확인하지 못했어요. 잠시 후 다시 시도해 주세요'), findsOneWidget);
    expect(find.text(brandKeyNotFoundMessage), findsNothing);
    expect(find.textContaining('찾을 수 없어요'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('rate limit: 조회 과다 문구', (t) async {
    repo.error = const BrandKeyLookupException(
      BrandKeyLookupFailure.rateLimited,
    );
    await submitWithKey(t, 'BR-ABCDEFGH');
    expect(find.text('조회를 너무 많이 시도했어요. 잠시 후 다시 시도해 주세요'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('에러는 필드 수정으로 해제되고, 제출 버튼 재탭이 복구 동작이다', (t) async {
    repo.error = const BrandKeyLookupException(BrandKeyLookupFailure.failed);
    await submitWithKey(t, 'BR-ABCDEFGH');
    expect(find.text(brandKeyLookupFailedMessage), findsOneWidget);
    await t.enterText(
      find.widgetWithText(TextFormField, '브랜드 키'),
      'BR-ABCDEFGJ',
    );
    await t.pump();
    expect(find.text(brandKeyLookupFailedMessage), findsNothing);
    // 다시 제출 -> 조회가 다시 일어난다.
    await t.tap(find.text('검토 요청 보내기'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(repo.calls, 2);
  });

  test('문구 매핑은 3경우가 서로 다르다', () {
    final texts = BrandKeyLookupFailure.values
        .map(brandKeyLookupErrorText)
        .toSet();
    expect(texts.length, 3);
  });
}

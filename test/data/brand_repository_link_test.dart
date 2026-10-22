import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/errors/brand_claim_exception.dart';
import 'package:qradar/data/datasources/remote/brand_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/store_remote_data_source.dart';
import 'package:qradar/data/models/brand_model.dart';
import 'package:qradar/data/repositories/brand_repository_impl.dart';
import 'package:qradar/domain/entities/brand_entity.dart';

/// brand_authorization_hardening D1: `upsertBrand` 신규 분기는 `users` 를 쓰지 않는다.
/// 브랜드 문서 1건만 쓰고, 연결(users.brandId)은 서버(claimSubmittedBrand)에 맡긴다.
/// 구 방식(브랜드 문서 + users.brandId batch)은 신 Rules 에서 batch 전체가 거부돼 신규 등록이 전면 실패한다.
class _Ds implements BrandRemoteDataSource {
  final List<String> calls = [];
  final List<Map<String, dynamic>> sets = [];
  Object? claimError;
  List<BrandModel> submitted = [];

  @override
  Future<void> set(String brandId, Map<String, dynamic> data) async {
    calls.add('set:$brandId');
    sets.add(data);
  }

  @override
  Future<void> claimSubmittedBrand(String brandId) async {
    calls.add('claim:$brandId');
    if (claimError != null) throw claimError!;
  }

  @override
  Future<List<BrandModel>> fetchBySubmitter(String uid) async {
    calls.add('fetchBySubmitter:$uid');
    return submitted;
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('쓰기 경로 침범: ${i.memberName}');
}

class _StoreDs implements StoreRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

BrandEntity _form() => const BrandEntity(
  id: '',
  name: '새 브랜드',
  companyName: '(주)새',
  businessRegistrationNumber: '123-45-67890',
  contactName: '홍',
  contactPhone: '02-1234-5678',
);

void main() {
  late _Ds ds;
  late BrandRepositoryImpl repo;
  setUp(() {
    ds = _Ds();
    repo = BrandRepositoryImpl(
      ds,
      _StoreDs(),
      currentUidGetter: () => 'uid-me',
      newBrandIdGenerator: () => 'newBrandId',
    );
  });

  test(
    '신규 등록: 브랜드 문서 1건 쓰기 -> claimSubmittedBrand 호출. users 쓰기 경로가 없다',
    () async {
      final id = await repo.upsertBrand(_form());
      expect(id, 'newBrandId');
      // 호출 순서와 대상 전부 (데이터소스에는 users 를 쓰는 메서드가 없고, 있었다면 noSuchMethod 가 던진다).
      expect(ds.calls, ['set:newBrandId', 'claim:newBrandId']);
      final w = ds.sets.single;
      expect(w['status'], 'pending');
      expect(w['brandKey'], '');
      expect(w['submittedBy'], 'uid-me');
      // 쓰기 맵 키 집합 골든 — users.brandId 같은 권한 값이 브랜드 문서 쓰기에 끼어들지 않는다.
      expect(
        w.keys.toSet(),
        containsAll({'name', 'status', 'brandKey', 'submittedBy'}),
      );
      expect(
        w.keys.where((k) => k.toLowerCase().contains('qoin')),
        isEmpty,
        reason: 'Qoin 필드는 create 로도 심을 수 없다 (Rules)',
      );
      for (final k in const ['role', 'users', 'uid', 'brandId']) {
        expect(w.containsKey(k), isFalse, reason: k);
      }
    },
  );

  test(
    'claim 이 실패해도 upsertBrand 는 실패하지 않는다 (브랜드 문서가 이미 있다 — 재등록 방지, 복구는 게이트)',
    () async {
      ds.claimError = const BrandClaimException(BrandClaimFailure.retryable);
      final id = await repo.upsertBrand(_form());
      expect(id, 'newBrandId');
      expect(ds.calls, ['set:newBrandId', 'claim:newBrandId']);
    },
  );

  test('브랜드 문서 쓰기 자체가 실패하면 claim 을 부르지 않고 예외를 전파한다', () async {
    final failing = _FailingSet();
    final r = BrandRepositoryImpl(
      failing,
      _StoreDs(),
      currentUidGetter: () => 'uid-me',
      newBrandIdGenerator: () => 'x',
    );
    await expectLater(r.upsertBrand(_form()), throwsA(isA<StateError>()));
    expect(failing.claimed, isFalse);
  });

  test(
    'fetchMySubmittedBrands: 가장 이른 submittedAt 순, 제출 시각 없는 문서는 뒤로',
    () async {
      BrandModel m(String id, DateTime? at) => BrandModel.fromEntity(
        BrandEntity(id: id, name: id, submittedAt: at, submittedBy: 'uid-me'),
      );
      ds.submitted = [
        m('c', null),
        m('b', DateTime(2026, 3)),
        m('a', DateTime(2026, 1)),
      ];
      final list = await repo.fetchMySubmittedBrands();
      expect(list.map((b) => b.id), ['a', 'b', 'c']);
      expect(ds.calls, ['fetchBySubmitter:uid-me']);
    },
  );

  test('fetchMySubmittedBrands: 조회 실패는 빈 목록이 아니라 예외다', () async {
    final r = BrandRepositoryImpl(
      _ThrowingLookup(),
      _StoreDs(),
      currentUidGetter: () => 'uid-me',
    );
    await expectLater(r.fetchMySubmittedBrands(), throwsA(isA<StateError>()));
  });

  test('uid 가 비어 있으면 조회하지 않고 빈 목록', () async {
    final r = BrandRepositoryImpl(ds, _StoreDs(), currentUidGetter: () => '');
    expect(await r.fetchMySubmittedBrands(), isEmpty);
    expect(ds.calls, isEmpty);
  });
}

class _FailingSet extends _Ds {
  bool claimed = false;
  @override
  Future<void> set(String brandId, Map<String, dynamic> data) =>
      Future.error(StateError('rules denied'));
  @override
  Future<void> claimSubmittedBrand(String brandId) async => claimed = true;
}

class _ThrowingLookup extends _Ds {
  @override
  Future<List<BrandModel>> fetchBySubmitter(String uid) =>
      Future.error(StateError('network'));
}

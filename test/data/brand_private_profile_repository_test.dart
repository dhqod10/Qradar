import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/errors/brand_key_issue_exception.dart';
import 'package:qradar/core/errors/brand_key_lookup_exception.dart';
import 'package:qradar/core/errors/brand_private_profile_save_exception.dart';
import 'package:qradar/data/datasources/remote/authority_callables_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/brand_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/store_remote_data_source.dart';
import 'package:qradar/data/models/brand_model.dart';
import 'package:qradar/data/models/brand_private_profile_model.dart';
import 'package:qradar/data/repositories/brand_repository_impl.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/brand_key_lookup.dart';
import 'package:qradar/domain/entities/brand_private_profile_entity.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';

/// payment_server_authority B1: brandKey / 사업자 PII 가 부모 `brands/{id}` 에서 `private/profile` 로 이동했다.
/// 불변: (1) 클라이언트는 brandKey 를 어떤 경로로도 쓰지 않는다 (2) 승인은 `issueBrandKey` 성공 뒤에만 status 를 바꾼다
/// (3) PII 만 바뀌어도 status 는 회귀하지 않는다 (4) 비공개 프로필 읽기 실패는 빈 값이 아니라 예외다.
class _Ds implements BrandRemoteDataSource {
  final List<String> calls = [];
  final List<Map<String, dynamic>> sets = [];
  final List<Map<String, dynamic>> updates = [];
  final List<Map<String, dynamic>> privateSets = [];
  BrandModel? existing;
  Object? privateWriteError;
  Object? privateReadError;
  BrandPrivateProfileModel? privateProfile;

  @override
  Future<BrandModel?> fetchById(String brandId) async => existing;

  @override
  Future<void> set(String brandId, Map<String, dynamic> data) async {
    calls.add('set');
    sets.add(data);
  }

  @override
  Future<void> update(String brandId, Map<String, dynamic> partial) async {
    calls.add('update');
    updates.add(partial);
  }

  @override
  Future<void> claimSubmittedBrand(String brandId) async => calls.add('claim');

  @override
  Future<void> setPrivateProfile(
    String brandId,
    Map<String, dynamic> data,
  ) async {
    calls.add('private');
    if (privateWriteError != null) throw privateWriteError!;
    privateSets.add(data);
  }

  @override
  Stream<BrandPrivateProfileModel?> streamPrivateProfile(String brandId) {
    if (privateReadError != null) return Stream.error(privateReadError!);
    return Stream.value(privateProfile);
  }

  @override
  Future<BrandPrivateProfileModel?> fetchPrivateProfile(String brandId) async {
    if (privateReadError != null) throw privateReadError!;
    return privateProfile;
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _Callables implements AuthorityCallablesRemoteDataSource {
  final List<String> issued = [];
  Object? issueError;
  final _Ds ds;
  _Callables(this.ds);

  @override
  Future<({String brandKey, bool alreadyIssued})> issueBrandKey(
    String brandId,
  ) async {
    // 호출 시점에 브랜드 문서가 아직 안 바뀌었는지 확인할 수 있게 순서를 기록한다.
    ds.calls.add('issue');
    issued.add(brandId);
    if (issueError != null) throw issueError!;
    return (brandKey: 'BR-ABCDEFGH', alreadyIssued: false);
  }

  Object? lookupError;
  @override
  Future<BrandKeyLookup> lookupBrandByKey(String brandKey) async {
    if (lookupError != null) throw lookupError!;
    return const BrandKeyLookup(brandId: 'b1', name: 'Q');
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _StoreDs implements StoreRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

const _pii = BrandPrivateProfileEntity(
  brandKey: 'BR-SHOULDNOT', // 엔티티에 키가 실려 와도 쓰기 맵에는 들어가지 않아야 한다
  businessRegistrationNumber: '123-45-67890',
  contactName: '홍',
  contactPhone: '02-1234-5678',
);

BrandModel _existing({String name = 'B', String? description}) =>
    BrandModel.fromEntity(
      BrandEntity(
        id: 'b1',
        name: name,
        description: description,
        status: EntityApprovalStatus.approved,
        approvedBy: 'admin',
      ),
    );

void main() {
  late _Ds ds;
  late _Callables callables;
  late BrandRepositoryImpl repo;
  setUp(() {
    ds = _Ds();
    callables = _Callables(ds);
    repo = BrandRepositoryImpl(
      ds,
      _StoreDs(),
      callables,
      currentUidGetter: () => 'uid-me',
      newBrandIdGenerator: () => 'newId',
    );
  });

  group('approveBrand', () {
    test(
      'issueBrandKey 성공 후에만 status 를 승인으로 쓰고, brandKey 필드는 쓰지 않는다',
      () async {
        await repo.approveBrand('b1', 'admin-uid');
        expect(ds.calls, ['issue', 'update']); // 순서 고정
        expect(callables.issued, ['b1']);
        final u = ds.updates.single;
        expect(u['status'], 'approved');
        expect(u['approvedBy'], 'admin-uid');
        expect(u.containsKey('brandKey'), isFalse);
      },
    );

    test('issueBrandKey 가 실패하면 브랜드 문서를 건드리지 않고 예외를 전파한다', () async {
      callables.issueError = const BrandKeyIssueException(code: 'unavailable');
      await expectLater(
        repo.approveBrand('b1', 'admin-uid'),
        throwsA(isA<BrandKeyIssueException>()),
      );
      expect(ds.calls, ['issue']);
      expect(ds.updates, isEmpty);
      expect(ds.sets, isEmpty);
    });
  });

  group('upsertBrand', () {
    test('신규: 부모 -> claim -> private 순서, brandKey 는 어디에도 쓰지 않는다', () async {
      await repo.upsertBrand(
        const BrandEntity(id: '', name: 'N', companyName: 'C'),
        privateProfile: _pii,
      );
      expect(ds.calls, ['set', 'claim', 'private']);
      expect(ds.sets.single.containsKey('brandKey'), isFalse);
      expect(ds.privateSets.single.containsKey('brandKey'), isFalse);
      expect(
        ds.privateSets.single['businessRegistrationNumber'],
        '123-45-67890',
      );
    });

    test(
      '신규: 선택 PII 가 null 이면 FieldValue.delete (사용자가 비운 값이 남지 않는다)',
      () async {
        await repo.upsertBrand(
          const BrandEntity(id: '', name: 'N'),
          privateProfile: _pii,
        );
        expect(ds.privateSets.single['headOfficeAddress'], isA<FieldValue>());
        expect(ds.privateSets.single['representativeName'], isA<FieldValue>());
      },
    );

    test(
      '신규: private 쓰기 실패 -> 만들어진 brandId 를 실어 던진다 (폼이 같은 id 로 재시도)',
      () async {
        ds.privateWriteError = StateError('rules');
        await expectLater(
          repo.upsertBrand(
            const BrandEntity(id: '', name: 'N'),
            privateProfile: _pii,
          ),
          throwsA(
            isA<BrandPrivateProfileSaveException>().having(
              (e) => e.brandId,
              'brandId',
              'newId',
            ),
          ),
        );
      },
    );

    test('수정: PII 만 바뀌면 status 회귀 없이 logo update + private 쓰기만 한다', () async {
      ds.existing = _existing(name: 'B', description: 'd');
      await repo.upsertBrand(
        const BrandEntity(id: 'b1', name: 'B', description: 'd', logoUrl: 'l'),
        privateProfile: _pii,
      );
      expect(ds.sets, isEmpty, reason: '부모 전체 set(=pending 회귀)이 없어야 한다');
      expect(ds.updates.single.keys.toSet(), {'logoUrl', 'updatedAt'});
      expect(ds.updates.single.containsKey('status'), isFalse);
      expect(ds.calls, ['update', 'private']);
      expect(ds.privateSets.single.containsKey('brandKey'), isFalse);
    });

    test(
      '수정: name 이 바뀌면 pending 회귀 (기존 coreChanged 판정 유지), brandKey 는 쓰지 않는다',
      () async {
        ds.existing = _existing(name: 'B');
        await repo.upsertBrand(
          const BrandEntity(id: 'b1', name: 'B2'),
          privateProfile: _pii,
        );
        expect(ds.sets.single['status'], 'pending');
        expect(ds.sets.single.containsKey('brandKey'), isFalse);
        expect(ds.calls, ['set', 'private']);
      },
    );

    test('privateProfile 이 null 이면 private 쓰기를 하지 않는다', () async {
      ds.existing = _existing();
      await repo.upsertBrand(const BrandEntity(id: 'b1', name: 'B'));
      expect(ds.calls, ['update']);
    });
  });

  group('비공개 프로필 읽기', () {
    test('문서가 있으면 엔티티, 없으면 null', () async {
      ds.privateProfile = const BrandPrivateProfileModel(
        brandKey: 'BR-ABCDEFGH',
      );
      expect((await repo.fetchPrivateProfile('b1'))?.brandKey, 'BR-ABCDEFGH');
      ds.privateProfile = null;
      expect(await repo.fetchPrivateProfile('b1'), isNull);
    });

    test('읽기 실패는 빈 프로필이 아니라 예외/스트림 에러로 전파된다', () async {
      ds.privateReadError = StateError('permission-denied');
      await expectLater(
        repo.fetchPrivateProfile('b1'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        repo.watchPrivateProfile('b1'),
        emitsError(isA<StateError>()),
      );
    });
  });

  group('lookupBrandByKey', () {
    test(
      '성공 값 객체 / 실패는 BrandKeyLookupException 그대로 (null 로 뭉개지 않는다)',
      () async {
        expect((await repo.lookupBrandByKey('BR-ABCDEFGH')).brandId, 'b1');
        callables.lookupError = const BrandKeyLookupException(
          BrandKeyLookupFailure.failed,
        );
        await expectLater(
          repo.lookupBrandByKey('BR-ABCDEFGH'),
          throwsA(
            isA<BrandKeyLookupException>().having(
              (e) => e.kind,
              'kind',
              BrandKeyLookupFailure.failed,
            ),
          ),
        );
      },
    );
  });

  group('모델 쓰기 맵', () {
    test('BrandModel.toFirestore 에는 brandKey·PII 5개가 없다', () {
      final m = BrandModel.fromEntity(
        const BrandEntity(id: 'b', name: 'N', companyName: 'C'),
      ).toFirestore();
      for (final k in const [
        'brandKey',
        'businessRegistrationNumber',
        'contactName',
        'contactPhone',
        'headOfficeAddress',
        'representativeName',
      ]) {
        expect(m.containsKey(k), isFalse, reason: k);
      }
      expect(m['companyName'], 'C');
    });

    test(
      'BrandPrivateProfileModel.toFirestore 는 PII 5개만 — brandKey 는 엔티티에 있어도 쓰지 않는다',
      () {
        final m = BrandPrivateProfileModel.fromEntity(_pii).toFirestore();
        expect(m.keys.toSet(), {
          'businessRegistrationNumber',
          'contactName',
          'contactPhone',
          'headOfficeAddress',
          'representativeName',
        });
      },
    );

    test('fromMap 은 brandKey 를 읽는다 (읽기 전용 필드)', () {
      final p = BrandPrivateProfileModel.fromMap({'brandKey': 'BR-ABCDEFGH'});
      expect(p.toEntity().hasBrandKey, isTrue);
      expect(
        BrandPrivateProfileModel.fromMap({}).toEntity().hasBrandKey,
        isFalse,
      );
    });
  });
}

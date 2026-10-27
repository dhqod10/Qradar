import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/errors/brand_key_lookup_exception.dart';
import 'package:qradar/core/errors/store_deletion_exception.dart';
import 'package:qradar/data/datasources/remote/authority_callables_remote_data_source.dart';

/// callable 계약(에러 코드 -> 분류, dryRun 응답 파싱)의 순수 부분.
void main() {
  group('lookupBrandByKey 에러 분류', () {
    test('not-found / invalid-argument 는 같은 notFound (열거 오라클 방지)', () {
      for (final c in ['not-found', 'invalid-argument']) {
        expect(
          AuthorityCallablesRemoteDataSource.classifyLookupCode(c),
          BrandKeyLookupFailure.notFound,
          reason: c,
        );
      }
    });
    test('resource-exhausted 는 rateLimited', () {
      expect(
        AuthorityCallablesRemoteDataSource.classifyLookupCode(
          'resource-exhausted',
        ),
        BrandKeyLookupFailure.rateLimited,
      );
    });
    test(
      '그 밖(네트워크·unavailable·deadline·unauthenticated·internal)은 failed — 미매칭과 다르다',
      () {
        for (final c in [
          'unavailable',
          'deadline-exceeded',
          'unauthenticated',
          'internal',
          'unknown',
          'permission-denied',
        ]) {
          expect(
            AuthorityCallablesRemoteDataSource.classifyLookupCode(c),
            BrandKeyLookupFailure.failed,
            reason: c,
          );
        }
      },
    );
  });

  group('deleteStore 에러 분류', () {
    test('failed-precondition + 끝 토큰 -> inFlightOrders', () {
      expect(
        AuthorityCallablesRemoteDataSource.classifyDeleteError(
          'failed-precondition',
          '진행 중인 주문이 있어요 [STORE_HAS_INFLIGHT_ORDERS]',
        ),
        StoreDeletionFailure.inFlightOrders,
      );
    });
    test('토큰 없는 failed-precondition 은 가드로 읽지 않는다', () {
      expect(
        AuthorityCallablesRemoteDataSource.classifyDeleteError(
          'failed-precondition',
          '다른 사전조건',
        ),
        StoreDeletionFailure.failed,
      );
      expect(
        AuthorityCallablesRemoteDataSource.classifyDeleteError(
          'failed-precondition',
          null,
        ),
        StoreDeletionFailure.failed,
      );
    });
    test('토큰이 있어도 다른 코드면 가드가 아니다', () {
      expect(
        AuthorityCallablesRemoteDataSource.classifyDeleteError(
          'internal',
          '[STORE_HAS_INFLIGHT_ORDERS]',
        ),
        StoreDeletionFailure.failed,
      );
    });
    test('not-found / 중간 실패(internal·unavailable)', () {
      expect(
        AuthorityCallablesRemoteDataSource.classifyDeleteError('not-found', ''),
        StoreDeletionFailure.notFound,
      );
      for (final c in ['internal', 'unavailable', 'deadline-exceeded']) {
        expect(
          AuthorityCallablesRemoteDataSource.classifyDeleteError(c, 'x'),
          StoreDeletionFailure.failed,
          reason: c,
        );
      }
    });
  });

  group('dryRun 응답 파싱', () {
    test('affected 7종을 읽고 blockedBy 와 같이 진행 중 주문 수를 정한다', () {
      final p = AuthorityCallablesRemoteDataSource.parsePreview({
        'affected': {
          'menuItems': 3,
          'menuOverrides': 2,
          'subCategories': 1,
          'optionGroups': 4,
          'qoinRateHistory': 5,
          'images': 6,
          'inFlightOrders': 0,
        },
        'blockedBy': {'inFlightOrders': 2},
      });
      expect(p.affected.menuItems, 3);
      expect(p.affected.images, 6);
      expect(
        p.affected.inFlightOrders,
        2,
        reason: '둘 중 큰 쪽 — 한쪽만 와도 가드가 풀리지 않는다',
      );
      expect(p.isBlocked, isTrue);
    });
    test('전부 0 이면 차단 아님', () {
      final p = AuthorityCallablesRemoteDataSource.parsePreview({
        'affected': {'menuItems': 0},
      });
      expect(p.isBlocked, isFalse);
      expect(p.alreadyDeleted, isFalse);
    });
    test('alreadyDeleted:true', () {
      expect(
        AuthorityCallablesRemoteDataSource.parsePreview({
          'alreadyDeleted': true,
        }).alreadyDeleted,
        isTrue,
      );
    });
    test('affected 가 없는 응답은 0건이 아니라 실패 (fail-closed)', () {
      expect(
        () => AuthorityCallablesRemoteDataSource.parsePreview({'x': 1}),
        throwsA(isA<StoreDeletionException>()),
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/constants/grade_thresholds.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/store_grade.dart';
import 'package:qradar/domain/entities/store_page.dart';
import 'package:qradar/domain/entities/user_location.dart';
import 'package:qradar/domain/repositories/store_repository.dart';
import 'package:qradar/domain/usecases/get_nearby_stores_paged_use_case.dart';
import 'package:qradar/presentation/customer/home/providers/home_providers.dart';
import 'package:qradar/presentation/customer/home/providers/nearby_paged_providers.dart';

StoreEntity _s(String id, double? km) => StoreEntity(
  id: id,
  name: id,
  imageUrl: '',
  location: const UserLocation(latitude: 0, longitude: 0),
  grade: StoreGrade.c,
  averageScore: 0,
  reviewCount: 0,
  menuCategories: const [],
  createdAt: DateTime(2026),
  distanceKm: km,
);

/// 거리(km) 목록을 가진 가짜 저장소 — 반경 이내만 돌려준다 (Repository 계약과 동일).
class _FakeRepo implements StoreRepository {
  _FakeRepo(this.all);
  final List<StoreEntity> all;
  final List<double> calls = [];
  int failNext = 0;

  @override
  Future<StorePage> getNearbyStoresPaged({
    required UserLocation center,
    required double radiusKm,
  }) async {
    calls.add(radiusKm);
    if (failNext > 0) {
      failNext--;
      throw StateError('boom');
    }
    final items = all.where((s) => s.distanceKm! <= radiusKm).toList()
      ..sort((a, b) => a.distanceKm!.compareTo(b.distanceKm!));
    return StorePage(
      items: items,
      loadedRadiusKm: radiusKm,
      exhausted: GetNearbyStoresPagedUseCase.isMaxRadius(radiusKm),
    );
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

class _FakeLocation extends UserLocationNotifier {
  @override
  Future<UserLocation> build() async =>
      const UserLocation(latitude: 37.5, longitude: 127, isFallback: true);
}

ProviderContainer _container(_FakeRepo repo) => ProviderContainer(
  overrides: [
    storeRepositoryProvider.overrideWithValue(repo),
    userLocationProvider.overrideWith(_FakeLocation.new),
  ],
);

List<StoreEntity> _many(int n, {double step = 0.1, double start = 0.1}) =>
    List.generate(n, (i) => _s('s$i', start + i * step));

void main() {
  group('반경 확장 규칙', () {
    test('5 -> 10 -> 20 -> 40 이후 40 에서 멈춘다', () {
      var r = GradeThresholds.nearbyPagedStartRadiusKm;
      final seq = [r];
      while (!GetNearbyStoresPagedUseCase.isMaxRadius(r)) {
        r = GetNearbyStoresPagedUseCase.nextRadius(r);
        seq.add(r);
      }
      expect(seq, [5, 10, 20, 40]);
      expect(GetNearbyStoresPagedUseCase.nextRadius(40), 40);
    });

    test('newItemsOnly: 기존 id 제외 + 배치 내 중복 제거 + 거리 오름차순(미상은 뒤)', () {
      final fresh = GetNearbyStoresPagedUseCase.newItemsOnly(
        [_s('c', 3), _s('a', 1), _s('a', 1), _s('x', null), _s('seen', 0.5), _s('b', 2)],
        {'seen'},
      );
      expect(fresh.map((e) => e.id), ['a', 'b', 'c', 'x']);
    });
  });

  group('pagedNearbyStoresProvider', () {
    test('초기 20건만 노출, 가까운 순, 위치 폴백 플래그 전달', () async {
      final repo = _FakeRepo(_many(50)); // 0.1 ~ 5.0km 전부 5km 이내
      final c = _container(repo);
      addTearDown(c.dispose);
      final s = await c.read(pagedNearbyStoresProvider.future);
      expect(s.visible.length, 20);
      expect(s.visible.first.id, 's0');
      expect(s.isFallbackLocation, isTrue);
      expect(repo.calls, [5.0]); // 한 번만 읽고 확장 안 함
      expect(s.exhausted, isFalse);
    });

    test('미노출분이 20 이상이면 읽기 없이 노출만 늘린다 + 순서 불변', () async {
      final repo = _FakeRepo(_many(50));
      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(pagedNearbyStoresProvider.future);
      final before = c.read(pagedNearbyStoresProvider).value!.visible.map((e) => e.id).toList();
      await c.read(pagedNearbyStoresProvider.notifier).loadMore();
      final s = c.read(pagedNearbyStoresProvider).value!;
      expect(s.visible.length, 40);
      expect(s.visible.take(20).map((e) => e.id), before);
      expect(repo.calls.length, 1);
    });

    test('초기 결과가 모자라면 20건 찰 때까지 반경을 넓힌다', () async {
      // 5km 내 3건, 5~10km 내 3건, 10~20km 내 20건
      final all = [
        ..._many(3, start: 1, step: 1),
        ..._many(3, start: 6, step: 1).map((e) => _s('m${e.id}', e.distanceKm)),
        ...List.generate(20, (i) => _s('f$i', 11 + i * 0.4)),
      ];
      final repo = _FakeRepo(all);
      final c = _container(repo);
      addTearDown(c.dispose);
      final s = await c.read(pagedNearbyStoresProvider.future);
      expect(repo.calls, [5, 10, 20]);
      expect(s.visible.length, 20);
      expect(s.loaded.length, 26);
      // 거리 단조 증가 = 요동 없음
      final d = s.loaded.map((e) => e.distanceKm!).toList();
      expect([...d]..sort(), d);
    });

    test('최대 반경까지 0건이면 빈 목록 확정 (확장 중에는 loading 유지)', () async {
      final repo = _FakeRepo([_s('far', 99)]);
      final c = _container(repo);
      addTearDown(c.dispose);
      final sub = c.listen(pagedNearbyStoresProvider, (_, _) {});
      expect(sub.read().isLoading, isTrue);
      final s = await c.read(pagedNearbyStoresProvider.future);
      expect(repo.calls, [5, 10, 20, 40]);
      expect(s.visible, isEmpty);
      expect(s.exhausted, isTrue);
    });

    test('소진 판정: 마지막 노출 + 최대 반경이면 exhausted, loadMore 는 무시', () async {
      final repo = _FakeRepo(_many(25, start: 1, step: 1.5)); // 1 ~ 37km
      final c = _container(repo);
      addTearDown(c.dispose);
      final n = c.read(pagedNearbyStoresProvider.notifier);
      await c.read(pagedNearbyStoresProvider.future);
      await n.loadMore();
      final s = c.read(pagedNearbyStoresProvider).value!;
      expect(s.visible.length, 25);
      expect(s.exhausted, isTrue);
      final callsBefore = repo.calls.length;
      await n.loadMore();
      expect(repo.calls.length, callsBefore);
      expect(s.loaded.map((e) => e.id).toSet().length, s.loaded.length); // 중복 0
    });

    test('추가 로드 실패: 기존 목록 보존 + 실패 플래그, 자동 재호출 없음, 재시도 성공', () async {
      final all = [..._many(20, start: 0.1, step: 0.1), ...List.generate(5, (i) => _s('n$i', 30.0 + i))];
      final repo = _FakeRepo(all);
      final c = _container(repo);
      addTearDown(c.dispose);
      final n = c.read(pagedNearbyStoresProvider.notifier);
      final init = await c.read(pagedNearbyStoresProvider.future);
      expect(init.hasMore, isTrue);

      repo.failNext = 1;
      await n.loadMore();
      var s = c.read(pagedNearbyStoresProvider).value!;
      expect(s.loadMoreFailed, isTrue);
      expect(s.isLoadingMore, isFalse);
      expect(s.visible.length, 20); // 보존
      expect(s.canLoadMore, isFalse);

      final calls = repo.calls.length;
      await n.loadMore(); // 트리거 무시
      expect(repo.calls.length, calls);

      await n.retryLoadMore();
      s = c.read(pagedNearbyStoresProvider).value!;
      expect(s.loadMoreFailed, isFalse);
      expect(s.visible.length, 25);
      expect(s.exhausted, isTrue);
    });

    test('초기 로드 실패는 AsyncError', () async {
      final repo = _FakeRepo(_many(3))..failNext = 99;
      final c = _container(repo);
      addTearDown(c.dispose);
      c.listen(pagedNearbyStoresProvider, (_, _) {});
      await expectLater(c.read(pagedNearbyStoresProvider.future), throwsA(isA<StateError>()));
    });
  });

  test('StoreModel/라이브러리 geohash: 알려진 좌표 벡터 (백필 CF 와 동일 알고리즘 확인)', () {
    // 표준 geohash 예시: (57.64911, 10.40744) -> u4pruydqq (정밀도 9)
    final p = GeoFirePoint(const GeoPoint(57.64911, 10.40744));
    expect(p.geohash.substring(0, 9), 'u4pruydqq');
  });
}

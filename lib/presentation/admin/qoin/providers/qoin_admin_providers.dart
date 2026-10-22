import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/admin/providers/admin_brand_approval_providers.dart';
import 'package:qradar/presentation/admin/providers/admin_store_approval_providers.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_rate_edit_form.dart';
import 'package:qradar/presentation/common/providers/qoin_rate_providers.dart';

/// 모든 브랜드 (승인 전 포함 — design D3: 승인 전에도 적립률을 미리 정할 수 있게 노출하고 배지로 구분한다).
final qoinAdminBrandsProvider = StreamProvider<List<BrandEntity>>((ref) {
  return ref.watch(watchAllBrandsForAdminUseCaseProvider)();
});

/// 모든 매장 (승인 전 포함). 매장 목록·허브 부제·브랜드 편집의 산하 매장 통계가 **같은 스트림 1개**를 공유한다.
final qoinAdminStoresProvider = StreamProvider<List<StoreEntity>>((ref) {
  return ref.watch(adminWatchAllStoresUseCaseProvider)();
});

/// 한 브랜드의 산하 매장 통계 (클라이언트 미리보기). 전체 매장 스트림에서 거른다 — 추가 구독 0.
/// 로딩/에러는 그대로 전달한다 (영향 매장 수를 못 보여주면 저장하지 못한다).
final qoinBrandBulkStatsProvider = Provider.autoDispose
    .family<AsyncValue<QoinBulkStats>, String>((ref, brandId) {
      final stores = ref.watch(qoinAdminStoresProvider);
      return stores.whenData((all) {
        var total = 0;
        var overridden = 0;
        var stopped = 0;
        for (final s in all) {
          if (s.brandId != brandId) continue;
          total++;
          if (!s.qoinAccrualRate.isAbsent) overridden++;
          if (s.qoinAccrualRate.isZero) stopped++;
        }
        return QoinBulkStats(
          total: total,
          overridden: overridden,
          overriddenStopped: stopped,
        );
      });
    });

/// 전역 확인 다이얼로그의 `이 값을 따르는 매장 N곳`. 3소스가 모두 준비됐을 때만 계산한다 (아니면 null → 줄 생략).
final qoinGlobalFollowingStoresProvider = Provider.autoDispose<int?>((ref) {
  final stores = ref.watch(qoinAdminStoresProvider).asData?.value;
  final brands = ref.watch(qoinAdminBrandsProvider).asData?.value;
  if (stores == null || brands == null) return null;
  final byId = {for (final b in brands) b.id: b};
  var n = 0;
  for (final s in stores) {
    final bid = s.brandId;
    final hasBrand = bid != null && bid.isNotEmpty;
    // 이 매장이 전역 값에 도달하는가: 매장·브랜드 단계가 모두 부재.
    final brandAbsent =
        !hasBrand || (byId[bid]?.qoinAccrualRate.isAbsent ?? true);
    if (s.qoinAccrualRate.isAbsent && brandAbsent) n++;
  }
  return n;
});

/// 대상 단건 (편집 화면). null = 없음.
final qoinAdminStoreByIdProvider = Provider.autoDispose
    .family<AsyncValue<StoreEntity?>, String>((ref, id) {
      return ref
          .watch(qoinAdminStoresProvider)
          .whenData((all) => all.where((s) => s.id == id).firstOrNull);
    });

final qoinAdminBrandByIdProvider = Provider.autoDispose
    .family<AsyncValue<BrandEntity?>, String>((ref, id) {
      return ref
          .watch(qoinAdminBrandsProvider)
          .whenData((all) => all.where((b) => b.id == id).firstOrNull);
    });

/// 한 매장의 해석(편집 화면용): 매장 원본 + 브랜드 + 전역 3소스 준비 후에만 data.
final qoinAdminStoreEffectiveProvider = Provider.autoDispose
    .family<AsyncValue<EffectiveQoinRate>, String>((ref, storeId) {
      final store = ref.watch(qoinAdminStoreByIdProvider(storeId));
      final s = store.asData?.value;
      if (store.hasError && !store.hasValue) {
        return AsyncValue.error(store.error!, store.stackTrace ?? StackTrace.current);
      }
      if (s == null) return const AsyncValue.loading();
      return ref.watch(
        effectiveStoreQoinRateProvider((
          store: s.qoinAccrualRate,
          brandId: s.brandId,
        )),
      );
    });

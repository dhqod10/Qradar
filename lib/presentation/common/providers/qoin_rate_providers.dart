import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/qoin_config_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/brand/providers/brand_info_providers.dart';
import 'package:qradar/presentation/common/providers/qoin_config_providers.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';
import 'package:qradar/presentation/common/providers/qoin_di_providers.dart';

// ── 변경 이력 ────────────────────────────────────────────────────────────────

typedef QoinHistoryKey = ({QoinRateScope scope, String targetId, int limit});

/// 한 대상의 변경 이력 (최신순). 점주·브랜드·admin 공용.
final qoinRateHistoryProvider = StreamProvider.autoDispose
    .family<List<QoinRateChangeEntity>, QoinHistoryKey>((ref, key) {
      return ref.watch(watchQoinRateHistoryUseCaseProvider)(
        key.scope,
        key.targetId,
        limit: key.limit,
      );
    });

/// 전체 변경 이력 (admin, collectionGroup). [limit] 을 키워 "더 보기" 를 구현한다.
final qoinAllRateHistoryProvider = StreamProvider.autoDispose
    .family<List<QoinRateChangeEntity>, int>((ref, limit) {
      return ref.watch(watchAllQoinRateHistoryUseCaseProvider)(limit: limit);
    });

// ── 유효 적립률 (계층 해석) ───────────────────────────────────────────────────

/// 대상·브랜드·전역 **3소스가 모두 준비되기 전에는 값을 내지 않는다.**
/// 일부만 준비된 "임시 해석" 은 상속 값을 조용히 틀리게 만든다 (design §14-7).
AsyncValue<EffectiveQoinRate> _combine(
  Ref ref, {
  required QoinRateSetting store,
  required String? brandId,
  required bool storeScope,
}) {
  final cfg = ref.watch(qoinConfigProvider);
  final hasBrand = brandId != null && brandId.isNotEmpty;
  final brand = hasBrand ? ref.watch(brandByIdProvider(brandId)) : null;

  for (final a in <AsyncValue<Object?>?>[cfg, brand]) {
    if (a == null) continue;
    if (!a.hasValue) {
      return a.hasError
          ? AsyncValue.error(a.error!, a.stackTrace ?? StackTrace.current)
          : const AsyncValue.loading();
    }
  }
  final global = cfg.value?.accrualRateSetting ?? QoinRateSetting.absent;
  final brandSetting = brand?.value?.qoinAccrualRate ?? QoinRateSetting.absent;
  return AsyncValue.data(
    resolveEffectiveQoinRate(
      store: storeScope ? store : QoinRateSetting.absent,
      brand: brandSetting,
      global: global,
      hasBrand: hasBrand,
    ),
  );
}

typedef QoinStoreRateKey = ({QoinRateSetting store, String? brandId});

/// 한 매장의 유효 적립률. 점주 읽기 행 / 매장 편집 화면이 쓴다.
final effectiveStoreQoinRateProvider = Provider.autoDispose
    .family<AsyncValue<EffectiveQoinRate>, QoinStoreRateKey>((ref, key) {
      return _combine(
        ref,
        store: key.store,
        brandId: key.brandId,
        storeScope: true,
      );
    });

/// 한 브랜드의 유효 적립률 (브랜드 값 → 전역). 브랜드 읽기 행 / 브랜드 편집 화면이 쓴다.
/// 인자는 **브랜드 id** 다 — 브랜드 설정 원본은 이 provider 가 브랜드 스트림에서 직접 읽는다.
final effectiveBrandQoinRateProvider = Provider.autoDispose
    .family<AsyncValue<EffectiveQoinRate>, String>((ref, brandId) {
      return _combine(
        ref,
        store: QoinRateSetting.absent,
        brandId: brandId,
        storeScope: false,
      );
    });

/// 목록용 동기 해석: 매장 목록 + 브랜드 맵 + 전역을 **목록 단위로 한 번** 받아 풀어낸다
/// (타일마다 스트림을 만들지 않는다). 3소스가 모두 준비된 뒤에만 호출한다.
EffectiveQoinRate resolveStoreQoinRate(
  StoreEntity store,
  Map<String, BrandEntity> brandsById,
  QoinConfigEntity? config,
) {
  final brandId = store.brandId;
  final hasBrand = brandId != null && brandId.isNotEmpty;
  return resolveEffectiveQoinRate(
    store: store.qoinAccrualRate,
    brand: hasBrand
        ? (brandsById[brandId]?.qoinAccrualRate ?? QoinRateSetting.absent)
        : QoinRateSetting.absent,
    global: config?.accrualRateSetting ?? QoinRateSetting.absent,
    hasBrand: hasBrand,
  );
}

/// 브랜드 목록용 해석 (브랜드 값 → 전역).
EffectiveQoinRate resolveBrandQoinRate(
  BrandEntity brand,
  QoinConfigEntity? config,
) {
  return resolveEffectiveQoinRate(
    store: QoinRateSetting.absent,
    brand: brand.qoinAccrualRate,
    global: config?.accrualRateSetting ?? QoinRateSetting.absent,
  );
}

// ── 변경자 표시명 ────────────────────────────────────────────────────────────

/// 이력 행의 변경자 이름 (admin 이 볼 때만 사용). 조회 실패·미존재면 null → 호출자가 `관리자 {uid 끝4}` 로 폴백한다.
/// users 문서 읽기가 행마다 늘어나지만 family 로 uid 당 1구독이고, admin 만 쓴다.
final qoinChangerNameProvider = StreamProvider.autoDispose
    .family<String?, String>((ref, uid) {
      return ref
          .watch(watchUserProfileUseCaseProvider)(uid)
          .map((u) => u?.displayName)
          .handleError((_) {});
    });

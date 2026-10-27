import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/brand_private_profile_entity.dart';
import 'package:qradar/domain/usecases/approve_brand_use_case.dart';
import 'package:qradar/domain/usecases/claim_submitted_brand_use_case.dart';
import 'package:qradar/domain/usecases/fetch_brand_private_profile_use_case.dart';
import 'package:qradar/domain/usecases/fetch_my_submitted_brands_use_case.dart';
import 'package:qradar/domain/usecases/reject_brand_use_case.dart';
import 'package:qradar/domain/usecases/upsert_brand_use_case.dart';
import 'package:qradar/domain/usecases/watch_brand_by_id_use_case.dart';
import 'package:qradar/domain/usecases/watch_brand_private_profile_use_case.dart';
import 'package:qradar/presentation/brand/providers/brand_di_providers.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';

// ── UseCase Provider ───────────────────────────────────────────────────────

final watchBrandByIdUseCaseProvider = Provider<WatchBrandByIdUseCase>((ref) {
  return WatchBrandByIdUseCase(ref.watch(brandRepositoryProvider));
});

final upsertBrandUseCaseProvider = Provider<UpsertBrandUseCase>((ref) {
  return UpsertBrandUseCase(ref.watch(brandRepositoryProvider));
});

final approveBrandUseCaseProvider = Provider<ApproveBrandUseCase>((ref) {
  return ApproveBrandUseCase(ref.watch(brandRepositoryProvider));
});

final rejectBrandUseCaseProvider = Provider<RejectBrandUseCase>((ref) {
  return RejectBrandUseCase(ref.watch(brandRepositoryProvider));
});

final fetchMySubmittedBrandsUseCaseProvider =
    Provider<FetchMySubmittedBrandsUseCase>((ref) {
      return FetchMySubmittedBrandsUseCase(ref.watch(brandRepositoryProvider));
    });

final claimSubmittedBrandUseCaseProvider = Provider<ClaimSubmittedBrandUseCase>(
  (ref) {
    return ClaimSubmittedBrandUseCase(ref.watch(brandRepositoryProvider));
  },
);

final watchBrandPrivateProfileUseCaseProvider =
    Provider<WatchBrandPrivateProfileUseCase>((ref) {
      return WatchBrandPrivateProfileUseCase(
        ref.watch(brandRepositoryProvider),
      );
    });

final fetchBrandPrivateProfileUseCaseProvider =
    Provider<FetchBrandPrivateProfileUseCase>((ref) {
      return FetchBrandPrivateProfileUseCase(
        ref.watch(brandRepositoryProvider),
      );
    });

// ── Stream Provider ────────────────────────────────────────────────────────

/// 현재 brand 사용자 본인의 브랜드 스트림.
final myBrandProvider = StreamProvider<BrandEntity?>((ref) {
  final profile = ref.watch(currentUserProfileProvider).asData?.value;
  final brandId = profile?.brandId;
  if (brandId == null || brandId.isEmpty) return Stream.value(null);
  return ref.read(watchBrandByIdUseCaseProvider).call(brandId);
});

/// 임의 brandId 로 브랜드 단건 조회 — Owner 모듈의 brandId 분기에서 사용.
///
/// 로딩 중에는 null, 존재하지 않으면 null 을 반환한다.
final brandByIdProvider = StreamProvider.family<BrandEntity?, String>((
  ref,
  brandId,
) {
  if (brandId.isEmpty) return Stream.value(null);
  return ref.read(watchBrandByIdUseCaseProvider).call(brandId);
});

/// 자동 재시도 없음. Riverpod 3 기본값(10회·약 38초)은 그동안 사용자에게 정상 로딩(스켈레톤)만 보여 주어
/// "읽기 실패" 상태가 38초 뒤에야 나타난다. 이 읽기들은 실패를 즉시 확정하고 `다시 시도` 버튼이 복구를 맡는다.
Duration? readNoAutoRetry(int retryCount, Object error) => null;

/// 브랜드 비공개 프로필(brandKey + PII) 실시간 감시 — brandKey 행 · admin 승인 상세용.
///
/// 문서 없음 = `data(null)`, **읽기 실패 = `error`** (둘을 같은 화면 상태로 뭉개지 않는다).
/// 재시도는 `ref.invalidate` — autoDispose 라 다시 구독하며 `loading` 으로 돌아간다.
final brandPrivateProfileProvider = StreamProvider.autoDispose
    .family<BrandPrivateProfileEntity?, String>((ref, brandId) {
      if (brandId.isEmpty) return Stream.value(null);
      return ref.read(watchBrandPrivateProfileUseCaseProvider).call(brandId);
    }, retry: readNoAutoRetry);

/// 브랜드 수정 폼 초기값용 단발성 조회. 읽기 실패는 `error` (빈 폼으로 폴백하지 않는다).
final brandPrivateProfileFetchProvider = FutureProvider.autoDispose
    .family<BrandPrivateProfileEntity?, String>((ref, brandId) {
      return ref.read(fetchBrandPrivateProfileUseCaseProvider).call(brandId);
    }, retry: readNoAutoRetry);

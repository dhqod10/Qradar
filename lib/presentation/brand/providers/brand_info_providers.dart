import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/usecases/approve_brand_use_case.dart';
import 'package:qradar/domain/usecases/reject_brand_use_case.dart';
import 'package:qradar/domain/usecases/upsert_brand_use_case.dart';
import 'package:qradar/domain/usecases/watch_brand_by_id_use_case.dart';
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
final brandByIdProvider =
    StreamProvider.family<BrandEntity?, String>((ref, brandId) {
  if (brandId.isEmpty) return Stream.value(null);
  return ref.read(watchBrandByIdUseCaseProvider).call(brandId);
});

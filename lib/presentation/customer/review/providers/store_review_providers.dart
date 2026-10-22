import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/entities/review_entity.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/home/providers/home_providers.dart';
import 'package:qradar/presentation/customer/review/providers/review_di_providers.dart';

/// 매장 평가 목록 stream (최신순, 상한 50). 고객/점주 공용.
final storeReviewsProvider = StreamProvider.autoDispose
    .family<List<ReviewEntity>, String>((ref, storeId) {
      return ref.watch(getStoreReviewsUseCaseProvider)(storeId);
    });

/// 내가 이 매장에 남긴 평가. 비로그인이면 null.
final myStoreReviewProvider = StreamProvider.autoDispose
    .family<ReviewEntity?, String>((ref, storeId) {
      final uid = ref.watch(authProvider).asData?.value?.uid;
      if (uid == null) return Stream.value(null);
      return ref.watch(getMyStoreReviewUseCaseProvider)(
        storeId: storeId,
        userId: uid,
      );
    });

/// 매장 단건 실시간 구독.
///
/// 평가 작성 후 `onReviewWritten` CF 가 `stores.averageScore` / `reviewCount` 를
/// 갱신하는데, 진입 시점 스냅샷만 들고 있으면 화면이 계속 `미평가` 로 남는다.
/// 기능은 정상인데 사용자는 "반영이 안 됐다" 고 믿게 되므로 구독으로 받는다.
final watchedStoreProvider = StreamProvider.autoDispose
    .family<StoreEntity?, String>((ref, storeId) {
      return ref.watch(storeRepositoryProvider).watchById(storeId);
    });

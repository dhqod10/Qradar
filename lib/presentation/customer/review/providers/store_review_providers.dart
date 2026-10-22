import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/entities/review_entity.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
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

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/customer/review/widgets/store_reviews_view.dart';
import 'package:qradar/presentation/owner/providers/owner_providers.dart';

/// 점주용 받은 평가 목록 (읽기 전용). 답글/신고/삭제 UI 없음 (2차).
///
/// 평균 점수는 점주 화면에만 노출한다 (`showAverage: true`).
class OwnerStoreReviewsPage extends ConsumerWidget {
  const OwnerStoreReviewsPage({super.key, required this.store});

  /// 진입 시점 스냅샷. 라이브 값([myStoreProvider])이 있으면 그쪽을 쓴다.
  final StoreEntity store;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(myStoreProvider).asData?.value;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          '받은 평가',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textHeading),
      ),
      body: StoreReviewsView(
        store: (live != null && live.id == store.id) ? live : store,
        showMine: false,
        showAverage: true,
        emptyTitle: '아직 받은 평가가 없어요',
        emptyDescription: '손님이 주문을 완료하고 평가를 남기면 여기에 표시돼요',
      ),
    );
  }
}

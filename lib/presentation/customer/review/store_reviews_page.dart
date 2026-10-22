import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/customer/review/widgets/store_reviews_view.dart';

/// 고객용 매장 평가 목록. 진입: 매장 메뉴 헤더의 `GradeBadge` 탭.
class StoreReviewsPage extends StatelessWidget {
  const StoreReviewsPage({super.key, required this.store});

  final StoreEntity store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          '매장 평가',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textHeading),
      ),
      body: StoreReviewsView(
        store: store,
        emptyTitle: '아직 평가가 없어요',
        emptyDescription: '주문을 완료한 뒤 Log 에서 이 매장을 평가할 수 있어요',
      ),
    );
  }
}

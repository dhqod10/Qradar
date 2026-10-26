import 'package:flutter/material.dart';
import 'package:qradar/core/constants/grade_thresholds.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:shimmer/shimmer.dart';

/// 메뉴 섹션 헤더 (건수 없음 — 로딩·에러·1글자). 로딩이면 인디케이터 + 문구.
class MenuSectionHeader extends StatelessWidget {
  const MenuSectionHeader({super.key, this.title = '메뉴', this.loading = false});

  final String title;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        header: true,
        liveRegion: loading,
        label: loading ? '메뉴를 찾고 있어요' : title,
        child: Row(
          children: [
            ExcludeSemantics(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHeading,
                ),
              ),
            ),
            if (loading) ...[
              const SizedBox(width: 10),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 6),
              const ExcludeSemantics(
                child: Text(
                  '메뉴를 찾고 있어요',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 메뉴 skeleton 2행 (72h).
class MenuSkeleton extends StatelessWidget {
  const MenuSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        2,
        (i) => Padding(
          padding: EdgeInsets.only(bottom: i == 1 ? 0 : 10),
          child: Shimmer.fromColors(
            baseColor: AppColors.surface,
            highlightColor: AppColors.surfaceElevated,
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 한 줄 안내 (`'{질의}' 와 일치하는 매장이 없어요` 등).
class SearchOneLiner extends StatelessWidget {
  const SearchOneLiner(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

/// 1글자 질의의 메뉴 자리 안내 plate.
class MenuMinLengthPlate extends StatelessWidget {
  const MenuMinLengthPlate({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.textMuted,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '메뉴는 두 글자부터 찾아요',
              style: TextStyle(fontSize: 13, color: AppColors.textBody),
            ),
          ),
        ],
      ),
    );
  }
}

/// 메뉴 전체 에러 인라인 카드 — 매장 섹션은 가리지 않는다.
class MenuErrorCard extends StatelessWidget {
  const MenuErrorCard({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, size: 20, color: AppColors.error),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '메뉴를 불러오지 못했어요',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHeading,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '매장 검색 결과는 그대로 볼 수 있어요',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              foregroundColor: AppColors.textBody,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}

/// 부분 실패 줄 — 결과 행은 유지, 재시도 중에는 버튼 자리에 인디케이터.
class MenuPartialFailureRow extends StatelessWidget {
  const MenuPartialFailureRow({
    super.key,
    required this.onRetry,
    this.retrying = false,
  });

  final VoidCallback onRetry;
  final bool retrying;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Semantics(
        label: '일부 매장의 메뉴를 불러오지 못했어요. 다시 시도 버튼이 있어요',
        child: Row(
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: ExcludeSemantics(
                child: Text(
                  '일부 매장의 메뉴를 불러오지 못했어요',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textBody,
                  ),
                ),
              ),
            ),
            if (retrying)
              const SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              )
            else
              InkWell(
                onTap: onRetry,
                child: const SizedBox(
                  height: 44,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '다시 시도',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.info,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 섹션 하단 고정 범위 안내 (F2-5). 로딩·에러에서는 그리지 않는다.
class MenuScopeNotice extends StatelessWidget {
  const MenuScopeNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '가까운 매장 ${GradeThresholds.menuSearchStoreLimit}곳의 메뉴에서 찾았어요',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          Text(
            '가격과 판매 여부는 매장 화면에서 확인해 주세요',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// 통합 빈 상태 — 메뉴가 확정(데이터 0 또는 부분 실패)일 때만 호출 측이 그린다.
class SearchUnifiedEmpty extends StatelessWidget {
  const SearchUnifiedEmpty({super.key, required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final echo = query.length > 20 ? '${query.substring(0, 20)}…' : query;
    return Semantics(
      label: '$echo와 일치하는 매장이나 메뉴가 없어요',
      child: Padding(
        padding: const EdgeInsets.only(top: 64),
        child: Column(
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              "'$echo' 와 일치하는 매장이나 메뉴가 없어요",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textHeading,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '매장 이름·주소와 가까운 매장 ${GradeThresholds.menuSearchStoreLimit}곳의 메뉴에서 찾았어요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const Text(
              '다른 검색어로 찾아보세요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

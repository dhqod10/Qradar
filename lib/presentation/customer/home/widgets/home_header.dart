import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/common/q_logo.dart';
import 'package:qradar/presentation/common/scaffold_with_nav.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';

/// 홈 헤더의 세 가지 상태:
/// - [full]: 홈 탭 + 스크롤 최상단. 브랜드·인삿말·서치박스 모두 노출
/// - [scrolled]: 홈 탭 + 스크롤 내려감. QLogo 하나만 남음
/// - [tabbed]: 다른 탭 진입. 홈 아이콘 노출
enum HomeHeaderMode { full, scrolled, tabbed }

/// 홈 상단 미드나잇 블록. 흰 캔버스 위에 좌하단 큰 라운드로 떠 있는 형태.
class HomeHeader extends ConsumerWidget {
  final HomeHeaderMode mode;
  const HomeHeader({super.key, this.mode = HomeHeaderMode.full});

  bool get _isCompact => mode != HomeHeaderMode.full;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final authState = ref.watch(authProvider);
    final name = authState.maybeWhen(
      data: (user) {
        if (user == null) return 'Qrator';
        if ((user.displayName ?? '').isNotEmpty) return user.displayName!;
        final email = user.email ?? '';
        if (email.contains('@')) return email.split('@').first;
        return 'Qrator';
      },
      orElse: () => 'Qrator',
    );

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDeep],
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(50)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SafeArea(
            bottom: false,
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 280),
              sizeCurve: Curves.easeInOut,
              firstCurve: Curves.easeOut,
              secondCurve: Curves.easeIn,
              alignment: Alignment.topCenter,
              crossFadeState: _isCompact
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: Padding(
                padding: const EdgeInsets.fromLTRB(20, 15, 20, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -15),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const QLogo(size: 30, color: AppColors.onPrimary),
                          Transform.translate(
                            offset: const Offset(0, 5),
                            child: const Text(
                              'uality Grader Radar',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onPrimary,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Transform.translate(
                      offset: const Offset(4, -15),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.onPrimary.withValues(alpha: 0.85),
                          ),
                          children: [
                            TextSpan(
                              text: name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onPrimary,
                              ),
                            ),
                            const TextSpan(text: '님 어서오세요.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              secondChild: const SizedBox(width: double.infinity, height: 56),
            ),
          ),
          Positioned(
            left: 40,
            right: 40,
            bottom: -23,
            child: IgnorePointer(
              ignoring: mode != HomeHeaderMode.full,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                opacity: mode == HomeHeaderMode.full ? 1 : 0,
                child: _HomeSearchBox(
                  onTap: () => _showSearchComingSoon(context),
                ),
              ),
            ),
          ),
          Positioned(
            top: statusBarHeight,
            left: 20,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: mode == HomeHeaderMode.scrolled ? 1 : 0,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const QLogo(size: 30, color: AppColors.onPrimary),
                    Transform.translate(
                      offset: const Offset(0, 5),
                      child: const Text(
                        'uality Grader Radar',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onPrimary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: statusBarHeight - 10,
            left: 4,
            child: IgnorePointer(
              ignoring: mode != HomeHeaderMode.tabbed,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: mode == HomeHeaderMode.tabbed ? 1 : 0,
                child: IconButton(
                  onPressed: () =>
                      ref.read(selectedTabIndexProvider.notifier).set(0),
                  icon: const Icon(
                    Icons.home_rounded,
                    color: AppColors.onPrimary,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: statusBarHeight - 10,
            right: 4,
            child: IconButton(
              onPressed: () =>
                  ref.read(selectedTabIndexProvider.notifier).set(4),
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: AppColors.onPrimary,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSearchComingSoon(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('검색 준비 중입니다')));
  }
}

class _HomeSearchBox extends StatelessWidget {
  final VoidCallback onTap;
  const _HomeSearchBox({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
            SizedBox(width: 10),
            Text(
              '매장이나 메뉴 검색',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

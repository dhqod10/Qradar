import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/price_formatter.dart';
import 'package:qradar/core/utils/relative_time_formatter.dart';
import 'package:qradar/domain/entities/cart_item_entity.dart';
import 'package:qradar/domain/entities/quick_reorder_candidate_entity.dart';
import 'package:qradar/presentation/customer/cart/cart_page.dart';
import 'package:qradar/presentation/customer/cart/providers/cart_providers.dart';
import 'package:qradar/presentation/customer/cart/widgets/replace_cart_dialog.dart';
import 'package:qradar/presentation/customer/home/providers/recommendation_providers.dart';
import 'package:qradar/presentation/customer/home/widgets/section_title.dart';
import 'package:shimmer/shimmer.dart';
import 'package:uuid/uuid.dart';

const double _kCardWidth = 240;
const double _kCardHeight = 196;

/// "다시 주문하기" 섹션 — 가장 최근 OrderLog 1~3건 가로 스크롤.
///
/// 비로그인 / data empty / error → 위/아래 spacer 포함 전체 hide.
class QuickReorderSection extends ConsumerWidget {
  const QuickReorderSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = ref.watch(quickReorderCandidatesProvider);

    final child = candidates.when(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return _ContentColumn(candidates: list);
      },
      loading: () => const _LoadingColumn(),
      error: (e, _) {
        if (kDebugMode) {
          debugPrint('[QuickReorder] stream error: $e');
        }
        return const SizedBox.shrink();
      },
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      child: child,
    );
  }
}

class _ContentColumn extends StatelessWidget {
  final List<QuickReorderCandidateEntity> candidates;
  const _ContentColumn({required this.candidates});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('quick-reorder-content'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: '다시 주문하기'),
        SizedBox(
          height: _kCardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemCount: candidates.length,
            itemBuilder: (_, i) =>
                QuickReorderCard(candidate: candidates[i]),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _LoadingColumn extends StatelessWidget {
  const _LoadingColumn();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('quick-reorder-loading'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: '다시 주문하기'),
        SizedBox(
          height: _kCardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemCount: 2,
            itemBuilder: (_, _) => Shimmer.fromColors(
              baseColor: AppColors.surface,
              highlightColor: AppColors.surfaceElevated,
              child: Container(
                width: _kCardWidth,
                height: _kCardHeight,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class QuickReorderCard extends ConsumerStatefulWidget {
  final QuickReorderCandidateEntity candidate;
  const QuickReorderCard({super.key, required this.candidate});

  @override
  ConsumerState<QuickReorderCard> createState() => _QuickReorderCardState();
}

class _QuickReorderCardState extends ConsumerState<QuickReorderCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.candidate;
    final relative =
        RelativeTimeFormatter.formatKo(DateTime.now(), c.paidAt);

    return GestureDetector(
      onTap: _busy ? null : _onTap,
      child: Container(
        width: _kCardWidth,
        height: _kCardHeight,
        decoration: _cardDecoration(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    c.storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHeading,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              relative,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: 8),
            Text(
              c.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textBody,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              PriceFormatter.formatKrw(c.total),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const Spacer(),
            const Align(
              alignment: Alignment.centerRight,
              child: IgnorePointer(child: _RestartPill()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onTap() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final activeCart = ref.read(cartProvider).value;
      if (activeCart != null &&
          activeCart.storeId != widget.candidate.storeId) {
        final ok = await showReplaceCartDialog(context);
        if (!mounted) return;
        if (!ok) {
          setState(() => _busy = false);
          return;
        }
      }
      // 카트 비우고 OrderLog items 그대로 채워 넣기.
      await ref.read(clearCartUseCaseProvider).call();
      final addUseCase = ref.read(addToCartUseCaseProvider);
      const uuid = Uuid();
      for (final item in widget.candidate.sourceLog.items) {
        final unitPriceWithOptions = _unitPriceFromLineTotal(
          lineTotal: item.lineTotal,
          quantity: item.quantity,
        );
        await addUseCase.call(
          storeId: widget.candidate.storeId,
          storeName: widget.candidate.storeName,
          item: CartItemEntity(
            cartItemId: uuid.v4(),
            menuItemId: item.menuItemId,
            menuItemName: item.menuItemName,
            quantity: item.quantity,
            selectedOptions: item.optionsSnapshot,
            unitPriceWithOptions: unitPriceWithOptions,
            lineTotal: item.lineTotal,
          ),
        );
      }
      if (!mounted) return;
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const CartPage()),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('다시 주문에 실패했어요. 잠시 후 다시 시도해주세요'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static int _unitPriceFromLineTotal({
    required int lineTotal,
    required int quantity,
  }) {
    if (quantity <= 0) return 0;
    return lineTotal ~/ quantity;
  }
}

class _RestartPill extends StatelessWidget {
  const _RestartPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.refresh_rounded,
            size: 14,
            color: AppColors.primary,
          ),
          SizedBox(width: 4),
          Text(
            '다시 주문',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: AppColors.surfaceElevated,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.border, width: 1),
    boxShadow: [
      BoxShadow(
        color: AppColors.primary.withValues(alpha: 0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

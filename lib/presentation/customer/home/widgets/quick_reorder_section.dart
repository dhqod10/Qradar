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
import 'package:qradar/presentation/customer/cart/providers/checkout_validation_providers.dart';
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
            itemBuilder: (_, i) => QuickReorderCard(candidate: candidates[i]),
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
    final relative = RelativeTimeFormatter.formatKo(DateTime.now(), c.paidAt);

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
      // 선검증 — 카트 비우기보다 **앞**에 둔다 (전부 위반이면 기존 카트를 날리지 않도록, design §4.5).
      // 확인 실패/타임아웃은 UseCase 가 "위반 없음"으로 돌려주므로 기존 동작대로 진행한다 (서버 게이트에 맡긴다).
      final sourceItems = widget.candidate.sourceLog.items;
      final validation = await ref
          .read(validateCheckoutUseCaseProvider)
          .call(
            storeId: widget.candidate.storeId,
            menuItemIds: sourceItems.map((i) => i.menuItemId),
          );
      if (!mounted) return;
      final violated = validation.violatedMenuItemIds;
      if (validation.store != null) {
        await _showNotice(
          title: '지금은 이 매장에서 주문할 수 없어요',
          message: '잠시 후 다시 시도해 주세요.',
        );
        return;
      }
      var itemsToAdd = sourceItems;
      if (violated.isNotEmpty) {
        // 이름은 과거 주문 스냅샷 (고객이 시켰던 이름이므로 알아본다). 메뉴 종류당 1번.
        final names = <String>[];
        final seen = <String>{};
        for (final i in sourceItems) {
          if (violated.contains(i.menuItemId) && seen.add(i.menuItemId)) {
            names.add(i.menuItemName);
          }
        }
        itemsToAdd = sourceItems
            .where((i) => !violated.contains(i.menuItemId))
            .toList(growable: false);
        if (itemsToAdd.isEmpty) {
          await _showNotice(
            title: '지금은 주문할 수 있는 메뉴가 없어요',
            message: '${_bulletLines(names)}\n\n모두 품절이거나 판매가 중단됐어요.',
          );
          return;
        }
        final proceed = await _confirmPartial(names);
        if (!mounted) return;
        if (!proceed) return;
      }
      // 카트 비우고 OrderLog items 채워 넣기 (위반 메뉴는 제외).
      await ref.read(clearCartUseCaseProvider).call();
      final addUseCase = ref.read(addToCartUseCaseProvider);
      const uuid = Uuid();
      for (final item in itemsToAdd) {
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
      navigator.push(MaterialPageRoute<void>(builder: (_) => const CartPage()));
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

  static String _bulletLines(List<String> names) =>
      names.map((n) => '• $n').join('\n');

  /// `cart_page.dart` 의 `_confirmClear` 와 같은 스타일 (surfaceElevated · 반경 16).
  Future<void> _showNotice({required String title, required String message}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textBody,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              '확인',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 일부 메뉴만 위반일 때 — 이름을 전부 열거하고 나머지만 담을지 묻는다 (design §4.5).
  Future<bool> _confirmPartial(List<String> names) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        title: const Text(
          '일부 메뉴는 지금 담을 수 없어요',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            '${_bulletLines(names)}\n\n나머지 메뉴만 담을까요?',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textBody,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              '취소',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              '나머지 담기',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
    return ok == true;
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
          Icon(Icons.refresh_rounded, size: 14, color: AppColors.primary),
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

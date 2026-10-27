import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/price_formatter.dart';
import 'package:qradar/domain/entities/cart_entity.dart';
import 'package:qradar/domain/entities/checkout_validation.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/auth/login_page.dart';
import 'package:qradar/presentation/customer/cart/cart_line_availability.dart';
import 'package:qradar/presentation/customer/cart/providers/cart_providers.dart';
import 'package:qradar/presentation/customer/cart/providers/checkout_validation_providers.dart';
import 'package:qradar/presentation/customer/cart/widgets/cart_availability_banner.dart';
import 'package:qradar/presentation/customer/cart/widgets/cart_line_tile.dart';
import 'package:qradar/presentation/customer/cart/widgets/cart_price_change_banner.dart';
import 'package:qradar/presentation/customer/checkout/checkout_page.dart';
import 'package:qradar/presentation/customer/order/menu/menu_item_detail_page.dart';

class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage>
    with WidgetsBindingObserver {
  final ScrollController _scroll = ScrollController();
  // cartItemId → 행 위치 (첫 위반 행으로 스크롤하기 위해).
  final Map<String, GlobalKey> _lineKeys = {};
  bool _checkingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 자동 선검증 ① 카트 진입 1회. 스트림 변화마다 호출하지 않는다 (읽기 폭증).
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoValidate());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 자동 선검증 ② 앱 포그라운드 복귀.
    if (state == AppLifecycleState.resumed) _autoValidate();
  }

  /// 자동 선검증 — 실패는 무음이다 (design N3). UseCase 가 실패를 "위반 없음"으로 돌려준다.
  Future<void> _autoValidate() async {
    try {
      await ref.read(cartProvider.future);
      if (!mounted) return;
      await ref.read(cartValidationProvider.notifier).refresh();
    } catch (_) {
      // 무음.
    }
  }

  /// `다시 확인` — 사용자가 직접 누른 확인이므로 실패하면 정직하게 알린다 (design N3).
  Future<void> _recheck() async {
    try {
      await ref
          .read(cartValidationProvider.notifier)
          .refresh(reportFailure: true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('확인하지 못했어요. 잠시 후 다시 눌러 주세요'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// 현재 카트에 대한 유효한 선검증 결과 (다른 매장 카트였던 결과는 버린다).
  CheckoutValidation _validationFor(CartEntity cart) {
    final st = ref.watch(cartValidationProvider);
    return st.storeId == cart.storeId ? st.validation : CheckoutValidation.none;
  }

  List<CartLineAvailability> _availabilities(
    CartEntity cart,
    CheckoutValidation validation,
    Set<String> rejected,
  ) => [
    for (final line in cart.items)
      resolveCartLineAvailability(
        menuItemId: line.menuItemId,
        cartItemId: line.cartItemId,
        validation: validation,
        rejectedMenuItemIds: rejected,
      ),
  ];

  /// `다시 고르기` (design §5.5) — 라인은 어차피 결제할 수 없는 상태였으므로 빼고 메뉴 상세에서 다시 담게 한다.
  Future<void> _reselectOptions(CartEntity cart, String cartItemId) async {
    final line = cart.items.where((l) => l.cartItemId == cartItemId).firstOrNull;
    if (line == null) return;
    await ref.read(removeCartItemUseCaseProvider).call(cartItemId);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MenuItemDetailPage(
          storeId: cart.storeId,
          storeName: cart.storeName,
          menuItemId: line.menuItemId,
        ),
      ),
    );
  }

  Future<void> _onCheckout(CartEntity cart) async {
    if (_checkingOut) return;
    // F1: Firebase Auth 세션 직접 확인 (세션 만료 / 강제 로그아웃 /
    // 계정 삭제 등 비정상 상태 방어)
    final authUser = ref.read(authProvider).asData?.value;
    if (authUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인 후 이용해주세요.'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
      return;
    }
    // 자동 선검증 ③ `결제하기` 탭 (체크아웃 진입 검증). 위반이 있을 때만 막고,
    // 확인 실패/통과는 기존대로 체크아웃으로 간다 (spec §8.2).
    setState(() => _checkingOut = true);
    CartRefreshResult result;
    try {
      result = await ref
          .read(cartValidationProvider.notifier)
          .refreshAndReprice();
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
    if (!mounted) return;
    if (result.validation.hasViolations) {
      _scrollToFirstViolation();
      return;
    }
    // 가격이 새로 바뀌었으면 체크아웃으로 가지 않고 카트에서 한 번 멈춘다 (design §5.3). 금액이 바뀐 채로 결제 화면에
    // 들어가면 "내가 본 금액" 과 다른 금액을 결제하게 된다. 한 번 더 탭하는 것이 동의다 — 그 탭은 다음 신선 선검증도 겸한다.
    if (result.applied.hasChanges) {
      _scrollToFirstPriceChange(result.applied.changes.first.cartItemId);
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CheckoutPage()));
  }

  void _scrollToFirstPriceChange(String cartItemId) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ctx = _lineKeys[cartItemId]?.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToFirstViolation() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final cart = ref.read(cartProvider).value;
      if (cart == null) return;
      final validation = _validationFor(cart);
      final rejected = ref.read(paymentRejectedMenuIdsProvider);
      final avail = _availabilities(cart, validation, rejected);
      var index = avail.indexWhere(
        (a) =>
            a == CartLineAvailability.soldOut ||
            a == CartLineAvailability.unavailable,
      );
      if (index < 0) {
        index = avail.indexWhere((a) => a != CartLineAvailability.normal);
      }
      if (index < 0 || !_scroll.hasClients) {
        if (_scroll.hasClients) {
          await _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
        return;
      }
      final key = _lineKeys[cart.items[index].cartItemId];
      final ctx = key?.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider).value;
    final hasItems = cart != null && cart.items.isNotEmpty;
    final rejected = ref.watch(paymentRejectedMenuIdsProvider);
    final optionRejected = ref.watch(paymentOptionRejectedMenuIdsProvider);
    final priceChanges = ref.watch(cartPriceChangesProvider);
    final priceSummary = summarizePriceChanges(cart, priceChanges);
    final validation = hasItems
        ? _validationFor(cart)
        : CheckoutValidation.none;
    final availabilities = hasItems
        ? _availabilities(cart, validation, rejected)
        : const <CartLineAvailability>[];
    final blockedCount = hasItems
        ? {
            for (var i = 0; i < cart.items.length; i++)
              if (availabilities[i] == CartLineAvailability.soldOut ||
                  availabilities[i] == CartLineAvailability.unavailable ||
                  availabilities[i] == CartLineAvailability.optionUnavailable)
                cart.items[i].menuItemId,
          }.length
        : 0;
    final banner = hasItems
        ? resolveCartBannerVariant(
            lines: availabilities,
            validation: validation,
          )
        : null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AppColors.textHeading,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          '장바구니',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        centerTitle: false,
        actions: [
          if (hasItems)
            TextButton(
              onPressed: () => _confirmClear(context),
              child: const Text(
                '비우기',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: hasItems
            ? _CartList(
                key: const ValueKey('list'),
                cart: cart,
                availabilities: availabilities,
                validation: validation,
                banner: banner,
                priceChanges: priceChanges,
                priceSummary: priceSummary,
                optionRejected: optionRejected,
                onAcknowledgePrice: () =>
                    ref.read(cartPriceChangesProvider.notifier).acknowledge(),
                onReselect: (id) => _reselectOptions(cart, id),
                onRecheck: _recheck,
                scroll: _scroll,
                keyFor: (id) => _lineKeys.putIfAbsent(id, GlobalKey.new),
              )
            : const _EmptyCart(key: ValueKey('empty')),
      ),
      bottomNavigationBar: hasItems
          ? _CheckoutBar(
              subtotal: cart.subtotal,
              blockedCount: blockedCount,
              processing: _checkingOut,
              onCheckout: () => _onCheckout(cart),
            )
          : null,
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        title: const Text(
          '카트를 비울까요?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        content: const Text(
          '담은 메뉴가 모두 사라져요.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textBody,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
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
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              '비우기',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(clearCartUseCaseProvider).call();
  }
}

class _CartList extends ConsumerWidget {
  const _CartList({
    super.key,
    required this.cart,
    required this.availabilities,
    required this.validation,
    required this.banner,
    required this.priceChanges,
    required this.priceSummary,
    required this.optionRejected,
    required this.onAcknowledgePrice,
    required this.onReselect,
    required this.onRecheck,
    required this.scroll,
    required this.keyFor,
  });
  final CartEntity cart;
  final List<CartLineAvailability> availabilities;
  final CheckoutValidation validation;
  final CartBannerVariant? banner;
  final CartPriceChangesState priceChanges;
  final CartPriceChangeSummary? priceSummary;
  final Set<String> optionRejected;
  final VoidCallback onAcknowledgePrice;
  final void Function(String cartItemId) onReselect;
  final Future<void> Function() onRecheck;
  final ScrollController scroll;
  final GlobalKey Function(String cartItemId) keyFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      controller: scroll,
      slivers: [
        // 가격 변동 배너 (payment_price_authority design §5.2): 가격이 바뀌었을 때만. 위반 배너 위에 둔다.
        SliverToBoxAdapter(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: priceSummary == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: CartPriceChangeBanner(
                      summary: priceSummary!,
                      onAcknowledge: onAcknowledgePrice,
                    ),
                  ),
          ),
        ),
        // 배너: 위반 1건 이상일 때만. 사라질 때 AnimatedSize 로 접힌다 — "문제 없음" 메시지는 띄우지 않는다 (N1).
        SliverToBoxAdapter(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: banner == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: CartAvailabilityBanner(
                      variant: banner!,
                      onRecheck: onRecheck,
                    ),
                  ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.storefront_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cart.storeName,
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
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          sliver: SliverList.separated(
            itemCount: cart.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final line = cart.items[i];
              return KeyedSubtree(
                key: keyFor(line.cartItemId),
                child: CartLineTile(
                  item: line,
                  availability: i < availabilities.length
                      ? availabilities[i]
                      : CartLineAvailability.normal,
                  priceChange: priceChanges.byCartItemId[line.cartItemId],
                  unavailableOptionItemIds: {
                    for (final o in validation.optionIssues)
                      if (o.cartItemId == line.cartItemId &&
                          o.issue.itemId != null)
                        o.issue.itemId!,
                  },
                  serverRejectedOption: optionRejected.contains(
                    line.menuItemId,
                  ),
                  onReselectOptions: () => onReselect(line.cartItemId),
                  onQuantityChanged: (q) => ref
                      .read(updateCartItemQuantityUseCaseProvider)
                      .call(cartItemId: line.cartItemId, quantity: q),
                  onRemove: () => ref
                      .read(removeCartItemUseCaseProvider)
                      .call(line.cartItemId),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              size: 56,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            const Text(
              '카트가 비어있어요',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeading,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '담고 싶은 메뉴를 골라보세요',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '메뉴 보러가기',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({
    required this.subtotal,
    required this.blockedCount,
    required this.processing,
    required this.onCheckout,
  });
  final int subtotal;
  final int blockedCount;
  final bool processing;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceElevated,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '합계',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  PriceFormatter.formatKrw(subtotal),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHeading,
                  ),
                ),
              ],
            ),
            if (blockedCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                '확인이 필요한 메뉴 $blockedCount개가 포함된 금액이에요',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                // 항상 활성 — 영구적으로 비활성인 결제 버튼은 만들지 않는다 (N6). 탭 중 중복 탭만 무시한다.
                onPressed: processing ? () {} : onCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: processing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : const Text(
                        '결제하기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
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

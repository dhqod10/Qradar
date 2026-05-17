import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/errors/unauthenticated_exception.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/price_formatter.dart';
import 'package:qradar/domain/entities/cart_item_entity.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/entities/selected_option.dart';
import 'package:qradar/presentation/common/favorite_login_required_dialog.dart';
import 'package:qradar/presentation/common/quantity_stepper.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/auth/login_page.dart';
import 'package:qradar/presentation/customer/cart/providers/cart_providers.dart';
import 'package:qradar/presentation/customer/cart/widgets/replace_cart_dialog.dart';
import 'package:qradar/presentation/customer/order/favorites/providers/favorites_providers.dart';
import 'package:qradar/presentation/customer/order/menu/providers/menu_detail_providers.dart';
import 'package:qradar/presentation/customer/order/menu/widgets/option_group_selector.dart';
import 'package:shimmer/shimmer.dart';
import 'package:uuid/uuid.dart';

class MenuItemDetailPage extends ConsumerWidget {
  const MenuItemDetailPage({
    super.key,
    required this.storeId,
    required this.storeName,
    required this.menuItemId,
  });

  final String storeId;
  final String storeName;
  final String menuItemId;

  MenuItemKey get _key =>
      MenuItemKey(storeId: storeId, menuItemId: menuItemId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(menuItemDetailProvider(_key));
    final groupsAsync = ref.watch(menuItemOptionGroupsProvider(_key));

    // 옵션 그룹 fetch 완료 시 단일/필수 그룹 첫 항목 자동 선택
    ref.listen<AsyncValue<List<OptionGroupEntity>>>(
      menuItemOptionGroupsProvider(_key),
      (prev, next) {
        next.whenOrNull(
          data: (groups) {
            ref
                .read(menuItemSelectedOptionsProvider(menuItemId).notifier)
                .primeRequiredDefaults(groups);
          },
        );
      },
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: detailAsync.when(
        loading: () => const _LoadingView(),
        error: (err, _) => _ErrorView(
          message: err.toString(),
          onRetry: () =>
              ref.invalidate(menuItemDetailProvider(_key)),
        ),
        data: (item) {
          if (item == null) return const _DeletedView();
          return _Body(
            menuItem: item,
            menuItemKey: _key,
            groupsAsync: groupsAsync,
          );
        },
      ),
      bottomNavigationBar: detailAsync.maybeWhen(
        data: (item) => item == null
            ? null
            : _BottomAction(
                menuItemKey: _key,
                menuItem: item,
                storeName: storeName,
              ),
        orElse: () => null,
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.menuItem,
    required this.menuItemKey,
    required this.groupsAsync,
  });

  final MenuItemEntity menuItem;
  final MenuItemKey menuItemKey;
  final AsyncValue<List<OptionGroupEntity>> groupsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(
      menuItemSelectedOptionsProvider(menuItem.id),
    );
    final quantity = ref.watch(menuItemQuantityProvider(menuItem.id));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _ImageHeader(
            menuItem: menuItem,
            storeId: menuItemKey.storeId,
            menuItemId: menuItemKey.menuItemId,
          ),
        ),
        SliverToBoxAdapter(
          child: _InfoSection(menuItem: menuItem),
        ),
        groupsAsync.when(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          ),
          error: (err, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '옵션을 불러오지 못했어요',
                    style: TextStyle(
                      color: AppColors.textHeading,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref.invalidate(
                      menuItemOptionGroupsProvider(menuItemKey),
                    ),
                    child: const Text('재시도'),
                  ),
                ],
              ),
            ),
          ),
          data: (groups) {
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final group = groups[i];
                  return Column(
                    children: [
                      OptionGroupSelector(
                        group: group,
                        selectedItemIds:
                            selected[group.id] ?? const <String>{},
                        onSelectSingle: (itemId) => ref
                            .read(
                              menuItemSelectedOptionsProvider(menuItem.id)
                                  .notifier,
                            )
                            .selectSingle(group.id, itemId),
                        onClearSingle: () => ref
                            .read(
                              menuItemSelectedOptionsProvider(menuItem.id)
                                  .notifier,
                            )
                            .clearSingle(group.id),
                        onToggleMulti: (itemId) => ref
                            .read(
                              menuItemSelectedOptionsProvider(menuItem.id)
                                  .notifier,
                            )
                            .toggleMulti(group.id, itemId),
                      ),
                      if (i != groups.length - 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          child: Container(
                            height: 1,
                            color: AppColors.border,
                          ),
                        ),
                    ],
                  );
                },
                childCount: groups.length,
              ),
            );
          },
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '수량',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHeading,
                  ),
                ),
                QuantityStepper(
                  value: quantity,
                  onChanged: (v) => ref
                      .read(menuItemQuantityProvider(menuItem.id).notifier)
                      .set(v),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _ImageHeader extends ConsumerWidget {
  const _ImageHeader({
    required this.menuItem,
    required this.storeId,
    required this.menuItemId,
  });

  final MenuItemEntity menuItem;
  final String storeId;
  final String menuItemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final favoriteKeys = ref
            .watch(favoriteMenuItemKeysProvider)
            .asData
            ?.value ??
        const <String>{};
    final isFavorite = favoriteKeys
        .contains(favoriteMenuItemKey(storeId: storeId, menuItemId: menuItemId));

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (menuItem.imageUrl.isEmpty)
            Container(
              color: AppColors.surface,
              alignment: Alignment.center,
              child: const Icon(
                Icons.local_cafe_outlined,
                size: 64,
                color: AppColors.textMuted,
              ),
            )
          else
            CachedNetworkImage(
              imageUrl: menuItem.imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(color: AppColors.surface),
              errorWidget: (_, _, _) => Container(
                color: AppColors.surface,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.local_cafe_outlined,
                  size: 64,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topPadding + 96,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.textHeading.withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: topPadding + 12,
            left: 16,
            child: _CircleIconButton(
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: AppColors.textHeading,
              ),
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          Positioned(
            top: topPadding + 12,
            right: 16,
            child: _CircleIconButton(
              onTap: () => _onToggleMenuItemFavorite(
                context,
                ref,
                storeId: storeId,
                menuItemId: menuItemId,
              ),
              child: Icon(
                isFavorite
                    ? Icons.favorite
                    : Icons.favorite_border_rounded,
                size: 20,
                color:
                    isFavorite ? AppColors.error : AppColors.textHeading,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated.withValues(alpha: 0.85),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// 메뉴 즐겨찾기 토글 흐름.
///
/// 비로그인 → 다이얼로그 → "로그인하기" 시 LoginPage push.
/// 로그인 → toggleFavoriteMenuItemUseCase await → stream 으로 자동 갱신.
Future<void> _onToggleMenuItemFavorite(
  BuildContext context,
  WidgetRef ref, {
  required String storeId,
  required String menuItemId,
}) async {
  final user = ref.read(authProvider).asData?.value;
  if (user == null) {
    final wantsLogin = await showFavoriteLoginRequiredDialog(context);
    if (!context.mounted) return;
    if (wantsLogin) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      );
    }
    return;
  }

  try {
    await ref.read(toggleFavoriteMenuItemUseCaseProvider).call(
          storeId: storeId,
          menuItemId: menuItemId,
        );
  } on UnauthenticatedException {
    if (!context.mounted) return;
    final wantsLogin = await showFavoriteLoginRequiredDialog(context);
    if (!context.mounted) return;
    if (wantsLogin) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      );
    }
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('즐겨찾기 저장에 실패했어요'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.menuItem});
  final MenuItemEntity menuItem;

  @override
  Widget build(BuildContext context) {
    final desc = menuItem.description;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            menuItem.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textHeading,
            ),
          ),
          if (desc != null && desc.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              desc,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.textBody,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            PriceFormatter.formatKrw(menuItem.basePrice),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _BottomAction extends ConsumerStatefulWidget {
  const _BottomAction({
    required this.menuItemKey,
    required this.menuItem,
    required this.storeName,
  });
  final MenuItemKey menuItemKey;
  final MenuItemEntity menuItem;
  final String storeName;

  @override
  ConsumerState<_BottomAction> createState() => _BottomActionState();
}

class _BottomActionState extends ConsumerState<_BottomAction> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final price = ref.watch(menuItemCurrentPriceProvider(widget.menuItemKey));
    final ready = ref.watch(menuItemAddToCartReadyProvider(widget.menuItemKey));
    final missing =
        ref.watch(menuItemMissingRequiredGroupsProvider(widget.menuItemKey));
    final enabled = ready && !_busy;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '합계',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  PriceFormatter.formatKrw(price),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: enabled ? () => _onAddPressed(missing) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      ready ? AppColors.primary : AppColors.surface,
                  foregroundColor:
                      ready ? AppColors.onPrimary : AppColors.textMuted,
                  disabledBackgroundColor:
                      ready ? AppColors.primary : AppColors.surface,
                  disabledForegroundColor:
                      ready ? AppColors.onPrimary : AppColors.textMuted,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : const Text(
                        '담기',
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

  Future<void> _onAddPressed(List<String> missing) async {
    final ready = ref.read(menuItemAddToCartReadyProvider(widget.menuItemKey));
    if (!ready) {
      final names = missing.join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("'$names' 을(를) 선택해주세요"),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final storeId = widget.menuItemKey.storeId;
    final activeCart = ref.read(cartProvider).value;
    if (activeCart != null && activeCart.storeId != storeId) {
      final ok = await showReplaceCartDialog(context);
      if (!mounted) return;
      if (!ok) return;
      await ref.read(clearCartUseCaseProvider).call();
    }

    setState(() => _busy = true);

    try {
      final groups =
          ref.read(menuItemOptionGroupsProvider(widget.menuItemKey)).value ??
              const <OptionGroupEntity>[];
      final selectedMap = ref.read(
        menuItemSelectedOptionsProvider(widget.menuItemKey.menuItemId),
      );
      final quantity = ref.read(
        menuItemQuantityProvider(widget.menuItemKey.menuItemId),
      );

      final selectedOptions = <SelectedOption>[];
      var unitPriceWithOptions = widget.menuItem.basePrice;
      for (final g in groups) {
        final picked = selectedMap[g.id] ?? const <String>{};
        for (final item in g.items) {
          if (picked.contains(item.id)) {
            selectedOptions.add(SelectedOption(
              groupId: g.id,
              groupName: g.name,
              itemId: item.id,
              label: item.label,
              priceDelta: item.priceDelta,
            ));
            unitPriceWithOptions += item.priceDelta;
          }
        }
      }

      final cartItem = CartItemEntity(
        cartItemId: const Uuid().v4(),
        menuItemId: widget.menuItem.id,
        menuItemName: widget.menuItem.name,
        imageUrl: widget.menuItem.imageUrl,
        quantity: quantity,
        selectedOptions: selectedOptions,
        unitPriceWithOptions: unitPriceWithOptions,
        lineTotal: unitPriceWithOptions * quantity,
      );

      await ref.read(addToCartUseCaseProvider).call(
            storeId: storeId,
            storeName: widget.storeName,
            item: cartItem,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('카트에 담겼어요'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('담기에 실패했어요. 잠시 후 다시 시도해주세요'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceElevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(color: AppColors.surface),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(height: 24, color: AppColors.surface),
                const SizedBox(height: 12),
                Container(height: 16, color: AppColors.surface),
                const SizedBox(height: 8),
                Container(
                    height: 16, width: 200, color: AppColors.surface),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            const Text(
              '메뉴를 불러오지 못했어요',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeading,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
              child: const Text('재시도'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeletedView extends StatelessWidget {
  const _DeletedView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded,
              color: AppColors.textMuted, size: 56),
          const SizedBox(height: 12),
          const Text(
            '메뉴를 찾을 수 없어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('뒤로가기'),
          ),
        ],
      ),
    );
  }
}

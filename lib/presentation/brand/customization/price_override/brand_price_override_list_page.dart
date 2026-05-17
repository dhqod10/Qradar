import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/menu_override_entity.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/brand/customization/price_override/brand_price_override_form_page.dart';
import 'package:qradar/presentation/brand/customization/price_override/widgets/master_menu_override_card.dart';
import 'package:qradar/presentation/brand/providers/brand_master_menu_providers.dart';
import 'package:qradar/presentation/brand/providers/brand_store_management_providers.dart';

/// 마스터 메뉴 목록 + 해당 매장 override 현황 머지 리스트.
class BrandPriceOverrideListPage extends ConsumerWidget {
  final StoreEntity store;

  const BrandPriceOverrideListPage({super.key, required this.store});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masterAsync = ref.watch(myMasterMenuItemsProvider);
    final overrideAsync = ref.watch(menuOverridesByStoreProvider(store.id));

    // 두 stream 중 하나라도 로딩이면 로딩 표시
    if (masterAsync.isLoading || overrideAsync.isLoading) {
      return const _LoadingView();
    }

    if (masterAsync.hasError) {
      return _ErrorView(
        onRetry: () => ref.invalidate(myMasterMenuItemsProvider),
      );
    }

    if (overrideAsync.hasError) {
      return _ErrorView(
        onRetry: () => ref.invalidate(menuOverridesByStoreProvider(store.id)),
      );
    }

    final masters = masterAsync.asData?.value ?? [];
    final overrides = overrideAsync.asData?.value ?? [];

    // masterMenuItemId → MenuOverrideEntity 매핑
    final overrideMap = <String, MenuOverrideEntity>{
      for (final o in overrides) o.masterMenuItemId: o,
    };

    if (masters.isEmpty) {
      return const _EmptyView();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: masters.length,
      itemBuilder: (context, index) {
        final master = masters[index];
        final override = overrideMap[master.id];
        return MasterMenuOverrideCard(
          master: master,
          menuOverride: override,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BrandPriceOverrideFormPage(
                store: store,
                masterMenu: master,
                currentOverride: override,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── 상태 뷰 ────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primaryBright),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          const Text(
            '데이터를 불러오지 못했어요',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '잠시 후 다시 시도해주세요',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              '다시 시도',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 56,
            color: AppColors.textMuted,
          ),
          SizedBox(height: 20),
          Text(
            '마스터 메뉴가 없어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textHeading,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '마스터 메뉴를 먼저 등록하고 승인을 받아주세요.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

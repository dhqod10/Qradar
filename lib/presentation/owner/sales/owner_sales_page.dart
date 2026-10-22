import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/errors/permission_denied_exception.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/store_sales_entity.dart';
import 'package:qradar/domain/entities/store_sales_query.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/presentation/owner/owner_scaffold.dart';
import 'package:qradar/presentation/owner/providers/owner_providers.dart';
import 'package:qradar/presentation/owner/sales/formatters/sales_formatters.dart';
import 'package:qradar/presentation/owner/sales/providers/owner_sales_providers.dart';
import 'package:qradar/presentation/owner/sales/widgets/sales_empty_state.dart';
import 'package:qradar/presentation/owner/sales/widgets/sales_order_tile.dart';
import 'package:qradar/presentation/owner/sales/widgets/sales_period_header.dart';
import 'package:qradar/presentation/owner/sales/widgets/sales_store_status_banner.dart';
import 'package:qradar/presentation/owner/sales/widgets/sales_summary_card.dart';

/// 점주 매출 탭. 기간(일/주/월)별 총 매출 · 건수 · 객단가와 주문 목록.
///
/// - OwnerScaffold 가 IndexedStack 이라 탭을 떠나도 dispose 되지 않는다.
///   자동 재조회가 없으므로 기간 전환 / pull-to-refresh 가 유일한 갱신 수단.
/// - 집계는 `aggregateStoreSales` 에만 있다. 이 화면은 값을 표시만 한다.
class OwnerSalesPage extends ConsumerWidget {
  const OwnerSalesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(myStoreProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '매출',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: storeAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) {
          debugPrint('[OwnerSalesPage] myStore error: $e');
          return Center(
            child: SalesEmptyState(
              icon: Icons.cloud_off_rounded,
              iconColor: AppColors.error,
              title: '매장 정보를 불러오지 못했어요',
              titleSize: 16,
              message: '잠시 후 다시 시도해 주세요',
              actionLabel: '다시 시도',
              onAction: () => ref.invalidate(myStoreProvider),
            ),
          );
        },
        data: (store) {
          if (store == null) {
            return Center(
              child: SalesEmptyState(
                icon: Icons.storefront_outlined,
                iconColor: AppColors.textMuted,
                title: '등록된 매장이 없어요',
                message: '매장을 등록하면 매출이 집계됩니다',
                actionLabel: '내 매장 탭으로 이동',
                actionStyle: SalesEmptyActionStyle.filled,
                onAction: () => ref.read(ownerTabIndexProvider.notifier).set(0),
              ),
            );
          }
          return _SalesBody(store: store);
        },
      ),
    );
  }
}

class _SalesBody extends ConsumerWidget {
  const _SalesBody({required this.store});

  final StoreEntity store;

  Future<void> _refresh(
    BuildContext context,
    WidgetRef ref,
    StoreSalesQuery query,
  ) async {
    final hadValue = ref.read(storeSalesProvider(query)).hasValue;
    try {
      final _ = await ref.refresh(storeSalesProvider(query).future);
    } catch (e) {
      debugPrint('[OwnerSalesPage] refresh failed: $e');
      // 기존 내용은 유지하고, 에러를 놓치지 않도록 SnackBar 만 띄운다.
      if (hadValue && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('새로고침에 실패했어요')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(salesPeriodProvider);
    final query = StoreSalesQuery(storeId: store.id, period: period);
    final async = ref.watch(storeSalesProvider(query));
    // 새로고침 실패 시에도 이전 값이 남아 있으면 그대로 표시한다.
    // 기간 전환(새 키)은 값이 없는 loading 이므로 skeleton 이 된다.
    final sales = async.value;

    final children = <Widget>[
      if (store.status != EntityApprovalStatus.approved)
        SalesStoreStatusBanner(store: store),
      if (sales != null)
        ..._dataChildren(sales)
      // isLoading 을 hasError 보다 먼저 본다.
      // 에러 상태를 invalidate 하면 isLoading 과 hasError 가 동시에 true 라서,
      // hasError 를 먼저 보면 "다시 시도" 를 눌러도 에러 블록이 그대로 남는다.
      else if (async.isLoading)
        ..._skeleton()
      else if (async.hasError)
        _errorBlock(ref, query, async.error)
      else
        ..._skeleton(),
    ];

    return Column(
      children: [
        const SalesPeriodHeader(),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surfaceElevated,
            displacement: 40,
            strokeWidth: 2.5,
            onRefresh: () => _refresh(context, ref, query),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 8, bottom: 110),
              children: children,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _dataChildren(StoreSalesEntity sales) {
    final orders = sales.orders;
    final type = sales.summary.period.type;
    return [
      SalesSummaryCard(summary: sales.summary, isTruncated: sales.isTruncated),
      if (orders.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 32),
          child: SalesEmptyState(
            icon: Icons.receipt_long_outlined,
            iconColor: AppColors.textMuted,
            title: '이 기간에 주문이 없어요',
            message: '주문이 들어오면 매출에 반영됩니다',
            compact: true,
          ),
        )
      else ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(
            children: [
              Semantics(
                header: true,
                child: const Text(
                  '주문 내역',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHeading,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '환불·취소 포함 ${orders.length}건',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        for (final o in orders)
          SalesOrderTile(key: ValueKey(o.id), order: o, periodType: type),
        if (sales.isTruncated)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Text(
              SalesFormatters.truncatedListFootnote,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
      ],
    ];
  }

  List<Widget> _skeleton() {
    Widget box(double h) => Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      height: h,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
    );
    return [box(280), box(76), box(76), box(76)];
  }

  Widget _errorBlock(WidgetRef ref, StoreSalesQuery query, Object? error) {
    debugPrint('[OwnerSalesPage] sales error: $error');
    final denied = error is PermissionDeniedException;
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: denied
          ? const SalesEmptyState(
              icon: Icons.lock_outline_rounded,
              iconColor: AppColors.error,
              title: '매출을 조회할 권한이 없어요',
              titleSize: 16,
              message: '매장 소유자 계정으로 로그인했는지 확인해 주세요',
            )
          : SalesEmptyState(
              icon: Icons.cloud_off_rounded,
              iconColor: AppColors.error,
              title: '불러오는 데 실패했어요',
              titleSize: 16,
              message: '네트워크 상태를 확인하고 다시 시도해 주세요',
              actionLabel: '다시 시도',
              onAction: () => ref.invalidate(storeSalesProvider(query)),
            ),
    );
  }
}

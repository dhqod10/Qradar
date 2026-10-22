import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/errors/permission_denied_exception.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/domain/entities/qoin_transaction_entity.dart';
import 'package:qradar/presentation/customer/order/orders/order_detail_page.dart';
import 'package:qradar/presentation/customer/qoin/providers/qoin_providers.dart';
import 'package:qradar/presentation/customer/qoin/widgets/qoin_status_block.dart';
import 'package:qradar/presentation/customer/qoin/widgets/qoin_transaction_tile.dart';

/// Qoin 내역 섹션 (헤더 + 원장 카드 / skeleton / empty / error).
/// 잔액 카드와 독립된 상태를 가진다.
class QoinHistorySection extends ConsumerWidget {
  const QoinHistorySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(qoinTransactionsProvider);

    return async.when(
      loading: () => const _Section(child: _LedgerSkeleton()),
      error: (e, _) => _Section(
        child: QoinStatusBlock(
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.error,
          title: '내역을 불러오지 못했어요',
          message: e is PermissionDeniedException
              ? '권한 문제로 불러오지 못했어요. 계속되면 문의해주세요'
              : '잠시 후 다시 시도해주세요',
          actionLabel: '다시 시도',
          onAction: () => ref.invalidate(qoinTransactionsProvider),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const QoinStatusBlock(
            icon: Icons.toll_rounded,
            iconColor: AppColors.textMuted,
            title: '아직 적립된 Qoin 이 없어요',
            message: '주문이 픽업 완료되면 여기에 쌓여요.\n결제 직후에는 보이지 않을 수 있어요',
          );
        }
        return _Section(child: _Ledger(list: list));
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Semantics(
            header: true,
            child: const Text(
              'Qoin 내역',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeading,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _LedgerCard extends StatelessWidget {
  const _LedgerCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _Ledger extends StatelessWidget {
  const _Ledger({required this.list});
  final List<QoinTransactionEntity> list;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < list.length; i++) {
      final tx = list[i];
      if (i > 0) {
        rows.add(
          const Divider(
            height: 1,
            color: AppColors.border,
            indent: 16,
            endIndent: 16,
          ),
        );
      }
      rows.add(
        QoinTransactionTile(
          tx: tx,
          onTap: tx.orderId.isEmpty
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => OrderDetailPage(orderId: tx.orderId),
                  ),
                ),
        ),
      );
    }
    return Column(
      children: [
        _LedgerCard(children: rows),
        if (list.length >= QoinPolicy.historyLimit)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Text(
              '최근 ${QoinPolicy.historyLimit}건을 보여드려요',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
      ],
    );
  }
}

class _LedgerSkeleton extends StatelessWidget {
  const _LedgerSkeleton();

  Widget _box(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: AppColors.border,
      borderRadius: BorderRadius.circular(6),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '내역을 불러오는 중',
      excludeSemantics: true,
      child: _LedgerCard(
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                color: AppColors.border,
                indent: 16,
                endIndent: 16,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.border,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _box(120, 14),
                        const SizedBox(height: 6),
                        _box(180, 12),
                        const SizedBox(height: 6),
                        _box(90, 12),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _box(64, 16),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

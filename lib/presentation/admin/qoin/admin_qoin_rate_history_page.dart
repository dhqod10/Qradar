import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/errors/permission_denied_exception.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/presentation/admin/qoin/providers/qoin_admin_providers.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_admin_ui.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_bulk_resume.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_filter_chip.dart';
import 'package:qradar/presentation/common/providers/qoin_rate_providers.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_load_error.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_history_list.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_history_page.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_history_tile.dart';

enum _HistoryFilter {
  all('전체'),
  global('전역'),
  brand('브랜드'),
  store('매장'),
  unfinished('미완료 적용');

  const _HistoryFilter(this.label);
  final String label;
}

/// 관리자 전체 변경 이력 (`collectionGroup('qoinRateHistory')`, 최신순, 50건씩).
///
/// 필터는 **로드된 범위 안의 클라이언트 필터**다 — 서버 필터는 collection-group 복합 인덱스가 필요한데
/// 배포 없이는 검증할 수 없다 (design D10). 필터 결과가 비어도 더 불러올 수 있으면 `이전 이력 더 보기` 를 그대로 노출한다.
/// 정렬(`changedAt`)에는 collection-group **단일 필드 인덱스**가 필요하다 (`firestore.indexes.json` 의 fieldOverrides — 배포 필요).
class AdminQoinRateHistoryPage extends ConsumerStatefulWidget {
  const AdminQoinRateHistoryPage({super.key, this.unfinishedOnly = false});

  /// 허브 배너에서 들어오면 `미완료 적용` 칩이 선택된 채로 열린다.
  final bool unfinishedOnly;

  @override
  ConsumerState<AdminQoinRateHistoryPage> createState() =>
      _AdminQoinRateHistoryPageState();
}

class _AdminQoinRateHistoryPageState
    extends ConsumerState<AdminQoinRateHistoryPage> {
  int _limit = QoinPolicy.historyPageSize;
  late _HistoryFilter _filter;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _filter = widget.unfinishedOnly
        ? _HistoryFilter.unfinished
        : _HistoryFilter.all;
  }

  bool _match(QoinRateChangeEntity c, DateTime now) {
    switch (_filter) {
      case _HistoryFilter.all:
        return true;
      case _HistoryFilter.global:
        return c.scope == QoinRateScope.global;
      case _HistoryFilter.brand:
        return c.scope == QoinRateScope.brand;
      case _HistoryFilter.store:
        return c.scope == QoinRateScope.store;
      case _HistoryFilter.unfinished:
        return c.isUnfinished(now);
    }
  }

  /// 매장 이력의 `clearByBulk` → 그 매장의 브랜드 이력 (admin 은 항상 가능). 브랜드를 찾지 못하면 SnackBar.
  void _openBrandHistory(QoinRateChangeEntity c) {
    final stores = ref.read(qoinAdminStoresProvider).asData?.value;
    final brandId = stores
        ?.where((s) => s.id == c.targetId)
        .firstOrNull
        ?.brandId;
    if (brandId == null || brandId.isEmpty) {
      qoinSnack(context, '해당 일괄 적용 기록을 찾지 못했어요');
      return;
    }
    final brandName =
        ref.read(qoinAdminBrandByIdProvider(brandId)).asData?.value?.name ?? '';
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QoinRateHistoryPage(
          scope: QoinRateScope.brand,
          targetId: brandId,
          targetName: brandName,
          viewer: QoinHistoryViewer.admin,
          highlightHistoryId: c.bulkHistoryId,
        ),
      ),
    );
  }

  Future<void> _resume(QoinRateChangeEntity c) async {
    final r = await runBulkResume(
      context,
      ref,
      c,
      onRunning: (v) {
        if (mounted) setState(() => _running = v);
      },
    );
    if (r != null && mounted) qoinSnack(context, '적용을 마쳤어요');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(qoinAllRateHistoryProvider(_limit));
    return PopScope(
      canPop: !_running,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: qoinAppBar(context, '변경 이력', canPop: !_running),
        body: Stack(
          children: [
            Column(
              children: [
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    children: [
                      for (final f in _HistoryFilter.values) ...[
                        if (f != _HistoryFilter.all) const SizedBox(width: 8),
                        QoinFilterChip(
                          label: f.label,
                          selected: _filter == f,
                          onTap: () => setState(() => _filter = f),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: async.when(
                    loading: () => async.hasValue
                        ? _content(async.requireValue)
                        : const SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                            child: QoinRateHistorySkeleton(),
                          ),
                    error: (e, _) => QoinLoadError(
                      title: QoinHistoryCopy.errorTitle,
                      // 인덱스 오류 문자열을 노출하지 않는다.
                      message: e is PermissionDeniedException
                          ? QoinHistoryCopy.errorPermissionAdmin
                          : QoinHistoryCopy.errorGeneric,
                      onRetry: () =>
                          ref.invalidate(qoinAllRateHistoryProvider(_limit)),
                    ),
                    data: _content,
                  ),
                ),
              ],
            ),
            if (_running)
              Positioned.fill(
                child: Container(
                  color: AppColors.background.withValues(alpha: 0.92),
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Qoin 적립률을 적용하고 있어요',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textHeading,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _content(List<QoinRateChangeEntity> all) {
    final now = DateTime.now();
    final canLoadMore = all.length >= _limit;
    final shown = all.where((c) => _match(c, now)).toList();

    if (all.isEmpty) {
      return const _Empty(
        icon: Icons.history_rounded,
        title: '변경 이력이 없어요',
        message: '적립률을 변경하면 여기에 기록돼요',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          if (shown.isEmpty)
            _Empty(
              icon: Icons.history_rounded,
              title: _filter == _HistoryFilter.unfinished
                  ? '끝나지 않은 일괄 적용이 없어요'
                  : '조건에 맞는 이력이 없어요',
              message: '다른 조건으로 찾아보세요',
              shrink: true,
            )
          else
            QoinRateHistoryList(
              items: shown,
              viewer: QoinHistoryViewer.admin,
              now: now,
              onResume: _resume,
              onOpenBrandHistory: _openBrandHistory,
            ),
          // 필터 결과가 0 이어도 더 불러올 수 있으면 그대로 노출 (더 불러오면 있을 수 있음).
          QoinHistoryFooter(
            canLoadMore: canLoadMore,
            loading: false,
            onMore: () => setState(() => _limit += QoinPolicy.historyPageSize),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.message,
    this.shrink = false,
  });
  final IconData icon;
  final String title;
  final String message;
  final bool shrink;

  @override
  Widget build(BuildContext context) {
    final col = Padding(
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: shrink ? 32 : 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: shrink ? 48 : 56, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
    return shrink ? col : Center(child: col);
  }
}

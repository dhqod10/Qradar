import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/errors/permission_denied_exception.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/presentation/common/providers/qoin_rate_providers.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_load_error.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_history_list.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_history_tile.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_labels.dart';

/// 이력 화면 공용 카피.
class QoinHistoryCopy {
  QoinHistoryCopy._();

  static const String more = '이전 이력 더 보기';
  static const String allLoaded = '모든 이력을 불러왔어요';
  static const String errorTitle = '이력을 불러오지 못했어요';
  static const String errorGeneric = '잠시 후 다시 시도해주세요';
  static const String errorPermissionAdmin = '권한 문제로 불러오지 못했어요. 계속되면 문의해주세요';
  static const String errorPermissionReader = '이력을 볼 수 있는 권한이 없어요';
}

/// "이전 이력 더 보기" / "모든 이력을 불러왔어요" 푸터.
class QoinHistoryFooter extends StatelessWidget {
  const QoinHistoryFooter({
    super.key,
    required this.canLoadMore,
    required this.loading,
    required this.onMore,
  });

  final bool canLoadMore;
  final bool loading;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    if (!canLoadMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            QoinHistoryCopy.allLoaded,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: OutlinedButton(
        onPressed: loading ? null : onMore,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : const Text(
                QoinHistoryCopy.more,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
      ),
    );
  }
}

/// 점주·브랜드 이력 화면 (읽기 전용). 필터 칩 없음, `이어서 적용` 버튼 없음, 변경자는 `관리자`.
/// 자기 것이 아닌 대상을 열면 Rules 가 거부하고 `이력을 볼 수 있는 권한이 없어요` 가 보인다 (방어).
class QoinRateHistoryPage extends ConsumerStatefulWidget {
  const QoinRateHistoryPage({
    super.key,
    required this.scope,
    required this.targetId,
    required this.targetName,
    this.viewer = QoinHistoryViewer.owner,
    this.brandId,
    this.brandName,
    this.highlightHistoryId,
  });

  final QoinRateScope scope;
  final String targetId;
  final String targetName;

  /// 뷰어 역할 — `clearByBulk` 행의 브랜드 이력 링크 노출을 정한다 (N8). 기본은 가맹점주(링크 없음).
  final QoinHistoryViewer viewer;

  /// 브랜드 보유자(viewer == brand)가 매장 이력을 볼 때 링크가 가리킬 자기 브랜드. owner 에게는 쓰이지 않는다.
  final String? brandId;
  final String? brandName;

  /// `브랜드 이력에서 보기` 로 들어왔을 때 스크롤·강조할 일괄 적용 이력 ID.
  final String? highlightHistoryId;

  @override
  ConsumerState<QoinRateHistoryPage> createState() =>
      _QoinRateHistoryPageState();
}

class _QoinRateHistoryPageState extends ConsumerState<QoinRateHistoryPage> {
  int _limit = QoinPolicy.historyPageSize;
  final GlobalKey _highlightKey = GlobalKey();
  String? _highlightId;
  bool _highlightHandled = false;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    _highlightId = widget.highlightHistoryId;
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  /// 데이터가 처음 도착했을 때 한 번: 있으면 스크롤 + 2초 강조, 없으면 SnackBar (페이지네이션이 없어 대부분 바로 찾는다).
  void _handleHighlight(List<QoinRateChangeEntity> list) {
    if (_highlightHandled || _highlightId == null) return;
    _highlightHandled = true;
    final found = list.any((c) => c.id == _highlightId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!found) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('해당 일괄 적용 기록을 찾지 못했어요')),
        );
        setState(() => _highlightId = null);
        return;
      }
      final ctx = _highlightKey.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.3);
      _highlightTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _highlightId = null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final key = (scope: widget.scope, targetId: widget.targetId, limit: _limit);
    final async = ref.watch(qoinRateHistoryProvider(key));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textBody,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('적립률 변경 이력'),
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textHeading,
        ),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${QoinScopeLabel.of(widget.scope, widget.targetName)} 의 변경 이력',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHeading,
                ),
              ),
            ),
            const SizedBox(height: 16),
            async.when(
              loading: () => async.hasValue
                  ? _content(async.requireValue)
                  : const QoinRateHistorySkeleton(),
              error: (e, _) => QoinLoadError(
                compact: true,
                title: QoinHistoryCopy.errorTitle,
                message: e is PermissionDeniedException
                    ? QoinHistoryCopy.errorPermissionReader
                    : QoinHistoryCopy.errorGeneric,
                onRetry: () => ref.invalidate(qoinRateHistoryProvider(key)),
              ),
              data: _content,
            ),
          ],
        ),
      ),
    );
  }

  void _openBrandHistory(QoinRateChangeEntity change) {
    final id = widget.brandId;
    if (id == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QoinRateHistoryPage(
          scope: QoinRateScope.brand,
          targetId: id,
          targetName: widget.brandName ?? '',
          viewer: QoinHistoryViewer.brand,
          brandId: id,
          brandName: widget.brandName,
          highlightHistoryId: change.bulkHistoryId,
        ),
      ),
    );
  }

  Widget _content(List<QoinRateChangeEntity> list) {
    _handleHighlight(list);
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.history_rounded, size: 56, color: AppColors.textMuted),
              SizedBox(height: 12),
              Text(
                '아직 변경된 적이 없어요',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHeading,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '적립률이 바뀌면 여기에 기록돼요',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        QoinRateHistoryList(
          items: list,
          viewer: widget.viewer,
          now: DateTime.now(),
          highlightId: _highlightId,
          highlightKey: _highlightKey,
          // owner 에게는 콜백 자체를 만들지 않는다 (Rules 가 브랜드 이력 읽기를 거부한다 — N8).
          onOpenBrandHistory:
              widget.viewer == QoinHistoryViewer.brand && widget.brandId != null
              ? _openBrandHistory
              : null,
        ),
        QoinHistoryFooter(
          canLoadMore: list.length >= _limit,
          loading: false,
          onMore: () => setState(() => _limit += QoinPolicy.historyPageSize),
        ),
      ],
    );
  }
}

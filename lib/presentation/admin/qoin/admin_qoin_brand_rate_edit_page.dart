import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_results.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/presentation/admin/qoin/admin_qoin_rate_history_page.dart';
import 'package:qradar/presentation/admin/qoin/providers/qoin_admin_providers.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_accrual_switch_card.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_admin_ui.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_bulk_resume.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_current_rate_card.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_rate_chain.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_rate_edit_form.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_scope_band.dart';
import 'package:qradar/presentation/common/providers/qoin_di_providers.dart';
import 'package:qradar/presentation/common/providers/qoin_rate_providers.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_load_error.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_partial_banner.dart';

/// 브랜드 적립률 편집 + **하위 매장 일괄 적용** (H4/H5).
///
/// 일괄 적용 3단: ① `개별 설정이 있는 매장 처리` 선택(폼) → ② 확인 다이얼로그(영향 매장 수, 체크박스 없음) →
/// ③ 실행·결과·partial. `적립 사용` 스위치는 폼 아래 독립 카드이며 일괄 적용은 스위치를 읽지도 쓰지도 않는다. 실행 중에는 `PopScope(canPop: false)` 로 화면을 떠나지 못하게 한다
/// (서버는 브랜드 값을 먼저 쓰고 개별 설정을 청크로 지운다 — 중간에 떠나도 안전하지만 결과를 못 본다).
/// 숫자(N, M, K)는 클라이언트 미리보기이고, 결과 카드·이력의 숫자는 서버 응답을 쓴다.
class AdminQoinBrandRateEditPage extends ConsumerStatefulWidget {
  const AdminQoinBrandRateEditPage({super.key, required this.brandId});
  final String brandId;

  @override
  ConsumerState<AdminQoinBrandRateEditPage> createState() =>
      _AdminQoinBrandRateEditPageState();
}

class _ResultView {
  const _ResultView(this.result, this.value, this.mode);
  final QoinBulkApplyResult result;

  /// 재개(이어서 적용)는 값을 보내지 않으므로 null.
  final QoinRateValue? value;
  final QoinBulkMode mode;
}

class _AdminQoinBrandRateEditPageState
    extends ConsumerState<AdminQoinBrandRateEditPage> {
  bool _running = false;
  _ResultView? _result;
  final Set<String> _laterIds = {};
  final QoinSwitchFocusController _switchFocus = QoinSwitchFocusController();

  @override
  void dispose() {
    _switchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brandAsync = ref.watch(qoinAdminBrandByIdProvider(widget.brandId));
    final effAsync = ref.watch(effectiveBrandQoinRateProvider(widget.brandId));

    Widget body;
    if (brandAsync.hasError || effAsync.hasError) {
      body = QoinLoadError(
        onRetry: () {
          ref.invalidate(qoinAdminBrandsProvider);
          ref.invalidate(effectiveBrandQoinRateProvider(widget.brandId));
        },
      );
    } else if (!brandAsync.hasValue) {
      body = const _EditSkeleton();
    } else if (brandAsync.requireValue == null) {
      body = const _NotFound();
    } else if (!effAsync.hasValue) {
      body = const _EditSkeleton();
    } else {
      body = _buildBody(brandAsync.requireValue!, effAsync.requireValue);
    }

    return PopScope(
      canPop: !_running,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: qoinAppBar(context, '브랜드 적립률', canPop: !_running),
        body: Stack(children: [body, if (_running) const _RunningOverlay()]),
      ),
    );
  }

  Widget _buildBody(BrandEntity brand, EffectiveQoinRate effective) {
    final statsAsync = ref.watch(qoinBrandBulkStatsProvider(widget.brandId));
    final stats = statsAsync.asData?.value;
    final now = DateTime.now();
    final historyAsync = ref.watch(
      qoinRateHistoryProvider((
        scope: QoinRateScope.brand,
        targetId: widget.brandId,
        limit: 20,
      )),
    );
    final unfinished = historyAsync.asData?.value
        .where((c) => c.isUnfinished(now) && !_laterIds.contains(c.id))
        .firstOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QoinScopeBand(
            scope: QoinRateScope.brand,
            targetName: brand.name,
            detail: QoinScopeBandDetail.brand(
              total: stats?.total,
              overridden: stats?.overridden,
            ),
          ),
          const SizedBox(height: 16),
          if (unfinished != null) ...[
            QoinPartialBanner.full(
              change: unfinished,
              onResume: () => _resume(unfinished),
              onLater: () => setState(() => _laterIds.add(unfinished.id)),
            ),
            const SizedBox(height: 16),
          ],
          if (_result != null) ...[
            _ResultCard(
              view: _result!,
              onClose: () => setState(() => _result = null),
              onGoToSwitch: _switchFocus.go,
              onOpenHistory: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdminQoinRateHistoryPage(),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          QoinCurrentRateCard.target(
            effective: effective,
            target: QoinRateScope.brand,
          ),
          const SizedBox(height: 12),
          QoinRateChain(effective: effective, target: QoinRateScope.brand),
          const SizedBox(height: 20),
          QoinRateEditForm(
            scope: QoinRateScope.brand,
            targetName: brand.name,
            current: brand.qoinAccrualRate,
            effective: effective,
            saveLabel: '브랜드 설정 저장',
            bulkStats: statsAsync,
            onRetryBulk: () => ref.invalidate(qoinAdminStoresProvider),
            onGoToSwitch: _switchFocus.go,
            onSubmit: (s) => _apply(s, stats),
          ),
          // 저장 버튼 아래 — 적립률 폼과 시각적으로 갈라 둔다 (gap 32).
          const SizedBox(height: 32),
          const Text(
            '적립 사용',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          QoinAccrualSwitchCard(
            scope: QoinRateScope.brand,
            targetId: brand.id,
            targetName: brand.name,
            switchSetting: brand.qoinAccrualEnabled,
            effective: effective,
            controller: _switchFocus,
            subStoreTotal: stats?.total,
            subStoreOverridden: stats?.overridden,
          ),
        ],
      ),
    );
  }

  Future<void> _apply(QoinRateSubmission s, QoinBulkStats? stats) async {
    final mode = s.mode ?? QoinBulkMode.preserve;
    // 즉시 끝나는 경로(보존 / 개별 설정 0곳)는 덮개 없이 저장 버튼 인디케이터만.
    final heavy =
        mode == QoinBulkMode.overwrite && (stats?.overridden ?? 0) > 0;
    if (heavy) setState(() => _running = true);
    try {
      final r = await ref.read(applyBrandQoinRateUseCaseProvider)(
        brandId: widget.brandId,
        value: s.value,
        mode: mode,
        reason: s.reason,
      );
      if (!mounted) return;
      setState(() => _result = _ResultView(r, s.value, mode));
    } catch (e) {
      if (mounted) qoinSnack(context, QoinMessages.failure(e, bulk: true));
      rethrow;
    } finally {
      if (mounted && heavy) setState(() => _running = false);
    }
  }

  Future<void> _resume(QoinRateChangeEntity change) async {
    final r = await runBulkResume(
      context,
      ref,
      change,
      onRunning: (v) {
        if (mounted) setState(() => _running = v);
      },
    );
    if (r == null || !mounted) return;
    setState(() => _result = _ResultView(r, null, QoinBulkMode.overwrite));
  }
}

/// 일괄 적용 결과 카드 (폼 위, 닫기 전까지 유지). 숫자는 **서버 응답**이다.
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.view,
    required this.onClose,
    required this.onOpenHistory,
    required this.onGoToSwitch,
  });

  final _ResultView view;
  final VoidCallback onClose;
  final VoidCallback onOpenHistory;

  /// `적립 사용 켜러 가기` — 스위치 카드로 스크롤. 스위치를 대신 누르지 않는다.
  final VoidCallback onGoToSwitch;

  String get _valueLine {
    final v = view.value;
    if (v == null) return '';
    switch (v) {
      case QoinRateValueRate(:final tenths):
        return '새 적립률 ${QoinPolicy.formatTenths(tenths)}%';
      case QoinRateValueInherit():
        return '새 설정 상위 설정 따르기';
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = view.result;
    final done = r.status == QoinBulkStatus.completed;
    final countLine = view.mode == QoinBulkMode.overwrite
        ? '적용된 매장 ${r.affectedCount}곳 · 초기화된 개별 설정 ${r.clearedCount}곳'
        : '적용된 매장 ${r.affectedCount}곳 · 개별 설정 ${r.preservedCount}곳은 그대로예요';
    final title = done ? '적용을 마쳤어요' : '일부만 적용됐어요';
    // `brandDisabled` 는 서버가 트랜잭션에서 읽은 그 시점의 확정 기록이다. K 보다 우선하며, 있으면 K 줄은 그리지 않는다.
    final brandOff = r.brandDisabled;
    final k = r.disabledUntouchedCount;

    return Semantics(
      container: true,
      liveRegion: true,
      label:
          '$title. ${brandOff ? '브랜드가 사용 안 함이라 산하 매장 전체가 적립되지 않아요. ' : ''}'
          '${_valueLine.isEmpty ? '' : '$_valueLine. '}$countLine'
          '${!brandOff && k > 0 ? '. 적립 사용 안 함 $k곳은 적립이 시작되지 않았어요' : ''}',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primaryBright.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primaryBright.withValues(alpha: 0.30),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textBody,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onClose,
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            if (brandOff) ...[
              const SizedBox(height: 8),
              _BrandOffPlate(onGoToSwitch: onGoToSwitch),
            ],
            if (_valueLine.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _valueLine,
                style: const TextStyle(fontSize: 13, color: AppColors.textBody),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              countLine,
              style: const TextStyle(fontSize: 13, color: AppColors.textBody),
            ),
            if (!brandOff && k > 0) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '적립 사용 안 함 $k곳은 적립이 시작되지 않았어요',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textBody,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            TextButton(
              onPressed: onOpenHistory,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.zero,
              ),
              child: const Text(
                '이력 보기 ›',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 일괄 적용 결과의 `brandDisabled` 고지 (N4). 모든 수치보다 먼저 그린다.
class _BrandOffPlate extends StatelessWidget {
  const _BrandOffPlate({required this.onGoToSwitch});
  final VoidCallback onGoToSwitch;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.pause_circle_outline_rounded,
                size: 18,
                color: AppColors.warning,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '브랜드가 ‘사용 안 함’ 이라 산하 매장 전체가 적립되지 않아요',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBody,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '새 적립률은 저장됐어요. 브랜드의 ‘적립 사용’ 을 켜면 적용돼요',
            style: TextStyle(fontSize: 12, color: AppColors.textBody),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onGoToSwitch,
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              child: const Text(
                '적립 사용 켜러 가기',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RunningOverlay extends StatelessWidget {
  const _RunningOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Semantics(
        liveRegion: true,
        label: 'Qoin 적립률을 적용하고 있어요',
        child: Container(
          color: AppColors.background.withValues(alpha: 0.92),
          alignment: Alignment.center,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Column(
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
                SizedBox(height: 6),
                Text(
                  '매장 수에 따라 시간이 걸릴 수 있어요. 끝나지 않은 경우 이력에서 이어서 적용할 수 있어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditSkeleton extends StatelessWidget {
  const _EditSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget box(double h) => Container(
      height: h,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(14),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(children: [box(76), box(120)]),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.business_outlined,
              size: 56,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            const Text(
              '브랜드를 찾을 수 없어요',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textHeading,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '목록으로 돌아가 다시 선택해주세요',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('목록으로'),
            ),
          ],
        ),
      ),
    );
  }
}

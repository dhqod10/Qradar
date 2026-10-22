import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/qoin_formatters.dart';
import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/domain/entities/qoin_config_entity.dart';
import 'package:qradar/presentation/admin/qoin/admin_qoin_brand_rates_page.dart';
import 'package:qradar/presentation/admin/qoin/admin_qoin_global_rate_page.dart';
import 'package:qradar/presentation/admin/qoin/admin_qoin_rate_history_page.dart';
import 'package:qradar/presentation/admin/qoin/admin_qoin_store_rates_page.dart';
import 'package:qradar/presentation/admin/qoin/providers/qoin_admin_providers.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_admin_ui.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_current_rate_card.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_kill_switch_card.dart';
import 'package:qradar/presentation/common/providers/qoin_config_providers.dart';
import 'package:qradar/presentation/common/providers/qoin_di_providers.dart';
import 'package:qradar/presentation/common/providers/qoin_rate_providers.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_load_error.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_partial_banner.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_labels.dart';

/// 관리자 Qoin 설정 **허브** (현황 + 진입 + 비상 정지). 1차의 단일 설정 화면을 교체했다.
///
/// 허브에서는 적립률을 직접 입력하지 않는다 — 전역 입력은 `AdminQoinGlobalRatePage` 로 분리했다
/// (범위 오입력 방어). 영역별로 독립 상태를 가진다: config 가 로딩/에러여도 진입 타일은 항상 즉시 보인다
/// (config 장애 중에도 이력 조회·매장 점검은 가능해야 한다).
///
/// 비상 정지는 적립률 입력과 저장 경로가 분리돼 있다 — 적립률 검증에 막히지 않고, 작성 중인 값이 딸려 저장되지 않는다.
class AdminQoinSettingsPage extends ConsumerStatefulWidget {
  const AdminQoinSettingsPage({super.key});

  @override
  ConsumerState<AdminQoinSettingsPage> createState() =>
      _AdminQoinSettingsPageState();
}

class _AdminQoinSettingsPageState extends ConsumerState<AdminQoinSettingsPage> {
  bool _savingEnabled = false;

  Future<void> _onToggleEnabled(QoinConfigEntity cfg, bool next) async {
    final latest = ref.read(qoinConfigProvider).asData?.value ?? cfg;
    final rateLabel = latest.accrualRate == null
        ? ''
        : QoinPolicy.formatRatePercent(latest.accrualRate!);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => next
          ? QoinEnableDialog(rateLabel: rateLabel)
          : const QoinDisableDialog(),
    );
    if (ok != true || !mounted) return;

    setState(() => _savingEnabled = true);
    try {
      // 적립률 폼과 독립된 경로: enabled 1필드만 저장.
      await ref.read(setQoinEnabledUseCaseProvider).call(next);
      if (!mounted) return;
      qoinSnack(
        context,
        next ? QoinMessages.enabledOn : QoinMessages.enabledOff,
      );
    } catch (_) {
      if (!mounted) return;
      qoinSnack(context, QoinMessages.enabledFailed);
    } finally {
      if (mounted) setState(() => _savingEnabled = false);
    }
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final cfgAsync = ref.watch(qoinConfigProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: qoinAppBar(context, 'Qoin 설정'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PartialSection(
              onOpen: () =>
                  _push(const AdminQoinRateHistoryPage(unfinishedOnly: true)),
            ),
            // 전역 카드 + 비상 정지: config 상태에만 묶인다.
            cfgAsync.when(
              loading: () => const _GlobalSkeleton(),
              error: (_, _) => Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: QoinLoadError(
                  compact: true,
                  onRetry: () => ref.invalidate(qoinConfigProvider),
                ),
              ),
              data: (cfg) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  QoinCurrentRateCard.global(cfg: cfg),
                  const SizedBox(height: 8),
                  const Text(
                    '따로 설정하지 않은 브랜드·매장은 이 값을 따라요',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => _push(const AdminQoinGlobalRatePage()),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        cfg == null ? '전역 기본값 설정하기' : '전역 기본값 변경',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  QoinKillSwitchCard(
                    cfg: cfg,
                    saving: _savingEnabled,
                    onToggle: (next) => _onToggleEnabled(cfg!, next),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '범위별 설정',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _ScopeTile(
                    icon: QoinScopeIcons.of(QoinRateScope.brand),
                    title: '브랜드별 적립률',
                    subtitle: _brandSubtitle(ref),
                    onTap: () => _push(const AdminQoinBrandRatesPage()),
                  ),
                  const Divider(height: 1, indent: 16, color: AppColors.border),
                  _ScopeTile(
                    icon: QoinScopeIcons.of(QoinRateScope.store),
                    title: '매장별 적립률',
                    subtitle: _storeSubtitle(ref),
                    onTap: () => _push(const AdminQoinStoreRatesPage()),
                  ),
                  const Divider(height: 1, indent: 16, color: AppColors.border),
                  _ScopeTile(
                    icon: Icons.history_rounded,
                    title: '변경 이력',
                    subtitle: _historySubtitle(ref),
                    onTap: () => _push(const AdminQoinRateHistoryPage()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 부제는 **사실 하나만**. 로딩·실패면 생략 (부가 정보라 에러를 노출하지 않는다).
  String? _brandSubtitle(WidgetRef ref) {
    final brands = ref.watch(qoinAdminBrandsProvider).asData?.value;
    if (brands == null) return null;
    final m = brands.where((b) => !b.qoinAccrualRate.isAbsent).length;
    return m > 0
        ? '브랜드 ${brands.length}곳 · 개별 설정 $m곳'
        : '브랜드 ${brands.length}곳';
  }

  String? _storeSubtitle(WidgetRef ref) {
    final stores = ref.watch(qoinAdminStoresProvider).asData?.value;
    if (stores == null) return null;
    final brands = ref.watch(qoinAdminBrandsProvider).asData?.value;
    final cfgAsync = ref.watch(qoinConfigProvider);
    // `적립 안 함` 수는 해석이 필요하다 — 3소스가 모두 준비됐을 때만 센다 (틀린 숫자 금지).
    if (brands == null || !cfgAsync.hasValue) return '매장 ${stores.length}곳';
    final byId = {for (final b in brands) b.id: b};
    final z = stores
        .where((s) => resolveStoreQoinRate(s, byId, cfgAsync.value).isStopped)
        .length;
    return z > 0 ? '매장 ${stores.length}곳 · 적립 안 함 $z곳' : '매장 ${stores.length}곳';
  }

  String? _historySubtitle(WidgetRef ref) {
    final async = ref.watch(
      qoinAllRateHistoryProvider(QoinPolicy.historyPageSize),
    );
    final list = async.asData?.value;
    if (list == null) return null;
    final first = list.firstOrNull;
    final at = first?.changedAt;
    if (first == null || at == null) return '변경 이력이 없어요';
    return '최근 변경 ${QoinFormatters.dateTime(at, now: DateTime.now()).replaceAll(RegExp(r' \(.\)'), '')}';
  }
}

/// 허브 partial 배너. **최근 이력 페이지(50건) 안에서만 판정한다** (축소 동작) —
/// collectionGroup `status` 필터 쿼리는 복합 인덱스가 필요하고 배포 없이는 검증할 수 없어서 쓰지 않는다
/// (design D10: 실측 불가 시 축소). 실패·로딩이면 조용히 생략한다.
class _PartialSection extends ConsumerWidget {
  const _PartialSection({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref
        .watch(qoinAllRateHistoryProvider(QoinPolicy.historyPageSize))
        .asData
        ?.value;
    if (list == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final open = list.where((c) => c.isUnfinished(now)).toList();
    if (open.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: QoinPartialBanner.hub(
        change: open.first,
        moreCount: open.length - 1,
        onTap: onOpen,
      ),
    );
  }
}

class _ScopeTile extends StatelessWidget {
  const _ScopeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: subtitle == null ? title : '$title, $subtitle',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: AppColors.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textHeading,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 전역 카드 + 비상 정지 자리의 skeleton. `0%` / `3%` 를 그리지 않는다.
class _GlobalSkeleton extends StatelessWidget {
  const _GlobalSkeleton();

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
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_box(80, 13), const SizedBox(height: 10), _box(120, 34)],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
        ),
      ],
    );
  }
}

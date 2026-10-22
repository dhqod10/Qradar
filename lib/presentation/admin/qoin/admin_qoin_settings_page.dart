import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/qoin_formatters.dart';
import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/qoin_config_entity.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/admin/qoin/admin_qoin_brand_rate_edit_page.dart';
import 'package:qradar/presentation/admin/qoin/admin_qoin_brand_rates_page.dart';
import 'package:qradar/presentation/admin/qoin/admin_qoin_global_rate_page.dart';
import 'package:qradar/presentation/admin/qoin/admin_qoin_rate_history_page.dart';
import 'package:qradar/presentation/admin/qoin/admin_qoin_store_rates_page.dart';
import 'package:qradar/presentation/admin/qoin/providers/qoin_admin_providers.dart';
import 'package:qradar/presentation/admin/qoin/widgets/admin_qoin_migration_card.dart';
import 'package:qradar/presentation/admin/widgets/admin_brand_link_audit_card.dart';
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
            // TRANSITIONAL(spec §20.4.5): 임시 마이그레이션 카드. 정리 커밋에서 이 한 줄과 import 를 삭제한다.
            const AdminQoinMigrationCard(),
            // TRANSITIONAL(brand_authorization_hardening §4): 임시 브랜드 링크 점검 카드. 정리 커밋에서 이 한 줄과 import 를 삭제한다.
            const AdminBrandLinkAuditCard(),
            const _PartialSection(),
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
                  _HistoryTile(
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

  /// 부제는 **사실 하나만**. 로딩·실패면 생략한다 — 이 두 부제는 개수 안내(편의 정보)이고, 값이 없다고 해서
  /// 중단·장애를 숨기지 않기 때문이다 (생략했을 때 사용자가 안전하다고 오해할 수 있는 항목은 아래 배너·최근 변경이다).
  String? _brandSubtitle(WidgetRef ref) {
    final brands = ref.watch(qoinAdminBrandsProvider).asData?.value;
    if (brands == null) return null;
    // 꺼진 브랜드가 있으면 돈이 멈춘 쪽이 우선이다 (개별 설정 수를 대체).
    final off = brands.where(_brandOff).length;
    if (off > 0) return '브랜드 ${brands.length}곳 · 사용 안 함 $off곳';
    final m = brands.where((b) => !b.qoinAccrualRate.isAbsent).length;
    return m > 0
        ? '브랜드 ${brands.length}곳 · 개별 설정 $m곳'
        : '브랜드 ${brands.length}곳';
  }

  // TRANSITIONAL(spec §20.4.5): 레거시 0 도 꺼진 것으로 센다.
  static bool _brandOff(BrandEntity b) =>
      b.qoinAccrualEnabled.isDisabled || b.qoinAccrualRate.isLegacyZero;
  static bool _storeOff(StoreEntity s) =>
      s.qoinAccrualEnabled.isDisabled || s.qoinAccrualRate.isLegacyZero;

  /// 매장 자신의 스위치가 꺼진 수 — 해석이 필요 없는 사실이라 매장 스트림만으로 센다.
  String? _storeSubtitle(WidgetRef ref) {
    final stores = ref.watch(qoinAdminStoresProvider).asData?.value;
    if (stores == null) return null;
    final z = stores.where(_storeOff).length;
    return z > 0 ? '매장 ${stores.length}곳 · 사용 안 함 $z곳' : '매장 ${stores.length}곳';
  }
}

/// `변경 이력` 타일 부제 — 로딩 / 에러 / 없음 / 데이터를 서로 다르게 그린다 (조용히 생략 금지).
class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = qoinAllRateHistoryProvider(QoinPolicy.historyPageSize);
    final async = ref.watch(provider);
    return async.when(
      loading: () => _ScopeTile(
        icon: Icons.history_rounded,
        title: '변경 이력',
        subtitleWidget: Container(
          width: 120,
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        subtitle: '불러오는 중',
        onTap: onTap,
      ),
      error: (_, _) => _ScopeTile(
        icon: Icons.history_rounded,
        title: '변경 이력',
        subtitle: '이력을 불러오지 못했어요',
        subtitleWidget: const Row(
          children: [
            Icon(Icons.error_outline_rounded, size: 12, color: AppColors.error),
            SizedBox(width: 4),
            Flexible(
              child: Text(
                '이력을 불러오지 못했어요',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
        trailing: InkWell(
          // 행 탭(내비게이션)과 별도 터치 영역 — 눌러도 이력 화면이 열리지 않는다.
          onTap: () => ref.invalidate(provider),
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: const Center(
              child: Text(
                '다시 시도',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
        onTap: onTap,
      ),
      data: (list) {
        final first = list.firstOrNull;
        final at = first?.changedAt;
        final sub = (first == null || at == null)
            ? '변경 이력이 없어요'
            : '최근 변경 ${QoinFormatters.dateTime(at, now: DateTime.now()).replaceAll(RegExp(r' \(.\)'), '')}';
        return _ScopeTile(
          icon: Icons.history_rounded,
          title: '변경 이력',
          subtitle: sub,
          onTap: onTap,
        );
      },
    );
  }
}

/// 허브 partial 배너 — 데이터 출처는 **브랜드 문서의 포인터**(`qoinBulkStatus`)다 (spec §19.5 D-1).
/// 이력 쿼리(인덱스·50건 윈도우)에 의존하지 않는다. 세 상태를 서로 다르게 그린다:
/// 로딩 = skeleton("아직 모름") / 에러 = 에러 배너("알 수 없음") / 없음 = 아무것도 안 그림("확인된 없음").
/// 에러 때 사라지면 "중단 없음" 과 "알 수 없음" 이 구별되지 않는다 — 이 위젯에 `조용히 생략` 분기는 없다.
class _PartialSection extends ConsumerWidget {
  const _PartialSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(qoinUnfinishedBulkBrandsProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(bottom: 20),
        child: QoinHubBannerSkeleton(),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: QoinHubBannerError(
          onRetry: () => ref.invalidate(qoinAdminBrandsProvider),
        ),
      ),
      data: (open) {
        if (open.isEmpty) return const SizedBox.shrink(); // 확인된 없음
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: QoinHubPartialBanner(
            brandName: open.first.name,
            moreCount: open.length - 1,
            onTap: () {
              // 1건: 그 브랜드 편집 (이어서 적용이 있는 곳). 2건 이상: 브랜드 목록 (`적용 중단됨` 태그로 찾는다).
              final page = open.length == 1
                  ? AdminQoinBrandRateEditPage(brandId: open.first.id)
                  : const AdminQoinBrandRatesPage();
              Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => page));
            },
          ),
        );
      },
    );
  }
}

class _ScopeTile extends StatelessWidget {
  const _ScopeTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String title;

  /// 스크린리더용 부제 문장(및 기본 표시).
  final String? subtitle;

  /// 있으면 [subtitle] 대신 이 위젯을 그린다 (skeleton / 에러 줄).
  final Widget? subtitleWidget;

  /// chevron 자리 대체 (에러 부제의 `다시 시도`).
  final Widget? trailing;
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
                    if (subtitleWidget != null) ...[
                      const SizedBox(height: 2),
                      subtitleWidget!,
                    ] else if (subtitle != null) ...[
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
              trailing ??
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

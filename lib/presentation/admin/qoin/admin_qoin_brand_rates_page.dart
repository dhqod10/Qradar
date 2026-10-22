import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/qoin_bulk_banner.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/qoin_config_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/admin/qoin/admin_qoin_brand_rate_edit_page.dart';
import 'package:qradar/presentation/admin/qoin/providers/qoin_admin_providers.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_admin_ui.dart';
import 'package:qradar/presentation/common/providers/qoin_config_providers.dart';
import 'package:qradar/presentation/common/providers/qoin_rate_providers.dart';
import 'package:qradar/presentation/common/widgets/approval_status_badge.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_load_error.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_labels.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_source_badge.dart';

/// 브랜드별 적립률 목록. **편집하지 않는다** — 행 탭은 항상 편집 페이지로의 이동이다 (인라인 편집 금지: 범위 오입력 방어).
/// 승인 전 브랜드도 포함하고 상태 배지로 구분한다 (design D3).
/// 브랜드·산하 매장·전역 3소스가 모두 준비되기 전에는 숫자를 그리지 않는다.
class AdminQoinBrandRatesPage extends ConsumerStatefulWidget {
  const AdminQoinBrandRatesPage({super.key});

  @override
  ConsumerState<AdminQoinBrandRatesPage> createState() =>
      _AdminQoinBrandRatesPageState();
}

class _AdminQoinBrandRatesPageState
    extends ConsumerState<AdminQoinBrandRatesPage> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brandsAsync = ref.watch(qoinAdminBrandsProvider);
    final storesAsync = ref.watch(qoinAdminStoresProvider);
    final cfgAsync = ref.watch(qoinConfigProvider);

    Widget body;
    final firstError = [
      brandsAsync,
      storesAsync,
      cfgAsync,
    ].where((a) => a.hasError && !a.hasValue).firstOrNull;
    if (firstError != null) {
      body = QoinLoadError(
        title: '브랜드를 불러오지 못했어요',
        onRetry: () {
          ref.invalidate(qoinAdminBrandsProvider);
          ref.invalidate(qoinAdminStoresProvider);
          ref.invalidate(qoinConfigProvider);
        },
      );
    } else if (!brandsAsync.hasValue ||
        !storesAsync.hasValue ||
        !cfgAsync.hasValue) {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [for (var i = 0; i < 4; i++) const _RowSkeleton()],
      );
    } else {
      body = _buildList(
        brandsAsync.requireValue,
        storesAsync.requireValue,
        cfgAsync.requireValue,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: qoinAppBar(context, '브랜드별 적립률'),
      body: body,
    );
  }

  Widget _buildList(
    List<BrandEntity> brands,
    List<StoreEntity> stores,
    QoinConfigEntity? cfg,
  ) {
    final counts = <String, int>{};
    final overrides = <String, int>{};
    for (final s in stores) {
      final id = s.brandId;
      if (id == null) continue;
      counts[id] = (counts[id] ?? 0) + 1;
      if (!s.qoinAccrualRate.isAbsent) overrides[id] = (overrides[id] ?? 0) + 1;
    }
    // 중단 판정은 브랜드 문서의 포인터로 한다 (이력 쿼리·인덱스 의존 없음 — 허브 배너와 같은 근거).
    final now = DateTime.now();

    final q = _searchCtrl.text.trim().toLowerCase();
    final sorted = [...brands]..sort((a, b) => a.name.compareTo(b.name));
    final shown = q.isEmpty
        ? sorted
        : sorted.where((b) => b.name.toLowerCase().contains(q)).toList();

    if (brands.isEmpty) {
      return const _EmptyState(
        icon: Icons.business_outlined,
        title: '아직 등록된 브랜드가 없어요',
        message: '브랜드가 등록되면 여기에서 적립률을 설정할 수 있어요',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: SizedBox(
            height: 44,
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 15, color: AppColors.textBody),
              decoration: InputDecoration(
                hintText: '브랜드 이름 검색',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textMuted,
                ),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '브랜드 ${shown.length}곳',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: shown.isEmpty
              ? const _EmptyState(
                  icon: Icons.search_off_rounded,
                  title: '검색 결과가 없어요',
                  message: '다른 이름으로 찾아보세요',
                  iconSize: 48,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: shown.length,
                  itemBuilder: (context, i) {
                    final b = shown[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _BrandRow(
                        brand: b,
                        cfg: cfg,
                        storeCount: counts[b.id] ?? 0,
                        overrideCount: overrides[b.id] ?? 0,
                        unfinished: resolveBulkBanner(b, now).isUnfinished,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow({
    required this.brand,
    required this.cfg,
    required this.storeCount,
    required this.overrideCount,
    required this.unfinished,
  });

  final BrandEntity brand;
  final QoinConfigEntity? cfg;
  final int storeCount;
  final int overrideCount;
  final bool unfinished;

  @override
  Widget build(BuildContext context) {
    final e = resolveBrandQoinRate(brand, cfg);
    final kind = QoinRateBadgeKind.of(e, target: QoinRateScope.brand);
    final sub = overrideCount > 0
        ? '산하 매장 $storeCount곳 · 개별 설정 $overrideCount곳'
        : '산하 매장 $storeCount곳';

    return Semantics(
      button: true,
      label:
          '${brand.name}, $sub, ${e.isDisabled ? '' : '적립률 '}${QoinRateValueLabel.spokenEffective(e)}, ${kind.label}. 탭하면 적립률 설정',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AdminQoinBrandRateEditPage(brandId: brand.id),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                brand.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textHeading,
                                ),
                              ),
                            ),
                            if (brand.status !=
                                EntityApprovalStatus.approved) ...[
                              const SizedBox(width: 6),
                              ApprovalStatusBadge(status: brand.status),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Text(
                              sub,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            if (unfinished)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(
                                    alpha: 0.18,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  '적용 중단됨',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textBody,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      QoinRateValueText(effective: e, kind: kind),
                      const SizedBox(height: 4),
                      QoinRateSourceBadge(kind: kind),
                    ],
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget box(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return Container(
      height: 76,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [box(120, 14), box(48, 16)],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.iconSize = 56,
  });
  final IconData icon;
  final String title;
  final String message;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              title,
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
      ),
    );
  }
}

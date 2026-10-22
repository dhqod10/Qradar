import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/qoin_config_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/admin/qoin/admin_qoin_store_rate_edit_page.dart';
import 'package:qradar/presentation/admin/qoin/providers/qoin_admin_providers.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_admin_ui.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_filter_chip.dart';
import 'package:qradar/presentation/common/providers/qoin_config_providers.dart';
import 'package:qradar/presentation/common/providers/qoin_rate_providers.dart';
import 'package:qradar/presentation/common/widgets/approval_status_badge.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_load_error.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_labels.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_source_badge.dart';

/// 출처 필터. 칩 라벨 = 배지 라벨과 **글자 그대로 같다** (같은 상수 [QoinRateLabels]).
enum _SourceFilter {
  all('전체', null),
  storeSet(QoinRateLabels.storeSet, QoinRateBadgeKind.storeSet),
  brandInherit(QoinRateLabels.brandInherit, QoinRateBadgeKind.brandInherit),
  globalInherit(QoinRateLabels.globalInherit, QoinRateBadgeKind.globalInherit),
  stopped(QoinRateLabels.stopped, QoinRateBadgeKind.stopped);

  const _SourceFilter(this.label, this.kind);
  final String label;
  final QoinRateBadgeKind? kind;
}

/// 매장 목록 브랜드 필터: 전체 / 개인 매장 / 특정 브랜드.
class _BrandFilter {
  const _BrandFilter.all() : personal = false, brandId = null;
  const _BrandFilter.personal() : personal = true, brandId = null;
  const _BrandFilter.brand(String id) : personal = false, brandId = id;
  final bool personal;
  final String? brandId;
  bool get isAll => !personal && brandId == null;
}

class _Item {
  const _Item(this.store, this.effective, this.kind);
  final StoreEntity store;
  final EffectiveQoinRate effective;
  final QoinRateBadgeKind kind;
}

/// 매장별 적립률 목록 (대량 대응). 검색 + 필터를 목록 위에 고정한다. 클라이언트 메모리 필터, `ListView.builder`.
/// **편집하지 않는다** — 행 탭은 편집 페이지 이동이다. 승인 전 매장도 포함 + 상태 배지.
/// 해석은 목록 단위로 한 번 (브랜드 맵 1개 + 전역 1개) — 타일마다 스트림을 만들지 않는다.
class AdminQoinStoreRatesPage extends ConsumerStatefulWidget {
  const AdminQoinStoreRatesPage({super.key});

  @override
  ConsumerState<AdminQoinStoreRatesPage> createState() =>
      _AdminQoinStoreRatesPageState();
}

class _AdminQoinStoreRatesPageState
    extends ConsumerState<AdminQoinStoreRatesPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  _BrandFilter _brandFilter = const _BrandFilter.all();
  _SourceFilter _source = _SourceFilter.all;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() => _query = _searchCtrl.text.trim().toLowerCase());
        }
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _resetFilters() {
    _searchCtrl.clear();
    setState(() {
      _query = '';
      _brandFilter = const _BrandFilter.all();
      _source = _SourceFilter.all;
    });
  }

  @override
  Widget build(BuildContext context) {
    final storesAsync = ref.watch(qoinAdminStoresProvider);
    final brandsAsync = ref.watch(qoinAdminBrandsProvider);
    final cfgAsync = ref.watch(qoinConfigProvider);

    final failed = [
      storesAsync,
      brandsAsync,
      cfgAsync,
    ].where((a) => a.hasError && !a.hasValue).isNotEmpty;
    final ready =
        storesAsync.hasValue && brandsAsync.hasValue && cfgAsync.hasValue;

    Widget content;
    if (failed) {
      // 하나라도 에러면 목록 전체 에러 (일부만 보여주면 상속 값이 조용히 틀린다). 필터 영역 숨김.
      content = QoinLoadError(
        title: '매장을 불러오지 못했어요',
        onRetry: () {
          ref.invalidate(qoinAdminStoresProvider);
          ref.invalidate(qoinAdminBrandsProvider);
          ref.invalidate(qoinConfigProvider);
        },
      );
    } else if (!ready) {
      content = Column(
        children: [
          _FilterBar(
            searchCtrl: _searchCtrl,
            brandLabel: '브랜드: 전체',
            brandActive: false,
            source: _source,
            enabled: false,
            onBrand: () {},
            onSource: (_) {},
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [for (var i = 0; i < 6; i++) const _RowSkeleton()],
            ),
          ),
        ],
      );
    } else {
      content = _buildReady(
        storesAsync.requireValue,
        brandsAsync.requireValue,
        cfgAsync.requireValue,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: qoinAppBar(context, '매장별 적립률'),
      body: content,
    );
  }

  Widget _buildReady(
    List<StoreEntity> stores,
    List<BrandEntity> brands,
    QoinConfigEntity? cfg,
  ) {
    if (stores.isEmpty) {
      return const _Empty(
        icon: Icons.storefront_outlined,
        title: '아직 등록된 매장이 없어요',
        message: '매장이 등록되면 여기에서 적립률을 설정할 수 있어요',
      );
    }
    final byId = {for (final b in brands) b.id: b};
    final items = [
      for (final s in stores)
        () {
          final e = resolveStoreQoinRate(s, byId, cfg);
          return _Item(
            s,
            e,
            QoinRateBadgeKind.of(e, target: QoinRateScope.store),
          );
        }(),
    ]..sort((a, b) => a.store.name.compareTo(b.store.name));

    final filtered = items.where((it) {
      final s = it.store;
      if (_query.isNotEmpty &&
          !s.name.toLowerCase().contains(_query) &&
          !s.address.toLowerCase().contains(_query)) {
        return false;
      }
      final bf = _brandFilter;
      if (bf.personal && (s.brandId != null && s.brandId!.isNotEmpty)) {
        return false;
      }
      if (bf.brandId != null && s.brandId != bf.brandId) return false;
      if (_source.kind != null && it.kind != _source.kind) return false;
      return true;
    }).toList();

    final brandLabel = _brandFilter.isAll
        ? '브랜드: 전체'
        : _brandFilter.personal
        ? '개인 매장'
        : '브랜드: ${byId[_brandFilter.brandId]?.name ?? ''}';

    return Column(
      children: [
        _FilterBar(
          searchCtrl: _searchCtrl,
          brandLabel: brandLabel,
          brandActive: !_brandFilter.isAll,
          source: _source,
          enabled: true,
          onBrand: () => _pickBrand(brands),
          onSource: (s) => setState(() => _source = s),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '매장 ${filtered.length}곳',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _Empty(
                  icon: Icons.filter_alt_off_outlined,
                  title: '조건에 맞는 매장이 없어요',
                  message: '다른 조건으로 찾아보세요',
                  iconSize: 48,
                  action: TextButton(
                    onPressed: _resetFilters,
                    child: const Text('필터 초기화'),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final it = filtered[i];
                    final brandName = it.store.brandId == null
                        ? null
                        : byId[it.store.brandId]?.name;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _StoreRow(item: it, brandName: brandName),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _pickBrand(List<BrandEntity> brands) async {
    final sorted = [...brands]..sort((a, b) => a.name.compareTo(b.name));
    final picked = await showModalBottomSheet<_BrandFilter>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('전체'),
                onTap: () => Navigator.pop(ctx, const _BrandFilter.all()),
              ),
              ListTile(
                title: const Text('개인 매장'),
                onTap: () => Navigator.pop(ctx, const _BrandFilter.personal()),
              ),
              for (final b in sorted)
                ListTile(
                  title: Text(b.name),
                  onTap: () => Navigator.pop(ctx, _BrandFilter.brand(b.id)),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _brandFilter = picked);
  }
}

/// 검색 + 브랜드 필터 + 출처 필터 칩. 목록 위에 고정.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.searchCtrl,
    required this.brandLabel,
    required this.brandActive,
    required this.source,
    required this.enabled,
    required this.onBrand,
    required this.onSource,
  });

  final TextEditingController searchCtrl;
  final String brandLabel;
  final bool brandActive;
  final _SourceFilter source;
  final bool enabled;
  final VoidCallback onBrand;
  final ValueChanged<_SourceFilter> onSource;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: c),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: SizedBox(
            height: 44,
            child: TextField(
              controller: searchCtrl,
              enabled: enabled,
              style: const TextStyle(fontSize: 15, color: AppColors.textBody),
              decoration: InputDecoration(
                hintText: '매장 이름·주소 검색',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textMuted,
                ),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                contentPadding: EdgeInsets.zero,
                border: border(AppColors.border),
                enabledBorder: border(AppColors.border),
                focusedBorder: border(AppColors.primary),
                disabledBorder: border(AppColors.border),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              QoinFilterChip(
                label: brandLabel,
                selected: false,
                outlined: brandActive,
                trailing: Icons.arrow_drop_down_rounded,
                onTap: enabled ? onBrand : null,
              ),
              for (final s in _SourceFilter.values) ...[
                const SizedBox(width: 8),
                QoinFilterChip(
                  label: s.label,
                  selected: source == s,
                  onTap: enabled ? () => onSource(s) : null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StoreRow extends StatelessWidget {
  const _StoreRow({required this.item, required this.brandName});
  final _Item item;
  final String? brandName;

  @override
  Widget build(BuildContext context) {
    final s = item.store;
    final e = item.effective;
    final belongs = (brandName == null || brandName!.isEmpty)
        ? '개인 매장'
        : brandName!;
    final origin = e.isStopped
        ? (e.source == QoinRateSource.brand ? ', 브랜드에서 설정' : ', 매장에서 설정')
        : '';
    return Semantics(
      button: true,
      label:
          '${s.name}, $belongs 소속, '
          '${e.isStopped ? '' : '적립률 '}${QoinRateValueLabel.spokenEffective(e)}'
          '${e.isStopped ? '' : ', ${item.kind.label}'}$origin. 탭하면 적립률 설정',
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
              builder: (_) => AdminQoinStoreRateEditPage(storeId: s.id),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                s.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textHeading,
                                ),
                              ),
                            ),
                            if (s.status != EntityApprovalStatus.approved) ...[
                              const SizedBox(width: 6),
                              ApprovalStatusBadge(status: s.status),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          belongs,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        if (s.address.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            s.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      QoinRateValueText(effective: e, kind: item.kind),
                      const SizedBox(height: 4),
                      QoinRateSourceBadge(kind: item.kind),
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
    return Container(
      height: 88,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.message,
    this.iconSize = 56,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final double iconSize;
  final Widget? action;

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
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}

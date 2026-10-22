import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/admin/qoin/providers/qoin_admin_providers.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_accrual_switch_card.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_admin_ui.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_current_rate_card.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_rate_chain.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_rate_edit_form.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_scope_band.dart';
import 'package:qradar/presentation/common/providers/qoin_di_providers.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_load_error.dart';

/// 매장 적립률 편집 (얇은 페이지). 하위 매장 처리 섹션은 없다 — 브랜드 전용.
/// `적립 사용` 스위치는 적립률 폼(저장 버튼) **아래** 독립 카드다 — 저장 버튼에 묶이지 않고 확인 다이얼로그를 거쳐 즉시 적용된다.
class AdminQoinStoreRateEditPage extends ConsumerWidget {
  const AdminQoinStoreRateEditPage({super.key, required this.storeId});
  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(qoinAdminStoreByIdProvider(storeId));
    final effAsync = ref.watch(qoinAdminStoreEffectiveProvider(storeId));

    Widget body;
    if (storeAsync.hasError || effAsync.hasError) {
      body = QoinLoadError(
        onRetry: () {
          ref.invalidate(qoinAdminStoresProvider);
        },
      );
    } else if (!storeAsync.hasValue) {
      body = const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: _Skeleton(),
      );
    } else if (storeAsync.requireValue == null) {
      // 대상이 삭제됨/없음: 해석 로딩을 기다리지 않고 바로 안내한다.
      body = const _NotFound();
    } else if (!effAsync.hasValue) {
      body = const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: _Skeleton(),
      );
    } else {
      body = _Body(
        store: storeAsync.requireValue!,
        effective: effAsync.requireValue,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: qoinAppBar(context, '매장 적립률'),
      body: body,
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.store, required this.effective});
  final StoreEntity store;
  final EffectiveQoinRate effective;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final QoinSwitchFocusController _switchFocus = QoinSwitchFocusController();

  @override
  void dispose() {
    _switchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final effective = widget.effective;
    final brandId = store.brandId;
    final brandName = (brandId == null || brandId.isEmpty)
        ? null
        : ref.watch(qoinAdminBrandByIdProvider(brandId)).asData?.value?.name;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QoinScopeBand(
            scope: QoinRateScope.store,
            targetName: store.name,
            detail: QoinScopeBandDetail.store(brandName: brandName),
          ),
          const SizedBox(height: 16),
          QoinCurrentRateCard.target(
            effective: effective,
            target: QoinRateScope.store,
          ),
          const SizedBox(height: 12),
          QoinRateChain(effective: effective, target: QoinRateScope.store),
          const SizedBox(height: 20),
          QoinRateEditForm(
            scope: QoinRateScope.store,
            targetName: store.name,
            brandName: brandName,
            current: store.qoinAccrualRate,
            effective: effective,
            saveLabel: '매장 설정 저장',
            onGoToSwitch: _switchFocus.go,
            onSubmit: (s) async {
              try {
                await ref.read(setQoinAccrualRateUseCaseProvider)(
                  scope: QoinRateScope.store,
                  targetId: store.id,
                  value: s.value,
                  reason: s.reason,
                );
                if (!context.mounted) return;
                qoinSnack(context, QoinMessages.saved(s.value, global: false));
              } catch (e) {
                if (context.mounted) {
                  qoinSnack(context, QoinMessages.failure(e));
                }
                rethrow;
              }
            },
          ),
          // 저장 버튼 아래 — 적립률 폼과 시각적으로 갈라 둔다 (gap 32).
          const SizedBox(height: 32),
          const _SwitchSectionLabel(),
          const SizedBox(height: 6),
          QoinAccrualSwitchCard(
            scope: QoinRateScope.store,
            targetId: store.id,
            targetName: store.name,
            switchSetting: store.qoinAccrualEnabled,
            effective: effective,
            controller: _switchFocus,
          ),
        ],
      ),
    );
  }
}

class _SwitchSectionLabel extends StatelessWidget {
  const _SwitchSectionLabel();

  @override
  Widget build(BuildContext context) => const Text(
    '적립 사용',
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.textMuted,
    ),
  );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

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
    return Column(children: [box(76), box(120)]);
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
              Icons.storefront_outlined,
              size: 56,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            const Text(
              '매장을 찾을 수 없어요',
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

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/qoin_config_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/presentation/admin/qoin/providers/qoin_admin_providers.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_admin_ui.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_current_rate_card.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_rate_edit_form.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_scope_band.dart';
import 'package:qradar/presentation/common/providers/qoin_config_providers.dart';
import 'package:qradar/presentation/common/providers/qoin_di_providers.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_load_error.dart';

/// 전역 기본값 편집 (얇은 페이지). 전역 입력이 허브를 열자마자 노출되면 가장 파급이 큰 범위가
/// 가장 쉬운 범위가 된다 — 범위 오입력 방어의 연장선으로 별도 페이지로 분리했다 (design D4).
///
/// 설정 방식 라디오 없음: 전역은 항상 유효한 숫자여야 한다. 전역 중단은 비상 정지 스위치의 일.
/// 이 페이지에는 검증 카피가 없다 (`QoinRateEditForm` 소유).
class AdminQoinGlobalRatePage extends ConsumerWidget {
  const AdminQoinGlobalRatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(qoinConfigProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: qoinAppBar(context, '전역 기본값'),
      body: async.when(
        // 값을 모른 채 덮어쓰는 사고 방지: 로딩/에러 중에는 입력·저장을 노출하지 않는다.
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (_, _) =>
            QoinLoadError(onRetry: () => ref.invalidate(qoinConfigProvider)),
        data: (cfg) => _Body(cfg: cfg),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.cfg});
  final QoinConfigEntity? cfg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = cfg?.accrualRateSetting ?? QoinRateSetting.absent;
    final effective = resolveEffectiveQoinRate(
      store: QoinRateSetting.absent,
      brand: QoinRateSetting.absent,
      global: setting,
      hasBrand: false,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const QoinScopeBand(
            scope: QoinRateScope.global,
            detail: QoinScopeBandDetail.global,
          ),
          const SizedBox(height: 16),
          QoinCurrentRateCard.global(cfg: cfg),
          if (cfg != null && !cfg!.enabled && cfg!.accrualRate != null) ...[
            const SizedBox(height: 8),
            const Text(
              '적립은 ‘적립 사용’ 을 켜야 시작돼요',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 20),
          QoinRateEditForm(
            scope: QoinRateScope.global,
            current: setting,
            effective: effective,
            saveLabel: '전역 기본값 저장',
            followingStores: ref.watch(qoinGlobalFollowingStoresProvider),
            onSubmit: (s) async {
              try {
                final r = await ref.read(setQoinAccrualRateUseCaseProvider)(
                  scope: QoinRateScope.global,
                  value: s.value,
                  reason: s.reason,
                );
                if (!context.mounted) return;
                // changed 를 성공 분기보다 먼저 본다 — 값이 같으면 "변경했어요" 라고 말하지 않는다 (spec §21.3-b).
                if (!r.changed) {
                  qoinSnack(context, QoinMessages.rateUnchanged(r, s.value));
                  return;
                }
                qoinSnack(context, QoinMessages.saved(s.value, global: true));
              } catch (e) {
                if (context.mounted) {
                  qoinSnack(context, QoinMessages.failure(e));
                }
                rethrow;
              }
            },
          ),
        ],
      ),
    );
  }
}

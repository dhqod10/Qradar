import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_results.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_admin_ui.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_rate_confirm_dialog.dart';
import 'package:qradar/presentation/common/providers/qoin_di_providers.dart';

/// 끝나지 않은 일괄 적용 **이어서 적용** 흐름. 브랜드 편집 / 이력 / (허브→이력) 가 모두 이 한 곳을 쓴다.
///
/// 확인 다이얼로그(체크박스를 다시 요구) → 실행. 성공이면 결과, 취소면 null,
/// 실패하면 SnackBar 를 띄우고 null 을 돌려준다 (배너는 유지된다).
/// [onRunning] 으로 호출 화면이 실행 중 덮개 / `PopScope` 를 걸 수 있다.
Future<QoinBulkApplyResult?> runBulkResume(
  BuildContext context,
  WidgetRef ref,
  QoinRateChangeEntity change, {
  ValueChanged<bool>? onRunning,
}) async {
  final total = change.totalCount ?? change.processedCount ?? 0;
  final processed = change.processedCount ?? 0;
  final remaining = (total - processed).clamp(0, total);

  final ok = await QoinRateConfirmDialog.show(
    context,
    scope: QoinRateScope.brand,
    targetName: change.targetName,
    action: QoinConfirmAction.resume,
    current: QoinConfirmValue.none,
    next: QoinConfirmValue.none,
    bulk: QoinBulkConfirm(
      total: 0,
      overridden: 0,
      overriddenStopped: 0,
      mode: QoinBulkMode.overwrite,
      remaining: remaining,
    ),
  );
  if (!ok || !context.mounted) return null;

  onRunning?.call(true);
  try {
    return await ref.read(applyBrandQoinRateUseCaseProvider)(
      brandId: change.targetId,
      mode: QoinBulkMode.overwrite,
      resumeHistoryId: change.id,
    );
  } catch (e) {
    if (context.mounted) {
      qoinSnack(context, QoinMessages.failure(e, resume: true));
    }
    return null;
  } finally {
    onRunning?.call(false);
  }
}

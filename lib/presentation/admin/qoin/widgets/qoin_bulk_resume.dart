import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_results.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_admin_ui.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_rate_confirm_dialog.dart';
import 'package:qradar/presentation/common/providers/qoin_di_providers.dart';

/// 끝나지 않은 일괄 적용 **이어서 적용** 흐름. 브랜드 편집 / 이력 가 모두 이 한 곳을 쓴다.
///
/// 확인 다이얼로그(체크박스 없음) -> 실행. 성공이면 결과, 취소면 null,
/// 실패하면 SnackBar 를 띄우고 null 을 돌려준다 (배너는 유지된다).
/// [onRunning] 으로 호출 화면이 실행 중 덮개 / `PopScope` 를 걸 수 있다.
///
/// [historyId] 는 브랜드 문서 포인터의 `qoinBulkHistoryId` (또는 포인터와 일치하는 이력 행의 id) 다.
/// [remaining] 을 모르면(본문 수치 읽기 실패) null — 다이얼로그가 숫자 없이 말한다.
Future<QoinBulkApplyResult?> runBulkResume(
  BuildContext context,
  WidgetRef ref, {
  required String brandId,
  required String brandName,
  required String historyId,
  int? remaining,
  ValueChanged<bool>? onRunning,
}) async {
  final ok = await QoinRateConfirmDialog.show(
    context,
    scope: QoinRateScope.brand,
    targetName: brandName,
    action: QoinConfirmAction.resume,
    current: QoinConfirmValue.none,
    next: QoinConfirmValue.none,
    bulk: QoinBulkConfirm(
      total: 0,
      overridden: 0,
      mode: QoinBulkMode.overwrite,
      remaining: remaining,
    ),
  );
  if (!ok || !context.mounted) return null;

  onRunning?.call(true);
  try {
    return await ref.read(applyBrandQoinRateUseCaseProvider)(
      brandId: brandId,
      mode: QoinBulkMode.overwrite,
      resumeHistoryId: historyId,
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

/// 남은 매장 수 = 전체 - 처리. 이력 문서 수치를 모르면 null.
int? bulkRemaining(QoinRateChangeEntity? progress) {
  final total = progress?.totalCount;
  if (total == null) return null;
  return (total - (progress?.processedCount ?? 0)).clamp(0, total);
}

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/qoin_formatters.dart';
import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/presentation/common/providers/qoin_rate_providers.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_partial_banner.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_labels.dart';

/// 이력을 보는 사람. admin 만 변경자 이름·`이어서 적용` 을 본다.
enum QoinHistoryViewer { admin, reader }

/// 적립률 변경 이력 1행. admin(전체) / 점주·브랜드(자기 것) 가 같은 타일을 쓴다.
/// **행 탭 동작 없음** (chevron·ripple 없음) — 이력은 읽는 곳이다.
class QoinRateHistoryTile extends ConsumerWidget {
  const QoinRateHistoryTile({
    super.key,
    required this.change,
    required this.viewer,
    required this.now,
    this.onResume,
  });

  final QoinRateChangeEntity change;
  final QoinHistoryViewer viewer;
  final DateTime now;

  /// admin 의 `이어서 적용`. reader 에게는 항상 무시된다.
  final void Function(QoinRateChangeEntity change)? onResume;

  bool get _isEnabledField => change.field == QoinRateField.enabled;

  String _scopeLine() {
    final name = change.targetName;
    if (change.scope == QoinRateScope.global || name.isNotEmpty) {
      return QoinScopeLabel.of(change.scope, name);
    }
    // 대상명이 박제되지 않은 옛 이력.
    return change.scope == QoinRateScope.brand ? '브랜드' : '매장';
  }

  String _before() => _isEnabledField
      ? QoinRateValueLabel.enabled(change.beforeEnabled)
      : QoinRateValueLabel.history(change.beforeRate);

  String _after() => _isEnabledField
      ? QoinRateValueLabel.enabled(change.afterEnabled)
      : QoinRateValueLabel.history(change.afterRate);

  String _spokenBefore() => _isEnabledField
      ? QoinRateValueLabel.enabled(change.beforeEnabled)
      : QoinRateValueLabel.spokenHistory(change.beforeRate);

  String _spokenAfter() => _isEnabledField
      ? QoinRateValueLabel.enabled(change.afterEnabled)
      : QoinRateValueLabel.spokenHistory(change.afterRate);

  String _uidTail(String uid) =>
      uid.length <= 4 ? uid : uid.substring(uid.length - 4);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = viewer == QoinHistoryViewer.admin;
    final unfinished = change.isUnfinished(now);
    final running = change.isRunning(now);

    // 변경자 표기.
    final bool unknownActor = change.changedBy == null;
    String actor;
    if (!isAdmin) {
      actor = '관리자';
    } else if (unknownActor) {
      actor = '변경자 알 수 없음 (직접 수정)';
    } else {
      final uid = change.changedBy!;
      final name = ref.watch(qoinChangerNameProvider(uid)).asData?.value;
      actor = (name != null && name.isNotEmpty) ? name : '관리자 ${_uidTail(uid)}';
    }
    final reason = change.reason;
    final metaText = reason == null || reason.isEmpty
        ? actor
        : '$actor · 사유: $reason';

    final modeText = change.bulkMode == QoinBulkMode.overwrite
        ? '개별 설정 덮어쓰기'
        : '개별 설정 보존';
    final countText = _bulkCountText();

    final spoken = StringBuffer()
      ..write(QoinFormatters.dateTimeSpoken(change.changedAt ?? now))
      ..write('. ${_scopeLine()}. ')
      ..write(_isEnabledField ? '적립 상태를 ' : '적립률을 ')
      ..write('${_spokenBefore()}에서 ${_spokenAfter()}'
          '${QoinRateValueLabel.particleEuroOrRo(_spokenAfter())} 변경.');
    if (change.isBulk) {
      spoken.write(' 일괄 적용, $modeText.');
      if (countText != null) spoken.write(' $countText.');
    }
    spoken.write(
      unknownActor && isAdmin
          ? ' 변경자를 알 수 없음, 직접 수정.'
          : ' 변경자 $actor.',
    );
    if (reason != null && reason.isNotEmpty) spoken.write(' 사유 $reason');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Semantics(
        container: true,
        label: spoken.toString(),
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isEnabledField
                    ? Icons.power_settings_new_rounded
                    : QoinScopeIcons.of(change.scope),
                size: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _scopeLine(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHeading,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        change.changedAt == null
                            ? ''
                            : QoinFormatters.dateTime(
                                change.changedAt!,
                                now: now,
                              ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ExcludeSemantics(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            _before(),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            _after(),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textHeading,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (change.isBulk) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          height: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '일괄 적용',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textBody,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            modeText,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textBody,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (countText != null && !unfinished && !running) ...[
                      const SizedBox(height: 4),
                      Text(
                        countText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textBody,
                        ),
                      ),
                    ],
                    if (running) ...[
                      const SizedBox(height: 6),
                      const Row(
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            '적용 중…',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (unknownActor && isAdmin) ...[
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          metaText,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (unfinished)
                    QoinPartialBanner.inRow(
                      change: change,
                      onResume: isAdmin && onResume != null
                          ? () => onResume!(change)
                          : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 일괄 적용 4행: `매장 {n}곳 적용` + (덮어쓰기) ` · 개별 설정 {m}곳 초기화`. 서버 수치가 없으면 null.
  String? _bulkCountText() {
    final n = change.affectedCount;
    if (!change.isBulk || n == null) return null;
    final base = '매장 $n곳 적용';
    if (change.bulkMode == QoinBulkMode.overwrite) {
      final m = change.clearedCount ?? 0;
      return '$base · 개별 설정 $m곳 초기화';
    }
    return base;
  }
}

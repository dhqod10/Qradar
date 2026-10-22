import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/qoin_formatters.dart';
import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/presentation/common/providers/qoin_rate_providers.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_partial_banner.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_labels.dart';

/// 이력을 보는 사람. **뷰어 역할**로 분기한다 (행 데이터가 아니라 — N8).
/// - [admin] 변경자 이름·`이어서 적용`·브랜드 이력 링크를 본다.
/// - [brand] 해당 브랜드 보유자 (`role == 'brand'`). 브랜드 이력 링크를 본다 (Rules `isBrandHolder`).
/// - [owner] 가맹점주. 브랜드 이력을 **읽을 수 없다** (Rules) → 링크도 탭 타깃도 만들지 않는다.
enum QoinHistoryViewer {
  admin,
  brand,
  owner;

  bool get isAdmin => this == admin;

  /// `clearByBulk` 행에서 브랜드 이력으로 가는 링크를 보일 수 있는 뷰어.
  bool get canOpenBrandHistory => this == admin || this == brand;
}

/// 적립률 변경 이력 1행. admin(전체) / 점주·브랜드(자기 것) 가 같은 타일을 쓴다.
/// **행 탭 동작 없음** (chevron·ripple 없음) — 이력은 읽는 곳이다.
class QoinRateHistoryTile extends ConsumerWidget {
  const QoinRateHistoryTile({
    super.key,
    required this.change,
    required this.viewer,
    required this.now,
    this.onResume,
    this.onOpenBrandHistory,
  });

  final QoinRateChangeEntity change;
  final QoinHistoryViewer viewer;
  final DateTime now;

  /// admin 의 `이어서 적용`. reader 에게는 항상 무시된다.
  final void Function(QoinRateChangeEntity change)? onResume;

  /// `clearByBulk` 행의 `브랜드 이력에서 보기`. 뷰어가 [QoinHistoryViewer.canOpenBrandHistory] 이고 `bulkHistoryId` 가 있을 때만
  /// 링크를 그린다. owner 에게는 이 콜백이 있어도 무시한다.
  final void Function(QoinRateChangeEntity change)? onOpenBrandHistory;

  bool get _isGlobalEnabled => change.field == QoinRateField.globalEnabled;
  bool get _isSwitchField => change.field == QoinRateField.accrualEnabled;
  bool get _isClearByBulk => change.op == QoinRateChangeOp.clearByBulk;
  bool get _isMigration => change.source == QoinRateChangeSource.migration;
  bool get _isUnknownChange =>
      change.op == QoinRateChangeOp.unknown ||
      change.source == QoinRateChangeSource.unknown;
  bool get _beforeInvalid => change.beforeState == QoinBeforeState.invalid;

  String _scopeLine() {
    final name = change.targetName;
    if (change.scope == QoinRateScope.global || name.isNotEmpty) {
      return QoinScopeLabel.of(change.scope, name);
    }
    // 대상명이 박제되지 않은 옛 이력.
    return change.scope == QoinRateScope.brand ? '브랜드' : '매장';
  }

  String _before() {
    if (_isGlobalEnabled) return QoinRateValueLabel.enabled(change.beforeEnabled);
    if (_isSwitchField) {
      return QoinRateValueLabel.historySwitch(
        change.beforeEnabled,
        invalid: _beforeInvalid,
      );
    }
    if (_beforeInvalid) return QoinRateLabels.needsCheck;
    return QoinRateValueLabel.history(change.beforeRate);
  }

  String _after() {
    if (_isGlobalEnabled) return QoinRateValueLabel.enabled(change.afterEnabled);
    if (_isSwitchField) return QoinRateValueLabel.historySwitch(change.afterEnabled);
    return QoinRateValueLabel.history(change.afterRate);
  }

  String _spokenBefore() {
    if (_isGlobalEnabled || _isSwitchField || _beforeInvalid) return _before();
    return QoinRateValueLabel.spokenHistory(change.beforeRate);
  }

  String _spokenAfter() => _isSwitchField || _isGlobalEnabled || _beforeInvalid
      ? _after()
      : QoinRateValueLabel.spokenHistory(change.afterRate);

  String _uidTail(String uid) =>
      uid.length <= 4 ? uid : uid.substring(uid.length - 4);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = viewer.isAdmin;
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
      if (_isMigration) actor = '$actor (이전 작업)';
    }
    // 마이그레이션의 사유는 서버의 고정 문구라 4행 문장이 대신한다.
    final reason = _isMigration ? null : change.reason;
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
      ..write(
        _isGlobalEnabled
            ? '적립 상태를 '
            : _isSwitchField
            ? '적립 사용 여부를 '
            : '적립률을 ',
      )
      ..write('${_spokenBefore()}에서 ${_spokenAfter()}'
          '${QoinRateValueLabel.particleEuroOrRo(_spokenAfter())} 변경.');
    if (change.isBulk) {
      spoken.write(' 일괄 적용, $modeText.');
      if (countText != null) spoken.write(' $countText.');
      if (change.brandDisabled == true) {
        spoken.write(' $_brandOffLine.');
      } else if ((change.disabledUntouchedCount ?? 0) > 0) {
        spoken.write(' ${_untouchedLine(change.disabledUntouchedCount!)}.');
      }
    }
    if (_isMigration) spoken.write(' $_migrationLine.');
    if (_isClearByBulk) {
      spoken.write(' $_clearByBulkLine.');
      if (_showBrandLink) spoken.write(' 브랜드 이력에서 보기, 버튼');
    }
    if (_isUnknownChange) spoken.write(' 알 수 없는 변경.');
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
                _isGlobalEnabled
                    ? Icons.power_settings_new_rounded
                    : _isSwitchField
                    ? Icons.pause_circle_outline_rounded
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
                  if (_isSwitchField || _isClearByBulk) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _Pill(
                          _isClearByBulk ? '일괄 적용으로 초기화' : '적립 사용 여부',
                          tint: AppColors.primary.withValues(alpha: 0.10),
                        ),
                        if (_isMigration)
                          _Pill(
                            '이전',
                            tint: AppColors.textMuted.withValues(alpha: 0.12),
                          ),
                      ],
                    ),
                  ],
                  if (_isMigration) ...[
                    const SizedBox(height: 4),
                    Text(
                      _migrationLine,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textBody,
                      ),
                    ),
                  ],
                  if (_isClearByBulk) ...[
                    const SizedBox(height: 4),
                    Text(
                      _clearByBulkLine,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textBody,
                      ),
                    ),
                    if (isAdmin &&
                        _beforeInvalid &&
                        change.beforeRaw != null &&
                        change.beforeRaw!.isNotEmpty)
                      Text(
                        '값 "${change.beforeRaw}"',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                  if (_isUnknownChange) ...[
                    const SizedBox(height: 4),
                    const Text(
                      '알 수 없는 변경',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
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
                    if (change.brandDisabled == true) ...[
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(
                              Icons.pause_circle_outline_rounded,
                              size: 12,
                              color: AppColors.warning,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _brandOffLine,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textBody,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if ((change.disabledUntouchedCount ?? 0) > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        _untouchedLine(change.disabledUntouchedCount!),
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
                  if (_showBrandLink)
                    Semantics(
                      button: true,
                      label: '브랜드 이력에서 보기, 버튼',
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: () => onOpenBrandHistory!(change),
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '브랜드 이력에서 보기',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
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

  static const String _migrationLine =
      '예전 설정 ‘적립률 0%’ 가 ‘사용 안 함’ 으로 옮겨졌어요';
  static const String _clearByBulkLine = '브랜드 일괄 적용으로 개별 설정이 지워졌어요';
  static const String _brandOffLine = '브랜드가 사용 안 함이라 산하 매장 전체의 적립이 시작되지 않았어요';
  static String _untouchedLine(int k) => '적립 사용 안 함 $k곳은 적립이 시작되지 않았어요';

  /// N8: 링크는 **뷰어 역할**로 분기한다. 가맹점주(owner)에게는 링크도 탭 타깃도 만들지 않는다.
  bool get _showBrandLink =>
      _isClearByBulk &&
      viewer.canOpenBrandHistory &&
      onOpenBrandHistory != null &&
      change.bulkHistoryId != null;

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

class _Pill extends StatelessWidget {
  const _Pill(this.text, {required this.tint});
  final String text;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textBody,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_labels.dart';

/// 편집 화면 최상단 범위 밴드. "지금 내가 어느 범위를 바꾸는 중인지" 를 항상 같은 자리·모양으로 말한다.
/// 범위 오입력(한 매장에 주려던 10% 를 전역에)은 100배 오입력보다 위험하다.
///
/// 중간 줄은 확인 다이얼로그 첫 줄과 **글자 그대로 같은 문자열**이다 (`QoinScopeLabel.of`).
/// 전역은 가장 파급이 커서 warning 틴트로 강조한다.
class QoinScopeBand extends StatelessWidget {
  const QoinScopeBand({
    super.key,
    required this.scope,
    this.targetName,
    required this.detail,
  });

  final QoinRateScope scope;
  final String? targetName;

  /// 셋째 줄 (범위별 문자열은 호출자가 [QoinScopeBandDetail] 로 만든다).
  final String detail;

  @override
  Widget build(BuildContext context) {
    final label = QoinScopeLabel.of(scope, targetName);
    final isGlobal = scope == QoinRateScope.global;
    return Semantics(
      container: true,
      label: '적용 범위, ${label.replaceAll('"', '')}. $detail',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isGlobal
              ? AppColors.warning.withValues(alpha: 0.10)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
              ),
              child: Icon(
                QoinScopeIcons.of(scope),
                size: 22,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '적용 범위',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textHeading,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 범위 밴드 셋째 줄 문자열 (design §15-b).
class QoinScopeBandDetail {
  QoinScopeBandDetail._();

  static const String global = '따로 설정하지 않은 모든 브랜드·매장에 적용돼요';

  /// 산하 매장 수가 아직 로딩 중이면 [total] 을 null 로 — 숫자를 지어내지 않는다.
  static String brand({int? total, int? overridden}) {
    if (total == null) return '산하 매장 정보를 불러오는 중이에요';
    final base = '산하 매장 $total곳';
    return (overridden != null && overridden > 0)
        ? '$base · 개별 설정 $overridden곳'
        : base;
  }

  /// 같은 이름의 매장이 여러 브랜드에 있을 수 있어 소속을 반드시 넣는다.
  static String store({String? brandName}) =>
      (brandName == null || brandName.isEmpty) ? '개인 매장' : '$brandName 소속 매장';
}

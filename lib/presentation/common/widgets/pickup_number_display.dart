import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// 픽업 주문번호 표시 변형 (order_pickup_number design.md).
enum PickupNumberVariant {
  /// 고객 결제완료 / 주문상세 — 가장 크게 (라벨 + 56pt 숫자).
  hero,

  /// 점주 목록 타일 / 주문상세 — 정사각 칩 (기본 52, 상세는 64).
  badge,

  /// Log / 고객 주문목록 카드 — `#3 · 3분 전` 보조 표기.
  inline,
}

/// 매장·일별 픽업 주문번호 표시 공통 위젯.
///
/// [number] 가 null (번호 미부여 = 과거 주문) 이면 **아무것도 그리지 않는다** (`SizedBox.shrink`).
/// 단 [PickupNumberVariant.inline] 은 [inlineSuffix] 가 있으면 번호 없이 suffix 만 그린다 (카드의 기존 시간 텍스트 유지).
/// 호출부는 번호 영역과 함께 둘 간격(SizedBox)도 `number != null` 일 때만 두어야 한다.
class PickupNumberDisplay extends StatelessWidget {
  const PickupNumberDisplay({
    super.key,
    required this.number,
    required this.variant,
    this.muted = false,
    this.caption,
    this.badgeSize = 52,
    this.inlineSuffix,
  });

  final int? number;
  final PickupNumberVariant variant;

  /// 취소/환불 등 종료 상태 — surface 배경 + textMuted 로 약화 (hero 전용).
  final bool muted;

  /// hero 하단 보조 문구 (결제완료 화면의 "매장에서 이 번호를 보여주세요").
  final String? caption;

  /// badge 한 변. 목록 타일 52, 점주 주문상세 64.
  final double badgeSize;

  /// inline 에서 `#N · ` 뒤에 붙는 텍스트 (예: 상대 시간).
  final String? inlineSuffix;

  static const _tabular = <FontFeature>[FontFeature.tabularFigures()];

  @override
  Widget build(BuildContext context) {
    final n = number;
    if (n == null) {
      if (variant == PickupNumberVariant.inline && inlineSuffix != null) {
        return Text(inlineSuffix!, style: _suffixStyle);
      }
      return const SizedBox.shrink();
    }
    return switch (variant) {
      PickupNumberVariant.hero => _hero(n),
      PickupNumberVariant.badge => _badge(n),
      PickupNumberVariant.inline => _inline(n),
    };
  }

  static const _suffixStyle = TextStyle(
    fontSize: 12,
    color: AppColors.textMuted,
  );

  Widget _hero(int n) {
    final bg = muted ? AppColors.surface : AppColors.primary;
    final numberColor = muted ? AppColors.textMuted : AppColors.onPrimary;
    final subColor = muted
        ? AppColors.textMuted
        : AppColors.onPrimary.withAlpha((0.8 * 255).round());
    return Semantics(
      label: '픽업 번호 $n번',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(caption != null ? 16 : 12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '픽업 번호',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: subColor,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$n',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  color: numberColor,
                  fontFeatures: _tabular,
                ),
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 6),
              Text(caption!, style: TextStyle(fontSize: 12, color: subColor)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge(int n) {
    final large = badgeSize >= 64;
    return Semantics(
      label: '픽업 번호 $n번',
      excludeSemantics: true,
      child: Container(
        width: badgeSize,
        height: badgeSize,
        padding: const EdgeInsets.all(4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$n',
            style: TextStyle(
              fontSize: large ? 32 : 26,
              fontWeight: FontWeight.w800,
              color: AppColors.onPrimary,
              fontFeatures: _tabular,
            ),
          ),
        ),
      ),
    );
  }

  Widget _inline(int n) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '#$n',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textBody,
              fontFeatures: _tabular,
            ),
          ),
          if (inlineSuffix != null)
            TextSpan(text: ' · $inlineSuffix', style: _suffixStyle),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';

/// 출처 배지 5종 + 필터 칩이 **글자 그대로 같은** 문자열을 쓰도록 한 곳에 둔다 (design §7-a).
class QoinRateLabels {
  QoinRateLabels._();

  static const String storeSet = '매장 설정';
  static const String brandSet = '브랜드 설정';
  static const String brandInherit = '브랜드 상속';
  static const String globalInherit = '전역 상속';
  static const String stopped = '적립 안 함';
  static const String invalid = '설정 확인 필요';

  static const String none = '설정 없음';
  static const String needsCheck = '확인 필요';
  static const String enabledOn = '적립 중';
  static const String enabledOff = '적립 중단됨';
}

/// 출처 배지의 종류. 해석 결과 + 보는 대상(매장/브랜드)에서 결정된다.
/// 같은 5% 라도 브랜드 화면에서는 `브랜드 설정`, 매장 화면에서는 `브랜드 상속` 이다 (대상 기준).
enum QoinRateBadgeKind {
  storeSet(QoinRateLabels.storeSet),
  brandSet(QoinRateLabels.brandSet),
  brandInherit(QoinRateLabels.brandInherit),
  globalInherit(QoinRateLabels.globalInherit),
  stopped(QoinRateLabels.stopped),
  invalid(QoinRateLabels.invalid);

  const QoinRateBadgeKind(this.label);
  final String label;

  /// [target] 은 지금 보고 있는 대상의 범위 (brand 또는 store).
  static QoinRateBadgeKind of(EffectiveQoinRate e, {required QoinRateScope target}) {
    if (e.isInvalid) return invalid;
    if (e.isStopped) return stopped;
    switch (e.source!) {
      case QoinRateSource.store:
        return storeSet;
      case QoinRateSource.brand:
        return target == QoinRateScope.brand ? brandSet : brandInherit;
      case QoinRateSource.global:
        return globalInherit;
    }
  }

  /// 명시 값(대상 자신이 정한 값)인가. 상속은 false. 값 위계(굵기/색)를 결정한다.
  bool get isExplicit =>
      this == storeSet || this == brandSet || this == stopped;
}

/// 값 → 표기 문자열 변환의 **유일한 경로** (화면별로 각자 조립하지 않는다).
class QoinRateValueLabel {
  QoinRateValueLabel._();

  /// 저장된 필드 1칸: 부재 `설정 없음` / 0 `적립 안 함` / 유효 `5%` / 무효 `확인 필요`.
  static String setting(QoinRateSetting s) {
    switch (s.kind) {
      case QoinRateCellKind.absent:
        return QoinRateLabels.none;
      case QoinRateCellKind.zero:
        return QoinRateLabels.stopped;
      case QoinRateCellKind.valid:
        return QoinPolicy.formatRatePercent(s.value!);
      case QoinRateCellKind.invalid:
        return QoinRateLabels.needsCheck;
    }
  }

  /// 우선순위 사슬의 줄 값: 0 은 `0% · 적립 안 함`.
  static String chain(QoinRateSetting s) =>
      s.isZero ? '0% · ${QoinRateLabels.stopped}' : setting(s);

  /// 해석된 값: `5%` / `0%` / 해석 불가 `—`.
  static String effective(EffectiveQoinRate e) =>
      e.isInvalid ? '—' : QoinPolicy.formatRatePercent(e.rate!);

  /// 이력의 before/after (`null` = 설정 없음).
  static String history(double? rate) {
    if (rate == null) return QoinRateLabels.none;
    if (rate == 0) return QoinRateLabels.stopped;
    return QoinPolicy.formatRatePercent(rate);
  }

  /// 이력의 enabled 값.
  static String enabled(bool? v) =>
      v == true ? QoinRateLabels.enabledOn : QoinRateLabels.enabledOff;

  // ── 스크린리더 ─────────────────────────────────────────────────────────────
  // `%` 는 `퍼센트`, 화살표/대시는 읽히지 않게 말로 대체한다.

  static String spokenRate(double rate) =>
      '${QoinPolicy.formatTenths(QoinPolicy.tenthsFromRate(rate))}퍼센트';

  static String spokenSetting(QoinRateSetting s) {
    switch (s.kind) {
      case QoinRateCellKind.absent:
        return QoinRateLabels.none;
      case QoinRateCellKind.zero:
        return '적립 안 함, 0퍼센트';
      case QoinRateCellKind.valid:
        return spokenRate(s.value!);
      case QoinRateCellKind.invalid:
        return QoinRateLabels.needsCheck;
    }
  }

  static String spokenEffective(EffectiveQoinRate e) {
    if (e.isInvalid) return QoinRateLabels.needsCheck;
    if (e.isStopped) return '적립 안 함, 0퍼센트';
    return spokenRate(e.rate!);
  }

  static String spokenHistory(double? rate) {
    if (rate == null) return QoinRateLabels.none;
    if (rate == 0) return QoinRateLabels.stopped;
    return spokenRate(rate);
  }

  /// `에서 … (으)로` 조사. 도착 값이 `…퍼센트` 면 `로`, 그 외(`적립 안 함`/`설정 없음`/`적립 중…`)는 `으로`.
  static String particleEuroOrRo(String spokenDestination) =>
      spokenDestination.endsWith('퍼센트') ? '로' : '으로';
}

/// 범위 줄 문자열 — 범위 밴드 · 확인 다이얼로그 첫 줄 · 이력 · SnackBar 가 **같은 함수**를 쓴다.
/// 각자 조립하면 반드시 어긋난다 (design §14-2).
class QoinScopeLabel {
  QoinScopeLabel._();

  static String of(QoinRateScope scope, String? name) {
    switch (scope) {
      case QoinRateScope.global:
        return '전역 기본값';
      case QoinRateScope.brand:
        return '브랜드 "${name ?? ''}" 전체';
      case QoinRateScope.store:
        return '매장 "${name ?? ''}"';
    }
  }
}

/// 범위별 아이콘 — 허브 타일 · 범위 밴드 · 이력 원이 **같은 아이콘**을 쓴다.
class QoinScopeIcons {
  QoinScopeIcons._();

  static IconData of(QoinRateScope scope) {
    switch (scope) {
      case QoinRateScope.global:
        return Icons.public_rounded;
      case QoinRateScope.brand:
        return Icons.business_rounded;
      case QoinRateScope.store:
        return Icons.storefront_outlined;
    }
  }
}

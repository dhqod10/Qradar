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
  static const String storeStopped = '매장에서 중단';
  static const String brandStopped = '브랜드에서 중단';
  static const String invalid = '설정 확인 필요';

  /// 스위치가 꺼진 상태의 값 라벨 (사슬·목록·값 칸). 켜짐은 `사용`.
  static const String switchOff = '사용 안 함';
  static const String switchOn = '사용';
  static const String switchOffSentence = '적립 사용 안 함';

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
  storeStopped(QoinRateLabels.storeStopped),
  brandStopped(QoinRateLabels.brandStopped),
  invalid(QoinRateLabels.invalid);

  const QoinRateBadgeKind(this.label);
  final String label;

  /// [target] 은 지금 보고 있는 대상의 범위 (brand 또는 store).
  static QoinRateBadgeKind of(EffectiveQoinRate e, {required QoinRateScope target}) {
    if (e.isInvalid) return invalid;
    if (e.isDisabled) {
      return e.disabledSource == QoinRateSource.store
          ? storeStopped
          : brandStopped;
    }
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
      this == storeSet ||
      this == brandSet ||
      this == storeStopped ||
      this == brandStopped;

  /// 스위치가 꺼져 적립이 멈춘 종류인가.
  bool get isStopped => this == storeStopped || this == brandStopped;
}

/// 값 → 표기 문자열 변환의 **유일한 경로** (화면별로 각자 조립하지 않는다).
class QoinRateValueLabel {
  QoinRateValueLabel._();

  /// 저장된 적립률 필드 1칸: 부재 `설정 없음` / 유효 `5%` / 무효 `확인 필요`.
  static String setting(QoinRateSetting s) {
    switch (s.kind) {
      case QoinRateCellKind.absent:
        return QoinRateLabels.none;
      case QoinRateCellKind.valid:
        return QoinPolicy.formatRatePercent(s.value!);
      case QoinRateCellKind.invalid:
        return QoinRateLabels.needsCheck;
    }
  }

  /// 스위치 1칸: `사용` / `사용 안 함` / `확인 필요`.
  static String switchSetting(QoinSwitchSetting s) {
    switch (s.kind) {
      case QoinSwitchKind.enabled:
        return QoinRateLabels.switchOn;
      case QoinSwitchKind.disabled:
        return QoinRateLabels.switchOff;
      case QoinSwitchKind.invalid:
        return QoinRateLabels.needsCheck;
    }
  }

  /// 해석된 값: `5%` / `사용 안 함` / 해석 불가 `—`.
  static String effective(EffectiveQoinRate e) {
    if (e.isInvalid) return '—';
    if (e.isDisabled) return QoinRateLabels.switchOff;
    return QoinPolicy.formatRatePercent(e.rate!);
  }

  /// 이력의 적립률 before/after (`null` = 설정 없음). 숫자 0 은 적립률이 아니므로 `알 수 없는 값`.
  static String history(double? rate) {
    if (rate == null) return QoinRateLabels.none;
    if (rate == 0) return '알 수 없는 값';
    return QoinPolicy.formatRatePercent(rate);
  }

  /// 이력의 전역 비상 정지 값.
  static String enabled(bool? v) =>
      v == true ? QoinRateLabels.enabledOn : QoinRateLabels.enabledOff;

  /// 이력의 스위치 값: 부재·true `사용` / false `사용 안 함` / 무효 `확인 필요`.
  static String historySwitch(bool? v, {bool invalid = false}) {
    if (invalid) return QoinRateLabels.needsCheck;
    return v == false ? QoinRateLabels.switchOff : QoinRateLabels.switchOn;
  }

  // ── 스크린리더 ─────────────────────────────────────────────────────────────
  // `%` 는 `퍼센트`, 화살표/대시는 읽히지 않게 말로 대체한다.

  static String spokenRate(double rate) =>
      '${QoinPolicy.formatTenths(QoinPolicy.tenthsFromRate(rate))}퍼센트';

  static String spokenSetting(QoinRateSetting s) {
    switch (s.kind) {
      case QoinRateCellKind.absent:
        return QoinRateLabels.none;
      case QoinRateCellKind.valid:
        return spokenRate(s.value!);
      case QoinRateCellKind.invalid:
        return QoinRateLabels.needsCheck;
    }
  }

  /// [sentence] 가 true 면 읽기 행 문장형(`적립 사용 안 함`), 아니면 값 라벨형(`사용 안 함`).
  static String spokenEffective(EffectiveQoinRate e, {bool sentence = false}) {
    if (e.isInvalid) return QoinRateLabels.needsCheck;
    if (e.isDisabled) {
      return sentence ? QoinRateLabels.switchOffSentence : QoinRateLabels.switchOff;
    }
    return spokenRate(e.rate!);
  }

  static String spokenHistory(double? rate) {
    if (rate == null) return QoinRateLabels.none;
    if (rate == 0) return '알 수 없는 값';
    return spokenRate(rate);
  }

  /// `에서 … (으)로` 조사. 도착 값이 `…퍼센트` 면 `로`, 그 외(`사용`/`사용 안 함`/`설정 없음`/`적립 중…`)는 `으로`, `확인 필요` 는 `로`.
  static String particleEuroOrRo(String spokenDestination) =>
      (spokenDestination.endsWith('퍼센트') ||
          spokenDestination.endsWith('필요'))
      ? '로'
      : '으로';
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

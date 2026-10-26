import 'package:qradar/core/utils/qoin_policy.dart';

/// 저장된 적립률 필드 1칸의 상태. **값을 `null` / `0.0` 으로 뭉개지 않는다.**
///
/// - [absent]     필드 부재 = 상위 설정 상속
/// - [valid]      0.001~0.2 의 명시 값
/// - [invalid]    비number / NaN / 범위 밖 / **0** — 상위로 폴백하지 않고 멈춘다 (fail-closed)
///
/// "적립 안 함" 은 적립률이 아니다. 별도 스위치([QoinSwitchSetting])가 가진다 (spec §20).
enum QoinRateCellKind {
  absent,
  valid,
  invalid,
}

class QoinRateSetting {
  const QoinRateSetting._(this.kind, this.value);

  /// 필드 부재.
  static const QoinRateSetting absent = QoinRateSetting._(
    QoinRateCellKind.absent,
    null,
  );

  /// 무효 값 (원본은 보관하지 않는다 — 화면은 `설정 확인 필요` 만 말한다).
  static const QoinRateSetting invalid = QoinRateSetting._(
    QoinRateCellKind.invalid,
    null,
  );

  /// 유효 값. 범위 밖이면 [ArgumentError] — 호출자는 [fromRaw] 로 분류해서 만든다.
  factory QoinRateSetting.valid(double rate) {
    if (!QoinPolicy.isValidRate(rate)) {
      throw ArgumentError.value(rate, 'rate', 'out of valid range');
    }
    return QoinRateSetting._(QoinRateCellKind.valid, rate);
  }

  /// Firestore 원본 값 분류. [present] 는 문서에 필드 키가 있는가 (Dart 의 `map[key]` 는 부재와 null 을 구분하지 못한다).
  /// `present && raw == null` 은 무효 (서버와 같은 규칙: null 상태를 만들지 않는다).
  factory QoinRateSetting.fromRaw(Object? raw, {required bool present}) {
    if (!present) return absent;
    if (raw is! num) return invalid;
    final d = raw.toDouble();
    if (!d.isFinite) return invalid;
    // 0 은 어느 범위에서도 적립률이 아니다 — isValidRate 가 거부한다 ("적립 안 함" 은 스위치의 일).
    if (!QoinPolicy.isValidRate(d)) return invalid;
    return QoinRateSetting._(QoinRateCellKind.valid, d);
  }

  final QoinRateCellKind kind;

  /// [QoinRateCellKind.valid] 일 때만 비율, 그 외 null.
  final double? value;

  bool get isAbsent => kind == QoinRateCellKind.absent;
  bool get isValid => kind == QoinRateCellKind.valid;
  bool get isInvalid => kind == QoinRateCellKind.invalid;

  /// 누군가 이 범위에서 적립률을 정했는가 (유효 값). 무효·레거시 0 은 "정했다" 로 세지 않는다.
  bool get isExplicit => isValid;

  @override
  bool operator ==(Object other) =>
      other is QoinRateSetting && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);

  @override
  String toString() =>
      'QoinRateSetting($kind${value == null ? '' : ', $value'})';
}

/// 적립 스위치(`qoinAccrualEnabled`) 1칸. 부재 = `true` = 사용. `false` 만 저장된다.
class QoinSwitchSetting {
  const QoinSwitchSetting._(this.kind, this.present);

  /// 부재 / `true`.
  static const QoinSwitchSetting enabled = QoinSwitchSetting._(
    QoinSwitchKind.enabled,
    false,
  );
  static const QoinSwitchSetting disabled = QoinSwitchSetting._(
    QoinSwitchKind.disabled,
    true,
  );
  static const QoinSwitchSetting invalid = QoinSwitchSetting._(
    QoinSwitchKind.invalid,
    true,
  );

  factory QoinSwitchSetting.fromRaw(Object? raw, {required bool present}) {
    switch (QoinPolicy.classifySwitch(raw, present: present)) {
      case QoinSwitchKind.enabled:
        return enabled;
      case QoinSwitchKind.disabled:
        return disabled;
      case QoinSwitchKind.invalid:
        return invalid;
    }
  }

  final QoinSwitchKind kind;
  final bool present;

  bool get isEnabled => kind == QoinSwitchKind.enabled;
  bool get isDisabled => kind == QoinSwitchKind.disabled;
  bool get isInvalid => kind == QoinSwitchKind.invalid;

  @override
  bool operator ==(Object other) =>
      other is QoinSwitchSetting && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;

  @override
  String toString() => 'QoinSwitchSetting($kind)';
}

/// 유효 적립률이 어느 범위에서 왔는가. 원장 `accrualRateSource` 와 같은 코드.
enum QoinRateSource {
  store,
  brand,
  global;

  String get code => name;
}

/// 해석 불가의 원인 (서버 로그의 `invalid_*` 와 같은 이름).
enum QoinRateInvalidScope {
  store,
  brand,
  global,
  storeEnabled,
  brandEnabled;

  /// 진리표 표기 (`store_enabled`).
  String get code => switch (this) {
    storeEnabled => 'store_enabled',
    brandEnabled => 'brand_enabled',
    _ => name,
  };
}

/// 계층 해석 결과 + **각 단계 원본**. 배지·우선순위 사슬·라디오 초기 선택이 모두 이 원본을 쓴다.
///
/// 결과는 셋 중 하나다: 적립률 확정([rate]+[source]) / 사용 안 함([disabledSource]) / 해석 불가([invalidScope]).
class EffectiveQoinRate {
  const EffectiveQoinRate({
    required this.store,
    required this.brand,
    required this.global,
    required this.storeSwitch,
    required this.brandSwitch,
    required this.hasBrand,
    required this.rate,
    required this.source,
    required this.disabledSource,
    required this.invalidScope,
  });

  final QoinRateSetting store;
  final QoinRateSetting brand;
  final QoinRateSetting global;
  final QoinSwitchSetting storeSwitch;
  final QoinSwitchSetting brandSwitch;

  /// 브랜드 소속 매장인가 (개인 매장이면 brand 단계가 없다).
  final bool hasBrand;

  /// 해석된 비율. [isDisabled] / [isInvalid] 면 null.
  final double? rate;

  /// 적립률의 출처. [isDisabled] / [isInvalid] 면 null.
  final QoinRateSource? source;

  /// 사용 안 함일 때 어느 단계에서 꺼졌는가 (`store` / `brand`). 아니면 null.
  final QoinRateSource? disabledSource;

  /// 해석 불가일 때 원인. 아니면 null.
  final QoinRateInvalidScope? invalidScope;

  bool get isDisabled => disabledSource != null;
  bool get isInvalid => invalidScope != null;
  bool get isActive => rate != null;

  /// "스위치가 켜져 있다면 적용될 값". 확인 다이얼로그가 변경 전·후를 이 값끼리 비교하고,
  /// 상속 설명(`브랜드 5% 를 따라요`)이 이 값을 쓴다 — 스위치와 숫자는 독립인 두 축이다.
  /// 무효 스위치도 켜진 것으로 본다(숫자 축만 보기 위함).
  EffectiveQoinRate asIfEnabled() => resolveEffectiveQoinRate(
    store: store,
    brand: brand,
    global: global,
    hasBrand: hasBrand,
  );
}

/// 계층 해석. 서버 `resolveEffectiveRate` 와 같은 진리표 (spec §20.3.1 개정판, N4).
///
/// **스위치 단계가 숫자 단계를 통째로 앞선다**, 스위치 단계 안에서 `disabled` 가 `invalid` 보다 앞선다.
/// ```
/// storeSwitch disabled -> DISABLED(store)      brandSwitch disabled -> DISABLED(brand)
/// storeSwitch invalid  -> INVALID(store_enabled)  brandSwitch invalid -> INVALID(brand_enabled)
/// storeRate -> brandRate -> globalRate
/// ```
/// **무효 값은 상위로 폴백하지 않는다.** 브랜드 미소속이면 [brand] 에 absent 를 넘기고 [hasBrand] 를 false 로.
EffectiveQoinRate resolveEffectiveQoinRate({
  required QoinRateSetting store,
  required QoinRateSetting brand,
  required QoinRateSetting global,
  QoinSwitchSetting storeSwitch = QoinSwitchSetting.enabled,
  QoinSwitchSetting brandSwitch = QoinSwitchSetting.enabled,
  bool hasBrand = true,
}) {
  EffectiveQoinRate build({
    double? rate,
    QoinRateSource? source,
    QoinRateSource? disabled,
    QoinRateInvalidScope? invalid,
  }) => EffectiveQoinRate(
    store: store,
    brand: brand,
    global: global,
    storeSwitch: storeSwitch,
    brandSwitch: brandSwitch,
    hasBrand: hasBrand,
    rate: rate,
    source: source,
    disabledSource: disabled,
    invalidScope: invalid,
  );
  EffectiveQoinRate ok(double rate, QoinRateSource source) =>
      build(rate: rate, source: source);
  EffectiveQoinRate off(QoinRateSource at) => build(disabled: at);
  EffectiveQoinRate bad(QoinRateInvalidScope scope) => build(invalid: scope);

  // ── 1단계: 스위치 (숫자보다 먼저. 매장 → 브랜드) ──────────────────────────
  if (storeSwitch.isDisabled) return off(QoinRateSource.store);
  if (brandSwitch.isDisabled) return off(QoinRateSource.brand);
  if (storeSwitch.isInvalid) return bad(QoinRateInvalidScope.storeEnabled);
  if (brandSwitch.isInvalid) return bad(QoinRateInvalidScope.brandEnabled);

  // ── 2단계: 숫자 (상속) ───────────────────────────────────────────────────
  if (store.isInvalid) return bad(QoinRateInvalidScope.store);
  if (store.isValid) return ok(store.value!, QoinRateSource.store);
  if (brand.isInvalid) return bad(QoinRateInvalidScope.brand);
  if (brand.isValid) return ok(brand.value!, QoinRateSource.brand);
  if (global.isValid) return ok(global.value!, QoinRateSource.global);
  return bad(QoinRateInvalidScope.global);
}

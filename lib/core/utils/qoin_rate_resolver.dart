import 'package:qradar/core/utils/qoin_policy.dart';

/// 저장된 적립률 필드 1칸의 상태. **4값을 `null` / `0.0` 으로 뭉개지 않는다.**
///
/// - [absent]  필드 부재 = 상위 설정 상속
/// - [valid]   0.001~0.2 의 명시 값
/// - [zero]    명시적 0 = 적립 안 함 (적립만 막는다. 회수는 계속된다)
/// - [invalid] 비number / NaN / 범위 밖 — 상위로 폴백하지 않고 멈춘다 (fail-closed)
enum QoinRateCellKind { absent, valid, zero, invalid }

class QoinRateSetting {
  const QoinRateSetting._(this.kind, this.value);

  /// 필드 부재.
  static const QoinRateSetting absent = QoinRateSetting._(
    QoinRateCellKind.absent,
    null,
  );

  /// 명시적 0%.
  static const QoinRateSetting zero = QoinRateSetting._(
    QoinRateCellKind.zero,
    0,
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
  /// [allowZero] 가 false(전역)이면 0 은 무효.
  factory QoinRateSetting.fromRaw(
    Object? raw, {
    required bool present,
    bool allowZero = true,
  }) {
    if (!present) return absent;
    if (raw is! num) return invalid;
    final d = raw.toDouble();
    if (!d.isFinite) return invalid;
    if (d == 0) return allowZero ? zero : invalid;
    if (!QoinPolicy.isValidRate(d)) return invalid;
    return QoinRateSetting._(QoinRateCellKind.valid, d);
  }

  final QoinRateCellKind kind;

  /// [QoinRateCellKind.valid] 는 비율, [QoinRateCellKind.zero] 는 0, 그 외 null.
  final double? value;

  bool get isAbsent => kind == QoinRateCellKind.absent;
  bool get isValid => kind == QoinRateCellKind.valid;
  bool get isZero => kind == QoinRateCellKind.zero;
  bool get isInvalid => kind == QoinRateCellKind.invalid;

  /// 누군가 이 범위에서 값을 정했는가 (유효 값 또는 명시적 0).
  bool get isExplicit => isValid || isZero;

  @override
  bool operator ==(Object other) =>
      other is QoinRateSetting && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);

  @override
  String toString() =>
      'QoinRateSetting($kind${value == null ? '' : ', $value'})';
}

/// 유효 적립률이 어느 범위에서 왔는가. 원장 `accrualRateSource` 와 같은 코드.
enum QoinRateSource {
  store,
  brand,
  global;

  String get code => name;
}

/// 해석 불가의 원인 범위 (서버 로그의 `invalid_*` 와 같은 이름).
enum QoinRateInvalidScope { store, brand, global }

/// 계층 해석 결과 + **각 단계 원본**. 배지·우선순위 사슬·라디오 초기 선택이 모두 이 원본을 쓴다.
class EffectiveQoinRate {
  const EffectiveQoinRate({
    required this.store,
    required this.brand,
    required this.global,
    required this.hasBrand,
    required this.rate,
    required this.source,
    required this.invalidScope,
  });

  final QoinRateSetting store;
  final QoinRateSetting brand;
  final QoinRateSetting global;

  /// 브랜드 소속 매장인가 (개인 매장이면 brand 단계가 없다).
  final bool hasBrand;

  /// 해석된 비율. 0 이면 적립 안 함. [isInvalid] 면 null.
  final double? rate;

  /// [isInvalid] 면 null.
  final QoinRateSource? source;

  /// [isInvalid] 일 때 어느 범위 때문인가.
  final QoinRateInvalidScope? invalidScope;

  bool get isInvalid => rate == null;

  /// 적립 안 함 (명시적 0 이 이기는 경우).
  bool get isStopped => rate == 0;
}

/// 계층 해석 (매장 → 브랜드 → 전역). 서버 `resolveEffectiveRate` 와 같은 진리표.
/// **무효 값은 상위로 폴백하지 않는다.** 브랜드 미소속이면 [brand] 에 [QoinRateSetting.absent] 를 넘기고 [hasBrand] 를 false 로.
EffectiveQoinRate resolveEffectiveQoinRate({
  required QoinRateSetting store,
  required QoinRateSetting brand,
  required QoinRateSetting global,
  bool hasBrand = true,
}) {
  EffectiveQoinRate ok(double rate, QoinRateSource source) => EffectiveQoinRate(
    store: store,
    brand: brand,
    global: global,
    hasBrand: hasBrand,
    rate: rate,
    source: source,
    invalidScope: null,
  );
  EffectiveQoinRate bad(QoinRateInvalidScope scope) => EffectiveQoinRate(
    store: store,
    brand: brand,
    global: global,
    hasBrand: hasBrand,
    rate: null,
    source: null,
    invalidScope: scope,
  );

  if (store.isZero) return ok(0, QoinRateSource.store);
  if (store.isValid) return ok(store.value!, QoinRateSource.store);
  if (store.isInvalid) return bad(QoinRateInvalidScope.store);

  if (brand.isZero) return ok(0, QoinRateSource.brand);
  if (brand.isValid) return ok(brand.value!, QoinRateSource.brand);
  if (brand.isInvalid) return bad(QoinRateInvalidScope.brand);

  if (global.isValid) return ok(global.value!, QoinRateSource.global);
  return bad(QoinRateInvalidScope.global);
}

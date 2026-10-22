import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';

/// `다시 켜면 …` 고지의 종류 (design §18-3). 판정 순서가 아니라 결과의 분류다 —
/// 순서는 resolver(스위치 단계 → 숫자 단계)가 정한다.
enum QoinReenableKind {
  /// A — 켜면 이 매장의 개별 적립률이 적용된다 (브랜드가 켜져 있을 때만).
  storeOwnRate,

  /// B — 켜면 브랜드 적립률이 적용된다.
  brandRate,

  /// C — 켜면 전역 기본값이 적용된다.
  globalRate,

  /// D — 켜도 브랜드가 꺼져 있어 적립되지 않는다. (A 보다 먼저 나온다: 해석이 D 를 돌려주기 때문이다.)
  brandStillOff,

  /// E — 켜도 설정에 문제가 있다.
  invalid,

  /// 매장 화면에서, 매장 스위치는 켜져 있는데 브랜드가 꺼져서 멈춘 경우.
  brandBlocksStore,
}

/// `QoinReenableHint.of` — 사슬 하단과 켜기 다이얼로그가 쓰는 **유일한 문장 출처**.
///
/// 문장을 위젯에서 조립하지 않는다. "스위치를 켠다고 가정하고 해석을 한 번 더 돌려" 그 결과를 말한다.
/// 따라서 resolver 가 스위치 단계를 숫자 단계보다 앞세우는 규칙(N4)이 이 고지에도 자동으로 반영된다.
/// "개별 적립률이 있으면 적립" 같은 분기를 여기서 만들지 않는다.
class QoinReenableHint {
  const QoinReenableHint._(this.kind, this.headline, this.sub, this.dialogSub);

  final QoinReenableKind kind;

  /// 13/w600 본문.
  final String headline;

  /// 사슬 하단 보조 (12 muted). 없으면 null.
  final String? sub;

  /// 켜기 다이얼로그 보조 (12 muted). 없으면 null.
  final String? dialogSub;

  static const String _currentRateSub = '끄기 전 값이 아니라 지금의 요율이에요';
  static const String _currentRateDialogSub = '끄기 전에 어떤 값이었는지와 관계없이 지금의 요율이에요';

  /// [e] 는 **현재** 해석 결과(꺼진 상태). [target] 은 지금 보는 대상(store 또는 brand).
  /// 이 대상 때문에 멈춘 것도, 상위(브랜드) 때문에 멈춘 것도 아니면 null.
  static QoinReenableHint? of(
    EffectiveQoinRate e, {
    required QoinRateScope target,
  }) {
    if (target == QoinRateScope.global) return null;

    if (target == QoinRateScope.brand) {
      final brandOff = e.brandSwitch.isDisabled || e.brand.isLegacyZero;
      if (!brandOff) return null;
      final r = _rerun(e, enableBrand: true, brandHere: true);
      return _forTurnOn(r, brandScreen: true);
    }

    final storeOff = e.storeSwitch.isDisabled || e.store.isLegacyZero;
    if (storeOff) {
      final r = _rerun(e, enableStore: true);
      return _forTurnOn(r, brandScreen: false);
    }

    // 매장은 켜져 있고 브랜드 때문에 멈춘 경우.
    if (e.isDisabled && e.disabledSource == QoinRateSource.brand) {
      final r = _rerun(e, enableBrand: true);
      final applied = _appliedPhrase(r);
      return QoinReenableHint._(
        QoinReenableKind.brandBlocksStore,
        '브랜드가 사용 안 함이라 이 매장은 적립하지 않아요',
        '브랜드의 ‘적립 사용’ 을 켜야 이 매장이 적립해요'
            '${applied == null ? '' : ' · 브랜드를 켜면 $applied 가 적용돼요'}',
        null,
      );
    }
    return null;
  }

  /// 스위치를 켠다고 가정한 해석. 레거시 0(TRANSITIONAL)은 켜는 순간 "숫자 없음" 이 된다.
  static EffectiveQoinRate _rerun(
    EffectiveQoinRate e, {
    bool enableStore = false,
    bool enableBrand = false,
    bool brandHere = false,
  }) {
    return resolveEffectiveQoinRate(
      store: enableStore && e.store.isLegacyZero
          ? QoinRateSetting.absent
          : e.store,
      storeSwitch: enableStore ? QoinSwitchSetting.enabled : e.storeSwitch,
      brand: enableBrand && e.brand.isLegacyZero
          ? QoinRateSetting.absent
          : e.brand,
      brandSwitch: enableBrand ? QoinSwitchSetting.enabled : e.brandSwitch,
      global: e.global,
      hasBrand: e.hasBrand,
    );
  }

  static QoinReenableHint _forTurnOn(
    EffectiveQoinRate r, {
    required bool brandScreen,
  }) {
    if (r.isDisabled) {
      // 켜도 (다른) 스위치가 꺼져 있다 — 매장 화면에서 브랜드가 꺼져 있는 경우 (D).
      return const QoinReenableHint._(
        QoinReenableKind.brandStillOff,
        '다시 켜도 브랜드가 사용 안 함이라 적립되지 않아요',
        '브랜드의 ‘적립 사용’ 도 켜야 해요',
        '브랜드의 ‘적립 사용’ 도 켜야 해요',
      );
    }
    if (r.isInvalid) {
      return const QoinReenableHint._(
        QoinReenableKind.invalid,
        '다시 켜도 적립률 설정에 문제가 있어 적립되지 않을 수 있어요',
        null,
        null,
      );
    }
    final rate = QoinPolicy.formatRatePercent(r.rate!);
    switch (r.source!) {
      case QoinRateSource.store:
        return QoinReenableHint._(
          QoinReenableKind.storeOwnRate,
          '다시 켜면 이 매장의 개별 적립률 $rate 가 적용돼요',
          null,
          null,
        );
      case QoinRateSource.brand:
        return QoinReenableHint._(
          QoinReenableKind.brandRate,
          '다시 켜면 브랜드 $rate 가 적용돼요',
          _currentRateSub,
          _currentRateDialogSub,
        );
      case QoinRateSource.global:
        return QoinReenableHint._(
          QoinReenableKind.globalRate,
          '다시 켜면 전역 기본값 $rate 가 적용돼요',
          _currentRateSub,
          _currentRateDialogSub,
        );
    }
  }

  /// `브랜드를 켜면 {…} 가 적용돼요` 의 `{…}`. 해석 불가면 null (문장 뒷부분을 생략한다).
  static String? _appliedPhrase(EffectiveQoinRate r) {
    if (r.isDisabled || r.isInvalid) return null;
    final rate = QoinPolicy.formatRatePercent(r.rate!);
    switch (r.source!) {
      case QoinRateSource.store:
        return '이 매장의 개별 적립률 $rate';
      case QoinRateSource.brand:
        return '브랜드 $rate';
      case QoinRateSource.global:
        return '전역 기본값 $rate';
    }
  }
}

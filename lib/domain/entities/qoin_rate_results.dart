import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';

/// 저장하려는 적립률 동작. 0 은 적립률이 아니다 — "적립 안 함" 은 스위치([SetQoinAccrualEnabledUseCase])가 한다.
sealed class QoinRateValue {
  const QoinRateValue();

  /// 0.1% 단위 정수 (30 = 3.0%). 범위 검증은 UseCase 가 한다.
  const factory QoinRateValue.rate(int tenths) = QoinRateValueRate;

  /// 상위 설정 따르기 (필드 삭제).
  const factory QoinRateValue.inherit() = QoinRateValueInherit;
}

class QoinRateValueRate extends QoinRateValue {
  const QoinRateValueRate(this.tenths);
  final int tenths;
}

class QoinRateValueInherit extends QoinRateValue {
  const QoinRateValueInherit();
}

/// `setQoinAccrualRate` 결과. [changed] 가 false 면 값이 이미 같아서 아무것도 쓰지 않았다.
class QoinRateSetResult {
  const QoinRateSetResult({
    required this.before,
    required this.after,
    required this.changed,
    this.historyId,
  });

  /// null = 설정 없음(상속).
  final double? before;
  final double? after;
  final bool changed;
  final String? historyId;
}

/// `applyBrandQoinRate` 결과. 숫자는 **서버가 센 값**이다 (클라이언트 미리보기가 아니다).
class QoinBulkApplyResult {
  const QoinBulkApplyResult({
    required this.changed,
    required this.status,
    required this.affectedCount,
    required this.clearedCount,
    required this.preservedCount,
    required this.processedCount,
    required this.totalCount,
    this.historyId,
    this.disabledUntouchedCount = 0,
    this.clearedValueCount = 0,
    this.clearedInvalidCount = 0,
    this.brandDisabled = false,
  });

  final bool changed;
  final QoinBulkStatus status;
  final int affectedCount;
  final int clearedCount;
  final int preservedCount;
  final int processedCount;
  final int totalCount;
  final String? historyId;

  /// 산하 매장 중 스위치가 꺼져 있어 **일괄 적용 후에도 적립되지 않는** 매장 수. `cleared*` 합에 들어가지 않는다.
  final int disabledUntouchedCount;
  final int clearedValueCount;
  final int clearedInvalidCount;

  /// 실행 시점에 브랜드 자신이 `사용 안 함` 이었는가 → 산하 매장 전체가 적립되지 않는다.
  final bool brandDisabled;
}

/// `setQoinAccrualEnabled` 결과. [before] / [after]: null = 필드 부재 = 적립 사용, false = 사용 안 함.
/// [changed] 가 false 면 값이 이미 같아서 아무것도 쓰지 않았다.
class QoinAccrualEnabledResult {
  const QoinAccrualEnabledResult({
    required this.before,
    required this.after,
    required this.changed,
    this.historyId,
  });
  final bool? before;
  final bool? after;
  final bool changed;
  final String? historyId;
}

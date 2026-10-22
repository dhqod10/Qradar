import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';

/// 저장하려는 적립률 동작. 입력란은 0 을 거부하므로 "적립 안 함" 은 [QoinRateValue.stop] 으로만 만든다.
sealed class QoinRateValue {
  const QoinRateValue();

  /// 0.1% 단위 정수 (30 = 3.0%). 범위 검증은 UseCase 가 한다.
  const factory QoinRateValue.rate(int tenths) = QoinRateValueRate;

  /// 명시적 0% — 적립 안 함. 회수는 계속된다.
  const factory QoinRateValue.stop() = QoinRateValueStop;

  /// 상위 설정 따르기 (필드 삭제).
  const factory QoinRateValue.inherit() = QoinRateValueInherit;
}

class QoinRateValueRate extends QoinRateValue {
  const QoinRateValueRate(this.tenths);
  final int tenths;
}

class QoinRateValueStop extends QoinRateValue {
  const QoinRateValueStop();
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
  });

  final bool changed;
  final QoinBulkStatus status;
  final int affectedCount;
  final int clearedCount;
  final int preservedCount;
  final int processedCount;
  final int totalCount;
  final String? historyId;
}

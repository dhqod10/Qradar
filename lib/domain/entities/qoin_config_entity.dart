import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/core/utils/qoin_spend_calculator.dart';

part 'qoin_config_entity.freezed.dart';

/// 운영 설정 `config/qoin`. CF 와 클라이언트가 같은 문서를 읽는다.
@freezed
abstract class QoinConfigEntity with _$QoinConfigEntity {
  const factory QoinConfigEntity({
    /// 적립 비율 (0.03 = 3%). 문서 값이 number 가 아니거나 범위 밖이면 null (CF 도 적립하지 않음).
    double? accrualRate,

    /// 전역 기본값 원본 4값 (부재 / 유효 / 무효). 계층 해석과 "설정 확인 필요" 표기에 쓴다.
    /// 전역은 0 을 허용하지 않으므로 0 도 무효다. [accrualRate] 는 이 값이 유효일 때만 non-null.
    @Default(QoinRateSetting.absent) QoinRateSetting accrualRateSetting,

    /// kill switch. 부재 → false (fail-closed).
    @Default(false) bool enabled,

    /// 사용(qoin_spend) 유효 정책. 부재/꺼짐/무효 → [QoinSpendPolicy.disabled] (fail-closed). 체크아웃 Qoin 섹션이 읽는다.
    @Default(QoinSpendPolicy.disabled) QoinSpendPolicy spendPolicy,
  }) = _QoinConfigEntity;
}

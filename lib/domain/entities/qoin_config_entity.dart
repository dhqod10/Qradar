import 'package:freezed_annotation/freezed_annotation.dart';

part 'qoin_config_entity.freezed.dart';

/// 운영 설정 `config/qoin`. CF 와 클라이언트가 같은 문서를 읽는다.
@freezed
abstract class QoinConfigEntity with _$QoinConfigEntity {
  const factory QoinConfigEntity({
    /// 적립 비율 (0.03 = 3%). 문서 값이 number 가 아니거나 범위 밖이면 null (CF 도 적립하지 않음).
    double? accrualRate,

    /// kill switch. 부재 → false (fail-closed).
    @Default(false) bool enabled,
  }) = _QoinConfigEntity;
}

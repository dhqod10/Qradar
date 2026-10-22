import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/domain/entities/store_grade.dart';

part 'review_entity.freezed.dart';

/// Qrator가 매장에 남긴 평가 (1인 1매장 1표, 문서 ID = `{storeId}_{userId}`).
///
/// `score`(집계용 비정규화 값)는 [grade] 의 `StoreGrade.score` 로 파생 가능하므로
/// 엔티티에 두지 않는다 (저장층 전용).
@freezed
abstract class ReviewEntity with _$ReviewEntity {
  const factory ReviewEntity({
    required String id,
    required String storeId,
    required String userId,

    /// 자격 근거가 된 주문 (재주문 후 재평가 시 갱신).
    required String orderId,
    required StoreGrade grade,
    String? comment,
    required DateTime createdAt,

    /// 수정된 적이 있을 때만 non-null.
    DateTime? updatedAt,
  }) = _ReviewEntity;
}

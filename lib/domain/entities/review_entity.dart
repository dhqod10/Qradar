import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/domain/entities/store_grade.dart';

part 'review_entity.freezed.dart';

/// Qrator가 매장에 남긴 평가. 이번 단계에선 읽기 전용으로 사용.
@freezed
abstract class ReviewEntity with _$ReviewEntity {
  const factory ReviewEntity({
    required String id,
    required String storeId,
    required String userId,
    required StoreGrade grade,
    String? comment,
    required DateTime createdAt,
  }) = _ReviewEntity;
}

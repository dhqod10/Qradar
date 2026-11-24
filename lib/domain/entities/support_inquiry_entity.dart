import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/domain/entities/support_inquiry_category.dart';
import 'package:qradar/domain/entities/support_inquiry_status.dart';

part 'support_inquiry_entity.freezed.dart';

/// 관리자 답변 (append-only, 1건).
@freezed
abstract class SupportInquiryAnswer with _$SupportInquiryAnswer {
  const factory SupportInquiryAnswer({
    required String body,
    required String answeredBy,
    DateTime? answeredAt,
  }) = _SupportInquiryAnswer;
}

/// 문의 생성 시점에 박제된 주문 맥락 (주문이 바뀌거나 삭제돼도 유지).
@freezed
abstract class SupportInquiryOrderSnapshot with _$SupportInquiryOrderSnapshot {
  const factory SupportInquiryOrderSnapshot({
    required String storeId,
    required String storeName,
    int? pickupNumber,
    required int totalPrice,
    @Default('') String status,
    DateTime? createdAt,
  }) = _SupportInquiryOrderSnapshot;
}

/// 고객센터 문의 한 건.
@freezed
abstract class SupportInquiryEntity with _$SupportInquiryEntity {
  const SupportInquiryEntity._();

  const factory SupportInquiryEntity({
    required String id,
    required String userId,
    required SupportInquiryCategory category,
    required String title,
    required String body,
    @Default(<String>[]) List<String> imageUrls,
    String? orderId,
    SupportInquiryOrderSnapshot? orderSnapshot,
    required SupportInquiryStatus status,
    SupportInquiryAnswer? answer,
    DateTime? answerReadAt,
    required DateTime createdAt,
    DateTime? updatedAt,
    DateTime? withdrawnAt,
    DateTime? closedAt,
    String? closedReason,
    @Default(false) bool authorDeleted,
  }) = _SupportInquiryEntity;

  /// 미확인 답변 — dot 의 **단일 기준**. 목록 타일·더보기 타일·읽음 처리가 모두 이 정의를 쓴다.
  ///
  /// 답변이 있고 아직 안 읽었으면 `answered` 뿐 아니라 `closed`(답변 후 읽기 전 종결)도 포함한다.
  /// FCM 이 없어 dot 이 답변 도착을 아는 유일한 경로이기 때문. `withdrawn` 은 답변이 있을 수 없어 제외.
  bool get hasUnreadAnswer =>
      (status == SupportInquiryStatus.answered ||
          status == SupportInquiryStatus.closed) &&
      answer != null &&
      answerReadAt == null;
}

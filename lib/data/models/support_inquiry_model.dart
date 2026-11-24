import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/domain/entities/support_inquiry_category.dart';
import 'package:qradar/domain/entities/support_inquiry_entity.dart';
import 'package:qradar/domain/entities/support_inquiry_status.dart';

/// Firestore `supportInquiries/{id}` 문서 매퍼.
///
/// **생성은 Cloud Function 전담**이라 `toFirestoreForCreate` 를 두지 않는다.
/// 고객 쓰기는 철회·읽음 2개뿐 — [patchForWithdraw] / [patchForAnswerRead] 의 키 집합은
/// `firestore.rules` 의 `isCustomerWithdraw` / `isCustomerAnswerRead` 화이트리스트와 **1:1** 이다 (drift 금지).
class SupportInquiryModel {
  const SupportInquiryModel({
    required this.id,
    required this.userId,
    required this.category,
    required this.title,
    required this.body,
    required this.imageUrls,
    this.orderId,
    this.orderSnapshot,
    required this.status,
    this.answer,
    this.answerReadAt,
    required this.createdAt,
    this.updatedAt,
    this.withdrawnAt,
    this.closedAt,
    this.closedReason,
    required this.authorDeleted,
  });

  final String id;
  final String userId;
  final SupportInquiryCategory category;
  final String title;
  final String body;
  final List<String> imageUrls;
  final String? orderId;
  final SupportInquiryOrderSnapshot? orderSnapshot;
  final SupportInquiryStatus status;
  final SupportInquiryAnswer? answer;
  final DateTime? answerReadAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? withdrawnAt;
  final DateTime? closedAt;
  final String? closedReason;
  final bool authorDeleted;

  factory SupportInquiryModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => SupportInquiryModel.fromMap(
    doc.id,
    doc.data() ?? const <String, dynamic>{},
  );

  /// 필드 누락/오염에 안전한 파서 (단위 테스트 진입점).
  factory SupportInquiryModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime? ts(Object? v) => v is Timestamp ? v.toDate() : null;

    SupportInquiryAnswer? answer;
    final rawAnswer = data['answer'];
    if (rawAnswer is Map) {
      final body = rawAnswer['body'];
      if (body is String && body.isNotEmpty) {
        answer = SupportInquiryAnswer(
          body: body,
          answeredBy: (rawAnswer['answeredBy'] as String?) ?? '',
          answeredAt: ts(rawAnswer['answeredAt']),
        );
      }
    }

    SupportInquiryOrderSnapshot? snapshot;
    final rawSnap = data['orderSnapshot'];
    if (rawSnap is Map) {
      snapshot = SupportInquiryOrderSnapshot(
        storeId: (rawSnap['storeId'] as String?) ?? '',
        storeName: (rawSnap['storeName'] as String?) ?? '',
        pickupNumber: (rawSnap['pickupNumber'] as num?)?.toInt(),
        totalPrice: (rawSnap['totalPrice'] as num?)?.toInt() ?? 0,
        status: (rawSnap['status'] as String?) ?? '',
        createdAt: ts(rawSnap['createdAt']),
      );
    }

    final rawImages = data['imageUrls'];
    return SupportInquiryModel(
      id: id,
      userId: (data['userId'] as String?) ?? '',
      category: SupportInquiryCategory.fromCode(data['category'] as String?),
      title: (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      imageUrls: rawImages is List
          ? rawImages.whereType<String>().toList(growable: false)
          : const <String>[],
      orderId: data['orderId'] as String?,
      orderSnapshot: snapshot,
      status: SupportInquiryStatus.fromCode(data['status'] as String?),
      answer: answer,
      answerReadAt: ts(data['answerReadAt']),
      // serverTimestamp 미확정 로컬 스냅샷은 null → 현재 시각으로 대체.
      createdAt: ts(data['createdAt']) ?? DateTime.now(),
      updatedAt: ts(data['updatedAt']),
      withdrawnAt: ts(data['withdrawnAt']),
      closedAt: ts(data['closedAt']),
      closedReason: data['closedReason'] as String?,
      authorDeleted: data['authorDeleted'] == true,
    );
  }

  SupportInquiryEntity toEntity() => SupportInquiryEntity(
    id: id,
    userId: userId,
    category: category,
    title: title,
    body: body,
    imageUrls: imageUrls,
    orderId: orderId,
    orderSnapshot: orderSnapshot,
    status: status,
    answer: answer,
    answerReadAt: answerReadAt,
    createdAt: createdAt,
    updatedAt: updatedAt,
    withdrawnAt: withdrawnAt,
    closedAt: closedAt,
    closedReason: closedReason,
    authorDeleted: authorDeleted,
  );

  /// Rules C1: 변경 필드 = status / withdrawnAt / updatedAt.
  static Map<String, dynamic> patchForWithdraw() => <String, dynamic>{
    'status': SupportInquiryStatus.withdrawn.name,
    'withdrawnAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// Rules C2: 변경 필드 = answerReadAt / updatedAt.
  static Map<String, dynamic> patchForAnswerRead() => <String, dynamic>{
    'answerReadAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

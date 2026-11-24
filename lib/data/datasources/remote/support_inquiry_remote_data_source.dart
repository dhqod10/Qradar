import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:qradar/core/constants/firestore_paths.dart';
import 'package:qradar/core/errors/network_unavailable_exception.dart';
import 'package:qradar/core/errors/permission_denied_exception.dart';
import 'package:qradar/core/errors/support_inquiry_exception.dart';
import 'package:qradar/data/models/support_inquiry_model.dart';
import 'package:qradar/domain/repositories/support_inquiry_repository.dart';

/// Firestore `supportInquiries` + Cloud Function `createSupportInquiry` 원격 데이터소스.
/// **Firestore / Functions 직접 사용은 본 파일까지.**
///
/// 서버 message 는 화면에 싣지 않고 토큰으로만 분류한다 (`[SUPPORT_*]`).
class SupportInquiryRemoteDataSource {
  SupportInquiryRemoteDataSource({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirestorePaths.supportInquiries);

  /// 문서 ID 사전 생성 (네트워크 호출 없음).
  String newInquiryId() => _col.doc().id;

  /// 내 문의 목록. userId == + createdAt desc + limit (복합 인덱스 필요 — 배포 선행).
  Stream<List<SupportInquiryModel>> streamMine(
    String userId, {
    int limit = 50,
  }) {
    return _col
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              // 로컬(미확정) 스냅샷 필터 — CF 전담 생성이라 보통 없지만 방어한다.
              .where(
                (d) =>
                    !d.metadata.hasPendingWrites ||
                    d.data()['createdAt'] != null,
              )
              .map(SupportInquiryModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Stream<SupportInquiryModel?> streamOne(String inquiryId) {
    return _col
        .doc(inquiryId)
        .snapshots()
        .map(
          (doc) => doc.exists ? SupportInquiryModel.fromFirestore(doc) : null,
        );
  }

  /// CF 생성. 같은 [CreateSupportInquiryInput.inquiryId] 재호출은 멱등 성공.
  Future<void> create(CreateSupportInquiryInput input) async {
    try {
      await _functions
          .httpsCallable(
            'createSupportInquiry',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
          )
          .call<Object?>(<String, dynamic>{
            'inquiryId': input.inquiryId,
            'category': input.category.name,
            'title': input.title,
            'body': input.body,
            'imageUrls': input.imageUrls,
            if (input.orderId != null) 'orderId': input.orderId,
            if (input.platform != null) 'platform': input.platform,
          });
    } on FirebaseFunctionsException catch (e) {
      throw SupportInquiryException(classifyCode(e.code, e.message, e.details));
    } catch (_) {
      throw const SupportInquiryException(SupportInquiryFailure.failed);
    }
  }

  /// 토큰·code → 실패 분류 (테스트 진입점). `details` 가 실기기에서 비는 경우가 있어 message 끝도 본다.
  static SupportInquiryFailure classifyCode(
    String code,
    String? message,
    Object? details,
  ) {
    String? reason;
    if (details is Map && details['reason'] is String) {
      reason = details['reason'] as String;
    }
    bool has(String token) =>
        reason == token || (message?.contains('[$token]') ?? false);
    if (has('SUPPORT_RATE_LIMITED')) return SupportInquiryFailure.rateLimited;
    if (has('SUPPORT_INVALID_ATTACHMENT')) {
      return SupportInquiryFailure.invalidAttachment;
    }
    if (has('SUPPORT_ORDER_NOT_FOUND')) {
      return SupportInquiryFailure.orderNotFound;
    }
    if (has('SUPPORT_ACCOUNT_DELETED')) {
      return SupportInquiryFailure.accountDeleted;
    }
    if (has('SUPPORT_INVALID_INPUT')) return SupportInquiryFailure.invalidInput;
    switch (code) {
      case 'unauthenticated':
        return SupportInquiryFailure.unauthenticated;
      case 'resource-exhausted':
        return SupportInquiryFailure.rateLimited;
      case 'unavailable':
      case 'deadline-exceeded':
        return SupportInquiryFailure.network;
      default:
        return SupportInquiryFailure.failed;
    }
  }

  /// Rules C1 철회. Rules 가 거부하면(그 사이 답변 등록) [SupportInquiryFailure.withdrawRejected].
  Future<void> withdraw(String inquiryId) => _update(
    inquiryId,
    SupportInquiryModel.patchForWithdraw(),
    isWithdraw: true,
  );

  /// Rules C2 읽음 표시.
  Future<void> markAnswerRead(String inquiryId) =>
      _update(inquiryId, SupportInquiryModel.patchForAnswerRead());

  Future<void> _update(
    String inquiryId,
    Map<String, dynamic> patch, {
    bool isWithdraw = false,
  }) async {
    try {
      await _col.doc(inquiryId).update(patch);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        if (isWithdraw) {
          throw const SupportInquiryException(
            SupportInquiryFailure.withdrawRejected,
          );
        }
        throw const PermissionDeniedException();
      }
      if (e.code == 'unavailable' || e.code == 'network-request-failed') {
        throw const NetworkUnavailableException();
      }
      rethrow;
    }
  }
}

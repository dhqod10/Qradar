import 'dart:io';

import 'package:qradar/domain/entities/support_inquiry_category.dart';
import 'package:qradar/domain/entities/support_inquiry_entity.dart';

/// 문의 생성 입력. 서버(`createSupportInquiry`)가 같은 상한으로 다시 검증한다.
class CreateSupportInquiryInput {
  const CreateSupportInquiryInput({
    required this.inquiryId,
    required this.category,
    required this.title,
    required this.body,
    this.imageUrls = const <String>[],
    this.orderId,
    this.platform,
  });

  final String inquiryId;
  final SupportInquiryCategory category;
  final String title;
  final String body;
  final List<String> imageUrls;
  final String? orderId;

  /// `ios` / `android` (재현용 메타, 신뢰 불필요).
  final String? platform;
}

abstract class SupportInquiryRepository {
  /// 클라이언트가 문서 ID 를 미리 만든다 (첨부 Storage 경로 + CF 멱등키).
  String newInquiryId();

  Stream<List<SupportInquiryEntity>> watchMyInquiries(
    String userId, {
    int limit = 50,
  });

  /// 문서가 없거나 권한이 없으면 null.
  Stream<SupportInquiryEntity?> watchInquiry(String inquiryId);

  /// CF `createSupportInquiry`. 실패는 [SupportInquiryException].
  Future<void> createInquiry(CreateSupportInquiryInput input);

  /// 첨부 업로드 (all-or-nothing). 실패 시 이미 올라간 파일을 best-effort 정리하고
  /// `SupportInquiryException(imageUploadFailed)` 를 던진다. 다운로드 URL 을 입력 순서대로 반환.
  Future<List<String>> uploadImages({
    required String userId,
    required String inquiryId,
    required List<File> files,
    void Function(int done, int total)? onProgress,
  });

  /// 업로드된 첨부 정리 (best-effort, 예외 삼킴) — CF 생성 실패 시 사용.
  Future<void> discardImages(List<String> urls);

  /// 답변 전 철회 (Rules C1).
  Future<void> withdrawInquiry(String inquiryId);

  /// 답변 읽음 표시 (Rules C2).
  Future<void> markAnswerRead(String inquiryId);
}

import 'package:qradar/domain/repositories/support_inquiry_repository.dart';

/// 답변 읽음 표시 (dot 소거).
class MarkSupportInquiryAnswerReadUseCase {
  final SupportInquiryRepository _repo;
  const MarkSupportInquiryAnswerReadUseCase(this._repo);

  Future<void> call(String inquiryId) => _repo.markAnswerRead(inquiryId);
}

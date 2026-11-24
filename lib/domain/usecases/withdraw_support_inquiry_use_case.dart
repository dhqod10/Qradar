import 'package:qradar/domain/repositories/support_inquiry_repository.dart';

/// 답변 전 문의 철회.
class WithdrawSupportInquiryUseCase {
  final SupportInquiryRepository _repo;
  const WithdrawSupportInquiryUseCase(this._repo);

  Future<void> call(String inquiryId) => _repo.withdrawInquiry(inquiryId);
}

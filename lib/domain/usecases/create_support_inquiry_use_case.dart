import 'package:qradar/core/errors/support_inquiry_exception.dart';
import 'package:qradar/domain/repositories/support_inquiry_repository.dart';

/// 문의 생성. 서버와 같은 상한을 클라이언트에서 먼저 검증한다 (서버가 최종 권위).
class CreateSupportInquiryUseCase {
  static const int maxTitle = 60;
  static const int maxBody = 2000;
  static const int maxImages = 3;

  final SupportInquiryRepository _repo;
  const CreateSupportInquiryUseCase(this._repo);

  Future<void> call(CreateSupportInquiryInput input) {
    validate(input);
    return _repo.createInquiry(
      CreateSupportInquiryInput(
        inquiryId: input.inquiryId,
        category: input.category,
        title: input.title.trim(),
        body: input.body.trim(),
        imageUrls: input.imageUrls,
        orderId: input.orderId,
        platform: input.platform,
      ),
    );
  }

  /// 실패 시 [SupportInquiryException] (invalidInput).
  static void validate(CreateSupportInquiryInput input) {
    final title = input.title.trim();
    final body = input.body.trim();
    if (input.inquiryId.isEmpty ||
        input.inquiryId.contains('/') ||
        title.isEmpty ||
        title.length > maxTitle ||
        body.isEmpty ||
        body.length > maxBody ||
        input.imageUrls.length > maxImages) {
      throw const SupportInquiryException(SupportInquiryFailure.invalidInput);
    }
  }
}

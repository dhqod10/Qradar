import 'package:qradar/domain/entities/support_inquiry_entity.dart';
import 'package:qradar/domain/repositories/support_inquiry_repository.dart';

/// 문의 단건 실시간 구독.
class WatchSupportInquiryUseCase {
  final SupportInquiryRepository _repo;
  const WatchSupportInquiryUseCase(this._repo);

  Stream<SupportInquiryEntity?> call(String inquiryId) =>
      _repo.watchInquiry(inquiryId);
}

import 'package:qradar/domain/entities/support_inquiry_entity.dart';
import 'package:qradar/domain/repositories/support_inquiry_repository.dart';

/// 내 문의 목록 (최신순, 상한 [defaultLimit]).
class WatchMySupportInquiriesUseCase {
  static const int defaultLimit = 50;

  final SupportInquiryRepository _repo;
  const WatchMySupportInquiriesUseCase(this._repo);

  Stream<List<SupportInquiryEntity>> call(
    String userId, {
    int limit = defaultLimit,
  }) => _repo.watchMyInquiries(userId, limit: limit);
}

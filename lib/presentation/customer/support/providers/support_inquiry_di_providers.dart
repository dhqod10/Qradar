import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/storage_data_source.dart';
import 'package:qradar/data/datasources/remote/support_inquiry_remote_data_source.dart';
import 'package:qradar/data/repositories/support_inquiry_repository_impl.dart';
import 'package:qradar/domain/repositories/support_inquiry_repository.dart';
import 'package:qradar/domain/usecases/create_support_inquiry_use_case.dart';
import 'package:qradar/domain/usecases/mark_support_inquiry_answer_read_use_case.dart';
import 'package:qradar/domain/usecases/upload_support_inquiry_images_use_case.dart';
import 'package:qradar/domain/usecases/watch_my_support_inquiries_use_case.dart';
import 'package:qradar/domain/usecases/watch_support_inquiry_use_case.dart';
import 'package:qradar/domain/usecases/withdraw_support_inquiry_use_case.dart';

final supportInquiryRemoteDataSourceProvider =
    Provider<SupportInquiryRemoteDataSource>((ref) {
      return SupportInquiryRemoteDataSource();
    });

final supportInquiryRepositoryProvider = Provider<SupportInquiryRepository>((
  ref,
) {
  return SupportInquiryRepositoryImpl(
    ref.watch(supportInquiryRemoteDataSourceProvider),
    StorageDataSource(),
  );
});

final watchMySupportInquiriesUseCaseProvider =
    Provider<WatchMySupportInquiriesUseCase>((ref) {
      return WatchMySupportInquiriesUseCase(
        ref.watch(supportInquiryRepositoryProvider),
      );
    });

final watchSupportInquiryUseCaseProvider = Provider<WatchSupportInquiryUseCase>(
  (ref) {
    return WatchSupportInquiryUseCase(
      ref.watch(supportInquiryRepositoryProvider),
    );
  },
);

final createSupportInquiryUseCaseProvider =
    Provider<CreateSupportInquiryUseCase>((ref) {
      return CreateSupportInquiryUseCase(
        ref.watch(supportInquiryRepositoryProvider),
      );
    });

final uploadSupportInquiryImagesUseCaseProvider =
    Provider<UploadSupportInquiryImagesUseCase>((ref) {
      return UploadSupportInquiryImagesUseCase(
        ref.watch(supportInquiryRepositoryProvider),
      );
    });

final withdrawSupportInquiryUseCaseProvider =
    Provider<WithdrawSupportInquiryUseCase>((ref) {
      return WithdrawSupportInquiryUseCase(
        ref.watch(supportInquiryRepositoryProvider),
      );
    });

final markSupportInquiryAnswerReadUseCaseProvider =
    Provider<MarkSupportInquiryAnswerReadUseCase>((ref) {
      return MarkSupportInquiryAnswerReadUseCase(
        ref.watch(supportInquiryRepositoryProvider),
      );
    });

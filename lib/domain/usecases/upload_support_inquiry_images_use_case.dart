import 'dart:io';

import 'package:qradar/domain/repositories/support_inquiry_repository.dart';

/// 문의 첨부 업로드 (all-or-nothing).
class UploadSupportInquiryImagesUseCase {
  final SupportInquiryRepository _repo;
  const UploadSupportInquiryImagesUseCase(this._repo);

  Future<List<String>> call({
    required String userId,
    required String inquiryId,
    required List<File> files,
    void Function(int done, int total)? onProgress,
  }) => _repo.uploadImages(
    userId: userId,
    inquiryId: inquiryId,
    files: files,
    onProgress: onProgress,
  );
}

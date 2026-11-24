import 'dart:io';

import 'package:qradar/core/errors/support_inquiry_exception.dart';
import 'package:qradar/data/datasources/remote/storage_data_source.dart';
import 'package:qradar/data/datasources/remote/support_inquiry_remote_data_source.dart';
import 'package:qradar/domain/entities/support_inquiry_entity.dart';
import 'package:qradar/domain/repositories/support_inquiry_repository.dart';

/// [SupportInquiryRepository] 구현체. DataSource 외 직접 Firebase 접근 금지.
class SupportInquiryRepositoryImpl implements SupportInquiryRepository {
  SupportInquiryRepositoryImpl(this._remote, this._storage);

  final SupportInquiryRemoteDataSource _remote;
  final StorageDataSource _storage;

  @override
  String newInquiryId() => _remote.newInquiryId();

  @override
  Stream<List<SupportInquiryEntity>> watchMyInquiries(
    String userId, {
    int limit = 50,
  }) => _remote
      .streamMine(userId, limit: limit)
      .map((l) => l.map((m) => m.toEntity()).toList(growable: false));

  @override
  Stream<SupportInquiryEntity?> watchInquiry(String inquiryId) =>
      _remote.streamOne(inquiryId).map((m) => m?.toEntity());

  @override
  Future<void> createInquiry(CreateSupportInquiryInput input) =>
      _remote.create(input);

  @override
  Future<List<String>> uploadImages({
    required String userId,
    required String inquiryId,
    required List<File> files,
    void Function(int done, int total)? onProgress,
  }) async {
    final urls = <String>[];
    try {
      for (final file in files) {
        urls.add(
          await _storage.uploadSupportInquiryImage(
            uid: userId,
            inquiryId: inquiryId,
            file: file,
          ),
        );
        onProgress?.call(urls.length, files.length);
      }
      return urls;
    } catch (_) {
      // all-or-nothing: 이미 올라간 파일은 best-effort 정리. CF 생성 전이라 남아도 고아 파일일 뿐이다.
      await discardImages(urls);
      throw const SupportInquiryException(
        SupportInquiryFailure.imageUploadFailed,
      );
    }
  }

  @override
  Future<void> discardImages(List<String> urls) async {
    for (final u in urls) {
      await _storage.deleteByUrl(u);
    }
  }

  @override
  Future<void> withdrawInquiry(String inquiryId) => _remote.withdraw(inquiryId);

  @override
  Future<void> markAnswerRead(String inquiryId) =>
      _remote.markAnswerRead(inquiryId);
}

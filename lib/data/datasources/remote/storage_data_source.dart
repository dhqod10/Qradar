import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:qradar/core/constants/firestore_paths.dart';

/// Firebase Storage 원격 업로드/삭제 데이터소스.
class StorageDataSource {
  final FirebaseStorage _storage;

  StorageDataSource({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  /// 매장 이미지 업로드. downloadUrl 반환.
  ///
  /// 경로: `store_images/{ownerId}/{timestamp}_{filename}`
  Future<String> uploadStoreImage({
    required String ownerId,
    required File file,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = file.uri.pathSegments.last;
    final ref = _storage
        .ref()
        .child(FirestorePaths.storeImagesStoragePrefix)
        .child(ownerId)
        .child('${timestamp}_$filename');
    final task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }

  /// downloadUrl 기반 파일 삭제. 실패해도 예외를 삼킨다(연관 리소스 정리용).
  Future<void> deleteByUrl(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (_) {
      // ignore: 존재하지 않거나 권한 이슈는 상위에서 다루지 않는다.
    }
  }

  /// 브랜드 로고 이미지 업로드. downloadUrl 반환.
  ///
  /// 경로: `brand_images/{brandId}/{timestamp}_{filename}`
  Future<String> uploadBrandImage({
    required String brandId,
    required File file,
  }) async {
    _validateFileSize(file);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = file.uri.pathSegments.last;
    final ref = _storage
        .ref()
        .child(FirestorePaths.brandImagesStoragePrefix)
        .child(brandId)
        .child('${timestamp}_$filename');
    final task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }

  /// 브랜드 마스터 메뉴 이미지 업로드. downloadUrl 반환.
  ///
  /// 경로: `menu_images/brand/{brandId}/{menuItemId}/{timestamp}_{filename}`
  Future<String> uploadMasterMenuImage({
    required String brandId,
    required String menuItemId,
    required File file,
  }) async {
    _validateFileSize(file);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = file.uri.pathSegments.last;
    final ref = _storage
        .ref()
        .child(FirestorePaths.menuImagesBrandStoragePrefix)
        .child(brandId)
        .child(menuItemId)
        .child('${timestamp}_$filename');
    final task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }

  /// 개인 매장 메뉴 이미지 업로드. downloadUrl 반환.
  ///
  /// 경로: `menu_images/store/{storeId}/{menuItemId}/{timestamp}_{filename}`
  Future<String> uploadStoreMenuImage({
    required String storeId,
    required String menuItemId,
    required File file,
  }) async {
    _validateFileSize(file);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = file.uri.pathSegments.last;
    final ref = _storage
        .ref()
        .child('menu_images/store')
        .child(storeId)
        .child(menuItemId)
        .child('${timestamp}_$filename');
    final task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }

  /// 고객센터 문의 첨부 업로드. downloadUrl 반환 (support_inquiry).
  ///
  /// 경로: `support_inquiries/{uid}/{inquiryId}/{timestamp}_{filename}`
  /// Cloud Function `createSupportInquiry` 가 이 경로 prefix 를 검증한다. 크기 검증(5MB) 포함.
  /// [onProgress] 는 0.0~1.0.
  Future<String> uploadSupportInquiryImage({
    required String uid,
    required String inquiryId,
    required File file,
    void Function(double progress)? onProgress,
  }) async {
    _validateFileSize(file);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = file.uri.pathSegments.last;
    final ref = _storage
        .ref()
        .child(FirestorePaths.supportInquiryImagesStoragePrefix)
        .child(uid)
        .child(inquiryId)
        .child('${timestamp}_$filename');
    final task = ref.putFile(file, SettableMetadata(contentType: _contentType(filename)));
    final sub = task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) onProgress?.call(s.bytesTransferred / s.totalBytes);
    });
    try {
      final snap = await task;
      return await snap.ref.getDownloadURL();
    } finally {
      await sub.cancel();
    }
  }

  /// Storage Rules 가 `image/*` contentType 을 요구한다 — 확장자로 명시한다 (카메라 임시 파일 포함).
  String _contentType(String filename) {
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  /// 파일 크기 검증 (5MB 제한, S7).
  void _validateFileSize(File file) {
    const maxBytes = 5 * 1024 * 1024; // 5MB
    final bytes = file.lengthSync();
    if (bytes > maxBytes) {
      throw ArgumentError(
        '이미지 용량이 5MB를 초과했습니다. (${(bytes / 1024 / 1024).toStringAsFixed(1)}MB)',
      );
    }
  }
}

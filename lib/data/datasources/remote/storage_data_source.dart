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

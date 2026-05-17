import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:qradar/core/constants/firestore_paths.dart';
import 'package:qradar/data/models/menu_item_model.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';

/// Firestore `brands/{brandId}/menuItems` 원격 데이터소스.
///
/// 승인 큐 조회는 collectionGroup query 사용.
/// 인덱스 누락 시 에러 로그 노출 (S4 — 인덱스 생성은 별도 task).
class MasterMenuItemRemoteDataSource {
  final FirebaseFirestore _db;

  MasterMenuItemRemoteDataSource({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _menuItemsCol(String brandId) =>
      _db.collection(FirestorePaths.brandMenuItemsPath(brandId));

  /// 특정 브랜드의 마스터 메뉴 전체 실시간 스트림 (MenuItemEntity 반환).
  ///
  /// case B 머지에서 사용. 필터(status/visible)는 호출 측 머지 함수에서 적용.
  Stream<List<MenuItemEntity>> watchAllByBrand(String brandId) {
    return streamByBrand(brandId)
        .map((models) => models.map((m) => m.toEntity()).toList(growable: false));
  }

  /// 특정 브랜드의 마스터 메뉴 전체 스트림.
  Stream<List<MenuItemModel>> streamByBrand(String brandId) {
    return _menuItemsCol(brandId)
        .orderBy('displayOrder')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) =>
                  MenuItemModel.fromFirestore(doc, storeId: ''))
              .toList(growable: false),
        );
  }

  /// collectionGroup query: 모든 브랜드의 status==pending 마스터 메뉴 (S4).
  ///
  /// 인덱스 필요: `menuItems` collectionGroup + `status == pending` + `submittedAt desc`.
  /// 인덱스 누락 시 Firebase 가 콘솔 URL 을 포함한 에러를 throw 한다.
  Stream<List<MenuItemModel>> streamPending() {
    return _db
        .collectionGroup(FirestorePaths.brandMenuItems)
        .where('scope', isEqualTo: 'brand')
        .where('status', isEqualTo: 'pending')
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .handleError((Object e, StackTrace st) {
      debugPrint(
        '[MasterMenuItemRemoteDataSource] collectionGroup query 실패. '
        'Firestore 인덱스 설정이 필요할 수 있습니다. error=$e',
      );
    }).map(
          (snap) => snap.docs
              .map((doc) =>
                  MenuItemModel.fromFirestore(doc, storeId: ''))
              .toList(growable: false),
        );
  }

  /// 단일 마스터 메뉴 조회.
  Future<MenuItemModel?> fetchById(String brandId, String menuItemId) async {
    final doc = await _menuItemsCol(brandId).doc(menuItemId).get();
    if (!doc.exists) return null;
    return MenuItemModel.fromFirestore(doc, storeId: '');
  }

  /// 단일 마스터 메뉴 stream. 삭제되면 null.
  Stream<MenuItemModel?> streamById(String brandId, String menuItemId) {
    return _menuItemsCol(brandId).doc(menuItemId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return MenuItemModel.fromFirestore(doc, storeId: '');
    });
  }

  /// 마스터 메뉴 생성. 반환: 생성된 문서 ID.
  Future<String> create(String brandId, Map<String, dynamic> data) async {
    final ref = await _menuItemsCol(brandId).add(data);
    return ref.id;
  }

  /// 마스터 메뉴 partial update.
  ///
  /// `update()` 사용으로 전달된 필드만 갱신. Core/Operation/승인/반려 호출 모두
  /// partial map 을 보내므로 `set()` 사용 시 다른 필드 데이터 손실 (FAIL-J01).
  Future<void> update(
      String brandId, String menuItemId, Map<String, dynamic> data) {
    return _menuItemsCol(brandId).doc(menuItemId).update(data);
  }

  /// 마스터 메뉴 삭제.
  Future<void> delete(String brandId, String menuItemId) {
    return _menuItemsCol(brandId).doc(menuItemId).delete();
  }

  /// 마스터 메뉴 일괄 승인. Firestore WriteBatch 사용.
  Future<void> bulkApprove(
      String brandId, List<String> menuItemIds, String adminUid) async {
    final batch = _db.batch();
    final now = FieldValue.serverTimestamp();
    for (final id in menuItemIds) {
      final ref = _menuItemsCol(brandId).doc(id);
      batch.update(ref, <String, dynamic>{
        'status': 'approved',
        'approvedBy': adminUid,
        'approvedAt': now,
        'rejectedReason': null,
        'updatedAt': now,
      });
    }
    await batch.commit();
  }

  /// 마스터 메뉴 일괄 반려. Firestore WriteBatch 사용.
  Future<void> bulkReject(String brandId, List<String> menuItemIds,
      String adminUid, String reason) async {
    final batch = _db.batch();
    final now = FieldValue.serverTimestamp();
    for (final id in menuItemIds) {
      final ref = _menuItemsCol(brandId).doc(id);
      batch.update(ref, <String, dynamic>{
        'status': 'rejected',
        'approvedBy': adminUid,
        'rejectedReason': reason,
        'updatedAt': now,
      });
    }
    await batch.commit();
  }

  /// cascade: 모든 매장의 `menuOverrides/{masterMenuItemId}` batch delete (S9).
  ///
  /// 본 sub-phase: 대상 컬렉션(`menuOverrides`) 자체가 없으므로 항상 0건.
  Future<void> cascadeDeleteOverrides(String masterMenuItemId) async {
    // sub-phase 3 에서 menuOverrides 가 도입된 후 실제 동작.
    // 현재는 no-op.
    debugPrint(
      '[MasterMenuItemRemoteDataSource] cascadeDeleteOverrides: '
      'menuOverrides 컬렉션은 sub-phase 3 에서 활성화됩니다.',
    );
  }
}

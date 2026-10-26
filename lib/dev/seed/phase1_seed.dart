// DEV_ONLY_SEED — order_flow_phase1, phase2 추가. 사용자 요청 시 lib/dev/seed/ 폴더 통째로 삭제.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/core/constants/firestore_paths.dart';
import 'package:qradar/dev/seed/phase1_seed_data.dart';

/// Phase 1 시드 결과.
class SeedResult {
  final int subCategoryCount;
  final int masterOptionGroupCount;
  final int storeOptionGroupCount;
  final int menuItemCount;
  final bool storeUpserted;
  final int orderLogCount;
  final bool brandUpserted;
  final int brandMasterMenuCount;
  final bool brandStoreUpserted;

  const SeedResult({
    required this.subCategoryCount,
    required this.masterOptionGroupCount,
    required this.storeOptionGroupCount,
    required this.menuItemCount,
    required this.storeUpserted,
    this.orderLogCount = 0,
    this.brandUpserted = false,
    this.brandMasterMenuCount = 0,
    this.brandStoreUpserted = false,
  });

  String summary() {
    return [
      'subCategories: $subCategoryCount',
      'masterOptionGroups: $masterOptionGroupCount',
      'storeOptionGroups: $storeOptionGroupCount',
      'store (개인): ${storeUpserted ? 'upsert' : 'skip'}',
      'menuItems: $menuItemCount',
      'orderLogs: $orderLogCount',
      'brand: ${brandUpserted ? 'upsert' : 'skip'}',
      'brandMasterMenus: $brandMasterMenuCount',
      'brandStore: ${brandStoreUpserted ? 'upsert' : 'skip'}',
    ].join('\n');
  }
}

/// Phase 1 + Phase 2 시드.
///
/// - 메뉴/옵션/카테고리/임시 매장+메뉴: Phase 1
/// - 사용자 OrderLog 7건: Phase 2 (uid 가 주어진 경우만)
///
/// 동일 ID 존재 시 `merge: true` 로 안전하게 덮어쓴다.
Future<SeedResult> runPhase1Seed({
  FirebaseFirestore? firestore,
  String? uid,
}) async {
  final db = firestore ?? FirebaseFirestore.instance;
  final batch = db.batch();

  // subCategories
  for (final sc in Phase1SeedData.subCategories) {
    final id = sc['id'] as String;
    final ref = db.collection(FirestorePaths.subCategories).doc(id);
    final data = Map<String, dynamic>.from(sc)..remove('id');
    batch.set(ref, data, SetOptions(merge: true));
  }

  // master option groups
  for (final og in Phase1SeedData.masterOptionGroups) {
    final id = og['id'] as String;
    final ref = db.collection(FirestorePaths.optionGroups).doc(id);
    final data = Map<String, dynamic>.from(og)..remove('id');
    batch.set(ref, data, SetOptions(merge: true));
  }

  // store
  final storeRef =
      db.collection(FirestorePaths.stores).doc(Phase1SeedData.storeId);
  batch.set(storeRef, Phase1SeedData.storeDoc(), SetOptions(merge: true));

  // store option groups
  for (final og in Phase1SeedData.storeOptionGroups) {
    final id = og['id'] as String;
    final ref = storeRef
        .collection(FirestorePaths.optionGroupsSubcollection)
        .doc(id);
    final data = Map<String, dynamic>.from(og)..remove('id');
    batch.set(ref, data, SetOptions(merge: true));
  }

  // menu items
  final items = Phase1SeedData.menuItems();
  for (final mi in items) {
    final id = mi['id'] as String;
    final ref = storeRef.collection(FirestorePaths.menuItems).doc(id);
    final data = Map<String, dynamic>.from(mi)
      ..remove('id')
      ..['createdAt'] = FieldValue.serverTimestamp();
    batch.set(ref, data, SetOptions(merge: true));
  }

  // order logs (Phase 2)
  var orderLogCount = 0;
  if (uid != null && uid.isNotEmpty) {
    final logs = Phase1SeedData.orderLogs(uid: uid, now: DateTime.now());
    for (final l in logs) {
      final id = l['id'] as String;
      final ref = db
          .collection(FirestorePaths.users)
          .doc(uid)
          .collection(FirestorePaths.orderLogs)
          .doc(id);
      final data = Map<String, dynamic>.from(l)..remove('id');
      batch.set(ref, data, SetOptions(merge: true));
    }
    orderLogCount = logs.length;
  }

  // ── sub-phase 3: brand + brand master menus + brand store ─────────────────
  // brand doc
  final brandRef =
      db.collection(FirestorePaths.brands).doc(Phase1SeedData.brandId);
  batch.set(brandRef, Phase1SeedData.brandDoc(), SetOptions(merge: true));

  // brand master menu items
  final brandMenuItems = Phase1SeedData.brandMasterMenuItems();
  for (final bm in brandMenuItems) {
    final id = bm['id'] as String;
    final ref = brandRef
        .collection(FirestorePaths.brandMenuItems)
        .doc(id);
    final data = Map<String, dynamic>.from(bm)
      ..remove('id')
      ..['createdAt'] = FieldValue.serverTimestamp();
    batch.set(ref, data, SetOptions(merge: true));
  }

  // brand store
  final brandStoreRef =
      db.collection(FirestorePaths.stores).doc(Phase1SeedData.brandStoreId);
  batch.set(
      brandStoreRef, Phase1SeedData.brandStoreDoc(), SetOptions(merge: true));

  await batch.commit();

  return SeedResult(
    subCategoryCount: Phase1SeedData.subCategories.length,
    masterOptionGroupCount: Phase1SeedData.masterOptionGroups.length,
    storeOptionGroupCount: Phase1SeedData.storeOptionGroups.length,
    menuItemCount: items.length,
    storeUpserted: true,
    orderLogCount: orderLogCount,
    brandUpserted: true,
    brandMasterMenuCount: brandMenuItems.length,
    brandStoreUpserted: true,
  );
}

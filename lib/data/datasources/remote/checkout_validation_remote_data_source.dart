import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/core/constants/firestore_paths.dart';
import 'package:qradar/data/models/menu_item_model.dart';
import 'package:qradar/data/models/menu_override_model.dart';

/// 매장 문서에서 읽은 **가공 전** 필드 (payment_server_authority spec §6.3).
class RawStoreFields {
  const RawStoreFields({
    required this.rawStatus,
    required this.hasApprovedAt,
    required this.brandId,
  });

  final String? rawStatus;
  final bool hasApprovedAt;
  final String? brandId;
}

/// 결제 선검증용 신선 읽기 데이터소스. 모든 읽기는 `Source.server` 다 (design N5 — 캐시로 결제를 막지 않는다).
/// 읽기 실패는 예외로 전파한다.
class CheckoutValidationRemoteDataSource {
  CheckoutValidationRemoteDataSource({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _server = GetOptions(source: Source.server);

  /// `stores/{storeId}`. 문서가 없으면 null.
  /// `status` 는 `StoreModel` / `EntityApprovalStatus.fromString` 을 거치지 않고 원시 문자열로 읽는다.
  Future<RawStoreFields?> fetchStore(String storeId) async {
    final snap = await _db
        .collection(FirestorePaths.stores)
        .doc(storeId)
        .get(_server);
    if (!snap.exists) return null;
    final data = snap.data() ?? const <String, dynamic>{};
    final status = data['status'];
    final brandId = data['brandId'];
    return RawStoreFields(
      rawStatus: status is String ? status : null,
      hasApprovedAt: data['approvedAt'] != null,
      brandId: brandId is String && brandId.isNotEmpty ? brandId : null,
    );
  }

  /// 메뉴 id 별 문서 3종을 읽는다 (서버 `paymentGateReader.getMenuDocs` 와 같은 대상).
  Future<
    Map<
      String,
      ({
        MenuItemModel? storeMenu,
        MenuItemModel? master,
        MenuOverrideModel? override,
      })
    >
  >
  fetchMenuDocs({
    required String storeId,
    required String? brandId,
    required List<String> menuItemIds,
  }) async {
    final store = _db.collection(FirestorePaths.stores).doc(storeId);
    final entries = await Future.wait(
      menuItemIds.map((id) async {
        final storeMenuF = store
            .collection(FirestorePaths.menuItems)
            .doc(id)
            .get(_server);
        Future<DocumentSnapshot<Map<String, dynamic>>>? overrideF;
        Future<DocumentSnapshot<Map<String, dynamic>>>? masterF;
        if (brandId != null) {
          overrideF = store
              .collection(FirestorePaths.menuOverrides)
              .doc(id)
              .get(_server);
          masterF = _db
              .collection(FirestorePaths.brands)
              .doc(brandId)
              .collection(FirestorePaths.brandMenuItems)
              .doc(id)
              .get(_server);
        }
        final storeSnap = await storeMenuF;
        final overrideSnap = overrideF == null ? null : await overrideF;
        final masterSnap = masterF == null ? null : await masterF;
        return MapEntry(id, (
          storeMenu: storeSnap.exists
              ? MenuItemModel.fromFirestore(storeSnap, storeId: storeId)
              : null,
          master: masterSnap != null && masterSnap.exists
              ? MenuItemModel.fromFirestore(masterSnap, storeId: '')
              : null,
          override: overrideSnap != null && overrideSnap.exists
              ? MenuOverrideModel.fromFirestore(overrideSnap, storeId)
              : null,
        ));
      }),
    );
    return Map.fromEntries(entries);
  }
}

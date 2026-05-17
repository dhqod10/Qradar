import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/repositories/menu_item_repository.dart';

/// 개인 매장 메뉴 복제 UseCase (sub-phase 4, V8).
///
/// DB 저장 X — prefill 된 entity 반환만 수행.
/// name = '{원본 이름} 복사', imageUrl = '', status = approved, 승인 메타 reset, id = ''.
class CloneOwnerStoreMenuUseCase {
  final MenuItemRepository _repository;

  CloneOwnerStoreMenuUseCase(this._repository);

  /// [storeId], [menuItemId] 로 원본 fetch → copyWith → 반환 (DB 저장 없음).
  /// 원본이 없으면 null 반환.
  Future<MenuItemEntity?> call(String storeId, String menuItemId) async {
    MenuItemEntity? source;
    // watchById 스트림을 1회성으로 읽음
    await for (final item
        in _repository.watchById(storeId: storeId, menuItemId: menuItemId)) {
      source = item;
      break;
    }
    if (source == null) return null;
    return source.copyWith(
      id: '',
      name: '${source.name} 복사',
      imageUrl: '',
      status: EntityApprovalStatus.approved,
      submittedBy: null,
      submittedAt: null,
      approvedBy: null,
      approvedAt: null,
      rejectedReason: null,
    );
  }
}

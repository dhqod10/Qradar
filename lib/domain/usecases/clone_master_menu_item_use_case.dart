import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/repositories/master_menu_item_repository.dart';

class CloneMasterMenuItemUseCase {
  final MasterMenuItemRepository _repository;

  const CloneMasterMenuItemUseCase(this._repository);

  /// 원본 메뉴를 draft 로 복제. DB 저장 없음 (폼 prefill 용).
  ///
  /// copyWith: id='', name='{원본} 복사', status=null, 승인 메타 reset.
  Future<MenuItemEntity> call(String brandId, String sourceId) =>
      _repository.cloneAsDraft(brandId, sourceId);
}

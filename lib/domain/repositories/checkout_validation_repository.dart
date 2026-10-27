import 'package:qradar/core/utils/option_availability.dart';
import 'package:qradar/domain/entities/checkout_validation.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';

/// 결제 선검증용 **신선 읽기**(서버 source) 저장소 (payment_server_authority design N5).
///
/// 오래된 스트림 캐시 하나로 결제를 막지 않기 위해 구현은 캐시를 쓰지 않는다. 읽기 실패는 **예외로 전파**한다
/// (실패를 "통과"로 바꾸는 것은 UseCase 의 몫이다).
abstract class CheckoutValidationRepository {
  /// `stores/{storeId}` 의 원시 status / approvedAt / brandId. 문서가 없으면 null.
  Future<StoreSellabilityInput?> fetchStoreFresh(String storeId);

  /// 메뉴 종류([menuItemIds]) 별 문서. [brandId] 가 null 이면 override/마스터는 읽지 않는다.
  /// 반환 map 은 [menuItemIds] 의 모든 키를 가진다 (문서가 없으면 값이 비어 있는 [CheckoutMenuDocs]).
  Future<Map<String, CheckoutMenuDocs>> fetchMenuDocsFresh({
    required String storeId,
    required String? brandId,
    required List<String> menuItemIds,
  });

  /// 재가격(payment_price_authority R9)용 옵션 그룹 문서 신선 읽기. 키는 [optionRefKey].
  /// 문서가 없으면 값이 null 이다. brand scope 는 [brandId] 가 null 이면 읽지 않고 null (서버 `getOptionGroups` 와 같다).
  /// 읽기 실패는 예외로 전파한다.
  Future<Map<String, OptionGroupEntity?>> fetchOptionGroupsFresh({
    required String storeId,
    required String? brandId,
    required List<OptionGroupRef> refs,
  });
}

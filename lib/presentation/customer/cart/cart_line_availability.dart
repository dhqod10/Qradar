import 'package:qradar/domain/entities/checkout_validation.dart';

/// 카트 행 상태 (payment_server_authority design §4.1).
///
/// **`verified` / `ok` 같은 "확인됨" 값을 추가하지 않는다** (design N1·N2). 통과는 "아무 표시 없음" 이며
/// 선검증이 조용히 실패한 상태와 화면에서 구분되면 안 된다. `normal` = 모름 또는 문제 없음.
enum CartLineAvailability { normal, soldOut, unavailable, rejectedByServer }

/// 카트 상단 배너 변형 (design §4.2).
enum CartBannerVariant {
  unavailableMenus,
  serverRejectedOnly,
  storeUnavailable,
}

/// 한 메뉴의 행 상태. 직접 읽어서 확인한 위반이 서버 지목보다 우선한다.
CartLineAvailability resolveCartLineAvailability({
  required String menuItemId,
  required CheckoutValidation validation,
  required Set<String> rejectedMenuItemIds,
}) {
  for (final m in validation.menus) {
    if (m.menuItemId != menuItemId) continue;
    return m.kind == MenuViolationKind.soldOut
        ? CartLineAvailability.soldOut
        : CartLineAvailability.unavailable;
  }
  if (rejectedMenuItemIds.contains(menuItemId)) {
    return CartLineAvailability.rejectedByServer;
  }
  return CartLineAvailability.normal;
}

/// 배너 변형. 표시할 것이 없으면 null (= 배너 없음, 통과와 확인 실패가 같다).
CartBannerVariant? resolveCartBannerVariant({
  required Iterable<CartLineAvailability> lines,
  required CheckoutValidation validation,
}) {
  if (validation.store != null) return CartBannerVariant.storeUnavailable;
  var rejected = false;
  for (final a in lines) {
    if (a == CartLineAvailability.soldOut ||
        a == CartLineAvailability.unavailable) {
      return CartBannerVariant.unavailableMenus;
    }
    if (a == CartLineAvailability.rejectedByServer) rejected = true;
  }
  return rejected ? CartBannerVariant.serverRejectedOnly : null;
}

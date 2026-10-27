import 'package:qradar/domain/entities/checkout_validation.dart';

/// 카트 행 상태 (payment_server_authority design §4.1).
///
/// **`verified` / `ok` / `priceChecked` 같은 "확인됨" 값을 추가하지 않는다** (design N1·N2·P5). 통과는 "아무 표시 없음" 이며
/// 선검증이 조용히 실패한 상태와 화면에서 구분되면 안 된다. `normal` = 모름 또는 문제 없음.
/// `optionUnavailable` 은 위반이다 (payment_price_authority design §5.5) — "확인됨" 이 아니다.
/// 가격 변동은 이 enum 이 아니라 별도 값(`CartLinePriceChange`)이다.
enum CartLineAvailability {
  normal,
  soldOut,
  unavailable,
  optionUnavailable,
  rejectedByServer,
}

/// 카트 상단 배너 변형 (design §4.2).
enum CartBannerVariant {
  unavailableMenus,
  optionUnavailable,
  serverRejectedOnly,
  storeUnavailable,
}

/// 한 메뉴의 행 상태. 직접 읽어서 확인한 위반이 서버 지목보다 우선한다.
CartLineAvailability resolveCartLineAvailability({
  required String menuItemId,
  String? cartItemId,
  required CheckoutValidation validation,
  required Set<String> rejectedMenuItemIds,
}) {
  for (final m in validation.menus) {
    if (m.menuItemId != menuItemId) continue;
    return m.kind == MenuViolationKind.soldOut
        ? CartLineAvailability.soldOut
        : CartLineAvailability.unavailable;
  }
  // 옵션 위반은 라인 단위다 (같은 메뉴를 옵션만 달리해 담은 두 줄 중 한 줄만 위반일 수 있다).
  for (final o in validation.optionIssues) {
    if (cartItemId != null
        ? o.cartItemId == cartItemId
        : o.menuItemId == menuItemId) {
      return CartLineAvailability.optionUnavailable;
    }
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
  var option = false;
  var rejected = false;
  for (final a in lines) {
    if (a == CartLineAvailability.soldOut ||
        a == CartLineAvailability.unavailable) {
      return CartBannerVariant.unavailableMenus;
    }
    if (a == CartLineAvailability.optionUnavailable) option = true;
    if (a == CartLineAvailability.rejectedByServer) rejected = true;
  }
  if (option) return CartBannerVariant.optionUnavailable;
  return rejected ? CartBannerVariant.serverRejectedOnly : null;
}

import 'package:qradar/core/utils/store_menu_visibility.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_override_entity.dart';

/// 결제 시점 메뉴 1종의 판정 결과 (payment_server_authority spec §7.2 ③).
enum CheckoutMenuVerdict { ok, soldOut, excluded, notFound }

/// `menuItemId` 하나를 **문서 존재로 역추론**해 분류한다. 클라이언트가 선언한 scope/brandId 를 쓰지 않는다 (spec §5-3).
///
/// - [storeMenu]: `stores/{s}/menuItems/{id}` (개인 매장 메뉴 / 가맹점 점포 한정 메뉴)
/// - [master]   : `brands/{b}/menuItems/{id}` — **매장에 brandId 가 있을 때만** 읽는다 ([hasBrand]).
/// - [override] : `stores/{s}/menuOverrides/{id}`
///
/// 서버 `functions/src/menuVisibility.ts classifyCartMenu` 와 같은 규칙이며
/// `test_fixtures/checkout_menu_gate_contract.json` 으로 양방향 고정된다.
/// override 적용은 [applyOverrideForCustomer] 한 곳이다 (복제 금지).
CheckoutMenuVerdict classifyCheckoutMenu({
  required bool hasBrand,
  required MenuItemEntity? storeMenu,
  required MenuItemEntity? master,
  required MenuOverrideEntity? override,
}) {
  if (storeMenu != null) {
    if (!storeMenu.visible) return CheckoutMenuVerdict.excluded;
    if (storeMenu.soldOut) return CheckoutMenuVerdict.soldOut;
    return CheckoutMenuVerdict.ok;
  }
  if (hasBrand && master != null) {
    final merged = applyOverrideForCustomer(master: master, override: override);
    if (merged == null) return CheckoutMenuVerdict.excluded;
    if (merged.soldOut) return CheckoutMenuVerdict.soldOut;
    return CheckoutMenuVerdict.ok;
  }
  return CheckoutMenuVerdict.notFound;
}

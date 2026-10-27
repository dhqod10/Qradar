import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_override_entity.dart';

/// 결제 선검증(payment_server_authority spec §7.4, design §4.0)이 매장 문서에서 읽은 **가공 전 원시값**.
///
/// `canSellNow` 의 입력이다. `EntityApprovalStatus.fromString` 을 통과시키지 않는다 (fail-open 복제 금지, spec §6.3).
class StoreSellabilityInput {
  const StoreSellabilityInput({
    required this.rawStatus,
    required this.hasApprovedAt,
    this.brandId,
  });

  /// `stores/{id}.status` 가공 전 문자열. 부재/비문자열이면 null.
  final String? rawStatus;

  /// `stores/{id}.approvedAt != null`
  final bool hasApprovedAt;

  /// `stores/{id}.brandId` (비어 있으면 null). 마스터 메뉴를 읽을지 결정하는 데만 쓴다.
  final String? brandId;
}

/// 메뉴 1종의 판정 입력 (spec §7.2 ②). 문서 존재로 역추론한다 — 카트의 scope/brandId 를 믿지 않는다.
class CheckoutMenuDocs {
  const CheckoutMenuDocs({this.storeMenu, this.master, this.override});

  final MenuItemEntity? storeMenu;
  final MenuItemEntity? master;
  final MenuOverrideEntity? override;
}

/// 매장 단위 위반.
enum StoreViolation { notSellable, notFound }

/// 메뉴 위반 종류. `unavailable` = 판매 중단(excluded) 또는 메뉴 부재(notFound) — UI 는 둘을 구분하지 않는다.
enum MenuViolationKind { soldOut, unavailable }

class MenuViolation {
  const MenuViolation({required this.menuItemId, required this.kind});

  final String menuItemId;
  final MenuViolationKind kind;
}

/// 선검증 결과. **위반을 직접 읽어서 확인했을 때만** 위반이 들어 있다.
///
/// 확인 실패(네트워크/타임아웃/권한)는 [none] 과 구분되지 않는다 (design N1·N2, spec §8.2).
/// 이 타입에 `failed` / `verified` 를 두지 않는다.
class CheckoutValidation {
  const CheckoutValidation({this.store, this.menus = const []});

  static const CheckoutValidation none = CheckoutValidation();

  final StoreViolation? store;
  final List<MenuViolation> menus;

  bool get hasViolations => store != null || menus.isNotEmpty;

  /// 위반 메뉴 id 집합 (종류 단위, 중복 없음).
  Set<String> get violatedMenuItemIds => {for (final m in menus) m.menuItemId};
}

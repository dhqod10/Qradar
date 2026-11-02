import 'package:qradar/core/utils/option_availability.dart';
import 'package:qradar/domain/entities/business_hours.dart';
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
    this.temporaryClosed = false,
    this.businessHours,
    this.closedDates = const [],
  });

  /// `stores/{id}.status` 가공 전 문자열. 부재/비문자열이면 null.
  final String? rawStatus;

  /// `stores/{id}.approvedAt != null`
  final bool hasApprovedAt;

  /// `stores/{id}.brandId` (비어 있으면 null). 마스터 메뉴를 읽을지 결정하는 데만 쓴다.
  final String? brandId;

  /// `stores/{id}.temporaryClosed == true` 원시 읽기 (부재/비bool → false).
  final bool temporaryClosed;

  /// `stores/{id}.businessHours` (null = 스케줄 미설정 = 시간 제한 없음, Q1).
  final BusinessHours? businessHours;

  /// `stores/{id}.closedDates` (특정 날짜 휴무). 스케줄이 없어도 오늘이 포함되면 닫힘.
  final List<DateTime> closedDates;
}

/// 메뉴 1종의 판정 입력 (spec §7.2 ②). 문서 존재로 역추론한다 — 카트의 scope/brandId 를 믿지 않는다.
class CheckoutMenuDocs {
  const CheckoutMenuDocs({this.storeMenu, this.master, this.override});

  final MenuItemEntity? storeMenu;
  final MenuItemEntity? master;
  final MenuOverrideEntity? override;
}

/// 매장 단위 위반.
enum StoreViolation { notSellable, temporarilyClosed, closedSchedule, notFound }

/// 메뉴 위반 종류. `unavailable` = 판매 중단(excluded) 또는 메뉴 부재(notFound) — UI 는 둘을 구분하지 않는다.
enum MenuViolationKind { soldOut, unavailable }

class MenuViolation {
  const MenuViolation({required this.menuItemId, required this.kind});

  final String menuItemId;
  final MenuViolationKind kind;
}

/// 재가격으로 **단가가 달라진** 카트 라인 1건 (payment_price_authority R9). 금액은 `computeCartAmount` 와 같은 식으로
/// 문서에서 다시 계산한 값이다 — presentation 이 계산하지 않는다.
class RepricedLine {
  const RepricedLine({
    required this.cartItemId,
    required this.menuItemId,
    required this.menuItemName,
    required this.oldUnitPrice,
    required this.newUnitPrice,
  });

  final String cartItemId;
  final String menuItemId;
  final String menuItemName;
  final int oldUnitPrice;
  final int newUnitPrice;

  bool get isIncrease => newUnitPrice > oldUnitPrice;
}

/// 카트 라인 하나의 옵션 선택이 지금은 유효하지 않다 (spec R4 와 같은 판정 — `validateSelection`).
class LineOptionIssue {
  const LineOptionIssue({
    required this.cartItemId,
    required this.menuItemId,
    required this.issue,
  });

  final String cartItemId;
  final String menuItemId;
  final OptionIssue issue;
}

/// 선검증이 **직접 읽어서** 다시 계산한 결과. 읽기 실패·타임아웃이면 만들어지지 않는다 (선검증은 권위가 아니다).
class CartRepricing {
  const CartRepricing({
    this.priceChanges = const [],
    this.optionIssues = const [],
  });

  static const CartRepricing none = CartRepricing();

  /// 단가가 달라진 라인. 옵션 위반 라인은 유효한 가격이 없으므로 여기에 들어가지 않는다.
  final List<RepricedLine> priceChanges;
  final List<LineOptionIssue> optionIssues;
}

/// 선검증 결과. **위반을 직접 읽어서 확인했을 때만** 위반이 들어 있다.
///
/// 확인 실패(네트워크/타임아웃/권한)는 [none] 과 구분되지 않는다 (design N1·N2, spec §8.2).
/// 이 타입에 `failed` / `verified` 를 두지 않는다.
class CheckoutValidation {
  const CheckoutValidation({
    this.store,
    this.menus = const [],
    this.repricing = CartRepricing.none,
  });

  static const CheckoutValidation none = CheckoutValidation();

  final StoreViolation? store;
  final List<MenuViolation> menus;

  /// 재가격 결과 (payment_price_authority R9). 가격 변동은 위반이 아니므로 [hasViolations] 에 들어가지 않는다.
  final CartRepricing repricing;

  /// 옵션 위반은 위반이다 — 서버가 어차피 거절한다 (`OPTION_UNAVAILABLE`).
  bool get hasViolations =>
      store != null || menus.isNotEmpty || repricing.optionIssues.isNotEmpty;

  bool get hasPriceChanges => repricing.priceChanges.isNotEmpty;

  List<LineOptionIssue> get optionIssues => repricing.optionIssues;
  List<RepricedLine> get priceChanges => repricing.priceChanges;

  /// 위반 메뉴 id 집합 (종류 단위, 중복 없음). 메뉴 위반만 — 옵션 위반 메뉴는 [optionViolatedMenuItemIds].
  Set<String> get violatedMenuItemIds => {for (final m in menus) m.menuItemId};

  Set<String> get optionViolatedMenuItemIds => {
    for (final o in repricing.optionIssues) o.menuItemId,
  };
}

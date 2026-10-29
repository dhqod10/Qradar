import 'package:qradar/core/utils/cart_pricing.dart';
import 'package:qradar/core/utils/checkout_menu_gate.dart';
import 'package:qradar/core/utils/option_availability.dart';
import 'package:qradar/core/utils/store_menu_visibility.dart';
import 'package:qradar/core/utils/store_sellability.dart';
import 'package:qradar/domain/entities/cart_item_entity.dart';
import 'package:qradar/domain/entities/checkout_validation.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/repositories/checkout_validation_repository.dart';

/// 서버 `MAX_OPTION_GROUP_DOCS` 와 같은 상한. 넘으면 클라이언트는 재가격을 하지 않는다 (서버가 어차피 거절한다).
const int kMaxOptionGroupDocs = 200;

/// 결제 선검증 (payment_server_authority spec §7.4, design §4.0).
///
/// **선검증은 권위가 아니다.** 위반을 직접 읽어서 확인했을 때만 위반을 반환한다. 읽기 실패·타임아웃·권한 오류는
/// [CheckoutValidation.none] 이다 (spec §8.2 — 정상 손님의 결제를 클라이언트가 막으면 안 된다). 반환 타입에
/// `failed` 가 없으므로 UI 는 "통과"와 "확인 실패"를 구분할 수 없다 (design N1).
///
/// 예외는 [reportFailure] = true (사용자가 직접 누른 `다시 확인`, design N3) 일 때만 던진다.
///
/// **재가격 (payment_price_authority R9)**: [cartItems] 를 주면 카트 라인을 **현재 문서 가격**으로 다시 계산해
/// [CheckoutValidation.repricing] 에 싣는다. 이미 읽은 메뉴 문서를 재사용하고 옵션 그룹만 더 읽는다. 판정은
/// [applyOverrideForCustomer] · [validateSelection] · [computeLinePrice] 만 호출한다 (서버와 같은 함수 — 자체 계산 금지).
/// 옵션 그룹 읽기가 실패하면 재가격만 생략한다 (메뉴 위반은 그대로 돌려준다). [reportFailure] 면 그 실패도 던진다.
///
/// 판정은 [storeGateReason] / [classifyCheckoutMenu] 만 호출한다 (자체 판정 금지).
class ValidateCheckoutUseCase {
  ValidateCheckoutUseCase(
    this._repository, {
    Duration timeout = const Duration(seconds: 3),
    Duration? userTimeout,
  }) : _timeout = timeout,
       _userTimeout = userTimeout ?? timeout;

  final CheckoutValidationRepository _repository;

  /// 자동 선검증(카트 진입·포그라운드 복귀·결제 탭) 타임아웃.
  final Duration _timeout;

  /// 사용자가 직접 누른 동작(`다시 확인`, 거절 화면의 `최신 가격으로 다시 담기`) 타임아웃 — 기다릴 의사가 있다 (design Q-D3).
  /// 앱 DI 가 5초를 넣는다. 생략하면 [timeout] 과 같다.
  final Duration _userTimeout;

  Future<CheckoutValidation> call({
    required String storeId,
    required Iterable<String> menuItemIds,
    Iterable<CartItemEntity>? cartItems,
    bool reportFailure = false,
  }) async {
    try {
      return await _evaluate(
        storeId,
        menuItemIds,
        cartItems?.toList(growable: false),
        reportFailure,
      ).timeout(reportFailure ? _userTimeout : _timeout);
    } catch (_) {
      if (reportFailure) rethrow;
      return CheckoutValidation.none;
    }
  }

  Future<CheckoutValidation> _evaluate(
    String storeId,
    Iterable<String> menuItemIds,
    List<CartItemEntity>? cartItems,
    bool reportFailure,
  ) async {
    // 메뉴 종류 단위로 1회만 판정한다 (같은 메뉴가 옵션이 달라 여러 줄이어도).
    final ids = <String>[];
    final seen = <String>{};
    for (final id in menuItemIds) {
      if (seen.add(id)) ids.add(id);
    }

    if (!_isLookupSafeId(storeId)) {
      return const CheckoutValidation(store: StoreViolation.notFound);
    }
    final store = await _repository.fetchStoreFresh(storeId);
    if (store == null) {
      return const CheckoutValidation(store: StoreViolation.notFound);
    }
    final storeReason = storeGateReason(
      rawStatus: store.rawStatus,
      hasApprovedAt: store.hasApprovedAt,
      temporaryClosed: store.temporaryClosed,
    );
    if (storeReason == kStoreTemporarilyClosed) {
      return const CheckoutValidation(store: StoreViolation.temporarilyClosed);
    }
    if (storeReason != null) {
      return const CheckoutValidation(store: StoreViolation.notSellable);
    }

    // 경로 조립에 안전하지 않은 id 는 존재할 수 없는 메뉴다 (서버 게이트와 같은 처리).
    final unsafe = ids.where((id) => !_isLookupSafeId(id)).toList();
    final readable = ids.where(_isLookupSafeId).toList(growable: false);
    final docs = readable.isEmpty
        ? const <String, CheckoutMenuDocs>{}
        : await _repository.fetchMenuDocsFresh(
            storeId: storeId,
            brandId: store.brandId,
            menuItemIds: readable,
          );

    final violations = <MenuViolation>[];
    // 재가격이 쓸 판매 가능 메뉴의 현재 문서 값 (이미 읽은 문서 — 추가 읽기 없음).
    final sellable = <String, MenuItemEntity>{};
    for (final id in ids) {
      if (unsafe.contains(id)) {
        violations.add(
          MenuViolation(menuItemId: id, kind: MenuViolationKind.unavailable),
        );
        continue;
      }
      final d = docs[id] ?? const CheckoutMenuDocs();
      final verdict = classifyCheckoutMenu(
        hasBrand: store.brandId != null,
        storeMenu: d.storeMenu,
        master: d.master,
        override: d.override,
      );
      switch (verdict) {
        case CheckoutMenuVerdict.ok:
          final merged = _mergedMenu(d, hasBrand: store.brandId != null);
          if (merged != null) sellable[id] = merged;
        case CheckoutMenuVerdict.soldOut:
          violations.add(
            MenuViolation(menuItemId: id, kind: MenuViolationKind.soldOut),
          );
        case CheckoutMenuVerdict.excluded:
        case CheckoutMenuVerdict.notFound:
          violations.add(
            MenuViolation(menuItemId: id, kind: MenuViolationKind.unavailable),
          );
      }
    }

    var repricing = CartRepricing.none;
    if (cartItems != null && cartItems.isNotEmpty && sellable.isNotEmpty) {
      try {
        repricing = await _reprice(
          storeId: storeId,
          brandId: store.brandId,
          cartItems: cartItems,
          sellable: sellable,
        );
      } catch (_) {
        // 선검증은 권위가 아니다 — 재가격만 생략한다. 사용자가 직접 누른 동작이면 정직하게 알린다.
        if (reportFailure) rethrow;
      }
    }
    if (violations.isEmpty &&
        repricing.priceChanges.isEmpty &&
        repricing.optionIssues.isEmpty) {
      return CheckoutValidation.none;
    }
    return CheckoutValidation(menus: violations, repricing: repricing);
  }

  /// 판매 가능으로 분류된 메뉴의 결제 시점 값 (단가·옵션 참조·옵션 비활성). 서버 `classifyCartMenu(...).merged` 와 같다.
  static MenuItemEntity? _mergedMenu(
    CheckoutMenuDocs d, {
    required bool hasBrand,
  }) {
    if (d.storeMenu != null) return d.storeMenu;
    if (hasBrand && d.master != null) {
      return applyOverrideForCustomer(master: d.master!, override: d.override);
    }
    return null;
  }

  /// 카트 라인을 현재 문서 가격으로 다시 계산한다. 옵션 위반 라인은 유효한 가격이 없으므로 가격 변동에서 뺀다.
  Future<CartRepricing> _reprice({
    required String storeId,
    required String? brandId,
    required List<CartItemEntity> cartItems,
    required Map<String, MenuItemEntity> sellable,
  }) async {
    final refs = <String, OptionGroupRef>{};
    for (final line in cartItems) {
      final m = sellable[line.menuItemId];
      if (m == null) continue;
      for (final r in m.optionGroupRefs) {
        refs[optionRefKey(r.scope, r.id)] = r;
      }
    }
    if (refs.length > kMaxOptionGroupDocs) return CartRepricing.none;
    final groups = refs.isEmpty
        ? <String, OptionGroupEntity?>{}
        : await _repository.fetchOptionGroupsFresh(
            storeId: storeId,
            brandId: brandId,
            refs: refs.values.toList(growable: false),
          );

    final changes = <RepricedLine>[];
    final issues = <LineOptionIssue>[];
    for (final line in cartItems) {
      final menu = sellable[line.menuItemId];
      if (menu == null) continue;
      final check = validateSelection(
        refs: menu.optionGroupRefs,
        groupsByRefKey: groups,
        disabledGroupIds: menu.disabledOptionGroupIds.toSet(),
        disabledItemIds: menu.disabledOptionItemIds.toSet(),
        selected: [
          for (final o in line.selectedOptions)
            (groupId: o.groupId, itemId: o.itemId),
        ],
      );
      if (!check.isValid) {
        for (final issue in check.issues) {
          issues.add(
            LineOptionIssue(
              cartItemId: line.cartItemId,
              menuItemId: line.menuItemId,
              issue: issue,
            ),
          );
        }
        continue;
      }
      final newUnit = computeLinePrice(
        basePrice: menu.basePrice,
        priceDeltas: check.priceDeltas,
      );
      if (newUnit != line.unitPriceWithOptions ||
          computeLineTotal(unitPrice: newUnit, quantity: line.quantity) !=
              line.lineTotal) {
        changes.add(
          RepricedLine(
            cartItemId: line.cartItemId,
            menuItemId: line.menuItemId,
            menuItemName: line.menuItemName,
            oldUnitPrice: line.unitPriceWithOptions,
            newUnitPrice: newUnit,
          ),
        );
      }
    }
    return CartRepricing(priceChanges: changes, optionIssues: issues);
  }

  static bool _isLookupSafeId(String id) =>
      id.isNotEmpty &&
      id.length <= 256 &&
      !id.contains('/') &&
      id != '.' &&
      id != '..';
}

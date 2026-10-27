import 'package:qradar/core/utils/checkout_menu_gate.dart';
import 'package:qradar/core/utils/store_sellability.dart';
import 'package:qradar/domain/entities/checkout_validation.dart';
import 'package:qradar/domain/repositories/checkout_validation_repository.dart';

/// 결제 선검증 (payment_server_authority spec §7.4, design §4.0).
///
/// **선검증은 권위가 아니다.** 위반을 직접 읽어서 확인했을 때만 위반을 반환한다. 읽기 실패·타임아웃·권한 오류는
/// [CheckoutValidation.none] 이다 (spec §8.2 — 정상 손님의 결제를 클라이언트가 막으면 안 된다). 반환 타입에
/// `failed` 가 없으므로 UI 는 "통과"와 "확인 실패"를 구분할 수 없다 (design N1).
///
/// 예외는 [reportFailure] = true (사용자가 직접 누른 `다시 확인`, design N3) 일 때만 던진다.
///
/// 판정은 [canSellNow] / [classifyCheckoutMenu] 만 호출한다 (자체 판정 금지).
class ValidateCheckoutUseCase {
  ValidateCheckoutUseCase(
    this._repository, {
    Duration timeout = const Duration(seconds: 3),
  }) : _timeout = timeout;

  final CheckoutValidationRepository _repository;
  final Duration _timeout;

  Future<CheckoutValidation> call({
    required String storeId,
    required Iterable<String> menuItemIds,
    bool reportFailure = false,
  }) async {
    try {
      return await _evaluate(storeId, menuItemIds).timeout(_timeout);
    } catch (_) {
      if (reportFailure) rethrow;
      return CheckoutValidation.none;
    }
  }

  Future<CheckoutValidation> _evaluate(
    String storeId,
    Iterable<String> menuItemIds,
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
    if (!canSellNow(
      rawStatus: store.rawStatus,
      hasApprovedAt: store.hasApprovedAt,
    )) {
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
          break;
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
    return violations.isEmpty
        ? CheckoutValidation.none
        : CheckoutValidation(menus: violations);
  }

  static bool _isLookupSafeId(String id) =>
      id.isNotEmpty &&
      id.length <= 256 &&
      !id.contains('/') &&
      id != '.' &&
      id != '..';
}

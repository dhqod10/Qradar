import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/checkout_validation_remote_data_source.dart';
import 'package:qradar/data/repositories/checkout_validation_repository_impl.dart';
import 'package:qradar/domain/entities/checkout_validation.dart';
import 'package:qradar/domain/repositories/checkout_validation_repository.dart';
import 'package:qradar/domain/usecases/validate_checkout_use_case.dart';
import 'package:qradar/presentation/customer/cart/providers/cart_providers.dart';

// ── DI ────────────────────────────────────────────────────────────────────────

final checkoutValidationRemoteDataSourceProvider =
    Provider<CheckoutValidationRemoteDataSource>(
      (ref) => CheckoutValidationRemoteDataSource(),
    );

final checkoutValidationRepositoryProvider =
    Provider<CheckoutValidationRepository>(
      (ref) => CheckoutValidationRepositoryImpl(
        ref.watch(checkoutValidationRemoteDataSourceProvider),
      ),
    );

final validateCheckoutUseCaseProvider = Provider<ValidateCheckoutUseCase>(
  (ref) =>
      ValidateCheckoutUseCase(ref.watch(checkoutValidationRepositoryProvider)),
);

// ── 서버가 직전 결제에서 지목한 메뉴 (design D6) ─────────────────────────────────

/// 서버 게이트가 지목한 `menuItemId`. **메모리 전용** (앱 재시작 시 소거).
///
/// 소거 시점 (design §9.2): 카트 비우기 · 해당 줄 삭제(= 카트에서 사라진 id 가공 — 카트 변화 때 가지치기) ·
/// 새 결제 시도 시작([clear]) · `다시 확인` 에서 신선 읽기가 정상([retainOnly]) · 앱 재시작.
class PaymentRejectedMenuIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    // 카트에서 사라진 메뉴(줄 삭제 · 카트 비우기 · 결제 성공 후 비우기)는 지목 기록에서도 지운다.
    ref.listen(cartProvider, (_, next) {
      final cart = next.value;
      if (state.isEmpty) return;
      if (cart == null) {
        state = const {};
        return;
      }
      final inCart = {for (final i in cart.items) i.menuItemId};
      final kept = state.where(inCart.contains).toSet();
      if (kept.length != state.length) state = kept;
    });
    return const {};
  }

  void addAll(Iterable<String> ids) {
    if (ids.isEmpty) return;
    state = {...state, ...ids};
  }

  void clear() {
    if (state.isNotEmpty) state = const {};
  }

  /// [keep] 에 든 id 만 남긴다 (신선 읽기에서 위반이 아니었던 id 를 지운다).
  void retainOnly(Set<String> keep) {
    final kept = state.where(keep.contains).toSet();
    if (kept.length != state.length) state = kept;
  }
}

final paymentRejectedMenuIdsProvider =
    NotifierProvider<PaymentRejectedMenuIdsNotifier, Set<String>>(
      PaymentRejectedMenuIdsNotifier.new,
    );

// ── 카트 화면의 선검증 결과 ──────────────────────────────────────────────────────

/// 카트 화면이 마지막으로 **직접 읽어서 확인한** 위반. 어느 매장에 대한 결과인지 함께 보관한다.
class CartValidationState {
  const CartValidationState({
    this.storeId,
    this.validation = CheckoutValidation.none,
  });

  final String? storeId;
  final CheckoutValidation validation;
}

/// 호출 시점: 카트 진입 1회 · 앱 포그라운드 복귀 · `결제하기` 탭 · `다시 확인`.
/// 카트 스트림 변화마다 호출하지 않는다 (읽기 폭증). 자동 호출(`reportFailure: false`)의 실패는 무음이다.
class CartValidationNotifier extends Notifier<CartValidationState> {
  @override
  CartValidationState build() => const CartValidationState();

  /// 다른 화면(체크아웃 차단 시트)이 이미 직접 읽어서 확인한 결과를 카트 화면에 반영한다.
  void applyKnown(String storeId, CheckoutValidation validation) {
    state = CartValidationState(storeId: storeId, validation: validation);
  }

  /// 신선 선검증. 반환값은 이번 호출의 결과다 (`결제하기` 탭 가로채기가 사용).
  /// [reportFailure] 가 true 일 때만 읽기 실패를 예외로 던진다 (design N3).
  Future<CheckoutValidation> refresh({bool reportFailure = false}) async {
    final cart = ref.read(cartProvider).value;
    if (cart == null || cart.items.isEmpty) {
      state = const CartValidationState();
      return CheckoutValidation.none;
    }
    final result = await ref
        .read(validateCheckoutUseCaseProvider)
        .call(
          storeId: cart.storeId,
          menuItemIds: cart.items.map((i) => i.menuItemId),
          reportFailure: reportFailure,
        );
    if (!ref.mounted) return result;
    state = CartValidationState(storeId: cart.storeId, validation: result);
    if (reportFailure && result.store == null) {
      // 이번 메뉴 읽기가 성공이다 → 위반이 아니었던 메뉴의 서버 지목 플래그를 지운다 (design D6).
      ref
          .read(paymentRejectedMenuIdsProvider.notifier)
          .retainOnly(result.violatedMenuItemIds);
    }
    return result;
  }
}

final cartValidationProvider =
    NotifierProvider.autoDispose<CartValidationNotifier, CartValidationState>(
      CartValidationNotifier.new,
    );

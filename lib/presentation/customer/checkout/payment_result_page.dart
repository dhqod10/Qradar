import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/cart_entity.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/payment_failure.dart';
import 'package:qradar/presentation/common/scaffold_with_nav.dart';
import 'package:qradar/presentation/common/widgets/pickup_number_display.dart';
import 'package:qradar/presentation/customer/cart/providers/cart_providers.dart';
import 'package:qradar/presentation/customer/cart/providers/checkout_validation_providers.dart';
import 'package:qradar/presentation/customer/checkout/payment_failure_copy.dart';
import 'package:qradar/presentation/customer/checkout/widgets/payment_menu_list_card.dart';
import 'package:qradar/presentation/customer/order/orders/order_detail_page.dart';
import 'package:qradar/presentation/customer/order/orders/providers/order_view_providers.dart';

enum PaymentResultVariant { success, fail, cancelled }

class PaymentResultPage extends ConsumerWidget {
  const PaymentResultPage({
    super.key,
    required this.variant,
    this.orderId,
    this.failure,
  });

  final PaymentResultVariant variant;
  final String? orderId;

  /// variant == fail 일 때의 **유일한 실패 입력** (design §3.0). 서버/Toss 원문 문자열은 받지 않는다.
  /// null 이면 갈래 C (알 수 없는 실패) 로 그린다.
  final PaymentFailure? failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: switch (variant) {
            PaymentResultVariant.success => _SuccessBody(
              orderId: orderId,
              onGoToLog: () {
                ref.read(selectedTabIndexProvider.notifier).set(3);
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
            PaymentResultVariant.fail => FailureBody(
              failure: failure ?? PaymentFailure.from(const Object()),
            ),
            PaymentResultVariant.cancelled => const _CancelledBody(),
          },
        ),
      ),
    );
  }
}

// ── Success ───────────────────────────────────────────────────────────────────

class _SuccessBody extends ConsumerWidget {
  const _SuccessBody({this.orderId, required this.onGoToLog});
  final String? orderId;
  final VoidCallback onGoToLog;

  String get _shortId {
    final id = orderId ?? '';
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}...';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 픽업 번호(order_pickup_number): 기존 주문 watch 스트림 재사용. 로딩 중엔 스켈레톤, 에러/미도달/null 은 조용히 생략.
    // 완료 문구·버튼은 어떤 경우에도 막지 않는다.
    final id = orderId;
    final orderAsync = (id == null || id.isEmpty)
        ? const AsyncValue<OrderEntity?>.data(null)
        : ref.watch(currentOrderProvider(id));
    final pickupNumber = orderAsync.asData?.value?.pickupNumber;
    final loading = orderAsync.isLoading;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          const Icon(
            Icons.check_circle_rounded,
            size: 64,
            color: AppColors.success,
          ),
          const SizedBox(height: 20),
          const Text(
            '결제가 완료되었어요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 20),
          if (loading) ...[
            Container(
              height: 108,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 16),
          ] else if (pickupNumber != null) ...[
            PickupNumberDisplay(
              number: pickupNumber,
              variant: PickupNumberVariant.hero,
              caption: '매장에서 이 번호를 보여주세요',
            ),
            const SizedBox(height: 16),
          ],
          const Text(
            '주문 ID',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            _shortId,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const Spacer(),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                final id = orderId;
                if (id == null || id.isEmpty) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => OrderDetailPage(orderId: id),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '주문 상세 보기',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 54,
            child: OutlinedButton(
              onPressed: onGoToLog,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textBody,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Log 로 이동',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Fail ─────────────────────────────────────────────────────────────────────

/// 메뉴 id → 고객 카트의 `menuItemName`. 카트에서 해석되지 않는 id 는 건너뛴다 (출력하지 않는다).
/// 같은 메뉴가 옵션이 달라 여러 줄이어도 이름은 한 번만 (design D5). 순서는 토큰 순서.
List<String> resolveFailureMenuNames(
  CartEntity? cart,
  Iterable<String> menuItemIds,
) {
  if (cart == null) return const [];
  final nameById = <String, String>{};
  for (final item in cart.items) {
    nameById.putIfAbsent(item.menuItemId, () => item.menuItemName);
  }
  final out = <String>[];
  final seen = <String>{};
  for (final id in menuItemIds) {
    if (!seen.add(id)) continue;
    final name = nameById[id];
    if (name != null && name.isNotEmpty) out.add(name);
  }
  return out;
}

/// 결제 실패 화면 본문 3갈래 (design §3). 화면에 그리는 문자열은 코드 상수 + 카트의 메뉴 이름뿐이다.
class FailureBody extends ConsumerWidget {
  const FailureBody({super.key, required this.failure});
  final PaymentFailure failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (failure.family) {
      PaymentFailureFamily.launch => _LaunchFailBody(failure: failure),
      PaymentFailureFamily.gate => _GateFailBody(failure: failure),
      PaymentFailureFamily.unknown => _UnknownFailBody(failure: failure),
    };
  }
}

Future<void> _runAction(
  BuildContext context,
  WidgetRef ref,
  PaymentFailureAction action,
  PaymentFailure failure,
) async {
  final navigator = Navigator.of(context);
  switch (action) {
    case PaymentFailureAction.popToCart:
      // MENU_* 사유는 pop 직전에 지목한 id 를 기록한다 (design D6) — 카트 행이 같은 말을 한다.
      if (failure.reason.isMenuReason) {
        ref
            .read(paymentRejectedMenuIdsProvider.notifier)
            .addAll(failure.menuItemIds);
      }
      // 옵션 사유는 따로 기록한다 — 카트 행의 폴백 캡션이 "옵션이 바뀐 메뉴" 라고 말한다 (payment_price_authority design §4.3).
      if (failure.reason == PaymentFailureReason.optionUnavailable) {
        ref
            .read(paymentOptionRejectedMenuIdsProvider.notifier)
            .addAll(failure.menuItemIds);
      }
      navigator.pop();
    case PaymentFailureAction.browseStores:
      ref.read(selectedTabIndexProvider.notifier).set(0);
      navigator.popUntil((route) => route.isFirst);
    case PaymentFailureAction.clearCartAndBrowse:
      await ref.read(clearCartUseCaseProvider).call();
      ref.read(selectedTabIndexProvider.notifier).set(0);
      navigator.popUntil((route) => route.isFirst);
    case PaymentFailureAction.goToLog:
      ref.read(selectedTabIndexProvider.notifier).set(3);
      navigator.popUntil((route) => route.isFirst);
    case PaymentFailureAction.repriceAndReturn:
      // 읽기·적용·실패 표시가 필요한 동작이라 [_PriceMismatchBody] 가 직접 처리한다 (상태를 가진 위젯).
      break;
  }
}

/// 스크롤 본문 + 하단 고정 버튼 영역 (design §3.5 — 기존 `Spacer()` 레이아웃을 쓰지 않는다).
class _FailScaffold extends StatelessWidget {
  const _FailScaffold({required this.content, required this.buttons});
  final List<Widget> content;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                ...content,
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: buttons,
          ),
        ),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textHeading,
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
  });
  final String label;
  final VoidCallback onPressed;

  /// 진행 중: 라벨 대신 스피너를 그리고 탭을 막는다 (재가격 중 — payment_price_authority design §4.2).
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: busy
            ? Semantics(
                label: kRepriceBusySemantics,
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onPrimary,
                  ),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

class _LineButton extends StatelessWidget {
  const _LineButton({required this.label, required this.onPressed});
  final String label;

  /// null 이면 비활성 (재가격 중).
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textBody,
          backgroundColor: AppColors.surfaceElevated,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _TextActionButton extends StatelessWidget {
  const _TextActionButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
      ),
    );
  }
}

/// 문의 코드 캡션 (design D4, Q2 ⓐ) — 형식 검증을 통과한 식별자만. 갈래 A 기본 문구 · 갈래 C 에서만 쓴다.
class _CodeCaption extends StatelessWidget {
  const _CodeCaption(this.code);
  final String code;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        '오류 코드: $code',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
    );
  }
}

// 갈래 A — 결제창 단계 실패
class _LaunchFailBody extends ConsumerWidget {
  const _LaunchFailBody({required this.failure});
  final PaymentFailure failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapped = launchMessageFor(failure.launchCode);
    final message = mapped ?? kLaunchDefaultMessage;
    final caption = mapped == null ? failure.rawCode : null;
    void pop() => Navigator.of(context).pop();
    return _FailScaffold(
      content: [
        const Icon(Icons.cancel_rounded, size: 80, color: AppColors.error),
        const SizedBox(height: 20),
        const _Headline(kLaunchHeadline),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
        ),
        if (caption != null) _CodeCaption(caption),
      ],
      buttons: [
        _PrimaryButton(label: '다시 시도', onPressed: pop),
        const SizedBox(height: 12),
        _LineButton(label: '결제 수단 변경', onPressed: pop),
        const SizedBox(height: 8),
        _TextActionButton(label: '닫기', onPressed: pop),
      ],
    );
  }
}

// 갈래 B — 서버 게이트 거절
class _GateFailBody extends ConsumerWidget {
  const _GateFailBody({required this.failure});
  final PaymentFailure failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 가격 거절은 상태(재가격 중/실패/반복)를 가진 별도 위젯이다.
    if (failure.reason == PaymentFailureReason.priceMismatch) {
      return _PriceMismatchBody(failure: failure);
    }
    final names = failure.reason.isMenuReason
        ? resolveFailureMenuNames(
            ref.watch(cartProvider).value,
            failure.menuItemIds,
          )
        : const <String>[];
    final copy = gateFailureCopy(failure.reason, hasNames: names.isNotEmpty);
    final showList = copy.listHeader != null && names.isNotEmpty;
    final secondaryLabel = copy.secondaryLabel;
    final secondaryAction = copy.secondaryAction;

    return _FailScaffold(
      content: [
        const Icon(
          Icons.error_outline_rounded,
          size: 64,
          color: AppColors.warning,
        ),
        const SizedBox(height: 20),
        _Headline(copy.headline),
        const SizedBox(height: 12),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: AppColors.info),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                kGateMoneyLine,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textBody,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          copy.body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: AppColors.textBody,
          ),
        ),
        if (showList)
          PaymentMenuListCard(
            header: copy.listHeader!,
            names: names,
            icon: failure.reason == PaymentFailureReason.optionUnavailable
                ? Icons.tune_rounded
                : Icons.remove_circle_outline_rounded,
          ),
        if (copy.subBody != null) ...[
          const SizedBox(height: 12),
          Text(
            copy.subBody!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ],
      buttons: [
        _PrimaryButton(
          label: copy.primaryLabel,
          onPressed: () =>
              _runAction(context, ref, copy.primaryAction, failure),
        ),
        if (secondaryLabel != null && secondaryAction != null) ...[
          const SizedBox(height: 8),
          // `닫기` 는 텍스트 버튼, `다른 매장 둘러보기` 는 라인 버튼 (design §3.1 — 시각적으로 주 버튼과 구별).
          copy.secondaryIsLine ||
                  secondaryAction == PaymentFailureAction.browseStores
              ? _LineButton(
                  label: secondaryLabel,
                  onPressed: () =>
                      _runAction(context, ref, secondaryAction, failure),
                )
              : _TextActionButton(
                  label: secondaryLabel,
                  onPressed: () =>
                      _runAction(context, ref, secondaryAction, failure),
                ),
        ],
      ],
    );
  }
}

// 갈래 B — PRICE_MISMATCH (payment_price_authority design §4.2)
//
// 금액이 안 맞아 서버가 거절해도 카트는 스스로 가격을 갱신하지 않으므로 다시 눌러 봐야 같은 거절이다 (spec §7-2 무한 거절 루프).
// 그래서 주 버튼은 pop 이 아니라 **카트를 최신 가격으로 다시 읽어 적용하는 동작**이다. 이 화면은 금액 숫자를 그리지 않는다 —
// 숫자는 카트로 돌아간 뒤 재가격 결과(UseCase 가 계산한 int)로 보인다 (Q6=ⓒ, D4).
class _PriceMismatchBody extends ConsumerStatefulWidget {
  const _PriceMismatchBody({required this.failure});
  final PaymentFailure failure;

  @override
  ConsumerState<_PriceMismatchBody> createState() => _PriceMismatchBodyState();
}

class _PriceMismatchBodyState extends ConsumerState<_PriceMismatchBody> {
  bool _busy = false;
  int _failures = 0;

  /// 방금 재가격했는데 달라진 게 없었다 → 변형 N 으로 전환 (design P2).
  bool _noChange = false;

  Future<void> _reprice() async {
    if (_busy) return;
    final cart = ref.read(cartProvider).value;
    if (cart == null || cart.items.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _busy = true);
    try {
      // 사용자가 직접 누른 동작이다 — 실패는 무음이 아니라 이 화면에 인라인으로 알린다 (design N3). 타임아웃은 UseCase 안의 5초.
      final validation = await ref
          .read(validateCheckoutUseCaseProvider)
          .call(
            storeId: cart.storeId,
            menuItemIds: cart.items.map((i) => i.menuItemId),
            cartItems: cart.items,
            reportFailure: true,
          );
      if (!mounted) return;
      if (!validation.hasPriceChanges && !validation.hasViolations) {
        // 재가격해도 같다: 같은 버튼을 다시 주면 두 번째 루프다. 변형 N 으로 바꾸고 서명을 남긴다.
        ref
            .read(priceRepricedCartSignatureProvider.notifier)
            .mark(cartSignature(cart));
        setState(() {
          _busy = false;
          _noChange = true;
        });
        return;
      }
      final applied = await ref
          .read(applyRepricedCartUseCaseProvider)
          .call(validation.repricing);
      if (!mounted) return;
      ref.read(cartPriceChangesProvider.notifier).record(applied);
      ref
          .read(cartValidationProvider.notifier)
          .applyKnown(cart.storeId, validation);
      ref
          .read(priceRepricedCartSignatureProvider.notifier)
          .mark(cartSignature(cart));
      // 체크아웃을 대체한 결제 화면이므로 pop 하면 카트다. 카트가 배너와 라인 표시로 바뀐 금액을 보여 준다.
      // 자동으로 결제하지 않는다 — 새 금액을 확인하고 고객이 직접 다시 누른다.
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failures++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider).value;
    final signature = ref.watch(priceRepricedCartSignatureProvider);
    final repeated =
        _noChange ||
        (cart != null && signature != null && signature == cartSignature(cart));
    final names = repeated
        ? const <String>[]
        : resolveFailureMenuNames(cart, widget.failure.menuItemIds);
    final copy = gateFailureCopy(
      PaymentFailureReason.priceMismatch,
      hasNames: names.isNotEmpty,
      repeated: repeated,
    );
    final showList = !repeated && copy.listHeader != null && names.isNotEmpty;
    final secondaryLabel = copy.secondaryLabel;
    final secondaryAction = copy.secondaryAction;

    return _FailScaffold(
      content: [
        Icon(
          repeated ? Icons.help_outline_rounded : Icons.price_change_outlined,
          size: 64,
          color: AppColors.warning,
        ),
        const SizedBox(height: 20),
        _Headline(copy.headline),
        const SizedBox(height: 12),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: AppColors.info),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                kGateMoneyLine,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textBody,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          copy.body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: AppColors.textBody,
          ),
        ),
        if (showList)
          PaymentMenuListCard(
            header: copy.listHeader!,
            names: names,
            icon: Icons.price_change_outlined,
          ),
        if (copy.subBody != null) ...[
          const SizedBox(height: 12),
          Text(
            copy.subBody!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
        // 변형 N 은 문의 때 식별 수단이 필요하다 (design Q-D2). 형식 검증을 통과한 토큰 식별자만 — 원문이 아니다.
        if (repeated) _CodeCaption(widget.failure.rawCode ?? 'PRICE_MISMATCH'),
      ],
      buttons: [
        if (!repeated && _failures > 0) ...[
          // 재가격 읽기 실패 — 이 화면에 머문다 (원시 예외 문자열은 노출하지 않는다).
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: AppColors.error,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        kRepriceErrorText,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textBody,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_failures >= 2)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      kRepriceErrorHint,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        _PrimaryButton(
          label: !repeated && _failures > 0
              ? kRepriceRetryLabel
              : copy.primaryLabel,
          busy: _busy,
          onPressed: () {
            if (copy.primaryAction == PaymentFailureAction.repriceAndReturn) {
              _reprice();
            } else {
              _runAction(context, ref, copy.primaryAction, widget.failure);
            }
          },
        ),
        if (secondaryLabel != null && secondaryAction != null) ...[
          const SizedBox(height: 8),
          _LineButton(
            label: secondaryLabel,
            // 재가격 중에는 비활성. 읽기에 실패해도 '카트로 돌아가기' 는 계속 활성이다 — 카트의 결제하기 탭도 재가격을
            // 시도하므로 막다른 길이 아니다.
            onPressed: _busy
                ? null
                : () =>
                      _runAction(context, ref, secondaryAction, widget.failure),
          ),
        ],
      ],
    );
  }
}

// 갈래 C — 알 수 없는 실패 (돈의 상태를 모른다)
class _UnknownFailBody extends ConsumerWidget {
  const _UnknownFailBody({required this.failure});
  final PaymentFailure failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caption = failure.rawCode;
    return _FailScaffold(
      content: [
        const Icon(
          Icons.help_outline_rounded,
          size: 64,
          color: AppColors.warning,
        ),
        const SizedBox(height: 20),
        const _Headline(kUnknownHeadline),
        const SizedBox(height: 16),
        const Text(
          kUnknownBody,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: AppColors.textBody,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          kUnknownSubBody,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        if (caption != null) _CodeCaption(caption),
      ],
      buttons: [
        _PrimaryButton(
          label: kUnknownPrimaryLabel,
          onPressed: () =>
              _runAction(context, ref, PaymentFailureAction.goToLog, failure),
        ),
        const SizedBox(height: 12),
        _LineButton(
          label: kUnknownSecondaryLabel,
          onPressed: () =>
              _runAction(context, ref, PaymentFailureAction.popToCart, failure),
        ),
      ],
    );
  }
}

// ── Cancelled ─────────────────────────────────────────────────────────────────

class _CancelledBody extends StatelessWidget {
  const _CancelledBody();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 60),
          const Icon(Icons.info_rounded, size: 80, color: AppColors.textMuted),
          const SizedBox(height: 20),
          const Text(
            '결제가 취소되었어요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '결제를 다시 시도하시려면 카트로 돌아가주세요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          const Spacer(),
          SizedBox(
            height: 54,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textBody,
                backgroundColor: AppColors.surfaceElevated,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '닫기 (카트로 돌아가기)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/cart_entity.dart';
import 'package:qradar/domain/entities/payment_failure.dart';
import 'package:qradar/presentation/common/scaffold_with_nav.dart';
import 'package:qradar/presentation/customer/cart/providers/cart_providers.dart';
import 'package:qradar/presentation/customer/cart/providers/checkout_validation_providers.dart';
import 'package:qradar/presentation/customer/checkout/payment_failure_copy.dart';
import 'package:qradar/presentation/customer/checkout/widgets/payment_menu_list_card.dart';
import 'package:qradar/presentation/customer/order/orders/order_detail_page.dart';

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

class _SuccessBody extends StatelessWidget {
  const _SuccessBody({this.orderId, required this.onGoToLog});
  final String? orderId;
  final VoidCallback onGoToLog;

  String get _shortId {
    final id = orderId ?? '';
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 60),
          const Icon(
            Icons.check_circle_rounded,
            size: 80,
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
          const SizedBox(height: 12),
          const Text(
            '주문번호',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            _shortId,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textBody,
            ),
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
  const _PrimaryButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _LineButton extends StatelessWidget {
  const _LineButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

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
          PaymentMenuListCard(header: copy.listHeader!, names: names),
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

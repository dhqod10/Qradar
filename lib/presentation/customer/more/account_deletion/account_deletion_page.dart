import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/qoin_formatters.dart';
import 'package:qradar/domain/entities/account_deletion_preview.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/more/account_deletion/account_deletion_providers.dart';

/// 확인 문구. 비교는 `trim()` 후 완전 일치.
const String accountDeletionConfirmPhrase = '탈퇴합니다';

/// 탈퇴 버튼 활성 조건 (fail-closed) — 미리보기 **로드 성공** · 진행 중 주문 0건 · 입력 일치 · 처리 중 아님.
bool canSubmitAccountDeletion({
  required AccountDeletionPreview? preview,
  required String input,
  required bool processing,
  bool blocked = false,
}) {
  if (processing || blocked || preview == null || !preview.canDelete) {
    return false;
  }
  return input.trim() == accountDeletionConfirmPhrase;
}

/// 회원 탈퇴 — 되돌릴 수 없는 작업이라 다이얼로그가 아니라 전체 화면이다 (design §2).
///
/// 성공 시 [authProvider] signOut 으로 세션을 null 로 만든다 → 기존 RoleRouter 가 LoginPage 로 보낸다
/// (수동 pop/push 금지). 서버 raw message 는 어디에도 그리지 않는다.
class AccountDeletionPage extends ConsumerStatefulWidget {
  const AccountDeletionPage({super.key});

  @override
  ConsumerState<AccountDeletionPage> createState() =>
      _AccountDeletionPageState();
}

class _AccountDeletionPageState extends ConsumerState<AccountDeletionPage> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 한글 IME 조합 중에도 매 변경마다 재평가한다.
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref
        .read(accountDeletionControllerProvider.notifier)
        .submit();
    if (!mounted) {
      if (ok) await ref.read(authProvider.notifier).signOut();
      return;
    }
    if (ok) {
      // 소셜 unlink 는 후속(best-effort) — 탈퇴는 이미 성립. 세션 정리만 한다.
      await ref.read(authProvider.notifier).signOut();
      return;
    }
    final s = ref.read(accountDeletionControllerProvider);
    if (s.status == AccountDeletionStatus.blockedInFlight) {
      ref.invalidate(accountDeletionPreviewProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctl = ref.watch(accountDeletionControllerProvider);
    final previewAsync = ref.watch(accountDeletionPreviewProvider);
    final processing = ctl.isProcessing;

    return PopScope(
      canPop: !processing,
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('회원 탈퇴'),
          automaticallyImplyLeading: !processing,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: _body(ctl, previewAsync),
          ),
        ),
      ),
    );
  }

  Widget _body(
    AccountDeletionState ctl,
    AsyncValue<AccountDeletionPreview> previewAsync,
  ) {
    final preview = previewAsync.asData?.value;
    final blockedByCtl = ctl.status == AccountDeletionStatus.blockedInFlight;
    final blockedCount = [
      preview?.inFlightOrderCount ?? 0,
      ctl.blockedCount ?? 0,
    ].reduce((a, b) => a > b ? a : b);
    final blocked = blockedByCtl || (preview != null && !preview.canDelete);

    if (blocked) {
      return _BlockedView(
        count: blockedCount,
        onConfirm: () => Navigator.of(context).pop(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Header(),
        const SizedBox(height: 24),
        if (previewAsync.isLoading && preview == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primaryBright),
            ),
          )
        else if (preview == null)
          _PreviewError(
            onRetry: () => ref.invalidate(accountDeletionPreviewProvider),
          )
        else
          _Form(
            preview: preview,
            ctrl: _ctrl,
            ctl: ctl,
            canSubmit: canSubmitAccountDeletion(
              preview: preview,
              input: _ctrl.text,
              processing: ctl.isProcessing,
              blocked: blockedByCtl,
            ),
            onSubmit: _submit,
            onLogout: () => ref.read(authProvider.notifier).signOut(),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_rounded, size: 32, color: AppColors.error),
        SizedBox(height: 12),
        Text(
          '정말 탈퇴하시겠어요?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        SizedBox(height: 6),
        Text(
          '탈퇴하면 되돌릴 수 없어요. 아래 내용을 꼭 확인해 주세요.',
          style: TextStyle(fontSize: 14, color: AppColors.textBody),
        ),
      ],
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.preview,
    required this.ctrl,
    required this.ctl,
    required this.canSubmit,
    required this.onSubmit,
    required this.onLogout,
  });

  final AccountDeletionPreview preview;
  final TextEditingController ctrl;
  final AccountDeletionState ctl;
  final bool canSubmit;
  final VoidCallback onSubmit;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final processing = ctl.isProcessing;
    final matched = ctrl.text.trim() == accountDeletionConfirmPhrase;
    final hasQoin = preview.qoinToForfeit > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DeletedItemsCard(showQoin: hasQoin),
        if (hasQoin) ...[
          const SizedBox(height: 12),
          _QoinForfeitCard(qoin: preview.qoinToForfeit),
        ],
        const SizedBox(height: 12),
        const _RetainedCard(),
        const SizedBox(height: 24),
        const _ConfirmPrompt(),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          enabled: !processing,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          style: const TextStyle(fontSize: 15, color: AppColors.textHeading),
          decoration: InputDecoration(
            hintText: accountDeletionConfirmPhrase,
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surface,
            suffixIcon: matched
                ? const Icon(
                    Icons.check_circle,
                    size: 20,
                    color: AppColors.success,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (ctl.status == AccountDeletionStatus.failed)
          const _InlineError(message: '탈퇴 처리에 실패했어요. 잠시 후 다시 시도해 주세요.'),
        if (ctl.status == AccountDeletionStatus.failedUnauthenticated) ...[
          const _InlineError(message: '로그인 정보가 만료됐어요. 다시 로그인해 주세요.'),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onLogout,
              child: const Text(
                '로그인 화면으로',
                style: TextStyle(color: AppColors.primaryBright),
              ),
            ),
          ),
        ],
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: canSubmit ? onSubmit : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              disabledBackgroundColor: processing
                  ? AppColors.error
                  : AppColors.error.withValues(alpha: 0.25),
              foregroundColor: AppColors.onPrimary,
              disabledForegroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: processing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onPrimary,
                    ),
                  )
                : const Text(
                    '회원 탈퇴',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: processing ? null : () => Navigator.of(context).pop(),
            child: const Text(
              '취소',
              style: TextStyle(color: AppColors.textBody),
            ),
          ),
        ),
        if (processing)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Center(
              child: Text(
                '처리 중이에요. 잠시만 기다려 주세요.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          ),
      ],
    );
  }
}

class _DeletedItemsCard extends StatelessWidget {
  const _DeletedItemsCard({required this.showQoin});
  final bool showQoin;

  @override
  Widget build(BuildContext context) {
    Widget row(String text, {bool bold = false}) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.remove_circle_outline,
              size: 16,
              color: AppColors.error,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: bold ? AppColors.textHeading : AppColors.textBody,
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '삭제되는 정보',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.error,
            ),
          ),
          row('계정 및 로그인 정보 (이메일·소셜 연결)'),
          row('이름 · 전화번호 등 개인정보'),
          row('즐겨찾기한 매장 · 메뉴'),
          if (showQoin) row('보유 Qoin', bold: true),
        ],
      ),
    );
  }
}

class _QoinForfeitCard extends StatelessWidget {
  const _QoinForfeitCard({required this.qoin});
  final int qoin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.toll_outlined, size: 24, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '소멸되는 Qoin',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                Text(
                  '${QoinFormatters.number(qoin)} Qoin',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '탈퇴하면 남은 Qoin 은 모두 소멸되며 환급·복구되지 않아요.',
                  style: TextStyle(fontSize: 13, color: AppColors.textBody),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RetainedCard extends StatelessWidget {
  const _RetainedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '보관되는 정보',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.info,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '주문 내역은 관련 법령(전자상거래법)에 따라 개인정보 없이 보관돼요.',
                  style: TextStyle(fontSize: 13, color: AppColors.textBody),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfirmPrompt extends StatelessWidget {
  const _ConfirmPrompt();

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        style: TextStyle(fontSize: 14, color: AppColors.textBody),
        children: [
          TextSpan(text: '계속하려면 아래에 "'),
          TextSpan(
            text: accountDeletionConfirmPhrase,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.error,
            ),
          ),
          TextSpan(text: '" 를 입력해 주세요.'),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.error_outline, size: 16, color: AppColors.error),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewError extends StatelessWidget {
  const _PreviewError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.error),
            const SizedBox(height: 12),
            const Text(
              '정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textBody),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(160, 44),
                side: const BorderSide(color: AppColors.primaryBright),
              ),
              child: const Text(
                '다시 시도',
                style: TextStyle(color: AppColors.primaryBright),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockedView extends StatelessWidget {
  const _BlockedView({required this.count, required this.onConfirm});
  final int count;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.hourglass_top_rounded,
          size: 32,
          color: AppColors.warning,
        ),
        const SizedBox(height: 12),
        const Text(
          '지금은 탈퇴할 수 없어요',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count > 0 ? '진행 중인 주문 $count건이 있어요' : '진행 중인 주문이 있어요',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHeading,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '주문이 완료된 후에 탈퇴할 수 있어요. 주문 상태는 Log 에서 확인해 주세요.',
                style: TextStyle(fontSize: 14, color: AppColors.textBody),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: onConfirm,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '확인',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

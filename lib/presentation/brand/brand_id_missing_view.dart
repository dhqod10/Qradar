import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/errors/brand_claim_exception.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/brand/brand_info/brand_info_form_page.dart';
import 'package:qradar/presentation/brand/providers/brand_link_gate_provider.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';

/// `users.brandId` 가 없는 brand 계정의 진입 게이트 (brand_authorization_hardening design §3).
///
/// - 먼저 `brands where submittedBy == uid` 를 조회한다. 0건일 때만 등록 폼을 그린다.
/// - 1건이면 자동으로 `claimSubmittedBrand` 를 호출해 연결한다 (사용자 조작 0).
/// - 2건 이상이면 가장 이른 제출 1건으로 연결하고 정상 진입 직후 SnackBar 로 알린다.
/// - **조회 중·조회 실패·연결 실패에서는 등록 폼을 절대 그리지 않는다.** 실패 화면에 `새로 등록하기` 버튼도 없다.
///
/// sub-phase 6(V8) 에서 폐기됐던 `_BrandIdMissingView` 를 되살린 것이다 (그 사이 `brandId` 없음은 곧바로 폼으로 갔다).
class BrandIdMissingView extends ConsumerWidget {
  const BrandIdMissingView({super.key});

  static const String checkingTitle = '브랜드 정보를 확인하고 있어요';
  static const String linkingTitle = '브랜드를 연결하고 있어요';
  static const String linkingBody = '잠시만 기다려 주세요';
  static const String lookupFailedTitle = '브랜드 정보를 확인하지 못했어요';
  static const String lookupFailedBody =
      '이미 등록한 브랜드가 있을 수 있어서, 확인되기 전에는 새로 등록할 수 없어요';
  static const String claimFailedTitle = '브랜드 연결을 마치지 못했어요';
  static const String alreadyLinkedTitle = '이 계정은 이미 다른 브랜드에 연결돼 있어요';
  static const String alreadyLinkedBody = '관리자에게 문의해 주세요. 직접 바꿀 수는 없어요';
  static const String notSubmitterTitle = '이 브랜드는 내 계정으로 등록한 브랜드가 아니에요';
  static const String notSubmitterBody = '관리자에게 문의해 주세요';
  static const String contactFooter = '계속 안 되면 관리자에게 문의해 주세요';
  static const String retryLookupLabel = '다시 시도';
  static const String retryClaimLabel = '다시 연결';
  static const String logoutLabel = '로그아웃';

  /// 2건 이상이 자동 연결된 직후의 SnackBar (design §3-d).
  static String multiLinkedSnack(String name) =>
      '브랜드 "$name" 에 연결했어요. 같은 계정으로 등록된 브랜드가 더 있어서 관리자가 확인할 거예요';

  /// 연결 실패 본문. 2건 이상이면 어느 브랜드로 시도했는지 말한다.
  static String claimFailedBody(String name, int count) => count >= 2
      ? '등록한 브랜드가 $count개 있어요. 가장 먼저 등록한 "$name" 으로 연결을 시도했어요'
      : (name.isEmpty
            ? '등록한 브랜드는 그대로 있어요. 다시 등록하지 않아도 돼요'
            : '등록한 브랜드 "$name" 은 그대로 있어요. 다시 등록하지 않아도 돼요');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(brandLinkGateProvider);

    // 2건 이상 -> 연결 성공 순간 한 번만 알린다. 정상 화면으로 넘어가도 SnackBar 는 ScaffoldMessenger 에 남는다.
    ref.listen<BrandGateState>(brandLinkGateProvider, (prev, next) {
      if (next is BrandGateLinked &&
          next.totalCount >= 2 &&
          prev is! BrandGateLinked) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(multiLinkedSnack(next.brand.name)),
            duration: const Duration(seconds: 6),
            showCloseIcon: true,
          ),
        );
      }
    });

    // 0건일 때만 등록 폼. 그 폼이 브랜드를 만들면 provider 를 invalidate 해 게이트가 다시 평가한다.
    if (state is BrandGateNeedsRegistration) {
      return const BrandInfoFormPage(brand: null);
    }

    final notifier = ref.read(brandLinkGateProvider.notifier);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        actions: [
          // 이 게이트에는 BottomNav 가 없다 — 막다른 길을 막기 위한 로그아웃.
          TextButton(
            onPressed: () => ref.read(authProvider.notifier).signOut(),
            child: const Text(
              logoutLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: _content(state, notifier),
          ),
        ),
      ),
    );
  }

  Widget _content(BrandGateState state, BrandLinkGateNotifier notifier) {
    switch (state) {
      case BrandGateChecking():
        return const _Busy(title: checkingTitle);
      case BrandGateLinking():
      case BrandGateLinked():
        return const _Busy(title: linkingTitle, body: linkingBody);
      case BrandGateLookupFailed():
        return _Notice(
          icon: Icons.cloud_off_rounded,
          title: lookupFailedTitle,
          body: lookupFailedBody,
          buttonLabel: retryLookupLabel,
          onButton: notifier.retryLookup,
        );
      case BrandGateClaimFailed(
        :final brand,
        :final totalCount,
        :final failure,
      ):
        switch (failure) {
          case BrandClaimFailure.alreadyLinked:
            return const _Notice(
              icon: Icons.info_outline_rounded,
              title: alreadyLinkedTitle,
              body: alreadyLinkedBody,
            );
          case BrandClaimFailure.notSubmitter:
            return const _Notice(
              icon: Icons.info_outline_rounded,
              title: notSubmitterTitle,
              body: notSubmitterBody,
            );
          case BrandClaimFailure.retryable:
            return _Notice(
              icon: Icons.link_off_rounded,
              title: claimFailedTitle,
              body: claimFailedBody(brand.name, totalCount),
              buttonLabel: retryClaimLabel,
              onButton: notifier.retryClaim,
            );
        }
      case BrandGateNeedsRegistration():
        // build() 에서 폼으로 분기하므로 여기에 오지 않는다. 방어적으로 확인 중 화면.
        return const _Busy(title: checkingTitle);
    }
  }
}

class _Busy extends StatelessWidget {
  const _Busy({required this.title, this.body});
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: body == null ? title : '$title. $body',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.body,
    this.buttonLabel,
    this.onButton,
  });
  final IconData icon;
  final String title;
  final String body;
  final String? buttonLabel;
  final VoidCallback? onButton;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: AppColors.textMuted),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        if (buttonLabel != null && onButton != null) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onButton,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                buttonLabel!,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onPrimary,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        const Text(
          BrandIdMissingView.contactFooter,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/dialog/dialog_queue_service.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';
import 'package:qradar/presentation/customer/more/profile/profile_edit_page.dart';

/// 성별·출생연도를 아직 **묻지 않은** 사용자에게 1회 안내한다.
///
/// 이메일 가입자는 가입 화면에서 이미 물었으므로(안 골라도 `demographicsAskedAt` 이 찍힌다) 여기에
/// 걸리지 않는다. 걸리는 쪽은 가입 화면을 거치지 않는 **소셜 가입자**와, 이 기능 이전에 가입한 **기존 회원**이다.
///
/// 한 번 뜨면 어느 쪽을 고르든 `demographicsAskedAt` 이 찍혀 다시 뜨지 않는다 — `나중에` 도
/// 사용자의 선택이고, 더보기 → 내 정보에서 언제든 입력할 수 있다.
Future<void> maybePromptDemographics(
  BuildContext context,
  WidgetRef ref,
) async {
  final profile = ref.read(currentUserProfileProvider).asData?.value;
  if (profile == null) return;
  // 값이 아니라 "물어봤는가" 로 판정한다 — 물어봤는데 안 밝힌 경우도 값은 null 이다.
  if (profile.demographicsAskedAt != null) return;

  final queue = ref.read(dialogQueueServiceProvider);
  final goSetup = await queue.enqueueDialog<bool>(
    context: context,
    key: 'demographics_prompt',
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        '성별·출생연도를 알려주시겠어요?',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textHeading,
        ),
      ),
      content: const Text(
        '어떤 메뉴가 사랑받는지 파악하는 통계 목적으로만 쓰고, 다른 곳에는 쓰지 않아요.\n'
        '선택 항목이라 알려주지 않으셔도 모든 기능을 그대로 이용할 수 있어요.',
        style: TextStyle(fontSize: 14, color: AppColors.textMuted, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text(
            '나중에',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('설정하기'),
        ),
      ],
    ),
  );

  if (goSetup == true) {
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProfileEditPage()),
    );
    return;
  }

  // `나중에`(false) 와 바깥 탭으로 닫음(null) 을 같게 다룬다 — 둘 다 "지금은 밝히지 않겠다" 이고,
  // 기록해 두지 않으면 앱을 열 때마다 다시 묻게 된다. 값은 비우고 "물어봤다" 만 남긴다.
  try {
    await ref.read(updateMyDemographicsUseCaseProvider).call(uid: profile.uid);
  } catch (_) {
    // 저장 실패는 조용히 넘긴다 — 다음 실행에 다시 물으면 될 뿐, 사용자를 막을 일이 아니다.
  }
}

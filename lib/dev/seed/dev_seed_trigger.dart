// DEV_ONLY_SEED — order_flow_phase1, phase2 추가. 사용자 요청 시 lib/dev/seed/ 폴더 통째로 삭제.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/dev/seed/phase1_seed.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';

/// 디버그 빌드에서만 long-press 로 Phase 1+2 시드 다이얼로그를 띄우는 래퍼.
///
/// release 빌드에서는 자식 위젯을 그대로 반환한다.
class DevSeedTrigger extends ConsumerWidget {
  final Widget child;
  const DevSeedTrigger({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _showSeedDialog(context, ref),
      child: child,
    );
  }

  Future<void> _showSeedDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text(
          'Phase 1+2 시드 데이터',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        content: const Text(
          'subCategories / optionGroups / 개인 매장 1개 + 메뉴 7개 + '
          '주문 로그 7건 + 브랜드 1개 + 마스터 메뉴 2개 + 브랜드 매장 1개를 '
          'Firestore 에 기록합니다. 이미 존재 시 덮어씁니다.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textBody,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              '취소',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              '실행',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final uid = ref.read(authProvider).asData?.value?.uid;
    await _runSeed(context, uid: uid);
  }

  Future<void> _runSeed(BuildContext context, {required String? uid}) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('시드 데이터 기록 중...')),
    );
    try {
      final result = await runPhase1Seed(uid: uid);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('시드 완료\n${result.summary()}'),
            duration: const Duration(seconds: 4),
          ),
        );
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('시드 실패: $e'),
            backgroundColor: AppColors.error,
          ),
        );
    }
  }
}

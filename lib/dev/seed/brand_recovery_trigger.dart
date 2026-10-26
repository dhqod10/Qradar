// RECOVERY(2026-10-26): 브랜드 복구 실행 트리거. 확인 후 이 파일과 호출부를 삭제한다.
//
// admin 더보기의 '앱 정보' 를 길게 눌러 실행한다. `brands` create 는 admin 만
// 가능하므로(firestore.rules) 고객 더보기의 기존 시드 트리거로는 돌릴 수 없다.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/dev/seed/brand_recovery.dart';

class BrandRecoveryTrigger extends StatelessWidget {
  final Widget child;
  const BrandRecoveryTrigger({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _confirm(context),
      child: child,
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('브랜드 복구'),
        content: const Text(
          '삭제된 brands 문서 3건(ChaCha / 낫심플 / Q브루어리)을 원본과 같은 ID 로 '
          '다시 만듭니다. 매장·주문·카테고리는 건드리지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('실행'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('복구 중...')));
    try {
      final result = await runBrandRecovery();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('복구 완료\n${result.summary()}'),
          duration: const Duration(seconds: 6),
        ));
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('복구 실패: $e'),
          duration: const Duration(seconds: 10),
          backgroundColor: AppColors.error,
        ));
    }
  }
}

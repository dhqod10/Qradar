import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/store_brand_link.dart';

/// 브랜드 매장 승인 확인 (brand_authorization_hardening design §2-g). 개인 매장은 즉시 처리라 이 다이얼로그를 거치지 않는다.
///
/// 확인 문장은 admin 이 **무엇을 승인하는지** 한 번 더 말한다. 상속 적립률 문장은 승인 상세 블록과 같은 함수의 결과다
/// ([InheritedRate.sentence]) — 각자 조립하지 않는다. 브랜드 분류가 `approved` 일 때만 열린다.
class StoreApproveConfirmDialog extends StatelessWidget {
  const StoreApproveConfirmDialog({
    super.key,
    required this.brandName,
    required this.inherited,
  });

  final String brandName;

  /// 적립률 읽기가 로딩·실패면 null — 그 줄만 생략한다 (승인은 막지 않는다).
  final InheritedRate? inherited;

  static String title(String brandName) =>
      '이 매장을 브랜드 "$brandName" 의 가맹점으로 승인합니다';
  static const String note = '승인하면 이 매장은 브랜드 메뉴와 적립률을 적용받아요';

  static Future<bool> show(
    BuildContext context, {
    required String brandName,
    required InheritedRate? inherited,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) =>
          StoreApproveConfirmDialog(brandName: brandName, inherited: inherited),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title(brandName),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textHeading,
              ),
            ),
            if (inherited != null) ...[
              const SizedBox(height: 12),
              Text(
                inherited!.sentence,
                style: const TextStyle(fontSize: 13, color: AppColors.textBody),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              note,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '취소',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textBody,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '승인',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

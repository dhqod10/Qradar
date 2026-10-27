import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// 최소 클라이언트 수준 미만으로 **확인된** 구버전의 결제 경로를 막는 화면 (payment_price_authority H-01).
/// 결제는 시작되지 않았다. 서버 문자열은 보간하지 않는다.
const String kUpdateRequiredHeadline = '앱을 업데이트해 주세요';
const String kUpdateRequiredBody =
    '이 버전에서는 결제를 할 수 없어요. 스토어에서 Qradar 를 최신 버전으로 업데이트한 뒤 다시 시도해 주세요.';
const String kUpdateRequiredMoney = '아직 결제되지 않았고, 요금도 청구되지 않았어요';
const String kUpdateRequiredClose = '확인';

class UpdateRequiredPage extends StatelessWidget {
  const UpdateRequiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(
                Icons.system_update_alt_rounded,
                size: 64,
                color: AppColors.warning,
              ),
              const SizedBox(height: 20),
              const Text(
                kUpdateRequiredHeadline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHeading,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                kUpdateRequiredMoney,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textBody,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                kUpdateRequiredBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppColors.textBody,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    kUpdateRequiredClose,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

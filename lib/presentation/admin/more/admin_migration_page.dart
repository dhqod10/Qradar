// TEMP_MIGRATION_CARD — payment_server_authority 배포 ③⑤⑨ 용 임시 화면. 배포 ⑪ 정리 커밋에서 삭제한다.
// (payment_price_authority 의 TEMP_PRICE_AUDIT_CARD 도 같은 화면에 들어간다 — 그쪽은 배포 ⑩ 에서 카드만 뺀다.)
import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/admin/widgets/admin_migration_cards.dart';
import 'package:qradar/presentation/admin/widgets/admin_price_audit_card.dart';

class AdminMigrationPage extends StatelessWidget {
  const AdminMigrationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('배포 마이그레이션 (임시)'),
        backgroundColor: AppColors.background,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminStoreApprovalMigrationCard(),
            AdminBrandProfileMigrationCard(),
            // payment_price_authority 배포 ②⑨ (읽기 전용 임시 감사, 배포 ⑩ 에서 삭제)
            AdminPriceAuditCard(),
          ],
        ),
      ),
    );
  }
}

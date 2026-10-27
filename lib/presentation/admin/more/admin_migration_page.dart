// TEMP_MIGRATION_CARD — payment_server_authority 배포 ③⑤⑨ 용 임시 화면. 배포 ⑪ 정리 커밋에서 삭제한다.
import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/admin/widgets/admin_migration_cards.dart';

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
          ],
        ),
      ),
    );
  }
}

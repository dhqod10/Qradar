import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/constants/support_contact.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/customer/support/providers/support_inquiry_providers.dart';
import 'package:qradar/presentation/customer/support/support_inquiry_detail_page.dart';
import 'package:qradar/presentation/customer/support/support_inquiry_form_page.dart';
import 'package:qradar/presentation/customer/support/widgets/support_inquiry_tile.dart';
import 'package:shimmer/shimmer.dart';

/// 고객센터 — 내 문의 목록 (더보기 → 고객센터).
class SupportInquiryListPage extends ConsumerWidget {
  const SupportInquiryListPage({super.key});

  void _openForm(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SupportInquiryFormPage()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myInquiriesProvider);
    final isEmpty = async.asData?.value.isEmpty ?? false;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('고객센터')),
      floatingActionButton: (async.hasValue && !isEmpty)
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(context),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('문의하기'),
            )
          : null,
      body: async.when(
        loading: () => const _Skeleton(),
        error: (_, _) =>
            _ErrorView(onRetry: () => ref.invalidate(myInquiriesProvider)),
        data: (list) {
          if (list.isEmpty) {
            return _EmptyView(onWrite: () => _openForm(context));
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(myInquiriesProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    '답변은 이 화면에서 확인할 수 있어요',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
                for (final q in list) ...[
                  SupportInquiryTile(
                    inquiry: q,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            SupportInquiryDetailPage(inquiryId: q.id),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
                if (list.length >= 50)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      '최근 50건까지 표시돼요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                const Text(
                  '급한 문의는 $kSupportContact 로 연락해 주세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onWrite});
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.forum_outlined,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            const Text(
              '아직 문의가 없어요',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textBody,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '궁금한 점이나 불편한 점을 남겨 주세요',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 160,
              height: 48,
              child: ElevatedButton(
                onPressed: onWrite,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('문의하기'),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '급한 문의는 $kSupportContact 로 연락해 주세요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: 12),
          const Text(
            '문의 내역을 불러오지 못했어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '잠시 후 다시 시도해 주세요',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double h, double widthFactor) => FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: h,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => Shimmer.fromColors(
        baseColor: AppColors.surface,
        highlightColor: AppColors.surfaceElevated,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              bar(12, 0.4),
              const SizedBox(height: 10),
              bar(16, 0.7),
              const SizedBox(height: 10),
              bar(12, 0.9),
            ],
          ),
        ),
      ),
    );
  }
}

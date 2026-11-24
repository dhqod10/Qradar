import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qradar/core/errors/support_inquiry_exception.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/support_inquiry_entity.dart';
import 'package:qradar/domain/entities/support_inquiry_status.dart';
import 'package:qradar/presentation/customer/support/providers/support_inquiry_di_providers.dart';
import 'package:qradar/presentation/customer/support/providers/support_inquiry_providers.dart';
import 'package:qradar/presentation/customer/support/support_inquiry_form_page.dart';
import 'package:qradar/presentation/customer/support/widgets/support_inquiry_answer_card.dart';
import 'package:qradar/presentation/customer/support/widgets/support_inquiry_image_viewer.dart';
import 'package:qradar/presentation/customer/support/widgets/support_inquiry_order_summary.dart';
import 'package:qradar/presentation/customer/support/widgets/support_inquiry_status_badge.dart';

/// 문의 상세. 데이터는 스트림이라 답변 도착·철회가 화면에 자동 반영된다.
class SupportInquiryDetailPage extends ConsumerStatefulWidget {
  const SupportInquiryDetailPage({
    super.key,
    required this.inquiryId,
    this.justCreated = false,
  });

  final String inquiryId;

  /// 작성 직후 진입 — 접수 토스트를 1회 띄운다.
  final bool justCreated;

  @override
  ConsumerState<SupportInquiryDetailPage> createState() =>
      _SupportInquiryDetailPageState();
}

class _SupportInquiryDetailPageState
    extends ConsumerState<SupportInquiryDetailPage> {
  bool _readRequested = false;
  bool _withdrawing = false;

  @override
  void initState() {
    super.initState();
    if (widget.justCreated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('문의가 접수됐어요')));
      });
    }
  }

  /// 답변 카드가 실제로 렌더되는 첫 데이터에서 1회만 읽음 처리. 실패는 조용히 무시.
  void _maybeMarkRead(SupportInquiryEntity q) {
    if (_readRequested || !q.hasUnreadAnswer) return;
    _readRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(markSupportInquiryAnswerReadUseCaseProvider).call(q.id);
      } catch (_) {
        // 읽음 표시 실패는 UI 에 노출하지 않는다.
      }
    });
  }

  Future<void> _withdraw() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '문의를 철회할까요?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        content: const Text(
          '철회하면 이 문의는 더 이상 처리되지 않아요.\n철회한 문의는 수정하거나 삭제할 수 없고, 내용을 고치려면 새로 작성해야 해요.',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textBody,
          ),
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              '취소',
              style: TextStyle(color: AppColors.textBody),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              '철회하기',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _withdrawing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(withdrawSupportInquiryUseCaseProvider)
          .call(widget.inquiryId);
      messenger.showSnackBar(const SnackBar(content: Text('문의를 철회했어요')));
    } on SupportInquiryException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.reason == SupportInquiryFailure.withdrawRejected
                ? '이미 답변이 등록되어 철회할 수 없어요'
                : '철회하지 못했어요. 잠시 후 다시 시도해 주세요.',
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('철회하지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
    } finally {
      if (mounted) setState(() => _withdrawing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(inquiryDetailProvider(widget.inquiryId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('문의 상세')),
      body: async.when(
        loading: () => const _DetailSkeleton(),
        error: (_, _) => _Message(
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.error,
          title: '문의를 불러오지 못했어요',
          actionLabel: '다시 시도',
          onAction: () =>
              ref.invalidate(inquiryDetailProvider(widget.inquiryId)),
        ),
        data: (q) {
          if (q == null) {
            return _Message(
              icon: Icons.search_off_rounded,
              iconColor: AppColors.textMuted,
              title: '문의를 찾을 수 없어요',
              actionLabel: '목록으로',
              onAction: () => Navigator.of(context).maybePop(),
            );
          }
          _maybeMarkRead(q);
          return _Body(
            inquiry: q,
            withdrawing: _withdrawing,
            onWithdraw: _withdraw,
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.inquiry,
    required this.withdrawing,
    required this.onWithdraw,
  });

  final SupportInquiryEntity inquiry;
  final bool withdrawing;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final q = inquiry;
    final snap = q.orderSnapshot;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SupportInquiryStatusBadge(status: q.status, large: true),
                    const Spacer(),
                    Text(
                      DateFormat('yyyy.MM.dd HH:mm').format(q.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  q.category.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  q.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHeading,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),
                SelectableText(
                  q.body,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textBody,
                  ),
                ),
                if (q.imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _Thumbs(urls: q.imageUrls),
                ],
              ],
            ),
          ),
          if (snap != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SupportInquiryOrderSummary(
                      storeName: snap.storeName,
                      pickupNumber: snap.pickupNumber,
                      totalPrice: snap.totalPrice,
                      date: snap.createdAt,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _answerArea(context),
          if (q.status == SupportInquiryStatus.open) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: withdrawing
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : OutlinedButton(
                      onPressed: onWithdraw,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surfaceElevated,
                        foregroundColor: AppColors.textBody,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '문의 철회',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );

  Widget _answerArea(BuildContext context) {
    final q = inquiry;
    final answer = q.answer;
    switch (q.status) {
      case SupportInquiryStatus.open:
        return _InfoCard(
          icon: Icons.hourglass_empty_rounded,
          title: '답변을 준비하고 있어요',
          sub: '확인되는 대로 답변드려요. 답변은 이 화면에서 확인할 수 있어요.',
        );
      case SupportInquiryStatus.answered:
        return answer == null
            ? const SizedBox.shrink()
            : SupportInquiryAnswerCard(answer: answer);
      case SupportInquiryStatus.closed:
        if (answer != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SupportInquiryAnswerCard(answer: answer),
              const SizedBox(height: 8),
              const Text(
                '종결된 문의예요',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          );
        }
        return _InfoCard(
          title: '종결 처리된 문의예요',
          sub: '추가로 궁금한 점은 새 문의로 남겨 주세요.',
          onNew: () => _openNew(context),
        );
      case SupportInquiryStatus.withdrawn:
        return _InfoCard(
          title: '철회한 문의예요',
          sub: '내용을 고쳐 다시 문의하려면 새로 작성해 주세요.',
          onNew: () => _openNew(context),
        );
    }
  }

  void _openNew(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SupportInquiryFormPage()),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    this.icon,
    required this.title,
    required this.sub,
    this.onNew,
  });

  final IconData? icon;
  final String title;
  final String sub;
  final VoidCallback? onNew;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 24, color: AppColors.textMuted),
            const SizedBox(height: 8),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textBody,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          if (onNew != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: onNew,
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.surfaceElevated,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '새로 문의하기',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Thumbs extends StatelessWidget {
  const _Thumbs({required this.urls});
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: i < urls.length
                ? AspectRatio(
                    aspectRatio: 1,
                    child: Semantics(
                      label: '첨부 사진 ${i + 1} / ${urls.length}, 확대 보기',
                      child: GestureDetector(
                        onTap: () => SupportInquiryImageViewer.open(
                          context,
                          images: [
                            for (final u in urls) CachedNetworkImageProvider(u),
                          ],
                          initialIndex: i,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: CachedNetworkImage(
                            imageUrl: urls[i],
                            fit: BoxFit.cover,
                            placeholder: (_, _) =>
                                const ColoredBox(color: AppColors.surface),
                            errorWidget: (_, _, _) => const ColoredBox(
                              color: AppColors.surface,
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: iconColor),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textBody,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget block() => Container(
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
    );
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [block(), const SizedBox(height: 16), block()]),
    );
  }
}

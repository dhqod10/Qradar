import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/errors/support_inquiry_exception.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/support_inquiry_category.dart';
import 'package:qradar/presentation/customer/order/orders/providers/order_view_providers.dart';
import 'package:qradar/presentation/customer/support/providers/support_inquiry_providers.dart';
import 'package:qradar/presentation/customer/support/support_inquiry_detail_page.dart';
import 'package:qradar/presentation/customer/support/widgets/support_inquiry_attachment_picker.dart';
import 'package:qradar/presentation/customer/support/widgets/support_inquiry_order_picker_sheet.dart';
import 'package:qradar/presentation/customer/support/widgets/support_inquiry_order_summary.dart';

/// 문의 작성. [presetOrderId] 가 있으면 해당 주문이 자동 연결되고 유형은 '주문' 이 기본 선택된다.
class SupportInquiryFormPage extends ConsumerStatefulWidget {
  const SupportInquiryFormPage({super.key, this.presetOrderId});

  final String? presetOrderId;

  @override
  ConsumerState<SupportInquiryFormPage> createState() =>
      _SupportInquiryFormPageState();
}

class _SupportInquiryFormPageState
    extends ConsumerState<SupportInquiryFormPage> {
  static const int _maxTitle = 60;
  static const int _maxBody = 2000;

  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _presetApplied = false;

  @override
  void initState() {
    super.initState();
    _title.addListener(_onInput);
    _body.addListener(_onInput);
    // preset 은 첫 프레임 이후 컨트롤러에 반영 (provider 수정은 build 중 금지).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.presetOrderId != null) {
        ref
            .read(inquiryFormControllerProvider.notifier)
            .setCategory(SupportInquiryCategory.order);
      }
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _onInput() {
    ref.read(inquiryFormControllerProvider.notifier).clearFailure();
    setState(() {});
  }

  /// preset 주문을 주문 스트림에서 찾아 연결한다 (1회).
  void _applyPresetOrder() {
    final id = widget.presetOrderId;
    if (_presetApplied || id == null) return;
    final list = ref.read(myOrdersProvider).asData?.value;
    if (list == null) return;
    _presetApplied = true;
    for (final o in list) {
      if (o.id == id) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref
                .read(inquiryFormControllerProvider.notifier)
                .setOrder(LinkedOrder.fromOrder(o));
          }
        });
        return;
      }
    }
  }

  bool get _dirtyByUser {
    final s = ref.read(inquiryFormControllerProvider);
    final categoryByUser = widget.presetOrderId == null
        ? s.category != null
        : s.category != SupportInquiryCategory.order && s.category != null;
    final orderByUser = widget.presetOrderId == null
        ? s.order != null
        : s.order?.id != widget.presetOrderId;
    return _title.text.isNotEmpty ||
        _body.text.isNotEmpty ||
        s.files.isNotEmpty ||
        categoryByUser ||
        orderByUser;
  }

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '작성을 취소할까요?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        content: const Text(
          '작성 중인 내용이 사라져요.',
          style: TextStyle(fontSize: 14, color: AppColors.textBody),
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              '계속 작성',
              style: TextStyle(color: AppColors.textBody),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('나가기', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final id = await ref
        .read(inquiryFormControllerProvider.notifier)
        .submit(title: _title.text, body: _body.text);
    if (!mounted) return;
    if (id != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              SupportInquiryDetailPage(inquiryId: id, justCreated: true),
        ),
      );
      return;
    }
    final f = ref.read(inquiryFormControllerProvider).failure;
    if (f == SupportInquiryFailure.invalidAttachment) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('첨부를 다시 선택해 주세요')));
    } else if (f == SupportInquiryFailure.unauthenticated ||
        f == SupportInquiryFailure.accountDeleted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인이 필요해요. 다시 로그인해 주세요.')));
    }
  }

  Future<void> _pickOrder() async {
    final s = ref.read(inquiryFormControllerProvider);
    final r = await showSupportInquiryOrderPicker(
      context,
      selectedOrderId: s.order?.id,
    );
    if (!mounted || r == null) return;
    final c = ref.read(inquiryFormControllerProvider.notifier);
    if (r is LinkedOrder) {
      c.setOrder(r);
    } else {
      c.setOrder(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(myOrdersProvider, (_, _) => _applyPresetOrder());
    _applyPresetOrder();
    final s = ref.watch(inquiryFormControllerProvider);
    final c = ref.read(inquiryFormControllerProvider.notifier);

    final canSubmit =
        s.category != null &&
        _title.text.trim().isNotEmpty &&
        _body.text.trim().isNotEmpty &&
        !s.busy;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || s.busy) return;
        final nav = Navigator.of(context);
        if (!_dirtyByUser || await _confirmLeave()) nav.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('문의하기')),
        body: AbsorbPointer(
          absorbing: s.busy,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _NoticeBanner(),
                const SizedBox(height: 24),
                const _Label('유형', required: true),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final cat in SupportInquiryCategory.values)
                      _CategoryChip(
                        label: cat.label,
                        selected: s.category == cat,
                        onTap: () => c.setCategory(cat),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                const _Label('관련 주문'),
                const SizedBox(height: 10),
                _OrderRow(
                  order: s.order,
                  onTap: _pickOrder,
                  onClear: () => c.setOrder(null),
                ),
                if (s.failure == SupportInquiryFailure.orderNotFound)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      '주문 정보를 확인할 수 없어요',
                      style: TextStyle(fontSize: 12, color: AppColors.error),
                    ),
                  ),
                const SizedBox(height: 24),
                const _Label('제목', required: true),
                const SizedBox(height: 10),
                _Field(
                  controller: _title,
                  hint: '제목을 입력해 주세요',
                  maxLength: _maxTitle,
                  minLines: 1,
                  maxLines: 1,
                  hasError: s.failure == SupportInquiryFailure.invalidInput,
                ),
                const SizedBox(height: 24),
                const _Label('내용', required: true),
                const SizedBox(height: 10),
                _Field(
                  controller: _body,
                  hint: '어떤 점이 궁금하거나 불편하셨는지 자세히 적어 주세요',
                  maxLength: _maxBody,
                  minLines: 6,
                  maxLines: 10,
                  hasError: s.failure == SupportInquiryFailure.invalidInput,
                ),
                if (s.failure == SupportInquiryFailure.invalidInput)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      '입력한 내용을 확인해 주세요',
                      style: TextStyle(fontSize: 12, color: AppColors.error),
                    ),
                  ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const _Label('사진 첨부 (선택)'),
                    const Spacer(),
                    Text(
                      '${s.files.length}/3',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SupportInquiryAttachmentPicker(
                  files: s.files,
                  busy: s.busy,
                  uploadedCount: s.uploadedCount,
                  uploadFailed: s.uploadFailed,
                  onAdd: c.addFiles,
                  onRemove: c.removeFileAt,
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              12 + MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_failureBox(s.failure) case final box?) ...[
                  box,
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: canSubmit ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      disabledBackgroundColor: AppColors.surface,
                      disabledForegroundColor: AppColors.textMuted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _submitLabel(s),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _submitLabel(InquiryFormState s) {
    if (s.phase == InquiryFormPhase.idle) {
      return const Text(
        '문의 접수하기',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      );
    }
    final text = s.phase == InquiryFormPhase.uploading
        ? '사진 업로드 중 (${s.uploadedCount}/${s.files.length})'
        : '접수하는 중…';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.onPrimary,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  /// 버튼 위 인라인 경고/에러 박스. 입력·첨부는 유지된다.
  Widget? _failureBox(SupportInquiryFailure? f) {
    if (f == null) return null;
    switch (f) {
      case SupportInquiryFailure.rateLimited:
        return const _InlineBox(
          color: AppColors.warning,
          icon: Icons.schedule_rounded,
          text: '문의를 너무 자주 보냈어요. 잠시 후 다시 시도해 주세요.',
        );
      case SupportInquiryFailure.network:
        return const _InlineBox(
          color: AppColors.error,
          icon: Icons.wifi_off_rounded,
          text: '네트워크 상태를 확인하고 다시 시도해 주세요.',
        );
      case SupportInquiryFailure.failed:
      case SupportInquiryFailure.notFound:
      case SupportInquiryFailure.alreadyAnswered:
      case SupportInquiryFailure.notOwner:
      case SupportInquiryFailure.withdrawRejected:
      case SupportInquiryFailure.imageUploadFailed:
        return const _InlineBox(
          color: AppColors.error,
          icon: Icons.error_outline_rounded,
          text: '문의를 접수하지 못했어요. 잠시 후 다시 시도해 주세요.',
        );
      case SupportInquiryFailure.invalidInput:
      case SupportInquiryFailure.invalidAttachment:
      case SupportInquiryFailure.orderNotFound:
      case SupportInquiryFailure.accountDeleted:
      case SupportInquiryFailure.unauthenticated:
        return null; // 필드 인라인 / SnackBar 로 이미 안내
    }
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '제출한 문의는 수정하거나 삭제할 수 없어요. 답변이 등록되기 전에는 철회할 수 있어요.\n카드 번호·비밀번호 같은 민감한 정보는 적지 마세요.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textBody,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.required = false});
  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        children: [
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: AppColors.error),
            ),
        ],
      ),
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textHeading,
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(999),
            border: selected ? null : Border.all(color: AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.onPrimary : AppColors.textBody,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({
    required this.order,
    required this.onTap,
    required this.onClear,
  });

  final LinkedOrder? order;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final o = order;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
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
              child: o == null
                  ? const Text(
                      '관련 주문 선택 (선택사항)',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    )
                  : SupportInquiryOrderSummary(
                      storeName: o.storeName,
                      pickupNumber: o.pickupNumber,
                      totalPrice: o.totalPrice,
                      date: o.createdAt,
                    ),
            ),
            if (o == null)
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textMuted,
              )
            else
              IconButton(
                tooltip: '연결 해제',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                onPressed: onClear,
              ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.maxLength,
    required this.minLines,
    required this.maxLines,
    required this.hasError,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final int minLines;
  final int maxLines;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c),
    );
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      cursorColor: AppColors.primary,
      style: const TextStyle(fontSize: 14, color: AppColors.textHeading),
      buildCounter:
          (_, {required currentLength, required isFocused, maxLength}) => Text(
            '$currentLength/$maxLength',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surfaceElevated,
        contentPadding: const EdgeInsets.all(14),
        enabledBorder: border(hasError ? AppColors.error : AppColors.border),
        focusedBorder: border(hasError ? AppColors.error : AppColors.primary),
      ),
    );
  }
}

class _InlineBox extends StatelessWidget {
  const _InlineBox({
    required this.color,
    required this.icon,
    required this.text,
  });

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppColors.textBody),
            ),
          ),
        ],
      ),
    );
  }
}

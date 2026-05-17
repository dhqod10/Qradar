import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/business_hours.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/common/widgets/error_dialog.dart';
import 'package:qradar/presentation/common/widgets/image_upload_field.dart';
import 'package:qradar/presentation/owner/providers/owner_providers.dart';

/// 매장 운영 필드 폼 — status 변동 없이 즉시 반영.
///
/// 다루는 필드: phone / businessHours / temporaryClosed / closedDates /
///             description / imageUrls / notice.
/// 저장 시 UpdateStoreOperationFieldsUseCase 호출.
class StoreOperationFormPage extends ConsumerStatefulWidget {
  final StoreEntity existing;

  const StoreOperationFormPage({super.key, required this.existing});

  @override
  ConsumerState<StoreOperationFormPage> createState() =>
      _StoreOperationFormPageState();
}

class _StoreOperationFormPageState
    extends ConsumerState<StoreOperationFormPage> {
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _noticeCtrl;

  late BusinessHours? _hours;
  late bool _temporaryClosed;
  late List<DateTime> _closedDates;
  late List<String> _imageUrls;

  File? _pickedImage;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _phoneCtrl = TextEditingController(text: e.phone);
    _descCtrl = TextEditingController(text: e.description ?? '');
    _noticeCtrl = TextEditingController(text: e.notice ?? '');
    _hours = e.businessHours;
    _temporaryClosed = e.temporaryClosed;
    _closedDates = List<DateTime>.from(e.closedDates);
    _imageUrls = List<String>.from(e.imageUrls);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _descCtrl.dispose();
    _noticeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textHeading),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '운영 정보',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
      ),
      body: Form(
        onChanged: () => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            // 즉시 반영 안내 배너
            _InstantNoticeBanner(),
            const SizedBox(height: 20),
            // 대표 이미지
            ImageUploadField(
              initialUrl: _imageUrls.isNotEmpty ? _imageUrls.first : null,
              height: 180,
              placeholderIcon: Icons.add_photo_alternate_rounded,
              onFileChanged: (f) => setState(() => _pickedImage = f),
            ),
            const SizedBox(height: 20),
            // 전화번호
            _FormField(
              label: '전화번호',
              controller: _phoneCtrl,
              placeholder: '010-0000-0000',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            // 영업시간
            _BusinessHoursPicker(
              hours: _hours,
              onChange: (h) => setState(() => _hours = h),
            ),
            const SizedBox(height: 20),
            // 임시 휴무 토글
            _TemporaryClosedToggle(
              value: _temporaryClosed,
              onChanged: (v) => setState(() => _temporaryClosed = v),
            ),
            const SizedBox(height: 12),
            // 휴무 날짜 리스트
            _ClosedDatesEditor(
              dates: _closedDates,
              onAdd: _addClosedDate,
              onRemove: (d) => setState(() => _closedDates.remove(d)),
            ),
            const SizedBox(height: 20),
            // 소개
            _FormField(
              label: '소개',
              controller: _descCtrl,
              placeholder: '매장 분위기나 대표 메뉴를 간단히 소개해주세요',
              maxLength: 200,
              maxLines: 4,
            ),
            const SizedBox(height: 20),
            // 매장 안내
            _FormField(
              label: '매장 안내',
              controller: _noticeCtrl,
              placeholder: '주차 안내, 포인트 적립 등 안내 사항을 입력해주세요',
              maxLength: 200,
              maxLines: 3,
            ),
          ],
        ),
      ),
      bottomSheet: _SubmitBar(
        submitting: _submitting,
        onSubmit: _submit,
      ),
    );
  }

  Future<void> _addClosedDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: '휴무 날짜 선택',
      confirmText: '추가',
      cancelText: '취소',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: AppColors.onPrimary,
            surface: AppColors.surfaceElevated,
            onSurface: AppColors.textHeading,
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked == null || !mounted) return;

    final normalized = DateTime(picked.year, picked.month, picked.day);
    final alreadyExists = _closedDates.any(
      (d) =>
          d.year == normalized.year &&
          d.month == normalized.month &&
          d.day == normalized.day,
    );
    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 추가된 날짜예요')),
      );
      return;
    }
    setState(() {
      _closedDates.add(normalized);
      _closedDates.sort();
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      // 이미지 업로드 처리
      List<String> finalImageUrls = List<String>.from(_imageUrls);
      if (_pickedImage != null) {
        final url = await ref
            .read(storageDataSourceProvider)
            .uploadStoreImage(
              ownerId: widget.existing.ownerId,
              file: _pickedImage!,
            );
        finalImageUrls = [url, ...finalImageUrls.skip(1)];
      }

      final updated = widget.existing.copyWith(
        phone: _phoneCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        notice: _noticeCtrl.text.trim().isEmpty
            ? null
            : _noticeCtrl.text.trim(),
        businessHours: _hours,
        temporaryClosed: _temporaryClosed,
        closedDates: _closedDates,
        imageUrls: finalImageUrls,
        imageUrl: finalImageUrls.isNotEmpty
            ? finalImageUrls.first
            : widget.existing.imageUrl,
      );

      await ref
          .read(updateStoreOperationFieldsUseCaseProvider)
          .call(updated);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('즉시 반영되었습니다'),
          backgroundColor: AppColors.success.withValues(alpha: 0.9),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      await showErrorDialog(context, '저장에 실패했어요. 다시 시도해주세요');
    }
  }
}

// ── 즉시 반영 안내 배너 ────────────────────────────────────────────────────

class _InstantNoticeBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 16, color: AppColors.success),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '아래 정보는 저장 즉시 반영돼요.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.success,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 공통 폼 필드 ───────────────────────────────────────────────────────────

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String placeholder;
  final int? maxLength;
  final int maxLines;
  final TextInputType? keyboardType;

  const _FormField({
    required this.label,
    required this.controller,
    required this.placeholder,
    this.maxLength,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textBody,
              ),
            ),
            const Spacer(),
            if (maxLength != null)
              Text(
                '${controller.text.length} / $maxLength',
                style: TextStyle(
                  fontSize: 11,
                  color: controller.text.length >= maxLength!
                      ? AppColors.accent
                      : AppColors.textMuted,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            maxLength: maxLength,
            maxLines: maxLines,
            keyboardType: keyboardType,
            cursorColor: AppColors.primaryBright,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textHeading,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              counterText: '',
              hintText: placeholder,
              hintStyle: const TextStyle(
                fontSize: 15,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 영업시간 피커 ──────────────────────────────────────────────────────────

class _BusinessHoursPicker extends StatelessWidget {
  final BusinessHours? hours;
  final ValueChanged<BusinessHours?> onChange;

  const _BusinessHoursPicker({required this.hours, required this.onChange});

  String get _open => hours?.openTime ?? '';
  String get _close => hours?.closeTime ?? '';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '영업시간',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textBody,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _TimeTile(
                label: '영업 시작',
                value: _open,
                onPick: (t) => _update(open: t),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('~', style: TextStyle(color: AppColors.textMuted)),
            ),
            Expanded(
              child: _TimeTile(
                label: '영업 종료',
                value: _close,
                onPick: (t) => _update(close: t),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _update({String? open, String? close}) {
    final nextOpen = open ?? _open;
    final nextClose = close ?? _close;
    if (nextOpen.isEmpty && nextClose.isEmpty) {
      onChange(null);
      return;
    }
    onChange(BusinessHours(openTime: nextOpen, closeTime: nextClose));
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onPick;

  const _TimeTile({
    required this.label,
    required this.value,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 2),
                  Text(
                    value.isEmpty ? '--:--' : value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color:
                          value.isEmpty ? AppColors.textMuted : AppColors.textHeading,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.access_time_rounded,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final initial = _parse(value) ?? const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primaryBright,
            surface: AppColors.surfaceElevated,
            onSurface: AppColors.textHeading,
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked == null) return;
    onPick(_fmt(picked));
  }

  TimeOfDay? _parse(String v) {
    final parts = v.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

// ── 임시 휴무 토글 ─────────────────────────────────────────────────────────

class _TemporaryClosedToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _TemporaryClosedToggle({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '임시 휴무',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHeading,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '활성화 시 잠시 휴무 상태로 표시돼요.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.error,
            activeTrackColor: AppColors.error.withValues(alpha: 0.2),
            inactiveTrackColor: AppColors.surface,
          ),
        ],
      ),
    );
  }
}

// ── 휴무 날짜 에디터 ───────────────────────────────────────────────────────

class _ClosedDatesEditor extends StatelessWidget {
  final List<DateTime> dates;
  final VoidCallback onAdd;
  final ValueChanged<DateTime> onRemove;

  const _ClosedDatesEditor({
    required this.dates,
    required this.onAdd,
    required this.onRemove,
  });

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.event_busy_rounded,
                  size: 18, color: AppColors.textHeading),
              SizedBox(width: 8),
              Text(
                '휴무 날짜',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHeading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '특정 날짜에 휴무인 경우 추가해주세요.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          if (dates.isEmpty)
            const Text(
              '추가된 휴무 날짜가 없어요.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: dates
                  .map((d) => _DateChip(
                        label: _fmt(d),
                        onRemove: () => onRemove(d),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded,
                size: 18, color: AppColors.primary),
            label: const Text(
              '휴무 날짜 추가',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            style: TextButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              foregroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _DateChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 저장 버튼 ─────────────────────────────────────────────────────────────

class _SubmitBar extends StatelessWidget {
  final bool submitting;
  final VoidCallback onSubmit;

  const _SubmitBar({required this.submitting, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: FilledButton(
            onPressed: submitting ? null : onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              disabledBackgroundColor: AppColors.surfaceElevated,
              disabledForegroundColor: AppColors.textMuted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: AppColors.onPrimary,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    '즉시 반영하기',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

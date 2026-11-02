import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/store_schedule_format.dart';
import 'package:qradar/domain/entities/business_hours.dart';
import 'package:qradar/domain/entities/main_category_entity.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/common/store_open_state.dart';
import 'package:qradar/presentation/common/widgets/error_dialog.dart';
import 'package:qradar/presentation/common/widgets/image_upload_field.dart';
import 'package:qradar/presentation/customer/order/orders/providers/order_di_providers.dart';
import 'package:qradar/presentation/customer/order/store/providers/main_category_providers.dart';
import 'package:qradar/presentation/owner/my_store/widgets/weekly_schedule_editor.dart';
import 'package:qradar/presentation/owner/providers/owner_providers.dart';

/// 매장 운영 필드 폼 — status 변동 없이 즉시 반영.
///
/// 다루는 필드: phone / businessHours / temporaryClosed / closedDates /
///             description / imageUrls / notice / excludedMainCategories.
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

  /// 점주가 끈(숨긴) 메인 카테고리 코드. 원본 전체를 들고 있고, 화면에는 active 만 렌더한다.
  /// 저장 시 active 가 아닌(휴면) 코드는 그대로 보존한다 (spec §2.1 / design §1.7).
  late Set<String> _excluded;

  File? _pickedImage;
  bool _submitting = false;
  final GlobalKey _scheduleKey = GlobalKey();

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
    _excluded = e.excludedMainCategories.toSet();
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
            // 영업 스케줄 → 휴무 날짜 → 임시 휴업 (스케줄 항목끼리 묶는다, design §1.1)
            KeyedSubtree(
              key: _scheduleKey,
              child: WeeklyScheduleEditor(
                value: _hours,
                enabled: !_submitting,
                onChanged: (h) => setState(() => _hours = h),
              ),
            ),
            const SizedBox(height: 12),
            IgnorePointer(
              ignoring: _submitting,
              child: Opacity(
                opacity: _submitting ? 0.6 : 1,
                child: _ClosedDatesEditor(
                  dates: _closedDates,
                  onAdd: _addClosedDate,
                  onRemove: (d) => setState(() => _closedDates.remove(d)),
                  onClearPast: () => setState(
                    () => _closedDates.removeWhere(_isPastDate),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // 임시 휴업 토글
            _TemporaryClosedToggle(
              value: _temporaryClosed,
              onChanged: (v) => setState(() => _temporaryClosed = v),
            ),
            const SizedBox(height: 20),
            // 카테고리 노출 설정 (임시 휴무와 같은 "매장 노출/운영" 성격이라 근처에 둔다)
            _CategoryExposureSection(
              async: ref.watch(mainCategoriesActiveProvider),
              excluded: _excluded,
              enabled: !_submitting,
              onToggle: (code, visible) => setState(() {
                visible ? _excluded.remove(code) : _excluded.add(code);
              }),
              onRetry: () => ref.invalidate(mainCategoriesActiveProvider),
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

  static bool _isPastDate(DateTime d) {
    final n = DateTime.now();
    return DateTime(d.year, d.month, d.day).isBefore(DateTime(n.year, n.month, n.day));
  }

  /// 저장 전 스케줄 확인 (design §2.1, §2.3). 막지 않는다 — 안내만. false = 사용자가 돌아가기.
  ///   · 전체 휴무(영구 휴업)로 바뀌는 저장 → 경고 다이얼로그
  ///   · 이번 저장으로 "지금부터" 닫히고 진행 중 주문이 1건 이상(또는 조회 실패) → 안내 다이얼로그 (0건이면 생략)
  Future<bool> _confirmScheduleChange() async {
    final existing = widget.existing;
    final allOffNow = _hours != null && _hours!.weeklyHours.isEmpty;
    final wasAllOff =
        existing.businessHours != null &&
        existing.businessHours!.weeklyHours.isEmpty;
    final needAllOff = allOffNow && !wasAllOff;

    final now = DateTime.now();
    final next = existing.copyWith(
      businessHours: _hours,
      closedDates: _closedDates,
    );
    final closesNow =
        !existing.temporaryClosed &&
        storeOpenStateOf(existing, now).isOpen &&
        !storeOpenStateOf(next, now).isOpen;

    if (!needAllOff && !closesNow) return true;

    int? activeCount; // null = 조회 실패 (막지 않고 숫자 없이 안내)
    var queryFailed = false;
    if (closesNow) {
      setState(() => _submitting = true);
      try {
        activeCount = await ref
            .read(countActiveStoreOrdersUseCaseProvider)
            .call(existing.id);
      } catch (_) {
        queryFailed = true;
      }
      if (!mounted) return false;
      setState(() => _submitting = false);
      if (!needAllOff && !queryFailed && (activeCount ?? 0) == 0) return true;
    }

    final hasActive = (activeCount ?? 0) > 0;
    final title = needAllOff
        ? '매장이 영구 휴업 상태가 돼요'
        : '지금부터 새 주문을 받지 않아요';
    final lines = <String>[
      if (needAllOff)
        '모든 요일이 휴무라서 손님이 이 매장에서 주문할 수 없어요. 요일별 영업시간을 다시 켜기 전까지 계속돼요. 그래도 저장할까요?'
      else if (hasActive)
        '이미 받은 주문 $activeCount건은 그대로 진행돼요. 새 주문만 받지 않아요.'
      else
        '저장하면 바로 새 주문을 받지 않아요.',
      if (needAllOff && hasActive) '이미 받은 주문 $activeCount건은 그대로 진행돼요.',
      if (!needAllOff) '자동으로 취소되는 주문은 없어요.',
    ];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        content: Text(
          lines.join('\n'),
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppColors.textBody,
          ),
        ),
        actions: [
          TextButton(
            autofocus: needAllOff,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              '돌아가기',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              needAllOff ? '그래도 저장' : '저장하기',
              style: TextStyle(
                color: needAllOff ? AppColors.error : AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    return ok ?? false;
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

  /// 저장할 excluded = (원본 중 active 가 아닌 휴면 코드) ∪ (화면에서 OFF 인 active 코드).
  /// active 목록을 못 불러온 상태(loading/error)면 원본을 그대로 보존한다.
  List<String> _resolveExcluded(List<MainCategoryEntity>? active) {
    if (active == null) return widget.existing.excludedMainCategories;
    final activeIds = active.map((c) => c.id).toSet();
    final dormant = widget.existing.excludedMainCategories
        .where((c) => !activeIds.contains(c));
    final off = activeIds.where(_excluded.contains);
    return [...dormant, ...off];
  }

  /// "전부 끄기" = 렌더된 active 카테고리가 1개 이상이고 전부 OFF.
  bool _allOff(List<MainCategoryEntity>? active) =>
      active != null &&
      active.isNotEmpty &&
      active.every((c) => _excluded.contains(c.id));

  Future<bool> _confirmAllOff() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '메뉴가 모두 숨겨져요',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        content: const Text(
          '모든 카테고리를 끄면 손님은 이 매장에서 메뉴를 볼 수 없어요. 그래도 저장할까요?',
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppColors.textBody,
          ),
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              '돌아가기',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              '저장',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _showActiveOrdersBlockedDialog(int count) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '지금은 임시 휴업할 수 없어요',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        content: Text(
          '진행 중인 주문이 $count건 있어요. 주문이 모두 끝나면 임시 휴업을 켤 수 있어요.',
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppColors.textBody,
          ),
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              '확인',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;

    // 스케줄 검증 (Q2): 시작 == 종료 행은 저장 차단 + 해당 카드로 스크롤.
    if (WeeklyScheduleEditor.hasInvalidRow(_hours)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('영업시간을 확인해 주세요')),
      );
      final ctx = _scheduleKey.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
      return;
    }
    final active = ref.read(mainCategoriesActiveProvider).asData?.value;
    // 이미 전부 OFF 로 저장돼 있고 그대로면 다이얼로그 생략 (반복 경고 방지).
    final wasAllOff = active != null &&
        active.isNotEmpty &&
        active.every(
          (c) => widget.existing.excludedMainCategories.contains(c.id),
        );
    if (_allOff(active) && !wasAllOff) {
      if (!await _confirmAllOff() || !mounted) return;
    }

    if (!await _confirmScheduleChange() || !mounted) return;
    setState(() => _submitting = true);

    // 임시 휴업 전환(false→true) 가드 — 진행 중 주문이 있으면 저장 중단 (temporary_closed_gate R5).
    // 권위가 아니다(TOCTOU 수용): 서버 결제 게이트가 백스톱. 조회 실패 시 막지 않고 저장 후 안내한다.
    var activeCheckFailed = false;
    if (_temporaryClosed && !widget.existing.temporaryClosed) {
      try {
        final n = await ref
            .read(countActiveStoreOrdersUseCaseProvider)
            .call(widget.existing.id);
        if (!mounted) return;
        if (n > 0) {
          setState(() {
            _temporaryClosed = false;
            _submitting = false;
          });
          await _showActiveOrdersBlockedDialog(n);
          return;
        }
      } catch (_) {
        activeCheckFailed = true;
      }
      if (!mounted) return;
    }

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
        excludedMainCategories: _resolveExcluded(active),
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
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('즉시 반영되었습니다'),
          backgroundColor: AppColors.success.withValues(alpha: 0.9),
        ),
      );
      if (activeCheckFailed) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('진행 중 주문을 확인하지 못했어요. 임시 휴업이 적용돼 신규 주문은 받지 않아요.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
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
                  '임시 휴업',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHeading,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '켜면 손님이 이 매장에서 주문할 수 없어요. 진행 중인 주문이 있으면 켤 수 없어요.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                SizedBox(height: 2),
                Text(
                  '임시 휴업은 영업 스케줄보다 우선해요.',
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

// ── 카테고리 노출 설정 ─────────────────────────────────────────────────────

/// 메인 카테고리별 노출 on/off. ON = 손님에게 노출 (기본 전부 ON), OFF 코드만 excluded 로 저장된다.
/// 로컬 폼 상태만 바꾸고 저장은 폼의 저장 버튼이 담당한다.
class _CategoryExposureSection extends StatelessWidget {
  final AsyncValue<List<MainCategoryEntity>> async;
  final Set<String> excluded;
  final bool enabled;
  final void Function(String code, bool visible) onToggle;
  final VoidCallback onRetry;

  const _CategoryExposureSection({
    required this.async,
    required this.excluded,
    required this.enabled,
    required this.onToggle,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cats = async.asData?.value;
    final hasCats = cats != null && cats.isNotEmpty;
    final allOff = hasCats && cats.every((c) => excluded.contains(c.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: const Text(
            '카테고리 노출 설정',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textBody,
            ),
          ),
        ),
        if (cats == null || hasCats) ...[
          const SizedBox(height: 4),
          const Text(
            '끄면 이 매장의 메뉴 탭과 검색에서 해당 카테고리 메뉴가 모두 사라져요. '
            '나중에 브랜드가 메뉴를 추가해도 다시 켜기 전까지 보이지 않아요.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textMuted,
            ),
          ),
        ],
        const SizedBox(height: 10),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: allOff
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Semantics(
                    liveRegion: true,
                    label: '모든 카테고리가 꺼져 있어요. 손님에게 메뉴가 보이지 않아요',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 16, color: AppColors.warning),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '모든 카테고리를 끄면 손님에게 메뉴가 하나도 보이지 않아 주문을 받을 수 없어요.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        _body(cats),
      ],
    );
  }

  Widget _body(List<MainCategoryEntity>? cats) {
    if (async.hasError && cats == null) {
      return Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: AppColors.error),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              '카테고리를 불러오지 못했어요',
              style: TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              '다시 시도',
              style: TextStyle(fontSize: 12, color: AppColors.primary),
            ),
          ),
        ],
      );
    }
    if (cats == null) {
      return _card(
        List.generate(3, (_) => const _CategoryShimmerRow()),
      );
    }
    if (cats.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text(
            '설정할 수 있는 카테고리가 없어요',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ),
      );
    }
    return _card([
      for (final c in cats)
        _CategoryToggleRow(
          label: c.label,
          visible: !excluded.contains(c.id),
          enabled: enabled,
          onChanged: (v) => onToggle(c.id, v),
        ),
    ]);
  }

  Widget _card(List<Widget> rows) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) {
        children.add(const Divider(height: 1, color: AppColors.border));
      }
      children.add(rows[i]);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _CategoryToggleRow extends StatelessWidget {
  final String label;
  final bool visible;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _CategoryToggleRow({
    required this.label,
    required this.visible,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        label: '$label 카테고리 노출',
        hint: '켜면 손님에게 보이고, 끄면 숨겨져요',
        toggled: visible,
        child: InkWell(
          onTap: enabled ? () => onChanged(!visible) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHeading,
                          ),
                        ),
                      ),
                      if (!visible) ...[
                        const SizedBox(height: 2),
                        const ExcludeSemantics(
                          child: Text(
                            '손님에게 숨김',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Switch(
                  value: visible,
                  onChanged: enabled ? onChanged : null,
                  activeThumbColor: AppColors.onPrimary,
                  activeTrackColor: AppColors.primary,
                  inactiveThumbColor: AppColors.textMuted,
                  inactiveTrackColor: AppColors.surface,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryShimmerRow extends StatelessWidget {
  const _CategoryShimmerRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Container(
            width: 80,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const Spacer(),
          Container(
            width: 44,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 특정 날짜 휴무 에디터 ──────────────────────────────────────────────────

class _ClosedDatesEditor extends StatelessWidget {
  final List<DateTime> dates;
  final VoidCallback onAdd;
  final ValueChanged<DateTime> onRemove;
  final VoidCallback onClearPast;

  const _ClosedDatesEditor({
    required this.dates,
    required this.onAdd,
    required this.onRemove,
    required this.onClearPast,
  });

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  String _label(DateTime d, DateTime today) {
    final wd = dayLabelOf(d.weekday);
    final y = d.year == today.year ? '' : '${d.year}년 ';
    return '$y${d.month}월 ${d.day}일 ($wd)';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = _day(now);
    final upcoming = dates.where((d) => !_day(d).isBefore(today)).toList()
      ..sort();
    final past = dates.where((d) => _day(d).isBefore(today)).toList()..sort();
    final ordered = [...upcoming, ...past];

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
          Row(
            children: [
              const Icon(Icons.event_busy_rounded,
                  size: 18, color: AppColors.textHeading),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '특정 날짜 휴무',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHeading,
                  ),
                ),
              ),
              if (past.isNotEmpty)
                TextButton(
                  onPressed: onClearPast,
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  child: const Text(
                    '지난 날짜 정리',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '공휴일·임시 휴무처럼 하루만 쉬는 날을 추가해 주세요. 요일별 스케줄보다 우선해요.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          if (dates.isEmpty)
            const Text(
              '추가된 휴무 날짜가 없어요.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in ordered)
                  _DateChip(
                    label: _label(d, today),
                    isToday: _day(d) == today,
                    isPast: _day(d).isBefore(today),
                    onRemove: () => onRemove(d),
                  ),
              ],
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
  final bool isToday;
  final bool isPast;
  final VoidCallback onRemove;

  const _DateChip({
    required this.label,
    required this.isToday,
    required this.isPast,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 12),
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
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isPast ? AppColors.textMuted : AppColors.textHeading,
            ),
          ),
          if (isToday) ...[
            const SizedBox(width: 6),
            _Tag(
              text: '오늘',
              background: AppColors.primary,
              foreground: AppColors.onPrimary,
            ),
          ],
          if (isPast) ...[
            const SizedBox(width: 6),
            _Tag(
              text: '지남',
              background: AppColors.surface,
              foreground: AppColors.textMuted,
            ),
          ],
          Semantics(
            button: true,
            label: '$label 휴무 삭제',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: const SizedBox(
                width: 40,
                height: 36,
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;

  const _Tag({
    required this.text,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
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

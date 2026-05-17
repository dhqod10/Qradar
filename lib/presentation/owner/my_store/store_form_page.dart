import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kpostal/kpostal.dart';
import 'package:qradar/core/constants/menu_categories.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/business_hours.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/store_grade.dart';
import 'package:qradar/domain/entities/user_location.dart';
import 'package:qradar/presentation/common/widgets/error_dialog.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/owner/providers/owner_providers.dart';

/// 매장 등록 / 수정 공통 폼.
///
/// [existing] 이 null 이면 신규 등록, 있으면 수정.
class StoreFormPage extends ConsumerStatefulWidget {
  final StoreEntity? existing;
  const StoreFormPage({super.key, this.existing});

  @override
  ConsumerState<StoreFormPage> createState() => _StoreFormPageState();
}

class _StoreFormPageState extends ConsumerState<StoreFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  final _selectedCategories = <String>{};
  UserLocation? _location;
  String? _resolvedAddress;
  BusinessHours? _hours;
  File? _pickedImage;
  String? _existingImageUrl;
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _phoneCtrl.text = e.phone;
      _addressCtrl.text = e.address;
      _descCtrl.text = e.description ?? '';
      _selectedCategories.addAll(e.menuCategories);
      _location = e.location;
      _hours = e.businessHours;
      _existingImageUrl = e.imageUrl.isNotEmpty ? e.imageUrl : null;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _isValid {
    return _nameCtrl.text.trim().isNotEmpty &&
        _phoneCtrl.text.trim().isNotEmpty &&
        _addressCtrl.text.trim().isNotEmpty &&
        _selectedCategories.isNotEmpty &&
        _location != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isEdit ? '매장 수정' : '매장 등록',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        onChanged: () => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            _ImagePickerTile(
              pickedFile: _pickedImage,
              existingUrl: _existingImageUrl,
              onPick: _pickImage,
              onClear: () => setState(() {
                _pickedImage = null;
                _existingImageUrl = null;
              }),
            ),
            const SizedBox(height: 20),
            _FormField(
              label: '매장명',
              required: true,
              controller: _nameCtrl,
              placeholder: '매장 이름을 입력해주세요',
              maxLength: 30,
            ),
            const SizedBox(height: 20),
            _FormField(
              label: '전화번호',
              required: true,
              controller: _phoneCtrl,
              placeholder: '010-0000-0000',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            _FormField(
              label: '주소',
              required: true,
              controller: _addressCtrl,
              placeholder: '예: 서울시 강남구 테헤란로 1',
            ),
            const SizedBox(height: 20),
            _AddressSearchTile(
              location: _location,
              resolvedAddress: _resolvedAddress,
              onTap: _openAddressSearch,
            ),
            const SizedBox(height: 20),
            _CategoryMultiSelect(
              selected: _selectedCategories,
              onToggle: (c) => setState(() {
                if (_selectedCategories.contains(c)) {
                  _selectedCategories.remove(c);
                } else {
                  _selectedCategories.add(c);
                }
              }),
            ),
            const SizedBox(height: 20),
            _BusinessHoursPicker(
              hours: _hours,
              onChange: (h) => setState(() => _hours = h),
            ),
            const SizedBox(height: 20),
            _FormField(
              label: '소개',
              controller: _descCtrl,
              placeholder: '매장 분위기나 대표 메뉴를 간단히 소개해주세요',
              maxLength: 200,
              maxLines: 4,
            ),
          ],
        ),
      ),
      bottomSheet: _SubmitBar(
        isEdit: _isEdit,
        enabled: _isValid && !_submitting,
        submitting: _submitting,
        onSubmit: _submit,
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      setState(() => _pickedImage = File(file.path));
    } catch (_) {
      if (!mounted) return;
      await showErrorDialog(context, '이미지를 불러오지 못했어요. 다시 시도해주세요');
    }
  }

  Future<void> _openAddressSearch() async {
    final result = await Navigator.of(context).push<Kpostal>(
      MaterialPageRoute(
        builder: (_) => KpostalView(
          title: '매장 주소 검색',
          appBarColor: AppColors.background,
          titleColor: AppColors.textDark,
          loadingColor: AppColors.primaryBright,
          callback: (_) {},
        ),
      ),
    );
    if (result == null || !mounted) return;

    final address = result.address;
    final lat = result.latitude;
    final lng = result.longitude;

    setState(() {
      _resolvedAddress = address;
      _addressCtrl.text = address;
      if (lat != null && lng != null) {
        _location = UserLocation(latitude: lat, longitude: lng);
      }
    });

    if (lat == null || lng == null) {
      if (!mounted) return;
      await showErrorDialog(context, '좌표 변환에 실패했어요. 다른 주소로 다시 시도해주세요');
    }
  }

  Future<void> _submit() async {
    if (!_isValid || _submitting) return;
    setState(() => _submitting = true);

    final authUser = ref.read(authProvider).asData?.value;
    if (authUser == null) {
      setState(() => _submitting = false);
      return;
    }

    try {
      String imageUrl = _existingImageUrl ?? '';
      if (_pickedImage != null) {
        imageUrl = await ref.read(storageDataSourceProvider).uploadStoreImage(
              ownerId: authUser.uid,
              file: _pickedImage!,
            );
      }

      final entity = StoreEntity(
        id: widget.existing?.id ?? '',
        ownerId: authUser.uid,
        name: _nameCtrl.text.trim(),
        imageUrl: imageUrl,
        location: _location!,
        grade: widget.existing?.grade ?? StoreGrade.c,
        averageScore: widget.existing?.averageScore ?? 0.0,
        reviewCount: widget.existing?.reviewCount ?? 0,
        menuCategories: _selectedCategories.toList(growable: false),
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
        phone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        businessHours: _hours,
      );

      if (_isEdit) {
        await ref.read(updateStoreUseCaseProvider).call(entity);
      } else {
        await ref.read(registerStoreUseCaseProvider).call(entity);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('매장 정보가 저장되었습니다'),
          backgroundColor: AppColors.accent.withValues(alpha: 0.9),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          title: const Text(
            '저장에 실패했어요',
            style: TextStyle(color: AppColors.textDark, fontSize: 17),
          ),
          content: Text(
            '$e',
            style: const TextStyle(color: AppColors.textDefault, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('닫기'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _submit();
              },
              child: const Text('재시도'),
            ),
          ],
        ),
      );
    }
  }
}

// ── 공통 폼 필드 ───────────────────────────────────────────────────────────

class _FormField extends StatelessWidget {
  final String label;
  final bool required;
  final TextEditingController controller;
  final String placeholder;
  final int? maxLength;
  final int maxLines;
  final TextInputType? keyboardType;

  const _FormField({
    required this.label,
    required this.controller,
    required this.placeholder,
    this.required = false,
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
                color: AppColors.textDefault,
              ),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(color: AppColors.accent, fontSize: 13),
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
              color: AppColors.textDark,
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

// ── 이미지 피커 ───────────────────────────────────────────────────────────

class _ImagePickerTile extends StatelessWidget {
  final File? pickedFile;
  final String? existingUrl;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _ImagePickerTile({
    required this.pickedFile,
    required this.existingUrl,
    required this.onPick,
    required this.onClear,
  });

  bool get _hasImage => pickedFile != null || existingUrl != null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hasImage
                ? AppColors.primaryBright.withValues(alpha: 0.5)
                : AppColors.surfaceElevated,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (pickedFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(pickedFile!, fit: BoxFit.cover),
              )
            else if (existingUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(existingUrl!, fit: BoxFit.cover),
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.add_photo_alternate_rounded,
                      size: 36,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(height: 8),
                    Text(
                      '대표 이미지 추가 (선택)',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            if (_hasImage)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: onClear,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.background.withValues(alpha: 0.7),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── 주소 검색 ─────────────────────────────────────────────────────────────

class _AddressSearchTile extends StatelessWidget {
  final UserLocation? location;
  final String? resolvedAddress;
  final VoidCallback onTap;

  const _AddressSearchTile({
    required this.location,
    required this.resolvedAddress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasLoc = location != null;
    final hasAddress =
        resolvedAddress != null && resolvedAddress!.trim().isNotEmpty;
    final displayText = hasAddress
        ? resolvedAddress!
        : hasLoc
            ? '${location!.latitude.toStringAsFixed(6)}, ${location!.longitude.toStringAsFixed(6)}'
            : '주소를 검색해주세요';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_on_rounded,
            size: 24,
            color: AppColors.primaryBright,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '매장 위치 *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDefault,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayText,
                  style: TextStyle(
                    fontSize: 13,
                    color: (hasLoc || hasAddress)
                        ? AppColors.textDefault
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: const Text(
              '주소 찾기',
              style: TextStyle(
                color: AppColors.primaryBright,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 카테고리 다중 선택 ───────────────────────────────────────────────────

class _CategoryMultiSelect extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _CategoryMultiSelect({
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              '카테고리',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textDefault,
              ),
            ),
            Text(
              ' *',
              style: TextStyle(color: AppColors.accent, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MenuCategories.all.map((c) {
            final active = selected.contains(c);
            return GestureDetector(
              onTap: () => onToggle(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primaryBright.withValues(alpha: 0.18)
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active
                        ? AppColors.primaryBright
                        : AppColors.surfaceElevated,
                  ),
                ),
                child: Text(
                  c,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active
                        ? AppColors.primaryBright
                        : AppColors.textDefault,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── 운영시간 ─────────────────────────────────────────────────────────────

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
          '운영시간',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textDefault,
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
    onChange(
      BusinessHours(openTime: nextOpen, closeTime: nextClose),
    );
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
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value.isEmpty ? '--:--' : value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: value.isEmpty
                          ? AppColors.textMuted
                          : AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.access_time_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
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
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryBright,
              surface: AppColors.surfaceElevated,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) return;
    onPick(_format(picked));
  }

  TimeOfDay? _parse(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

// ── 저장 버튼 ─────────────────────────────────────────────────────────────

class _SubmitBar extends StatelessWidget {
  final bool isEdit;
  final bool enabled;
  final bool submitting;
  final VoidCallback onSubmit;

  const _SubmitBar({
    required this.isEdit,
    required this.enabled,
    required this.submitting,
    required this.onSubmit,
  });

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
            onPressed: enabled ? onSubmit : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.textDark,
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
                      color: AppColors.textDark,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    isEdit ? '수정 완료' : '매장 등록',
                    style: const TextStyle(
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

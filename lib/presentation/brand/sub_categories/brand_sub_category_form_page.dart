import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/errors/duplicate_sub_category_name_exception.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/main_category_entity.dart';
import 'package:qradar/domain/entities/sub_category_entity.dart';
import 'package:qradar/presentation/brand/sub_categories/providers/brand_sub_category_providers.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';
import 'package:qradar/presentation/customer/order/store/providers/main_category_providers.dart';

/// 브랜드 서브 카테고리 등록 / 수정 통합 폼 페이지.
class BrandSubCategoryFormPage extends ConsumerStatefulWidget {
  final SubCategoryEntity? editItem;

  const BrandSubCategoryFormPage({super.key, this.editItem});

  @override
  ConsumerState<BrandSubCategoryFormPage> createState() =>
      _BrandSubCategoryFormPageState();
}

class _BrandSubCategoryFormPageState
    extends ConsumerState<BrandSubCategoryFormPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _orderCtrl;
  bool _active = true;
  bool _isSaving = false;
  bool _isDuplicateChecking = false;

  String? _selectedMainCategoryCode;
  String? _nameError;
  Timer? _debounce;

  bool get _isEditMode => widget.editItem != null;

  bool get _canSave =>
      _nameCtrl.text.trim().isNotEmpty &&
      _selectedMainCategoryCode != null &&
      _nameError == null &&
      !_isSaving &&
      !_isDuplicateChecking;

  @override
  void initState() {
    super.initState();
    final e = widget.editItem;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _orderCtrl =
        TextEditingController(text: e?.displayOrder.toString() ?? '0');
    _active = e?.active ?? true;
    _selectedMainCategoryCode = e?.mainCategoryCode;

    _nameCtrl.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    setState(() {
      _nameError = null;
      _isDuplicateChecking = true;
    });
    _debounce?.cancel();
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _isDuplicateChecking = false);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final profile =
          ref.read(currentUserProfileProvider).asData?.value;
      final brandId = profile?.brandId;
      if (brandId == null || brandId.isEmpty) {
        if (mounted) setState(() => _isDuplicateChecking = false);
        return;
      }
      final isDuplicate =
          await ref.read(findDuplicateSubCategoryNameUseCaseProvider).call(
                name: name,
                scope: SubCategoryScope.brand,
                brandId: brandId,
                excludeId: _isEditMode ? widget.editItem!.id : null,
              );
      if (!mounted) return;
      setState(() {
        _nameError =
            isDuplicate ? '이미 같은 이름의 분류가 있어요' : null;
        _isDuplicateChecking = false;
      });
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final profile = ref.read(currentUserProfileProvider).asData?.value;
    final brandId = profile?.brandId;
    if (brandId == null || brandId.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final entity = SubCategoryEntity(
        id: _isEditMode
            ? widget.editItem!.id
            : '${_selectedMainCategoryCode!}_${now.millisecondsSinceEpoch}',
        mainCategoryCode: _selectedMainCategoryCode!,
        name: _nameCtrl.text.trim(),
        displayOrder: int.tryParse(_orderCtrl.text.trim()) ?? 0,
        active: _active,
        scope: SubCategoryScope.brand,
        brandId: brandId,
        createdAt: _isEditMode ? widget.editItem!.createdAt : null,
      );
      await ref.read(upsertSubCategoryUseCaseProvider).call(entity);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(_isEditMode ? '분류를 수정했어요' : '분류를 추가했어요'),
        ),
      );
      Navigator.of(context).pop();
    } on DuplicateSubCategoryNameException {
      if (!mounted) return;
      setState(() => _nameError = '이미 같은 이름의 분류가 있어요');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('처리에 실패했어요. 다시 시도해주세요')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(mainCategoriesActiveProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textBody),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_isEditMode ? '분류 수정' : '분류 추가'),
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textHeading,
        ),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이름
            _FormSection(
              label: '분류 이름',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    maxLength: 20,
                    style: const TextStyle(
                        fontSize: 15, color: AppColors.textBody),
                    decoration: InputDecoration(
                      hintText: '예: 에스프레소, 콜드브루, 라떼',
                      hintStyle: const TextStyle(
                          fontSize: 15, color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
                      errorText: _nameError,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.primary),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.error),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.error),
                      ),
                      errorStyle: const TextStyle(
                          fontSize: 11, color: AppColors.error),
                      counterStyle: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 메인 카테고리 선택
            _FormSection(
              label: '메인 카테고리',
              child: categoriesAsync.when(
                loading: () => const _ShimmerBox(
                    width: double.infinity, height: 50, radius: 10),
                error: (_, _) => const Text('목록을 불러오지 못했어요',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.error)),
                data: (categories) =>
                    _MainCategorySelector(
                  categories: categories,
                  selected: _selectedMainCategoryCode,
                  onSelect: (code) =>
                      setState(() => _selectedMainCategoryCode = code),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 정렬 순서
            _FormSection(
              label: '정렬 순서',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _orderCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: const TextStyle(
                        fontSize: 15, color: AppColors.textBody),
                    decoration: InputDecoration(
                      hintText: '0, 1, 2 ...',
                      hintStyle: const TextStyle(
                          fontSize: 15, color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '숫자가 낮을수록 앞에 표시돼요',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 활성화 스위치
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '활성화',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textBody,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '비활성화 시 메뉴 폼에서 숨겨져요',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
                Switch.adaptive(
                  value: _active,
                  activeThumbColor: AppColors.primary,
                  activeTrackColor:
                      AppColors.primaryBright.withValues(alpha: 0.3),
                  inactiveThumbColor: AppColors.textMuted,
                  inactiveTrackColor: AppColors.surface,
                  onChanged: (v) => setState(() => _active = v),
                ),
              ],
            ),
            const SizedBox(height: 36),

            // 버튼 Row
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surfaceElevated,
                        side:
                            const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
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
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _canSave ? _save : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canSave
                            ? AppColors.primary
                            : AppColors.textMuted,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onPrimary,
                              ),
                            )
                          : const Text(
                              '저장',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onPrimary,
                              ),
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

// ── 메인 카테고리 칩 선택기 ────────────────────────────────────────────────

class _MainCategorySelector extends StatelessWidget {
  final List<MainCategoryEntity> categories;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _MainCategorySelector({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((cat) {
        final isSelected = cat.id == selected;
        return GestureDetector(
          onTap: () => onSelect(cat.id),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(999),
              border: isSelected
                  ? null
                  : Border.all(color: AppColors.border),
            ),
            child: Text(
              cat.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? AppColors.onPrimary
                    : AppColors.textBody,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── 공통 섹션 레이블 ─────────────────────────────────────────────────────────

class _FormSection extends StatelessWidget {
  final String label;
  final Widget child;

  const _FormSection({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

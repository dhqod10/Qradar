import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_item_scope.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/entities/option_scope.dart';
import 'package:qradar/presentation/brand/master_menu/widgets/option_group_selector.dart';
import 'package:qradar/presentation/brand/option_groups/providers/brand_option_group_providers.dart';
import 'package:qradar/presentation/brand/providers/brand_di_providers.dart';
import 'package:qradar/presentation/brand/providers/brand_master_menu_providers.dart';
import 'package:qradar/presentation/brand/providers/brand_store_management_providers.dart';
import 'package:qradar/presentation/brand/sub_categories/providers/brand_sub_category_providers.dart';
import 'package:qradar/presentation/common/widgets/error_dialog.dart';
import 'package:qradar/presentation/common/widgets/image_upload_field.dart';
import 'package:qradar/presentation/common/widgets/inactive_category_warning_banner.dart';
import 'package:qradar/presentation/common/widgets/sub_category_chips_selector.dart';
import 'package:qradar/presentation/common/widgets/tag_chips_selector.dart';
import 'package:qradar/presentation/customer/order/store/providers/main_category_providers.dart';

/// 점포 한정 메뉴 등록 / 수정 / 복제 통합 폼.
///
/// - 등록: [editItem] == null && [sourceForClone] == null
/// - 수정: [editItem] != null
/// - 복제: [sourceForClone] != null
///
/// scope=store 및 brandId/storeId 는 자동으로 박힘 (Repository 책임).
class BrandStoreOnlyMenuFormPage extends ConsumerStatefulWidget {
  final String brandId;
  final String storeId;
  final MenuItemEntity? editItem;
  final MenuItemEntity? sourceForClone;

  const BrandStoreOnlyMenuFormPage({
    super.key,
    required this.brandId,
    required this.storeId,
    this.editItem,
    this.sourceForClone,
  });

  @override
  ConsumerState<BrandStoreOnlyMenuFormPage> createState() =>
      _BrandStoreOnlyMenuFormPageState();
}

class _BrandStoreOnlyMenuFormPageState
    extends ConsumerState<BrandStoreOnlyMenuFormPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _orderCtrl;

  File? _imageFile;
  String? _imageUrl;
  String? _imageError;
  double? _uploadProgress;

  String? _selectedMainCategory;
  String? _selectedSubCategoryId;
  List<String> _tags = [];
  bool _visible = true;
  bool _isLoading = false;
  List<String> _selectedOptionGroupIds = [];

  // sub-phase 7 patch: 메뉴별 비활성 옵션 그룹/항목 ID 목록
  List<String> _disabledOptionGroupIds = [];
  List<String> _disabledOptionItemIds = [];

  bool get _isEditMode => widget.editItem != null;
  bool get _isCloneMode => widget.sourceForClone != null;

  String get _title {
    if (_isCloneMode) return '점포 한정 메뉴 복제';
    if (_isEditMode) return '점포 한정 메뉴 수정';
    return '점포 한정 메뉴 등록';
  }

  bool get _canSubmit =>
      (_imageFile != null || (_imageUrl != null && _imageUrl!.isNotEmpty)) &&
      _nameCtrl.text.trim().isNotEmpty &&
      (int.tryParse(_priceCtrl.text) ?? 0) > 0 &&
      _selectedMainCategory != null;

  @override
  void initState() {
    super.initState();
    final source = widget.editItem ?? widget.sourceForClone;
    _nameCtrl = TextEditingController(
      text: _isCloneMode && source != null
          ? '${source.name} 복사'
          : source?.name ?? '',
    );
    _descCtrl = TextEditingController(text: source?.description ?? '');
    _priceCtrl = TextEditingController(
      text: source != null ? source.basePrice.toString() : '',
    );
    _orderCtrl = TextEditingController(
      text: source?.displayOrder.toString() ?? '0',
    );
    _imageUrl =
        source?.imageUrl.isNotEmpty == true ? source!.imageUrl : null;
    _selectedMainCategory = source?.mainCategoryCode;
    _selectedSubCategoryId = source?.subCategoryId;
    _tags = List<String>.from(source?.tags ?? []);
    _visible = source?.visible ?? true;
    _selectedOptionGroupIds =
        source?.optionGroupRefs.map((r) => r.id).toList() ?? [];

    // sub-phase 7 patch: disabledOption* prefill
    _disabledOptionGroupIds = List<String>.from(source?.disabledOptionGroupIds ?? []);
    _disabledOptionItemIds = List<String>.from(source?.disabledOptionItemIds ?? []);

    _nameCtrl.addListener(() => setState(() {}));
    _priceCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  // ── 변경 필드 분석 (결정 J 패턴) ────────────────────────────────────────────

  bool _hasCoreFieldChange(MenuItemEntity old, MenuItemEntity next) {
    return old.name != next.name ||
        old.basePrice != next.basePrice ||
        old.mainCategoryCode != next.mainCategoryCode ||
        old.subCategoryId != next.subCategoryId ||
        old.description != next.description ||
        old.optionGroupRefs.length != next.optionGroupRefs.length ||
        !_listEquals(
          old.optionGroupRefs.map((r) => r.id).toList(),
          next.optionGroupRefs.map((r) => r.id).toList(),
        );
  }

  /// 운영 필드(visible, tags, displayOrder, imageUrl, disabledOptionGroupIds,
  /// disabledOptionItemIds) 중 하나 이상 변경됐는지 판별 (결정 J 정합).
  bool _hasOperationFieldChange(MenuItemEntity old, MenuItemEntity next) {
    return old.visible != next.visible ||
        old.displayOrder != next.displayOrder ||
        old.imageUrl != next.imageUrl ||
        !_listEquals(old.tags, next.tags) ||
        !_sortedListEquals(old.disabledOptionGroupIds, next.disabledOptionGroupIds) ||
        !_sortedListEquals(old.disabledOptionItemIds, next.disabledOptionItemIds);
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// 순서 무관 리스트 비교 — 정렬 후 [_listEquals] 로 비교.
  bool _sortedListEquals(List<String> a, List<String> b) {
    final sa = [...a]..sort();
    final sb = [...b]..sort();
    return _listEquals(sa, sb);
  }

  /// 선택된 옵션 그룹 id 목록을 master/brand 출처에 따라 OptionGroupRef 로 변환.
  /// master list 에 있으면 master scope, 아니면 brand scope (가맹점 매장 정책).
  List<OptionGroupRef> _buildOptionGroupRefs() {
    final master = ref.read(brandMasterOptionGroupsProvider).asData?.value ??
        const <OptionGroupEntity>[];
    final masterIds = master.map((g) => g.id).toSet();
    return _selectedOptionGroupIds
        .map((id) => OptionGroupRef(
              scope: masterIds.contains(id)
                  ? OptionScope.master
                  : OptionScope.brand,
              id: id,
            ))
        .toList(growable: false);
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('필수 항목(이미지, 이름, 가격, 카테고리)을 모두 입력해주세요'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _imageError = null;
    });

    try {
      String imageUrl = _imageUrl ?? '';

      if (_imageFile != null) {
        setState(() => _uploadProgress = 0.0);
        final storage = ref.read(brandStorageDataSourceProvider);
        final menuId = widget.editItem?.id ?? 'new';
        imageUrl = await storage.uploadMasterMenuImage(
          brandId: widget.brandId,
          menuItemId: menuId,
          file: _imageFile!,
        );
        setState(() => _uploadProgress = null);
      }

      final item = MenuItemEntity(
        id: _isCloneMode ? '' : (widget.editItem?.id ?? ''),
        storeId: widget.storeId,
        name: _nameCtrl.text.trim(),
        imageUrl: imageUrl,
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        mainCategoryCode: _selectedMainCategory ?? 'coffee',
        subCategoryId: _selectedSubCategoryId,
        basePrice: int.tryParse(_priceCtrl.text) ?? 0,
        optionGroupRefs: _buildOptionGroupRefs(),
        displayOrder: int.tryParse(_orderCtrl.text) ?? 0,
        scope: MenuItemScope.store,
        brandId: widget.brandId,
        tags: _tags,
        visible: _visible,
        disabledOptionGroupIds: _disabledOptionGroupIds,
        disabledOptionItemIds: _disabledOptionItemIds,
      );

      if (_isEditMode) {
        final old = widget.editItem!;
        final hasCoreChange = _hasCoreFieldChange(old, item);
        final hasOpChange = _hasOperationFieldChange(old, item);

        if (!hasCoreChange && !hasOpChange) {
          if (!mounted) return;
          Navigator.pop(context);
          return;
        }

        if (hasCoreChange) {
          await ref
              .read(updateStoreOnlyMenuCoreUseCaseProvider)
              .call(item);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('검토 요청을 보냈어요')),
          );
        } else {
          await ref
              .read(updateStoreOnlyMenuOperationUseCaseProvider)
              .call(item);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('즉시 반영되었습니다')),
          );
        }
      } else {
        await ref.read(createStoreOnlyMenuUseCaseProvider).call(item);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('검토 요청을 보냈어요')),
        );
      }

      Navigator.pop(context);
    } on ArgumentError catch (e) {
      setState(() => _imageError = e.message.toString());
    } catch (_) {
      if (!mounted) return;
      await showErrorDialog(context, '저장에 실패했어요. 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            _isEditMode
                ? Icons.arrow_back_ios_new_rounded
                : Icons.close_rounded,
            color: AppColors.textHeading,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _sectionLabel('메뉴 이미지 *'),
            const SizedBox(height: 8),
            ImageUploadField(
              initialUrl: _imageUrl,
              height: 180,
              placeholderIcon: Icons.local_cafe_outlined,
              uploadProgress: _uploadProgress,
              errorMessage: _imageError,
              onFileChanged: (f) => setState(() => _imageFile = f),
            ),
            _divider(),
            _sectionLabel('메뉴 이름 *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              maxLength: 40,
              style: const TextStyle(fontSize: 15, color: AppColors.textBody),
              decoration: _inputDecoration('메뉴 이름을 입력해주세요'),
            ),
            const SizedBox(height: 12),
            _sectionLabel('메뉴 설명'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              minLines: 2,
              style: const TextStyle(fontSize: 15, color: AppColors.textBody),
              decoration: _inputDecoration('메뉴 설명을 입력해주세요 (선택)'),
            ),
            _divider(),
            _sectionLabel('기본 가격 *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 15, color: AppColors.textBody),
              decoration: _inputDecoration('0').copyWith(
                prefixText: '₩ ',
                prefixStyle:
                    const TextStyle(fontSize: 15, color: AppColors.textMuted),
              ),
            ),
            _divider(),
            _sectionLabel('카테고리 *'),
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final allAsync = ref.watch(mainCategoriesAllProvider);
              final cats = allAsync.asData?.value ?? const [];
              final activeIds =
                  cats.where((c) => c.active).map((c) => c.id).toSet();
              final visibleCats = _isEditMode
                  ? cats
                  : cats.where((c) => c.active).toList();
              final isCurrentInactive = _selectedMainCategory != null &&
                  cats.any((c) => c.id == _selectedMainCategory) &&
                  !activeIds.contains(_selectedMainCategory);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isCurrentInactive)
                    const InactiveCategoryWarningBanner(),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: visibleCats.map((c) {
                      final selected = _selectedMainCategory == c.id;
                      final inactive = !c.active;
                      final disabled = inactive && !selected;
                      final chip = Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? (inactive
                                  ? AppColors.warning.withValues(alpha: 0.6)
                                  : AppColors.primary)
                              : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(999),
                          border: selected
                              ? null
                              : Border.all(
                                  color: disabled
                                      ? AppColors.border.withValues(alpha: 0.5)
                                      : AppColors.border,
                                ),
                        ),
                        child: Text(
                          c.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: selected
                                ? AppColors.onPrimary
                                : (disabled
                                    ? AppColors.textMuted
                                    : AppColors.textBody),
                          ),
                        ),
                      );
                      if (disabled) {
                        return IgnorePointer(child: chip);
                      }
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (_selectedMainCategory != c.id) {
                            _selectedMainCategory = c.id;
                            _selectedSubCategoryId = null;
                          }
                        }),
                        child: chip,
                      );
                    }).toList(),
                  ),
                ],
              );
            }),
            if (_selectedMainCategory != null)
              Builder(builder: (context) {
                final allSubs = ref
                    .watch(brandSubCategoriesAllProvider)
                    .asData
                    ?.value
                    .where((s) =>
                        s.mainCategoryCode == _selectedMainCategory &&
                        (s.active || s.id == _selectedSubCategoryId))
                    .toList() ?? [];
                if (allSubs.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    _sectionLabel('서브 카테고리'),
                    const SizedBox(height: 8),
                    SubCategoryChipsSelector(
                      subCategories: allSubs,
                      selectedId: _selectedSubCategoryId,
                      onSelect: (id) =>
                          setState(() => _selectedSubCategoryId = id),
                    ),
                  ],
                );
              }),
            _divider(),
            _sectionLabel('옵션 그룹'),
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final master = ref
                      .watch(brandMasterOptionGroupsProvider)
                      .asData
                      ?.value ??
                  const <OptionGroupEntity>[];
              final brand = widget.brandId.isEmpty
                  ? const <OptionGroupEntity>[]
                  : ref
                          .watch(brandOptionGroupsActiveByIdProvider(
                              widget.brandId))
                          .asData
                          ?.value ??
                      const <OptionGroupEntity>[];
              return OptionGroupSelector(
                optionGroups: master,
                brandGroups: brand,
                selectedIds: _selectedOptionGroupIds,
                onChanged: (ids) =>
                    setState(() => _selectedOptionGroupIds = ids),
                disabledOptionItemIds: _disabledOptionItemIds,
                onDisabledItemsChanged: (updated) =>
                    setState(() => _disabledOptionItemIds = updated),
              );
            }),
            _divider(),
            _sectionLabel('태그'),
            const SizedBox(height: 8),
            TagChipsSelector(
              selected: _tags,
              onChanged: (tags) => setState(() => _tags = tags),
            ),
            _divider(),
            _sectionLabel('노출 순서'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _orderCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 15, color: AppColors.textBody),
              decoration: _inputDecoration('0'),
            ),
            const SizedBox(height: 6),
            const Text(
              '숫자가 낮을수록 앞에 노출됩니다',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: _SubmitButton(
        canSubmit: _canSubmit,
        isLoading: _isLoading,
        onTap: _submit,
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
        ),
      );

  Widget _divider() =>
      const Divider(height: 32, color: AppColors.border, thickness: 1);

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 15, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      );
}

class _SubmitButton extends StatelessWidget {
  final bool canSubmit;
  final bool isLoading;
  final VoidCallback onTap;

  const _SubmitButton({
    required this.canSubmit,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: isLoading ? null : onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canSubmit ? AppColors.primary : AppColors.surface,
                foregroundColor:
                    canSubmit ? AppColors.onPrimary : AppColors.textMuted,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: canSubmit
                      ? BorderSide.none
                      : const BorderSide(color: AppColors.border),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : const Text(
                      '제출 (검토 요청)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_item_scope.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/entities/option_scope.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/brand/master_menu/widgets/option_group_selector.dart';
import 'package:qradar/presentation/common/widgets/error_dialog.dart';
import 'package:qradar/presentation/common/widgets/image_upload_field.dart';
import 'package:qradar/presentation/common/widgets/inactive_category_warning_banner.dart';
import 'package:qradar/presentation/common/widgets/sub_category_chips_selector.dart';
import 'package:qradar/presentation/common/widgets/tag_chips_selector.dart';
import 'package:qradar/presentation/owner/sub_categories/providers/owner_sub_category_providers.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/order/store/providers/main_category_providers.dart';
import 'package:qradar/presentation/owner/providers/owner_providers.dart';
import 'package:qradar/presentation/owner/providers/owner_store_menu_providers.dart';

/// 개인 매장 메뉴 등록 / 수정 / 복제 통합 폼 (sub-phase 4).
///
/// - [editItem] == null && [prefillItem] == null → 신규 등록 (create)
/// - [editItem] != null → 수정 (edit)
/// - [prefillItem] != null → 복제 prefill (create, V8)
///
/// D1: status 배지 / 승인 메타 / Core/Operation 분리 안내 미노출.
/// D5: 폼 상단 즉시 반영 안내 배너.
class OwnerStoreMenuFormPage extends ConsumerStatefulWidget {
  final StoreEntity store;
  final MenuItemEntity? editItem;
  final MenuItemEntity? prefillItem;

  const OwnerStoreMenuFormPage({
    super.key,
    required this.store,
    this.editItem,
    this.prefillItem,
  });

  @override
  ConsumerState<OwnerStoreMenuFormPage> createState() =>
      _OwnerStoreMenuFormPageState();
}

class _OwnerStoreMenuFormPageState
    extends ConsumerState<OwnerStoreMenuFormPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _orderCtrl;

  File? _imageFile;
  String? _imageUrl;
  String? _imageError;

  String? _selectedMainCategory;
  String? _selectedSubCategoryId;
  List<String> _tags = [];
  bool _visible = true;
  List<String> _selectedOptionGroupIds = [];
  bool _isLoading = false;

  // sub-phase 7 patch: 메뉴별 비활성 옵션 그룹/항목 ID 목록
  List<String> _disabledOptionGroupIds = [];
  List<String> _disabledOptionItemIds = [];

  bool get _isEditMode => widget.editItem != null;
  bool get _isPrefillMode => widget.prefillItem != null;

  String get _title {
    if (_isPrefillMode) return '메뉴 복제';
    if (_isEditMode) return '메뉴 수정';
    return '메뉴 추가';
  }

  MenuItemEntity? get _source => widget.editItem ?? widget.prefillItem;

  bool get _canSubmit {
    final hasImage =
        _imageFile != null || (_imageUrl != null && _imageUrl!.isNotEmpty);
    return hasImage &&
        _nameCtrl.text.trim().isNotEmpty &&
        (int.tryParse(_priceCtrl.text) ?? 0) > 0 &&
        _selectedMainCategory != null;
  }

  @override
  void initState() {
    super.initState();
    final source = _source;
    _nameCtrl = TextEditingController(
      text: _isPrefillMode && source != null
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
    // 복제 시 imageUrl 은 빈 문자열 (V8)
    _imageUrl = _isPrefillMode
        ? null
        : (source?.imageUrl.isNotEmpty == true ? source!.imageUrl : null);
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

  Future<void> _submit() async {
    if (!_canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('필수 항목을 모두 입력해주세요'),
          backgroundColor: AppColors.textHeading.withValues(alpha: 0.9),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _imageError = null;
    });

    try {
      final authUser = ref.read(authProvider).asData?.value;
      final uid = authUser?.uid ?? '';
      String imageUrl = _imageUrl ?? '';

      // 이미지 업로드
      if (_imageFile != null) {
        final storage = ref.read(storageDataSourceProvider);
        final menuId = widget.editItem?.id.isNotEmpty == true
            ? widget.editItem!.id
            : 'new_${DateTime.now().millisecondsSinceEpoch}';
        try {
          imageUrl = await storage.uploadStoreMenuImage(
            storeId: widget.store.id,
            menuItemId: menuId,
            file: _imageFile!,
          );
        } on ArgumentError catch (e) {
          // 5MB 초과
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message.toString()),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 2),
            ),
          );
          setState(() => _isLoading = false);
          return;
        } catch (_) {
          if (!mounted) return;
          await showErrorDialog(context, '이미지 업로드에 실패했어요. 다시 시도해주세요');
          setState(() => _isLoading = false);
          return;
        }
      }

      // optionGroupRefs 구성 (store scope 판별)
      final optionGroupRefs = _buildOptionGroupRefs();

      final item = MenuItemEntity(
        id: widget.editItem?.id ?? '',
        storeId: widget.store.id,
        name: _nameCtrl.text.trim(),
        imageUrl: imageUrl,
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        mainCategoryCode: _selectedMainCategory ?? 'coffee',
        subCategoryId: _selectedSubCategoryId,
        basePrice: int.tryParse(_priceCtrl.text) ?? 0,
        optionGroupRefs: optionGroupRefs,
        displayOrder: int.tryParse(_orderCtrl.text) ?? 0,
        scope: MenuItemScope.store,
        brandId: null,
        tags: _tags,
        visible: _visible,
        disabledOptionGroupIds: _disabledOptionGroupIds,
        disabledOptionItemIds: _disabledOptionItemIds,
        soldOut: _source?.soldOut ?? false,
        submittedBy: uid,
      );

      // edit 모드 변경 없음 감지 (D4 보강 — UseCase 호출 없이 pop)
      if (_isEditMode && !_hasChanged(item)) {
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      if (_isEditMode) {
        await ref.read(updateOwnerStoreMenuUseCaseProvider).call(item);
      } else {
        await ref.read(createOwnerStoreMenuUseCaseProvider).call(item);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('저장됐어요'),
          backgroundColor: AppColors.primary.withValues(alpha: 0.9),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      await showErrorDialog(context, '저장에 실패했어요. 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// edit 모드에서 폼 입력값과 기존 entity 비교 — 변경 없으면 UseCase 호출 생략.
  bool _hasChanged(MenuItemEntity submitted) {
    final src = widget.editItem;
    if (src == null) return true;
    if (submitted.name != src.name) return true;
    if (submitted.basePrice != src.basePrice) return true;
    if (submitted.imageUrl != src.imageUrl) return true;
    if (submitted.description != src.description) return true;
    if (submitted.mainCategoryCode != src.mainCategoryCode) return true;
    if (submitted.subCategoryId != src.subCategoryId) return true;
    if (submitted.displayOrder != src.displayOrder) return true;
    if (submitted.visible != src.visible) return true;
    // tags / optionGroupRefs 는 List 비교
    if (!_listEqualsString(submitted.tags, src.tags)) return true;
    if (submitted.optionGroupRefs.length != src.optionGroupRefs.length) {
      return true;
    }
    for (var i = 0; i < submitted.optionGroupRefs.length; i++) {
      if (submitted.optionGroupRefs[i].id != src.optionGroupRefs[i].id ||
          submitted.optionGroupRefs[i].scope != src.optionGroupRefs[i].scope) {
        return true;
      }
    }
    // sub-phase 7 patch: disabledOption* 비교 (순서 무관)
    if (!_sortedListEquals(submitted.disabledOptionGroupIds, src.disabledOptionGroupIds)) return true;
    if (!_sortedListEquals(submitted.disabledOptionItemIds, src.disabledOptionItemIds)) return true;
    return false;
  }

  bool _listEqualsString(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// 순서 무관 리스트 비교 — 정렬 후 [_listEqualsString] 로 비교.
  bool _sortedListEquals(List<String> a, List<String> b) {
    final sa = [...a]..sort();
    final sb = [...b]..sort();
    return _listEqualsString(sa, sb);
  }

  List<OptionGroupRef> _buildOptionGroupRefs() {
    final storeAsync = ref.read(storeOptionGroupsProvider(widget.store.id));
    final storeIds =
        storeAsync.asData?.value.map((g) => g.id).toSet() ?? const <String>{};

    return _selectedOptionGroupIds.map((id) {
      final scope =
          storeIds.contains(id) ? OptionScope.store : OptionScope.master;
      return OptionGroupRef(scope: scope, id: id);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final masterGroups =
        ref.watch(masterOptionGroupsProvider).asData?.value ?? [];
    final storeGroups =
        ref.watch(storeOptionGroupsProvider(widget.store.id)).asData?.value ??
            [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            (_isEditMode && !_isPrefillMode)
                ? Icons.arrow_back_ios_new_rounded
                : Icons.close_rounded,
            color: AppColors.textHeading,
          ),
          onPressed: () => Navigator.of(context).pop(),
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
      bottomNavigationBar: _SubmitBar(
        isLoading: _isLoading,
        canSubmit: _canSubmit,
        onSubmit: _submit,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            // D5: 즉시 반영 안내 배너
            const _ImmediateBanner(),

            const SizedBox(height: 16),

            // 이미지 섹션
            const _SectionHeader(label: '메뉴 이미지'),
            ImageUploadField(
              initialUrl: _imageUrl,
              height: 180,
              placeholderIcon: Icons.local_cafe_outlined,
              errorMessage: _imageError,
              onFileChanged: (file) => setState(() {
                _imageFile = file;
                _imageError = null;
              }),
            ),

            const _SectionDivider(),

            // 기본 정보 섹션
            const _SectionHeader(label: '기본 정보'),
            _buildTextField(
              controller: _nameCtrl,
              hint: '메뉴 이름을 입력해주세요',
              maxLength: 40,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _descCtrl,
              hint: '메뉴 설명을 입력해주세요 (선택)',
              maxLines: 3,
              minLines: 2,
            ),

            const _SectionDivider(),

            // 가격 섹션
            const _SectionHeader(label: '가격'),
            _buildTextField(
              controller: _priceCtrl,
              hint: '0',
              prefix: '₩ ',
              keyboardType: TextInputType.number,
            ),

            const _SectionDivider(),

            // 카테고리 섹션
            const _SectionHeader(label: '카테고리'),
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
                      final isSelected = _selectedMainCategory == c.id;
                      final inactive = !c.active;
                      final disabled = inactive && !isSelected;
                      final chip = Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (inactive
                                  ? AppColors.warning.withValues(alpha: 0.6)
                                  : AppColors.primary)
                              : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(999),
                          border: isSelected
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
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
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
                final storeId = widget.store.id;
                final allSubs = ref
                    .watch(storeSubCategoriesByIdProvider(storeId))
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
                    const _SectionHeader(label: '서브 카테고리'),
                    SubCategoryChipsSelector(
                      subCategories: allSubs,
                      selectedId: _selectedSubCategoryId,
                      onSelect: (id) =>
                          setState(() => _selectedSubCategoryId = id),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              }),

            const _SectionDivider(),

            // 태그 섹션
            const _SectionHeader(label: '태그'),
            TagChipsSelector(
              selected: _tags,
              onChanged: (v) => setState(() => _tags = v),
            ),

            const _SectionDivider(),

            // 노출 순서 섹션
            const _SectionHeader(label: '노출 순서'),
            _buildTextField(
              controller: _orderCtrl,
              hint: '0',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 4),
            const Text(
              '숫자가 낮을수록 앞에 노출됩니다',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),

            const _SectionDivider(),

            // 옵션 그룹 섹션 (V6: master + store 양쪽)
            const _SectionHeader(label: '옵션 그룹'),
            OptionGroupSelector(
              optionGroups: masterGroups,
              storeGroups: storeGroups,
              storeId: widget.store.id,
              selectedIds: _selectedOptionGroupIds,
              onChanged: (ids) =>
                  setState(() => _selectedOptionGroupIds = ids),
              disabledOptionItemIds: _disabledOptionItemIds,
              onDisabledItemsChanged: (updated) =>
                  setState(() => _disabledOptionItemIds = updated),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    int? minLines,
    int? maxLength,
    String? prefix,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, color: AppColors.textBody),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 15, color: AppColors.textMuted),
        prefixText: prefix,
        prefixStyle:
            const TextStyle(fontSize: 15, color: AppColors.textMuted),
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
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        counterText: '',
      ),
    );
  }
}

// ── 즉시 반영 배너 (D5) ──────────────────────────────────────────────────

class _ImmediateBanner extends StatelessWidget {
  const _ImmediateBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 16, color: AppColors.success),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '저장 즉시 반영돼요.',
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

// ── 섹션 구분 ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 32, color: AppColors.border, thickness: 1);
  }
}

// ── 하단 저장 버튼 ────────────────────────────────────────────────────────

class _SubmitBar extends StatelessWidget {
  final bool isLoading;
  final bool canSubmit;
  final VoidCallback onSubmit;

  const _SubmitBar({
    required this.isLoading,
    required this.canSubmit,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (canSubmit && !isLoading) ? onSubmit : null,
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
                        color: AppColors.onPrimary,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      '저장',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: canSubmit
                            ? AppColors.onPrimary
                            : AppColors.textMuted,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

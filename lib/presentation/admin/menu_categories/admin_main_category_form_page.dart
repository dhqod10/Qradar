import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/main_category_entity.dart';
import 'package:qradar/presentation/customer/order/store/providers/main_category_providers.dart';

/// 메인 카테고리 등록 / 수정 통합 폼 페이지 (admin 전용).
///
/// - [editItem] == null: 등록 모드 (id 자유 입력)
/// - [editItem] != null: 수정 모드 (id read-only)
class AdminMainCategoryFormPage extends ConsumerStatefulWidget {
  final MainCategoryEntity? editItem;

  const AdminMainCategoryFormPage({super.key, this.editItem});

  @override
  ConsumerState<AdminMainCategoryFormPage> createState() =>
      _AdminMainCategoryFormPageState();
}

class _AdminMainCategoryFormPageState
    extends ConsumerState<AdminMainCategoryFormPage> {
  late final TextEditingController _idCtrl;
  late final TextEditingController _labelCtrl;
  late final TextEditingController _orderCtrl;
  bool _active = true;
  bool _isSaving = false;

  bool get _isEditMode => widget.editItem != null;

  bool get _canSave =>
      _idCtrl.text.trim().isNotEmpty && _labelCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final e = widget.editItem;
    _idCtrl = TextEditingController(text: e?.id ?? '');
    _labelCtrl = TextEditingController(text: e?.label ?? '');
    _orderCtrl =
        TextEditingController(text: e?.displayOrder.toString() ?? '0');
    _active = e?.active ?? true;

    _idCtrl.addListener(() => setState(() {}));
    _labelCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _labelCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);
    try {
      final entity = MainCategoryEntity(
        id: _idCtrl.text.trim(),
        label: _labelCtrl.text.trim(),
        displayOrder: int.tryParse(_orderCtrl.text.trim()) ?? 0,
        active: _active,
      );
      await ref.read(upsertMainCategoryUseCaseProvider).call(entity);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(_isEditMode ? '카테고리를 수정했어요' : '카테고리를 추가했어요'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('already-exists') ||
              e.toString().contains('duplicate')
          ? '이미 사용 중인 코드예요. 다른 코드를 입력해주세요'
          : '처리에 실패했어요. 다시 시도해주세요';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textBody),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_isEditMode ? '카테고리 수정' : '카테고리 추가'),
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
            // ID 섹션
            _FormSection(
              label: '카테고리 코드 (ID)',
              child: _isEditMode
                  ? _IdReadOnly(id: widget.editItem!.id)
                  : _IdInput(controller: _idCtrl),
            ),
            const SizedBox(height: 20),

            // label 섹션
            _FormSection(
              label: '카테고리 이름',
              child: _buildTextField(
                controller: _labelCtrl,
                hint: '예: 커피, 논커피, 디저트',
                maxLength: 10,
              ),
            ),
            const SizedBox(height: 20),

            // displayOrder 섹션
            _FormSection(
              label: '정렬 순서',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(
                    controller: _orderCtrl,
                    hint: '0, 1, 2 ...',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
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

            // active 스위치 섹션
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
                      '비활성화 시 고객 화면과 메뉴 폼에서 숨겨져요',
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
                        side: const BorderSide(color: AppColors.border),
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
                      onPressed:
                          (_canSave && !_isSaving) ? _save : null,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 15, color: AppColors.textBody),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
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
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        errorStyle:
            const TextStyle(fontSize: 11, color: AppColors.error),
        counterStyle:
            const TextStyle(fontSize: 11, color: AppColors.textMuted),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

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

class _IdInput extends StatelessWidget {
  final TextEditingController controller;

  const _IdInput({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          maxLength: 20,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
          ],
          style:
              const TextStyle(fontSize: 15, color: AppColors.textBody),
          decoration: InputDecoration(
            hintText: '예: coffee, bakery, juice',
            hintStyle: const TextStyle(
                fontSize: 15, color: AppColors.textMuted),
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
                  const BorderSide(color: AppColors.primary),
            ),
            errorStyle: const TextStyle(
                fontSize: 11, color: AppColors.error),
            counterStyle: const TextStyle(
                fontSize: 11, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '영문·숫자, lowerCamelCase, 최대 20자. 등록 후 변경 불가',
          style:
              TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _IdReadOnly extends StatelessWidget {
  final String id;

  const _IdReadOnly({required this.id});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  id,
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.textMuted),
                ),
              ),
              const Icon(Icons.lock_outline_rounded,
                  size: 16, color: AppColors.textMuted),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '등록된 코드는 변경할 수 없어요',
          style:
              TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

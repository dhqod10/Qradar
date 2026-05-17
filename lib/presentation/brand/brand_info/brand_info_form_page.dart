import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kpostal/kpostal.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/presentation/brand/providers/brand_di_providers.dart';
import 'package:qradar/presentation/brand/providers/brand_info_providers.dart';
import 'package:qradar/presentation/common/widgets/error_dialog.dart';
import 'package:qradar/presentation/common/widgets/image_upload_field.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';

// 사업자등록번호: 000-00-00000
final _bizRegNoRegex = RegExp(r'^\d{3}-\d{2}-\d{5}$');
// 전화번호: 00-0000-0000 ~ 000-0000-0000 등
final _phoneRegex = RegExp(r'^\d{2,3}-\d{3,4}-\d{4}$');

/// 브랜드 등록(brand == null) / 수정(brand != null) 통합 폼.
class BrandInfoFormPage extends ConsumerStatefulWidget {
  final BrandEntity? brand;

  const BrandInfoFormPage({super.key, required this.brand});

  @override
  ConsumerState<BrandInfoFormPage> createState() => _BrandInfoFormPageState();
}

class _BrandInfoFormPageState extends ConsumerState<BrandInfoFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _companyNameCtrl;
  late final TextEditingController _bizRegNoCtrl;
  late final TextEditingController _contactNameCtrl;
  late final TextEditingController _contactPhoneCtrl;
  late final TextEditingController _headOfficeAddressCtrl;
  late final TextEditingController _representativeNameCtrl;

  File? _logoFile;
  String? _logoUrl;
  bool _isLoading = false;
  double? _uploadProgress;
  String? _imageError;

  bool get _isEditMode => widget.brand != null;

  bool get _bizRegNoValid =>
      _bizRegNoRegex.hasMatch(_bizRegNoCtrl.text.trim());

  bool get _phoneValid =>
      _phoneRegex.hasMatch(_contactPhoneCtrl.text.trim());

  bool get _canSubmit =>
      (_logoFile != null || (_logoUrl != null && _logoUrl!.isNotEmpty)) &&
      _nameCtrl.text.trim().isNotEmpty &&
      _companyNameCtrl.text.trim().isNotEmpty &&
      _bizRegNoValid &&
      _contactNameCtrl.text.trim().isNotEmpty &&
      _phoneValid;

  @override
  void initState() {
    super.initState();
    final b = widget.brand;
    _nameCtrl = TextEditingController(text: b?.name ?? '');
    _descCtrl = TextEditingController(text: b?.description ?? '');
    _companyNameCtrl = TextEditingController(text: b?.companyName ?? '');
    _bizRegNoCtrl =
        TextEditingController(text: b?.businessRegistrationNumber ?? '');
    _contactNameCtrl = TextEditingController(text: b?.contactName ?? '');
    _contactPhoneCtrl = TextEditingController(text: b?.contactPhone ?? '');
    _headOfficeAddressCtrl =
        TextEditingController(text: b?.headOfficeAddress ?? '');
    _representativeNameCtrl =
        TextEditingController(text: b?.representativeName ?? '');
    _logoUrl = b?.logoUrl;

    for (final c in [
      _nameCtrl,
      _companyNameCtrl,
      _bizRegNoCtrl,
      _contactNameCtrl,
      _contactPhoneCtrl,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _companyNameCtrl.dispose();
    _bizRegNoCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _headOfficeAddressCtrl.dispose();
    _representativeNameCtrl.dispose();
    super.dispose();
  }

  /// 신규 등록 모드에서 X 버튼 → "고객 모드로 돌아가기" confirm.
  /// 확인 시 users.role 을 customer 로 되돌림 → RoleRouter 자동 redirect.
  Future<void> _confirmDowngradeToCustomer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '고객 모드로 돌아갈까요?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHeading,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '브랜드 등록을 취소하고 고객 화면으로 돌아갑니다. '
                '브랜드 등록은 언제든 다시 시도할 수 있어요.',
                style: TextStyle(fontSize: 13, color: AppColors.textBody),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text(
                        '취소',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('돌아가기'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final uid = ref.read(authProvider).asData?.value?.uid ?? '';
      if (uid.isEmpty) throw StateError('로그인 정보를 찾을 수 없습니다.');
      await ref.read(downgradeToCustomerUseCaseProvider).call(uid);
      // RoleRouter 가 users.role 변경을 watch 해서 자동으로 customer 화면으로 redirect.
    } catch (_) {
      if (!mounted) return;
      await showErrorDialog(context, '처리에 실패했어요. 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openHeadOfficeAddressSearch() async {
    final result = await Navigator.of(context).push<Kpostal>(
      MaterialPageRoute(
        builder: (_) => KpostalView(
          title: '본사 주소 검색',
          appBarColor: AppColors.background,
          titleColor: AppColors.textHeading,
          loadingColor: AppColors.primaryBright,
          callback: (_) {},
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _headOfficeAddressCtrl.text = result.address;
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('필수 항목을 모두 올바르게 입력해주세요')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _imageError = null;
    });

    try {
      String logoUrl = _logoUrl ?? '';

      if (_logoFile != null) {
        setState(() => _uploadProgress = 0.0);
        final storage = ref.read(brandStorageDataSourceProvider);
        final brandId = widget.brand?.id ?? '';
        logoUrl = await storage.uploadBrandImage(
          brandId: brandId.isEmpty ? 'temp' : brandId,
          file: _logoFile!,
        );
        setState(() => _uploadProgress = null);
      }

      final brand = BrandEntity(
        id: widget.brand?.id ?? '',
        name: _nameCtrl.text.trim(),
        logoUrl: logoUrl,
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        companyName: _companyNameCtrl.text.trim(),
        businessRegistrationNumber: _bizRegNoCtrl.text.trim(),
        contactName: _contactNameCtrl.text.trim(),
        contactPhone: _contactPhoneCtrl.text.trim(),
        headOfficeAddress: _headOfficeAddressCtrl.text.trim().isEmpty
            ? null
            : _headOfficeAddressCtrl.text.trim(),
        representativeName: _representativeNameCtrl.text.trim().isEmpty
            ? null
            : _representativeNameCtrl.text.trim(),
      );

      await ref.read(upsertBrandUseCaseProvider).call(brand);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('검토 요청을 보냈어요')),
      );
      Navigator.pop(context);
    } on ArgumentError catch (e) {
      setState(() => _imageError = e.message);
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
        // 수정 모드: push 로 진입 → 뒤로가기 (Navigator.pop).
        // 신규 등록 모드: BrandScaffold home 위치 직접 노출 → pop 불가.
        //   X 버튼 누르면 "고객 모드로 돌아가기" confirm → role downgrade →
        //   RoleRouter 가 자동으로 customer 화면으로 redirect.
        leading: IconButton(
          icon: Icon(
            _isEditMode
                ? Icons.arrow_back_ios_new_rounded
                : Icons.close_rounded,
            color: AppColors.textHeading,
          ),
          onPressed: _isEditMode
              ? () => Navigator.pop(context)
              : _confirmDowngradeToCustomer,
        ),
        title: Text(
          _isEditMode ? '브랜드 수정' : '브랜드 등록',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // ── 브랜드 정보 섹션 ───────────────────────────────────────
              _sectionLabel('브랜드 로고'),
              const SizedBox(height: 8),
              ImageUploadField(
                initialUrl: _logoUrl,
                height: 160,
                placeholderIcon: Icons.storefront_rounded,
                uploadProgress: _uploadProgress,
                errorMessage: _imageError,
                onFileChanged: (f) => setState(() => _logoFile = f),
              ),
              const SizedBox(height: 24),
              _sectionLabel('브랜드 이름 *'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                maxLength: 30,
                style:
                    const TextStyle(fontSize: 15, color: AppColors.textBody),
                decoration: _inputDecoration('브랜드 이름을 입력해주세요'),
              ),
              const SizedBox(height: 16),
              _sectionLabel('브랜드 설명'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 5,
                minLines: 3,
                style:
                    const TextStyle(fontSize: 15, color: AppColors.textBody),
                decoration: _inputDecoration('브랜드 설명을 입력해주세요'),
              ),
              // ── 사업자 정보 섹션 ───────────────────────────────────────
              const SizedBox(height: 32),
              _sectionDivider('사업자 정보'),
              const SizedBox(height: 16),
              _sectionLabel('회사명 *'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _companyNameCtrl,
                maxLength: 60,
                style:
                    const TextStyle(fontSize: 15, color: AppColors.textBody),
                decoration: _inputDecoration('(주)스타벅스코리아'),
              ),
              const SizedBox(height: 16),
              _sectionLabel('사업자등록번호 *'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bizRegNoCtrl,
                keyboardType: TextInputType.number,
                style:
                    const TextStyle(fontSize: 15, color: AppColors.textBody),
                decoration: _inputDecorationWithError(
                  hint: '000-00-00000',
                  errorText:
                      _bizRegNoCtrl.text.trim().isNotEmpty && !_bizRegNoValid
                          ? '올바른 사업자등록번호 형식이 아닙니다 (000-00-00000)'
                          : null,
                ),
              ),
              const SizedBox(height: 16),
              _sectionLabel('담당자 이름 *'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contactNameCtrl,
                maxLength: 30,
                style:
                    const TextStyle(fontSize: 15, color: AppColors.textBody),
                decoration: _inputDecoration('홍길동'),
              ),
              const SizedBox(height: 16),
              _sectionLabel('담당자 연락처 *'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contactPhoneCtrl,
                keyboardType: TextInputType.phone,
                style:
                    const TextStyle(fontSize: 15, color: AppColors.textBody),
                decoration: _inputDecorationWithError(
                  hint: '010-1234-5678',
                  errorText:
                      _contactPhoneCtrl.text.trim().isNotEmpty && !_phoneValid
                          ? '올바른 연락처 형식이 아닙니다 (010-1234-5678)'
                          : null,
                ),
              ),
              const SizedBox(height: 16),
              _sectionLabel('본사 주소'),
              const SizedBox(height: 8),
              _AddressSearchTile(
                address: _headOfficeAddressCtrl.text,
                onTap: _openHeadOfficeAddressSearch,
              ),
              const SizedBox(height: 16),
              _sectionLabel('대표자 이름'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _representativeNameCtrl,
                maxLength: 30,
                style:
                    const TextStyle(fontSize: 15, color: AppColors.textBody),
                decoration: _inputDecoration('김대표'),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _SubmitButton(
        canSubmit: _canSubmit,
        isLoading: _isLoading,
        onTap: _submit,
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
      ),
    );
  }

  Widget _sectionDivider(String title) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
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
    );
  }

  InputDecoration _inputDecorationWithError({
    required String hint,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          const TextStyle(fontSize: 15, color: AppColors.textMuted),
      errorText: errorText,
      errorStyle: const TextStyle(fontSize: 12, color: AppColors.error),
      filled: true,
      fillColor: AppColors.surfaceElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: errorText != null ? AppColors.error : AppColors.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: errorText != null ? AppColors.error : AppColors.primary,
        ),
      ),
    );
  }
}

class _AddressSearchTile extends StatelessWidget {
  final String address;
  final VoidCallback onTap;

  const _AddressSearchTile({
    required this.address,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasAddress = address.trim().isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.location_on_rounded,
              size: 22,
              color: AppColors.primaryBright,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasAddress ? address : '주소를 검색해주세요',
                style: TextStyle(
                  fontSize: 15,
                  color:
                      hasAddress ? AppColors.textBody : AppColors.textMuted,
                ),
              ),
            ),
            const Text(
              '주소 찾기',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBright,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
                foregroundColor: canSubmit
                    ? AppColors.onPrimary
                    : AppColors.textMuted,
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
                      '신청하기',
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

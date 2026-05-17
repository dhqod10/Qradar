import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kpostal/kpostal.dart';
import 'package:qradar/core/constants/menu_categories.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/store_grade.dart';
import 'package:qradar/domain/entities/user_location.dart';
import 'package:qradar/presentation/common/widgets/error_dialog.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/owner/providers/owner_providers.dart';

/// brandKey 형식 검증 정규식 (클라이언트 side — V4).
final _brandKeyRegExp = RegExp(r'^BR-[A-Z2-9]{8}$');

/// 매장 핵심 필드 폼 — 등록 / 수정 / 재제출.
///
/// 다루는 필드: name / address / lat·lng / menuCategories / businessRegistrationNumber.
/// 저장 시 SubmitStoreForApprovalUseCase 호출 → status=pending 회귀 또는 신규 등록.
///
/// [existing] null → 신규 등록.
/// [isResubmit] true → 재제출 모드 (rejected 상태에서 수정 후 재제출).
class StoreCoreFormPage extends ConsumerStatefulWidget {
  final StoreEntity? existing;
  final bool isResubmit;

  const StoreCoreFormPage({
    super.key,
    this.existing,
    this.isResubmit = false,
  });

  @override
  ConsumerState<StoreCoreFormPage> createState() => _StoreCoreFormPageState();
}

class _StoreCoreFormPageState extends ConsumerState<StoreCoreFormPage> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _bizNumCtrl = TextEditingController();
  final _brandKeyCtrl = TextEditingController();

  final _selectedCategories = <String>{};
  UserLocation? _location;
  String? _resolvedAddress;
  bool _submitting = false;
  bool _isBrandFranchise = false;
  String? _brandKeyError;

  bool get _isEdit => widget.existing != null;
  bool get _isResubmit => widget.isResubmit;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _addressCtrl.text = e.address;
      _bizNumCtrl.text = e.businessRegistrationNumber ?? '';
      _selectedCategories.addAll(e.menuCategories);
      _location = e.location;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _bizNumCtrl.dispose();
    _brandKeyCtrl.dispose();
    super.dispose();
  }

  bool get _isValid {
    return _nameCtrl.text.trim().isNotEmpty &&
        _addressCtrl.text.trim().isNotEmpty &&
        _selectedCategories.isNotEmpty &&
        _location != null;
  }

  String get _appBarTitle {
    if (_isResubmit) return '재제출';
    if (_isEdit) return '매장 정보 수정';
    return '매장 등록';
  }

  String get _submitLabel {
    if (_isResubmit) return '재제출하기';
    if (_isEdit) return '검토 요청 보내기';
    return '매장 등록';
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
        title: Text(
          _appBarTitle,
          style: const TextStyle(
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
            // 검수 안내 배너
            _ReviewNoticeBanner(),
            const SizedBox(height: 20),
            // 브랜드 가맹점 섹션 (V3) — 폼 최상단
            SwitchListTile(
              title: const Text(
                '브랜드 가맹점',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHeading,
                ),
              ),
              subtitle: const Text(
                '브랜드 키를 입력하면 가맹점으로 등록됩니다',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              value: _isBrandFranchise,
              onChanged: (val) => setState(() {
                _isBrandFranchise = val;
                if (!val) {
                  _brandKeyCtrl.clear();
                  _brandKeyError = null;
                }
              }),
              activeThumbColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _isBrandFranchise
                  ? _BrandKeyField(
                      controller: _brandKeyCtrl,
                      errorText: _brandKeyError,
                      onChanged: (_) => setState(() => _brandKeyError = null),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 20),
            // 매장명 — 브랜드 매장 ON 시 "지점명" 으로 라벨 변경
            // (예: '강남점' / '역삼점'). 표시 시 'ABCD 강남점' 으로 결합.
            _FormField(
              label: _isBrandFranchise ? '지점명' : '매장명',
              required: true,
              controller: _nameCtrl,
              placeholder: _isBrandFranchise
                  ? '지점명을 입력해주세요 (예: 강남점)'
                  : '매장 이름을 입력해주세요',
              maxLength: 30,
            ),
            const SizedBox(height: 20),
            // 주소 검색
            _AddressSearchTile(
              location: _location,
              resolvedAddress: _resolvedAddress,
              onTap: _openAddressSearch,
            ),
            const SizedBox(height: 8),
            // 주소 텍스트 직접 입력
            _FormField(
              label: '주소',
              required: true,
              controller: _addressCtrl,
              placeholder: '예: 서울시 강남구 테헤란로 1',
            ),
            const SizedBox(height: 20),
            // 카테고리
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
            // 사업자등록번호 (선택)
            _FormField(
              label: '사업자등록번호',
              controller: _bizNumCtrl,
              placeholder: '000-00-00000',
              keyboardType: TextInputType.number,
            ),
            if (!_isValid) ...[
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  '필수 항목을 모두 입력해주세요',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomSheet: _SubmitBar(
        label: _submitLabel,
        enabled: _isValid && !_submitting,
        submitting: _submitting,
        onSubmit: _submit,
      ),
    );
  }

  Future<void> _openAddressSearch() async {
    final result = await Navigator.of(context).push<Kpostal>(
      MaterialPageRoute(
        builder: (_) => KpostalView(
          title: '매장 주소 검색',
          appBarColor: AppColors.background,
          titleColor: AppColors.textHeading,
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

    // brandKey 클라이언트 사이드 형식 검증 (V4)
    if (_isBrandFranchise) {
      final key = _brandKeyCtrl.text.trim();
      if (key.isEmpty) {
        setState(() => _brandKeyError = '브랜드 키를 입력해주세요');
        return;
      }
      if (!_brandKeyRegExp.hasMatch(key)) {
        setState(() => _brandKeyError = '올바른 브랜드 키 형식이 아닙니다');
        return;
      }
    }

    setState(() => _submitting = true);

    final authUser = ref.read(authProvider).asData?.value;
    if (authUser == null) {
      setState(() => _submitting = false);
      return;
    }

    try {
      // brandKey 서버 매칭 (V4)
      String? resolvedBrandId;
      if (_isBrandFranchise) {
        final matched = await ref
            .read(ownerLookupBrandByKeyUseCaseProvider)
            .call(_brandKeyCtrl.text.trim());
        if (!mounted) return;
        if (matched == null) {
          setState(() => _submitting = false);
          if (!mounted) return;
          await showErrorDialog(context, '정상 브랜드 키가 아닙니다. 다시 확인해주세요');
          return;
        }
        resolvedBrandId = matched.id;
      }

      final e = widget.existing;
      final entity = StoreEntity(
        id: e?.id ?? '',
        ownerId: e?.ownerId ?? authUser.uid,
        name: _nameCtrl.text.trim(),
        imageUrl: e?.imageUrl ?? '',
        location: _location!,
        grade: e?.grade ?? StoreGrade.c,
        averageScore: e?.averageScore ?? 0.0,
        reviewCount: e?.reviewCount ?? 0,
        menuCategories: _selectedCategories.toList(growable: false),
        createdAt: e?.createdAt ?? DateTime.now(),
        address: _addressCtrl.text.trim(),
        businessRegistrationNumber: _bizNumCtrl.text.trim().isEmpty
            ? null
            : _bizNumCtrl.text.trim(),
        // 운영 필드는 기존 값 보존
        phone: e?.phone ?? '',
        description: e?.description,
        businessHours: e?.businessHours,
        temporaryClosed: e?.temporaryClosed ?? false,
        closedDates: e?.closedDates ?? const [],
        imageUrls: e?.imageUrls ?? const [],
        notice: e?.notice,
        // brandId: brandKey 매칭 성공 시 박힘, 아니면 기존 값 보존
        brandId: resolvedBrandId ?? e?.brandId,
        // 승인 메타 (status 는 RepositoryImpl 에서 결정)
        status: e?.status ?? EntityApprovalStatus.approved,
        submittedBy: e?.submittedBy,
        submittedAt: e?.submittedAt,
        approvedBy: e?.approvedBy,
        approvedAt: e?.approvedAt,
        rejectedReason: e?.rejectedReason,
      );

      await ref.read(submitStoreForApprovalUseCaseProvider).call(entity);

      if (!mounted) return;
      Navigator.of(context).pop();

      final msg = _isResubmit
          ? '재제출이 완료되었어요'
          : _isEdit
              ? '검토 요청을 보냈어요. 검토 동안 매장은 계속 노출됩니다'
              : '검토 요청을 보냈어요';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.primary.withValues(alpha: 0.9),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      await showErrorDialog(context, '저장에 실패했어요. 다시 시도해주세요');
    }
  }
}

// ── 검수 안내 배너 ─────────────────────────────────────────────────────────

class _ReviewNoticeBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.info.withValues(alpha: 0.3),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: AppColors.info),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '아래 정보는 관리자 검토 후 반영돼요.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.info,
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
  final bool required;
  final TextEditingController controller;
  final String placeholder;
  final int? maxLength;
  final TextInputType? keyboardType;

  const _FormField({
    required this.label,
    required this.controller,
    required this.placeholder,
    this.required = false,
    this.maxLength,
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
                    color: AppColors.textBody,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayText,
                  style: TextStyle(
                    fontSize: 13,
                    color: (hasLoc || hasAddress)
                        ? AppColors.textBody
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
                color: AppColors.textBody,
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
                        : AppColors.textBody,
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

// ── 브랜드 키 입력 필드 (V3) ────────────────────────────��─────────────────

class _BrandKeyField extends StatelessWidget {
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const _BrandKeyField({
    required this.controller,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextFormField(
        controller: controller,
        onChanged: onChanged,
        textCapitalization: TextCapitalization.characters,
        keyboardType: TextInputType.visiblePassword,
        autocorrect: false,
        enableSuggestions: false,
        style: const TextStyle(
          fontSize: 15,
          fontFamily: 'monospace',
          color: AppColors.textHeading,
        ),
        decoration: InputDecoration(
          labelText: '브랜드 키',
          hintText: 'BR-A1B2C3D4',
          prefixIcon: const Icon(
            Icons.vpn_key_rounded,
            color: AppColors.textMuted,
            size: 20,
          ),
          filled: true,
          fillColor: AppColors.surfaceElevated,
          labelStyle: const TextStyle(color: AppColors.textMuted),
          errorText: errorText,
          errorStyle: const TextStyle(
            fontSize: 12,
            color: AppColors.error,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error, width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ── 저장 버튼 ───────────────────────────────────────────────────��─────────

class _SubmitBar extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool submitting;
  final VoidCallback onSubmit;

  const _SubmitBar({
    required this.label,
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
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              disabledBackgroundColor: AppColors.surface,
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
                : Text(
                    label,
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

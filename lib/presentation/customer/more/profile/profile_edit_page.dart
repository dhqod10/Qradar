import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/demographics.dart';
import 'package:qradar/domain/usecases/update_my_display_name_use_case.dart';
import 'package:qradar/presentation/common/widgets/demographics_picker.dart';
import 'package:qradar/presentation/common/widgets/error_dialog.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';

/// 내 정보 화면 — 이름(필수) + 성별·출생연도(선택).
///
/// 이름은 홈 인사말·주문 식별에 쓰이고, 성별·출생연도는 **통계에만** 쓴다.
/// 세 값 모두 `users/{uid}` 한 문서에 저장된다.
class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  late final TextEditingController _controller;
  Gender? _gender;
  int? _birthYear;
  String? _error;
  bool _saving = false;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 프로필이 도착하면 현재 값을 1회만 채운다. 이후 입력 중에는 덮지 않는다
  /// (프로필 스트림이 다시 흘러도 사용자가 고르던 값이 날아가면 안 된다).
  void _seedOnce(String name, Gender? gender, int? birthYear) {
    if (_seeded) return;
    _seeded = true;
    _controller.text = name;
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
    _gender = gender;
    _birthYear = birthYear;
  }

  Future<void> _save() async {
    if (_saving) return;
    final uid = ref.read(currentUserProfileProvider).asData?.value?.uid ?? '';
    if (uid.isEmpty) {
      setState(() => _error = '로그인 정보를 확인할 수 없어요.');
      return;
    }
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '이름을 입력해주세요.');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await ref
          .read(updateMyDisplayNameUseCaseProvider)
          .call(uid: uid, displayName: name);
      // 비어 있어도 호출한다 — 값이 아니라 "물어봤다" 를 남기는 게 목적이다.
      await ref.read(updateMyDemographicsUseCaseProvider).call(
            uid: uid,
            gender: _gender,
            birthYear: _birthYear,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장했어요')),
      );
      Navigator.of(context).pop();
    } on ArgumentError {
      if (!mounted) return;
      setState(() => _error = '이름은 1~$kDisplayNameMaxLength자로 입력해주세요.');
    } catch (e, st) {
      debugPrint('[profile.save] $e\n$st');
      if (!mounted) return;
      await showErrorDialog(context, '저장에 실패했어요. 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    if (profile != null) {
      _seedOnce(profile.displayName ?? '', profile.gender, profile.birthYear);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AppColors.textHeading,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '내 정보',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  const Text(
                    '이름',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHeading,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller,
                    maxLength: kDisplayNameMaxLength,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(kDisplayNameMaxLength),
                    ],
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    decoration: InputDecoration(
                      hintText: '앱에서 보이는 이름이에요',
                      errorText: _error,
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
                      border: _border(AppColors.border),
                      enabledBorder: _border(AppColors.border),
                      focusedBorder: _border(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DemographicsPicker(
                    gender: _gender,
                    birthYear: _birthYear,
                    onGenderChanged: (v) => setState(() => _gender = v),
                    onBirthYearChanged: (v) => setState(() => _birthYear = v),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '성별과 출생연도는 통계 목적으로만 쓰고, 고르지 않아도 모든 기능을 이용할 수 있어요.\n'
                    '출생연도는 연령대로만 집계하며 월·일은 받지 않아요.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SizedBox(
                height: 54,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    disabledBackgroundColor: AppColors.surface,
                    disabledForegroundColor: AppColors.textMuted,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : const Text(
                          '저장',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color),
      );
}

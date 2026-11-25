import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/usecases/update_my_display_name_use_case.dart';
import 'package:qradar/presentation/common/widgets/error_dialog.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';

/// 표시 이름 수정 화면.
///
/// 저장 대상은 `users/{uid}.displayName` 하나다. 홈 인사말·주문 식별이 이 값을 본다.
/// 가입 화면과 **같은 제약**(필수, 최대 [kDisplayNameMaxLength]자)을 쓴다.
class DisplayNameEditPage extends ConsumerStatefulWidget {
  const DisplayNameEditPage({super.key});

  @override
  ConsumerState<DisplayNameEditPage> createState() =>
      _DisplayNameEditPageState();
}

class _DisplayNameEditPageState extends ConsumerState<DisplayNameEditPage> {
  late final TextEditingController _controller;
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

  /// 프로필이 도착하면 현재 이름을 1회만 채운다. 이후 입력 중에는 덮지 않는다
  /// (프로필 스트림이 다시 흘러도 사용자가 타이핑하던 값이 날아가면 안 된다).
  void _seedOnce(String current) {
    if (_seeded) return;
    _seeded = true;
    _controller.text = current;
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름을 변경했어요')),
      );
      Navigator.of(context).pop();
    } on ArgumentError {
      if (!mounted) return;
      setState(() => _error = '이름은 1~$kDisplayNameMaxLength자로 입력해주세요.');
    } catch (_) {
      if (!mounted) return;
      await showErrorDialog(context, '이름 변경에 실패했어요. 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    if (profile != null) {
      _seedOnce(profile.displayName ?? '');
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
          '이름 변경',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '앱에서 보이는 이름이에요',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLength: kDisplayNameMaxLength,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(kDisplayNameMaxLength),
                ],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: InputDecoration(
                  hintText: '이름을 입력해주세요',
                  errorText: _error,
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
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
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
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
            ],
          ),
        ),
      ),
    );
  }
}

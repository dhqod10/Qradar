import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/common/role_router.dart';
import 'package:qradar/presentation/common/widgets/error_dialog.dart';
import 'package:qradar/presentation/customer/auth/auth_error_message.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';

/// 한국 휴대폰 번호 (숫자만 10~11자리).
final RegExp _phonePattern = RegExp(r'^01[016789]\d{7,8}$');

InputDecoration _decoration(String label, {String? hintText, String? errorText}) {
  OutlineInputBorder border(Color? color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: color == null ? const BorderSide() : BorderSide(color: color),
      );
  return InputDecoration(
    labelText: label,
    hintText: hintText,
    errorText: errorText,
    errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
    border: border(null),
    focusedBorder: border(AppColors.primary),
    errorBorder: border(AppColors.error),
    focusedErrorBorder: border(AppColors.error),
  );
}

class EmailSignupPage extends HookConsumerWidget {
  const EmailSignupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController = useTextEditingController();
    final phoneController = useTextEditingController();
    final nameError = useState<String?>(null);
    final phoneError = useState<String?>(null);
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final passwordConfirmController = useTextEditingController();
    final isLoading = useState(false);

    ref.listen(authProvider, (previous, next) {
      next.whenOrNull(
        data: (user) {
          if (user != null) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const RoleRouter()),
              (route) => false,
            );
          }
        },
        error: (e, _) {
          showErrorDialog(context, authFriendlyMessage(e));
        },
      );
    });

    Future<void> onSignUp() async {
      final name = nameController.text.trim();
      final phone = phoneController.text;
      nameError.value = name.isEmpty ? '이름을 입력해주세요.' : null;
      phoneError.value = phone.isEmpty
          ? '전화번호를 입력해주세요.'
          : (_phonePattern.hasMatch(phone)
              ? null
              : '올바른 휴대폰 번호를 입력해주세요. (예: 01012345678)');
      if (nameError.value != null || phoneError.value != null) return;
      if (emailController.text.isEmpty || passwordController.text.isEmpty) {
        await showErrorDialog(context, '이메일과 비밀번호를 입력해주세요.');
        return;
      }
      if (passwordController.text != passwordConfirmController.text) {
        await showErrorDialog(context, '비밀번호가 일치하지 않습니다.');
        return;
      }
      isLoading.value = true;
      await ref.read(authProvider.notifier).signUpWithEmail(
            email: emailController.text.trim(),
            password: passwordController.text,
            name: name,
            phone: phone,
          );
      isLoading.value = false;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textDefault),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '회원가입',
          style: TextStyle(color: AppColors.textDefault, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              enabled: !isLoading.value,
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              inputFormatters: [LengthLimitingTextInputFormatter(20)],
              onChanged: (_) => nameError.value = null,
              decoration: _decoration('이름', errorText: nameError.value),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              enabled: !isLoading.value,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              onChanged: (_) => phoneError.value = null,
              decoration: _decoration(
                '전화번호',
                hintText: '01012345678',
                errorText: phoneError.value,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              enabled: !isLoading.value,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: '이메일',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              enabled: !isLoading.value,
              textInputAction: TextInputAction.next,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '비밀번호 (6자 이상)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordConfirmController,
              enabled: !isLoading.value,
              textInputAction: TextInputAction.done,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '비밀번호 확인',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
              onSubmitted: (_) => onSignUp(),
            ),
            const SizedBox(height: 12),
            const Text(
              '이름과 전화번호는 주문 식별 및 서비스 제공을 위해서만 사용됩니다.',
              maxLines: 2,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: isLoading.value ? null : onSignUp,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.primaryBright,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: isLoading.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          '가입하기',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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
}

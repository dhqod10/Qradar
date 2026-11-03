import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/phone_validator.dart';
import 'package:qradar/presentation/common/widgets/phone_input.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';

/// 결제 직전 전화번호 수집 시트 (existing_user_phone_collection).
///
/// 저장 성공 시 true, 닫기/스와이프 시 null. 결제는 시작하지 않는다 (호출부가 fail-closed 처리).
Future<bool?> showPhoneCollectionSheet(BuildContext context, String uid) {
  return showModalBottomSheet<bool>(
    context: context,
    isDismissible: true,
    enableDrag: false, // 저장 중 드래그로 닫혀 fail-closed 가 흐려지는 것 방지 (닫기는 "나중에 할게요" 버튼)
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => PhoneCollectionSheet(uid: uid),
  );
}

class PhoneCollectionSheet extends ConsumerStatefulWidget {
  const PhoneCollectionSheet({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<PhoneCollectionSheet> createState() =>
      _PhoneCollectionSheetState();
}

class _PhoneCollectionSheetState extends ConsumerState<PhoneCollectionSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _saving = false;
  bool _saveFailed = false;
  bool _touched = false; // 포커스를 잃은 적 있음

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _controller.text.isNotEmpty && !_touched) {
        setState(() => _touched = true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _valid => isValidKoreanMobile(_controller.text);

  String? get _formatError {
    final text = _controller.text;
    if (text.isEmpty || _valid) return null;
    if (_touched || text.length >= kPhoneMaxLength) {
      return '올바른 휴대폰 번호를 입력해주세요. (예: 01012345678)';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await ref
          .read(updateMyPhoneUseCaseProvider)
          .call(uid: widget.uid, phone: _controller.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      // raw 메시지 노출/로그 금지 (PII). 입력 유지 + 인라인 재시도 안내.
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          16 + media.viewPadding.bottom + media.viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '주문 연락처를 입력해 주세요',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHeading,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '픽업 연락을 위해 전화번호가 필요해요. 결제는 아직 시작되지 않았어요.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textBody,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                focusNode: _focus,
                autofocus: true,
                enabled: !_saving,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: phoneInputFormatters(),
                onChanged: (_) => setState(() => _saveFailed = false),
                onSubmitted: (_) => _save(),
                decoration: formFieldDecoration(
                  '전화번호',
                  hintText: '01012345678',
                  errorText: _formatError,
                ),
              ),
              if (_saveFailed) ...[
                const SizedBox(height: 8),
                const Text(
                  '저장에 실패했어요. 다시 시도해 주세요.',
                  style: TextStyle(fontSize: 13, color: AppColors.error),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                '전화번호는 주문 식별 및 픽업 연락을 위해서만 사용됩니다.',
                maxLines: 2,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: (_valid && !_saving) ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? Semantics(
                          label: '저장 중',
                          child: const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimary,
                            ),
                          ),
                        )
                      : const Text(
                          '저장하기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textBody,
                    backgroundColor: AppColors.surfaceElevated,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '나중에 할게요',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

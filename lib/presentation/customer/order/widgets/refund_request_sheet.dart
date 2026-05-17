import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// 환불 요청 결과.
class RefundRequestResult {
  const RefundRequestResult({required this.reason});
  final String reason;
}

/// 환불 요청 사유 입력 바텀 시트.
///
/// [show] 를 통해 호출하며, 확인 시 [RefundRequestResult], 취소 시 null 반환.
class RefundRequestSheet extends StatefulWidget {
  const RefundRequestSheet({super.key});

  static Future<RefundRequestResult?> show(BuildContext context) {
    return showModalBottomSheet<RefundRequestResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const RefundRequestSheet(),
    );
  }

  @override
  State<RefundRequestSheet> createState() => _RefundRequestSheetState();
}

class _RefundRequestSheetState extends State<RefundRequestSheet> {
  static const _reasons = ['주문 실수', '메뉴 변경', '매장 사정', '기타'];

  String? _selected;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '환불 요청',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHeading,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _reasons.map((r) => _chip(r)).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                minLines: 3,
                maxLines: 5,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textBody,
                ),
                decoration: InputDecoration(
                  hintText: '추가 사유를 입력해주세요 (선택)',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
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
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _cancelButton()),
                  const SizedBox(width: 10),
                  Expanded(child: _confirmButton()),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String reason) {
    final selected = _selected == reason;
    return GestureDetector(
      onTap: () => setState(() => _selected = reason),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          reason,
          style: TextStyle(
            fontSize: 13,
            color: selected ? AppColors.onPrimary : AppColors.textBody,
          ),
        ),
      ),
    );
  }

  Widget _cancelButton() {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: () => Navigator.of(context).pop(),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surfaceElevated,
          side: const BorderSide(color: AppColors.border),
          foregroundColor: AppColors.textBody,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text('취소'),
      ),
    );
  }

  Widget _confirmButton() {
    final enabled = _selected != null;
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: enabled
            ? () {
                final extra = _controller.text.trim();
                final reason =
                    extra.isEmpty ? _selected! : '$_selected · $extra';
                Navigator.of(context).pop(RefundRequestResult(reason: reason));
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              enabled ? AppColors.primary : AppColors.surface,
          foregroundColor:
              enabled ? AppColors.onPrimary : AppColors.textMuted,
          disabledBackgroundColor: AppColors.surface,
          disabledForegroundColor: AppColors.textMuted,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text('환불 요청'),
      ),
    );
  }
}

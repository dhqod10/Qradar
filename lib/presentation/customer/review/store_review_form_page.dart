import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/errors/network_unavailable_exception.dart';
import 'package:qradar/core/errors/permission_denied_exception.dart';
import 'package:qradar/core/errors/review_submit_exception.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/qrator_name.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/review_entity.dart';
import 'package:qradar/domain/entities/store_grade.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/review/providers/review_di_providers.dart';
import 'package:qradar/presentation/customer/review/widgets/grade_selector.dart';

/// 저장 성공 결과. 호출한 화면이 스낵바 문구를 결정한다.
enum StoreReviewFormResult { created, updated }

const _maxCommentLength = 300;

/// 매장 평가 작성/수정 겸용 폼.
///
/// [existingReview] 는 `OrderDetailPage` 가 이미 구독 중인 값을 인자로 받는다
/// (폼이 자체 구독하면 첫 프레임에 작성/수정 모드가 바뀌는 깜빡임이 생긴다).
class StoreReviewFormPage extends ConsumerStatefulWidget {
  const StoreReviewFormPage({
    super.key,
    required this.order,
    this.existingReview,
  });

  final OrderEntity order;
  final ReviewEntity? existingReview;

  @override
  ConsumerState<StoreReviewFormPage> createState() =>
      _StoreReviewFormPageState();
}

class _StoreReviewFormPageState extends ConsumerState<StoreReviewFormPage> {
  late final TextEditingController _commentCtrl;
  StoreGrade? _grade;
  bool _submitting = false;
  bool _discard = false;

  bool get _isEdit => widget.existingReview != null;
  String get _initialComment => widget.existingReview?.comment?.trim() ?? '';

  @override
  void initState() {
    super.initState();
    _grade = widget.existingReview?.grade;
    _commentCtrl = TextEditingController(text: _initialComment);
    _commentCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  String get _currentComment => _commentCtrl.text.trim();

  /// 작성: 등급 선택 또는 코멘트 입력됨 / 수정: 기존 값과 다름.
  bool get _isDirty {
    if (_isEdit) {
      return _grade != widget.existingReview!.grade ||
          _currentComment != _initialComment;
    }
    return _grade != null || _currentComment.isNotEmpty;
  }

  /// 작성: 등급 선택 시 활성 / 수정: 변경 있을 때만 활성.
  bool get _canSubmit => _grade != null && (!_isEdit || _isDirty);

  Future<void> _submit() async {
    final grade = _grade;
    final uid = ref.read(authProvider).asData?.value?.uid;
    if (grade == null || uid == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ref.read(submitStoreReviewUseCaseProvider)(
        storeId: widget.order.storeId,
        userId: uid,
        order: widget.order,
        grade: grade,
        comment: _currentComment,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        _isEdit ? StoreReviewFormResult.updated : StoreReviewFormResult.created,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(e))));
    }
  }

  String _errorMessage(Object e) {
    if (e is ReviewSubmitException) {
      return e.reason == ReviewSubmitFailure.windowExpired
          ? '평가 기간이 지나 저장할 수 없어요'
          : '이 주문으로는 평가할 수 없어요';
    }
    if (e is PermissionDeniedException) return '이 주문으로는 평가할 수 없어요';
    if (e is NetworkUnavailableException) return '네트워크 연결을 확인해 주세요';
    return '평가를 저장하지 못했어요. 잠시 후 다시 시도해 주세요';
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => const _LeaveDialog(),
    );
    if (leave != true || !mounted) return;
    setState(() => _discard = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authProvider).asData?.value?.uid ?? '';
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: _discard || (!_submitting && !_isDirty),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _submitting) return;
        _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: Text(
            _isEdit ? '평가 수정' : '매장 평가',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          iconTheme: const IconThemeData(color: AppColors.textHeading),
        ),
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '이 매장에 대한 내 평가',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.order.storeName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textHeading,
                ),
              ),
              const SizedBox(height: 16),
              if (_isEdit &&
                  widget.existingReview!.orderId != widget.order.id) ...[
                const _PreviousReviewNotice(),
                const SizedBox(height: 16),
              ],
              const Text(
                '음료·서비스·분위기를 종합해서 골라주세요',
                style: TextStyle(fontSize: 13, color: AppColors.textBody),
              ),
              const SizedBox(height: 12),
              GradeSelector(
                selected: _grade,
                enabled: !_submitting,
                onChanged: (g) => setState(() => _grade = g),
              ),
              const SizedBox(height: 28),
              const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '한마디 남기기',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHeading,
                      ),
                    ),
                    TextSpan(
                      text: ' (선택)',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _CommentField(controller: _commentCtrl, enabled: !_submitting),
              const SizedBox(height: 16),
              Text(
                '솔직한 평가가 다른 Qrator 에게 가장 도움이 돼요\n'
                "평가는 '${maskedQratorName(uid)}' 로 익명 공개되며, 매장 점주도 볼 수 있어요",
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomSafe),
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Semantics(
            button: true,
            enabled: _canSubmit,
            hint: (!_isEdit && _grade == null) ? '등급을 먼저 선택해 주세요' : null,
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_canSubmit && !_submitting) ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  disabledBackgroundColor: _submitting
                      ? AppColors.primary
                      : AppColors.surface,
                  disabledForegroundColor: AppColors.textMuted,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : Text(
                        _isEdit ? '수정 완료' : '평가 등록',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviousReviewNotice extends StatelessWidget {
  const _PreviousReviewNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: AppColors.info),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '이전에 남긴 평가가 있어요. 저장하면 이번 주문 기준으로 바뀌어요',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentField extends StatelessWidget {
  const _CommentField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final length = controller.text.length;
    final nearLimit = length >= 280;
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Semantics(
          label: '한마디 남기기, 선택 입력, 최대 300자',
          child: TextField(
            controller: controller,
            enabled: enabled,
            minLines: 4,
            maxLines: 6,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [
              LengthLimitingTextInputFormatter(_maxCommentLength),
            ],
            cursorColor: AppColors.primary,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textBody,
            ),
            decoration: InputDecoration(
              hintText: '방문하면서 느낀 점을 자유롭게 남겨주세요',
              hintStyle: const TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
              filled: true,
              fillColor: AppColors.surfaceElevated,
              contentPadding: const EdgeInsets.all(14),
              enabledBorder: border(AppColors.border, 1),
              disabledBorder: border(AppColors.border, 1),
              focusedBorder: border(AppColors.primary, 1.5),
            ),
          ),
        ),
        const SizedBox(height: 6),
        ExcludeSemantics(
          child: Text(
            '$length/$_maxCommentLength',
            style: TextStyle(
              fontSize: 12,
              fontWeight: nearLimit ? FontWeight.w600 : FontWeight.w400,
              color: nearLimit ? AppColors.textHeading : AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _LeaveDialog extends StatelessWidget {
  const _LeaveDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        '작성 중인 평가를 그만둘까요?',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textHeading,
        ),
      ),
      content: const Text(
        '나가면 입력한 내용이 사라져요',
        style: TextStyle(fontSize: 14, color: AppColors.textBody),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.surfaceElevated,
                    foregroundColor: AppColors.textBody,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('계속 작성'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('나가기'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

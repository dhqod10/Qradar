import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/errors/support_inquiry_exception.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/support_inquiry_category.dart';
import 'package:qradar/domain/entities/support_inquiry_entity.dart';
import 'package:qradar/domain/repositories/support_inquiry_repository.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/support/providers/support_inquiry_di_providers.dart';

/// 내 문의 목록 스트림 (최신순 50). 비로그인 → `[]`.
final myInquiriesProvider =
    StreamProvider.autoDispose<List<SupportInquiryEntity>>((ref) {
      final uid = ref.watch(authProvider).asData?.value?.uid;
      if (uid == null) {
        return Stream<List<SupportInquiryEntity>>.value(
          const <SupportInquiryEntity>[],
        );
      }
      return ref.watch(watchMySupportInquiriesUseCaseProvider).call(uid);
    });

/// 문의 단건 스트림.
final inquiryDetailProvider = StreamProvider.autoDispose
    .family<SupportInquiryEntity?, String>((ref, inquiryId) {
      return ref.watch(watchSupportInquiryUseCaseProvider).call(inquiryId);
    });

/// 더보기 dot 용 미확인 답변 수. 목록 로딩/에러 시 0 (fail-quiet — 실패가 타일을 깨지 않는다).
/// 판정은 [SupportInquiryEntity.hasUnreadAnswer] 한 곳.
final unreadInquiryAnswerCountProvider = Provider.autoDispose<int>((ref) {
  final list = ref.watch(myInquiriesProvider).asData?.value;
  if (list == null) return 0;
  return list.where((e) => e.hasUnreadAnswer).length;
});

// ── 작성 폼 ──────────────────────────────────────────────────────────────────

enum InquiryFormPhase { idle, uploading, sending }

/// 연결 주문 요약 (표시용). 서버가 `orders/{id}` 로 소유를 재검증하고 스냅샷을 박제한다.
@immutable
class LinkedOrder {
  const LinkedOrder({
    required this.id,
    required this.storeName,
    this.pickupNumber,
    required this.totalPrice,
    required this.createdAt,
  });

  factory LinkedOrder.fromOrder(OrderEntity o) => LinkedOrder(
    id: o.id,
    storeName: o.storeName,
    pickupNumber: o.pickupNumber,
    totalPrice: o.totalPrice,
    createdAt: o.createdAt,
  );

  final String id;
  final String storeName;
  final int? pickupNumber;
  final int totalPrice;
  final DateTime createdAt;
}

@immutable
class InquiryFormState {
  const InquiryFormState({
    this.category,
    this.order,
    this.files = const <File>[],
    this.phase = InquiryFormPhase.idle,
    this.uploadedCount = 0,
    this.uploadFailed = false,
    this.failure,
  });

  final SupportInquiryCategory? category;
  final LinkedOrder? order;
  final List<File> files;
  final InquiryFormPhase phase;

  /// 업로드 완료 장수 (진행 표시용).
  final int uploadedCount;

  /// 직전 제출에서 첨부 업로드가 실패했다.
  final bool uploadFailed;

  /// 직전 제출의 실패 사유 (화면이 문구로 매핑). null = 없음.
  final SupportInquiryFailure? failure;

  bool get busy => phase != InquiryFormPhase.idle;

  InquiryFormState copyWith({
    Object? category = _keep,
    Object? order = _keep,
    List<File>? files,
    InquiryFormPhase? phase,
    int? uploadedCount,
    bool? uploadFailed,
    Object? failure = _keep,
  }) => InquiryFormState(
    category: identical(category, _keep)
        ? this.category
        : category as SupportInquiryCategory?,
    order: identical(order, _keep) ? this.order : order as LinkedOrder?,
    files: files ?? this.files,
    phase: phase ?? this.phase,
    uploadedCount: uploadedCount ?? this.uploadedCount,
    uploadFailed: uploadFailed ?? this.uploadFailed,
    failure: identical(failure, _keep)
        ? this.failure
        : failure as SupportInquiryFailure?,
  );
}

const Object _keep = Object();

/// 문의 작성 컨트롤러. 제목·본문 텍스트는 화면의 TextEditingController 가 갖고, 제출 시 인자로 받는다.
class InquiryFormController extends Notifier<InquiryFormState> {
  /// 문서 ID 는 폼 생성 시 1회 확정 — 재시도해도 같은 ID(CF 멱등).
  late final String _inquiryId;

  @override
  InquiryFormState build() {
    _inquiryId = ref.read(supportInquiryRepositoryProvider).newInquiryId();
    return const InquiryFormState();
  }

  void setCategory(SupportInquiryCategory c) =>
      state = state.copyWith(category: c, failure: null);

  void setOrder(LinkedOrder? o) =>
      state = state.copyWith(order: o, failure: null);

  void addFiles(List<File> added) {
    if (added.isEmpty) return;
    final next = [...state.files, ...added].take(3).toList(growable: false);
    state = state.copyWith(files: next, uploadFailed: false, failure: null);
  }

  void removeFileAt(int index) {
    if (state.busy || index < 0 || index >= state.files.length) return;
    final next = [...state.files]..removeAt(index);
    state = state.copyWith(files: next, uploadFailed: false);
  }

  void clearFiles() =>
      state = state.copyWith(files: const <File>[], uploadFailed: false);

  void clearFailure() {
    if (state.failure != null) state = state.copyWith(failure: null);
  }

  /// 제출. 성공 시 inquiryId, 실패 시 null (사유는 [InquiryFormState.failure] / [InquiryFormState.uploadFailed]).
  Future<String?> submit({required String title, required String body}) async {
    if (state.busy) return null; // 중복 탭 차단
    final uid = ref.read(authProvider).asData?.value?.uid;
    final category = state.category;
    if (uid == null) {
      state = state.copyWith(failure: SupportInquiryFailure.unauthenticated);
      return null;
    }
    if (category == null) return null;

    state = state.copyWith(
      phase: state.files.isEmpty
          ? InquiryFormPhase.sending
          : InquiryFormPhase.uploading,
      uploadedCount: 0,
      uploadFailed: false,
      failure: null,
    );

    var urls = const <String>[];
    try {
      if (state.files.isNotEmpty) {
        urls = await ref
            .read(uploadSupportInquiryImagesUseCaseProvider)
            .call(
              userId: uid,
              inquiryId: _inquiryId,
              files: state.files,
              onProgress: (done, total) =>
                  state = state.copyWith(uploadedCount: done),
            );
      }
      state = state.copyWith(phase: InquiryFormPhase.sending);
      await ref
          .read(createSupportInquiryUseCaseProvider)
          .call(
            CreateSupportInquiryInput(
              inquiryId: _inquiryId,
              category: category,
              title: title,
              body: body,
              imageUrls: urls,
              orderId: state.order?.id,
              platform: _platform(),
            ),
          );
      state = state.copyWith(phase: InquiryFormPhase.idle);
      return _inquiryId;
    } on SupportInquiryException catch (e) {
      final repo = ref.read(supportInquiryRepositoryProvider);
      if (e.reason == SupportInquiryFailure.imageUploadFailed) {
        state = state.copyWith(
          phase: InquiryFormPhase.idle,
          uploadFailed: true,
        );
        return null;
      }
      // 서버가 **확정 거절**한 경우에만 올라간 첨부를 best-effort 정리한다.
      // 네트워크 단절·알 수 없는 실패는 서버가 이미 생성했을 수 있어(응답만 유실) 지우면 문서가 깨진 URL 을 가리킨다.
      if (urls.isNotEmpty && _definitiveRejection(e.reason)) {
        await repo.discardImages(urls);
      }
      state = state.copyWith(
        phase: InquiryFormPhase.idle,
        failure: e.reason,
        files: e.reason == SupportInquiryFailure.invalidAttachment
            ? const <File>[]
            : null,
        order: e.reason == SupportInquiryFailure.orderNotFound ? null : _keep,
      );
      return null;
    } catch (_) {
      state = state.copyWith(
        phase: InquiryFormPhase.idle,
        failure: SupportInquiryFailure.failed,
      );
      return null;
    }
  }

  static bool _definitiveRejection(SupportInquiryFailure f) =>
      f == SupportInquiryFailure.rateLimited ||
      f == SupportInquiryFailure.invalidInput ||
      f == SupportInquiryFailure.invalidAttachment ||
      f == SupportInquiryFailure.orderNotFound ||
      f == SupportInquiryFailure.accountDeleted;

  static String? _platform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return null;
    }
  }
}

final inquiryFormControllerProvider =
    NotifierProvider.autoDispose<InquiryFormController, InquiryFormState>(
      InquiryFormController.new,
    );

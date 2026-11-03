import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/errors/account_deletion_exception.dart';
import 'package:qradar/data/datasources/remote/account_deletion_remote_data_source.dart';
import 'package:qradar/data/repositories/account_deletion_repository_impl.dart';
import 'package:qradar/domain/entities/account_deletion_preview.dart';
import 'package:qradar/domain/repositories/account_deletion_repository.dart';
import 'package:qradar/domain/usecases/delete_my_account_use_case.dart';
import 'package:qradar/domain/usecases/preview_account_deletion_use_case.dart';
import 'package:qradar/presentation/brand/providers/brand_info_providers.dart'
    show readNoAutoRetry;

// ── Repository / UseCase ───────────────────────────────────────────────────

final accountDeletionRepositoryProvider = Provider<AccountDeletionRepository>((
  ref,
) {
  return AccountDeletionRepositoryImpl(AccountDeletionRemoteDataSource());
});

final previewAccountDeletionUseCaseProvider =
    Provider<PreviewAccountDeletionUseCase>((ref) {
      return PreviewAccountDeletionUseCase(
        ref.watch(accountDeletionRepositoryProvider),
      );
    });

final deleteMyAccountUseCaseProvider = Provider<DeleteMyAccountUseCase>((ref) {
  return DeleteMyAccountUseCase(ref.watch(accountDeletionRepositoryProvider));
});

// ── 미리보기 (dryRun) ──────────────────────────────────────────────────────

/// 실패는 `error` 이고 화면은 탈퇴 UI 를 숨긴다 (fail-closed). 다시 시도 = `ref.invalidate`.
final accountDeletionPreviewProvider =
    FutureProvider.autoDispose<AccountDeletionPreview>((ref) {
      return ref.read(previewAccountDeletionUseCaseProvider).call();
    }, retry: readNoAutoRetry);

// ── 실행 상태 ──────────────────────────────────────────────────────────────

enum AccountDeletionStatus {
  idle,
  processing,
  failed,
  failedUnauthenticated,

  /// 실행 시 서버 재검증에서 진행 중 주문이 발견됨 (미리보기 이후 새 주문).
  blockedInFlight,
}

class AccountDeletionState {
  const AccountDeletionState({
    this.status = AccountDeletionStatus.idle,
    this.blockedCount,
  });
  final AccountDeletionStatus status;

  /// `blockedInFlight` 일 때 서버가 알려준 건수 (모르면 null).
  final int? blockedCount;

  bool get isProcessing => status == AccountDeletionStatus.processing;
}

class AccountDeletionController extends Notifier<AccountDeletionState> {
  @override
  AccountDeletionState build() => const AccountDeletionState();

  /// 탈퇴 실행. 성공이면 true (호출자가 signOut 으로 세션을 정리한다). 실패는 상태로 표현하고 false.
  /// 중복 탭 방지: 처리 중이면 즉시 false.
  Future<bool> submit() async {
    if (state.isProcessing) return false;
    state = const AccountDeletionState(
      status: AccountDeletionStatus.processing,
    );
    try {
      await ref.read(deleteMyAccountUseCaseProvider).call();
      return true;
    } on AccountDeletionException catch (e) {
      state = switch (e.kind) {
        AccountDeletionFailure.inFlightOrders => AccountDeletionState(
          status: AccountDeletionStatus.blockedInFlight,
          blockedCount: e.inFlightOrders,
        ),
        AccountDeletionFailure.unauthenticated => const AccountDeletionState(
          status: AccountDeletionStatus.failedUnauthenticated,
        ),
        AccountDeletionFailure.failed => const AccountDeletionState(
          status: AccountDeletionStatus.failed,
        ),
      };
      return false;
    } catch (_) {
      state = const AccountDeletionState(status: AccountDeletionStatus.failed);
      return false;
    }
  }
}

final accountDeletionControllerProvider =
    NotifierProvider.autoDispose<
      AccountDeletionController,
      AccountDeletionState
    >(AccountDeletionController.new);

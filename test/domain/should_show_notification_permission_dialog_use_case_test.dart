import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/domain/entities/notification_permission_prompt_state.dart';
import 'package:qradar/domain/entities/notification_permission_status.dart';
import 'package:qradar/domain/repositories/user_repository.dart';
import 'package:qradar/domain/usecases/should_show_notification_permission_dialog_use_case.dart';

class _FakeUserRepository extends Fake implements UserRepository {
  _FakeUserRepository(this.state, {this.throws = false});

  final NotificationPermissionPromptState state;
  final bool throws;
  int reads = 0;

  @override
  Future<NotificationPermissionPromptState>
  getNotificationPermissionPromptState(String uid) async {
    reads++;
    if (throws) throw StateError('boom');
    return state;
  }
}

void main() {
  const promptable = NotificationPermissionPromptState(laterCount: 1);
  const exhaustedLater = NotificationPermissionPromptState(laterCount: 3);
  const prompted = NotificationPermissionPromptState(prompted: true);

  Future<bool> run(
    NotificationPermissionPromptState state,
    NotificationPermissionStatus os,
  ) {
    return ShouldShowNotificationPermissionDialogUseCase(
      userRepo: _FakeUserRepository(state),
    ).call(uid: 'u', osStatus: os);
  }

  group('osStatus x state', () {
    // authorized / provisional -> 항상 false
    for (final os in [
      NotificationPermissionStatus.authorized,
      NotificationPermissionStatus.provisional,
    ]) {
      test('$os blocks regardless of state', () async {
        expect(await run(promptable, os), false);
      });
    }

    // denied / notDetermined -> state.canPromptAgain 에 따름
    // (Android 는 notDetermined 를 반환하지 않으므로 denied 에서도 노출되어야 한다)
    for (final os in [
      NotificationPermissionStatus.denied,
      NotificationPermissionStatus.notDetermined,
    ]) {
      test('$os + promptable -> true', () async {
        expect(await run(promptable, os), true);
      });
      test('$os + default state -> true', () async {
        expect(await run(const NotificationPermissionPromptState(), os), true);
      });
      test('$os + laterCount exhausted -> false', () async {
        expect(await run(exhaustedLater, os), false);
      });
      test('$os + prompted -> false', () async {
        expect(await run(prompted, os), false);
      });
    }
  });

  test('authorized skips Firestore read', () async {
    final repo = _FakeUserRepository(promptable);
    await ShouldShowNotificationPermissionDialogUseCase(
      userRepo: repo,
    ).call(uid: 'u', osStatus: NotificationPermissionStatus.authorized);
    expect(repo.reads, 0);
  });

  test('repository exception propagates', () async {
    final uc = ShouldShowNotificationPermissionDialogUseCase(
      userRepo: _FakeUserRepository(promptable, throws: true),
    );
    expect(
      () => uc.call(uid: 'u', osStatus: NotificationPermissionStatus.denied),
      throwsStateError,
    );
  });
}

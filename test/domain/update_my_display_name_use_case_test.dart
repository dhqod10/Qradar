import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/domain/entities/notification_category.dart';
import 'package:qradar/domain/entities/notification_permission_prompt_state.dart';
import 'package:qradar/domain/entities/user_entity.dart';
import 'package:qradar/domain/entities/user_role.dart';
import 'package:qradar/domain/repositories/user_repository.dart';
import 'package:qradar/domain/usecases/update_my_display_name_use_case.dart';

/// 저장 호출만 기록하는 스파이. 다른 메서드는 이 테스트가 건드리지 않는다.
class _SpyRepo implements UserRepository {
  int calls = 0;
  String? savedUid;
  String? savedName;

  @override
  Future<void> updateMyDisplayName({
    required String uid,
    required String displayName,
  }) async {
    calls++;
    savedUid = uid;
    savedName = displayName;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('이 테스트가 쓰지 않는 경로: ${invocation.memberName}');

  // ── 아래는 인터페이스 충족용 (호출되면 noSuchMethod 로 가지 않으므로 직접 던진다) ──
  @override
  Future<UserEntity> getOrCreateUserProfile(UserEntity authUser) =>
      throw UnimplementedError();
  @override
  Future<void> updateRole({required String uid, required UserRole role}) =>
      throw UnimplementedError();
  @override
  Stream<UserEntity?> watchCurrent(String uid) => throw UnimplementedError();
  @override
  Future<void> updateFcmToken(String uid, String? token) =>
      throw UnimplementedError();
  @override
  Future<void> markNotificationPermissionPrompted(String uid) =>
      throw UnimplementedError();
  @override
  Future<NotificationPermissionPromptState>
      getNotificationPermissionPromptState(String uid) =>
          throw UnimplementedError();
  @override
  Future<void> incrementNotificationPermissionLaterCount(String uid) =>
      throw UnimplementedError();
  @override
  Future<void> updateNotificationSetting({
    required String uid,
    required NotificationCategory category,
    required bool enabled,
  }) =>
      throw UnimplementedError();
  @override
  Future<void> updateMyPhone({required String uid, required String phone}) =>
      throw UnimplementedError();
}

void main() {
  group('UpdateMyDisplayNameUseCase', () {
    late _SpyRepo repo;
    late UpdateMyDisplayNameUseCase useCase;

    setUp(() {
      repo = _SpyRepo();
      useCase = UpdateMyDisplayNameUseCase(repo);
    });

    test('앞뒤 공백을 떼고 저장한다', () async {
      await useCase.call(uid: 'u1', displayName: '  김큐레이터  ');
      expect(repo.calls, 1);
      expect(repo.savedUid, 'u1');
      expect(repo.savedName, '김큐레이터');
    });

    test('빈 값은 저장하지 않는다 (공백만 입력도 빈 값이다)', () async {
      expect(
        () => useCase.call(uid: 'u1', displayName: '   '),
        throwsArgumentError,
      );
      expect(repo.calls, 0, reason: '검증 실패 시 저장을 호출하지 않는다');
    });

    test('최대 길이까지는 통과하고, 넘으면 저장하지 않는다', () async {
      final exact = 'ㄱ' * kDisplayNameMaxLength;
      await useCase.call(uid: 'u1', displayName: exact);
      expect(repo.savedName, exact);

      expect(
        () => useCase.call(uid: 'u1', displayName: 'ㄱ' * (kDisplayNameMaxLength + 1)),
        throwsArgumentError,
      );
      expect(repo.calls, 1, reason: '초과분은 저장되지 않는다');
    });

    test('길이는 공백을 뗀 뒤 센다 — 양끝 공백 때문에 거부되지 않는다', () async {
      await useCase.call(
        uid: 'u1',
        displayName: '  ${'ㄱ' * kDisplayNameMaxLength}  ',
      );
      expect(repo.calls, 1);
    });

    test('에러 메시지에 입력한 이름을 넣지 않는다 (로그 유출 방지)', () {
      try {
        useCase.call(uid: 'u1', displayName: 'ㄱ' * 50);
        fail('ArgumentError 가 나야 한다');
      } on ArgumentError catch (e) {
        expect(e.toString().contains('ㄱ'), isFalse);
      }
    });
  });
}

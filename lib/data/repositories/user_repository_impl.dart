import 'package:qradar/data/datasources/remote/user_remote_data_source.dart';
import 'package:qradar/data/models/user_model.dart';
import 'package:qradar/domain/entities/notification_category.dart';
import 'package:qradar/domain/entities/notification_permission_prompt_state.dart';
import 'package:qradar/domain/entities/user_entity.dart';
import 'package:qradar/domain/entities/user_role.dart';
import 'package:qradar/domain/repositories/user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource _dataSource;

  UserRepositoryImpl(this._dataSource);

  @override
  Future<UserEntity> getOrCreateUserProfile(UserEntity authUser) async {
    final existing = await _dataSource.fetch(authUser.uid);
    if (existing != null) {
      // 프로필 없이 만들어진 기존 문서 보강: 문서 값이 비어 있고 로그인 응답에 값이 있을 때만
      // displayName/photoUrl 을 채운다 (이미 값이 있으면 덮지 않음, role/brandId 등 불변).
      final fillName = _isBlank(existing.displayName) && !_isBlank(authUser.displayName)
          ? authUser.displayName
          : null;
      final fillPhoto = _isBlank(existing.photoUrl) && !_isBlank(authUser.photoUrl)
          ? authUser.photoUrl
          : null;
      if (fillName == null && fillPhoto == null) return existing.toEntity();
      try {
        await _dataSource.fillProfile(
          uid: authUser.uid,
          displayName: fillName,
          photoUrl: fillPhoto,
        );
        final reloaded = await _dataSource.fetch(authUser.uid);
        return (reloaded ?? existing).toEntity();
      } catch (_) {
        // 프로필 보강 실패가 로그인/프로필 로딩을 막지 않는다.
        return existing.toEntity();
      }
    }

    final model = UserModelFactory.fromEntity(authUser);
    await _dataSource.createIfAbsent(model);
    final reloaded = await _dataSource.fetch(authUser.uid);
    return (reloaded ?? model).toEntity();
  }

  static bool _isBlank(String? v) => v == null || v.isEmpty;

  @override
  Future<void> updateRole({required String uid, required UserRole role}) {
    return _dataSource.updateRole(uid: uid, role: role.asString);
  }

  @override
  Stream<UserEntity?> watchCurrent(String uid) {
    return _dataSource.watch(uid).map((model) => model?.toEntity());
  }

  // ── FCM 토큰 관련 (Phase 3b) ──────────────────────────────────────────────

  @override
  Future<void> updateFcmToken(String uid, String? token) =>
      _dataSource.updateFcmToken(uid, token);

  @override
  Future<void> markNotificationPermissionPrompted(String uid) =>
      _dataSource.markNotificationPermissionPrompted(uid);

  @override
  Future<NotificationPermissionPromptState>
  getNotificationPermissionPromptState(String uid) =>
      _dataSource.getNotificationPermissionPromptState(uid);

  @override
  Future<void> incrementNotificationPermissionLaterCount(String uid) =>
      _dataSource.incrementNotificationPermissionLaterCount(uid);

  @override
  Future<void> updateNotificationSetting({
    required String uid,
    required NotificationCategory category,
    required bool enabled,
  }) =>
      _dataSource.updateNotificationSetting(
        uid: uid,
        key: category.asString,
        enabled: enabled,
      );

  @override
  Future<void> updateMyPhone({required String uid, required String phone}) =>
      _dataSource.updateMyPhone(uid: uid, phone: phone);
}

import 'package:qradar/data/datasources/remote/user_remote_data_source.dart';
import 'package:qradar/data/models/user_model.dart';
import 'package:qradar/domain/entities/user_entity.dart';
import 'package:qradar/domain/entities/user_role.dart';
import 'package:qradar/domain/repositories/user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource _dataSource;

  UserRepositoryImpl(this._dataSource);

  @override
  Future<UserEntity> getOrCreateUserProfile(UserEntity authUser) async {
    final existing = await _dataSource.fetch(authUser.uid);
    if (existing != null) return existing.toEntity();

    final model = UserModelFactory.fromEntity(authUser);
    await _dataSource.createIfAbsent(model);
    final reloaded = await _dataSource.fetch(authUser.uid);
    return (reloaded ?? model).toEntity();
  }

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
  Future<bool> getNotificationPermissionPrompted(String uid) =>
      _dataSource.getNotificationPermissionPrompted(uid);
}

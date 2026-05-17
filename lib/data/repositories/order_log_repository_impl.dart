import 'package:qradar/core/errors/unauthenticated_exception.dart';
import 'package:qradar/data/datasources/remote/order_log_remote_data_source.dart';
import 'package:qradar/data/models/order_log_model.dart';
import 'package:qradar/domain/entities/order_log_entity.dart';
import 'package:qradar/domain/repositories/order_log_repository.dart';

/// 주문 로그 Repository 구현체.
///
/// uid 획득은 생성자에 주입받은 [_currentUidGetter] callback 으로 한다.
/// 카카오/네이버 prefix uid 호환을 위해 Presentation `authProvider` 의 uid 를 그대로 사용한다.
///
/// 알고리즘:
/// - [appendLog]: uid null → [UnauthenticatedException]
/// - [watchUserLogs]: 인자 uid 가 들어오지만 안전성을 위해 [_currentUidGetter] 검증 후
///   현재 사용자 본인일 때만 stream 을 노출한다 (Phase 1c 와 동일 패턴).
class OrderLogRepositoryImpl implements OrderLogRepository {
  final OrderLogRemoteDataSource _ds;
  final String? Function() _currentUidGetter;

  OrderLogRepositoryImpl(this._ds, this._currentUidGetter);

  @override
  Future<void> appendLog(OrderLogEntity log) async {
    final uid = _currentUidGetter();
    if (uid == null) throw const UnauthenticatedException();
    await _ds.appendLog(uid, OrderLogModel.fromEntity(log));
  }

  @override
  Stream<List<OrderLogEntity>> watchUserLogs(String userId) {
    final currentUid = _currentUidGetter();
    if (currentUid == null) {
      return Stream<List<OrderLogEntity>>.value(const <OrderLogEntity>[]);
    }
    return _ds
        .watchUserLogs(userId)
        .map((models) =>
            models.map((m) => m.toEntity()).toList(growable: false));
  }
}

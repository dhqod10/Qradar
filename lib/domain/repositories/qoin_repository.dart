import 'package:qradar/domain/entities/qoin_config_entity.dart';
import 'package:qradar/domain/entities/qoin_transaction_entity.dart';

/// Qoin 조회 Repository. **쓰기 메서드 없음** — 원장은 Cloud Function 전용.
///
/// 잔액은 `UserEntity.qoinBalance` (currentUserProfileProvider) 에서 온다.
/// 별도 잔액 구독을 만들지 않는다.
abstract class QoinRepository {
  /// 본인 내역, createdAt 내림차순. 상한 [limit].
  Stream<List<QoinTransactionEntity>> watchTransactions(
    String uid, {
    required int limit,
  });

  /// `config/qoin`. 문서 없으면 null emit.
  Stream<QoinConfigEntity?> watchConfig();
}

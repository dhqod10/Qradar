import 'package:qradar/domain/entities/qoin_transaction_entity.dart';
import 'package:qradar/domain/repositories/qoin_repository.dart';

class WatchQoinTransactionsUseCase {
  final QoinRepository _repo;
  const WatchQoinTransactionsUseCase(this._repo);

  Stream<List<QoinTransactionEntity>> call(String uid, {required int limit}) =>
      _repo.watchTransactions(uid, limit: limit);
}

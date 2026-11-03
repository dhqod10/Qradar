import 'package:qradar/data/datasources/remote/account_deletion_remote_data_source.dart';
import 'package:qradar/domain/entities/account_deletion_preview.dart';
import 'package:qradar/domain/repositories/account_deletion_repository.dart';

/// [AccountDeletionRepository] 구현 — `deleteMyAccount` callable 위임.
class AccountDeletionRepositoryImpl implements AccountDeletionRepository {
  AccountDeletionRepositoryImpl(this._dataSource);
  final AccountDeletionRemoteDataSource _dataSource;

  @override
  Future<AccountDeletionPreview> preview() => _dataSource.preview();

  @override
  Future<AccountDeletionResult> deleteMyAccount({String reason = ''}) =>
      _dataSource.deleteMyAccount(reason: reason);
}

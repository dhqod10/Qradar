import 'package:qradar/data/datasources/remote/app_config_remote_data_source.dart';
import 'package:qradar/domain/repositories/app_config_repository.dart';

class AppConfigRepositoryImpl implements AppConfigRepository {
  AppConfigRepositoryImpl(this._ds);
  final AppConfigRemoteDataSource _ds;

  @override
  Future<int?> fetchMinClientLevel() => _ds.fetchMinClientLevel();
}

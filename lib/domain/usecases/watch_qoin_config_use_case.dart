import 'package:qradar/domain/entities/qoin_config_entity.dart';
import 'package:qradar/domain/repositories/qoin_repository.dart';

class WatchQoinConfigUseCase {
  final QoinRepository _repo;
  const WatchQoinConfigUseCase(this._repo);

  Stream<QoinConfigEntity?> call() => _repo.watchConfig();
}

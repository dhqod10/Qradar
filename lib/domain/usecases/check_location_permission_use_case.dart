import 'package:qradar/domain/entities/location_permission_status.dart';
import 'package:qradar/domain/repositories/location_repository.dart';

class CheckLocationPermissionUseCase {
  final LocationRepository _repository;
  CheckLocationPermissionUseCase(this._repository);

  Future<LocationPermissionStatus> call() => _repository.getPermissionStatus();
}

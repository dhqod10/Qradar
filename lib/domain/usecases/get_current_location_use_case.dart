import 'package:qradar/domain/entities/user_location.dart';
import 'package:qradar/domain/repositories/location_repository.dart';

class GetCurrentLocationUseCase {
  final LocationRepository _repository;
  GetCurrentLocationUseCase(this._repository);

  Future<UserLocation> call() => _repository.getCurrentLocation();
}

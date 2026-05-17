import 'package:geolocator/geolocator.dart';
import 'package:qradar/core/constants/grade_thresholds.dart';
import 'package:qradar/data/datasources/remote/location_data_source.dart';
import 'package:qradar/domain/entities/location_permission_status.dart';
import 'package:qradar/domain/entities/user_location.dart';
import 'package:qradar/domain/repositories/location_repository.dart';

class LocationRepositoryImpl implements LocationRepository {
  final LocationDataSource _dataSource;

  LocationRepositoryImpl(this._dataSource);

  static const UserLocation _fallback = UserLocation(
    latitude: GradeThresholds.defaultLatitude,
    longitude: GradeThresholds.defaultLongitude,
    isFallback: true,
  );

  @override
  Future<UserLocation> getCurrentLocation() async {
    final position = await _dataSource.getCurrentPosition();
    if (position == null) return _fallback;
    return UserLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  @override
  Future<bool> requestPermission() => _dataSource.requestPermission();

  @override
  Future<LocationPermissionStatus> getPermissionStatus() async {
    if (!await _dataSource.isServiceEnabled()) {
      return LocationPermissionStatus.serviceDisabled;
    }
    final permission = await _dataSource.getPermission();
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionStatus.granted;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.notYetAsked;
    }
  }
}

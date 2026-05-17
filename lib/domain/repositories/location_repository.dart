import 'package:qradar/domain/entities/location_permission_status.dart';
import 'package:qradar/domain/entities/user_location.dart';

/// 위치 Repository 인터페이스.
abstract class LocationRepository {
  /// 현재 위치 조회. 권한이 없거나 실패하면 기본 위치(서울 시청)를 `isFallback: true`로 반환.
  Future<UserLocation> getCurrentLocation();

  /// 위치 권한 요청. 허용 시 true.
  Future<bool> requestPermission();

  /// 현재 위치 권한 상태 조회. 실제 요청을 발생시키지 않음(pre-permission 판단용).
  Future<LocationPermissionStatus> getPermissionStatus();
}

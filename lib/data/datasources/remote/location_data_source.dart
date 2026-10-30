import 'package:geolocator/geolocator.dart';

/// geolocator 래퍼. Repository가 이 클래스를 통해 플랫폼 API에 접근.
class LocationDataSource {
  /// 현재 좌표 반환. 권한/서비스 이슈 시 null.
  Future<Position?> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      // timeLimit 필수 — 없으면 GPS 고정이 안 잡히는 환경(에뮬레이터·실내 등)에서
      // 무한 대기 → 호출부(홈 주변매장) 로드가 끝나지 않아 ANR 발생. 초과 시 TimeoutException → null 폴백.
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// 권한 요청. 허용되면 true.
  Future<bool> requestPermission() async {
    final permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// 위치 서비스 활성화 여부(단말 전역 설정).
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  /// 현재 권한 상태 확인(OS 다이얼로그를 띄우지 않음).
  Future<LocationPermission> getPermission() => Geolocator.checkPermission();
}

/// 위치 권한 상태(도메인 레이어 추상화).
///
/// geolocator 의 세부 enum 에 presentation/domain 이 의존하지 않도록 격리.
enum LocationPermissionStatus {
  /// 아직 묻지 않았거나 이전에 거부했지만 다시 물을 수 있음 → pre-permission 대화상자 노출 대상
  notYetAsked,

  /// 이미 허용됨 → 바로 위치 조회
  granted,

  /// 영구 거부됨 → 설정에서 수동 변경 필요, 폴백 사용
  deniedForever,

  /// 단말 위치 서비스 자체가 꺼져 있음 → 폴백 사용
  serviceDisabled,
}

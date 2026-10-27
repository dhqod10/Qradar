/// 앱 운영 설정(`config/app`) 읽기 저장소 (payment_price_authority H-01).
abstract class AppConfigRepository {
  /// `config/app.minClientLevel`. 문서·필드가 없으면 null. 읽기 실패는 예외 (호출자가 "막지 않음" 으로 바꾼다).
  Future<int?> fetchMinClientLevel();
}

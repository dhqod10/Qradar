/// `config/qoin` 쓰기 (admin 전용). 거래 원장 쓰기와 무관 — [QoinRepository] 와 분리.
///
/// 적립률과 kill switch 는 **저장 경로가 분리**되어 있다.
/// 비상 정지가 적립률 입력/검증에 막히거나, 작성 중인 적립률이 딸려 저장되면 안 된다.
abstract class QoinConfigAdminRepository {
  /// 적립률만 저장. 문서가 없으면 `enabled: false` 로 함께 생성 (fail-closed 유지).
  /// 문서가 있으면 `enabled` 는 건드리지 않는다.
  Future<void> saveAccrualRate(double rate);

  /// `enabled` 만 저장. 문서가 없으면 실패한다 (적립률 없이 켤 수 없다).
  Future<void> setEnabled(bool enabled);
}

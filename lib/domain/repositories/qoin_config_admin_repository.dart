/// `config/qoin` 쓰기 (admin 전용). 거래 원장 쓰기와 무관 — [QoinRepository] 와 분리.
///
/// **적립률 쓰기는 여기에 없다.** 적립률(전역 포함)은 Cloud Function(`setQoinAccrualRate`)
/// 전담이라 `QoinRateRepository` 가 맡는다 — 이력 없는 변경이 구조적으로 불가능해야 하기 때문이다.
/// `enabled`(비상 정지)만 직접 쓰기를 유지한다: CF 장애 중에도 끌 수 있어야 한다.
/// 그 변경 이력은 `onQoinConfigWritten` 트리거가 남긴다 (행위자는 알 수 없음).
abstract class QoinConfigAdminRepository {
  /// `enabled` 만 저장. 문서가 없으면 실패한다 (적립률 없이 켤 수 없다).
  Future<void> setEnabled(bool enabled);
}

/// Qoin 거래 유형.
///
/// `OrderStatus.fromCode` 와 달리 **미지 값을 임의 멤버로 폴백하지 않는다** (null 반환).
/// 폴백하면 금액 부호와 문구가 어긋난다. UI 는 적립/회수 판정을 `amount` 의 부호로 하고,
/// 미지 타입은 중립 문구(`Qoin 조정`) 로 렌더한다 (2차 소멸 타입 추가 시 전방 호환).
enum QoinTransactionType {
  earn,
  clawback;

  /// Firestore 코드 → enum. 알 수 없는 값/null 은 null.
  static QoinTransactionType? fromCode(String? code) {
    for (final t in QoinTransactionType.values) {
      if (t.name == code) return t;
    }
    return null;
  }

  String get asString => name;
}

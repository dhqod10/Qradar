import 'package:intl/intl.dart';

/// Qoin 금액 표기 (`1,200 Q`). 단위는 `Q` 로 확정 (A5).
class QoinFormatters {
  QoinFormatters._();

  static final NumberFormat _grouped = NumberFormat('#,##0');

  /// 천 단위 콤마 숫자만. 음수는 `-` 가 붙는다.
  static String number(int n) => _grouped.format(n);

  /// 잔액: `1,200 Q` / `0 Q` / `-100 Q`. 부호 보존, clamp 없음.
  static String balance(int n) => '${number(n)} Q';

  /// 증감액: `+540 Q` / `-540 Q`. 0 은 부호 없이 `0 Q`.
  static String signed(int amount) {
    if (amount > 0) return '+${number(amount)} Q';
    if (amount < 0) return '-${number(-amount)} Q';
    return '0 Q';
  }

  /// 스크린리더용: 하이픈 대신 `마이너스`. `내 Qoin 잔액` 뒤에 붙는 값.
  static String balanceSpoken(int n) =>
      n < 0 ? '마이너스 ${number(-n)} Q' : '${number(n)} Q';

  /// 내역 일시: 올해면 `10월 22일 (수) 14:35`, 아니면 `2025년 12월 31일 (수) 14:35`.
  /// `ko_KR` 로케일 초기화(main.dart)가 전제.
  static String dateTime(DateTime dt, {required DateTime now}) {
    final local = dt.toLocal();
    final pattern = local.year == now.year
        ? 'M월 d일 (E) HH:mm'
        : 'yyyy년 M월 d일 (E) HH:mm';
    return DateFormat(pattern, 'ko_KR').format(local);
  }

  /// 스크린리더용 일시: `10월 22일 14시 35분`.
  static String dateTimeSpoken(DateTime dt) {
    final l = dt.toLocal();
    return '${l.month}월 ${l.day}일 ${l.hour}시 ${l.minute}분';
  }
}

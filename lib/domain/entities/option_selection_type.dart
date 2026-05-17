/// 옵션 그룹 선택 방식 — `single`(라디오) 또는 `multi`(체크박스).
enum OptionSelectionType {
  single,
  multi;

  static OptionSelectionType fromString(String value) {
    switch (value) {
      case 'multi':
        return OptionSelectionType.multi;
      case 'single':
      default:
        return OptionSelectionType.single;
    }
  }

  String get asString {
    switch (this) {
      case OptionSelectionType.single:
        return 'single';
      case OptionSelectionType.multi:
        return 'multi';
    }
  }
}

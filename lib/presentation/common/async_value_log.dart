import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// `provider.asData?.value ?? []` 의 안전한 대체.
///
/// 그 관용구는 **로딩과 실패를 똑같이 "빈 목록"으로 만든다.** 쿼리에 복합 인덱스가 빠져
/// 있어도 화면에는 "데이터가 없어요" 라고만 떠서, 기능이 통째로 막혀 있는데도 평범한
/// 빈 상태처럼 보인다 (실제로 브랜드 옵션 그룹이 그랬다 — optionGroups 인덱스 누락).
///
/// 이 함수는 실패를 **삼키지 않고 로그로 남긴 뒤** null 을 돌려준다. 호출부는 null 을
/// "불러오지 못했다" 로, 빈 목록을 "정말 없다" 로 구분해 보여 줄 수 있다.
T? asDataOrLog<T>(AsyncValue<T> value, String tag) {
  if (value.hasError) {
    debugPrint('[$tag] 불러오기 실패: ${value.error}\n${value.stackTrace}');
    return null;
  }
  return value.asData?.value;
}

# soldout_checkout_feedback 구현 결과

## 수정 파일
- `lib/presentation/customer/cart/cart_page.dart` — `_onCheckout` 의 `hasViolations` 분기에 스낵바 추가 (`clearSnackBars()` 후 `showSnackBar`, 2초). `_scrollToFirstViolation()` 유지.
  - `validation.store != null`: "지금은 이 매장에서 주문할 수 없어요. 잠시 후 다시 시도해 주세요."
  - 그 외: "지금 주문할 수 없는 메뉴가 있어요. 표시된 메뉴를 확인해 주세요."
  - 색 미지정(기본값), 신규 위젯/레이어 변경 없음.

## 문구 조정
스펙 초안에 문장 끝 마침표만 추가 (같은 파일 F1 스낵바 "로그인 후 이용해주세요." 와 표기 일관).

## 테스트 포인트
- 품절/판매중지 메뉴 담긴 상태 결제하기 탭 -> 메뉴 문구 스낵바 + 위반 라인 스크롤, 체크아웃 미진입.
- 매장 영업중단 상태 -> 매장 문구 스낵바.
- 연타 시 스낵바 누적 없음, 2초 후 사라짐.
- 위반 없음 / 가격변동 분기에는 스낵바 미노출, 기존 동작 유지.

## 미구현/보류
없음.

## flutter analyze
Analyzing OrderApp...                                           
No issues found! (ran in 7.7s)

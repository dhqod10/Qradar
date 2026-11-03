# existing_user_phone_collection — implementation.md

D1=B (체크아웃 게이트). Entity/Model/firestore.rules/CF/라우팅 변경 없음.

## 생성 파일
- `lib/core/utils/phone_validator.dart` — `kKoreanMobilePattern`, `kPhoneMaxLength`, `isValidKoreanMobile` (D3 단일 소스)
- `lib/presentation/common/widgets/phone_input.dart` — `phoneInputFormatters()`, `formFieldDecoration()` (signup `_decoration` 승격)
- `lib/domain/usecases/update_my_phone_use_case.dart` — 형식 검증 후 repository 호출 (잘못된 값은 ArgumentError, 값 미포함)
- `lib/presentation/customer/checkout/widgets/phone_collection_sheet.dart` — `showPhoneCollectionSheet(context, uid)` -> `Future<bool?>` (checkout_blocked_sheet 와 같은 폴더)
- `test/core/phone_validator_test.dart`

## 수정 파일
- `lib/domain/repositories/user_repository.dart`, `lib/data/repositories/user_repository_impl.dart`, `lib/data/datasources/remote/user_remote_data_source.dart` — `updateMyPhone` (`_doc(uid).update({'phone','updatedAt'})`)
- `lib/presentation/customer/auth/providers/user_profile_provider.dart` — `updateMyPhoneUseCaseProvider`
- `lib/presentation/customer/auth/email_signup_page.dart` — private `_phonePattern`/`_decoration`/formatter 를 공용으로 교체 (검증식·문구·동작 동일)
- `lib/presentation/customer/checkout/checkout_page.dart` — `_handlePay` 에서 profile 확인 직후, `_processing` 설정 전에 phone 게이트. 시트 true 여도 return + SnackBar. 저장 실패/닫기는 결제 미진행 (fail-closed).
- 테스트 fixture: `test/presentation/payment_price_checkout_page_test.dart`, `test/presentation/qoin_spend_checkout_test.dart` — 프로필 fixture 에 `phone: '01012345678'` 추가 (게이트 통과용, 기존 시나리오 의도 불변)

## 구현 메모
- 시트: 에러는 포커스 이탈 또는 11자리 불일치 시만 노출, 저장 중 입력/버튼/닫기 비활성 + `PopScope(canPop: !saving)`, 실패는 인라인 고정 문구(raw 숨김, 입력 유지). 하단 패딩에 viewInsets.bottom. phone 로그 출력 없음.
- AppColors 만 사용, Firebase import 없음.

## 테스트 포인트 (tester)
1. phone 없는 유저가 결제 탭 -> 시트, 결제/선검증 미시작. phone 있는 유저는 시트 없이 기존 흐름.
2. 유효 번호 저장 -> 시트 닫힘 + SnackBar, 결제 자동 시작 안 됨, 다시 탭하면 진행.
3. 닫기/배경 탭 -> 결제 미진행, 다음 탭에서 게이트 재발동.
4. 저장 실패(오프라인) -> 인라인 에러, 입력 유지, 재시도 가능.
5. 키보드 올라와도 저장 버튼 가려지지 않음. 빈값 첫 진입 시 빨간 에러 없음.
6. signup 회귀: 전화 형식 오류 문구, 숫자만/11자리 제한.
7. 실기기: Firestore 에 phone 저장 확인 (Rules 화이트리스트).

## 보류 / 미구현
- 시트 위젯 테스트 및 체크아웃 게이트 위젯 테스트 미작성 (validator 단위 테스트만 추가).
- 스와이프(drag) 다운은 저장 중에도 Flutter 가 막지 않음 (저장은 완료되지만 true 가 전달되지 않아 SnackBar 없음, 무해).
- `data_ownership.md §users` 1줄 주석 갱신 미실시 (spec 에 언급, 범위 밖으로 판단).

## 검증
- `flutter analyze`: No issues found
- `flutter test`: All tests passed (+1103)

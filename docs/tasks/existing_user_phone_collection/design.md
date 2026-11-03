# existing_user_phone_collection — design.md

경량 UI: 결제 직전 **전화번호 입력 바텀시트 1종**. 새 화면/라우팅 없음(홈/role_router 무변경).
톤·토큰은 `checkout_blocked_sheet.dart`, 필드·검증·고지는 `email_signup_page.dart` 를 그대로 복제한다. 신규 스타일 없음.

## 사용자 확인 필요 디자인 결정

없음. (저장 성공 후 흐름은 spec 의 "자동 결제 금지, 재탭" 정책에 맞춰 §4 에 권고안 1개로 확정.)

---

## 1. 진입 / 흐름

- 진입: `checkout_page.dart` `_handlePay` 진입부에서 `(profile.phone ?? '').isEmpty` 이면 결제를 시작하지 않고 시트 호출. 이미 phone 있으면 시트 없음(회귀 없음).
- 호출 형태: `showPhoneCollectionSheet(context, uid)` -> `Future<bool?>` (저장 성공 true, 그 외 닫기/스와이프 null).
- 호출 옵션은 `showCheckoutBlockedSheet` 와 동일하되 키보드 대응만 추가:
  `isDismissible: true`(저장 중에는 false 로 막음, §3), `useSafeArea: true`, `isScrollControlled: true`, `backgroundColor: AppColors.surfaceElevated`, 상단 radius 20.
  본문 하단 패딩에 `MediaQuery.viewInsets.bottom`(키보드)을 더해 CTA 가 키보드에 가리지 않게 한다.

## 2. 시트 구조 (위 -> 아래)

패딩 `EdgeInsets.fromLTRB(20, 12, 20, 16 + viewPadding.bottom + viewInsets.bottom)`, `SingleChildScrollView` > `Column(min, stretch)`.

| # | 요소 | 스펙 |
|---|---|---|
| 1 | 핸들 | 36x4, `AppColors.border`, radius 2, 중앙 (blocked sheet 동일) |
| 2 | (간격) | 16 |
| 3 | 제목 | `주문 연락처를 입력해 주세요` / 18 w700 / `textHeading` |
| 4 | (간격) | 8 |
| 5 | 사유 + 미시작 안내 | `픽업 연락을 위해 전화번호가 필요해요. 결제는 아직 시작되지 않았어요.` / 14, height 1.5 / `textBody` |
| 6 | (간격) | 16 |
| 7 | 전화 TextField | 아래 §2-1 |
| 8 | (간격) | 12 |
| 9 | 수집 고지 1줄 | `전화번호는 주문 식별 및 픽업 연락을 위해서만 사용됩니다.` / 12 / `textMuted` / maxLines 2 (signup 고지 `이름과 전화번호는 주문 식별 및 서비스 제공을 위해서만 사용됩니다.` 와 동일 톤·크기·색) |
| 10 | (간격) | 16 |
| 11 | 저장 버튼 | §2-2 |
| 12 | (간격) | 8 |
| 13 | 닫기 버튼 | §2-3 |

### 2-1. 전화 TextField (signup 과 동일)
- `keyboardType: TextInputType.phone`, `textInputAction: done`, `autofillHints: [AutofillHints.telephoneNumber]`, `autofocus: true`(시트 오픈 즉시 키패드).
- `inputFormatters`: 공용 유틸의 `digitsOnly` + `LengthLimitingTextInputFormatter(11)` (D3 승격 유틸 사용, 시트에 중복 정의 금지).
- 데코레이션: signup `_decoration` 과 동일 — label `전화번호`, hint `01012345678`, border radius 12, focused `AppColors.primary`, error/focusedError `AppColors.error`, errorStyle 12 `AppColors.error`. (`_decoration` 도 공용 승격 대상이면 같이, 아니면 값만 복제.)
- `onSubmitted`: 유효하면 저장 실행(키패드 완료 = 저장).

### 2-2. 저장 버튼
- 높이 52, `ElevatedButton`, 라벨 `저장하기`, 16 w700, radius 12, elevation 0.
- 활성: bg `AppColors.primary` / fg `AppColors.onPrimary` (blocked sheet primary 와 동일).
- 비활성: Material 기본 disabled 처리 사용(`onPressed: null`). 별도 색 발명 금지.

### 2-3. 닫기 버튼
- 높이 52, `OutlinedButton`, 라벨 `나중에 할게요`, 16 w600, fg `textBody`, bg `surfaceElevated`, side `border`, radius 12 (blocked sheet 보조 버튼 동일).
- 동작: `Navigator.pop(context)` (null). 결제 미시작·주문 없음. 안내 추가 노출 없음(차단감 최소화, 사유는 §5 카피로 이미 전달).

## 3. 상태

### 입력 검증
- 검증식: 공용 `^01[016789]\d{7,8}$` (signup 과 한 소스).
- 저장 버튼: 정규식 통과 시에만 활성. 그 외(빈값·부분 입력) 비활성.
- 인라인 에러 노출 시점(타이핑 중 깜빡임 방지): 입력이 비어있지 않고 **필드 포커스를 잃었을 때** 또는 **11자리 도달했는데 불일치**일 때.
  - 문구(signup 재사용): `올바른 휴대폰 번호를 입력해주세요. (예: 01012345678)` / `AppColors.error` / 12.
  - 빈값은 에러 문구 없이 버튼 비활성만(첫 진입에 빨간 에러 금지). `전화번호를 입력해주세요.` 는 버튼이 비활성이라 노출 경로 없음.
  - 입력 변경 시 에러 즉시 해제(`onChanged`), 서버 저장 에러도 동일하게 해제.

### Loading (저장 중)
- 저장 버튼: 라벨 대신 20x20 `CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary)`, `onPressed: null`.
- TextField `enabled: false`, 닫기 버튼 비활성.
- 시트 dismiss 차단: `isDismissible: false` + `enableDrag: false` 또는 `PopScope(canPop: !saving)`. (저장 완료 전 닫혀 상태 불일치 방지.)

### Error (저장 실패, fail-closed)
- 서버/Firebase raw 메시지 노출 금지. 필드 아래(고지 문구 위) 에러 영역에 `저장에 실패했어요. 다시 시도해 주세요.` / 13 / `AppColors.error`. 필드 자체 빨간 테두리는 쓰지 않음(입력은 정상이므로).
- 입력값 유지, 버튼 `저장하기` 로 복귀(= 재시도), 시트 유지. 실패 시 **결제로 진행하지 않고** 체크아웃도 phone 미저장 상태 그대로 -> 다음 결제 탭에서 게이트 재발동.
- `ErrorDialog` 는 쓰지 않는다(시트 안 인라인으로 충분, 이중 모달 방지).

### Empty
- 해당 없음(단건 입력).

## 4. 저장 성공 후 흐름 (권고안)

**권고: 성공 시 시트만 닫고 체크아웃에 머문다. 자동 결제 시작 금지, 사용자가 `결제하기` 를 다시 탭.**
- 근거: spec 정책·blocked sheet 정책과 동일(결제는 사용자가 금액 확인 후 시작), 스트림 반영 지연으로 인한 phone 불일치 위험 제거(`updateMyPhone` await 후 pop).
- 성공 피드백: 시트 닫힌 직후 체크아웃에서 SnackBar 1회 `전화번호를 저장했어요. 결제하기를 눌러 계속해 주세요.` (기존 SnackBar 스타일 사용, 신규 색상 없음).
- 구현 단서: 시트가 `true` 반환 -> `_handlePay` 는 `return`(결제 미시작), 스낵바만 표시.

## 5. 카피 요약

| 위치 | 문구 |
|---|---|
| 제목 | 주문 연락처를 입력해 주세요 |
| 본문 | 픽업 연락을 위해 전화번호가 필요해요. 결제는 아직 시작되지 않았어요. |
| 필드 label / hint | 전화번호 / 01012345678 |
| 형식 오류 | 올바른 휴대폰 번호를 입력해주세요. (예: 01012345678) |
| 고지 | 전화번호는 주문 식별 및 픽업 연락을 위해서만 사용됩니다. |
| 저장 / 닫기 | 저장하기 / 나중에 할게요 |
| 저장 실패 | 저장에 실패했어요. 다시 시도해 주세요. |
| 성공 스낵바 | 전화번호를 저장했어요. 결제하기를 눌러 계속해 주세요. |

## 6. 사용 토큰
`primary`, `onPrimary`, `surfaceElevated`, `border`, `textHeading`, `textBody`, `textMuted`, `error`. 신규 토큰·`Color(0x...)` 없음.

## 7. 개발자 전달 특이사항
- 전화 검증 정규식 + formatter(+가능하면 `_decoration`)를 공용 위치로 승격해 signup 과 시트가 한 소스 사용. signup 동작 회귀 금지.
- 시트는 별도 파일 `lib/presentation/customer/checkout/widgets/phone_collection_sheet.dart` 권장(blocked sheet 와 같은 폴더). 상태(saving/에러)는 `HookConsumerWidget` 로컬 상태로 충분.
- PII: phone 값을 로그/디버그 출력 금지.
- 접근성: 에러 문구는 TextField errorText 로 연결, 로딩 중 버튼 semantics 라벨 `저장 중`.

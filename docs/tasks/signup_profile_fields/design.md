# signup_profile_fields 디자인 명세

대상: `lib/presentation/customer/auth/email_signup_page.dart` (이메일 가입 폼만). 신규 컴포넌트 없음, 기존 TextField 스타일 재사용.
기준: spec.md (이름 필수 / 전화 필수·형식검증만 / 기존유저·소셜 제외). 홈 인사말은 변경 없음.

진입: 로그인 화면 -> 이메일 가입 (기존 흐름 그대로, role_flows 변경 없음. customer 비로그인 단계).

## 1. 필드 순서 / 배치

위에서 아래로, 필드 간 간격 16 (기존과 동일).

| # | 필드 | labelText | hintText | keyboardType | textInputAction |
|---|---|---|---|---|---|
| 1 | 이름 | `이름` | 없음 | `TextInputType.name` | next |
| 2 | 전화번호 | `전화번호` | `01012345678` | `TextInputType.phone` | next |
| 3 | 이메일 | `이메일` (기존) | - | emailAddress | next |
| 4 | 비밀번호 | `비밀번호 (6자 이상)` (기존) | - | - | next |
| 5 | 비밀번호 확인 | `비밀번호 확인` (기존) | - | - | done (기존 onSubmitted 유지) |

근거: 인적사항(이름/전화) -> 계정(이메일/비번) 순이 자연스럽고, 기존 3필드 순서와 스타일은 그대로 유지된다.
- 이름 `textCapitalization: words` 불필요(한글 위주). `autofillHints`: 이름 `AutofillHints.name`, 전화 `AutofillHints.telephoneNumber`(선택사항).
- 4필드 + 고지 + 버튼이 작은 화면에서 넘칠 수 있으므로 body 를 `SingleChildScrollView` 로 감싼다 (키보드 노출 시 필수). Padding 24 유지.

## 2. 입력 스타일 (기존 재사용)

기존 필드와 동일: `OutlineInputBorder` radius 12, 기본 border 는 Material 기본, focusedBorder 는 `AppColors.primary`. 신규 토큰 없음.
추가: 에러 상태 `errorBorder` / `focusedErrorBorder` 는 `BorderSide(color: AppColors.error)` (radius 12). `errorStyle` 은 `TextStyle(color: AppColors.error, fontSize: 12)`.
- 가장 쉬운 구현: 이름/전화 필드에 `errorText` 를 상태(`useState<String?>`)로 주입. 이메일/비번은 기존 다이얼로그 검증 유지(이번 범위 외, 과도설계 방지).

## 3. 전화번호 입력 정책 (결정)

- **자동 하이픈 포맷팅 하지 않는다.** 숫자만 입력받는다: `inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)]`.
- 마스킹 없음(가입 시 본인이 입력하는 값이므로 평문 표시).
- hint `01012345678` 로 형식을 안내. 붙여넣기로 하이픈이 들어와도 digitsOnly 가 제거.
- 저장값은 숫자만(예: `01012345678`) -> spec 의 Firestore 예시와 일치. 표시용 하이픈 포맷은 후속 화면에서 필요 시 처리.
- 검증 정규식(제출 시): `^01[016789]\d{7,8}$` (한국 휴대폰 10~11자리). 
  - 단순 입력 방침상 SMS 인증 없음.

## 4. 인라인 검증 에러

시점: **제출(가입하기 탭) 시** 일괄 검증. 이후 해당 필드 편집 시(`onChanged`) 그 필드의 에러를 즉시 해제. 포커스 이탈 검증은 하지 않음(과도설계 방지).
검증 순서: 이름 -> 전화 -> 기존 이메일/비번 검증. 이름/전화 오류가 있으면 가입 호출 안 함. 첫 번째 오류 필드로 포커스 이동(선택).

| 필드 | 조건 | 에러 문구 |
|---|---|---|
| 이름 | 공백 trim 후 빈값 | `이름을 입력해주세요.` |
| 이름 | trim 후 1자 미만은 위와 동일. 길이 > 20 | `이름은 20자 이내로 입력해주세요.` (입력 자체를 `LengthLimitingTextInputFormatter(20)` 로 막아 에러 문구는 사실상 불필요 -> 문구 생략하고 formatter 만 적용해도 됨) |
| 전화 | 빈값 | `전화번호를 입력해주세요.` |
| 전화 | 정규식 불일치 | `올바른 휴대폰 번호를 입력해주세요. (예: 01012345678)` |

이름 형식 규칙은 별도로 두지 않는다(실명 형식은 국가/표기 다양 -> trim 후 비어있지 않음 + 20자 제한만). 저장 시 `trim()` 값.
서버/네트워크/이메일중복 오류는 기존 `showErrorDialog(authFriendlyMessage)` 유지.

## 5. 개인정보 수집 고지 (1줄)

- 문구: `이름과 전화번호는 주문 식별 및 서비스 제공을 위해서만 사용됩니다.`
- 위치: 비밀번호 확인 필드와 가입하기 버튼 사이. 위 간격 12, 아래 간격 24(기존 버튼 위 간격 24 대체: 필드 -> 12 -> 고지 -> 24 -> 버튼).
- 스타일: fontSize 12, 색 `AppColors.textMuted`, 왼쪽 정렬, 최대 2줄(작은 화면에서 줄바꿈 허용).
- 동의 체크박스 **추가하지 않음**: 현재 가입 폼에 약관 동의 UI 자체가 없고 별도 약관 흐름도 없다. 고지 1줄로 충분(spec 의 "과하지 않게"). 법적 동의 요건은 기획/B 범위(미성년자 정책) 확정 시 재검토 -> 사용자 확인 항목.

## 6. 상태

| 상태 | UI |
|---|---|
| 기본 | 5필드 + 고지 + 가입하기 버튼(`AppColors.primaryBright`, radius 12, 기존) |
| 제출 중(loading) | 기존 패턴 유지: 버튼 내부 흰색 `CircularProgressIndicator` 20x20, strokeWidth 2, 탭 무시(`onTap: null`). 추가로 5개 TextField 를 `enabled: !isLoading.value` 로 비활성화 권장(중복 입력/수정 방지). |
| 검증 에러 | 해당 필드 errorBorder + 하단 에러 문구. 가입 버튼은 **비활성화하지 않는다**(탭하면 검증하여 에러 노출 — 사전 비활성은 이유를 알 수 없어 UX 불리). |
| 서버 에러 | 기존 에러 다이얼로그 |
| empty | 해당 없음(폼) |

## 7. 개발자 전달 사항

- 색상: `AppColors.error / textMuted / primary / primaryBright` 만. 기존 코드에 남아있는 `Colors.white`(배경/버튼 글자)는 기존 그대로이며 이번 범위에서 건드리지 않음(발견 사항: 가능하면 `AppColors.onPrimary` / `background` 로 교체 권장이나 선택).
- 키보드: 이름 `TextInputType.name`, 전화 `TextInputType.phone` (+ digitsOnly 필터로 숫자만).
- 전화 포맷팅/마스킹: 하지 않음. 저장은 숫자만 문자열. 빈값이면 payload 키 생략(spec).
- 이름은 `trim()` 후 `displayName` 으로 전달.
- 5필드 + 키보드 대응 `SingleChildScrollView`, `textInputAction.next` 연쇄(`FocusNode` 또는 기본 `TextInput.next` 동작).
- 기존 "이메일과 비밀번호를 입력해주세요." 다이얼로그 검증은 유지(이름/전화 검증이 그 앞에서 인라인으로 먼저 수행).
- 홈 인사말: 변경 없음. 이름이 비어 있던 이메일 가입 유저도 이제 입력한 이름이 "○○님 어서오세요."로 표시됨(회귀 확인: 소셜/기존 유저 폴백 유지).

## 8. 사용자 확인 필요

1. 개인정보 동의 체크박스 없이 고지 1줄만으로 진행해도 되는지(권고: 이번엔 1줄).
2. 전화번호 자동 하이픈 미적용(숫자만 입력) 방침 — 권고 그대로 진행해도 되는지.

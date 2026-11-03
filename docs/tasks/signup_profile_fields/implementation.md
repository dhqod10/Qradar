# signup_profile_fields 구현 기록

## 구현 내용
- domain: `UserEntity.phone` 추가 (읽기 전용 PII). `SignUpWithEmailUseCase` / `AuthRepository.signUpWithEmail` 에 `name`, `phone` 필수 파라미터 전파.
- data: `UserModel.phone` (JSON 제외, Firestore 전용), `fromFirestore` / `fromEntity` / `toEntity` / `toFirestoreForCreate`(빈값이면 키 생략). `AuthRemoteDataSource.signUpWithEmail` 이 `displayName=name`, `phone` 을 실어 반환.
- 생성 경로: authProvider state(가입 반환 entity) -> `currentUserProfileProvider` -> `getOrCreateUserProfile` -> `UserModelFactory.fromEntity` -> `createIfAbsent` (모델이 name/phone 을 이미 운반하므로 시그니처 변경 불필요).
- presentation: `email_signup_page.dart` 에 이름/전화 필드(이름 -> 전화 -> 이메일 -> 비번 -> 확인), 가입 탭 시 일괄 인라인 검증, 편집 시 에러 해제, `SingleChildScrollView`, 로딩 중 5필드 비활성, 고지 1줄. 이름 trim 20자 제한, 전화 digitsOnly 11자 + `^01[016789]\d{7,8}$`.
- firestore.rules: users self update 화이트리스트에 `phone` 추가 (create 는 기존 허용). `data_ownership.md §2.1` 갱신.
- freezed/json 재생성 완료.

## 테스트
- `flutter analyze`: 0 issues. `flutter test`: 전체 통과 (1089).
- rules 하네스 `npm test`: 495/495 PASS (신규 SP1~SP5: phone self update 허용, phone+qoinBalance 거부, 타인 update 거부, 신규 가입 payload create 허용, 타인 read 거부).

## 테스트 포인트
- 이메일 가입: 이름/전화 빈값·형식오류 인라인 에러, 편집 시 해제, 정상 가입 후 users 문서에 displayName/phone 저장, 홈 인사말에 입력 이름 표시.
- 전화 붙여넣기(하이픈 포함) 시 숫자만 남는지, 11자 제한.
- 소셜/기존 유저 회귀(phone 없음, 인사말 폴백).
- 키보드 노출 시 스크롤.

## 미구현 / 비고
- 기존 유저 입력 유도, 소셜 가입 전화: 비범위.
- Firebase Auth 프로필(displayName) 자체는 갱신하지 않음 (Firestore 가 진실원). 
- firebase deploy 미실행: rules 배포 필요(phone update 허용은 현 클라이언트 흐름에선 create 만 쓰므로 배포 전에도 가입 동작).
- 기존 코드의 `Colors.white` 는 범위 밖이라 유지.

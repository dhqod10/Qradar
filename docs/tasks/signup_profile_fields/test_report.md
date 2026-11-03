# signup_profile_fields 테스트 리포트

## 요약
PASS 5/5 중점 항목 + 절대규칙. FAIL 0. 보류 2 (모두 비차단).

## 자동 검증
- flutter analyze: No issues found
- flutter test: 1093 전체 통과 (implementation 기재 1089 이후 증가분, 타 작업 포함)
- test_rules npm test: 508/508 PASS (SP1~SP5 포함). 기대 495 와의 차이 13건은 범위 밖 order_pickup_number(PK-*) 테스트 추가분.

## 항목별
1. 저장 경로 PASS: UseCase/Repository/RemoteDataSource/AuthNotifier 모두 name·phone required 전파. DataSource 가 displayName=name, phone 반환. UserModel.phone 은 includeFromJson/ToJson false, fromFirestore/fromEntity/toEntity/toFirestoreForCreate 반영, 빈값 시 키 생략.
2. 읽기전용 PII PASS: users read = admin 또는 본인. SP5 로 타인 read 거부 확인.
3. 폼/검증 PASS: 순서 이름→전화→이메일→비번→확인, 이름 20자 제한·trim 빈값 검사, 전화 digitsOnly·11자·정규식 ^01[016789]\d{7,8}$, 가입 탭 시 일괄 검증, onChanged 에러 해제, 에러색 AppColors.error, 문구 3종, SingleChildScrollView+textInputAction.next, 로딩 중 5필드 enabled=false, 가입 버튼 사전 비활성 없음, 고지 12px textMuted.
4. 홈 인사말 회귀 PASS: home_header 의 profile.displayName -> user.displayName -> 폴백 구조 유지, phone 없는 유저 영향 없음.
5. firestore.rules PASS: isSelfProfileUpdate 화이트리스트에 phone 추가, create 규칙 유지. SP1~SP5 타당 (phone+qoinBalance 동시 거부 포함).

## 절대규칙
- Firebase import: presentation/domain 에 신규 없음 PASS
- Color(0x) 신규 없음, AppColors 사용 PASS. (기존 Colors.white 는 범위 밖, 지적만)
- secret 하드코딩 없음 PASS
- 범위 밖 접촉: signup 변경 파일에 order_pickup_number 접촉 없음. 단 워킹트리에는 pickup 관련 변경이 공존 (firestore.rules 의 pickupCounters 블록 등)

## 보류
- H1: firestore.rules 에 pickupCounters 블록(타 기능)이 동일 파일 변경으로 섞여 있음. 커밋/배포 시 기능별 분리 필요.
- H2: onSignUp 에서 가입 성공 후 isLoading.value=false 는 위젯 dispose 이후 실행될 수 있음 (기존 패턴, 미세 위험). 이메일/비번 빈값 검사는 기존 다이얼로그 방식 유지(이름/전화만 인라인).

# Qoin 1차 구현 내역

기준: `spec.md` (§15 전건 확정, D4-d 관리자 화면 포함), `design.md` (+ 맨 끝 "잔여 결정 확정" 우선).

## 구현 파일

### 인프라 (배포 필요)
- `firestore.rules` — 신규 블록 2개만 추가, **기존 블록 수정 0건** (diff 에 삭제 줄 없음).
  - `users/{userId}/qoinTransactions/{txId}` (users 중첩 match 안): read = 본인 or admin / create·update·delete 전부 `if false` (admin 도 불가 — 원장 append-only).
  - `config/{docId}`: read = 로그인 / write = admin.
- `functions/src/onOrderQoinSettled.ts` (신규) + `functions/src/index.ts` export 1줄.
  - `onDocumentUpdated("orders/{orderId}")`, region `asia-northeast3`, **`retry: true`** (일시 장애 throw 시 재시도. 이 옵션이 없으면 v2 는 throw 해도 재시도하지 않는다).
  - 매트릭스: `* -> completed` 적립 (D3-b), `completed -> refunded` 회수. 그 외 early return.
  - `config/qoin`: 부재 / `enabled !== true` / `accrualRate` 비number·음수·>1 → 로그(error/warn) 후 return. **enabled=false 면 적립도 회수도 안 함.** 읽기 실패는 throw(재시도). 코드에 적립률 폴백 없음.
  - 산식: `floor(totalPrice * accrualRate)`. 부동소수 오차(`4500*0.03`) 방지를 위해 rate 를 ppm 정수로 환산해 계산. `0` 이면 거래 문서 미생성.
  - 트랜잭션: `earn_{orderId}` / `clawback_{orderId}` 선존재 가드 → `users` 읽기 → 거래 문서 set(`balanceAfter` = 절대값) + `users.qoinBalance` update. `users` 에는 `qoinBalance` 1필드만 (updatedAt 금지), `orders` 는 읽기 전용, `FieldValue.increment` / 전량 재계산 미사용.
  - 회수액은 `earn_{orderId}` 문서의 `amount` 를 읽어 반전 (재계산 없음). earn 문서 없으면 no-op.
  - 모든 분기에 구조화 로그: `applied` / `already_applied` / `no_user` / `skipped_no_config` / `skipped_disabled` / `skipped_invalid_rate` / `skipped_zero_amount` / `skipped_invalid_total` / `skipped_no_earn`.
- `firestore.indexes.json` — **변경 없음** (아래 "인덱스 실측").

### Core
- `core/utils/qoin_policy.dart` — 순수 로직. 0.1% 단위 정수(tenths) 기준 환산·검증. 하한 0.1 / 상한 20 / 예시 결제액 10,000 / 내역 상한 50 상수. `validateRateInput` 은 **하한 검사를 소수 자릿수 검사보다 먼저** 해서 `0.03` 이 반드시 `tooLow` 로 걸린다. 적립률 값 자체는 어디에도 없다.
- `core/utils/qoin_formatters.dart` — `1,200 Q` / `+540 Q` / `-540 Q` / 접근성 문구(하이픈 대신 `마이너스`).
- `core/constants/firestore_paths.dart` — `qoinTransactions`, `userQoinTransactions(uid)`, `config`, `qoinConfigDocId`.

### Domain
- 수정: `UserEntity.qoinBalance` (`@Default(0)`).
- 신규: `QoinTransactionType` (`fromCode` 가 **미지 값을 null 반환**, 폴백 없음), `QoinTransactionEntity`, `QoinConfigEntity` (`accrualRate` nullable = 유효하지 않음, `enabled` 기본 false), `QoinRepository` (조회 2개, 쓰기 없음), `QoinConfigAdminRepository` (config 쓰기 2개 — D4-d 로 admin 쓰기가 생겨 거래 조회 인터페이스와 분리), UseCase 4종 (`WatchQoinTransactions`, `WatchQoinConfig`, `SaveQoinAccrualRate`, `SetQoinEnabled`). `SaveQoinAccrualRate` 는 범위 밖 tenths 를 `ArgumentError` 로 한 번 더 막는다 (화면 검증 우회 방어).
- 삭제: `QoinAccrualHook` 인터페이스.

### Data
- 수정: `UserModel.qoinBalance` (JSON 제외) + `UserModelFactory.parseQoinBalance` (**음수 보존**, 부재/비num/NaN → 0). `toFirestoreForCreate` 에는 넣지 않음.
- 신규: `QoinTransactionModel` / `QoinConfigModel` (읽기 전용 매퍼), `QoinRemoteDataSource` (Firestore 직접 사용은 여기까지), `QoinRepositoryImpl` (두 인터페이스 구현).
  - `saveAccrualRate`: 트랜잭션으로 문서 존재 확인 → 있으면 `accrualRate` 만 update, 없으면 `enabled:false` 로 생성 (fail-closed).
  - `setEnabled`: `enabled` 1필드만 update. 적립률 저장 경로와 완전히 분리.
- 삭제: `NoOpQoinAccrualHook`.

### Presentation
- 고객: `qoin_page.dart` 전면 교체(placeholder 와 `준비 중입니다` 제거), `widgets/{qoin_balance_card, qoin_in_progress_banner, qoin_history_section, qoin_transaction_tile, qoin_status_block}`, `providers/{qoin_di_providers, qoin_providers}`.
  - 잔액은 `currentUserProfileProvider` (신규 구독 없음). **로딩 중 skeleton, `0 Q` 미표시**. error 는 `-` + 재시도.
  - 내역 스트림은 `uid` 만 select 해서 구독 — 잔액이 바뀔 때마다 재구독하지 않는다.
  - 적립/회수 판정은 `amount` 부호, `type` 은 사유 문구 선택에만. 미지 타입 `Qoin 조정`. 사유 `결제액 18,000원의 3%` 는 거래 문서의 `orderTotalPrice`/`accrualRate` 사용.
  - 진행 중 주문 배너 포함 (`paid`~`ready` 건수, 금액 없음, 탭 → Log 탭). 로딩/에러/0건이면 렌더 안 함.
  - 회수 행에 error 색·취소선·dim 없음. `AppColors` 만 사용, 신규 토큰 0.
- 관리자: `admin/qoin/admin_qoin_settings_page.dart` (신규), `admin_more_page.dart` 에 타일 + 부제(`적립률 3% · 적립 중`).
  - **퍼센트 입력 + `%` 접미사 고정 + 하한 0.1 / 상한 20 + 소수 1자리**, 실시간 환산 미리보기, 저장 전 항상 확인 다이얼로그(현재 → 변경 + 10,000원 기준 환산 + 인상 경고).
  - **비상 정지 스위치 분리**: `_onToggleEnabled` 는 적립률 입력/검증/`canSave` 를 전혀 참조하지 않고 `setQoinEnabledUseCase` 만 호출 → 적립률 검증에 막히지 않고 작성 중인 적립률이 딸려 저장되지 않는다. 낙관적 갱신 없음(서버 스트림 값만 표시).
  - 끄기 다이얼로그에 `이미 적립된 주문이 환불되어도 Qoin 이 회수되지 않아요` 명시 (+ 소급 적립 없음 안내).
  - `config/qoin` 부재 시 스위치 비활성, 첫 적립률 저장은 `enabled:false` 로 생성. 서버 값이 바뀌어도 입력 초안은 덮어쓰지 않는다.
- hook 제거 4곳: 인터페이스 / NoOp / `qoinAccrualHookProvider` (+import 2줄) / `checkout_page.dart` 호출부. grep 결과 0건.

### 테스트
- `test/data/qoin_models_test.dart` (QU1~QU4), `test/domain/qoin_policy_test.dart` (QU5 + 100배 방어 경계 + 환산 + 사유 문구 + 접근성 문구).
- `test_rules/rules.test.mjs` — QR1~QR18 (+변형) 추가.

## 검증 결과
- `flutter analyze`: No issues found
- `flutter test`: All tests passed (129, 기존 95 + 신규 34)
- `functions` `npm run build`: 통과
- Rules (`cd test_rules && npm test`): **71/71 PASS** (기존 48 + Qoin 23). QR9 / QR10 / QR10b(increment) 포함 전건 deny 확인.
- CF 에뮬레이터(firestore+functions, `firebase-tools@14`): **21/21 PASS** — QC1/1b/2/3/4/4b/5/6/7/8/9/9b/10/10b/11/12/13/14/15/16/18. QC17: 로그에서 `onOrderStatusChanged` 와 `onOrderQoinSettled` 가 동일하게 27회씩 실행. 추가로 확인한 것: 정책 변경(3%→10%) 후에도 회수액 == 적립액(-300), `enabled=false` 중 환불 회수도 중단. 테스트 스크립트는 scratchpad 의 일회성 파일이며 저장소에 없다.
- 미실행: QM1~QM10 (기기 UI 수동 검증), 스크린리더 `Q` 발음(tester 실기 항목).

## 인덱스 실측 결과
- 변경 없음. 쿼리는 `users/{uid}/qoinTransactions` 의 **단일 필드 `orderBy createdAt desc` + limit** 이라 컬렉션 범위 단일 필드 자동 인덱스로 충분하다. `config/qoin` 단건, CF 의 `earn_*` 단건 read 도 인덱스 불필요.
- **한계**: Firestore 에뮬레이터는 인덱스를 강제하지 않아 에뮬레이터 통과(QR18)는 인덱스 존재의 증거가 아니다. 운영 프로젝트 쿼리 프로브는 하지 않았다(권한 분류기 전례). 위 판단은 "단일 필드 쿼리는 자동 인덱스" 라는 Firestore 규칙에 근거한 것이며, 배포 후 Qoin 탭 내역이 `failed-precondition` 없이 뜨는지로 최종 확인해야 한다. 만약 에러가 나면 로그 링크의 인덱스를 `firestore.indexes.json` 에 추가.

## 사용자 배포 명령 (순서 중요)
1. **먼저** Firebase Console 에서 `config/qoin` 문서 생성 — 이 문서가 CF 배포보다 앞서야 한다 (fail-closed: 없으면 적립이 조용히 전부 중단되고, 그동안 완료된 주문은 소급 적립되지 않는다).
   - 방법 A (권장): 앱 배포 후 admin `더보기 > Qoin 설정` 에서 적립률 저장 → 문서가 `enabled:false` 로 생성됨 → 스위치로 켜기. 단 이 경로는 **Rules 배포가 선행**돼야 한다(`config` 가 catch-all deny).
   - 방법 B: Console 에서 `config` 컬렉션 / 문서 ID `qoin` / `accrualRate`(number) `0.03` / `enabled`(boolean) `true` (또는 `false` 로 만들고 켜기).
2. `cd /Users/Byeonguk/Developer/OrderApp && firebase deploy --only firestore:rules`
3. `cd /Users/Byeonguk/Developer/OrderApp/functions && npm run build && cd /Users/Byeonguk/Developer/OrderApp && firebase deploy --only functions:onOrderQoinSettled`
4. 인덱스 배포 불필요.

## 테스트 안내 (tester) — 트리거 유형 주의
- `onOrderQoinSettled` 는 **`onDocumentUpdated`** 다. Console 에서 `orders` 문서를 `completed` 로 **생성**하면 발화하지 않는다. 반드시 `status: "ready"` 로 만든 뒤 `completed` 로 **수정**할 것 (필수 필드: `userId`, `storeId`, `storeName`, `totalPrice`, `status`).
- 회수 테스트: 적립된 주문(`completed`)을 `refunded` 로 수정. 적립되지 않은 주문의 `refunded` 는 no-op 이 정상.
- 같은 주문을 `completed → ready → completed` 로 왕복해도 `earn_{orderId}` 가 이미 있으면 `already_applied` (이중 적립 없음).
- 중지(`enabled=false`) 중 완료된 주문은 다시 켜도 소급되지 않는다. 필요하면 해당 주문을 `ready` 로 되돌렸다가 `completed` 로 재수정.
- 우선 확인할 것: QR9/QR10(고객의 잔액 직접 쓰기 차단), QC3/QC5(멱등), QC13/QC14, QC15/QC16(불변식), QC8/QC10(fail-closed), QM2(앱을 건드리지 않고 Console 의 status 변경만으로 잔액 자동 갱신), QM9(Mock 결제 회귀 — checkout_page 호출부 삭제 영향), 관리자 `0.03` / `30` 입력 차단, 끄기 다이얼로그 문구, 로딩 중 `0 Q` 미표시.

## spec/design 대비 차이 · 참고
- `QoinRepository` 에 config 쓰기를 넣지 않고 `QoinConfigAdminRepository` 를 분리했다 (spec §10.1 의 "쓰기 메서드 없음" 보존, D4-d 추가분은 별도 인터페이스). 구현 클래스는 하나.
- `QoinConfigEntity.accrualRate` 는 nullable (spec 은 `double`). 문서 값이 유효하지 않은 경우를 표현하기 위함 — 고객 plate 는 `적립 중단` 문구, 관리자는 `설정 없음` 표기. CF 도 이 경우 적립하지 않으므로 일치.
- 입력 필터는 숫자와 점만 허용하고 소수 자릿수 제한은 검증에서 안내한다 (design 은 필터에서 소수 1자리 제한). 필터에서 막으면 `0.03` 붙여넣기가 조용히 무시되어 하한 에러가 안 보이기 때문.
- 날짜 표기는 디바이스 로컬 시간 (`ko_KR`). `owner_sales` 처럼 KST 고정이 아니다 — 고객 화면이라 로컬이 자연스럽다고 판단.
- 문서 갱신(spec §12 X1~X9: backlog, role_flows, data_ownership, entity_lifecycle)은 하지 않았다 — architect 후속.
- 임시 파일/코드 없음. `--target` 변경 빌드 없음. `dart format` 은 신규 파일만 개별 지정해 실행 (수정한 기존 파일은 포맷하지 않음).

## 미구현·보류
- 위젯 테스트 없음 (단위만). 실기기/에뮬레이터 UI 검증(QM1~QM10) 미수행.
- 인덱스 운영 환경 실측 보류 (위 참조).
- 설정 변경 이력(audit_trail H7)과 계층 적립률은 후속 task `qoin_accrual_rate_hierarchy` 범위 — 1차 관리자 화면은 그 작업에서 교체된다.

# temporary_closed_gate 구현 기록

기준: spec.md + design.md (C안, 디자이너 기본안 전부 수용). 배포 없음.

## 수정/신규 파일

**판정 (Dart/TS 동기)**
- `lib/core/utils/store_sellability.dart` — `storeGateReason` 신규, `canSellNow` = `reason==null` 파생(`temporaryClosed` 필수 인자). 상수 `kStoreNotSellable`/`kStoreTemporarilyClosed`.
- `functions/src/storeSellability.ts` — 동일 규칙 `storeGateReason` + 파생 `canSellNow`.
- 우선순위(양쪽 동일): 승인 조건 실패 -> `STORE_NOT_SELLABLE`(temporaryClosed 무시) / 아니면 휴업 -> `STORE_TEMPORARILY_CLOSED` / 아니면 null.

**서버**
- `functions/src/paymentGate.ts` — `GateReason`/`GATE_HTTPS_CODE`(failed-precondition)/`GATE_TEXT` 에 `STORE_TEMPORARILY_CLOSED`, G1 은 `storeGateReason` 사용(`store.temporaryClosed === true` 원시 읽기). 거절 로깅은 기존 `paymentGateRejections` 경로 그대로. `MENU_REASONS` 불변.
- `functions/src/migrateStoreApprovalMeta.ts` — `temporaryClosed:false` 로 호출(승인 전용 판정 유지).

**교차 골든**
- `test_fixtures/store_sellability_contract.json` — 기존 11행에 `temporaryClosed:false` + `expectReason`(결과 불변), 신규 5행(approved/legacy approved/pending+approvedAt + 휴업 -> CLOSED, pending 단독/status 부재 + 휴업 -> NOT_SELLABLE). `expect` 는 `expectReason==null` 과 동치로 유지.
- 하네스 동시 갱신: `test/core/payment_authority_contract_test.dart`, `functions/test/paymentAuthority.test.mjs` (둘 다 `expectReason` + `expect` 단언).

**Domain/Data**
- `checkout_validation.dart` — `StoreSellabilityInput.temporaryClosed`(기본 false), `StoreViolation.temporarilyClosed`.
- `checkout_validation_remote_data_source.dart` — `RawStoreFields.temporaryClosed = data['temporaryClosed'] == true` 원시 읽기. repository_impl 전달.
- `validate_checkout_use_case.dart` — `storeGateReason` 분기(CLOSED -> temporarilyClosed, 그 외 -> notSellable).
- `payment_failure.dart` — `storeTemporarilyClosed('STORE_TEMPORARILY_CLOSED')`.

**Presentation**
- `payment_failure_copy.dart` — 신규 case(design §3 문구, storeNotSellable 레이아웃 동일, 기존 문구 불변).
- `store_menu_header.dart` — `temporaryClosed` 시 `_OpenStatusText` 대신 pill(error 배경/onPrimary 글자, Semantics). `store_menu_page.dart` — 헤더 직하단 배너(error 8%), `liveStore` 기준. 메뉴카드/품절 오버레이 불변.
- `menu_item_detail_page.dart` `_BottomAction` — `watchedStoreProvider(menuItemKey.storeId)`(= storeId, key 가 이미 보유해 별도 인자 대신 사용)로 휴업 판정, 우선순위 휴업>품절>busy>required, 라벨 "임시 휴업중", 합계 muted, `_onAddPressed` 무음 재확인 return. 로딩/에러는 false.
- 카트: `CartBannerVariant.storeTemporarilyClosed`(+ `resolveCartBannerVariant`, 배너 문구), `_onCheckout` 스낵바 `StoreViolation` 별 분기.
- 점주 `store_operation_form_page.dart` — 토글 라벨/설명 갱신("임시 휴업"), `_submit` 가드(아래). `my_store_page.dart` 는 거짓이 된 주석만 정정.

## 점주 가드 조회 경로
`OrderRemoteDataSource.countByStoreAndStatuses`(storeId == + status whereIn, orderBy 없음, one-shot `get`) -> `OrderRepository.countStoreOrdersByStatuses` -> `CountActiveStoreOrdersUseCase`(paid/accepted/making/ready) -> `countActiveStoreOrdersUseCaseProvider`(order_di_providers). 신규 인덱스/Rules 불필요(기존 isStoreOwner orders 읽기, 동등+in 쿼리).
`_submit`: `_temporaryClosed && !existing.temporaryClosed` 일 때만 1회 조회. N>=1 -> `_temporaryClosed=false` 롤백(다이얼로그 표시 직전 setState) + `_submitting=false` + 확인 1개 안내 다이얼로그 + 폼 잔류. 조회 실패 -> 저장 진행 + 저장 직후 스낵바(design §4-3). 브랜드 가맹 분기: 운영폼은 `store_operation_form_page` 단일(`store_core_form_page` 는 생성 전용, 토글 없음) -> 추가 처리 없음.

## 추가 테스트
- `payment_failure_test`(9개 사유 표), `validate_checkout_use_case_test`(휴업/미승인 우선), `payment_authority_screens_test`(배너 variant), `functions/test/paymentGate.test.mjs`(G1 휴업 3행).

## 검증
- `flutter analyze`: No issues found
- `flutter test`: 927 all passed
- `functions npm test`: 349 pass / 0 fail
- dart format 전체 미실행(변경 블록만 수기 정렬).

## 배포 안내 (사용자 수행)
- functions 재배포 필요(paymentGate/storeSellability). 앱 재빌드. Rules/인덱스 변경 없음. `PAYMENT_GATE_MODE=enforce` 전제.
- 순서 주의: 구앱은 `STORE_TEMPORARILY_CLOSED` 토큰을 모르면 갈래 C(확인 필요)로 보임 -> functions 와 앱을 같이 배포 권장. 현재 휴업 매장 0건이라 즉시 영향 없음.

## tester 포인트
- Dart/TS `storeGateReason` 동기 + 골든 통과, 우선순위(미승인 > 휴업).
- 휴업 매장: 헤더 pill/배너, 상세 담기 비활성(옵션 선택은 가능), 카트 배너/스낵바 문구, 결제 실패 화면 copy.
- 점주: 진행 중 주문 있을 때 전환 차단+롤백, 0건 정상, 조회 실패 시 저장+스낵바, 이미 휴업 상태에서 다른 필드 수정은 조회 안 함.
- 미구현/보류: 없음. (TOCTOU/조회실패 수용은 확정 C안.)

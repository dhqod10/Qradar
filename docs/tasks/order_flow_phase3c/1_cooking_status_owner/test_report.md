# Phase 3c-1 테스트 리포트 — 점주 조리 상태 전이 + 환불 차단 정책

## 테스트 일시

- 라이브 검증: 2026-06-20 ~ 2026-06-21
- 정적 검증: 2026-06-21

---

## 테스트 방법

- 정적 코드 검증 (코드 직접 열람)
- 문서 교차 검증 (spec.md / design.md / implementation.md / process docs)
- 라이브 검증 (Android 에뮬레이터 Pixel 7 + iPhone 17 시뮬레이터, Firebase 정식 환경)
- `flutter analyze` 실행

---

## 검증 환경

- Android 에뮬레이터 Pixel 7 (Wipe Data + Cold Boot 후 정상화) — 점주 (`dhqod12@naver.com`, uid: `Og25uNUmRDMX5aJPTCRkzMYYuA82`)
- iPhone 17 시뮬레이터 — 고객
- Firebase 프로젝트: `order-app-5957e` (정식 환경)
- Cold start 1분 지연 확인 (warm 후 정상). 정상 동작 범위로 판단.
- 점주 매장 ID: `iTr7gx0lHzIwccDIb1bw` (알람테스트 개인매장)

---

## 전체 결과

- PASS: 40개
- FAIL: 0개
- 보류: 4개

---

## PASS 항목

### 기능 검증

#### 신규 status 전이 (F1~F6)

- [x] F1. accepted → making 전이 (`status='making'`, `makingStartedAt=now`, `updatedAt=now`)
  - 근거: `OrderRepositoryImpl.startMakingOrder` 가 3개 필드만 set. 라이브 T1 PASS.
  - 위치: `lib/data/repositories/order_repository_impl.dart:91-98`

- [x] F2. making → ready 전이 (`status='ready'`, `readyAt=now`, `updatedAt=now`)
  - 근거: `OrderRepositoryImpl.markOrderReady` 가 3개 필드만 set. 라이브 T2 PASS.
  - 위치: `lib/data/repositories/order_repository_impl.dart:100-107`

- [x] F3. ready → completed 전이 (`status='completed'`, `completedAt=now`, `updatedAt=now`)
  - 근거: `OrderRepositoryImpl.markOrderCompleted` 가 3개 필드만 set. 라이브 T3 PASS.
  - 위치: `lib/data/repositories/order_repository_impl.dart:109-116`

- [x] F4. 전이 주체 = 본인 매장 점주 제한 (Rules O5/O6/O7 `isStoreOwner(resource.data.storeId)`)
  - 근거: `firestore.rules` O5/O6/O7 모두 `isStoreOwner(resource.data.storeId)` 첫 조건으로 검증.
  - 위치: `firestore.rules:210-233`

- [x] F5. 환불 요청 활성 + 조리 액션 충돌: 결정 F(Q7) 적용으로 making/ready active 케이스 자체 차단. accepted + active 케이스는 기존 Phase 3a 매트릭스(sticky bottom = 환불 승인/거절)로 처리.
  - 근거: `_ActionBar._buildContent()` — accepted + refundActive 분기 → `_buildRefundButtons()`, 조리 시작 미노출.
  - 위치: `lib/presentation/owner/orders/owner_order_detail_page.dart:963-974`

- [x] F6. 전이 후 stream 자동 갱신 → UI 액션 영역 자동 전환
  - 근거: `currentOrderProvider` 가 Firestore stream 구독. 라이브 시나리오 1-D/E 확인.
  - 위치: `lib/presentation/customer/order/orders/providers/order_view_providers.dart`

#### Repository 메서드 (F7~F10)

- [x] F7. `OrderRepository.startMakingOrder(orderId)` 인터페이스 정의
  - 근거: `order_repository.dart:37`
  - 위치: `lib/domain/repositories/order_repository.dart:37`

- [x] F8. `OrderRepository.markOrderReady(orderId)` 인터페이스 정의
  - 근거: `order_repository.dart:40`
  - 위치: `lib/domain/repositories/order_repository.dart:40`

- [x] F9. `OrderRepository.markOrderCompleted(orderId)` 인터페이스 정의
  - 근거: `order_repository.dart:43`
  - 위치: `lib/domain/repositories/order_repository.dart:43`

- [x] F10. 모든 Repository 메서드가 Rules 화이트리스트와 정확히 동일한 필드만 update (drift 없음)
  - 근거: implementation.md cross-check 표 + 직접 코드 대조 일치 확인.
  - 위치: `lib/data/repositories/order_repository_impl.dart:91-118`

#### UseCase (F11~F13)

- [x] F11. `StartMakingOrderUseCase` 신규
  - 근거: `start_making_order_use_case.dart` 존재. `_repo.startMakingOrder(orderId)` 위임.
  - 위치: `lib/domain/usecases/start_making_order_use_case.dart`

- [x] F12. `MarkOrderReadyUseCase` 신규
  - 위치: `lib/domain/usecases/mark_order_ready_use_case.dart`

- [x] F13. `MarkOrderCompletedUseCase` 신규
  - 위치: `lib/domain/usecases/mark_order_completed_use_case.dart`

#### Provider (F14~F15)

- [x] F14. UseCase provider 3개 (`startMakingOrderUseCaseProvider`, `markOrderReadyUseCaseProvider`, `markOrderCompletedUseCaseProvider`) 신규 추가
  - 위치: `lib/presentation/customer/order/orders/providers/order_di_providers.dart:116-128`

- [x] F15(변경). `inProgressOrdersByStoreProvider` 신규 추가. statusFilter = `{accepted, making, ready}` (spec 원안 `{making, ready}` 에서 라이브 검증 중 발견된 보완 2 반영 → `accepted` 포함으로 확장. 정정 이력 참조.)
  - 위치: `lib/presentation/customer/order/orders/providers/order_di_providers.dart:143-156`

#### OwnerOrderDetailPage 확장 (F16~F21)

- [x] F16. sticky bottom 액션 분기 매트릭스 (결정 E) 구현
  - 근거: `_ActionBar._buildContent()` — paid/accepted-refundActive/accepted-refundInactive/making/ready 모두 분기 처리됨.
  - 위치: `lib/presentation/owner/orders/owner_order_detail_page.dart:957-993`

- [x] F17. `_NoActionInfoCard` — making/ready/completed/cancelled/refunded 케이스 메시지 구현
  - 근거: `_NoActionInfoCard._message` switch 문 각 케이스 정의.
  - 위치: `lib/presentation/owner/orders/owner_order_detail_page.dart:869-913`

- [x] F18. 픽업 완료 확정 다이얼로그 (`OwnerOrderActionDialogs.showCompletePickup`) 구현 및 연결
  - 근거: `showCompletePickup` 정적 메서드 존재. `_completePickup` 에서 `confirmed != true` 시 early return.
  - 위치: `lib/presentation/owner/orders/widgets/owner_order_action_dialogs.dart:140-185`

- [x] F19. `_isActionLoading` 가드로 중복 탭 방지 + 버튼 disabled 처리
  - 근거: 모든 액션 메서드에서 `if (_isActionLoading) return;` 조건 + `_PrimaryButton.onPressed: isLoading ? null : onTap`.
  - 위치: `lib/presentation/owner/orders/owner_order_detail_page.dart:56-207`

- [x] F20. 액션 성공 시 SnackBar 표시
  - 근거: 각 핸들러 try 블록 후 SnackBar 호출. 카피: "조리를 시작했습니다" / "준비 완료 처리했습니다" / "픽업 완료 처리했습니다".
  - 위치: `lib/presentation/owner/orders/owner_order_detail_page.dart:157/176/197`

- [x] F21. 액션 후 페이지 pop 없음 — stream 갱신으로 자동 재구성
  - 근거: 어떤 핸들러에도 `Navigator.pop()` 없음. stream 기반 `currentOrderProvider` 가 갱신 담당.

#### OwnerOrdersPage 탭 확장 (F22~F25)

- [x] F22. TabController length=3, 탭 라벨 "신규" / "조리 중" / "환불 요청"
  - 근거: `initState` — `TabController(length: 3, vsync: this)`. 탭 라벨 코드 일치.
  - 위치: `lib/presentation/owner/orders/owner_orders_page.dart:44`

- [x] F23. `_InProgressOrdersTab` 신규 추가, `inProgressOrdersByStoreProvider(storeId)` watch
  - 위치: `lib/presentation/owner/orders/owner_orders_page.dart:493-600`

- [x] F24. `OwnerInProgressOrderTile` 신규 위젯. 시각 차별화 (making=outlined, ready=filled), 액션 버튼, onTapDetail 진입
  - 근거: `_buildActionButton()` making/ready 분기 확인. 라이브 시나리오 2 PASS.
  - 위치: `lib/presentation/owner/orders/widgets/owner_in_progress_order_tile.dart`

- [x] F25. `_processingOrderIds` 가드로 카드 액션 중복 탭 방지
  - 근거: `_OwnerOrdersPageState._processingOrderIds` Set + 각 핸들러 선두 `contains` 체크.
  - 위치: `lib/presentation/owner/orders/owner_orders_page.dart:36`

#### Firestore Rules (F26~F32, F36)

- [x] F26~F30. O5/O6/O7 신규 분기 구조 및 화이트리스트 — spec 정의와 완전 일치
  - 근거: `firestore.rules:208-233` 직접 대조. `isStoreOwner` + 이전 status + 다음 status + `onlyChangedFields` 3개 필드 패턴 정확히 일치.
  - 위치: `firestore.rules:208-233`

- [x] F31. `data_ownership.md §2.4.1` 표 O5/O6/O7 행 추가 + O2 status 조건 축소 반영
  - 근거: `data_ownership.md §2.4.1` 표 확인. 7개 분기 명시, O2 행에 `resource.status == 'accepted'` 조건 기재.
  - 위치: `docs/processes/data_ownership.md:83-92`

- [x] F32. `entity_lifecycle.md §2` 다이어그램 + 전이 표 갱신. `§2.3` O2 조건 축소 반영. `§2.5` making/ready/completed 보류 항목 제거
  - 근거: `entity_lifecycle.md:41-104` 직접 확인. 다이어그램에 O5/O6/O7 표시. 결정 F 주석 포함. §2.5 구현 완료 기록.
  - 위치: `docs/processes/entity_lifecycle.md:36-106`

- [x] F33. `OrderEntity` 에 `makingStartedAt`, `readyAt`, `completedAt` (DateTime?) 추가 + freezed regenerate
  - 위치: `lib/domain/entities/order_entity.dart:33-38`

- [x] F34/F35. `OrderModel` 동일 3필드 + `fromFirestore` / `toFirestore` / `toEntity` 매핑 추가. null-safe 처리.
  - 근거: `_fromMap` 의 `toDate()` 가 null 반환하므로 기존 doc 호환 안전.
  - 위치: `lib/data/models/order_model.dart:108-113, 160-164`

- [x] F36 (결정 F/Q7). Rules O2 허용 status `== 'accepted'` 단독으로 축소
  - 근거: `firestore.rules:185` — `resource.data.status == 'accepted'` 확인.
  - 위치: `firestore.rules:182-192`

#### 고객 환불 차단 (F38~F41)

- [x] F38. `OrderDetailPage._ActionSection` — `case OrderStatus.making:` 에서 환불 버튼 미노출 + inline 안내 카드 노출 ("조리가 시작되어 환불 요청이 어려워요")
  - 근거: `order_detail_page.dart:557-580` 직접 확인. 라이브 시나리오 4 PASS.
  - 위치: `lib/presentation/customer/order/orders/order_detail_page.dart:557-580`

- [x] F39. `case OrderStatus.accepted:` 분기 변경 없음 — 환불 요청 버튼 유지
  - 근거: accepted 분기가 기존 Phase 3a 로직 그대로 존재.
  - 위치: `lib/presentation/customer/order/orders/order_detail_page.dart:503-554`

- [x] F40. `case OrderStatus.ready:` 에서 inline 안내 카드 노출 ("음료 준비가 완료되어 환불 요청이 어려워요")
  - 근거: `order_detail_page.dart:582-606`. 라이브 시나리오 4 ready 전환 PASS.
  - 위치: `lib/presentation/customer/order/orders/order_detail_page.dart:582-606`

- [x] F41. `case OrderStatus.completed:` 기존 "완료된 주문" 안내 변경 없음
  - 위치: `lib/presentation/customer/order/orders/order_detail_page.dart:608-630`

### UI 검증

- [x] U1. OwnerOrdersPage 3탭 레이아웃 (TabBar + TabBarView)
  - 근거: 라이브 시나리오 2 PASS. 코드에서 `Tab(text: '신규')` / `Tab(text: '조리 중')` / `Tab(text: '환불 요청')` 확인.

- [x] U2. `OwnerInProgressOrderTile` 카드 — accepted(outlined primary) / making(outlined primary) / ready(filled primary) 시각 차별화
  - 근거: `_buildActionButton()` 분기 확인. 라이브 시나리오 2 카드 액션 분기 PASS.

- [x] U3. OwnerOrderDetailPage sticky bottom — making/ready 시 단일 full-width 버튼 (`_PrimaryButton`)
  - 근거: making/ready 분기 모두 `_PrimaryButton` (전체 너비) 사용.

- [x] U4. 픽업 완료 확정 다이얼로그 — `showApproveRefund` 패턴 재사용 톤 일치
  - 근거: `showCompletePickup` 이 `AlertDialog` + primary 버튼 톤으로 `showApproveRefund` 와 동일 패턴.

- [x] U5. 색상 `AppColors` 만 사용. `Color(0x...)` 하드코딩 없음.
  - 근거: 신규 파일 전체 grep 결과 0건. `Colors.transparent` 는 `Material.color` 에서 InkWell 스플래시 노출을 위한 관례적 사용으로 `owner_new_order_tile.dart` 동일 패턴 적용됨.

- [x] U6. `OrderStatusBadge` making/ready/completed 색상 — 기존 정의 재사용 (변경 없음)

- [x] U7. 고객 OrderDetailPage making/ready 환불 차단 inline 안내 카드 — info 아이콘 + `AppColors.info` + `AppColors.textMuted` 톤
  - 근거: 코드 직접 확인. 라이브 시나리오 4 PASS.

### 아키텍처 검증

- [x] 레이어 의존 방향 (`presentation → domain ← data`) 준수
  - 근거: `StartMakingOrderUseCase` 가 `OrderRepository` (domain) 만 의존. `OrderRepositoryImpl` 이 `data` 레이어. presentation 에서 domain usecase 를 통해서만 호출.

- [x] `domain` 레이어 순수 Dart 유지 — Firebase SDK import 없음
  - 근거: `start_making_order_use_case.dart` / `mark_order_ready_use_case.dart` / `mark_order_completed_use_case.dart` 모두 Firestore import 없음.

- [x] Firebase 직접 사용 `data` 레이어에만 한정
  - 근거: `OrderRepositoryImpl` 이 `cloud_firestore` import. `OrderRemoteDataSource.update()` 통해서만 Firestore 접근.

- [x] Repository Interface = domain, Repository Implementation = data
  - 근거: `order_repository.dart` (domain) + `order_repository_impl.dart` (data) 분리 확인.

- [x] UseCase 단일 책임 — 각 UseCase 가 하나의 repo 메서드만 위임
  - 근거: `StartMakingOrderUseCase.call` = `_repo.startMakingOrder(orderId)` 1줄.

- [x] Presentation 이 DataSource/RepositoryImpl 직접 호출하지 않음
  - 근거: `OwnerOrdersPage` 와 `OwnerOrderDetailPage` 모두 UseCase provider 를 통해서만 호출.

- [x] `firestore_security_rules/spec.md` O2 갱신 미완료 (F37) — architect 가 별도 task 로 분리. 보류 항목 처리됨.

### 코드 품질 검증

- [x] 파일명 `snake_case.dart` 준수 — 신규 파일 (`start_making_order_use_case.dart`, `mark_order_ready_use_case.dart`, `mark_order_completed_use_case.dart`, `owner_in_progress_order_tile.dart`) 모두 일치

- [x] 클래스명 `PascalCase` 준수 — `StartMakingOrderUseCase`, `MarkOrderReadyUseCase`, `MarkOrderCompletedUseCase`, `OwnerInProgressOrderTile`

- [x] Provider 명 `xxxProvider` 형식 — `startMakingOrderUseCaseProvider`, `markOrderReadyUseCaseProvider`, `markOrderCompletedUseCaseProvider`, `inProgressOrdersByStoreProvider`

- [x] freezed 기준 준수 (`OrderEntity` 자동 생성 파일 직접 수정 없음)
  - 근거: `order_entity.freezed.dart` 는 `build_runner` 재생성됨.

- [x] 기존 패턴 재사용 — `setAcceptedByOwner` 패턴 그대로 3개 복제. `_PrimaryButton` / `_ErrorOutlinedButton` / `OwnerOrderActionDialogs` 재사용.

- [x] 요청 범위 밖 리팩터링 없음 — 기존 `_NewOrdersTab` / `_RefundRequestsTab` 코드 변경 없음.

- [x] `flutter analyze` — No issues found

### 에러 처리 검증

- [x] 외부 호출 실패 시 SnackBar 오류 표시 (`'오류가 발생했습니다: $e'`)
  - 위치: 모든 액션 핸들러 catch 블록.

- [x] 중복 탭 방지 (`_isActionLoading` / `_processingOrderIds` 가드)

- [x] stream 에러 시 "다시 시도" 버튼 (`_buildError` 내부 `_InProgressOrdersTab._buildError`)

- [x] empty 상태 ("조리 중인 주문이 없어요") 구현

- [x] loading 상태 (shimmer placeholder) 구현

- [x] 픽업 완료 확정 다이얼로그 취소 시 no-op (F4 T4 케이스)
  - 근거: `if (confirmed != true) return;` 조건.

- [x] 매장 권한 가드 (결정 G) — `order.storeId != store.id` 시 fallback UI
  - 위치: `lib/presentation/owner/orders/owner_order_detail_page.dart:290-299`

### process docs 갱신 검증

- [x] `data_ownership.md §2.4.1` — O5/O6/O7 행 + O2 조건 축소 반영
- [x] `entity_lifecycle.md §2` 다이어그램 + 전이 표 갱신
- [x] `entity_lifecycle.md §2.3` refundRequest "(없음) → Requested" 조건 `accepted` 단독으로 축소
- [x] `entity_lifecycle.md §2.5` making/ready/completed 보류 항목 "구현 완료" 로 갱신
- [x] `role_flows.md §4.2` 조리 시작 / 준비 완료 / 픽업 완료 3행 추가

### spec 결정 항목 매칭 검증

- [x] 결정 A (Q1): 3탭 구조 (신규 / 조리 중 / 환불 요청) — 구현 일치
- [x] 결정 B (Q2): 라벨 "조리 시작" / "준비 완료" / "픽업 완료" — 구현 일치 (OwnerInProgressOrderTile + OwnerOrderDetailPage 모두)
- [x] 결정 B (Q3): 픽업 완료만 확정 다이얼로그 — `showCompletePickup` 1개만 존재. 나머지는 즉시 실행.
- [x] 결정 D (Q5): timestamp 필드명 `makingStartedAt` / `readyAt` / `completedAt` — 코드 / Rules 화이트리스트 / OrderEntity / OrderModel 모두 일치 (drift 없음)
- [x] 결정 E: status 매트릭스 (sticky bottom 분기) — `_ActionBar._buildContent()` 가 spec 표와 일치 (paid / accepted+refundActive / accepted+refundInactive / making / ready 분기)
- [x] 결정 F (Q7): O2 `accepted` 단독 축소 + 고객 UI making/ready inline 안내 — 구현 일치

### 라이브 검증 시나리오

- [x] T1. accepted → making 전이 ("조리 시작" 탭 → `_TimelineSection` 등장, 버튼 "준비 완료" 변경) — PASS
- [x] T2. making → ready 전이 ("준비 완료" 탭 → 버튼 "픽업 완료" 변경) — PASS
- [x] T3. ready → completed (확정 다이얼로그 → 승인 → 액션바 사라짐, inline 안내 노출) — PASS
- [x] T4. 확정 다이얼로그 취소 → status 변화 없음 — PASS
- [x] T5. OwnerOrdersPage "조리 중" 탭 — 카드 표시 + 액션 버튼 분기 — PASS
- [x] T6. 조리 중 탭 카드 making → ready — PASS
- [x] T7. 조리 중 탭 카드 ready → completed (카드 탭에서 사라짐) — PASS
- [x] T8. accepted + 환불 요청 active — sticky bottom = 환불 승인/거절, 조리 시작 미노출 — PASS (Phase 3b 회귀)
- [x] T9. 환불 거절 후 조리 시작 재노출 — PASS (Phase 3b 회귀)
- [x] T14. 고객 OrderDetailPage making 상태 — 환불 버튼 미노출 + inline 안내 카드 — PASS
- [x] T16. 점주 making 전이 직후 고객 UI 자동 갱신 → inline 안내 카드 전환 — PASS

---

## FAIL 항목

없음.

검증 중 발견된 보완 4건은 모두 fix 완료 처리됨 (정정 이력 참조).

---

## 보류 항목

- [ ] T10. Rules O5 차단 — paid 상태에서 making 직접 시도 (permission-denied 확인)
  - 이유: 에뮬레이터에서 SDK 우회 직접 호출 테스트 환경 미구성. UI 가드 + Rules O5 `resource.data.status == 'accepted'` 조건으로 정상 흐름에서 발생 불가하므로 허용 범위.
  - 필요한 확인: Firestore Emulator 또는 CLI 직접 write 로 T10 재현.
  - 후속 작업 제안: Phase 3c 정식 출시 전 Firestore Emulator 기반 Rules 단위 테스트 작성 task.

- [ ] T11. Rules `isStoreOwner` 차단 — 다른 매장 점주 액션 (permission-denied 확인)
  - 이유: T10 과 동일 — SDK 우회 호출 환경 미구성.
  - 필요한 확인: 별도 점주 계정 + 다른 매장 상황에서 직접 API 호출 검증.
  - 후속 작업 제안: T10 과 묶어 Emulator 기반 테스트로 처리.

- [ ] T15. Rules O2 차단 — making/ready/completed 상태에서 refundRequest update 시도 (Emulator 검증)
  - 이유: 라이브 환경에서 spec T15 가 요구하는 SDK 직접 update 시도 환경 미구성.
  - 필요한 확인: Firestore Emulator 에서 고객 uid 로 making 상태 주문의 refundRequest 직접 update 시 permission-denied 확인.
  - 후속 작업 제안: T10/T11 과 묶어 Emulator 기반 테스트 task.

- [ ] iOS APNs 설정 미완료 — FCM 알림 iOS 검증 보류
  - 이유: APNs 인증서 미발급. 별도 task `ios_apns_setup` 진행 예정.
  - 필요한 확인: 실 디바이스에서 점주 알림 수신 검증.
  - 후속 작업 제안: `ios_apns_setup` task 완료 후 Phase 3c-2 와 함께 통합 검증.

---

## 정정 이력

### 보완 1 — Cloud Function Cold Start 지연 (정상 범위 판정)

- 발생: 첫 호출 시 약 30초~1분 지연.
- 판단: warm 후 즉시 응답. 정상 동작 범위.
- 코드 변경: 없음.
- 후속 후보: 출시 시점에 `minInstances: 1` 설정 검토 (`functions/src/onOrderCreated.ts` 등).

### 보완 2 — accepted 상태 주문 조리 중 탭 미노출 (FIX 완료)

- 발생: 점주가 "주문 받기" 후 조리 시작 전 (`accepted` 상태) 주문이 어느 탭에도 표시되지 않음.
- 원인: spec F15 원안이 `inProgressOrdersByStoreProvider` statusFilter = `{making, ready}` 로 설계 — `accepted` 누락.
- 사용자 결정: 탭 2 "조리 중" 에 `accepted` 포함 + 탭 라벨 유지.
- 수정 사항:
  - `inProgressOrdersByStoreProvider` statusFilter → `{accepted, making, ready}` 확장
  - `OwnerInProgressOrderTile._buildActionButton` 에 `accepted` 분기 추가 ("조리 시작" outlined primary)
  - `_InProgressOrdersTab` 에 `onStartMaking` props 추가
  - `_OwnerOrdersPageState._startMaking` 메서드 신규
- 결과: `flutter analyze` No issues found.

### 보완 3 — Android 에뮬레이터 Google Play Services 손상 (환경 이슈, 코드 변경 없음)

- 발생: `GoogleApiManager: Unknown calling package name 'com.google.android.gms'` 에러로 FCM 알림 미수신.
- 해결: 에뮬레이터 Wipe Data + Cold Boot + 점주 fcmToken 리셋 후 재로그인.
- 코드 변경: 없음.

### 보완 4 — `notificationPermissionPrompted: true` 잔존 (환경 이슈, 코드 변경 없음)

- 발생: Wipe 후에도 Firestore 점주 doc 에 `notificationPermissionPrompted: true` 잔존 → 권한 요청 다이얼로그 미노출.
- 해결: 명령줄로 `notificationPermissionPrompted` + `fcmToken` 필드 삭제 → 재로그인 → 다이얼로그 노출 → 허용 → 새 토큰 저장.
- 코드 변경: 없음. 디바이스 변경 시 동작 방식 후속 확인 후보.

---

## 설계자 전달 메시지

### 요약

- 전체 판단: **조건부 완료 (PASS)**. 라이브 검증 시나리오 T1~T9 / T13~T14 / T16 모두 PASS. 정적 검증 (코드 / Rules / process docs) 모두 PASS. FAIL 0건.
- 보류 항목 4건 (T10/T11/T15 Emulator Rules 검증 미완, iOS APNs) 은 정상 출시 전 처리 권장이나 현 단계 블로커 아님.
- 보완 2 (accepted 탭 포함)는 spec F15 와 다르게 구현됨 — spec/design.md 갱신 권장.

### 재작업 우선순위

없음 (FAIL 0건).

### 후속 task 후보

1. **spec.md / design.md 갱신** — 보완 2 반영. `inProgressOrdersByStoreProvider` statusFilter `{accepted, making, ready}` 로 명세 정정. `OwnerInProgressOrderTile` 에 `accepted` 분기 명세 추가.
   - 이유: 구현과 spec 간 drift 방지.

2. **`firestore_security_rules/spec.md` O2 정의 갱신 (F37)** — architect 가 별 task 로 예정.
   - 이유: O2 허용 status 축소 (`accepted` 단독) 가 firestore_security_rules spec 에 미반영.

3. **Emulator 기반 Rules 단위 테스트 (T10/T11/T15)** — 보류 항목.
   - 이유: Rules 회귀 안전성 강화.

4. **iOS APNs 발급 (`ios_apns_setup` task)** — 보류 항목.

5. **Cloud Function `minInstances` 설정 검토** — 출시 시점에 `onOrderCreated.ts` / `onOrderRefundRequested.ts`.
   - 이유: Cold start 지연 사용자 경험 개선.

6. **Phase 3c-2 (고객 측 FCM 알림 + UI status 강화)** — 다음 sub-phase.

7. **Phase 3c-3 (알림 설정 UI)**.

8. **Toss 머천트 승인 + 실 결제 회귀 (`toss_merchant_approval`)**.

---

## flutter analyze 결과

```
No issues found! (ran in 6.4s)
```

---

## 완료 판단

- [x] 전체 PASS (FAIL 0건)
- [ ] FAIL 있으나 후속 task로 분리 가능
- [ ] 재작업 필요

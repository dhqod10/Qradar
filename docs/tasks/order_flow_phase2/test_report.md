# order_flow_phase2 테스트 리포트

## 테스트 일시

- 2026-04-30

---

## 테스트 방법

- 정적 코드 검증 (파일 존재 여부, 내용 직접 확인)
- 문서 교차 검증 (spec.md / design.md / implementation.md 대조)
- `flutter analyze` (0 issue 확인)
- `flutter test` — Phase 2 전용 테스트 파일 없음 (보류 항목 참조)

---

## 전체 결과

- PASS: 39개
- FAIL: 0개 (FAIL-1, FAIL-2 모두 2026-04-30 수정 완료)
- 보류: 5개

---

## PASS 항목

### 기능 검증

- [x] 추천 섹션 3종 — QuickReorderSection / FrequentStoresSection / FrequentMenuItemsSection 신규 작성 완료
  - 근거: spec.md 결정 B
  - 위치: `lib/presentation/customer/home/widgets/quick_reorder_section.dart`, `frequent_stores_section.dart`, `frequent_menu_items_section.dart`

- [x] 비로그인 / OrderLog 0건 시 섹션 숨김
  - 근거: spec.md 결정 G. `_rawOrderLogsProvider` 에서 uid null → `Stream.value([])`. 각 섹션 data.isEmpty → `SizedBox.shrink()`.
  - 위치: `recommendation_providers.dart` L68-74, 각 섹션 위젯 data 분기

- [x] 알고리즘 임계값 상수 파일 존재 및 적용
  - 근거: spec.md 결정 F. `frequentStoreMinVisits = 5` (방문 5회), `frequentMenuPairMinVisits = 3` (주문 3회), `lookbackDays = 30`, `favoriteScoreBoost = 5`
  - 위치: `lib/core/constants/recommendation_thresholds.dart`

- [x] favoriteScoreBoost = 5 적용 (additive boost)
  - 근거: spec.md 결정 F 잠정안. UseCase 내 `isFav ? favoriteScoreBoost : 0` 계산.
  - 위치: `get_frequent_stores_use_case.dart` L59-60, `get_frequent_menu_items_use_case.dart` L69-70

- [x] lookbackDays 30 적용
  - 근거: spec.md 결정 F. `frequentStoreLookbackDays = 30`, `frequentMenuPairLookbackDays = 30`
  - 위치: `recommendation_thresholds.dart` L24, L30

- [x] 즐겨찾기 단독(visitCount=0) 노출 X 가드
  - 근거: spec.md 결정 F "임계값 미달 항목은 노출 X". visitCountByStore 루프 외부에서 자연 제외.
  - 위치: `get_frequent_stores_use_case.dart` L46-52

- [x] QuickReorderCard onTap — 카트 충돌 다이얼로그 → clearCart + addItem → CartPage push 흐름
  - 근거: spec.md "다시 주문하기" 카드 탭 동작. `_onTap()` 내 충돌 검사 → `showReplaceCartDialog` → `clearCartUseCaseProvider` → `addToCartUseCaseProvider` 루프 → `CartPage push`.
  - 위치: `quick_reorder_section.dart` L209-271

- [x] FrequentStoreCard onTap → StoreMenuPage push
  - 근거: spec.md "자주 찾는 매장 카드 탭 → StoreMenuPage(storeId) push"
  - 위치: `frequent_stores_section.dart` L70-75

- [x] FrequentMenuCard onTap → StoreMenuPage push
  - 근거: spec.md / design.md "StoreMenuPage 진입까지만 (자동 메뉴 상세 open 안 함)"
  - 위치: `frequent_menu_items_section.dart` L76-82

- [x] OrderLog 컬렉션 경로 `users/{uid}/orderLogs/{logId}` 일치 (umbrella spec 결정 E)
  - 근거: `OrderLogRemoteDataSource._logs(uid)` 에서 `collection('users').doc(uid).collection('orderLogs')` 구성
  - 위치: `order_log_remote_data_source.dart` L16-19, `firestore_paths.dart` 내 `orderLogs = 'orderLogs'`

- [x] WriteOrderLogUseCase Provider 등록 확인
  - 근거: spec.md "Phase 3 hook 용 wrapper". `writeOrderLogUseCaseProvider` 등록됨.
  - 위치: `recommendation_providers.dart` L61-63

- [x] paidAt desc 정렬 (Firestore `orderBy`)
  - 근거: spec.md "paidAt desc 정렬". `watchUserLogs` 내 `.orderBy('paidAt', descending: true)`.
  - 위치: `order_log_remote_data_source.dart` L23-28

- [x] uid null → UnauthenticatedException
  - 근거: spec.md "uid null → UnauthenticatedException". `appendLog` 에서 uid null 체크 후 throw.
  - 위치: `order_log_repository_impl.dart` L23-26

- [x] OrderLog stream 에러 → 빈 List fallback (SizedBox.shrink)
  - 근거: spec.md "OrderLog stream 에러 → 섹션 숨김 + 콘솔 로그"
  - 위치: 각 섹션 위젯 error 분기 → `SizedBox.shrink()` + `debugPrint`

- [x] phase1_seed_data.dart `orderLogs(uid, now)` 메서드 존재 확인
  - 근거: implementation.md 요구사항. `static List<Map<String,dynamic>> orderLogs({required String uid, required DateTime now})` 존재.
  - 위치: `lib/dev/seed/phase1_seed_data.dart` L272

- [x] phase1_seed.dart `runPhase1Seed({uid})` 시그니처 확인
  - 근거: implementation.md 요구사항. `Future<SeedResult> runPhase1Seed({FirebaseFirestore?, String? uid})` 존재.
  - 위치: `lib/dev/seed/phase1_seed.dart` L42

- [x] SeedResult.orderLogCount 필드 및 summary 노출
  - 근거: implementation.md 요구사항. `orderLogCount` 필드, `summary()` 에서 `'orderLogs: $orderLogCount'` 출력.
  - 위치: `lib/dev/seed/phase1_seed.dart` L17, L31

- [x] dev_seed_trigger.dart ConsumerWidget 변환 + uid 주입
  - 근거: implementation.md 요구사항. `ConsumerWidget` 으로 변환, `ref.read(authProvider).asData?.value?.uid` 전달.
  - 위치: `lib/dev/seed/dev_seed_trigger.dart` L12, L67

- [x] 시드 다이얼로그 본문 "주문 로그 7건" 명시
  - 근거: spec.md "시드 다이얼로그 본문에 주문 더미 포함 명시"
  - 위치: `dev_seed_trigger.dart` L40-43 — "주문 로그 7건을 Firestore 에 기록합니다"

- [x] home_page.dart sliver 리스트에 추천 섹션 3종 추가 (NearbyStoresSection 위)
  - 근거: spec.md 결정 A "홈 상단(NearbyStoresSection 위) 노출"
  - 위치: `home_page.dart` L105-108

- [x] DEV_ONLY_SEED 주석 마커
  - 근거: spec.md "// DEV_ONLY_SEED 주석 마커 정책 유지"
  - 위치: `phase1_seed_data.dart` L1, `phase1_seed.dart` L1, `dev_seed_trigger.dart` L1

### UI 검증

- [x] SectionTitle 재사용 — "다시 주문하기" / "자주 찾는 매장" / "자주 찾는 메뉴" 헤더 톤 일관성
  - 근거: design.md "SectionTitle(title, trailing?) 그대로 재사용"
  - 위치: 각 섹션 위젯 _ContentColumn / _LoadingColumn

- [x] QuickReorderCard 구조 — 카드 폭 240 / 높이 196, pill 뱃지(IgnorePointer), paidAt 상대시간, 총액, 매장명 아이콘
  - 근거: design.md QuickReorderCard 명세
  - 위치: `quick_reorder_section.dart` L135-205

- [x] FrequentStoreCard — visitCount 이미지 좌상단 pill 뱃지 + 본문 "최근 N회 방문" 라벨
  - 근거: design.md FrequentStoreCard 명세
  - 위치: `frequent_stores_section.dart` L157-213

- [x] shimmer loading 구현 (3섹션 공통)
  - 근거: design.md Loading 상태 명세. shimmer base=AppColors.surface, highlight=AppColors.surfaceElevated
  - 위치: 각 섹션 _LoadingColumn

- [x] empty/error → SizedBox.shrink() 반환
  - 근거: design.md Empty/Error 상태 "섹션 자체 숨김"
  - 위치: 각 섹션 data.isEmpty 분기, error 분기

- [x] AnimatedSwitcher 200ms 페이드 효과 (3섹션 공통)
  - 근거: design.md "AnimatedSwitcher(duration: 200ms, curve: Curves.easeOut)"
  - 위치: `quick_reorder_section.dart` L44-50, `frequent_stores_section.dart` L39-45, `frequent_menu_items_section.dart` L35-41

- [x] 가로 스크롤 ListView (3섹션 공통) — padding 20, separator 12
  - 근거: design.md 가로 스크롤 채택, padding/separator 명세
  - 위치: 각 섹션 _ContentColumn

- [x] 매장 충돌 다이얼로그 톤 — Phase 1b 동일 (backgroundColor surfaceElevated, borderRadius 16, 취소=textMuted, 비우고 시작=error)
  - 근거: design.md "Phase 1b `_confirmReplaceCart` 톤 그대로 재사용"
  - 위치: `replace_cart_dialog.dart`

- [x] paidAt 상대시간 4단계 포맷 — 오늘/어제/N일 전/N주 전/yyyy.MM.dd
  - 근거: design.md 4단계 분기 명세
  - 위치: `relative_time_formatter.dart` L16-25

- [x] 섹션 내 trailing 24px spacer 포함 (data/loading 공통)
  - 근거: design.md "각 섹션 위젯이 자기 위 24px spacer 를 포함. 비어 있으면 SizedBox.shrink()." 섹션 각각 Column 마지막에 `SizedBox(height: 24)` 포함, empty/error 시 Column 전체 미렌더.
  - 위치: 각 섹션 _ContentColumn / _LoadingColumn 마지막 SizedBox(height: 24)

### 아키텍처 검증

- [x] cloud_firestore import — domain / presentation 레이어 0건
  - 근거: CLAUDE.md 절대 규칙 "Firebase / 외부 SDK 직접 사용은 data 레이어에서만"
  - 위치: grep 결과 domain / presentation 폴더 내 cloud_firestore import 없음

- [x] Repository Interface domain / Impl data 위치
  - 근거: CLAUDE.md / architecture.md
  - 위치: `domain/repositories/order_log_repository.dart` (interface), `data/repositories/order_log_repository_impl.dart` (impl)

- [x] DataSource data 레이어 한정
  - 근거: CLAUDE.md 절대 규칙
  - 위치: `data/datasources/remote/order_log_remote_data_source.dart`

- [x] UseCase domain 레이어, score 계산 UseCase 내 순수 함수로 처리
  - 근거: spec.md "score 계산은 UseCase 안에서 (domain layer, 순수 함수)"
  - 위치: `GetFrequentStoresUseCase.compute()`, `GetFrequentMenuItemsUseCase.compute()`

- [x] uid getter callback 패턴 — Phase 1c 동일
  - 근거: spec.md "currentUidGetter callback 패턴"
  - 위치: `OrderLogRepositoryImpl` 생성자, Provider 내 `String? currentUid()` 클로저

### 코드 품질 검증

- [x] snake_case 파일명 / PascalCase 클래스명
  - 위치: 전체 신규 파일

- [x] freezed 적용 (Entity 4종)
  - 근거: spec.md "freezed 적용"
  - 위치: `frequent_store_entity.dart`, `frequent_menu_item_entity.dart`, `quick_reorder_candidate_entity.dart`, `.freezed.dart` 파일 존재 확인

- [x] Provider 명명 규칙 (`xxxProvider`)
  - 위치: `recommendation_providers.dart` 전체

- [x] replaceCart 다이얼로그 공통 헬퍼화
  - 근거: spec.md / design.md "Phase 1b `_confirmReplaceCart` 추출 권장"
  - 위치: `lib/presentation/customer/cart/widgets/replace_cart_dialog.dart`

### 에러 처리 검증

- [x] 비로그인 시 모든 stream `Stream.value([])` 반환
  - 근거: spec.md "모든 UseCase 는 비로그인 시 Stream.value(const []) 반환"
  - 위치: `recommendation_providers.dart` `_rawOrderLogsProvider` L68-74

- [x] QuickReorderCard 실패 SnackBar
  - 근거: design.md "replaceCart 비동기 실패 시 SnackBar"
  - 위치: `quick_reorder_section.dart` L251-258

### flutter analyze

- [x] `flutter analyze` 0 issue
  - 결과: `No issues found! (ran in 4.1s)`

---

## FAIL 항목 (모두 2026-04-30 해소)

### FAIL-1. FrequentMenuCard — "최근 N회 주문" 텍스트 라벨 미구현 — RESOLVED

- 문제: design.md 명세에 FrequentMenuCard Padding 내 `"최근 ${orderCount}회 주문"` 텍스트 라벨 (`Icons.history_rounded`, `AppColors.textMuted`)과 `SizedBox(height: 8)` 이 명시되어 있으나, 실제 코드에는 해당 Row 위젯이 없음. 가격 텍스트가 매장명 바로 아래(`SizedBox(height: 6)`)에 위치함.
- 위치:
  - 명세: `docs/tasks/order_flow_phase2/design.md` L256-262
  - 구현: `lib/presentation/customer/home/widgets/frequent_menu_items_section.dart` L164-201 (Padding Column 내)
- 확인 방법: `frequent_menu_items_section.dart` FrequentMenuCard `build()` 의 Padding Column 확인 — `history_rounded` 아이콘 / "최근 N회 주문" 텍스트 Row 없음
- 제안 수정 방향: Padding Column 내 매장명(`storeName`) 아래, 가격(`basePrice`) 위에 아래 코드 추가
  ```dart
  const SizedBox(height: 8),
  Row(
    children: [
      const Icon(Icons.history_rounded, size: 12, color: AppColors.textMuted),
      const SizedBox(width: 4),
      Text(
        '최근 ${entity.orderCount}회 주문',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMuted),
      ),
    ],
  ),
  const SizedBox(height: 6),
  ```
  (`SizedBox(height: 6)` → `SizedBox(height: 6)` 은 가격 위 공간으로 유지)
- 우선순위: 중간 (UI 기능은 동작하지만 design.md 명세와 불일치)
- 해소: 2026-04-30. `frequent_menu_items_section.dart` Padding Column 에 `Icons.history_rounded` + "최근 N회 주문" Row 추가. 카드 높이도 220 → 244 로 보정. `flutter analyze` 0 issue.

---

### FAIL-2. implementation.md 알고리즘 표 — 임계값 수치 오기재 — RESOLVED

- 문제: `implementation.md` 알고리즘 요약 표의 임계값이 실제 코드 및 spec.md 와 다름.
  - 표: "자주 찾는 매장 score >= 3" → 코드: `frequentStoreMinVisits = 5` (spec "5회 이상" 과 일치)
  - 표: "자주 찾는 메뉴 score >= 4" → 코드: `frequentMenuPairMinVisits = 3` (spec "3회 이상" 과 일치)
  - 즉 코드는 spec.md 와 일치하지만 implementation.md 문서가 잘못 기재됨.
- 위치:
  - 오기재: `docs/tasks/order_flow_phase2/implementation.md` 알고리즘 요약 표 (score >= 3, score >= 4 행)
  - 실제 코드: `lib/core/constants/recommendation_thresholds.dart` L25 (`frequentStoreMinVisits = 5`), L31 (`frequentMenuPairMinVisits = 3`)
- 확인 방법: implementation.md 표와 recommendation_thresholds.dart 값 직접 비교
- 제안 수정 방향: `implementation.md` 알고리즘 요약 표 수정
  - "자주 찾는 매장" 행: `score >= 3` → `score >= 5`
  - "자주 찾는 메뉴" 행: `score >= 4` → `score >= 3`
- 우선순위: 낮음 (코드는 정상, 문서만 수정 필요)
- 해소: 2026-04-30. `implementation.md` 알고리즘 요약 표를 "자주 찾는 매장 score >= 5", "자주 찾는 메뉴 score >= 3" 으로 수정 (실제 코드/spec 과 일치).

---

## 보류 항목

- [ ] flutter test — Phase 2 전용 단위 테스트 없음
  - 이유: `test/` 디렉토리 내 `order_log`, `recommendation`, `quick_reorder`, `frequent` 관련 파일 없음
  - 필요한 확인: `GetFrequentStoresUseCase.compute()`, `GetFrequentMenuItemsUseCase.compute()`, `GetQuickReorderCandidatesUseCase._toCandidates()`, `RelativeTimeFormatter.formatKo()` 순수 함수 단위 테스트
  - 후속 작업 제안: Phase 3 전에 domain UseCase 단위 테스트 및 RelativeTimeFormatter 단위 테스트 추가

- [ ] storesByIdProvider nearbyStores 의존 — 5km 외 매장 hide 동작 실기기 확인
  - 이유: `storesByIdProvider` 가 `nearbyStoresProvider` 의존. 5km 반경 외 시드 매장의 경우 `FrequentStoreCard` / `FrequentMenuCard` 에서 hide될 수 있음.
  - 필요한 확인: 시드 매장 위치와 테스트 기기 위치가 5km 이상 차이날 때 동작 확인. 현재 시드는 단일 고정 매장이므로 시뮬레이터에서는 무관.
  - 후속 작업 제안: Phase 3 이후 OrderLog 매장 lookup 을 nearbyStores 의존에서 분리 (별도 Provider)

- [ ] 원클릭 재주문 `unitPriceWithOptions` 역산 로직 — lineTotal / quantity 가정 정합성
  - 이유: `_unitPriceFromLineTotal(lineTotal / quantity)` 는 정수 나눗셈이므로 옵션 금액 분산 시 원단위 오차 발생 가능. 현재 단계에서는 결제 검증이 Phase 3이므로 카트 표시 정확도만 영향.
  - 필요한 확인: 옵션이 있는 주문의 재주문 시 카트 단가 표시 정확성 실기기 확인
  - 후속 작업 제안: Phase 3 결제 구현 시 OrderLogItem 에 `unitPriceWithOptions` 필드 추가하여 역산 제거

- [ ] _menuItemsByStoreProvider 동적 family watch — 매장 수 증가 시 성능
  - 이유: `_orderedStoreIdsProvider` 에 등장하는 매장 수만큼 `storeMenuItemsProvider(id)` 를 loop watch. 현재 시드 1개 매장이므로 무관하나 실사용 시 다수 매장 watch 비용 검토 필요.
  - 필요한 확인: 10개 이상 매장에서의 렌더링 성능
  - 후속 작업 제안: lazy fetch / 특정 매장 조회만 하는 별도 provider 전략 검토

- [ ] 비로그인 → 로그인 전환 시 AnimatedSwitcher 페이드인 실기기 확인
  - 이유: 정적 코드 검증으로 AnimatedSwitcher 적용을 확인했으나, 실제 auth 상태 전환 시 섹션이 부드럽게 나타나는지 육안 확인 필요
  - 필요한 확인: 로그아웃 상태 → 로그인 후 추천 섹션 표시 전환 애니메이션
  - 후속 작업 제안: Phase 3 통합 테스트 시 같이 확인

---

## 설계자 전달 메시지

### 요약

- 전체 판단: 조건부 완료. FAIL 2건 중 FAIL-1(FrequentMenuCard 라벨 누락)은 코드 수정이 필요하며, FAIL-2(implementation.md 표 오기재)는 문서 수정만으로 해결 가능.
- 핵심 기능(추천 3종 섹션, 원클릭 재주문 흐름, Clean Architecture 준수, AppColors 전용)은 정상 구현됨.
- `flutter analyze` 0 issue 확인.

### 재작업 우선순위

1. **FAIL-1: FrequentMenuCard "최근 N회 주문" 라벨 추가**
   - 이유: design.md 명세와 코드 불일치. UI 영향 있음. 수정 범위 소규모(Row 위젯 추가).
   - 파일: `lib/presentation/customer/home/widgets/frequent_menu_items_section.dart`

2. **FAIL-2: implementation.md 알고리즘 표 임계값 수정**
   - 이유: 문서 오기재. 코드는 정상. 문서만 수정.
   - 파일: `docs/tasks/order_flow_phase2/implementation.md`

### 후속 task 후보

- **Phase 2 단위 테스트 추가**: `GetFrequentStoresUseCase.compute()` / `GetFrequentMenuItemsUseCase.compute()` / `RelativeTimeFormatter.formatKo()` 순수 함수 테스트. Phase 3 전 권장.
- **storesByIdProvider 의존 분리**: `nearbyStoresProvider` 의존을 끊고 OrderLog 에 등장한 매장은 별도 lookup (Phase 3 결제 이후 실사용자 데이터 증가 시점 적용).
- **OrderLogItem.unitPriceWithOptions 필드 추가**: Phase 3 결제 구현 시 lineTotal/quantity 역산 제거.

---

## 완료 판단

- [x] 전체 PASS (FAIL-1, FAIL-2 모두 2026-04-30 해소, 보류 5건은 후속 phase 로 분리)
- [ ] FAIL 있으나 후속 task로 분리 가능
- [ ] 재작업 필요

# 점주 매출 조회 (owner_sales) 구현 내역

## 개요
- 기준: `spec.md` (§12 D1~D7 확정), `design.md` (+ 맨 끝 "잔여 결정 확정" R1~R4 우선)
- 점주 "매출" 탭 placeholder 를 실구현. 클라이언트 집계(`get()` 1회 + pull-to-refresh).
- **Cloud Functions 변경 0건, `firestore.rules` 변경 0건.** `firestore.indexes.json` 만 1건 추가 (아래 인덱스 실측).

## 구현 파일

### 신규
- Core: `lib/core/constants/sales_query_limits.dart`, `lib/core/utils/kst.dart` (KST wall <-> instant 변환의 단일 지점), `lib/core/errors/permission_denied_exception.dart`
- Domain: `sales_period.dart`(+freezed), `sales_summary_entity.dart`, `store_sales_entity.dart`, `store_sales_query.dart`, `usecases/get_store_sales_use_case.dart` (`aggregateStoreSales` 순수 함수 포함)
- Presentation (`lib/presentation/owner/sales/`): `owner_sales_page.dart`, `providers/owner_sales_providers.dart`, `formatters/sales_formatters.dart`, `widgets/` (`sales_period_header`, `sales_summary_card`, `sales_order_tile`, `sales_status_badge`, `sales_store_status_banner`, `sales_empty_state`)
- 테스트: `test/domain/sales_period_test.dart`, `test/domain/aggregate_store_sales_test.dart`, `test/presentation/sales_formatters_test.dart`

### 수정
- `lib/domain/repositories/order_repository.dart` — `getStoreOrdersInPeriod` 추가
- `lib/data/repositories/order_repository_impl.dart`, `lib/data/datasources/remote/order_remote_data_source.dart` — `fetchByStoreInPeriod` (storeId == + createdAt 범위 + orderBy createdAt desc + limit). `permission-denied` -> `PermissionDeniedException` 변환(presentation 에 Firebase 비노출), `failed-precondition` 은 debugPrint 후 rethrow. `streamPaidByStore` 등 기존 메서드 **미변경**(개명 없음)
- `lib/presentation/owner/owner_scaffold.dart` — `OwnerSalesPage` 로 교체
- `firestore.indexes.json` — orders `(storeId ASC, createdAt DESC, __name__ DESC)` 추가
- `docs/processes/role_flows.md` — 148/153/215행 "미구현(placeholder)" 갱신

### 삭제
- `lib/presentation/owner/placeholders/owner_sales_placeholder.dart` (폴더도 비어 사라짐)

## 인덱스 실측 결과 (중요)
- **예상과 달리 인덱스 추가가 필요했다.** 기존 `(storeId, createdAt DESC, refundRequest DESC)` 는 `(storeId, createdAt)` 쿼리를 커버하지 못한다 (복합 인덱스가 접두 쿼리를 커버한다는 가정은 Firestore 에서 성립하지 않음).
- 방법: firebase CLI 로그인 자격으로 운영 프로젝트(`order-app-5957e`)에 Firestore REST `runQuery` 실행. 존재하지 않는 dummy storeId 로 조회해 **문서 read 0건**, 인덱스 요구 여부만 확인. 쿼리 형태는 앱과 동일(`storeId ==`, `createdAt >= / <`, `orderBy createdAt desc`, `limit 1000`).
- 결과: `400 FAILED_PRECONDITION: The query requires an index` (요구 인덱스 = storeId ASC, createdAt DESC, __name__ DESC).
- 배포된 인덱스 목록(`firebase firestore:indexes`)은 기존 3개와 동일함을 확인.
- 조치: `firestore.indexes.json` 에 위 인덱스 추가. **배포하지 않음 (사용자 작업)**:
  `cd /Users/Byeonguk/Developer/OrderApp && firebase deploy --only firestore:indexes`
  빌드 완료까지 수 분 소요. **배포 전에는 매출 탭이 `불러오는 데 실패했어요` 일반 에러로 보인다** (콘솔에는 `[OrderRemoteDataSource] fetchByStoreInPeriod 인덱스 누락 의심` 로그).
- 배포 체크리스트: Rules 배포 불필요 / CF 배포 불필요 / **인덱스 배포 필요**.

## 핵심 구현 요점
- **집계는 `aggregateStoreSales(orders, period)` 한 곳**. 위젯에 `totalPrice` 합산 없음(주문 행의 금액 *표시*만). 총 매출 = completed + 진행 중(paid/accepted/making/ready), refunded/cancelled 제외, 환불 금액은 `refundInfo.amount ?? totalPrice`, `refundRequest` 만 있는 주문은 포함, 평균은 `~/`.
- **KST**: `SalesPeriod` 는 `start/endExclusive` 를 UTC instant 로 보관하고 달력 계산은 `Kst` 로 한다. 표시용 변환(행 시각, "올해" 판정, 주차, 날짜 범위)은 `SalesFormatters` 한 곳.
- **주차**: 목요일 소속(ISO 8601). 제목 `10월 4주차` + 부제 `10월 19일 ~ 10월 25일`. `SalesPeriod.bucketKey` (`2026-10-21` / `2026-W43` / `2026-10`) 미리 고정.
- **기간 이동**: `canGoNext`(끝난 기간만), `canGoPrevious`(현재 달 1일 기준 12개월 전 경계와 겹치는 기간까지). 모두 `now` 주입 가능.
- **Provider**: 전부 top-level. `storeSalesProvider = FutureProvider.autoDispose.family<_, StoreSalesQuery>`. 새 키(기간/단위 전환)는 값 없는 loading = skeleton, 같은 키의 `ref.refresh` 만 기존 값 유지.
- **에러/새로고침**: 에러 시 요약 카드를 그리지 않음(0원 대체 금지). 새로고침 실패는 기존 내용 유지 + SnackBar `새로고침에 실패했어요`(기존 값이 있을 때만). `permission-denied` 는 재시도 버튼 없는 별도 문구.
- **배지/배너**: 4종 배지(진행 중 글자 `primary`), 배너 3변형(승인 대기 / 수정 검토 중 / 반려). 요약 plate 3행은 0건이어도 항상 표시. 환불은 error 색 미사용(요약 `-` 부호, 목록 취소선).
- truncated 경고 숫자는 `SalesQueryLimits.maxDocumentsPerQuery` 를 `NumberFormat` 으로 포맷. 세그먼트 재탭 복귀 / 갱신 시각 표기 없음(2차 S6).

## spec/design 대비 차이 및 참고
- `salesPeriodTypeProvider` 는 만들지 않았다. `salesPeriodProvider` 의 `SalesPeriod.type` 이 곧 선택 단위라 중복 상태를 피함.
- `aggregateStoreSales` 에 `@visibleForTesting` 은 붙이지 않았다 (S5/S1·S2 확장 시 공용 진입점이 될 함수이고, `meta` 직접 의존 회피).
- `PermissionDeniedException` 신설 (spec 에 없음): presentation 이 Firebase 를 import 할 수 없으므로 data 에서 변환.
- 날짜 포맷은 `DateFormat` 대신 수동 포맷 (요일/주차를 KST wall 로 결정적으로 생성, 로케일 초기화 의존 제거).
- `autoDispose` 때문에 기간을 왔다 갔다 하면 재조회한다 (캐시 0 read 이점 포기, 대신 stale 방지). 
- **알려진 한계**: 앱을 자정 넘어 켜 둔 채 매출 탭을 보면 `salesPeriodProvider` 의 "오늘" 이 어제로 남아 있다(IndexedStack, 자동 갱신 없음). 단위 세그먼트를 다시 선택(다른 단위 -> 원래 단위)하면 현재 기간으로 리셋된다. 필요하면 후속(S6)에서 처리.

## 테스트 포인트 (tester)
- 단위: `SalesPeriod` 경계(KST 자정, 월/연말, 윤년, 주 시작, bucketKey ISO 연말/연초, canGoNext/Previous 12개월), `aggregateStoreSales`(진행 중 포함·환불/취소 제외, 0건 평균, `~/` 버림, refundInfo fallback, refundRequest 만 있는 주문 포함), `SalesFormatters`(주차 목요일 규칙, 월 경계 부제, 올해 KST 판정, 행 시각 KST).
- 라이브: **인덱스 배포 후** 진입 -> 요약/목록, 일/주/월 전환 시 skeleton(이전 숫자 잔존 없음), 이전/다음 비활성, pull-to-refresh 시 내용 유지, 네트워크 차단 후 새로고침 -> SnackBar + 내용 유지, 신규 매장(0건)·pending·rejected·수정 검토 중 배너, 매장 미등록, 환불/취소 행 취소선·배지, 행 탭 -> 주문 상세, `0건` plate 3행 상시 표시, 디바이스 타임존을 KST 가 아닌 곳으로 바꿔 경계/시각 확인, 타 매장 storeId 접근 시 permission-denied (test_rules 하네스에 케이스 추가 검토).
- truncated 경고는 `SalesQueryLimits.maxDocumentsPerQuery` 를 임시로 낮춰 재현.

## 미구현 / 보류
- 위젯/통합 테스트 미추가 (단위 테스트만).
- 인덱스 배포(사용자 작업), Rules 테스트 케이스 추가, S1~S6 (2차).

## 검증
- `dart run build_runner build --delete-conflicting-outputs`: 완료
- `flutter analyze`: No issues found
- `flutter test`: All tests passed (71)
- `grep package:firebase_|cloud_firestore lib/presentation lib/domain`: 0건 / `Color(0x` (sales): 0건

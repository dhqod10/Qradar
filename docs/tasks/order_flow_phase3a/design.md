# order_flow_phase3a 디자인 명세

> 결제 인프라 + 신용/체크카드 + 카카오페이 (토스페이먼츠)
>
> spec 단일 진실원: `docs/tasks/order_flow_phase3a/spec.md`
> 디자인 시스템 단일 진실원: `docs/agents/designer_guide.md`

---

## 참조한 디자인

- Figma: 없음 (신규 화면)
- 기존 화면 패턴: `docs/design/screens/home/home.md` (카드 컴포넌트 패턴, 헤더 구조)
- 기존 컴포넌트: `docs/design/components/bottom_nav.md` (탭 선택 색상)
- 디자인 원칙: 밝은 캔버스 + 미드나잇 네이비 포인트. 기존 Qradar 디자인 시스템 그대로 유지. 디자인 변경 최소화 — 기능 완성 집중.

---

## 디자인 원칙 요약

- 전체 배경: `AppColors.background`
- 카드 표면: `AppColors.surfaceElevated`, border: `AppColors.border` 1px, radius: 16
- 주요 CTA 버튼: `AppColors.primary` 배경, `AppColors.onPrimary` 텍스트, radius: 12
- 섹션 제목: `AppColors.textHeading` / fontSize: 18~20 / w700
- 본문 텍스트: `AppColors.textBody` / fontSize: 14~16 / w400~w500
- 보조 텍스트: `AppColors.textMuted` / fontSize: 12~13 / w400
- 색상 하드코딩 절대 금지

---

## 화면 구성

### 1. CheckoutPage (결제수단 선택)

- 레이아웃: Scaffold + SafeArea. 단일 Column — 스크롤 영역 + 하단 고정 버튼.
- 배경: `AppColors.background`
- AppBar:
  - title: "결제하기" / fontSize: 18 / w700 / `AppColors.textHeading`
  - leading: 뒤로가기 아이콘 / `AppColors.textHeading`
  - backgroundColor: `AppColors.background`
  - elevation: 0
- SafeArea: true (상단 + 하단)
- Scroll: SingleChildScrollView (하단 고정 버튼 영역 제외)

스크롤 영역 섹션 구성 (top-down):
1. `CheckoutSummaryCard` — 주문 요약 카드
2. 결제수단 섹션 헤더 + `PaymentMethodTile` 목록
3. 약관 동의 섹션
4. 가격 요약 (`PriceSummary`)

하단 고정 영역:
- Container / height: 80 + bottomInset
- padding: horizontal 20, vertical 12
- 배경: `AppColors.surfaceElevated`
- 상단 border: `AppColors.border` 1px
- 결제 버튼: 전체 너비, height: 54, radius: 12
  - 활성: `AppColors.primary` 배경 / `AppColors.onPrimary` 텍스트 / "3,500원 결제하기" / fontSize: 16 / w700
  - 비활성(약관 미동의 또는 결제수단 미선택): `AppColors.surface` 배경 / `AppColors.textMuted` 텍스트
  - 로딩(결제 진행 중): `AppColors.primary` 배경 + CircularProgressIndicator(color: `AppColors.onPrimary`, size: 20) / 버튼 전체 disabled

결제 진행 중 상태 (Toss SDK 호출 후 ~ callback 대기):
- 결제 버튼 로딩 상태 (위 참조)
- 페이지 전체 IgnorePointer 로 상호작용 차단 (disabled 상태)
- ModalBarrier 없이 시각적으로만 비활성 표시 (Toss SDK 가 외부 화면을 직접 띄우므로 앱 UI 는 배경에 머뭄)

---

### 2. PaymentResultPage (결제 결과)

- 레이아웃: Scaffold + SafeArea. 중앙 정렬 Column.
- 배경: `AppColors.background`
- AppBar: 없음 (결과 화면 — 뒤로가기 막음)
- SafeArea: true
- Scroll: 없음 (단일 화면)

세 가지 변형 (success / fail / cancelled):

#### 성공 변형
- 상단 여백: 60
- 아이콘: `Icons.check_circle_rounded` / size: 80 / `AppColors.success`
- 제목: "결제가 완료되었어요" / fontSize: 22 / w700 / `AppColors.textHeading` / 상단 margin: 20
- 주문번호 라벨: "주문번호" / fontSize: 13 / `AppColors.textMuted` / 상단 margin: 12
- 주문번호 값: orderId 축약 표시 (앞 8자 + "...") / fontSize: 14 / w600 / `AppColors.textBody`
- 버튼 영역 (하단 고정, padding: horizontal 20 / vertical 16):
  - "주문 상세 보기" 버튼: 전체 너비 / height: 54 / radius: 12 / `AppColors.primary` 배경 / `AppColors.onPrimary` 텍스트 / fontSize: 16 / w700
  - 하단 여백 처리: bottomSafeArea

#### 실패 변형
- 아이콘: `Icons.cancel_rounded` / size: 80 / `AppColors.error`
- 제목: "결제에 실패했어요" / fontSize: 22 / w700 / `AppColors.textHeading`
- 설명: Toss errorCode 를 사용자 친화 문구로 매핑 (에러 메시지) / fontSize: 14 / `AppColors.textMuted` / textAlign: center / 좌우 padding: 32
- 버튼 영역 (세로 배열, gap: 12):
  - "다시 시도" 버튼: 전체 너비 / height: 54 / radius: 12 / `AppColors.primary`
  - "결제 수단 변경" 버튼: 전체 너비 / height: 54 / radius: 12 / `AppColors.surfaceElevated` 배경 / border: `AppColors.border` / `AppColors.textBody` 텍스트
  - "닫기" 텍스트 버튼: `AppColors.textMuted` / fontSize: 14

#### 취소 변형
- 아이콘: `Icons.info_rounded` / size: 80 / `AppColors.textMuted`
- 제목: "결제가 취소되었어요" / fontSize: 22 / w700 / `AppColors.textHeading`
- 설명: "결제를 다시 시도하시려면 카트로 돌아가주세요" / fontSize: 14 / `AppColors.textMuted`
- 버튼: "닫기 (카트로 돌아가기)" / 전체 너비 / height: 54 / radius: 12 / `AppColors.surfaceElevated` 배경 / border: `AppColors.border`

---

### 3. OrderDetailPage (주문 상세 — customer 시야)

- 레이아웃: Scaffold + SafeArea + SingleChildScrollView
- 배경: `AppColors.background`
- AppBar:
  - title: "주문 상세" / fontSize: 18 / w700 / `AppColors.textHeading`
  - leading: 뒤로가기 / `AppColors.textHeading`
  - backgroundColor: `AppColors.background`
  - elevation: 0

스크롤 영역 섹션 (top-down, padding: horizontal 20):
1. 상태 섹션: `OrderStatusBadge` (크게 표시) + 시각 (createdAt, RelativeTimeFormatter)
2. 구분선: `AppColors.border` / 두께 1
3. 매장 정보: 매장명 (fontSize: 16 / w600 / `AppColors.textHeading`)
4. 주문 라인 리스트: `OrderItemRow` 목록
5. 구분선
6. `PriceSummary`
7. 구분선
8. 결제 정보 섹션: 수단 / 카드사 + 마스킹 번호 또는 easyPayProvider 표시
9. 영수증 보기 버튼 (receiptUrl 있을 때만)
10. 하단 액션 버튼 영역

하단 액션 버튼 영역 (status 분기):
- `status == paid`:
  - "주문 취소" 버튼: `AppColors.error` border / `AppColors.error` 텍스트 / height: 48 / radius: 10 / 전체 너비
- `status == accepted || making || ready`:
  - "환불 요청" 버튼: `AppColors.primary` border / `AppColors.primary` 텍스트 / height: 48 / radius: 10 / 전체 너비
- `status == cancelled`:
  - "취소된 주문입니다" 안내 텍스트 (버튼 없음) / `AppColors.textMuted` / fontSize: 13 / textAlign: center
- `status == refunded`:
  - "환불 완료된 주문입니다" 안내 텍스트 / `AppColors.textMuted` / fontSize: 13 / textAlign: center
- `status == completed`:
  - 버튼 없음 (완료)

결제 정보 섹션 상세:
- 섹션 헤더: "결제 정보" / fontSize: 15 / w600 / `AppColors.textHeading`
- 결제 수단: PaymentMethod label (카드 → "신용/체크카드", kakaoPay → "카카오페이")
- 카드사: cardCompany (null 이 아닌 경우만)
- 카드번호 마스킹: cardNumberMasked (null 이 아닌 경우만)
- easyPayProvider: kakaoPay 결제 시 "카카오페이" 표시
- 각 행: 좌측 라벨 `AppColors.textMuted` / 우측 값 `AppColors.textBody`

영수증 보기 버튼:
- `receiptUrl != null` 일 때만 노출
- 스타일: 텍스트 링크 형태 / `AppColors.primaryBright` / fontSize: 14 / 밑줄 없음 / 아이콘: `Icons.receipt_long_outlined` size: 16 / 우측 배치

---

### 4. OrdersPage (내 주문 목록 = LogPage 본구현)

- 레이아웃: Scaffold + SafeArea
- 배경: `AppColors.background`
- AppBar:
  - title: "Log" (Qradar 고유 용어) / fontSize: 20 / w700 / `AppColors.textHeading`
  - backgroundColor: `AppColors.background`
  - elevation: 0
  - actions: 없음
- 본문: CustomScrollView 또는 ListView.builder
- Pull-to-refresh: RefreshIndicator / color: `AppColors.primary`

주문 카드 (`OrderCardTile`):
- 배경: `AppColors.surfaceElevated`
- border: `AppColors.border` 1px
- radius: 16
- shadow: `AppColors.primary` alpha 0.04
- padding: 16
- margin: horizontal 20 / vertical 6
- 내부 구조 (Column):
  - Row: 매장명 (fontSize: 15 / w600 / `AppColors.textHeading`) + `OrderStatusBadge` (우측 정렬)
  - 상단 margin: 6
  - Row: 메뉴 요약 텍스트 (첫 메뉴명 + 외 N개, `AppColors.textBody` / fontSize: 13) + 합계 금액 (우측, `AppColors.textHeading` / fontSize: 15 / w700)
  - 상단 margin: 6
  - 시각: RelativeTimeFormatter 출력 / `AppColors.textMuted` / fontSize: 12
- 탭 인터랙션: InkWell / splash: `AppColors.primary` alpha 0.08

---

### 5. OwnerOrdersPage (점주 최소 접수 UI)

- 레이아웃: Scaffold + SafeArea
- 배경: `AppColors.background`
- AppBar:
  - title: "주문 접수" / fontSize: 20 / w700 / `AppColors.textHeading`
  - backgroundColor: `AppColors.background`
  - elevation: 0
- 탭 바: TabBar (2개: "신규" / "환불 요청")
  - indicatorColor: `AppColors.primary`
  - labelColor: `AppColors.primary`
  - unselectedLabelColor: `AppColors.textMuted`
  - labelStyle: fontSize: 14 / w600
  - indicatorWeight: 2.5

#### 신규 탭 (`ownerNewOrdersProvider` — status=paid)

카드 (`OwnerNewOrderTile`):
- 배경: `AppColors.surfaceElevated`
- border: `AppColors.border` 1px
- radius: 16
- padding: 16
- margin: horizontal 16 / vertical 6
- 내부 구조:
  - Row: 시각 (`AppColors.textMuted` / fontSize: 12) + `OrderStatusBadge` (우측)
  - 상단 margin: 8
  - 라인 요약: 첫 메뉴명 외 N개 / `AppColors.textBody` / fontSize: 14
  - 합계: `AppColors.textHeading` / fontSize: 16 / w700
  - 상단 margin: 12
  - 버튼 Row (gap: 8):
    - "주문 받기" 버튼: height: 40 / radius: 10 / Expanded / `AppColors.primary` 배경 / `AppColors.onPrimary` 텍스트 / fontSize: 14 / w600
    - "거절" 버튼: height: 40 / radius: 10 / width: 80 / `AppColors.surfaceElevated` 배경 / border: `AppColors.error` / `AppColors.error` 텍스트 / fontSize: 14 / w600

#### 환불 요청 탭 (`ownerRefundRequestsProvider`)

카드 (`OwnerRefundRequestTile`):
- 구조는 신규 탭과 동일 (카드 스타일 공유)
- 추가 표시: 환불 요청 사유 / `AppColors.textMuted` / fontSize: 12 / 최대 2줄 (overflow: ellipsis)
- 요청 시각: requestedAt
- 버튼 Row:
  - "승인" 버튼: height: 40 / radius: 10 / Expanded / `AppColors.primary` 배경 / `AppColors.onPrimary` 텍스트
  - "거절" 버튼: height: 40 / radius: 10 / width: 80 / `AppColors.surfaceElevated` 배경 / border: `AppColors.border` / `AppColors.textBody` 텍스트

---

### 6. CartPage._CheckoutBar (수정)

변경 내용:
- 기존 placeholder SnackBar 제거
- "결제하기" 버튼 탭 → 사전 가드 검사 후 `CheckoutPage` push
- 가드 실패 시: SnackBar 대신 다이얼로그 표시 (spec 기준)
- 버튼 스타일은 기존 CartPage 스타일 유지

---

## 컴포넌트 명세

### C1. OrderStatusBadge

- 역할: 주문 상태를 한눈에 식별할 수 있는 뱃지. 목록 카드 / 상세 화면에서 재사용.
- 위젯 구조: Container(decoration: BoxDecoration) + Text
- 크기: 자동 (텍스트 길이 기반). height: 24 고정.
- padding: horizontal 10 / vertical 4
- radius: pill (999)
- 텍스트: fontSize: 12 / w600

status 별 색상 및 라벨:

| status | 배경 | 텍스트 | 라벨 | 설명 |
|---|---|---|---|---|
| paid | `AppColors.primaryBright` alpha 0.15 | `AppColors.primaryBright` | "결제 완료" | 활성 포인트 계열 |
| accepted | `AppColors.info` alpha 0.15 | `AppColors.info` | "접수 완료" | 정보 계열 |
| making | `AppColors.warning` alpha 0.15 | `AppColors.warning` | "제조 중" | 경고/진행 계열 |
| ready | `AppColors.success` alpha 0.15 | `AppColors.success` | "픽업 대기" | 성공 계열 |
| completed | `AppColors.surface` | `AppColors.textMuted` | "완료" | 비활성 계열 |
| cancelled | `AppColors.error` alpha 0.12 | `AppColors.error` | "취소됨" | 에러 계열 |
| refunded | `AppColors.textMuted` alpha 0.15 | `AppColors.textMuted` | "환불 완료" | 중립 계열 |

크기 변형:
- small (목록 카드): height: 22 / fontSize: 11 / padding: horizontal 8
- large (상세 화면 상단): height: 32 / fontSize: 14 / w700 / padding: horizontal 14

---

### C2. PaymentMethodTile

- 역할: 결제수단 선택 라디오 타일. CheckoutPage 에서 사용.
- 위젯 구조: InkWell > Container > Row (라디오 아이콘 + 로고 아이콘 + 라벨)
- 크기: 전체 너비 / height: 64
- 배경: `AppColors.surfaceElevated`
- border: 선택 시 `AppColors.primary` 2px / 미선택 시 `AppColors.border` 1px
- radius: 12
- shadow: 선택 시 `AppColors.primary` alpha 0.06 / 미선택 시 없음
- padding: horizontal 16
- gap (Row 내부): 12

내부 요소:
- 라디오 아이콘: Radio<PaymentMethod> / activeColor: `AppColors.primary` / size: 20
- 결제수단 아이콘:
  - 카드: `Icons.credit_card_rounded` / size: 24 / `AppColors.primary`
  - 카카오페이: 카카오 로고 이미지 애셋 (황색 배경 원형) 또는 `AppColors.kakao` 배경 원형 + "K" 텍스트 fallback / size: 24
- 라벨:
  - 카드: "신용/체크카드" / fontSize: 15 / w600 / `AppColors.textHeading`
  - 카카오페이: "카카오페이" / fontSize: 15 / w600 / `AppColors.textHeading`
- 보조 라벨:
  - 카드: "직접 입력" / fontSize: 12 / `AppColors.textMuted`
  - 카카오페이: "카카오톡 간편결제" / fontSize: 12 / `AppColors.textMuted`
- 라디오는 Row 우측 정렬

상태:
- default (미선택): border `AppColors.border`, 배경 `AppColors.surfaceElevated`
- selected: border `AppColors.primary` 2px, 배경 `AppColors.primary` alpha 0.04
- disabled: 배경 `AppColors.surface`, 텍스트 `AppColors.textMuted`, 탭 비활성

---

### C3. CheckoutSummaryCard

- 역할: CheckoutPage 상단 주문 요약 카드.
- 위젯 구조: Card > Column
- 배경: `AppColors.surfaceElevated`
- border: `AppColors.border` 1px
- radius: 16
- padding: 16
- margin: horizontal 20 / vertical 0

내부 구조:
- 매장명: fontSize: 16 / w700 / `AppColors.textHeading`
- 상단 margin: 10
- 라인 리스트: `OrderItemRow` (compact 변형 — 가격 표시, 옵션 숨김)
  - 최대 3줄 표시. 초과 시 "외 N개" 텍스트 추가
- 구분선: `AppColors.border` / height: 1
- 합계 Row: "합계" 라벨 / `AppColors.textMuted` / fontSize: 14 + 금액 / `AppColors.textHeading` / fontSize: 18 / w700

---

### C4. OrderItemRow

- 역할: 단일 주문 라인(메뉴 + 수량 + 옵션 + 가격) 표시. OrderDetailPage / CheckoutSummaryCard 에서 재사용.
- 위젯 구조: Row > (이미지? + Column (메뉴명/옵션) + Column (수량/가격))

변형:
- full (OrderDetailPage): 좌측 이미지 썸네일 (48x48, radius: 8, `AppColors.surface` placeholder) + 메뉴명 + 옵션 + 우측 수량/가격
- compact (CheckoutSummaryCard): 이미지 없음, 메뉴명 + 옵션 한 줄 + 우측 가격

full 변형 상세:
- 이미지: width: 48 / height: 48 / radius: 8 / fit: BoxFit.cover / 에러 시 `AppColors.surface` 배경 + `Icons.image_not_supported` / `AppColors.textMuted` size: 20
- 메뉴명: fontSize: 14 / w600 / `AppColors.textHeading` / maxLines: 1 / overflow: ellipsis
- 옵션 문자열: 옵션 선택값 join(", ") / fontSize: 12 / `AppColors.textMuted` / maxLines: 2 / overflow: ellipsis (옵션 없으면 숨김)
- 수량: "×{n}" / fontSize: 13 / `AppColors.textMuted`
- 가격: lineTotal 금액 포맷 / fontSize: 14 / w600 / `AppColors.textBody`

compact 변형 상세:
- 메뉴명 + 옵션: 한 줄 / fontSize: 13 / `AppColors.textBody` / maxLines: 1 / overflow: ellipsis
- 가격: fontSize: 13 / w600 / `AppColors.textBody`
- 좌우 padding: 없음 (부모 카드 padding 에 포함)

---

### C5. PriceSummary

- 역할: 소계 / 할인 / 최종 결제액 표시. CheckoutPage 하단, OrderDetailPage 에서 재사용.
- 위젯 구조: Column (행 목록)

각 행: Row (라벨 + 금액), gap: 8
- 행 gap: 8
- 소계 행: "소계" / `AppColors.textMuted` / fontSize: 13 + 금액 / `AppColors.textBody` / fontSize: 13
- 할인 행: `discount != null && discount > 0` 일 때만 표시 / "할인" / `AppColors.success` + "-N원" / `AppColors.success` / fontSize: 13
- 구분선: `AppColors.border` 높이 1 (최종 결제액 위)
- 최종 결제액 행: "최종 결제액" / `AppColors.textHeading` / fontSize: 14 / w600 + 금액 / `AppColors.textHeading` / fontSize: 18 / w700

---

### C6. RefundRequestDialog

- 역할: customer 가 환불 요청 사유를 입력하는 다이얼로그.
- 트리거: OrderDetailPage "환불 요청" 버튼 탭
- dismiss: "취소" 버튼 / 바깥 탭 (barrier dismissible)
- 위젯 구조: AlertDialog 또는 showModalBottomSheet

선택: `showModalBottomSheet` 채택 — 입력 키보드가 올라오는 경우 처리가 용이.

시트 구조:
- 상단 핸들 바: width: 40 / height: 4 / radius: 2 / `AppColors.border`
- 제목: "환불 요청" / fontSize: 18 / w700 / `AppColors.textHeading`
- 상단 margin: 20
- 사유 선택 칩 목록 (단일 선택):
  - 선택지: "주문 실수", "메뉴 변경", "매장 사정", "기타"
  - 선택됨: `AppColors.primary` 배경 / `AppColors.onPrimary` 텍스트
  - 미선택: `AppColors.surfaceElevated` 배경 / `AppColors.border` border / `AppColors.textBody` 텍스트
  - radius: pill / fontSize: 13 / padding: horizontal 14, vertical 8
- 상단 margin: 16
- 추가 사유 입력 (TextField):
  - hint: "추가 사유를 입력해주세요 (선택)" / `AppColors.textMuted`
  - 배경: `AppColors.surfaceElevated`
  - border: `AppColors.border`
  - 포커스 border: `AppColors.primary`
  - minLines: 3 / maxLines: 5
  - radius: 10
  - fontSize: 14 / `AppColors.textBody`
- 버튼 Row (gap: 10):
  - "취소" 버튼: height: 48 / Expanded / `AppColors.surfaceElevated` 배경 / `AppColors.border` border / `AppColors.textBody` 텍스트 / radius: 10
  - "환불 요청" 버튼: height: 48 / Expanded / `AppColors.primary` 배경 / `AppColors.onPrimary` 텍스트 / radius: 10
  - 사유 미선택 시 "환불 요청" 버튼 비활성 (`AppColors.surface` + `AppColors.textMuted`)
- 하단 padding: bottomSafeArea + 16

---

## 신규 다이얼로그 / 시트 명세

### D1. 결제 성공 다이얼로그

> 본 phase 에서 성공 시에는 `PaymentResultPage` 로 이동하므로 별도 다이얼로그는 미사용.
> `PaymentResultPage.success` 변형이 이 역할을 대체함.

---

### D2. 결제 실패 다이얼로그

- 트리거: Toss SDK fail callback 수신 또는 Cloud Functions verifyTossPayment 실패
- dismiss: "닫기" 버튼 (바깥 탭으로는 닫히지 않음 — 사용자가 명시적으로 선택해야 함)
- 위젯: `showDialog` → AlertDialog

구조:
- 아이콘: `Icons.warning_amber_rounded` / size: 48 / `AppColors.error`
- 제목: "결제에 실패했어요" / fontSize: 18 / w700 / `AppColors.textHeading`
- 내용: errorCode 를 사용자 친화 문구로 변환 (developer 전달 항목 참조) / fontSize: 14 / `AppColors.textBody`
- 버튼 Row (gap: 8):
  - "다시 시도": `AppColors.primary` 배경 / `AppColors.onPrimary` / radius: 10 / fontSize: 14 / w600
  - "결제 수단 변경": `AppColors.surfaceElevated` 배경 / `AppColors.border` border / `AppColors.textBody` / radius: 10
  - "닫기": 텍스트 버튼 / `AppColors.textMuted` / fontSize: 13
- 버튼 배열: Column (세로 배열) 또는 Column 내 Row + 텍스트버튼
- dialogBackgroundColor: `AppColors.surfaceElevated`
- radius: 16

---

### D3. 결제 취소 다이얼로그

- 트리거: Toss SDK cancel callback (사용자가 결제창 닫음)
- dismiss: "카트로 돌아가기" 버튼만 (barrierDismissible: false)
- 위젯: `showDialog` → AlertDialog

구조:
- 아이콘: `Icons.info_outline_rounded` / size: 48 / `AppColors.textMuted`
- 제목: "결제가 취소되었어요" / fontSize: 18 / w700 / `AppColors.textHeading`
- 내용: "카트로 돌아가서 다시 시도하실 수 있어요" / fontSize: 14 / `AppColors.textBody`
- 버튼: "카트로 돌아가기" (단일) / 전체 너비 / `AppColors.surfaceElevated` 배경 / `AppColors.border` border / radius: 10
- barrierDismissible: false

---

### D4. 주문 취소 확인 다이얼로그

- 트리거: OrderDetailPage "주문 취소" 버튼 탭
- dismiss: "아니요" 버튼 / 바깥 탭 (barrierDismissible: true)
- 위젯: `showDialog` → AlertDialog

구조:
- 제목: "주문을 취소하시겠어요?" / fontSize: 18 / w700 / `AppColors.textHeading`
- 내용: "취소하면 결제가 자동 환불됩니다." / fontSize: 14 / `AppColors.textBody`
- 버튼 Row:
  - "아니요": `AppColors.surfaceElevated` 배경 / `AppColors.border` border / `AppColors.textBody` / radius: 10
  - "주문 취소": `AppColors.error` 배경 / `AppColors.onPrimary` 텍스트 / radius: 10 (위험 액션이므로 error 색상 사용)
- 버튼 처리 중 (cancelPaidOrderUseCase 호출 중): "주문 취소" 버튼 내 CircularProgressIndicator / `AppColors.onPrimary` / size: 18 / 버튼 disabled

---

### D5. 환불 요청 확인 다이얼로그 (customer)

- 트리거: RefundRequestDialog 에서 "환불 요청" 버튼 탭 (2단계 확인)
- 위젯: `showDialog` → AlertDialog

구조:
- 제목: "환불을 요청하시겠어요?" / fontSize: 18 / w700 / `AppColors.textHeading`
- 내용: "환불 요청 후 매장 승인이 필요합니다.\n승인까지 1~2 영업일 소요될 수 있어요." / fontSize: 14 / `AppColors.textBody`
- 버튼 Row:
  - "취소": outline 스타일
  - "환불 요청": `AppColors.primary` 배경
- 처리 중: "환불 요청" 버튼 로딩 상태

---

### D6. 환불 동의 확인 다이얼로그 (owner)

- 트리거: OwnerRefundRequestTile "승인" 버튼 탭
- dismiss: "취소" 버튼

구조:
- 제목: "환불을 승인하시겠어요?" / fontSize: 18 / w700 / `AppColors.textHeading`
- 내용: "전액 {금액}원이 환불됩니다." / fontSize: 14 / `AppColors.textBody`
- 버튼: "취소" + "환불 승인" (`AppColors.primary`)
- 처리 중: "환불 승인" 버튼 로딩

---

### D7. 환불 거절 사유 다이얼로그 (owner)

- 트리거: OwnerRefundRequestTile "거절" 버튼 탭

구조:
- 제목: "환불 요청 거절" / fontSize: 18 / w700 / `AppColors.textHeading`
- 내용: TextField (거절 사유 입력) / hint: "거절 사유를 입력해주세요" / minLines: 2 / maxLines: 4
- 배경 / 포커스: 입력창 스타일 (C6 RefundRequestDialog 와 동일)
- 버튼: "취소" + "거절" (`AppColors.error` 배경)

---

### D8. 주문 거절 사유 다이얼로그 (owner, 신규 탭)

- 트리거: OwnerNewOrderTile "거절" 버튼 탭

구조:
- 제목: "주문을 거절하시겠어요?" / fontSize: 18 / w700 / `AppColors.textHeading`
- 내용: TextField (거절 사유) / hint: "거절 사유 (선택 입력)" / minLines: 2 / maxLines: 3
- 버튼: "아니요" + "거절" (`AppColors.error` 배경)

---

### D9. 결제 진행 중 로딩 시트

> spec 결정: Toss SDK 가 결제창을 직접 띄우므로 별도 로딩 시트 X.
> CheckoutPage 가 disabled 상태로 남아있고, 결제 버튼 내부에만 CircularProgressIndicator 표시.
> 카카오페이 외부 앱 복귀 후 ~ verifyTossPayment Cloud Functions 응답 대기 구간에는
> CheckoutPage 위에 전체 너비 선형 ProgressIndicator를 AppBar 하단에 표시.
>
> LinearProgressIndicator: color: `AppColors.primary` / backgroundColor: `AppColors.surface` / 높이: 2

---

### D10. 약관 동의 섹션 (CheckoutPage 내 인라인)

- 위젯: Column (체크박스 행 목록), 별도 다이얼로그 아님
- 섹션 헤더: "약관 동의" / fontSize: 15 / w600 / `AppColors.textHeading`

각 약관 행:
- Row: Checkbox + 라벨 텍스트 + 상세보기 링크
- Checkbox:
  - activeColor: `AppColors.primary`
  - checkColor: `AppColors.onPrimary`
  - side: `AppColors.border`
- 라벨: "(필수) 전자결제 이용 약관" / fontSize: 13 / `AppColors.textBody`
- 상세보기 링크: "보기" / fontSize: 12 / `AppColors.primaryBright` (url_launcher 로 Toss 약관 URL 열기)
- 전체 동의 행: 최상단 / CheckboxListTile 스타일 / 라벨: "전체 동의" / fontSize: 14 / w600 / `AppColors.textHeading`

---

## 상태별 UI

### CheckoutPage

#### Loading (결제 진행 중)
- 표시 방식: 결제 버튼 내 CircularProgressIndicator + 페이지 전체 IgnorePointer
- AppBar 하단 LinearProgressIndicator (D9 참조)
- 색상: `AppColors.primary`

#### Error (Toss SDK 초기화 실패 / 카트 검증 실패)
- 표시 방식: `showDialog` (AlertDialog)
- 문구: 에러 종류에 따라 (spec 에러 처리 표 참조)
- 재시도: "뒤로가기" 버튼 → CartPage pop

#### Empty (카트 비어있음)
- CartPage 가드에서 차단하므로 CheckoutPage 자체 empty 상태 없음

---

### PaymentResultPage

#### Loading
- 없음 — Cloud Functions 응답 받은 후 진입하므로 로딩 없음

#### Error
- fail 변형으로 표시 (별도 loading 상태 X)

---

### OrderDetailPage

#### Loading (Firestore stream 초기 로드)
- 표시 방식: 전체 화면 shimmer
- shimmer 구조: AppBar 영역 유지 + 본문 shimmer 블록
  - 상태 뱃지 영역: width: 80 / height: 24 / radius: pill
  - 매장명: width: 160 / height: 20 / radius: 6
  - 아이템 행 3개: 각 height: 56 / radius: 8
  - 가격 요약: height: 80 / radius: 8
- shimmer base: `AppColors.surface` / highlight: `AppColors.surfaceElevated`

#### Error (doc 없음 또는 stream 오류)
- 표시 방식: 화면 중앙 Column
- 아이콘: `Icons.receipt_long_outlined` / size: 56 / `AppColors.textMuted`
- 제목: "주문을 찾을 수 없어요" / fontSize: 16 / `AppColors.textHeading`
- 설명: "이미 삭제되었거나 잘못된 주문입니다" / fontSize: 13 / `AppColors.textMuted`
- 버튼: "돌아가기" / `AppColors.primary`

---

### OrdersPage

#### Loading (stream 초기 로드)
- 표시 방식: ListView shimmer (카드 목업 4개)
- 각 shimmer 카드: height: 90 / radius: 16 / margin: horizontal 20 / vertical 6
- shimmer base: `AppColors.surface` / highlight: `AppColors.surfaceElevated`

#### Error (stream 오류)
- 표시 방식: 화면 중앙 Column
- 아이콘: `Icons.cloud_off_rounded` / size: 56 / `AppColors.error`
- 제목: "불러오는 데 실패했어요" / fontSize: 16 / `AppColors.textHeading`
- 버튼: "다시 시도" / `AppColors.primary`

#### Empty
- 아이콘: `Icons.receipt_long_outlined` / size: 64 / `AppColors.textMuted`
- 제목: "아직 주문이 없어요" / fontSize: 16 / w600 / `AppColors.textHeading`
- 설명: "첫 주문을 남겨보세요, Qrator님" / fontSize: 13 / `AppColors.textMuted`
- CTA 버튼: "둘러보기" / height: 48 / radius: 12 / `AppColors.primary` 배경 / `AppColors.onPrimary` 텍스트

---

### OwnerOrdersPage

#### Loading
- 표시 방식: 각 탭 내 shimmer 카드 3개
- shimmer 카드: height: 110 / radius: 16 / margin: horizontal 16 / vertical 6

#### Error
- 표시 방식: 화면 중앙 Column
- 아이콘: `Icons.cloud_off_rounded` / `AppColors.error`
- 버튼: "다시 시도"

#### Empty (신규 탭)
- 아이콘: `Icons.check_circle_outline_rounded` / size: 56 / `AppColors.success`
- 제목: "신규 주문이 없어요" / fontSize: 15 / `AppColors.textHeading`
- 설명: "새 주문이 들어오면 여기에 표시됩니다" / fontSize: 13 / `AppColors.textMuted`

#### Empty (환불 요청 탭)
- 아이콘: `Icons.check_circle_outline_rounded` / size: 56 / `AppColors.textMuted`
- 제목: "환불 요청이 없어요" / fontSize: 15 / `AppColors.textHeading`

---

## 인터랙션 요약

| 화면 / 컴포넌트 | 동작 | 반응 |
|---|---|---|
| CartPage._CheckoutBar "결제하기" | 탭 | 사전 가드 → CheckoutPage push |
| CheckoutPage PaymentMethodTile | 탭 | 선택 상태 전환 (라디오) |
| CheckoutPage 약관 Checkbox | 탭 | 체크 토글 |
| CheckoutPage "결제하기" 버튼 | 탭 | Toss SDK 호출, 버튼 로딩 상태 |
| PaymentResultPage "주문 상세 보기" | 탭 | OrderDetailPage replace push |
| PaymentResultPage "다시 시도" | 탭 | CheckoutPage 로 pop |
| OrderDetailPage "주문 취소" | 탭 | D4 다이얼로그 표시 |
| OrderDetailPage "환불 요청" | 탭 | C6 시트 표시 |
| OrderDetailPage "영수증 보기" | 탭 | ReceiptWebView push |
| OrdersPage 카드 | 탭 | OrderDetailPage push |
| OrdersPage | Pull-to-refresh | stream 재구독 (RefreshIndicator) |
| OwnerOrdersPage "주문 받기" | 탭 | 즉시 acceptOrderUseCase 호출 (확인 다이얼로그 없음 — 빠른 접수 UX) |
| OwnerOrdersPage "거절" | 탭 | D8 사유 다이얼로그 → cancelPaidOrderUseCase |
| OwnerOrdersPage "승인" (환불) | 탭 | D6 확인 다이얼로그 → processRefundUseCase |
| OwnerOrdersPage "거절" (환불) | 탭 | D7 사유 다이얼로그 → denyRefundRequestUseCase |

---

## Figma 대비 변경사항

Figma 없음. 기존 Qradar 디자인 시스템에서 파생 설계.

| 항목 | 비고 |
|---|---|
| 색상 시스템 | AppColors 토큰 전체 사용. 하드코딩 없음 |
| 카드 스타일 | 기존 home.md 카드 패턴 그대로 (radius: 16 / surface / border) |
| 버튼 스타일 | 기존 primary 버튼 패턴 그대로 |
| OrderStatusBadge | 신규. 알파 배경 + 텍스트 컬러 조합으로 각 상태 구분 |
| 탭 바 (OwnerOrdersPage) | TabBar 표준. indicatorColor: primary |
| 카카오페이 로고 | 애셋 없을 경우 AppColors.kakao 원형 fallback 사용 (developer 에게 전달) |

---

## 개발자 전달 특이사항

### 1. Toss SDK 결제창 — designer 범위 밖

Toss SDK (토스페이먼츠) 가 제공하는 결제창 UI 는 Qradar 디자인 범위 밖이다.
카드 직접 입력창 / 카카오페이 OAuth 화면은 SDK / Kakao 가 제어한다.
designer 는 Toss SDK 호출 전후 (CheckoutPage disabled 상태, PaymentResultPage) 만 명세한다.

### 2. 에러 코드 → 사용자 친화 문구 매핑

developer 가 Toss errorCode 별 한국어 문구 매핑 테이블을 구현해야 한다.
주요 케이스:
- `PAY_PROCESS_CANCELED` → "결제를 취소하셨어요"
- `INVALID_CARD_EXPIRATION` → "카드 유효기간이 올바르지 않아요"
- `EXCEED_MAX_CARD_INSTALLMENT_PLAN` → "할부 한도를 초과했어요"
- `INVALID_STOPPED_CARD` → "정지된 카드예요"
- `EXCEED_MAX_DAILY_PAYMENT_AMOUNT` → "하루 결제 한도를 초과했어요"
- `NOT_SUPPORTED_INSTALLMENT_PLAN_CARD_OR_MERCHANT` → "이 카드는 할부가 지원되지 않아요"
- 그 외: "결제에 실패했어요 (코드: {errorCode})" fallback

### 3. 카카오페이 아이콘 애셋

카카오페이 로고 이미지 애셋 (`assets/icons/kakaopay_logo.png` 등) 이 없을 경우
`AppColors.kakao` (`Color(0xFFFEE500)`) 원형 배경 + "K" 텍스트 fallback 으로 처리한다.
developer 가 실제 로고 애셋 추가 여부 결정.

### 4. 금액 포맷

모든 금액은 `NumberFormat('#,###원', 'ko_KR')` 포맷 사용.
intl 패키지 이미 포함 여부 확인 필요.

### 5. OrdersPage 가 기존 LogPage 를 대체

spec 결정 6 에 의해 `LogPage` 는 `OrdersPage` (orders 컬렉션 기반) 로 대체된다.
기존 `LogPage` 경로 / bottom_nav 탭 라벨은 "Log" (Qradar 고유 용어) 유지.

### 6. OwnerOrdersPage "주문 받기" 확인 다이얼로그 없음

빠른 접수 UX 를 위해 "주문 받기" 는 확인 다이얼로그 없이 즉시 실행한다.
"거절" 은 되돌리기 어려우므로 사유 다이얼로그 필요.

### 7. ReceiptWebView

Toss `receiptUrl` 을 webview_flutter 로 표시한다.
AppBar title: "영수증" / 공유 버튼 (아이콘: `Icons.share_rounded`) 선택적 추가.

### 8. RelativeTimeFormatter

기존 phase 에 없다면 신규 구현 필요 ("방금", "N분 전", "N시간 전", "N일 전").
단, 영수증 / 결제 정보에서는 절대 시각도 함께 표시 (tooltip 또는 부제목 형태).

### 9. shimmer 패키지

shimmer 로딩 효과는 `shimmer` pub 패키지 사용 또는 AnimatedContainer + gradient 직접 구현.
기존 앱에서 이미 사용 중인 방식을 따른다.

### 10. LinearProgressIndicator (결제 중)

카카오페이 외부 앱 복귀 후 ~ verifyTossPayment 응답 대기 구간:
`LinearProgressIndicator` 를 CheckoutPage AppBar 하단 (preferredSize 0) 에 `PreferredSize` 래핑으로 삽입하거나,
Scaffold body 최상단에 2px 높이로 오버레이.
color: `AppColors.primary` / backgroundColor: `AppColors.surface`.

---

## 파일 경로 매핑

| 컴포넌트 | 파일 경로 |
|---|---|
| CheckoutPage | `lib/presentation/customer/checkout/checkout_page.dart` |
| PaymentResultPage | `lib/presentation/customer/checkout/payment_result_page.dart` |
| ReceiptWebView | `lib/presentation/customer/checkout/widgets/receipt_web_view.dart` |
| CheckoutSummaryCard | `lib/presentation/customer/checkout/widgets/checkout_summary_card.dart` |
| PaymentMethodTile | `lib/presentation/customer/checkout/widgets/payment_method_tile.dart` |
| OrdersPage | `lib/presentation/customer/order/orders/orders_page.dart` |
| OrderDetailPage | `lib/presentation/customer/order/orders/order_detail_page.dart` |
| OwnerOrdersPage | `lib/presentation/owner/orders/owner_orders_page.dart` |
| OwnerNewOrderTile | `lib/presentation/owner/orders/widgets/owner_new_order_tile.dart` |
| OwnerRefundRequestTile | `lib/presentation/owner/orders/widgets/owner_refund_request_tile.dart` |
| OrderStatusBadge | `lib/presentation/common/order_status_badge.dart` |
| OrderItemRow | `lib/presentation/common/order_item_row.dart` |
| PriceSummary | `lib/presentation/common/price_summary.dart` |
| RefundRequestDialog | `lib/presentation/common/refund_request_dialog.dart` |

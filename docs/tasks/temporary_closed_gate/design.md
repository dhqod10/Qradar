# temporary_closed_gate 디자인 명세

spec: `docs/tasks/temporary_closed_gate/spec.md` (단일 진실원). 신규 컴포넌트 0개 — 기존 배지/배너/버튼 상태/다이얼로그/스낵바/copy switch 재사용. 색은 `AppColors` 토큰만.

용어: 손님 노출 문구는 **"임시 휴업"** 으로 통일한다. (점주 토글 라벨은 현재 "임시 휴무" — §5 에서 "임시 휴업"으로 맞춘다.)

## 0. 디자인 원칙

- 휴업 매장은 **계속 보인다**(홈/목록 필터 없음). 매장 상세에서 메뉴는 **둘러볼 수 있고**, **담기·결제만 막힌다**. "문 닫은 느낌" = 배지 + 안내 배너 + 비활성 버튼 라벨.
- 휴업은 **빈 상태가 아니라 정상 표시 변형**이다. 품절(`SoldOutOverlay`, 메뉴 단위)과 시각을 섞지 않는다 — 메뉴 카드에는 오버레이/딤을 **넣지 않는다**.
- 휴업은 "곧 다시 열림"의 일시 상태 → 톤은 경고(`error` 계열 약하게), 문구는 "잠시/다시" 유도. `STORE_NOT_SELLABLE`(영구/승인 문제)과 문구 구분.

## 1. 손님 매장 상세 — "임시 휴업중" 표시

진입: 손님 홈 → 매장 → `customer/order/store/store_menu_page.dart`. 상태 소스는 `watchedStoreProvider(storeId)` 의 `store.temporaryClosed` (이미 페이지에서 watch 중).

### 1-1. 헤더 배지 (`store_menu_header.dart`)
- 위치: 헤더 2행(거리 · 영업상태 · 등급배지) 의 `_OpenStatusText` 자리. **`temporaryClosed==true` 이면 `_OpenStatusText` 대신 배지를 그린다**(영업 중/마감 문구와 모순 방지, 우선순위: 휴업 > 영업시간 표시).
- 모양: pill. 높이 22, 가로 padding 8, radius 11.
  - 배경 `AppColors.error`, 글자 `AppColors.onPrimary`, 12sp / w700, 문구 **"임시 휴업중"**. (사진+어두운 그라디언트 위에서도 대비 확보. 헤더는 이미 `onPrimary` 글자 사용.)
  - 앞 아이콘 없음(과설계 방지).
- 접근성: `Semantics(label: '임시 휴업중인 매장')`.
- 이름 Row/등급 배지/즐겨찾기 레이아웃 불변. 거리가 있으면 `거리 · [배지]` 순서 유지(간격 12).

### 1-2. 안내 배너 (헤더 바로 아래, 메뉴 영역 최상단)
- 헤더 직하단에 1줄 안내 스트립(스크롤 영역 맨 위, sticky 아님). `temporaryClosed==true` 일 때만.
- 컨테이너: margin `fromLTRB(16,12,16,0)`, padding 12×14, radius 12, 배경 `AppColors.error.withValues(alpha:0.08)`, 테두리 1px `AppColors.error.withValues(alpha:0.25)`.
- 내용 Row: `Icons.storefront_outlined` 18, `AppColors.error` + 8 간격 + 텍스트(13sp, w600, `AppColors.textHeading`) **"지금은 임시 휴업중이에요"**, 아래 줄(12sp, `AppColors.textBody`) **"메뉴는 볼 수 있지만 주문은 영업을 다시 시작한 뒤에 할 수 있어요."**
- 상호작용 없음(탭 불가).

### 1-3. 메뉴 카드 (`menu_item_card.dart`)
- 변경 없음. 탭 → 메뉴 상세 이동은 허용(둘러보기). 품절 오버레이/딤 금지.

## 2. 손님 담기·결제 비활성

담기는 **메뉴 상세**(`menu_item_detail_page.dart` `_BottomAction`)에서 일어난다. 매장 상세 목록에는 담기 버튼이 없다. 여기가 비활성 지점이다.

### 2-1. 메뉴 상세 하단 담기 버튼 (`_BottomAction`)
- `_BottomAction` 에서 `ref.watch(watchedStoreProvider(storeId))` 의 `temporaryClosed` 를 읽는다(`storeId` 는 페이지가 이미 보유 — `_BottomAction` 으로 전달). 로딩/에러 중엔 `false` 취급(막지 않음; 서버 R1 이 백스톱).
- **기존 `soldOut` 분기와 동일한 패턴을 재사용한다.** 판정 순서: ① soldOut ② **temporaryClosed** ③ `_busy` ④ required 미선택. 품절과 휴업이 동시면 **품절 문구 우선**(메뉴 단위가 더 구체적)이 아니라 **휴업 우선**을 권장한다 — 매장 전체가 닫혀 있으면 품절 여부는 무의미. → 최종: **휴업 > 품절 > 나머지**.
- 휴업 시 버튼: `onPressed: null`(disabled), 배경/글자 = 품절과 동일한 비활성 스타일(`AppColors.surface` / `AppColors.textMuted`), 라벨 **"임시 휴업중"**(16sp, w700). 합계 금액 색은 `AppColors.textMuted`(품절과 동일).
- 토스트/스낵바 **없음**: disabled 버튼 + 라벨이 이유를 이미 말한다(soldOut 도 토스트 없이 라벨로 안내하는 기존 규칙과 일치). soldout_checkout_feedback 스낵바 패턴은 여기엔 **불필요** — 그 패턴은 *활성처럼 보이는 결제 버튼이 눌렸는데 무반응*일 때의 피드백이라 비활성 버튼과 목적이 다르다.
- 상세 페이지 상단/본문 변경 없음(옵션 선택 UI 도 그대로 조작 가능 — 막는 건 담기만; 옵션 영역에 `IgnorePointer` 를 추가로 걸지 않는다. 품절은 걸지만 휴업은 "곧 다시 열림"이라 구경은 허용).
- `_onAddPressed` 시작부에 휴업 재확인(경쟁 상태 방어): `watchedStore.temporaryClosed` 이면 **조용히 return**(품절 방어와 동일).

### 2-2. 이미 카트에 담긴 뒤 휴업된 경우 (카트 → 결제)
카트 진입점은 막지 않는다(담긴 카트는 보존). 결제 시점에 선검증(`StoreViolation.temporarilyClosed`)이 막는다.

| 지점 | 변경 | 문구 |
|---|---|---|
| 카트 상단 `CartAvailabilityBanner` | `CartBannerVariant.storeUnavailable` 과 **분리된 신규 variant 1개** `storeTemporarilyClosed` 추가(= switch 한 줄 + 문구 2개; 컴포넌트 신규 아님. 레이아웃/색 동일, 기존 storeUnavailable 재사용) | title **"매장이 지금 임시 휴업중이에요"** / body **"영업을 다시 시작하면 '다시 확인'을 눌러 결제할 수 있어요. 카트는 그대로 남아 있어요."** |
| 카트 "결제하기" 스낵바 (`cart_page.dart` `_onCheckout`) | 기존 스낵바 문구를 `result.validation.store` 값으로 분기. 지속시간 2초·`clearSnackBars` 불변 | `notSellable`(기존): "지금은 이 매장에서 주문할 수 없어요. 잠시 후 다시 시도해 주세요." 유지 / `temporarilyClosed`: **"지금은 매장이 임시 휴업중이에요. 영업을 다시 시작하면 결제할 수 있어요."** / `notFound`: 기존 처리 유지 |
| 체크아웃 | 변경 없음(`validation.store != null` 이면 기존 `storeBlocked` 경로) | — |

> `variant` 추가가 부담이면 최소안: 배너는 기존 `storeUnavailable` 재사용(문구만 일반적), 스낵바만 분기. 권장은 위 표(배너까지 분기) — 같은 화면에서 배너는 "주문 불가", 스낵바는 "임시 휴업"으로 어긋나는 것을 막기 위해.

## 3. 결제 실패 화면 — `STORE_TEMPORARILY_CLOSED` copy

`payment_failure_copy.dart` `gateFailureCopy` 에 `PaymentFailureReason.storeTemporarilyClosed` case 추가. 레이아웃/버튼 동작은 `storeNotSellable` 과 동일, 문구만 다르다. 돈 줄(`kGateMoneyLine` "아직 결제되지 않았고, 요금도 청구되지 않았어요")은 갈래 B 공통으로 자동 노출.

| 필드 | 값 |
|---|---|
| headline | **지금은 임시 휴업중인 매장이에요** |
| body | **매장이 잠시 문을 닫았어요. 영업을 다시 시작하면 주문할 수 있어요. 잠시 후 다시 시도해 주세요. 카트는 그대로 남아 있어요.** |
| subBody / listHeader | 없음(null) |
| primary | **카트로 돌아가기** → `PaymentFailureAction.popToCart` |
| secondary | **다른 매장 둘러보기** → `PaymentFailureAction.browseStores` (텍스트 버튼, `secondaryIsLine` false) |

구분 포인트(개발자 참고):
- `STORE_NOT_SELLABLE`: "지금은 이 매장에서 주문할 수 없어요 / 잠시 후 다시 시도하거나 다른 매장…" — 이유 불명, 영구 가능.
- `STORE_TEMPORARILY_CLOSED`: 이유 명시(휴업) + "다시 열리면" 재시도 유도. headline 에 "임시 휴업" 포함.
- 서버가 보낸 문자열은 화면에 쓰지 않는다(기존 규칙 — 코드 상수만).

## 4. 점주 — 휴업 전환 차단 다이얼로그

대상: `owner/my_store/store_operation_form_page.dart`. 역할/진입: 점주 스캐폴드 → 내 매장 → 운영 정보 수정 (role_flows "매장 운영 필드 수정"; 신규 진입점 없음).

### 4-1. 트리거
- `_submit()` 에서 `_temporaryClosed==true && widget.existing.temporaryClosed==false`(false→true 전환)일 때만, `_confirmAllOff` 처리 **뒤**·`_submitting=true` **앞/직후**에 활성 주문 1회 조회(paid/accepted/making/ready).
- 조회 중: 저장 버튼 busy(기존 `_submitting` 스피너 그대로). 별도 로딩 UI 없음.
- 진행 중 주문 N≥1: 저장 중단(→ 쓰기 호출 안 함), 아래 다이얼로그 표시, **`_temporaryClosed=false` 로 롤백**(setState, 스위치가 꺼진 모양으로 복귀), `_submitting=false`. 폼에 머문다 — 다른 필드 편집 내용은 유지되므로 점주는 다른 변경만 다시 저장할 수 있다.
- N=0: 정상 저장.

### 4-2. 다이얼로그 (`_confirmAllOff` 의 AlertDialog 스타일 재사용, **버튼 1개**의 안내형)
- 컨테이너: `backgroundColor: AppColors.surfaceElevated`, radius 16 (동일).
- title: **"지금은 임시 휴업할 수 없어요"** (16sp / w700 / `AppColors.textHeading`)
- content: **"진행 중인 주문이 N건 있어요. 주문이 모두 끝나면 임시 휴업을 켤 수 있어요."** (13sp, height 1.5, `AppColors.textBody`). N 은 숫자 그대로("3건").
- actions: 버튼 1개 **"확인"** — `TextButton`, `autofocus: true`, 글자 `AppColors.primary` / w700. (`_confirmAllOff` 의 파괴적 빨강 "저장"과 달리 안내형이므로 primary. 취소/계속 선택지 없음 — 우회 불가.)
- `barrierDismissible` 기본값(true) 허용: 바깥 탭으로 닫아도 동일하게 롤백 완료 상태여야 하므로, 롤백은 다이얼로그 `await` 전에 수행해도 되고 후에 수행해도 되나 **어느 경로로 닫혀도 롤백된 상태**가 되도록 `await` 이후가 아닌 표시 직전에 setState 한다.

### 4-3. 조회 실패(error)
- 막지 않고 저장 진행(spec). 단 사용자가 직접 한 동작이므로 무음 금지: 저장 성공 직후 pop 전에 스낵바 **"진행 중 주문을 확인하지 못했어요. 임시 휴업이 적용돼 신규 주문은 받지 않아요."** (기본 스타일, 2~3초). 점주가 원치 않으면 다시 끄면 됨.

### 4-4. 토글 문구 정리 (`_TemporaryClosedToggle`, 선택 권장 — 용어 통일)
- 제목 "임시 휴무" → **"임시 휴업"**, 설명 "활성화 시 잠시 휴무 상태로 표시돼요." → **"켜면 손님이 이 매장에서 주문할 수 없어요. 진행 중인 주문이 있으면 켤 수 없어요."**
- 스위치 색(`activeThumbColor: AppColors.error` 등) 불변.

## 5. 상태 정리

| 상태 | 처리 |
|---|---|
| loading | 손님: 매장 로딩 중엔 `temporaryClosed` false 취급(배지/배너/비활성 없음, 기존 로딩 UI). 점주: 저장 버튼 `_submitting` 스피너 |
| error | 손님: 매장 읽기 실패 시 막지 않음(서버 R1 백스톱). 점주: §4-3 |
| empty | 해당 없음 — "임시 휴업중"은 빈 상태 아님. 메뉴 목록은 정상 표시, 진행중 주문 0건이면 정상 저장 |
| 휴업 해제(실시간) | `watchedStoreProvider` 스트림 → 배지/배너 사라지고 담기 버튼 즉시 활성 복귀 |

## 6. 개발자 전달 특이사항

1. **표시 지점**: 헤더 배지(`store_menu_header.dart`, `_OpenStatusText` 대체) + 헤더 직하단 배너(`store_menu_page.dart`). 메뉴 카드는 건드리지 않는다(`SoldOutOverlay` 금지).
2. **비활성 처리**: 담기는 `menu_item_detail_page.dart` `_BottomAction` 에서만 — soldOut 패턴 그대로 `onPressed:null` + 라벨 "임시 휴업중" + 금액 muted. 스낵바 불필요. `_onAddPressed` 에 무음 재확인 return. 우선순위 휴업 > 품절 > busy > required. `_BottomAction` 에 `storeId` 전달 필요.
3. **카트**: `CartBannerVariant.storeTemporarilyClosed` 추가(enum switch 컴파일 오류로 누락 방지), 카트 스낵바는 `StoreViolation` 별 분기(기존 `notSellable` 문구 유지). `StoreViolation.temporarilyClosed` 는 spec D4 대로.
4. **사유코드별 copy**: `storeTemporarilyClosed` 신규 case(§3 표). `storeNotSellable` 문구는 변경 금지.
5. **점주 다이얼로그**: `_confirmAllOff` 복제 → 단일 "확인" 버튼 안내형(§4-2). 트리거는 false→true 전환 시만. 차단 시 `_temporaryClosed=false` 롤백 + 폼 잔류. 건수 N 은 활성 주문 조회 결과 개수.
6. 신규 색 토큰/컴포넌트 없음: `error`, `onPrimary`, `textHeading`, `textBody`, `textMuted`, `surface`, `surfaceElevated`, `primary` 만 사용(`withValues(alpha)` 는 기존 코드와 동일 관용).
7. 브랜드 가맹점 운영폼 분기가 있으면 §4 동일 적용(spec D7).

## 7. 사용자 확인이 필요한 결정

- 배지/배너 색을 `error`(빨강 계열)로 한 것 — "마감" 텍스트가 이미 `error` 라 일관. 더 부드러운 톤(`textMuted`)을 원하면 교체 가능.
- 휴업 중에도 메뉴 상세 진입·옵션 선택은 허용(담기만 차단) — 완전 차단(상세 진입 막기)은 과설계로 판단해 제외.
- 점주 토글 라벨 "임시 휴무"→"임시 휴업" 통일(§4-4).

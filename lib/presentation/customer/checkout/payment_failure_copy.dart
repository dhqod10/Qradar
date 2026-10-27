import 'package:qradar/domain/entities/payment_failure.dart';

/// 결제 실패 화면 버튼이 하는 일 (design §3.1 "버튼 동작 정의").
enum PaymentFailureAction {
  /// `Navigator.pop()` — 체크아웃을 대체한 결제 화면에서 카트로 돌아간다.
  popToCart,

  /// 홈 탭으로 (카트 유지).
  browseStores,

  /// 카트 비우기 후 첫 화면으로 (확인 다이얼로그 없음).
  clearCartAndBrowse,

  /// Log 탭(3)으로.
  goToLog,

  /// `최신 가격으로 다시 담기` (payment_price_authority design P1) — 단순 pop 이 아니다. 신선 읽기로 카트를 재가격하고
  /// **적용한 뒤** 카트로 보낸다. 실패하면 이 화면에 머문다. 이 동작은 `PRICE_MISMATCH` 기본형의 주 버튼 하나에만 쓴다.
  repriceAndReturn,
}

/// 갈래 B 한 사유의 화면 문구 (design §3.1 표). **서버가 보낸 문자열은 어디에도 들어오지 않는다.**
class GateFailureCopy {
  const GateFailureCopy({
    required this.headline,
    required this.body,
    this.subBody,
    this.listHeader,
    required this.primaryLabel,
    required this.primaryAction,
    this.secondaryLabel,
    this.secondaryAction,
    this.secondaryIsLine = false,
  });

  final String headline;
  final String body;
  final String? subBody;

  /// 메뉴 목록 카드 헤더. null 이면 메뉴 사유가 아니다 (카드 없음).
  final String? listHeader;
  final String primaryLabel;
  final PaymentFailureAction primaryAction;
  final String? secondaryLabel;
  final PaymentFailureAction? secondaryAction;

  /// 보조 버튼을 라인 버튼으로 그린다 (기본은 텍스트 버튼). `PRICE_MISMATCH` 는 보조 버튼도 의미 있는 선택지다.
  final bool secondaryIsLine;
}

/// 돈 줄 (design §3.4). 갈래 B 에서만 쓴다.
const String kGateMoneyLine = '아직 결제되지 않았고, 요금도 청구되지 않았어요';

// ── 가격 거절 화면 (payment_price_authority design §4.2) ─────────────────────────
// 이 화면에는 금액 숫자가 없다 (Q6=ⓒ) — 숫자는 카트로 돌아간 뒤 재가격 결과로 보인다. 서버 문자열도 보간하지 않는다.

/// `PRICE_MISMATCH` 기본형 주 버튼. 누르면 신선 읽기로 카트를 다시 맞춘다.
const String kRepriceLabel = '최신 가격으로 다시 담기';

/// 재가격 읽기 실패 시 주 버튼 라벨 (같은 동작).
const String kRepriceRetryLabel = '다시 불러오기';

/// 재가격 읽기 실패 인라인 문구 — 사용자가 직접 누른 동작이므로 무음 금지 (design N3).
const String kRepriceErrorText = '최신 가격을 불러오지 못했어요. 네트워크를 확인하고 다시 눌러 주세요.';

/// 연속 2회 이상 실패했을 때 덧붙이는 한 줄.
const String kRepriceErrorHint = '계속 안 되면 카트에서 메뉴를 빼고 다시 담아 보세요.';

/// 재가격 진행 중 스크린리더 라벨.
const String kRepriceBusySemantics = '가격을 다시 불러오는 중';

/// 갈래 B 사유별 문구. [hasNames] 는 메뉴 이름을 하나라도 해석했는지다 (design §3.6 empty 행).
/// 알려진 6개 사유 모두에 값이 있어야 한다 (사유가 추가되면 이 switch 가 컴파일 오류로 알려 준다).
///
/// [repeated] 는 `PRICE_MISMATCH` 에서만 의미가 있다: 같은 카트로 재가격을 이미 한 번 적용했거나 재가격해도 달라진 게 없을 때
/// (**변형 N**, design P2 루프 차단기) — 재가격 버튼을 다시 주지 않는다.
GateFailureCopy gateFailureCopy(
  PaymentFailureReason reason, {
  required bool hasNames,
  bool repeated = false,
}) {
  switch (reason) {
    case PaymentFailureReason.priceMismatch:
      if (repeated) {
        return const GateFailureCopy(
          headline: '가격을 다시 확인했는데 달라진 게 없어요',
          body: '카트의 금액은 지금 가격과 같아요. 가격이 잠깐 바뀌었다가 돌아왔을 수 있어요. 카트로 돌아가 다시 결제해 보세요.',
          subBody:
              '같은 화면이 계속 나오면 카트를 비우고 메뉴를 다시 담아 보세요. 그래도 안 되면 아래 오류 코드와 함께 관리자에게 문의해 주세요.',
          primaryLabel: '카트로 돌아가기',
          primaryAction: PaymentFailureAction.popToCart,
          secondaryLabel: '카트 비우고 메뉴 보러가기',
          secondaryAction: PaymentFailureAction.clearCartAndBrowse,
          secondaryIsLine: true,
        );
      }
      return GateFailureCopy(
        headline: '메뉴 가격이 바뀌었어요',
        body: '카트에 담은 뒤에 가격이 바뀐 메뉴가 있어요. 최신 가격으로 다시 담으면 바뀐 금액을 카트에서 확인하고 결제할 수 있어요.',
        subBody: '카트에 담은 메뉴와 수량은 그대로 남아요.',
        listHeader: hasNames ? '가격을 다시 확인할 메뉴' : null,
        primaryLabel: kRepriceLabel,
        primaryAction: PaymentFailureAction.repriceAndReturn,
        secondaryLabel: '카트로 돌아가기',
        secondaryAction: PaymentFailureAction.popToCart,
        secondaryIsLine: true,
      );
    case PaymentFailureReason.optionUnavailable:
      return GateFailureCopy(
        headline: '선택하신 옵션이 바뀌었어요',
        body: hasNames
            ? '아래 메뉴에서 고르신 옵션을 지금은 선택할 수 없어요. 카트에서 어떤 옵션인지 확인하고 다시 골라 주세요.'
            : '선택하신 옵션이 바뀐 메뉴가 있어요. 카트에서 확인해 주세요.',
        subBody: '옵션이 바뀌면 가격도 함께 바뀔 수 있어요. 다시 고른 뒤 카트에서 새 금액을 확인해 주세요.',
        listHeader: '옵션을 다시 골라야 하는 메뉴',
        primaryLabel: '카트에서 확인하기',
        primaryAction: PaymentFailureAction.popToCart,
        secondaryLabel: '닫기',
        secondaryAction: PaymentFailureAction.popToCart,
      );
    case PaymentFailureReason.menuSoldOut:
      return GateFailureCopy(
        headline: '품절된 메뉴가 있어요',
        body: hasNames
            ? '아래 메뉴를 카트에서 빼고 다시 결제해 주세요.'
            : '품절된 메뉴가 있어요. 카트에서 확인해 주세요.',
        subBody: '품절이 아닌데 계속 이렇게 나오면 잠시 후 다시 시도하거나 매장에 확인해 주세요.',
        listHeader: '지금 품절인 메뉴',
        primaryLabel: '카트에서 확인하기',
        primaryAction: PaymentFailureAction.popToCart,
        secondaryLabel: '닫기',
        secondaryAction: PaymentFailureAction.popToCart,
      );
    case PaymentFailureReason.menuExcluded:
      return GateFailureCopy(
        headline: '판매가 중단된 메뉴가 있어요',
        body: hasNames
            ? '이 매장에서 더 이상 판매하지 않는 메뉴예요. 카트에서 빼고 다시 결제해 주세요.'
            : '판매가 중단된 메뉴가 있어요. 카트에서 확인해 주세요.',
        listHeader: '판매가 중단된 메뉴',
        primaryLabel: '카트에서 확인하기',
        primaryAction: PaymentFailureAction.popToCart,
        secondaryLabel: '닫기',
        secondaryAction: PaymentFailureAction.popToCart,
      );
    case PaymentFailureReason.menuNotFound:
      // 이름을 알면 그 메뉴만 빼게 하고, 모르면 그때만 카트를 비우게 한다 (design §3.1 표 아래 변경점).
      if (hasNames) {
        return const GateFailureCopy(
          headline: '메뉴 정보가 바뀌었어요',
          body: '아래 메뉴를 찾을 수 없어요. 카트에서 빼고 다시 결제해 주세요.',
          listHeader: '찾을 수 없는 메뉴',
          primaryLabel: '카트에서 확인하기',
          primaryAction: PaymentFailureAction.popToCart,
          secondaryLabel: '닫기',
          secondaryAction: PaymentFailureAction.popToCart,
        );
      }
      return const GateFailureCopy(
        headline: '메뉴 정보가 바뀌었어요',
        body: '카트를 비우고 메뉴를 다시 담아 주세요.',
        primaryLabel: '카트 비우고 메뉴 보러가기',
        primaryAction: PaymentFailureAction.clearCartAndBrowse,
        secondaryLabel: '닫기',
        secondaryAction: PaymentFailureAction.popToCart,
      );
    case PaymentFailureReason.storeNotSellable:
      return const GateFailureCopy(
        headline: '지금은 이 매장에서 주문할 수 없어요',
        body: '잠시 후 다시 시도하거나 다른 매장에서 주문해 주세요. 카트는 그대로 남아 있어요.',
        primaryLabel: '카트로 돌아가기',
        primaryAction: PaymentFailureAction.popToCart,
        secondaryLabel: '다른 매장 둘러보기',
        secondaryAction: PaymentFailureAction.browseStores,
      );
    case PaymentFailureReason.storeNotFound:
      return const GateFailureCopy(
        headline: '매장 정보를 찾을 수 없어요',
        body: '이 매장에서는 더 이상 주문할 수 없어요. 카트를 비우고 다른 매장에서 담아 주세요.',
        primaryLabel: '카트 비우고 메뉴 보러가기',
        primaryAction: PaymentFailureAction.clearCartAndBrowse,
        secondaryLabel: '닫기',
        secondaryAction: PaymentFailureAction.popToCart,
      );
    case PaymentFailureReason.readFailed:
      return const GateFailureCopy(
        headline: '일시적인 오류가 생겼어요',
        body: '잠시 후 다시 시도해 주세요. 카트는 그대로 남아 있어요.',
        primaryLabel: '카트로 돌아가기',
        primaryAction: PaymentFailureAction.popToCart,
      );
    case PaymentFailureReason.unknown:
      // 갈래 B 에 들어올 수 없다 (PaymentFailure.from 이 갈래 C 로 보낸다). 방어적으로 갈래 C 와 같은 안전 방향.
      return gateFailureCopy(PaymentFailureReason.readFailed, hasNames: false);
  }
}

// ── 갈래 C (design §3.3) — 돈의 상태를 모른다. `요금`/`청구` 단어를 쓰지 않는다 ───────────────

const String kUnknownHeadline = '주문이 완료됐는지 확인이 필요해요';
const String kUnknownBody =
    '결제를 확인하는 중에 문제가 생겼어요. 이미 결제가 처리됐을 수 있어요. Log 에서 주문이 보이는지 먼저 확인해 주세요.';
// design §3.3 원문은 "요금이 청구됐는데 ..." 였으나 spec §18.3 6-c ⓒ (갈래 C 에 요금/청구 0건) 가드와 충돌해 단어를 뺐다.
const String kUnknownSubBody =
    'Log 에 주문이 없다면 잠시 후 다시 결제해 주세요. 결제는 됐는데 주문이 없으면 관리자에게 문의해 주세요.';
const String kUnknownPrimaryLabel = 'Log 에서 확인하기';
const String kUnknownSecondaryLabel = '카트로 돌아가기';

// ── 갈래 A (design §3.2) ───────────────────────────────────────────────────────

const String kLaunchHeadline = '결제에 실패했어요';
const String kLaunchDefaultMessage = '결제를 완료하지 못했어요. 다른 결제수단으로 다시 시도해 주세요';

/// Toss errorCode → 문구. 매핑에 없으면 null (호출자가 [kLaunchDefaultMessage] 를 쓴다). 원문은 받지 않는다.
String? launchMessageFor(String? code) {
  switch (code) {
    case 'USER_CANCEL':
      return '사용자가 결제를 취소했습니다';
    case 'PAY_PROCESS_CANCELED':
      return '결제가 취소되었습니다';
    case 'PAY_PROCESS_ABORTED':
      return '결제가 중단되었습니다';
    case 'REJECT_CARD_COMPANY':
      return '카드사 승인 거절. 다른 결제수단을 이용해주세요';
    case 'INVALID_CARD':
      return '유효하지 않은 카드입니다';
    case 'NOT_ENOUGH_BALANCE':
      return '잔액이 부족합니다';
    case 'INVALID_CARD_EXPIRATION':
      return '카드 유효기간이 올바르지 않아요';
    case 'EXCEED_MAX_CARD_INSTALLMENT_PLAN':
      return '할부 한도를 초과했어요';
    case 'INVALID_STOPPED_CARD':
      return '정지된 카드예요';
    case 'EXCEED_MAX_DAILY_PAYMENT_AMOUNT':
      return '하루 결제 한도를 초과했어요';
    case 'NOT_SUPPORTED_INSTALLMENT_PLAN_CARD_OR_MERCHANT':
      return '이 카드는 할부가 지원되지 않아요';
    default:
      return null;
  }
}

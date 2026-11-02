import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/utils/qoin_spend_calculator.dart';
import 'package:qradar/presentation/common/providers/qoin_config_providers.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';
import 'package:qradar/presentation/customer/cart/providers/cart_providers.dart';

/// 체크아웃에서 고객이 입력한 Qoin 사용액 (원시 값). 체크아웃을 나가면 폐기된다 (재진입 시 0, design §7).
///
/// **이 값은 요청일 뿐이다.** 실제로 적용되는 값은 [qoinSpendViewProvider] 의 `applied` (한도로 클램프) 이고,
/// 서버가 최종 판정한다. 위젯이 한도 초과 입력을 즉시 잘라 이 값에 쓰므로 보통은 둘이 같다.
class QoinToUseNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int value) => state = value < 0 ? 0 : value;
}

final qoinToUseProvider =
    NotifierProvider.autoDispose<QoinToUseNotifier, int>(QoinToUseNotifier.new);

/// Qoin 사용 섹션의 상태 (design §3, §5).
enum QoinSpendPhase {
  /// 섹션 숨김: 사용 중지(S4) · 정책/잔액 로드 실패(S5) · 로그인 없음 · 카트 없음. 기존 결제(사용 0)로 폴백한다.
  hidden,

  /// 정책 또는 잔액 로딩 중 — skeleton. 로딩 중 `0 Q` 절대 표시 금지.
  loading,

  /// S1 잔액 0.
  noBalance,

  /// S2 음수 잔액.
  negativeBalance,

  /// S3 주문이 작아 `소계 − 최소현금 ≤ 0`.
  orderTooSmall,

  /// 입력 가능.
  active,
}

class QoinSpendView {
  const QoinSpendView({
    required this.phase,
    this.balance = 0,
    this.subtotal = 0,
    this.policy = QoinSpendPolicy.disabled,
    this.maxSpendable = 0,
    this.limitedBy = QoinSpendLimitedBy.none,
    this.applied = 0,
  });

  /// 숨김 · 로딩 (사용 0).
  const QoinSpendView.inactive(this.phase)
    : balance = 0,
      subtotal = 0,
      policy = QoinSpendPolicy.disabled,
      maxSpendable = 0,
      limitedBy = QoinSpendLimitedBy.none,
      applied = 0;

  final QoinSpendPhase phase;
  final int balance;
  final int subtotal;
  final QoinSpendPolicy policy;

  /// 표시용 사용가능액 (권위는 서버).
  final int maxSpendable;
  final QoinSpendLimitedBy limitedBy;

  /// 결제에 적용되는 Qoin. [QoinSpendPhase.active] 가 아니면 항상 0 — **결제 금액·`qoinToUse` 는 이 값만 쓴다.**
  final int applied;

  /// 결제 예정 금액 (소계 − 적용 Qoin). `subtotal` 은 [active]/[noBalance]… 에서만 채워지므로 호출부는 cart 소계로 계산해도 된다.
  int finalAmount(int cartSubtotal) =>
      QoinSpendCalculator.finalAmount(subtotal: cartSubtotal, qoinToUse: applied);
}

/// 잔액 + 정책 + 카트 소계 → 섹션 상태 · 사용가능액 · 적용액. 신규 구독 없음 (이미 구독 중인 프로필/설정/카트 스트림).
final qoinSpendViewProvider = Provider.autoDispose<QoinSpendView>((ref) {
  final cart = ref.watch(cartProvider);
  final profile = ref.watch(currentUserProfileProvider);
  final config = ref.watch(qoinConfigProvider);
  final requested = ref.watch(qoinToUseProvider);

  final cartValue = cart.asData?.value;
  if (cartValue == null) return const QoinSpendView.inactive(QoinSpendPhase.hidden);

  // 에러는 숨김 (틀린 정책/잔액으로 차감을 유도하지 않는다 — spec §2.3). 로딩은 skeleton.
  if (profile.hasError || config.hasError) {
    return const QoinSpendView.inactive(QoinSpendPhase.hidden);
  }
  if (!profile.hasValue || !config.hasValue) {
    return const QoinSpendView.inactive(QoinSpendPhase.loading);
  }
  final user = profile.value;
  final cfg = config.value;
  if (user == null || cfg == null) {
    return const QoinSpendView.inactive(QoinSpendPhase.hidden);
  }
  final policy = cfg.spendPolicy;
  if (!policy.enabled) {
    return const QoinSpendView.inactive(QoinSpendPhase.hidden); // S4: 사용 중지 → 통째로 숨김 (DD-1)
  }

  final balance = user.qoinBalance;
  final subtotal = cartValue.subtotal;
  final max = QoinSpendCalculator.maxSpendable(
    balance: balance,
    subtotal: subtotal,
    policy: policy,
  );
  final QoinSpendPhase phase;
  if (balance < 0) {
    phase = QoinSpendPhase.negativeBalance;
  } else if (balance == 0) {
    phase = QoinSpendPhase.noBalance;
  } else if (max <= 0) {
    phase = QoinSpendPhase.orderTooSmall;
  } else {
    phase = QoinSpendPhase.active;
  }
  final active = phase == QoinSpendPhase.active;
  return QoinSpendView(
    phase: phase,
    balance: balance,
    subtotal: subtotal,
    policy: policy,
    maxSpendable: max,
    limitedBy: QoinSpendCalculator.limitedBy(
      balance: balance,
      subtotal: subtotal,
      policy: policy,
    ),
    applied: active
        ? QoinSpendCalculator.clamp(
            requested: requested,
            balance: balance,
            subtotal: subtotal,
            policy: policy,
          )
        : 0,
  );
});

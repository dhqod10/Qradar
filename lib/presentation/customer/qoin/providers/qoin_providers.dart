import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/order_status.dart';
import 'package:qradar/domain/entities/qoin_config_entity.dart';
import 'package:qradar/domain/entities/qoin_transaction_entity.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';
import 'package:qradar/presentation/customer/order/orders/providers/order_view_providers.dart';
import 'package:qradar/presentation/customer/qoin/providers/qoin_di_providers.dart';

/// 본인 Qoin 내역 (최신순, 상한 [QoinPolicy.historyLimit]).
///
/// 프로필이 아직 없으면(로딩/로그아웃) 빈 목록이 아니라 **스트림을 만들지 않고 대기**한다 —
/// 로딩 중 "내역 없음" 이 보이면 안 된다.
final qoinTransactionsProvider = StreamProvider<List<QoinTransactionEntity>>((
  ref,
) {
  // uid 만 select — 잔액 변경(프로필 갱신) 때마다 내역 스트림을 재구독하지 않는다.
  final uid = ref.watch(
    currentUserProfileProvider.select((a) => a.asData?.value?.uid),
  );
  if (uid == null) return const Stream.empty();
  return ref.watch(watchQoinTransactionsUseCaseProvider)(
    uid,
    limit: QoinPolicy.historyLimit,
  );
});

/// `config/qoin` (null = 문서 없음). 고객은 안내 문구, 관리자는 편집 화면이 사용.
final qoinConfigProvider = StreamProvider<QoinConfigEntity?>((ref) {
  return ref.watch(watchQoinConfigUseCaseProvider)();
});

/// 진행 중(paid~ready) 주문 건수. 로딩/에러면 null (배너 생략).
final qoinInProgressOrderCountProvider = Provider<int?>((ref) {
  final async = ref.watch(myOrdersProvider);
  final orders = async.asData?.value;
  if (orders == null) return null;
  return orders.where(_isInProgress).length;
});

bool _isInProgress(OrderEntity o) =>
    o.status == OrderStatus.paid ||
    o.status == OrderStatus.accepted ||
    o.status == OrderStatus.making ||
    o.status == OrderStatus.ready;

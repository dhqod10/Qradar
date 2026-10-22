import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/cloud_functions_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/order_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/toss_payment_remote_data_source.dart';
import 'package:qradar/data/repositories/order_repository_impl.dart';
import 'package:qradar/data/repositories/payment_gateway_repository_impl.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/order_status.dart';
import 'package:qradar/domain/repositories/order_repository.dart';
import 'package:qradar/domain/repositories/payment_gateway_repository.dart';
import 'package:qradar/domain/usecases/accept_order_use_case.dart';
import 'package:qradar/domain/usecases/cancel_paid_order_use_case.dart';
import 'package:qradar/domain/usecases/deny_refund_request_use_case.dart';
import 'package:qradar/domain/usecases/launch_payment_use_case.dart';
import 'package:qradar/domain/usecases/mark_order_completed_use_case.dart';
import 'package:qradar/domain/usecases/mark_order_ready_use_case.dart';
import 'package:qradar/domain/usecases/process_refund_use_case.dart';
import 'package:qradar/domain/usecases/request_refund_use_case.dart';
import 'package:qradar/domain/usecases/start_making_order_use_case.dart';
import 'package:qradar/domain/usecases/verify_and_create_order_use_case.dart';
import 'package:qradar/domain/usecases/watch_order_use_case.dart';
import 'package:qradar/domain/usecases/watch_store_orders_use_case.dart';
import 'package:qradar/domain/usecases/watch_store_refund_requests_use_case.dart';
import 'package:qradar/domain/usecases/watch_user_orders_use_case.dart';

// ── DataSource ────────────────────────────────────────────────────────────────

final orderRemoteDataSourceProvider = Provider<OrderRemoteDataSource>((ref) {
  return OrderRemoteDataSource();
});

final tossPaymentRemoteDataSourceProvider =
    Provider<TossPaymentRemoteDataSource>((ref) {
  return TossPaymentRemoteDataSource();
});

final cloudFunctionsRemoteDataSourceProvider =
    Provider<CloudFunctionsRemoteDataSource>((ref) {
  return CloudFunctionsRemoteDataSource();
});

// ── Repository ────────────────────────────────────────────────────────────────

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepositoryImpl(ref.watch(orderRemoteDataSourceProvider));
});

final paymentGatewayRepositoryProvider =
    Provider<PaymentGatewayRepository>((ref) {
  return PaymentGatewayRepositoryImpl(
    tossDs: ref.watch(tossPaymentRemoteDataSourceProvider),
    functionsDs: ref.watch(cloudFunctionsRemoteDataSourceProvider),
    orderDs: ref.watch(orderRemoteDataSourceProvider),
  );
});

// ── UseCase ───────────────────────────────────────────────────────────────────

final launchPaymentUseCaseProvider = Provider<LaunchPaymentUseCase>((ref) {
  return LaunchPaymentUseCase(ref.watch(paymentGatewayRepositoryProvider));
});

final verifyAndCreateOrderUseCaseProvider =
    Provider<VerifyAndCreateOrderUseCase>((ref) {
  return VerifyAndCreateOrderUseCase(
    ref.watch(paymentGatewayRepositoryProvider),
  );
});

final cancelPaidOrderUseCaseProvider = Provider<CancelPaidOrderUseCase>((ref) {
  return CancelPaidOrderUseCase(ref.watch(paymentGatewayRepositoryProvider));
});

final requestRefundUseCaseProvider = Provider<RequestRefundUseCase>((ref) {
  return RequestRefundUseCase(ref.watch(orderRepositoryProvider));
});

final acceptOrderUseCaseProvider = Provider<AcceptOrderUseCase>((ref) {
  return AcceptOrderUseCase(ref.watch(orderRepositoryProvider));
});

final processRefundUseCaseProvider = Provider<ProcessRefundUseCase>((ref) {
  return ProcessRefundUseCase(ref.watch(paymentGatewayRepositoryProvider));
});

final denyRefundRequestUseCaseProvider =
    Provider<DenyRefundRequestUseCase>((ref) {
  return DenyRefundRequestUseCase(ref.watch(orderRepositoryProvider));
});

final watchOrderUseCaseProvider = Provider<WatchOrderUseCase>((ref) {
  return WatchOrderUseCase(ref.watch(orderRepositoryProvider));
});

final watchUserOrdersUseCaseProvider = Provider<WatchUserOrdersUseCase>((ref) {
  return WatchUserOrdersUseCase(ref.watch(orderRepositoryProvider));
});

final watchStoreOrdersUseCaseProvider =
    Provider<WatchStoreOrdersUseCase>((ref) {
  return WatchStoreOrdersUseCase(ref.watch(orderRepositoryProvider));
});

final watchStoreRefundRequestsUseCaseProvider =
    Provider<WatchStoreRefundRequestsUseCase>((ref) {
  return WatchStoreRefundRequestsUseCase(ref.watch(orderRepositoryProvider));
});

final startMakingOrderUseCaseProvider =
    Provider<StartMakingOrderUseCase>((ref) {
  return StartMakingOrderUseCase(ref.watch(orderRepositoryProvider));
});

final markOrderReadyUseCaseProvider = Provider<MarkOrderReadyUseCase>((ref) {
  return MarkOrderReadyUseCase(ref.watch(orderRepositoryProvider));
});

final markOrderCompletedUseCaseProvider =
    Provider<MarkOrderCompletedUseCase>((ref) {
  return MarkOrderCompletedUseCase(ref.watch(orderRepositoryProvider));
});

// ── Stream Provider (family) ─────────────────────────────────────────────────

/// 점주 주문 접수 페이지 "신규" 탭 — paid 상태 주문 stream.
///
/// build() 안에서 inline StreamProvider 를 만들면 매 rebuild 마다 새 인스턴스가
/// 생성되어 첫 snapshot 직전 loading 에 머무는 antipattern 이 발생. family 로 추출.
final newOrdersByStoreProvider =
    StreamProvider.family<List<OrderEntity>, String>((ref, storeId) {
  return ref
      .read(watchStoreOrdersUseCaseProvider)
      .call(storeId, statusFilter: {OrderStatus.paid});
});

/// 점주 주문 접수 페이지 "조리 중" 탭 — accepted + making + ready 상태 주문 stream.
/// (점주가 받기 후 조리 시작 전 대기 중인 accepted 도 포함하여
/// "진행 중인 모든 주문" 을 한 화면에서 관리 가능하도록 보강.)
final inProgressOrdersByStoreProvider =
    StreamProvider.family<List<OrderEntity>, String>((ref, storeId) {
  return ref.read(watchStoreOrdersUseCaseProvider).call(
    storeId,
    statusFilter: {
      OrderStatus.accepted,
      OrderStatus.making,
      OrderStatus.ready,
    },
  );
});

/// 점주 주문 접수 페이지 "환불 요청" 탭 — refundRequest 가 존재하는 주문 stream.
final refundRequestsByStoreProvider =
    StreamProvider.family<List<OrderEntity>, String>((ref, storeId) {
  return ref.read(watchStoreRefundRequestsUseCaseProvider).call(storeId);
});

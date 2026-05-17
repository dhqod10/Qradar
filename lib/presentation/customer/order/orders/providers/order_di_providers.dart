import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/cloud_functions_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/order_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/toss_payment_remote_data_source.dart';
import 'package:qradar/data/repositories/no_op_qoin_accrual_hook.dart';
import 'package:qradar/data/repositories/order_repository_impl.dart';
import 'package:qradar/data/repositories/payment_gateway_repository_impl.dart';
import 'package:qradar/domain/repositories/order_repository.dart';
import 'package:qradar/domain/repositories/payment_gateway_repository.dart';
import 'package:qradar/domain/repositories/qoin_accrual_hook.dart';
import 'package:qradar/domain/usecases/accept_order_use_case.dart';
import 'package:qradar/domain/usecases/cancel_paid_order_use_case.dart';
import 'package:qradar/domain/usecases/deny_refund_request_use_case.dart';
import 'package:qradar/domain/usecases/launch_payment_use_case.dart';
import 'package:qradar/domain/usecases/process_refund_use_case.dart';
import 'package:qradar/domain/usecases/request_refund_use_case.dart';
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

/// Phase 3a 는 NoOp. Phase 4 에서 real 구현체로 override.
final qoinAccrualHookProvider = Provider<QoinAccrualHook>((ref) {
  return const NoOpQoinAccrualHook();
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

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';
import 'package:qradar/presentation/customer/order/orders/providers/order_di_providers.dart';

/// 단일 주문 실시간 스트림. [orderId] 기준.
final currentOrderProvider =
    StreamProvider.family<OrderEntity?, String>((ref, orderId) {
  final useCase = ref.watch(watchOrderUseCaseProvider);
  return useCase(orderId);
});

/// 현재 로그인 사용자의 주문 목록 실시간 스트림.
///
/// uid 를 [currentUserProfileProvider] 에서 가져온다.
/// 로그인 전(uid 없음)이면 빈 리스트를 반환한다.
final myOrdersProvider = StreamProvider<List<OrderEntity>>((ref) {
  final profile = ref.watch(currentUserProfileProvider).asData?.value;
  if (profile == null) return Stream.value([]);
  final useCase = ref.watch(watchUserOrdersUseCaseProvider);
  return useCase(profile.uid);
});

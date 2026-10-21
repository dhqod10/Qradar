import 'package:flutter/material.dart';
import 'package:qradar/domain/entities/remote_notification_message.dart';
import 'package:qradar/presentation/customer/order/orders/order_detail_page.dart';
import 'package:qradar/presentation/owner/orders/owner_order_detail_page.dart';

/// FCM 메시지를 받아 적절한 화면으로 이동시킨다.
///
/// [navigatorKey] 로 전역 Navigator 에 접근하므로 `MaterialApp.navigatorKey` 와
/// 동일한 키를 주입해야 한다.
///
/// role 별 분기:
/// - owner: [newOrder] / [refundRequest] → [OwnerOrderDetailPage]
/// - customer: [orderAccepted] / [orderMaking] / [orderReady] / [orderCompleted]
///   → [OrderDetailPage]
///   (Phase 3c-2 에서 customer status 전이 알림 추가, Phase 3c-3 에서 orderCompleted 추가)
class NotificationNavigator {
  const NotificationNavigator._();

  static void navigate({
    required GlobalKey<NavigatorState> navigatorKey,
    required RemoteNotificationMessage message,
  }) {
    final orderId = message.orderId;
    if (orderId == null) return;

    switch (message.type) {
      // owner: 새 주문 / 환불 요청 → 점주 주문 상세
      case NotificationType.newOrder:
      case NotificationType.refundRequest:
        navigatorKey.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => OwnerOrderDetailPage(orderId: orderId),
          ),
        );
      // customer: 주문 status 전이 알림 → 고객 주문 상세 (Phase 3c-2)
      case NotificationType.orderAccepted:
      case NotificationType.orderMaking:
      case NotificationType.orderReady:
      case NotificationType.orderCompleted:
        navigatorKey.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => OrderDetailPage(orderId: orderId),
          ),
        );
      case NotificationType.unknown:
        // 처리하지 않음
        break;
    }
  }
}

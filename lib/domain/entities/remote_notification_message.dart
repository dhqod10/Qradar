/// FCM 메시지 타입 (외부 SDK 의존 차단 — domain 전용 enum).
enum NotificationType {
  newOrder,
  refundRequest,
  // Phase 3c-2: 고객 주문 status 전이 알림 (3건 — ready→completed 미발화)
  orderAccepted,
  orderMaking,
  orderReady,
  // Phase 3c-3: 픽업 완료 (옵트인 — pickupComplete 설정)
  orderCompleted,
  unknown,
}

/// FCM 원격 메시지 domain 표현.
///
/// `firebase_messaging` 의 `RemoteMessage` 를 data 레이어에서 변환해 도메인에 전달.
/// presentation / domain 레이어가 FirebaseMessaging SDK 를 직접 참조하지 않는다.
class RemoteNotificationMessage {
  final NotificationType type;
  final String? orderId;
  final String? storeId;
  final String? title;
  final String? body;

  const RemoteNotificationMessage({
    required this.type,
    this.orderId,
    this.storeId,
    this.title,
    this.body,
  });

  /// FCM data payload Map 에서 파싱.
  factory RemoteNotificationMessage.fromData(Map<String, dynamic> data) {
    final typeStr = data['type'] as String? ?? '';
    final type = switch (typeStr) {
      'new_order' => NotificationType.newOrder,
      'refund_request' => NotificationType.refundRequest,
      'order_accepted' => NotificationType.orderAccepted,
      'order_making' => NotificationType.orderMaking,
      'order_ready' => NotificationType.orderReady,
      'order_completed' => NotificationType.orderCompleted,
      _ => NotificationType.unknown,
    };
    return RemoteNotificationMessage(
      type: type,
      orderId: data['orderId'] as String?,
      storeId: data['storeId'] as String?,
      title: data['title'] as String?,
      body: data['body'] as String?,
    );
  }
}

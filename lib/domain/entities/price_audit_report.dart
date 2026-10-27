// TEMP_PRICE_AUDIT_CARD — payment_price_authority 배포 ②⑨ 용 임시 자산. 배포 ⑩ 정리 커밋에서 삭제한다.

/// 주문 Tier 1 위반 1건 (서버가 보고한 값 — 이 앱이 계산한 것이 아니다).
class PriceAuditOrderViolation {
  const PriceAuditOrderViolation({
    required this.orderId,
    required this.storeId,
    required this.failed,
    required this.malformed,
    required this.clientSubtotal,
    required this.sumOfLineTotals,
    required this.amount,
  });

  final String orderId;
  final String? storeId;

  /// 깨진 불변식 이름 (lineMath / subtotalSum / totalEqSubtotal / amountEqTotal).
  final List<String> failed;
  final bool malformed;
  final int? clientSubtotal;
  final int? sumOfLineTotals;
  final int? amount;
}

class PriceAuditOverrideItem {
  const PriceAuditOverrideItem({
    required this.storeId,
    required this.masterMenuItemId,
    required this.priceOverride,
    required this.excluded,
    required this.status,
    required this.approvedBy,
  });

  final String storeId;
  final String masterMenuItemId;
  final int? priceOverride;
  final bool excluded;
  final String? status;
  final String? approvedBy;
}

class PriceAuditRefItem {
  const PriceAuditRefItem({
    required this.brandId,
    required this.menuItemId,
    required this.groupId,
    required this.franchiseStores,
  });

  final String brandId;
  final String menuItemId;
  final String groupId;
  final int franchiseStores;
}

/// `auditOrderPriceIntegrity` 응답 (읽기 전용 감사). 분류가 응답에 없으면 null — 0건과 구분된다.
class PriceAuditReport {
  const PriceAuditReport({
    required this.windowFrom,
    required this.windowTo,
    required this.ordersScanned,
    required this.ordersViolationCount,
    required this.byCheck,
    required this.orderViolations,
    required this.ordersTruncated,
    required this.overridesScanned,
    required this.selfApprovedCount,
    required this.opsOnlyApproved,
    required this.selfApproved,
    required this.refCount,
    required this.refStorePairs,
    required this.refItems,
    required this.receivedAt,
  });

  final String? windowFrom;
  final String? windowTo;
  final int? ordersScanned;
  final int? ordersViolationCount;
  final Map<String, int>? byCheck;
  final List<PriceAuditOrderViolation>? orderViolations;
  final bool? ordersTruncated;
  final int? overridesScanned;
  final int? selfApprovedCount;
  final int? opsOnlyApproved;
  final List<PriceAuditOverrideItem>? selfApproved;
  final int? refCount;
  final int? refStorePairs;
  final List<PriceAuditRefItem>? refItems;
  final DateTime receivedAt;

  /// 배포 중단 기준 (런북 §18-2): ⓐ 위반이 1건이라도 있거나 ⓑ self-approved 가 0 이 아니면 멈춘다.
  /// 분류가 응답에 없으면 멈춰야 하는 쪽으로 본다.
  bool get blocksEnforce =>
      ordersViolationCount == null ||
      selfApprovedCount == null ||
      ordersViolationCount! > 0 ||
      selfApprovedCount! > 0;
}

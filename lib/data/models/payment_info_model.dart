import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/domain/entities/payment_channel.dart';
import 'package:qradar/domain/entities/payment_info_entity.dart';
import 'package:qradar/domain/entities/payment_method.dart';

/// Firestore `orders/{orderId}.paymentInfo` 필드 매퍼.
class PaymentInfoModel {
  final PaymentMethod method;
  final PaymentChannel channel;
  final String paymentKey;
  final String? transactionId;
  final String? receiptUrl;
  final DateTime approvedAt;
  final int amount;
  final String? cardCompany;
  final String? cardNumberMasked;
  final String? easyPayProvider;

  const PaymentInfoModel({
    required this.method,
    required this.channel,
    required this.paymentKey,
    this.transactionId,
    this.receiptUrl,
    required this.approvedAt,
    required this.amount,
    this.cardCompany,
    this.cardNumberMasked,
    this.easyPayProvider,
  });

  factory PaymentInfoModel.fromMap(Map<String, dynamic> map) {
    final ts = map['approvedAt'];
    return PaymentInfoModel(
      method: PaymentMethod.fromCode(map['method'] as String?),
      channel: PaymentChannel.fromCode(map['channel'] as String?),
      paymentKey: (map['paymentKey'] as String?) ?? '',
      transactionId: map['transactionId'] as String?,
      receiptUrl: map['receiptUrl'] as String?,
      approvedAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      cardCompany: map['cardCompany'] as String?,
      cardNumberMasked: map['cardNumberMasked'] as String?,
      easyPayProvider: map['easyPayProvider'] as String?,
    );
  }

  factory PaymentInfoModel.fromEntity(PaymentInfoEntity entity) {
    return PaymentInfoModel(
      method: entity.method,
      channel: entity.channel,
      paymentKey: entity.paymentKey,
      transactionId: entity.transactionId,
      receiptUrl: entity.receiptUrl,
      approvedAt: entity.approvedAt,
      amount: entity.amount,
      cardCompany: entity.cardCompany,
      cardNumberMasked: entity.cardNumberMasked,
      easyPayProvider: entity.easyPayProvider,
    );
  }

  PaymentInfoEntity toEntity() {
    return PaymentInfoEntity(
      method: method,
      channel: channel,
      paymentKey: paymentKey,
      transactionId: transactionId,
      receiptUrl: receiptUrl,
      approvedAt: approvedAt,
      amount: amount,
      cardCompany: cardCompany,
      cardNumberMasked: cardNumberMasked,
      easyPayProvider: easyPayProvider,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'method': method.name,
        'channel': channel.name,
        'paymentKey': paymentKey,
        if (transactionId != null) 'transactionId': transactionId,
        if (receiptUrl != null) 'receiptUrl': receiptUrl,
        'approvedAt': Timestamp.fromDate(approvedAt),
        'amount': amount,
        if (cardCompany != null) 'cardCompany': cardCompany,
        if (cardNumberMasked != null) 'cardNumberMasked': cardNumberMasked,
        if (easyPayProvider != null) 'easyPayProvider': easyPayProvider,
      };
}

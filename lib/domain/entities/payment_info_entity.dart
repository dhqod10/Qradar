import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/domain/entities/payment_channel.dart';
import 'package:qradar/domain/entities/payment_method.dart';

part 'payment_info_entity.freezed.dart';

/// 결제 정보 (Toss 응답 기반).
@freezed
abstract class PaymentInfoEntity with _$PaymentInfoEntity {
  const factory PaymentInfoEntity({
    required PaymentMethod method,
    required PaymentChannel channel,
    required String paymentKey,
    String? transactionId,
    String? receiptUrl,
    required DateTime approvedAt,
    required int amount,
    String? cardCompany,
    String? cardNumberMasked,
    String? easyPayProvider,
  }) = _PaymentInfoEntity;
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/domain/entities/qoin_config_entity.dart';

/// `config/qoin` 매퍼.
class QoinConfigModel {
  const QoinConfigModel._();

  static QoinConfigEntity fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      fromMap(doc.data() ?? const <String, dynamic>{});

  /// `enabled` 가 bool 이 아니면 false (fail-closed).
  /// `accrualRate` 가 number 아님/NaN/음수/1 초과면 null — CF 의 검증과 같은 기준.
  static QoinConfigEntity fromMap(Map<String, dynamic> data) {
    final enabled = data['enabled'];
    final rate = data['accrualRate'];
    final validRate =
        rate is num && !rate.isNaN && !rate.isInfinite && rate >= 0 && rate <= 1;
    return QoinConfigEntity(
      accrualRate: validRate ? rate.toDouble() : null,
      enabled: enabled is bool ? enabled : false,
    );
  }
}

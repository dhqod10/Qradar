import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/core/constants/firestore_paths.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/qoin_config_entity.dart';

/// `config/qoin` 매퍼.
class QoinConfigModel {
  const QoinConfigModel._();

  static QoinConfigEntity fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => fromMap(doc.data() ?? const <String, dynamic>{});

  /// `enabled` 가 bool 이 아니면 false (fail-closed).
  /// `accrualRate` 는 [QoinRateSetting.fromRaw] 로 분류한다 — 경계는 `QoinPolicy` 1곳이 소유하며
  /// CF 와 같은 기준이다 (전역은 0 도 무효). 유효하지 않으면 [QoinConfigEntity.accrualRate] 는 null.
  static QoinConfigEntity fromMap(Map<String, dynamic> data) {
    final enabled = data['enabled'];
    final parsed = QoinRateSetting.fromRaw(
      data[FirestorePaths.qoinGlobalAccrualRateField],
      present: data.containsKey(FirestorePaths.qoinGlobalAccrualRateField),
    );
    // 전역은 0 도 무효다 (R16) — fromRaw 가 0 을 무효로 분류한다.
    final setting = parsed;
    return QoinConfigEntity(
      accrualRate: setting.isValid ? setting.value : null,
      accrualRateSetting: setting,
      enabled: enabled is bool ? enabled : false,
    );
  }
}

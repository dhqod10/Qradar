import 'package:qradar/domain/entities/business_hours.dart';

/// Firestore `stores/{id}.businessHours` 맵 매퍼.
class BusinessHoursModel {
  final String openTime;
  final String closeTime;
  final List<int> closedDays;

  const BusinessHoursModel({
    required this.openTime,
    required this.closeTime,
    this.closedDays = const [],
  });

  factory BusinessHoursModel.fromMap(Map<String, dynamic> data) {
    return BusinessHoursModel(
      openTime: (data['openTime'] as String?) ?? '',
      closeTime: (data['closeTime'] as String?) ?? '',
      closedDays: ((data['closedDays'] as List<dynamic>?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList(growable: false),
    );
  }

  factory BusinessHoursModel.fromEntity(BusinessHours entity) {
    return BusinessHoursModel(
      openTime: entity.openTime,
      closeTime: entity.closeTime,
      closedDays: entity.closedDays,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'openTime': openTime,
        'closeTime': closeTime,
        'closedDays': closedDays,
      };

  BusinessHours toEntity() => BusinessHours(
        openTime: openTime,
        closeTime: closeTime,
        closedDays: closedDays,
      );
}

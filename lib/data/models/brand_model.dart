import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/core/constants/firestore_paths.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';

/// Firestore `brands/{brandId}` 문서 매퍼.
class BrandModel {
  final String id;
  final String name;
  final String logoUrl;
  final String? description;
  final String companyName;
  final String businessRegistrationNumber;
  final String contactName;
  final String contactPhone;
  final String? headOfficeAddress;
  final String? representativeName;
  final String brandKey;
  final String status;
  final String? submittedBy;
  final DateTime? submittedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectedReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Qoin 적립률 브랜드 설정 — **읽기 전용 필드.** `toFirestore()` 에 넣지 않는다 (쓰기는 CF 전담).
  final QoinRateSetting qoinAccrualRate;

  /// Qoin 적립 스위치 — **읽기 전용 필드.** `toFirestore()` 에 넣지 않는다.
  final QoinSwitchSetting qoinAccrualEnabled;

  /// 일괄 적용 포인터 3필드 — **읽기 전용.** CF 가 유지하고 허브의 중단 판정이 읽는다.
  final String? qoinBulkHistoryId;
  final QoinBulkStatus? qoinBulkStatus;
  final DateTime? qoinBulkAt;

  const BrandModel({
    required this.id,
    required this.name,
    this.logoUrl = '',
    this.description,
    this.companyName = '',
    this.businessRegistrationNumber = '',
    this.contactName = '',
    this.contactPhone = '',
    this.headOfficeAddress,
    this.representativeName,
    this.brandKey = '',
    this.status = 'pending',
    this.submittedBy,
    this.submittedAt,
    this.approvedBy,
    this.approvedAt,
    this.rejectedReason,
    this.createdAt,
    this.updatedAt,
    this.qoinAccrualRate = QoinRateSetting.absent,
    this.qoinAccrualEnabled = QoinSwitchSetting.enabled,
    this.qoinBulkHistoryId,
    this.qoinBulkStatus,
    this.qoinBulkAt,
  });

  factory BrandModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return BrandModel(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      logoUrl: (data['logoUrl'] as String?) ?? '',
      description: data['description'] as String?,
      companyName: (data['companyName'] as String?) ?? '',
      businessRegistrationNumber:
          (data['businessRegistrationNumber'] as String?) ?? '',
      contactName: (data['contactName'] as String?) ?? '',
      contactPhone: (data['contactPhone'] as String?) ?? '',
      headOfficeAddress: data['headOfficeAddress'] as String?,
      representativeName: data['representativeName'] as String?,
      brandKey: (data['brandKey'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'pending',
      submittedBy: data['submittedBy'] as String?,
      submittedAt: _toDate(data['submittedAt']),
      approvedBy: data['approvedBy'] as String?,
      approvedAt: _toDate(data['approvedAt']),
      rejectedReason: data['rejectedReason'] as String?,
      createdAt: _toDate(data['createdAt']),
      updatedAt: _toDate(data['updatedAt']),
      qoinAccrualRate: QoinRateSetting.fromRaw(
        data[FirestorePaths.qoinAccrualRateField],
        present: data.containsKey(FirestorePaths.qoinAccrualRateField),
      ),
      qoinAccrualEnabled: QoinSwitchSetting.fromRaw(
        data[FirestorePaths.qoinAccrualEnabledField],
        present: data.containsKey(FirestorePaths.qoinAccrualEnabledField),
      ),
      qoinBulkHistoryId: data[FirestorePaths.qoinBulkHistoryIdField] as String?,
      qoinBulkStatus: QoinBulkStatus.fromCode(
        data[FirestorePaths.qoinBulkStatusField],
      ),
      qoinBulkAt: _toDate(data[FirestorePaths.qoinBulkAtField]),
    );
  }

  factory BrandModel.fromEntity(BrandEntity entity) {
    return BrandModel(
      id: entity.id,
      name: entity.name,
      logoUrl: entity.logoUrl,
      description: entity.description,
      companyName: entity.companyName,
      businessRegistrationNumber: entity.businessRegistrationNumber,
      contactName: entity.contactName,
      contactPhone: entity.contactPhone,
      headOfficeAddress: entity.headOfficeAddress,
      representativeName: entity.representativeName,
      brandKey: entity.brandKey,
      status: entity.status.asString,
      submittedBy: entity.submittedBy,
      submittedAt: entity.submittedAt,
      approvedBy: entity.approvedBy,
      approvedAt: entity.approvedAt,
      rejectedReason: entity.rejectedReason,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      qoinAccrualRate: entity.qoinAccrualRate,
      qoinAccrualEnabled: entity.qoinAccrualEnabled,
      qoinBulkHistoryId: entity.qoinBulkHistoryId,
      qoinBulkStatus: entity.qoinBulkStatus,
      qoinBulkAt: entity.qoinBulkAt,
    );
  }

  BrandEntity toEntity() {
    return BrandEntity(
      id: id,
      name: name,
      logoUrl: logoUrl,
      description: description,
      companyName: companyName,
      businessRegistrationNumber: businessRegistrationNumber,
      contactName: contactName,
      contactPhone: contactPhone,
      headOfficeAddress: headOfficeAddress,
      representativeName: representativeName,
      brandKey: brandKey,
      status: EntityApprovalStatus.fromString(status),
      submittedBy: submittedBy,
      submittedAt: submittedAt,
      approvedBy: approvedBy,
      approvedAt: approvedAt,
      rejectedReason: rejectedReason,
      createdAt: createdAt,
      updatedAt: updatedAt,
      qoinAccrualRate: qoinAccrualRate,
      qoinAccrualEnabled: qoinAccrualEnabled,
      qoinBulkHistoryId: qoinBulkHistoryId,
      qoinBulkStatus: qoinBulkStatus,
      qoinBulkAt: qoinBulkAt,
    );
  }

  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'name': name,
        'logoUrl': logoUrl,
        if (description != null) 'description': description,
        'companyName': companyName,
        'businessRegistrationNumber': businessRegistrationNumber,
        'contactName': contactName,
        'contactPhone': contactPhone,
        if (headOfficeAddress != null) 'headOfficeAddress': headOfficeAddress,
        if (representativeName != null) 'representativeName': representativeName,
        'brandKey': brandKey,
        'status': status,
        if (submittedBy != null) 'submittedBy': submittedBy,
        if (submittedAt != null)
          'submittedAt': Timestamp.fromDate(submittedAt!)
        else
          'submittedAt': FieldValue.serverTimestamp(),
        if (approvedBy != null) 'approvedBy': approvedBy,
        if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
        if (rejectedReason != null) 'rejectedReason': rejectedReason,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}

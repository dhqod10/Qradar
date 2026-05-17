import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';

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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/domain/entities/brand_private_profile_entity.dart';

/// Firestore `brands/{brandId}/private/profile` 문서 매퍼.
///
/// **[toFirestore] 는 brandKey 를 절대 쓰지 않는다** — brandKey 는 `issueBrandKey` CF 전담이고,
/// 클라이언트가 쓰면 Rules 가 batch/문서 전체를 거부한다. 읽기([fromFirestore])는 brandKey 를 포함한다.
class BrandPrivateProfileModel {
  const BrandPrivateProfileModel({
    this.brandKey = '',
    this.businessRegistrationNumber = '',
    this.contactName = '',
    this.contactPhone = '',
    this.headOfficeAddress,
    this.representativeName,
  });

  final String brandKey;
  final String businessRegistrationNumber;
  final String contactName;
  final String contactPhone;
  final String? headOfficeAddress;
  final String? representativeName;

  factory BrandPrivateProfileModel.fromMap(Map<String, dynamic> data) {
    return BrandPrivateProfileModel(
      brandKey: (data['brandKey'] as String?) ?? '',
      businessRegistrationNumber:
          (data['businessRegistrationNumber'] as String?) ?? '',
      contactName: (data['contactName'] as String?) ?? '',
      contactPhone: (data['contactPhone'] as String?) ?? '',
      headOfficeAddress: data['headOfficeAddress'] as String?,
      representativeName: data['representativeName'] as String?,
    );
  }

  /// 문서가 없으면 null (= 키도 PII 도 아직 없다). 읽기 **실패**는 호출자에게 예외로 전달된다.
  static BrandPrivateProfileModel? fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return BrandPrivateProfileModel.fromMap(data);
  }

  factory BrandPrivateProfileModel.fromEntity(BrandPrivateProfileEntity e) {
    return BrandPrivateProfileModel(
      brandKey: e.brandKey,
      businessRegistrationNumber: e.businessRegistrationNumber,
      contactName: e.contactName,
      contactPhone: e.contactPhone,
      headOfficeAddress: e.headOfficeAddress,
      representativeName: e.representativeName,
    );
  }

  BrandPrivateProfileEntity toEntity() => BrandPrivateProfileEntity(
    brandKey: brandKey,
    businessRegistrationNumber: businessRegistrationNumber,
    contactName: contactName,
    contactPhone: contactPhone,
    headOfficeAddress: headOfficeAddress,
    representativeName: representativeName,
  );

  /// merge-set 용 쓰기 맵 — **PII 5개만.** 선택 필드가 null 이면 `FieldValue.delete()` 로 비운다
  /// (생략하면 사용자가 지운 값이 계속 남는다). `brandKey` 키는 어떤 경우에도 포함하지 않는다.
  Map<String, dynamic> toFirestore() => <String, dynamic>{
    'businessRegistrationNumber': businessRegistrationNumber,
    'contactName': contactName,
    'contactPhone': contactPhone,
    'headOfficeAddress': headOfficeAddress ?? FieldValue.delete(),
    'representativeName': representativeName ?? FieldValue.delete(),
  };
}

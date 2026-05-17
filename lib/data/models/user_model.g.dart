// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserModel _$UserModelFromJson(Map<String, dynamic> json) => _UserModel(
  uid: json['uid'] as String,
  email: json['email'] as String?,
  displayName: json['display_name'] as String?,
  photoUrl: json['photo_url'] as String?,
  provider: json['provider'] as String,
  role: json['role'] as String? ?? 'customer',
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  brandId: json['brandId'] as String?,
);

Map<String, dynamic> _$UserModelToJson(_UserModel instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'email': instance.email,
      'display_name': instance.displayName,
      'photo_url': instance.photoUrl,
      'provider': instance.provider,
      'role': instance.role,
      'createdAt': instance.createdAt?.toIso8601String(),
      'brandId': instance.brandId,
    };

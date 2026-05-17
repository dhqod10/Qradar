// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'brand_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BrandEntity {

 String get id; String get name; String get logoUrl; String? get description;// 사업자 정보 (Step 3 신규)
 String get companyName;// 회사명 (필수)
 String get businessRegistrationNumber;// 사업자등록번호 000-00-00000 (필수)
 String get contactName;// 담당자 이름 (필수)
 String get contactPhone;// 담당자 연락처 (필수)
 String? get headOfficeAddress;// 본사 주소 (선택)
 String? get representativeName;// 대표자 이름 (선택)
/// 브랜드 키 (V1). admin 승인 시점에 자동 발급. pending/rejected 상태에서는 빈 문자열.
 String get brandKey; EntityApprovalStatus get status; String? get submittedBy; DateTime? get submittedAt; String? get approvedBy; DateTime? get approvedAt; String? get rejectedReason; DateTime? get createdAt; DateTime? get updatedAt;
/// Create a copy of BrandEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BrandEntityCopyWith<BrandEntity> get copyWith => _$BrandEntityCopyWithImpl<BrandEntity>(this as BrandEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BrandEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl)&&(identical(other.description, description) || other.description == description)&&(identical(other.companyName, companyName) || other.companyName == companyName)&&(identical(other.businessRegistrationNumber, businessRegistrationNumber) || other.businessRegistrationNumber == businessRegistrationNumber)&&(identical(other.contactName, contactName) || other.contactName == contactName)&&(identical(other.contactPhone, contactPhone) || other.contactPhone == contactPhone)&&(identical(other.headOfficeAddress, headOfficeAddress) || other.headOfficeAddress == headOfficeAddress)&&(identical(other.representativeName, representativeName) || other.representativeName == representativeName)&&(identical(other.brandKey, brandKey) || other.brandKey == brandKey)&&(identical(other.status, status) || other.status == status)&&(identical(other.submittedBy, submittedBy) || other.submittedBy == submittedBy)&&(identical(other.submittedAt, submittedAt) || other.submittedAt == submittedAt)&&(identical(other.approvedBy, approvedBy) || other.approvedBy == approvedBy)&&(identical(other.approvedAt, approvedAt) || other.approvedAt == approvedAt)&&(identical(other.rejectedReason, rejectedReason) || other.rejectedReason == rejectedReason)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,name,logoUrl,description,companyName,businessRegistrationNumber,contactName,contactPhone,headOfficeAddress,representativeName,brandKey,status,submittedBy,submittedAt,approvedBy,approvedAt,rejectedReason,createdAt,updatedAt]);

@override
String toString() {
  return 'BrandEntity(id: $id, name: $name, logoUrl: $logoUrl, description: $description, companyName: $companyName, businessRegistrationNumber: $businessRegistrationNumber, contactName: $contactName, contactPhone: $contactPhone, headOfficeAddress: $headOfficeAddress, representativeName: $representativeName, brandKey: $brandKey, status: $status, submittedBy: $submittedBy, submittedAt: $submittedAt, approvedBy: $approvedBy, approvedAt: $approvedAt, rejectedReason: $rejectedReason, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $BrandEntityCopyWith<$Res>  {
  factory $BrandEntityCopyWith(BrandEntity value, $Res Function(BrandEntity) _then) = _$BrandEntityCopyWithImpl;
@useResult
$Res call({
 String id, String name, String logoUrl, String? description, String companyName, String businessRegistrationNumber, String contactName, String contactPhone, String? headOfficeAddress, String? representativeName, String brandKey, EntityApprovalStatus status, String? submittedBy, DateTime? submittedAt, String? approvedBy, DateTime? approvedAt, String? rejectedReason, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class _$BrandEntityCopyWithImpl<$Res>
    implements $BrandEntityCopyWith<$Res> {
  _$BrandEntityCopyWithImpl(this._self, this._then);

  final BrandEntity _self;
  final $Res Function(BrandEntity) _then;

/// Create a copy of BrandEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? logoUrl = null,Object? description = freezed,Object? companyName = null,Object? businessRegistrationNumber = null,Object? contactName = null,Object? contactPhone = null,Object? headOfficeAddress = freezed,Object? representativeName = freezed,Object? brandKey = null,Object? status = null,Object? submittedBy = freezed,Object? submittedAt = freezed,Object? approvedBy = freezed,Object? approvedAt = freezed,Object? rejectedReason = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,logoUrl: null == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,companyName: null == companyName ? _self.companyName : companyName // ignore: cast_nullable_to_non_nullable
as String,businessRegistrationNumber: null == businessRegistrationNumber ? _self.businessRegistrationNumber : businessRegistrationNumber // ignore: cast_nullable_to_non_nullable
as String,contactName: null == contactName ? _self.contactName : contactName // ignore: cast_nullable_to_non_nullable
as String,contactPhone: null == contactPhone ? _self.contactPhone : contactPhone // ignore: cast_nullable_to_non_nullable
as String,headOfficeAddress: freezed == headOfficeAddress ? _self.headOfficeAddress : headOfficeAddress // ignore: cast_nullable_to_non_nullable
as String?,representativeName: freezed == representativeName ? _self.representativeName : representativeName // ignore: cast_nullable_to_non_nullable
as String?,brandKey: null == brandKey ? _self.brandKey : brandKey // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as EntityApprovalStatus,submittedBy: freezed == submittedBy ? _self.submittedBy : submittedBy // ignore: cast_nullable_to_non_nullable
as String?,submittedAt: freezed == submittedAt ? _self.submittedAt : submittedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,approvedBy: freezed == approvedBy ? _self.approvedBy : approvedBy // ignore: cast_nullable_to_non_nullable
as String?,approvedAt: freezed == approvedAt ? _self.approvedAt : approvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,rejectedReason: freezed == rejectedReason ? _self.rejectedReason : rejectedReason // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [BrandEntity].
extension BrandEntityPatterns on BrandEntity {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BrandEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BrandEntity() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BrandEntity value)  $default,){
final _that = this;
switch (_that) {
case _BrandEntity():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BrandEntity value)?  $default,){
final _that = this;
switch (_that) {
case _BrandEntity() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String logoUrl,  String? description,  String companyName,  String businessRegistrationNumber,  String contactName,  String contactPhone,  String? headOfficeAddress,  String? representativeName,  String brandKey,  EntityApprovalStatus status,  String? submittedBy,  DateTime? submittedAt,  String? approvedBy,  DateTime? approvedAt,  String? rejectedReason,  DateTime? createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BrandEntity() when $default != null:
return $default(_that.id,_that.name,_that.logoUrl,_that.description,_that.companyName,_that.businessRegistrationNumber,_that.contactName,_that.contactPhone,_that.headOfficeAddress,_that.representativeName,_that.brandKey,_that.status,_that.submittedBy,_that.submittedAt,_that.approvedBy,_that.approvedAt,_that.rejectedReason,_that.createdAt,_that.updatedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String logoUrl,  String? description,  String companyName,  String businessRegistrationNumber,  String contactName,  String contactPhone,  String? headOfficeAddress,  String? representativeName,  String brandKey,  EntityApprovalStatus status,  String? submittedBy,  DateTime? submittedAt,  String? approvedBy,  DateTime? approvedAt,  String? rejectedReason,  DateTime? createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _BrandEntity():
return $default(_that.id,_that.name,_that.logoUrl,_that.description,_that.companyName,_that.businessRegistrationNumber,_that.contactName,_that.contactPhone,_that.headOfficeAddress,_that.representativeName,_that.brandKey,_that.status,_that.submittedBy,_that.submittedAt,_that.approvedBy,_that.approvedAt,_that.rejectedReason,_that.createdAt,_that.updatedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String logoUrl,  String? description,  String companyName,  String businessRegistrationNumber,  String contactName,  String contactPhone,  String? headOfficeAddress,  String? representativeName,  String brandKey,  EntityApprovalStatus status,  String? submittedBy,  DateTime? submittedAt,  String? approvedBy,  DateTime? approvedAt,  String? rejectedReason,  DateTime? createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _BrandEntity() when $default != null:
return $default(_that.id,_that.name,_that.logoUrl,_that.description,_that.companyName,_that.businessRegistrationNumber,_that.contactName,_that.contactPhone,_that.headOfficeAddress,_that.representativeName,_that.brandKey,_that.status,_that.submittedBy,_that.submittedAt,_that.approvedBy,_that.approvedAt,_that.rejectedReason,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _BrandEntity implements BrandEntity {
  const _BrandEntity({required this.id, required this.name, this.logoUrl = '', this.description, this.companyName = '', this.businessRegistrationNumber = '', this.contactName = '', this.contactPhone = '', this.headOfficeAddress, this.representativeName, this.brandKey = '', this.status = EntityApprovalStatus.pending, this.submittedBy, this.submittedAt, this.approvedBy, this.approvedAt, this.rejectedReason, this.createdAt, this.updatedAt});
  

@override final  String id;
@override final  String name;
@override@JsonKey() final  String logoUrl;
@override final  String? description;
// 사업자 정보 (Step 3 신규)
@override@JsonKey() final  String companyName;
// 회사명 (필수)
@override@JsonKey() final  String businessRegistrationNumber;
// 사업자등록번호 000-00-00000 (필수)
@override@JsonKey() final  String contactName;
// 담당자 이름 (필수)
@override@JsonKey() final  String contactPhone;
// 담당자 연락처 (필수)
@override final  String? headOfficeAddress;
// 본사 주소 (선택)
@override final  String? representativeName;
// 대표자 이름 (선택)
/// 브랜드 키 (V1). admin 승인 시점에 자동 발급. pending/rejected 상태에서는 빈 문자열.
@override@JsonKey() final  String brandKey;
@override@JsonKey() final  EntityApprovalStatus status;
@override final  String? submittedBy;
@override final  DateTime? submittedAt;
@override final  String? approvedBy;
@override final  DateTime? approvedAt;
@override final  String? rejectedReason;
@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of BrandEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BrandEntityCopyWith<_BrandEntity> get copyWith => __$BrandEntityCopyWithImpl<_BrandEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BrandEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl)&&(identical(other.description, description) || other.description == description)&&(identical(other.companyName, companyName) || other.companyName == companyName)&&(identical(other.businessRegistrationNumber, businessRegistrationNumber) || other.businessRegistrationNumber == businessRegistrationNumber)&&(identical(other.contactName, contactName) || other.contactName == contactName)&&(identical(other.contactPhone, contactPhone) || other.contactPhone == contactPhone)&&(identical(other.headOfficeAddress, headOfficeAddress) || other.headOfficeAddress == headOfficeAddress)&&(identical(other.representativeName, representativeName) || other.representativeName == representativeName)&&(identical(other.brandKey, brandKey) || other.brandKey == brandKey)&&(identical(other.status, status) || other.status == status)&&(identical(other.submittedBy, submittedBy) || other.submittedBy == submittedBy)&&(identical(other.submittedAt, submittedAt) || other.submittedAt == submittedAt)&&(identical(other.approvedBy, approvedBy) || other.approvedBy == approvedBy)&&(identical(other.approvedAt, approvedAt) || other.approvedAt == approvedAt)&&(identical(other.rejectedReason, rejectedReason) || other.rejectedReason == rejectedReason)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,name,logoUrl,description,companyName,businessRegistrationNumber,contactName,contactPhone,headOfficeAddress,representativeName,brandKey,status,submittedBy,submittedAt,approvedBy,approvedAt,rejectedReason,createdAt,updatedAt]);

@override
String toString() {
  return 'BrandEntity(id: $id, name: $name, logoUrl: $logoUrl, description: $description, companyName: $companyName, businessRegistrationNumber: $businessRegistrationNumber, contactName: $contactName, contactPhone: $contactPhone, headOfficeAddress: $headOfficeAddress, representativeName: $representativeName, brandKey: $brandKey, status: $status, submittedBy: $submittedBy, submittedAt: $submittedAt, approvedBy: $approvedBy, approvedAt: $approvedAt, rejectedReason: $rejectedReason, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$BrandEntityCopyWith<$Res> implements $BrandEntityCopyWith<$Res> {
  factory _$BrandEntityCopyWith(_BrandEntity value, $Res Function(_BrandEntity) _then) = __$BrandEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String logoUrl, String? description, String companyName, String businessRegistrationNumber, String contactName, String contactPhone, String? headOfficeAddress, String? representativeName, String brandKey, EntityApprovalStatus status, String? submittedBy, DateTime? submittedAt, String? approvedBy, DateTime? approvedAt, String? rejectedReason, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class __$BrandEntityCopyWithImpl<$Res>
    implements _$BrandEntityCopyWith<$Res> {
  __$BrandEntityCopyWithImpl(this._self, this._then);

  final _BrandEntity _self;
  final $Res Function(_BrandEntity) _then;

/// Create a copy of BrandEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? logoUrl = null,Object? description = freezed,Object? companyName = null,Object? businessRegistrationNumber = null,Object? contactName = null,Object? contactPhone = null,Object? headOfficeAddress = freezed,Object? representativeName = freezed,Object? brandKey = null,Object? status = null,Object? submittedBy = freezed,Object? submittedAt = freezed,Object? approvedBy = freezed,Object? approvedAt = freezed,Object? rejectedReason = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_BrandEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,logoUrl: null == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,companyName: null == companyName ? _self.companyName : companyName // ignore: cast_nullable_to_non_nullable
as String,businessRegistrationNumber: null == businessRegistrationNumber ? _self.businessRegistrationNumber : businessRegistrationNumber // ignore: cast_nullable_to_non_nullable
as String,contactName: null == contactName ? _self.contactName : contactName // ignore: cast_nullable_to_non_nullable
as String,contactPhone: null == contactPhone ? _self.contactPhone : contactPhone // ignore: cast_nullable_to_non_nullable
as String,headOfficeAddress: freezed == headOfficeAddress ? _self.headOfficeAddress : headOfficeAddress // ignore: cast_nullable_to_non_nullable
as String?,representativeName: freezed == representativeName ? _self.representativeName : representativeName // ignore: cast_nullable_to_non_nullable
as String?,brandKey: null == brandKey ? _self.brandKey : brandKey // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as EntityApprovalStatus,submittedBy: freezed == submittedBy ? _self.submittedBy : submittedBy // ignore: cast_nullable_to_non_nullable
as String?,submittedAt: freezed == submittedAt ? _self.submittedAt : submittedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,approvedBy: freezed == approvedBy ? _self.approvedBy : approvedBy // ignore: cast_nullable_to_non_nullable
as String?,approvedAt: freezed == approvedAt ? _self.approvedAt : approvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,rejectedReason: freezed == rejectedReason ? _self.rejectedReason : rejectedReason // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'store_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StoreEntity {

 String get id; String get name; String get imageUrl; UserLocation get location; StoreGrade get grade; double get averageScore; int get reviewCount; List<String> get menuCategories; DateTime get createdAt; String get ownerId; String get phone; String get address; String? get description; BusinessHours? get businessHours; double? get distanceKm;// ── sub-phase 2 신규 필드 ────────────────────────────────────────────
/// 브랜드 매장이면 brandId, 개인 매장(점주 직접 등록)이면 null.
 String? get brandId;/// 승인 상태. missing status → approved fallback (T1, legacy 안전).
 EntityApprovalStatus get status;/// 이번 신청을 제출한 사용자 uid.
 String? get submittedBy;/// 점주 제출 시점.
 DateTime? get submittedAt;/// admin 이 마지막으로 처리한 uid (approve/reject 양쪽).
 String? get approvedBy;/// admin **승인** 시점. 승인 행위에서만 쓴다 (반려는 [rejectedAt]).
 DateTime? get approvedAt;/// admin **반려** 시점. 점주 재제출 시 null 로 클리어된다.
 DateTime? get rejectedAt;/// admin 반려 사유. status=rejected 일 때만 의미 있음.
 String? get rejectedReason;/// 사업자등록번호 (핵심 필드).
 String? get businessRegistrationNumber;/// 임시 휴무 토글 (운영 필드).
 bool get temporaryClosed;/// 특정 날짜 휴무 리스트 (운영 필드).
 List<DateTime> get closedDates;/// 대표 이미지 URL 목록. 기존 단일 imageUrl 과 병행 (호환성).
 List<String> get imageUrls;/// 매장 안내 문구 (운영 필드).
 String? get notice;/// 점주가 끈 메인 카테고리 코드 목록 (운영 필드, opt-out). 빈 목록 = 전부 노출.
/// sticky: 한 번 끄면 이후 해당 카테고리 메뉴가 생겨도 계속 숨긴다.
 List<String> get excludedMainCategories;/// 검색/홈 필터용 파생 메인 카테고리 코드 (Cloud Function 전담, 읽기 전용).
/// 노출 메뉴의 mainCategory ∩ active − excluded. 부재 = 빈 목록.
 List<String> get availableMainCategories;/// 최종 수정 시점.
 DateTime? get updatedAt;/// Qoin 적립률 개별 설정 (`qoinAccrualRate`). 부재 = 상위 상속. 0 은 적립률이 아니다.
/// **읽기 전용** — 쓰기는 CF(setQoinAccrualRate / applyBrandQoinRate) 전담.
 QoinRateSetting get qoinAccrualRate;/// 적립 스위치 (`qoinAccrualEnabled`). 부재/true = 사용, false = 사용 안 함. **읽기 전용.**
 QoinSwitchSetting get qoinAccrualEnabled;
/// Create a copy of StoreEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StoreEntityCopyWith<StoreEntity> get copyWith => _$StoreEntityCopyWithImpl<StoreEntity>(this as StoreEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StoreEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.location, location) || other.location == location)&&(identical(other.grade, grade) || other.grade == grade)&&(identical(other.averageScore, averageScore) || other.averageScore == averageScore)&&(identical(other.reviewCount, reviewCount) || other.reviewCount == reviewCount)&&const DeepCollectionEquality().equals(other.menuCategories, menuCategories)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.ownerId, ownerId) || other.ownerId == ownerId)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.address, address) || other.address == address)&&(identical(other.description, description) || other.description == description)&&(identical(other.businessHours, businessHours) || other.businessHours == businessHours)&&(identical(other.distanceKm, distanceKm) || other.distanceKm == distanceKm)&&(identical(other.brandId, brandId) || other.brandId == brandId)&&(identical(other.status, status) || other.status == status)&&(identical(other.submittedBy, submittedBy) || other.submittedBy == submittedBy)&&(identical(other.submittedAt, submittedAt) || other.submittedAt == submittedAt)&&(identical(other.approvedBy, approvedBy) || other.approvedBy == approvedBy)&&(identical(other.approvedAt, approvedAt) || other.approvedAt == approvedAt)&&(identical(other.rejectedAt, rejectedAt) || other.rejectedAt == rejectedAt)&&(identical(other.rejectedReason, rejectedReason) || other.rejectedReason == rejectedReason)&&(identical(other.businessRegistrationNumber, businessRegistrationNumber) || other.businessRegistrationNumber == businessRegistrationNumber)&&(identical(other.temporaryClosed, temporaryClosed) || other.temporaryClosed == temporaryClosed)&&const DeepCollectionEquality().equals(other.closedDates, closedDates)&&const DeepCollectionEquality().equals(other.imageUrls, imageUrls)&&(identical(other.notice, notice) || other.notice == notice)&&const DeepCollectionEquality().equals(other.excludedMainCategories, excludedMainCategories)&&const DeepCollectionEquality().equals(other.availableMainCategories, availableMainCategories)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.qoinAccrualRate, qoinAccrualRate) || other.qoinAccrualRate == qoinAccrualRate)&&(identical(other.qoinAccrualEnabled, qoinAccrualEnabled) || other.qoinAccrualEnabled == qoinAccrualEnabled));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,name,imageUrl,location,grade,averageScore,reviewCount,const DeepCollectionEquality().hash(menuCategories),createdAt,ownerId,phone,address,description,businessHours,distanceKm,brandId,status,submittedBy,submittedAt,approvedBy,approvedAt,rejectedAt,rejectedReason,businessRegistrationNumber,temporaryClosed,const DeepCollectionEquality().hash(closedDates),const DeepCollectionEquality().hash(imageUrls),notice,const DeepCollectionEquality().hash(excludedMainCategories),const DeepCollectionEquality().hash(availableMainCategories),updatedAt,qoinAccrualRate,qoinAccrualEnabled]);

@override
String toString() {
  return 'StoreEntity(id: $id, name: $name, imageUrl: $imageUrl, location: $location, grade: $grade, averageScore: $averageScore, reviewCount: $reviewCount, menuCategories: $menuCategories, createdAt: $createdAt, ownerId: $ownerId, phone: $phone, address: $address, description: $description, businessHours: $businessHours, distanceKm: $distanceKm, brandId: $brandId, status: $status, submittedBy: $submittedBy, submittedAt: $submittedAt, approvedBy: $approvedBy, approvedAt: $approvedAt, rejectedAt: $rejectedAt, rejectedReason: $rejectedReason, businessRegistrationNumber: $businessRegistrationNumber, temporaryClosed: $temporaryClosed, closedDates: $closedDates, imageUrls: $imageUrls, notice: $notice, excludedMainCategories: $excludedMainCategories, availableMainCategories: $availableMainCategories, updatedAt: $updatedAt, qoinAccrualRate: $qoinAccrualRate, qoinAccrualEnabled: $qoinAccrualEnabled)';
}


}

/// @nodoc
abstract mixin class $StoreEntityCopyWith<$Res>  {
  factory $StoreEntityCopyWith(StoreEntity value, $Res Function(StoreEntity) _then) = _$StoreEntityCopyWithImpl;
@useResult
$Res call({
 String id, String name, String imageUrl, UserLocation location, StoreGrade grade, double averageScore, int reviewCount, List<String> menuCategories, DateTime createdAt, String ownerId, String phone, String address, String? description, BusinessHours? businessHours, double? distanceKm, String? brandId, EntityApprovalStatus status, String? submittedBy, DateTime? submittedAt, String? approvedBy, DateTime? approvedAt, DateTime? rejectedAt, String? rejectedReason, String? businessRegistrationNumber, bool temporaryClosed, List<DateTime> closedDates, List<String> imageUrls, String? notice, List<String> excludedMainCategories, List<String> availableMainCategories, DateTime? updatedAt, QoinRateSetting qoinAccrualRate, QoinSwitchSetting qoinAccrualEnabled
});


$UserLocationCopyWith<$Res> get location;$BusinessHoursCopyWith<$Res>? get businessHours;

}
/// @nodoc
class _$StoreEntityCopyWithImpl<$Res>
    implements $StoreEntityCopyWith<$Res> {
  _$StoreEntityCopyWithImpl(this._self, this._then);

  final StoreEntity _self;
  final $Res Function(StoreEntity) _then;

/// Create a copy of StoreEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? imageUrl = null,Object? location = null,Object? grade = null,Object? averageScore = null,Object? reviewCount = null,Object? menuCategories = null,Object? createdAt = null,Object? ownerId = null,Object? phone = null,Object? address = null,Object? description = freezed,Object? businessHours = freezed,Object? distanceKm = freezed,Object? brandId = freezed,Object? status = null,Object? submittedBy = freezed,Object? submittedAt = freezed,Object? approvedBy = freezed,Object? approvedAt = freezed,Object? rejectedAt = freezed,Object? rejectedReason = freezed,Object? businessRegistrationNumber = freezed,Object? temporaryClosed = null,Object? closedDates = null,Object? imageUrls = null,Object? notice = freezed,Object? excludedMainCategories = null,Object? availableMainCategories = null,Object? updatedAt = freezed,Object? qoinAccrualRate = null,Object? qoinAccrualEnabled = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as UserLocation,grade: null == grade ? _self.grade : grade // ignore: cast_nullable_to_non_nullable
as StoreGrade,averageScore: null == averageScore ? _self.averageScore : averageScore // ignore: cast_nullable_to_non_nullable
as double,reviewCount: null == reviewCount ? _self.reviewCount : reviewCount // ignore: cast_nullable_to_non_nullable
as int,menuCategories: null == menuCategories ? _self.menuCategories : menuCategories // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,ownerId: null == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,address: null == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,businessHours: freezed == businessHours ? _self.businessHours : businessHours // ignore: cast_nullable_to_non_nullable
as BusinessHours?,distanceKm: freezed == distanceKm ? _self.distanceKm : distanceKm // ignore: cast_nullable_to_non_nullable
as double?,brandId: freezed == brandId ? _self.brandId : brandId // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as EntityApprovalStatus,submittedBy: freezed == submittedBy ? _self.submittedBy : submittedBy // ignore: cast_nullable_to_non_nullable
as String?,submittedAt: freezed == submittedAt ? _self.submittedAt : submittedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,approvedBy: freezed == approvedBy ? _self.approvedBy : approvedBy // ignore: cast_nullable_to_non_nullable
as String?,approvedAt: freezed == approvedAt ? _self.approvedAt : approvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,rejectedAt: freezed == rejectedAt ? _self.rejectedAt : rejectedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,rejectedReason: freezed == rejectedReason ? _self.rejectedReason : rejectedReason // ignore: cast_nullable_to_non_nullable
as String?,businessRegistrationNumber: freezed == businessRegistrationNumber ? _self.businessRegistrationNumber : businessRegistrationNumber // ignore: cast_nullable_to_non_nullable
as String?,temporaryClosed: null == temporaryClosed ? _self.temporaryClosed : temporaryClosed // ignore: cast_nullable_to_non_nullable
as bool,closedDates: null == closedDates ? _self.closedDates : closedDates // ignore: cast_nullable_to_non_nullable
as List<DateTime>,imageUrls: null == imageUrls ? _self.imageUrls : imageUrls // ignore: cast_nullable_to_non_nullable
as List<String>,notice: freezed == notice ? _self.notice : notice // ignore: cast_nullable_to_non_nullable
as String?,excludedMainCategories: null == excludedMainCategories ? _self.excludedMainCategories : excludedMainCategories // ignore: cast_nullable_to_non_nullable
as List<String>,availableMainCategories: null == availableMainCategories ? _self.availableMainCategories : availableMainCategories // ignore: cast_nullable_to_non_nullable
as List<String>,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,qoinAccrualRate: null == qoinAccrualRate ? _self.qoinAccrualRate : qoinAccrualRate // ignore: cast_nullable_to_non_nullable
as QoinRateSetting,qoinAccrualEnabled: null == qoinAccrualEnabled ? _self.qoinAccrualEnabled : qoinAccrualEnabled // ignore: cast_nullable_to_non_nullable
as QoinSwitchSetting,
  ));
}
/// Create a copy of StoreEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserLocationCopyWith<$Res> get location {
  
  return $UserLocationCopyWith<$Res>(_self.location, (value) {
    return _then(_self.copyWith(location: value));
  });
}/// Create a copy of StoreEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BusinessHoursCopyWith<$Res>? get businessHours {
    if (_self.businessHours == null) {
    return null;
  }

  return $BusinessHoursCopyWith<$Res>(_self.businessHours!, (value) {
    return _then(_self.copyWith(businessHours: value));
  });
}
}


/// Adds pattern-matching-related methods to [StoreEntity].
extension StoreEntityPatterns on StoreEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StoreEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StoreEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StoreEntity value)  $default,){
final _that = this;
switch (_that) {
case _StoreEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StoreEntity value)?  $default,){
final _that = this;
switch (_that) {
case _StoreEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String imageUrl,  UserLocation location,  StoreGrade grade,  double averageScore,  int reviewCount,  List<String> menuCategories,  DateTime createdAt,  String ownerId,  String phone,  String address,  String? description,  BusinessHours? businessHours,  double? distanceKm,  String? brandId,  EntityApprovalStatus status,  String? submittedBy,  DateTime? submittedAt,  String? approvedBy,  DateTime? approvedAt,  DateTime? rejectedAt,  String? rejectedReason,  String? businessRegistrationNumber,  bool temporaryClosed,  List<DateTime> closedDates,  List<String> imageUrls,  String? notice,  List<String> excludedMainCategories,  List<String> availableMainCategories,  DateTime? updatedAt,  QoinRateSetting qoinAccrualRate,  QoinSwitchSetting qoinAccrualEnabled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StoreEntity() when $default != null:
return $default(_that.id,_that.name,_that.imageUrl,_that.location,_that.grade,_that.averageScore,_that.reviewCount,_that.menuCategories,_that.createdAt,_that.ownerId,_that.phone,_that.address,_that.description,_that.businessHours,_that.distanceKm,_that.brandId,_that.status,_that.submittedBy,_that.submittedAt,_that.approvedBy,_that.approvedAt,_that.rejectedAt,_that.rejectedReason,_that.businessRegistrationNumber,_that.temporaryClosed,_that.closedDates,_that.imageUrls,_that.notice,_that.excludedMainCategories,_that.availableMainCategories,_that.updatedAt,_that.qoinAccrualRate,_that.qoinAccrualEnabled);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String imageUrl,  UserLocation location,  StoreGrade grade,  double averageScore,  int reviewCount,  List<String> menuCategories,  DateTime createdAt,  String ownerId,  String phone,  String address,  String? description,  BusinessHours? businessHours,  double? distanceKm,  String? brandId,  EntityApprovalStatus status,  String? submittedBy,  DateTime? submittedAt,  String? approvedBy,  DateTime? approvedAt,  DateTime? rejectedAt,  String? rejectedReason,  String? businessRegistrationNumber,  bool temporaryClosed,  List<DateTime> closedDates,  List<String> imageUrls,  String? notice,  List<String> excludedMainCategories,  List<String> availableMainCategories,  DateTime? updatedAt,  QoinRateSetting qoinAccrualRate,  QoinSwitchSetting qoinAccrualEnabled)  $default,) {final _that = this;
switch (_that) {
case _StoreEntity():
return $default(_that.id,_that.name,_that.imageUrl,_that.location,_that.grade,_that.averageScore,_that.reviewCount,_that.menuCategories,_that.createdAt,_that.ownerId,_that.phone,_that.address,_that.description,_that.businessHours,_that.distanceKm,_that.brandId,_that.status,_that.submittedBy,_that.submittedAt,_that.approvedBy,_that.approvedAt,_that.rejectedAt,_that.rejectedReason,_that.businessRegistrationNumber,_that.temporaryClosed,_that.closedDates,_that.imageUrls,_that.notice,_that.excludedMainCategories,_that.availableMainCategories,_that.updatedAt,_that.qoinAccrualRate,_that.qoinAccrualEnabled);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String imageUrl,  UserLocation location,  StoreGrade grade,  double averageScore,  int reviewCount,  List<String> menuCategories,  DateTime createdAt,  String ownerId,  String phone,  String address,  String? description,  BusinessHours? businessHours,  double? distanceKm,  String? brandId,  EntityApprovalStatus status,  String? submittedBy,  DateTime? submittedAt,  String? approvedBy,  DateTime? approvedAt,  DateTime? rejectedAt,  String? rejectedReason,  String? businessRegistrationNumber,  bool temporaryClosed,  List<DateTime> closedDates,  List<String> imageUrls,  String? notice,  List<String> excludedMainCategories,  List<String> availableMainCategories,  DateTime? updatedAt,  QoinRateSetting qoinAccrualRate,  QoinSwitchSetting qoinAccrualEnabled)?  $default,) {final _that = this;
switch (_that) {
case _StoreEntity() when $default != null:
return $default(_that.id,_that.name,_that.imageUrl,_that.location,_that.grade,_that.averageScore,_that.reviewCount,_that.menuCategories,_that.createdAt,_that.ownerId,_that.phone,_that.address,_that.description,_that.businessHours,_that.distanceKm,_that.brandId,_that.status,_that.submittedBy,_that.submittedAt,_that.approvedBy,_that.approvedAt,_that.rejectedAt,_that.rejectedReason,_that.businessRegistrationNumber,_that.temporaryClosed,_that.closedDates,_that.imageUrls,_that.notice,_that.excludedMainCategories,_that.availableMainCategories,_that.updatedAt,_that.qoinAccrualRate,_that.qoinAccrualEnabled);case _:
  return null;

}
}

}

/// @nodoc


class _StoreEntity implements StoreEntity {
  const _StoreEntity({required this.id, required this.name, required this.imageUrl, required this.location, required this.grade, required this.averageScore, required this.reviewCount, required final  List<String> menuCategories, required this.createdAt, this.ownerId = '', this.phone = '', this.address = '', this.description, this.businessHours, this.distanceKm, this.brandId, this.status = EntityApprovalStatus.approved, this.submittedBy, this.submittedAt, this.approvedBy, this.approvedAt, this.rejectedAt, this.rejectedReason, this.businessRegistrationNumber, this.temporaryClosed = false, final  List<DateTime> closedDates = const [], final  List<String> imageUrls = const [], this.notice, final  List<String> excludedMainCategories = const [], final  List<String> availableMainCategories = const [], this.updatedAt, this.qoinAccrualRate = QoinRateSetting.absent, this.qoinAccrualEnabled = QoinSwitchSetting.enabled}): _menuCategories = menuCategories,_closedDates = closedDates,_imageUrls = imageUrls,_excludedMainCategories = excludedMainCategories,_availableMainCategories = availableMainCategories;
  

@override final  String id;
@override final  String name;
@override final  String imageUrl;
@override final  UserLocation location;
@override final  StoreGrade grade;
@override final  double averageScore;
@override final  int reviewCount;
 final  List<String> _menuCategories;
@override List<String> get menuCategories {
  if (_menuCategories is EqualUnmodifiableListView) return _menuCategories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_menuCategories);
}

@override final  DateTime createdAt;
@override@JsonKey() final  String ownerId;
@override@JsonKey() final  String phone;
@override@JsonKey() final  String address;
@override final  String? description;
@override final  BusinessHours? businessHours;
@override final  double? distanceKm;
// ── sub-phase 2 신규 필드 ────────────────────────────────────────────
/// 브랜드 매장이면 brandId, 개인 매장(점주 직접 등록)이면 null.
@override final  String? brandId;
/// 승인 상태. missing status → approved fallback (T1, legacy 안전).
@override@JsonKey() final  EntityApprovalStatus status;
/// 이번 신청을 제출한 사용자 uid.
@override final  String? submittedBy;
/// 점주 제출 시점.
@override final  DateTime? submittedAt;
/// admin 이 마지막으로 처리한 uid (approve/reject 양쪽).
@override final  String? approvedBy;
/// admin **승인** 시점. 승인 행위에서만 쓴다 (반려는 [rejectedAt]).
@override final  DateTime? approvedAt;
/// admin **반려** 시점. 점주 재제출 시 null 로 클리어된다.
@override final  DateTime? rejectedAt;
/// admin 반려 사유. status=rejected 일 때만 의미 있음.
@override final  String? rejectedReason;
/// 사업자등록번호 (핵심 필드).
@override final  String? businessRegistrationNumber;
/// 임시 휴무 토글 (운영 필드).
@override@JsonKey() final  bool temporaryClosed;
/// 특정 날짜 휴무 리스트 (운영 필드).
 final  List<DateTime> _closedDates;
/// 특정 날짜 휴무 리스트 (운영 필드).
@override@JsonKey() List<DateTime> get closedDates {
  if (_closedDates is EqualUnmodifiableListView) return _closedDates;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_closedDates);
}

/// 대표 이미지 URL 목록. 기존 단일 imageUrl 과 병행 (호환성).
 final  List<String> _imageUrls;
/// 대표 이미지 URL 목록. 기존 단일 imageUrl 과 병행 (호환성).
@override@JsonKey() List<String> get imageUrls {
  if (_imageUrls is EqualUnmodifiableListView) return _imageUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_imageUrls);
}

/// 매장 안내 문구 (운영 필드).
@override final  String? notice;
/// 점주가 끈 메인 카테고리 코드 목록 (운영 필드, opt-out). 빈 목록 = 전부 노출.
/// sticky: 한 번 끄면 이후 해당 카테고리 메뉴가 생겨도 계속 숨긴다.
 final  List<String> _excludedMainCategories;
/// 점주가 끈 메인 카테고리 코드 목록 (운영 필드, opt-out). 빈 목록 = 전부 노출.
/// sticky: 한 번 끄면 이후 해당 카테고리 메뉴가 생겨도 계속 숨긴다.
@override@JsonKey() List<String> get excludedMainCategories {
  if (_excludedMainCategories is EqualUnmodifiableListView) return _excludedMainCategories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_excludedMainCategories);
}

/// 검색/홈 필터용 파생 메인 카테고리 코드 (Cloud Function 전담, 읽기 전용).
/// 노출 메뉴의 mainCategory ∩ active − excluded. 부재 = 빈 목록.
 final  List<String> _availableMainCategories;
/// 검색/홈 필터용 파생 메인 카테고리 코드 (Cloud Function 전담, 읽기 전용).
/// 노출 메뉴의 mainCategory ∩ active − excluded. 부재 = 빈 목록.
@override@JsonKey() List<String> get availableMainCategories {
  if (_availableMainCategories is EqualUnmodifiableListView) return _availableMainCategories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableMainCategories);
}

/// 최종 수정 시점.
@override final  DateTime? updatedAt;
/// Qoin 적립률 개별 설정 (`qoinAccrualRate`). 부재 = 상위 상속. 0 은 적립률이 아니다.
/// **읽기 전용** — 쓰기는 CF(setQoinAccrualRate / applyBrandQoinRate) 전담.
@override@JsonKey() final  QoinRateSetting qoinAccrualRate;
/// 적립 스위치 (`qoinAccrualEnabled`). 부재/true = 사용, false = 사용 안 함. **읽기 전용.**
@override@JsonKey() final  QoinSwitchSetting qoinAccrualEnabled;

/// Create a copy of StoreEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StoreEntityCopyWith<_StoreEntity> get copyWith => __$StoreEntityCopyWithImpl<_StoreEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StoreEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.location, location) || other.location == location)&&(identical(other.grade, grade) || other.grade == grade)&&(identical(other.averageScore, averageScore) || other.averageScore == averageScore)&&(identical(other.reviewCount, reviewCount) || other.reviewCount == reviewCount)&&const DeepCollectionEquality().equals(other._menuCategories, _menuCategories)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.ownerId, ownerId) || other.ownerId == ownerId)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.address, address) || other.address == address)&&(identical(other.description, description) || other.description == description)&&(identical(other.businessHours, businessHours) || other.businessHours == businessHours)&&(identical(other.distanceKm, distanceKm) || other.distanceKm == distanceKm)&&(identical(other.brandId, brandId) || other.brandId == brandId)&&(identical(other.status, status) || other.status == status)&&(identical(other.submittedBy, submittedBy) || other.submittedBy == submittedBy)&&(identical(other.submittedAt, submittedAt) || other.submittedAt == submittedAt)&&(identical(other.approvedBy, approvedBy) || other.approvedBy == approvedBy)&&(identical(other.approvedAt, approvedAt) || other.approvedAt == approvedAt)&&(identical(other.rejectedAt, rejectedAt) || other.rejectedAt == rejectedAt)&&(identical(other.rejectedReason, rejectedReason) || other.rejectedReason == rejectedReason)&&(identical(other.businessRegistrationNumber, businessRegistrationNumber) || other.businessRegistrationNumber == businessRegistrationNumber)&&(identical(other.temporaryClosed, temporaryClosed) || other.temporaryClosed == temporaryClosed)&&const DeepCollectionEquality().equals(other._closedDates, _closedDates)&&const DeepCollectionEquality().equals(other._imageUrls, _imageUrls)&&(identical(other.notice, notice) || other.notice == notice)&&const DeepCollectionEquality().equals(other._excludedMainCategories, _excludedMainCategories)&&const DeepCollectionEquality().equals(other._availableMainCategories, _availableMainCategories)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.qoinAccrualRate, qoinAccrualRate) || other.qoinAccrualRate == qoinAccrualRate)&&(identical(other.qoinAccrualEnabled, qoinAccrualEnabled) || other.qoinAccrualEnabled == qoinAccrualEnabled));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,name,imageUrl,location,grade,averageScore,reviewCount,const DeepCollectionEquality().hash(_menuCategories),createdAt,ownerId,phone,address,description,businessHours,distanceKm,brandId,status,submittedBy,submittedAt,approvedBy,approvedAt,rejectedAt,rejectedReason,businessRegistrationNumber,temporaryClosed,const DeepCollectionEquality().hash(_closedDates),const DeepCollectionEquality().hash(_imageUrls),notice,const DeepCollectionEquality().hash(_excludedMainCategories),const DeepCollectionEquality().hash(_availableMainCategories),updatedAt,qoinAccrualRate,qoinAccrualEnabled]);

@override
String toString() {
  return 'StoreEntity(id: $id, name: $name, imageUrl: $imageUrl, location: $location, grade: $grade, averageScore: $averageScore, reviewCount: $reviewCount, menuCategories: $menuCategories, createdAt: $createdAt, ownerId: $ownerId, phone: $phone, address: $address, description: $description, businessHours: $businessHours, distanceKm: $distanceKm, brandId: $brandId, status: $status, submittedBy: $submittedBy, submittedAt: $submittedAt, approvedBy: $approvedBy, approvedAt: $approvedAt, rejectedAt: $rejectedAt, rejectedReason: $rejectedReason, businessRegistrationNumber: $businessRegistrationNumber, temporaryClosed: $temporaryClosed, closedDates: $closedDates, imageUrls: $imageUrls, notice: $notice, excludedMainCategories: $excludedMainCategories, availableMainCategories: $availableMainCategories, updatedAt: $updatedAt, qoinAccrualRate: $qoinAccrualRate, qoinAccrualEnabled: $qoinAccrualEnabled)';
}


}

/// @nodoc
abstract mixin class _$StoreEntityCopyWith<$Res> implements $StoreEntityCopyWith<$Res> {
  factory _$StoreEntityCopyWith(_StoreEntity value, $Res Function(_StoreEntity) _then) = __$StoreEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String imageUrl, UserLocation location, StoreGrade grade, double averageScore, int reviewCount, List<String> menuCategories, DateTime createdAt, String ownerId, String phone, String address, String? description, BusinessHours? businessHours, double? distanceKm, String? brandId, EntityApprovalStatus status, String? submittedBy, DateTime? submittedAt, String? approvedBy, DateTime? approvedAt, DateTime? rejectedAt, String? rejectedReason, String? businessRegistrationNumber, bool temporaryClosed, List<DateTime> closedDates, List<String> imageUrls, String? notice, List<String> excludedMainCategories, List<String> availableMainCategories, DateTime? updatedAt, QoinRateSetting qoinAccrualRate, QoinSwitchSetting qoinAccrualEnabled
});


@override $UserLocationCopyWith<$Res> get location;@override $BusinessHoursCopyWith<$Res>? get businessHours;

}
/// @nodoc
class __$StoreEntityCopyWithImpl<$Res>
    implements _$StoreEntityCopyWith<$Res> {
  __$StoreEntityCopyWithImpl(this._self, this._then);

  final _StoreEntity _self;
  final $Res Function(_StoreEntity) _then;

/// Create a copy of StoreEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? imageUrl = null,Object? location = null,Object? grade = null,Object? averageScore = null,Object? reviewCount = null,Object? menuCategories = null,Object? createdAt = null,Object? ownerId = null,Object? phone = null,Object? address = null,Object? description = freezed,Object? businessHours = freezed,Object? distanceKm = freezed,Object? brandId = freezed,Object? status = null,Object? submittedBy = freezed,Object? submittedAt = freezed,Object? approvedBy = freezed,Object? approvedAt = freezed,Object? rejectedAt = freezed,Object? rejectedReason = freezed,Object? businessRegistrationNumber = freezed,Object? temporaryClosed = null,Object? closedDates = null,Object? imageUrls = null,Object? notice = freezed,Object? excludedMainCategories = null,Object? availableMainCategories = null,Object? updatedAt = freezed,Object? qoinAccrualRate = null,Object? qoinAccrualEnabled = null,}) {
  return _then(_StoreEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as UserLocation,grade: null == grade ? _self.grade : grade // ignore: cast_nullable_to_non_nullable
as StoreGrade,averageScore: null == averageScore ? _self.averageScore : averageScore // ignore: cast_nullable_to_non_nullable
as double,reviewCount: null == reviewCount ? _self.reviewCount : reviewCount // ignore: cast_nullable_to_non_nullable
as int,menuCategories: null == menuCategories ? _self._menuCategories : menuCategories // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,ownerId: null == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,address: null == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,businessHours: freezed == businessHours ? _self.businessHours : businessHours // ignore: cast_nullable_to_non_nullable
as BusinessHours?,distanceKm: freezed == distanceKm ? _self.distanceKm : distanceKm // ignore: cast_nullable_to_non_nullable
as double?,brandId: freezed == brandId ? _self.brandId : brandId // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as EntityApprovalStatus,submittedBy: freezed == submittedBy ? _self.submittedBy : submittedBy // ignore: cast_nullable_to_non_nullable
as String?,submittedAt: freezed == submittedAt ? _self.submittedAt : submittedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,approvedBy: freezed == approvedBy ? _self.approvedBy : approvedBy // ignore: cast_nullable_to_non_nullable
as String?,approvedAt: freezed == approvedAt ? _self.approvedAt : approvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,rejectedAt: freezed == rejectedAt ? _self.rejectedAt : rejectedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,rejectedReason: freezed == rejectedReason ? _self.rejectedReason : rejectedReason // ignore: cast_nullable_to_non_nullable
as String?,businessRegistrationNumber: freezed == businessRegistrationNumber ? _self.businessRegistrationNumber : businessRegistrationNumber // ignore: cast_nullable_to_non_nullable
as String?,temporaryClosed: null == temporaryClosed ? _self.temporaryClosed : temporaryClosed // ignore: cast_nullable_to_non_nullable
as bool,closedDates: null == closedDates ? _self._closedDates : closedDates // ignore: cast_nullable_to_non_nullable
as List<DateTime>,imageUrls: null == imageUrls ? _self._imageUrls : imageUrls // ignore: cast_nullable_to_non_nullable
as List<String>,notice: freezed == notice ? _self.notice : notice // ignore: cast_nullable_to_non_nullable
as String?,excludedMainCategories: null == excludedMainCategories ? _self._excludedMainCategories : excludedMainCategories // ignore: cast_nullable_to_non_nullable
as List<String>,availableMainCategories: null == availableMainCategories ? _self._availableMainCategories : availableMainCategories // ignore: cast_nullable_to_non_nullable
as List<String>,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,qoinAccrualRate: null == qoinAccrualRate ? _self.qoinAccrualRate : qoinAccrualRate // ignore: cast_nullable_to_non_nullable
as QoinRateSetting,qoinAccrualEnabled: null == qoinAccrualEnabled ? _self.qoinAccrualEnabled : qoinAccrualEnabled // ignore: cast_nullable_to_non_nullable
as QoinSwitchSetting,
  ));
}

/// Create a copy of StoreEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserLocationCopyWith<$Res> get location {
  
  return $UserLocationCopyWith<$Res>(_self.location, (value) {
    return _then(_self.copyWith(location: value));
  });
}/// Create a copy of StoreEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BusinessHoursCopyWith<$Res>? get businessHours {
    if (_self.businessHours == null) {
    return null;
  }

  return $BusinessHoursCopyWith<$Res>(_self.businessHours!, (value) {
    return _then(_self.copyWith(businessHours: value));
  });
}
}

// dart format on

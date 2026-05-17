// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'menu_override_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MenuOverrideEntity {

/// doc.id (= masterMenuItemId). collectionGroup query 에서도 사용.
 String get masterMenuItemId; String get storeId;/// store.brandId 와 동일. collectionGroup query 필터용.
 String get brandId;/// null = 마스터 가격 사용.
 int? get priceOverride;/// 이 매장에서 해당 마스터 메뉴를 제외할지 여부.
 bool get excluded;/// 품절 여부. sub-phase 5 에서 점주 즉시 토글. status 무관.
 bool get soldOut;/// 점주가 비활성화한 옵션 그룹 ID 목록. sub-phase 5 활성.
 List<String> get disabledOptionGroupIds;/// 점주가 비활성화한 옵션 항목 ID 목록. sub-phase 5 활성.
 List<String> get disabledOptionItemIds;/// 핵심 필드(priceOverride / excluded) 의 승인 상태.
 EntityApprovalStatus get status; String? get submittedBy; DateTime? get submittedAt; String? get approvedBy; DateTime? get approvedAt; String? get rejectedReason;/// 최종 수정자 역할 추적 ('admin'|'brand'|'owner').
 String? get updatedBy; DateTime? get updatedAt;
/// Create a copy of MenuOverrideEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MenuOverrideEntityCopyWith<MenuOverrideEntity> get copyWith => _$MenuOverrideEntityCopyWithImpl<MenuOverrideEntity>(this as MenuOverrideEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MenuOverrideEntity&&(identical(other.masterMenuItemId, masterMenuItemId) || other.masterMenuItemId == masterMenuItemId)&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.brandId, brandId) || other.brandId == brandId)&&(identical(other.priceOverride, priceOverride) || other.priceOverride == priceOverride)&&(identical(other.excluded, excluded) || other.excluded == excluded)&&(identical(other.soldOut, soldOut) || other.soldOut == soldOut)&&const DeepCollectionEquality().equals(other.disabledOptionGroupIds, disabledOptionGroupIds)&&const DeepCollectionEquality().equals(other.disabledOptionItemIds, disabledOptionItemIds)&&(identical(other.status, status) || other.status == status)&&(identical(other.submittedBy, submittedBy) || other.submittedBy == submittedBy)&&(identical(other.submittedAt, submittedAt) || other.submittedAt == submittedAt)&&(identical(other.approvedBy, approvedBy) || other.approvedBy == approvedBy)&&(identical(other.approvedAt, approvedAt) || other.approvedAt == approvedAt)&&(identical(other.rejectedReason, rejectedReason) || other.rejectedReason == rejectedReason)&&(identical(other.updatedBy, updatedBy) || other.updatedBy == updatedBy)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,masterMenuItemId,storeId,brandId,priceOverride,excluded,soldOut,const DeepCollectionEquality().hash(disabledOptionGroupIds),const DeepCollectionEquality().hash(disabledOptionItemIds),status,submittedBy,submittedAt,approvedBy,approvedAt,rejectedReason,updatedBy,updatedAt);

@override
String toString() {
  return 'MenuOverrideEntity(masterMenuItemId: $masterMenuItemId, storeId: $storeId, brandId: $brandId, priceOverride: $priceOverride, excluded: $excluded, soldOut: $soldOut, disabledOptionGroupIds: $disabledOptionGroupIds, disabledOptionItemIds: $disabledOptionItemIds, status: $status, submittedBy: $submittedBy, submittedAt: $submittedAt, approvedBy: $approvedBy, approvedAt: $approvedAt, rejectedReason: $rejectedReason, updatedBy: $updatedBy, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $MenuOverrideEntityCopyWith<$Res>  {
  factory $MenuOverrideEntityCopyWith(MenuOverrideEntity value, $Res Function(MenuOverrideEntity) _then) = _$MenuOverrideEntityCopyWithImpl;
@useResult
$Res call({
 String masterMenuItemId, String storeId, String brandId, int? priceOverride, bool excluded, bool soldOut, List<String> disabledOptionGroupIds, List<String> disabledOptionItemIds, EntityApprovalStatus status, String? submittedBy, DateTime? submittedAt, String? approvedBy, DateTime? approvedAt, String? rejectedReason, String? updatedBy, DateTime? updatedAt
});




}
/// @nodoc
class _$MenuOverrideEntityCopyWithImpl<$Res>
    implements $MenuOverrideEntityCopyWith<$Res> {
  _$MenuOverrideEntityCopyWithImpl(this._self, this._then);

  final MenuOverrideEntity _self;
  final $Res Function(MenuOverrideEntity) _then;

/// Create a copy of MenuOverrideEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? masterMenuItemId = null,Object? storeId = null,Object? brandId = null,Object? priceOverride = freezed,Object? excluded = null,Object? soldOut = null,Object? disabledOptionGroupIds = null,Object? disabledOptionItemIds = null,Object? status = null,Object? submittedBy = freezed,Object? submittedAt = freezed,Object? approvedBy = freezed,Object? approvedAt = freezed,Object? rejectedReason = freezed,Object? updatedBy = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
masterMenuItemId: null == masterMenuItemId ? _self.masterMenuItemId : masterMenuItemId // ignore: cast_nullable_to_non_nullable
as String,storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,brandId: null == brandId ? _self.brandId : brandId // ignore: cast_nullable_to_non_nullable
as String,priceOverride: freezed == priceOverride ? _self.priceOverride : priceOverride // ignore: cast_nullable_to_non_nullable
as int?,excluded: null == excluded ? _self.excluded : excluded // ignore: cast_nullable_to_non_nullable
as bool,soldOut: null == soldOut ? _self.soldOut : soldOut // ignore: cast_nullable_to_non_nullable
as bool,disabledOptionGroupIds: null == disabledOptionGroupIds ? _self.disabledOptionGroupIds : disabledOptionGroupIds // ignore: cast_nullable_to_non_nullable
as List<String>,disabledOptionItemIds: null == disabledOptionItemIds ? _self.disabledOptionItemIds : disabledOptionItemIds // ignore: cast_nullable_to_non_nullable
as List<String>,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as EntityApprovalStatus,submittedBy: freezed == submittedBy ? _self.submittedBy : submittedBy // ignore: cast_nullable_to_non_nullable
as String?,submittedAt: freezed == submittedAt ? _self.submittedAt : submittedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,approvedBy: freezed == approvedBy ? _self.approvedBy : approvedBy // ignore: cast_nullable_to_non_nullable
as String?,approvedAt: freezed == approvedAt ? _self.approvedAt : approvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,rejectedReason: freezed == rejectedReason ? _self.rejectedReason : rejectedReason // ignore: cast_nullable_to_non_nullable
as String?,updatedBy: freezed == updatedBy ? _self.updatedBy : updatedBy // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [MenuOverrideEntity].
extension MenuOverrideEntityPatterns on MenuOverrideEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MenuOverrideEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MenuOverrideEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MenuOverrideEntity value)  $default,){
final _that = this;
switch (_that) {
case _MenuOverrideEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MenuOverrideEntity value)?  $default,){
final _that = this;
switch (_that) {
case _MenuOverrideEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String masterMenuItemId,  String storeId,  String brandId,  int? priceOverride,  bool excluded,  bool soldOut,  List<String> disabledOptionGroupIds,  List<String> disabledOptionItemIds,  EntityApprovalStatus status,  String? submittedBy,  DateTime? submittedAt,  String? approvedBy,  DateTime? approvedAt,  String? rejectedReason,  String? updatedBy,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MenuOverrideEntity() when $default != null:
return $default(_that.masterMenuItemId,_that.storeId,_that.brandId,_that.priceOverride,_that.excluded,_that.soldOut,_that.disabledOptionGroupIds,_that.disabledOptionItemIds,_that.status,_that.submittedBy,_that.submittedAt,_that.approvedBy,_that.approvedAt,_that.rejectedReason,_that.updatedBy,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String masterMenuItemId,  String storeId,  String brandId,  int? priceOverride,  bool excluded,  bool soldOut,  List<String> disabledOptionGroupIds,  List<String> disabledOptionItemIds,  EntityApprovalStatus status,  String? submittedBy,  DateTime? submittedAt,  String? approvedBy,  DateTime? approvedAt,  String? rejectedReason,  String? updatedBy,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _MenuOverrideEntity():
return $default(_that.masterMenuItemId,_that.storeId,_that.brandId,_that.priceOverride,_that.excluded,_that.soldOut,_that.disabledOptionGroupIds,_that.disabledOptionItemIds,_that.status,_that.submittedBy,_that.submittedAt,_that.approvedBy,_that.approvedAt,_that.rejectedReason,_that.updatedBy,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String masterMenuItemId,  String storeId,  String brandId,  int? priceOverride,  bool excluded,  bool soldOut,  List<String> disabledOptionGroupIds,  List<String> disabledOptionItemIds,  EntityApprovalStatus status,  String? submittedBy,  DateTime? submittedAt,  String? approvedBy,  DateTime? approvedAt,  String? rejectedReason,  String? updatedBy,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _MenuOverrideEntity() when $default != null:
return $default(_that.masterMenuItemId,_that.storeId,_that.brandId,_that.priceOverride,_that.excluded,_that.soldOut,_that.disabledOptionGroupIds,_that.disabledOptionItemIds,_that.status,_that.submittedBy,_that.submittedAt,_that.approvedBy,_that.approvedAt,_that.rejectedReason,_that.updatedBy,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _MenuOverrideEntity implements MenuOverrideEntity {
  const _MenuOverrideEntity({required this.masterMenuItemId, required this.storeId, required this.brandId, this.priceOverride, this.excluded = false, this.soldOut = false, final  List<String> disabledOptionGroupIds = const <String>[], final  List<String> disabledOptionItemIds = const <String>[], this.status = EntityApprovalStatus.pending, this.submittedBy, this.submittedAt, this.approvedBy, this.approvedAt, this.rejectedReason, this.updatedBy, this.updatedAt}): _disabledOptionGroupIds = disabledOptionGroupIds,_disabledOptionItemIds = disabledOptionItemIds;
  

/// doc.id (= masterMenuItemId). collectionGroup query 에서도 사용.
@override final  String masterMenuItemId;
@override final  String storeId;
/// store.brandId 와 동일. collectionGroup query 필터용.
@override final  String brandId;
/// null = 마스터 가격 사용.
@override final  int? priceOverride;
/// 이 매장에서 해당 마스터 메뉴를 제외할지 여부.
@override@JsonKey() final  bool excluded;
/// 품절 여부. sub-phase 5 에서 점주 즉시 토글. status 무관.
@override@JsonKey() final  bool soldOut;
/// 점주가 비활성화한 옵션 그룹 ID 목록. sub-phase 5 활성.
 final  List<String> _disabledOptionGroupIds;
/// 점주가 비활성화한 옵션 그룹 ID 목록. sub-phase 5 활성.
@override@JsonKey() List<String> get disabledOptionGroupIds {
  if (_disabledOptionGroupIds is EqualUnmodifiableListView) return _disabledOptionGroupIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_disabledOptionGroupIds);
}

/// 점주가 비활성화한 옵션 항목 ID 목록. sub-phase 5 활성.
 final  List<String> _disabledOptionItemIds;
/// 점주가 비활성화한 옵션 항목 ID 목록. sub-phase 5 활성.
@override@JsonKey() List<String> get disabledOptionItemIds {
  if (_disabledOptionItemIds is EqualUnmodifiableListView) return _disabledOptionItemIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_disabledOptionItemIds);
}

/// 핵심 필드(priceOverride / excluded) 의 승인 상태.
@override@JsonKey() final  EntityApprovalStatus status;
@override final  String? submittedBy;
@override final  DateTime? submittedAt;
@override final  String? approvedBy;
@override final  DateTime? approvedAt;
@override final  String? rejectedReason;
/// 최종 수정자 역할 추적 ('admin'|'brand'|'owner').
@override final  String? updatedBy;
@override final  DateTime? updatedAt;

/// Create a copy of MenuOverrideEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MenuOverrideEntityCopyWith<_MenuOverrideEntity> get copyWith => __$MenuOverrideEntityCopyWithImpl<_MenuOverrideEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MenuOverrideEntity&&(identical(other.masterMenuItemId, masterMenuItemId) || other.masterMenuItemId == masterMenuItemId)&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.brandId, brandId) || other.brandId == brandId)&&(identical(other.priceOverride, priceOverride) || other.priceOverride == priceOverride)&&(identical(other.excluded, excluded) || other.excluded == excluded)&&(identical(other.soldOut, soldOut) || other.soldOut == soldOut)&&const DeepCollectionEquality().equals(other._disabledOptionGroupIds, _disabledOptionGroupIds)&&const DeepCollectionEquality().equals(other._disabledOptionItemIds, _disabledOptionItemIds)&&(identical(other.status, status) || other.status == status)&&(identical(other.submittedBy, submittedBy) || other.submittedBy == submittedBy)&&(identical(other.submittedAt, submittedAt) || other.submittedAt == submittedAt)&&(identical(other.approvedBy, approvedBy) || other.approvedBy == approvedBy)&&(identical(other.approvedAt, approvedAt) || other.approvedAt == approvedAt)&&(identical(other.rejectedReason, rejectedReason) || other.rejectedReason == rejectedReason)&&(identical(other.updatedBy, updatedBy) || other.updatedBy == updatedBy)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,masterMenuItemId,storeId,brandId,priceOverride,excluded,soldOut,const DeepCollectionEquality().hash(_disabledOptionGroupIds),const DeepCollectionEquality().hash(_disabledOptionItemIds),status,submittedBy,submittedAt,approvedBy,approvedAt,rejectedReason,updatedBy,updatedAt);

@override
String toString() {
  return 'MenuOverrideEntity(masterMenuItemId: $masterMenuItemId, storeId: $storeId, brandId: $brandId, priceOverride: $priceOverride, excluded: $excluded, soldOut: $soldOut, disabledOptionGroupIds: $disabledOptionGroupIds, disabledOptionItemIds: $disabledOptionItemIds, status: $status, submittedBy: $submittedBy, submittedAt: $submittedAt, approvedBy: $approvedBy, approvedAt: $approvedAt, rejectedReason: $rejectedReason, updatedBy: $updatedBy, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$MenuOverrideEntityCopyWith<$Res> implements $MenuOverrideEntityCopyWith<$Res> {
  factory _$MenuOverrideEntityCopyWith(_MenuOverrideEntity value, $Res Function(_MenuOverrideEntity) _then) = __$MenuOverrideEntityCopyWithImpl;
@override @useResult
$Res call({
 String masterMenuItemId, String storeId, String brandId, int? priceOverride, bool excluded, bool soldOut, List<String> disabledOptionGroupIds, List<String> disabledOptionItemIds, EntityApprovalStatus status, String? submittedBy, DateTime? submittedAt, String? approvedBy, DateTime? approvedAt, String? rejectedReason, String? updatedBy, DateTime? updatedAt
});




}
/// @nodoc
class __$MenuOverrideEntityCopyWithImpl<$Res>
    implements _$MenuOverrideEntityCopyWith<$Res> {
  __$MenuOverrideEntityCopyWithImpl(this._self, this._then);

  final _MenuOverrideEntity _self;
  final $Res Function(_MenuOverrideEntity) _then;

/// Create a copy of MenuOverrideEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? masterMenuItemId = null,Object? storeId = null,Object? brandId = null,Object? priceOverride = freezed,Object? excluded = null,Object? soldOut = null,Object? disabledOptionGroupIds = null,Object? disabledOptionItemIds = null,Object? status = null,Object? submittedBy = freezed,Object? submittedAt = freezed,Object? approvedBy = freezed,Object? approvedAt = freezed,Object? rejectedReason = freezed,Object? updatedBy = freezed,Object? updatedAt = freezed,}) {
  return _then(_MenuOverrideEntity(
masterMenuItemId: null == masterMenuItemId ? _self.masterMenuItemId : masterMenuItemId // ignore: cast_nullable_to_non_nullable
as String,storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,brandId: null == brandId ? _self.brandId : brandId // ignore: cast_nullable_to_non_nullable
as String,priceOverride: freezed == priceOverride ? _self.priceOverride : priceOverride // ignore: cast_nullable_to_non_nullable
as int?,excluded: null == excluded ? _self.excluded : excluded // ignore: cast_nullable_to_non_nullable
as bool,soldOut: null == soldOut ? _self.soldOut : soldOut // ignore: cast_nullable_to_non_nullable
as bool,disabledOptionGroupIds: null == disabledOptionGroupIds ? _self._disabledOptionGroupIds : disabledOptionGroupIds // ignore: cast_nullable_to_non_nullable
as List<String>,disabledOptionItemIds: null == disabledOptionItemIds ? _self._disabledOptionItemIds : disabledOptionItemIds // ignore: cast_nullable_to_non_nullable
as List<String>,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as EntityApprovalStatus,submittedBy: freezed == submittedBy ? _self.submittedBy : submittedBy // ignore: cast_nullable_to_non_nullable
as String?,submittedAt: freezed == submittedAt ? _self.submittedAt : submittedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,approvedBy: freezed == approvedBy ? _self.approvedBy : approvedBy // ignore: cast_nullable_to_non_nullable
as String?,approvedAt: freezed == approvedAt ? _self.approvedAt : approvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,rejectedReason: freezed == rejectedReason ? _self.rejectedReason : rejectedReason // ignore: cast_nullable_to_non_nullable
as String?,updatedBy: freezed == updatedBy ? _self.updatedBy : updatedBy // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on

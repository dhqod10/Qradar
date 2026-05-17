// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sub_category_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SubCategoryEntity {

 String get id; String get mainCategoryCode; String get name; int get displayOrder; bool get active;// ── 2-tier 신규 필드 ───────────────────────────────────────────────
/// 소유 주체. null 이면 legacy global sub.
 SubCategoryScope? get scope;/// brand scope 일 때 해당 brandId.
 String? get brandId;/// store scope 일 때 해당 storeId.
 String? get storeId; DateTime? get createdAt; DateTime? get updatedAt;
/// Create a copy of SubCategoryEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubCategoryEntityCopyWith<SubCategoryEntity> get copyWith => _$SubCategoryEntityCopyWithImpl<SubCategoryEntity>(this as SubCategoryEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubCategoryEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.mainCategoryCode, mainCategoryCode) || other.mainCategoryCode == mainCategoryCode)&&(identical(other.name, name) || other.name == name)&&(identical(other.displayOrder, displayOrder) || other.displayOrder == displayOrder)&&(identical(other.active, active) || other.active == active)&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.brandId, brandId) || other.brandId == brandId)&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,mainCategoryCode,name,displayOrder,active,scope,brandId,storeId,createdAt,updatedAt);

@override
String toString() {
  return 'SubCategoryEntity(id: $id, mainCategoryCode: $mainCategoryCode, name: $name, displayOrder: $displayOrder, active: $active, scope: $scope, brandId: $brandId, storeId: $storeId, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $SubCategoryEntityCopyWith<$Res>  {
  factory $SubCategoryEntityCopyWith(SubCategoryEntity value, $Res Function(SubCategoryEntity) _then) = _$SubCategoryEntityCopyWithImpl;
@useResult
$Res call({
 String id, String mainCategoryCode, String name, int displayOrder, bool active, SubCategoryScope? scope, String? brandId, String? storeId, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class _$SubCategoryEntityCopyWithImpl<$Res>
    implements $SubCategoryEntityCopyWith<$Res> {
  _$SubCategoryEntityCopyWithImpl(this._self, this._then);

  final SubCategoryEntity _self;
  final $Res Function(SubCategoryEntity) _then;

/// Create a copy of SubCategoryEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? mainCategoryCode = null,Object? name = null,Object? displayOrder = null,Object? active = null,Object? scope = freezed,Object? brandId = freezed,Object? storeId = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,mainCategoryCode: null == mainCategoryCode ? _self.mainCategoryCode : mainCategoryCode // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,displayOrder: null == displayOrder ? _self.displayOrder : displayOrder // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,scope: freezed == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as SubCategoryScope?,brandId: freezed == brandId ? _self.brandId : brandId // ignore: cast_nullable_to_non_nullable
as String?,storeId: freezed == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [SubCategoryEntity].
extension SubCategoryEntityPatterns on SubCategoryEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubCategoryEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubCategoryEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubCategoryEntity value)  $default,){
final _that = this;
switch (_that) {
case _SubCategoryEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubCategoryEntity value)?  $default,){
final _that = this;
switch (_that) {
case _SubCategoryEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String mainCategoryCode,  String name,  int displayOrder,  bool active,  SubCategoryScope? scope,  String? brandId,  String? storeId,  DateTime? createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubCategoryEntity() when $default != null:
return $default(_that.id,_that.mainCategoryCode,_that.name,_that.displayOrder,_that.active,_that.scope,_that.brandId,_that.storeId,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String mainCategoryCode,  String name,  int displayOrder,  bool active,  SubCategoryScope? scope,  String? brandId,  String? storeId,  DateTime? createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _SubCategoryEntity():
return $default(_that.id,_that.mainCategoryCode,_that.name,_that.displayOrder,_that.active,_that.scope,_that.brandId,_that.storeId,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String mainCategoryCode,  String name,  int displayOrder,  bool active,  SubCategoryScope? scope,  String? brandId,  String? storeId,  DateTime? createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _SubCategoryEntity() when $default != null:
return $default(_that.id,_that.mainCategoryCode,_that.name,_that.displayOrder,_that.active,_that.scope,_that.brandId,_that.storeId,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _SubCategoryEntity implements SubCategoryEntity {
  const _SubCategoryEntity({required this.id, required this.mainCategoryCode, required this.name, this.displayOrder = 0, this.active = true, this.scope, this.brandId, this.storeId, this.createdAt, this.updatedAt});
  

@override final  String id;
@override final  String mainCategoryCode;
@override final  String name;
@override@JsonKey() final  int displayOrder;
@override@JsonKey() final  bool active;
// ── 2-tier 신규 필드 ───────────────────────────────────────────────
/// 소유 주체. null 이면 legacy global sub.
@override final  SubCategoryScope? scope;
/// brand scope 일 때 해당 brandId.
@override final  String? brandId;
/// store scope 일 때 해당 storeId.
@override final  String? storeId;
@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of SubCategoryEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubCategoryEntityCopyWith<_SubCategoryEntity> get copyWith => __$SubCategoryEntityCopyWithImpl<_SubCategoryEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubCategoryEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.mainCategoryCode, mainCategoryCode) || other.mainCategoryCode == mainCategoryCode)&&(identical(other.name, name) || other.name == name)&&(identical(other.displayOrder, displayOrder) || other.displayOrder == displayOrder)&&(identical(other.active, active) || other.active == active)&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.brandId, brandId) || other.brandId == brandId)&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,mainCategoryCode,name,displayOrder,active,scope,brandId,storeId,createdAt,updatedAt);

@override
String toString() {
  return 'SubCategoryEntity(id: $id, mainCategoryCode: $mainCategoryCode, name: $name, displayOrder: $displayOrder, active: $active, scope: $scope, brandId: $brandId, storeId: $storeId, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$SubCategoryEntityCopyWith<$Res> implements $SubCategoryEntityCopyWith<$Res> {
  factory _$SubCategoryEntityCopyWith(_SubCategoryEntity value, $Res Function(_SubCategoryEntity) _then) = __$SubCategoryEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String mainCategoryCode, String name, int displayOrder, bool active, SubCategoryScope? scope, String? brandId, String? storeId, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class __$SubCategoryEntityCopyWithImpl<$Res>
    implements _$SubCategoryEntityCopyWith<$Res> {
  __$SubCategoryEntityCopyWithImpl(this._self, this._then);

  final _SubCategoryEntity _self;
  final $Res Function(_SubCategoryEntity) _then;

/// Create a copy of SubCategoryEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? mainCategoryCode = null,Object? name = null,Object? displayOrder = null,Object? active = null,Object? scope = freezed,Object? brandId = freezed,Object? storeId = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_SubCategoryEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,mainCategoryCode: null == mainCategoryCode ? _self.mainCategoryCode : mainCategoryCode // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,displayOrder: null == displayOrder ? _self.displayOrder : displayOrder // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,scope: freezed == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as SubCategoryScope?,brandId: freezed == brandId ? _self.brandId : brandId // ignore: cast_nullable_to_non_nullable
as String?,storeId: freezed == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on

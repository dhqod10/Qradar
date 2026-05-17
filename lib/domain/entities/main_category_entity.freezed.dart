// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'main_category_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MainCategoryEntity {

 String get id; String get label; int get displayOrder; bool get active; DateTime? get createdAt; DateTime? get updatedAt;
/// Create a copy of MainCategoryEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MainCategoryEntityCopyWith<MainCategoryEntity> get copyWith => _$MainCategoryEntityCopyWithImpl<MainCategoryEntity>(this as MainCategoryEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MainCategoryEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.displayOrder, displayOrder) || other.displayOrder == displayOrder)&&(identical(other.active, active) || other.active == active)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,label,displayOrder,active,createdAt,updatedAt);

@override
String toString() {
  return 'MainCategoryEntity(id: $id, label: $label, displayOrder: $displayOrder, active: $active, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $MainCategoryEntityCopyWith<$Res>  {
  factory $MainCategoryEntityCopyWith(MainCategoryEntity value, $Res Function(MainCategoryEntity) _then) = _$MainCategoryEntityCopyWithImpl;
@useResult
$Res call({
 String id, String label, int displayOrder, bool active, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class _$MainCategoryEntityCopyWithImpl<$Res>
    implements $MainCategoryEntityCopyWith<$Res> {
  _$MainCategoryEntityCopyWithImpl(this._self, this._then);

  final MainCategoryEntity _self;
  final $Res Function(MainCategoryEntity) _then;

/// Create a copy of MainCategoryEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? label = null,Object? displayOrder = null,Object? active = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,displayOrder: null == displayOrder ? _self.displayOrder : displayOrder // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [MainCategoryEntity].
extension MainCategoryEntityPatterns on MainCategoryEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MainCategoryEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MainCategoryEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MainCategoryEntity value)  $default,){
final _that = this;
switch (_that) {
case _MainCategoryEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MainCategoryEntity value)?  $default,){
final _that = this;
switch (_that) {
case _MainCategoryEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String label,  int displayOrder,  bool active,  DateTime? createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MainCategoryEntity() when $default != null:
return $default(_that.id,_that.label,_that.displayOrder,_that.active,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String label,  int displayOrder,  bool active,  DateTime? createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _MainCategoryEntity():
return $default(_that.id,_that.label,_that.displayOrder,_that.active,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String label,  int displayOrder,  bool active,  DateTime? createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _MainCategoryEntity() when $default != null:
return $default(_that.id,_that.label,_that.displayOrder,_that.active,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _MainCategoryEntity implements MainCategoryEntity {
  const _MainCategoryEntity({required this.id, required this.label, this.displayOrder = 0, this.active = true, this.createdAt, this.updatedAt});
  

@override final  String id;
@override final  String label;
@override@JsonKey() final  int displayOrder;
@override@JsonKey() final  bool active;
@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of MainCategoryEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MainCategoryEntityCopyWith<_MainCategoryEntity> get copyWith => __$MainCategoryEntityCopyWithImpl<_MainCategoryEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MainCategoryEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.displayOrder, displayOrder) || other.displayOrder == displayOrder)&&(identical(other.active, active) || other.active == active)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,label,displayOrder,active,createdAt,updatedAt);

@override
String toString() {
  return 'MainCategoryEntity(id: $id, label: $label, displayOrder: $displayOrder, active: $active, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$MainCategoryEntityCopyWith<$Res> implements $MainCategoryEntityCopyWith<$Res> {
  factory _$MainCategoryEntityCopyWith(_MainCategoryEntity value, $Res Function(_MainCategoryEntity) _then) = __$MainCategoryEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String label, int displayOrder, bool active, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class __$MainCategoryEntityCopyWithImpl<$Res>
    implements _$MainCategoryEntityCopyWith<$Res> {
  __$MainCategoryEntityCopyWithImpl(this._self, this._then);

  final _MainCategoryEntity _self;
  final $Res Function(_MainCategoryEntity) _then;

/// Create a copy of MainCategoryEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? label = null,Object? displayOrder = null,Object? active = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_MainCategoryEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,displayOrder: null == displayOrder ? _self.displayOrder : displayOrder // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on

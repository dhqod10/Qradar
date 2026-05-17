// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'favorite_menu_item_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FavoriteMenuItemEntity {

 String get storeId; String get menuItemId; DateTime get addedAt;
/// Create a copy of FavoriteMenuItemEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FavoriteMenuItemEntityCopyWith<FavoriteMenuItemEntity> get copyWith => _$FavoriteMenuItemEntityCopyWithImpl<FavoriteMenuItemEntity>(this as FavoriteMenuItemEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FavoriteMenuItemEntity&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.menuItemId, menuItemId) || other.menuItemId == menuItemId)&&(identical(other.addedAt, addedAt) || other.addedAt == addedAt));
}


@override
int get hashCode => Object.hash(runtimeType,storeId,menuItemId,addedAt);

@override
String toString() {
  return 'FavoriteMenuItemEntity(storeId: $storeId, menuItemId: $menuItemId, addedAt: $addedAt)';
}


}

/// @nodoc
abstract mixin class $FavoriteMenuItemEntityCopyWith<$Res>  {
  factory $FavoriteMenuItemEntityCopyWith(FavoriteMenuItemEntity value, $Res Function(FavoriteMenuItemEntity) _then) = _$FavoriteMenuItemEntityCopyWithImpl;
@useResult
$Res call({
 String storeId, String menuItemId, DateTime addedAt
});




}
/// @nodoc
class _$FavoriteMenuItemEntityCopyWithImpl<$Res>
    implements $FavoriteMenuItemEntityCopyWith<$Res> {
  _$FavoriteMenuItemEntityCopyWithImpl(this._self, this._then);

  final FavoriteMenuItemEntity _self;
  final $Res Function(FavoriteMenuItemEntity) _then;

/// Create a copy of FavoriteMenuItemEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? storeId = null,Object? menuItemId = null,Object? addedAt = null,}) {
  return _then(_self.copyWith(
storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,menuItemId: null == menuItemId ? _self.menuItemId : menuItemId // ignore: cast_nullable_to_non_nullable
as String,addedAt: null == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [FavoriteMenuItemEntity].
extension FavoriteMenuItemEntityPatterns on FavoriteMenuItemEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FavoriteMenuItemEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FavoriteMenuItemEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FavoriteMenuItemEntity value)  $default,){
final _that = this;
switch (_that) {
case _FavoriteMenuItemEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FavoriteMenuItemEntity value)?  $default,){
final _that = this;
switch (_that) {
case _FavoriteMenuItemEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String storeId,  String menuItemId,  DateTime addedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FavoriteMenuItemEntity() when $default != null:
return $default(_that.storeId,_that.menuItemId,_that.addedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String storeId,  String menuItemId,  DateTime addedAt)  $default,) {final _that = this;
switch (_that) {
case _FavoriteMenuItemEntity():
return $default(_that.storeId,_that.menuItemId,_that.addedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String storeId,  String menuItemId,  DateTime addedAt)?  $default,) {final _that = this;
switch (_that) {
case _FavoriteMenuItemEntity() when $default != null:
return $default(_that.storeId,_that.menuItemId,_that.addedAt);case _:
  return null;

}
}

}

/// @nodoc


class _FavoriteMenuItemEntity implements FavoriteMenuItemEntity {
  const _FavoriteMenuItemEntity({required this.storeId, required this.menuItemId, required this.addedAt});
  

@override final  String storeId;
@override final  String menuItemId;
@override final  DateTime addedAt;

/// Create a copy of FavoriteMenuItemEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FavoriteMenuItemEntityCopyWith<_FavoriteMenuItemEntity> get copyWith => __$FavoriteMenuItemEntityCopyWithImpl<_FavoriteMenuItemEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FavoriteMenuItemEntity&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.menuItemId, menuItemId) || other.menuItemId == menuItemId)&&(identical(other.addedAt, addedAt) || other.addedAt == addedAt));
}


@override
int get hashCode => Object.hash(runtimeType,storeId,menuItemId,addedAt);

@override
String toString() {
  return 'FavoriteMenuItemEntity(storeId: $storeId, menuItemId: $menuItemId, addedAt: $addedAt)';
}


}

/// @nodoc
abstract mixin class _$FavoriteMenuItemEntityCopyWith<$Res> implements $FavoriteMenuItemEntityCopyWith<$Res> {
  factory _$FavoriteMenuItemEntityCopyWith(_FavoriteMenuItemEntity value, $Res Function(_FavoriteMenuItemEntity) _then) = __$FavoriteMenuItemEntityCopyWithImpl;
@override @useResult
$Res call({
 String storeId, String menuItemId, DateTime addedAt
});




}
/// @nodoc
class __$FavoriteMenuItemEntityCopyWithImpl<$Res>
    implements _$FavoriteMenuItemEntityCopyWith<$Res> {
  __$FavoriteMenuItemEntityCopyWithImpl(this._self, this._then);

  final _FavoriteMenuItemEntity _self;
  final $Res Function(_FavoriteMenuItemEntity) _then;

/// Create a copy of FavoriteMenuItemEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? storeId = null,Object? menuItemId = null,Object? addedAt = null,}) {
  return _then(_FavoriteMenuItemEntity(
storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,menuItemId: null == menuItemId ? _self.menuItemId : menuItemId // ignore: cast_nullable_to_non_nullable
as String,addedAt: null == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on

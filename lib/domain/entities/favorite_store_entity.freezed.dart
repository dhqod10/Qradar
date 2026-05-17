// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'favorite_store_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FavoriteStoreEntity {

 String get storeId; DateTime get addedAt;
/// Create a copy of FavoriteStoreEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FavoriteStoreEntityCopyWith<FavoriteStoreEntity> get copyWith => _$FavoriteStoreEntityCopyWithImpl<FavoriteStoreEntity>(this as FavoriteStoreEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FavoriteStoreEntity&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.addedAt, addedAt) || other.addedAt == addedAt));
}


@override
int get hashCode => Object.hash(runtimeType,storeId,addedAt);

@override
String toString() {
  return 'FavoriteStoreEntity(storeId: $storeId, addedAt: $addedAt)';
}


}

/// @nodoc
abstract mixin class $FavoriteStoreEntityCopyWith<$Res>  {
  factory $FavoriteStoreEntityCopyWith(FavoriteStoreEntity value, $Res Function(FavoriteStoreEntity) _then) = _$FavoriteStoreEntityCopyWithImpl;
@useResult
$Res call({
 String storeId, DateTime addedAt
});




}
/// @nodoc
class _$FavoriteStoreEntityCopyWithImpl<$Res>
    implements $FavoriteStoreEntityCopyWith<$Res> {
  _$FavoriteStoreEntityCopyWithImpl(this._self, this._then);

  final FavoriteStoreEntity _self;
  final $Res Function(FavoriteStoreEntity) _then;

/// Create a copy of FavoriteStoreEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? storeId = null,Object? addedAt = null,}) {
  return _then(_self.copyWith(
storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,addedAt: null == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [FavoriteStoreEntity].
extension FavoriteStoreEntityPatterns on FavoriteStoreEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FavoriteStoreEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FavoriteStoreEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FavoriteStoreEntity value)  $default,){
final _that = this;
switch (_that) {
case _FavoriteStoreEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FavoriteStoreEntity value)?  $default,){
final _that = this;
switch (_that) {
case _FavoriteStoreEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String storeId,  DateTime addedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FavoriteStoreEntity() when $default != null:
return $default(_that.storeId,_that.addedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String storeId,  DateTime addedAt)  $default,) {final _that = this;
switch (_that) {
case _FavoriteStoreEntity():
return $default(_that.storeId,_that.addedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String storeId,  DateTime addedAt)?  $default,) {final _that = this;
switch (_that) {
case _FavoriteStoreEntity() when $default != null:
return $default(_that.storeId,_that.addedAt);case _:
  return null;

}
}

}

/// @nodoc


class _FavoriteStoreEntity implements FavoriteStoreEntity {
  const _FavoriteStoreEntity({required this.storeId, required this.addedAt});
  

@override final  String storeId;
@override final  DateTime addedAt;

/// Create a copy of FavoriteStoreEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FavoriteStoreEntityCopyWith<_FavoriteStoreEntity> get copyWith => __$FavoriteStoreEntityCopyWithImpl<_FavoriteStoreEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FavoriteStoreEntity&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.addedAt, addedAt) || other.addedAt == addedAt));
}


@override
int get hashCode => Object.hash(runtimeType,storeId,addedAt);

@override
String toString() {
  return 'FavoriteStoreEntity(storeId: $storeId, addedAt: $addedAt)';
}


}

/// @nodoc
abstract mixin class _$FavoriteStoreEntityCopyWith<$Res> implements $FavoriteStoreEntityCopyWith<$Res> {
  factory _$FavoriteStoreEntityCopyWith(_FavoriteStoreEntity value, $Res Function(_FavoriteStoreEntity) _then) = __$FavoriteStoreEntityCopyWithImpl;
@override @useResult
$Res call({
 String storeId, DateTime addedAt
});




}
/// @nodoc
class __$FavoriteStoreEntityCopyWithImpl<$Res>
    implements _$FavoriteStoreEntityCopyWith<$Res> {
  __$FavoriteStoreEntityCopyWithImpl(this._self, this._then);

  final _FavoriteStoreEntity _self;
  final $Res Function(_FavoriteStoreEntity) _then;

/// Create a copy of FavoriteStoreEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? storeId = null,Object? addedAt = null,}) {
  return _then(_FavoriteStoreEntity(
storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,addedAt: null == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on

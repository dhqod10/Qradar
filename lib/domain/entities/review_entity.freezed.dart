// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'review_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReviewEntity {

 String get id; String get storeId; String get userId; StoreGrade get grade; String? get comment; DateTime get createdAt;
/// Create a copy of ReviewEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReviewEntityCopyWith<ReviewEntity> get copyWith => _$ReviewEntityCopyWithImpl<ReviewEntity>(this as ReviewEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReviewEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.grade, grade) || other.grade == grade)&&(identical(other.comment, comment) || other.comment == comment)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,storeId,userId,grade,comment,createdAt);

@override
String toString() {
  return 'ReviewEntity(id: $id, storeId: $storeId, userId: $userId, grade: $grade, comment: $comment, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $ReviewEntityCopyWith<$Res>  {
  factory $ReviewEntityCopyWith(ReviewEntity value, $Res Function(ReviewEntity) _then) = _$ReviewEntityCopyWithImpl;
@useResult
$Res call({
 String id, String storeId, String userId, StoreGrade grade, String? comment, DateTime createdAt
});




}
/// @nodoc
class _$ReviewEntityCopyWithImpl<$Res>
    implements $ReviewEntityCopyWith<$Res> {
  _$ReviewEntityCopyWithImpl(this._self, this._then);

  final ReviewEntity _self;
  final $Res Function(ReviewEntity) _then;

/// Create a copy of ReviewEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? storeId = null,Object? userId = null,Object? grade = null,Object? comment = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,grade: null == grade ? _self.grade : grade // ignore: cast_nullable_to_non_nullable
as StoreGrade,comment: freezed == comment ? _self.comment : comment // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [ReviewEntity].
extension ReviewEntityPatterns on ReviewEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReviewEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReviewEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReviewEntity value)  $default,){
final _that = this;
switch (_that) {
case _ReviewEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReviewEntity value)?  $default,){
final _that = this;
switch (_that) {
case _ReviewEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String storeId,  String userId,  StoreGrade grade,  String? comment,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReviewEntity() when $default != null:
return $default(_that.id,_that.storeId,_that.userId,_that.grade,_that.comment,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String storeId,  String userId,  StoreGrade grade,  String? comment,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _ReviewEntity():
return $default(_that.id,_that.storeId,_that.userId,_that.grade,_that.comment,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String storeId,  String userId,  StoreGrade grade,  String? comment,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _ReviewEntity() when $default != null:
return $default(_that.id,_that.storeId,_that.userId,_that.grade,_that.comment,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _ReviewEntity implements ReviewEntity {
  const _ReviewEntity({required this.id, required this.storeId, required this.userId, required this.grade, this.comment, required this.createdAt});
  

@override final  String id;
@override final  String storeId;
@override final  String userId;
@override final  StoreGrade grade;
@override final  String? comment;
@override final  DateTime createdAt;

/// Create a copy of ReviewEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReviewEntityCopyWith<_ReviewEntity> get copyWith => __$ReviewEntityCopyWithImpl<_ReviewEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReviewEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.grade, grade) || other.grade == grade)&&(identical(other.comment, comment) || other.comment == comment)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,storeId,userId,grade,comment,createdAt);

@override
String toString() {
  return 'ReviewEntity(id: $id, storeId: $storeId, userId: $userId, grade: $grade, comment: $comment, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$ReviewEntityCopyWith<$Res> implements $ReviewEntityCopyWith<$Res> {
  factory _$ReviewEntityCopyWith(_ReviewEntity value, $Res Function(_ReviewEntity) _then) = __$ReviewEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String storeId, String userId, StoreGrade grade, String? comment, DateTime createdAt
});




}
/// @nodoc
class __$ReviewEntityCopyWithImpl<$Res>
    implements _$ReviewEntityCopyWith<$Res> {
  __$ReviewEntityCopyWithImpl(this._self, this._then);

  final _ReviewEntity _self;
  final $Res Function(_ReviewEntity) _then;

/// Create a copy of ReviewEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? storeId = null,Object? userId = null,Object? grade = null,Object? comment = freezed,Object? createdAt = null,}) {
  return _then(_ReviewEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,grade: null == grade ? _self.grade : grade // ignore: cast_nullable_to_non_nullable
as StoreGrade,comment: freezed == comment ? _self.comment : comment // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on

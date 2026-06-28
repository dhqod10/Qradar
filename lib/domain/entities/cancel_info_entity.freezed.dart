// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cancel_info_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CancelInfoEntity {

 String get reason; String get approvedBy; DateTime get cancelledAt; String? get cancellationKey;
/// Create a copy of CancelInfoEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CancelInfoEntityCopyWith<CancelInfoEntity> get copyWith => _$CancelInfoEntityCopyWithImpl<CancelInfoEntity>(this as CancelInfoEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CancelInfoEntity&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.approvedBy, approvedBy) || other.approvedBy == approvedBy)&&(identical(other.cancelledAt, cancelledAt) || other.cancelledAt == cancelledAt)&&(identical(other.cancellationKey, cancellationKey) || other.cancellationKey == cancellationKey));
}


@override
int get hashCode => Object.hash(runtimeType,reason,approvedBy,cancelledAt,cancellationKey);

@override
String toString() {
  return 'CancelInfoEntity(reason: $reason, approvedBy: $approvedBy, cancelledAt: $cancelledAt, cancellationKey: $cancellationKey)';
}


}

/// @nodoc
abstract mixin class $CancelInfoEntityCopyWith<$Res>  {
  factory $CancelInfoEntityCopyWith(CancelInfoEntity value, $Res Function(CancelInfoEntity) _then) = _$CancelInfoEntityCopyWithImpl;
@useResult
$Res call({
 String reason, String approvedBy, DateTime cancelledAt, String? cancellationKey
});




}
/// @nodoc
class _$CancelInfoEntityCopyWithImpl<$Res>
    implements $CancelInfoEntityCopyWith<$Res> {
  _$CancelInfoEntityCopyWithImpl(this._self, this._then);

  final CancelInfoEntity _self;
  final $Res Function(CancelInfoEntity) _then;

/// Create a copy of CancelInfoEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? reason = null,Object? approvedBy = null,Object? cancelledAt = null,Object? cancellationKey = freezed,}) {
  return _then(_self.copyWith(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,approvedBy: null == approvedBy ? _self.approvedBy : approvedBy // ignore: cast_nullable_to_non_nullable
as String,cancelledAt: null == cancelledAt ? _self.cancelledAt : cancelledAt // ignore: cast_nullable_to_non_nullable
as DateTime,cancellationKey: freezed == cancellationKey ? _self.cancellationKey : cancellationKey // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CancelInfoEntity].
extension CancelInfoEntityPatterns on CancelInfoEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CancelInfoEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CancelInfoEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CancelInfoEntity value)  $default,){
final _that = this;
switch (_that) {
case _CancelInfoEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CancelInfoEntity value)?  $default,){
final _that = this;
switch (_that) {
case _CancelInfoEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String reason,  String approvedBy,  DateTime cancelledAt,  String? cancellationKey)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CancelInfoEntity() when $default != null:
return $default(_that.reason,_that.approvedBy,_that.cancelledAt,_that.cancellationKey);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String reason,  String approvedBy,  DateTime cancelledAt,  String? cancellationKey)  $default,) {final _that = this;
switch (_that) {
case _CancelInfoEntity():
return $default(_that.reason,_that.approvedBy,_that.cancelledAt,_that.cancellationKey);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String reason,  String approvedBy,  DateTime cancelledAt,  String? cancellationKey)?  $default,) {final _that = this;
switch (_that) {
case _CancelInfoEntity() when $default != null:
return $default(_that.reason,_that.approvedBy,_that.cancelledAt,_that.cancellationKey);case _:
  return null;

}
}

}

/// @nodoc


class _CancelInfoEntity implements CancelInfoEntity {
  const _CancelInfoEntity({required this.reason, required this.approvedBy, required this.cancelledAt, this.cancellationKey});
  

@override final  String reason;
@override final  String approvedBy;
@override final  DateTime cancelledAt;
@override final  String? cancellationKey;

/// Create a copy of CancelInfoEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CancelInfoEntityCopyWith<_CancelInfoEntity> get copyWith => __$CancelInfoEntityCopyWithImpl<_CancelInfoEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CancelInfoEntity&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.approvedBy, approvedBy) || other.approvedBy == approvedBy)&&(identical(other.cancelledAt, cancelledAt) || other.cancelledAt == cancelledAt)&&(identical(other.cancellationKey, cancellationKey) || other.cancellationKey == cancellationKey));
}


@override
int get hashCode => Object.hash(runtimeType,reason,approvedBy,cancelledAt,cancellationKey);

@override
String toString() {
  return 'CancelInfoEntity(reason: $reason, approvedBy: $approvedBy, cancelledAt: $cancelledAt, cancellationKey: $cancellationKey)';
}


}

/// @nodoc
abstract mixin class _$CancelInfoEntityCopyWith<$Res> implements $CancelInfoEntityCopyWith<$Res> {
  factory _$CancelInfoEntityCopyWith(_CancelInfoEntity value, $Res Function(_CancelInfoEntity) _then) = __$CancelInfoEntityCopyWithImpl;
@override @useResult
$Res call({
 String reason, String approvedBy, DateTime cancelledAt, String? cancellationKey
});




}
/// @nodoc
class __$CancelInfoEntityCopyWithImpl<$Res>
    implements _$CancelInfoEntityCopyWith<$Res> {
  __$CancelInfoEntityCopyWithImpl(this._self, this._then);

  final _CancelInfoEntity _self;
  final $Res Function(_CancelInfoEntity) _then;

/// Create a copy of CancelInfoEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? reason = null,Object? approvedBy = null,Object? cancelledAt = null,Object? cancellationKey = freezed,}) {
  return _then(_CancelInfoEntity(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,approvedBy: null == approvedBy ? _self.approvedBy : approvedBy // ignore: cast_nullable_to_non_nullable
as String,cancelledAt: null == cancelledAt ? _self.cancelledAt : cancelledAt // ignore: cast_nullable_to_non_nullable
as DateTime,cancellationKey: freezed == cancellationKey ? _self.cancellationKey : cancellationKey // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on

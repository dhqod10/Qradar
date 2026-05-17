// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'refund_request_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RefundRequestEntity {

 String get reason; DateTime get requestedAt; DateTime? get deniedAt; String? get deniedReason;
/// Create a copy of RefundRequestEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RefundRequestEntityCopyWith<RefundRequestEntity> get copyWith => _$RefundRequestEntityCopyWithImpl<RefundRequestEntity>(this as RefundRequestEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RefundRequestEntity&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.deniedAt, deniedAt) || other.deniedAt == deniedAt)&&(identical(other.deniedReason, deniedReason) || other.deniedReason == deniedReason));
}


@override
int get hashCode => Object.hash(runtimeType,reason,requestedAt,deniedAt,deniedReason);

@override
String toString() {
  return 'RefundRequestEntity(reason: $reason, requestedAt: $requestedAt, deniedAt: $deniedAt, deniedReason: $deniedReason)';
}


}

/// @nodoc
abstract mixin class $RefundRequestEntityCopyWith<$Res>  {
  factory $RefundRequestEntityCopyWith(RefundRequestEntity value, $Res Function(RefundRequestEntity) _then) = _$RefundRequestEntityCopyWithImpl;
@useResult
$Res call({
 String reason, DateTime requestedAt, DateTime? deniedAt, String? deniedReason
});




}
/// @nodoc
class _$RefundRequestEntityCopyWithImpl<$Res>
    implements $RefundRequestEntityCopyWith<$Res> {
  _$RefundRequestEntityCopyWithImpl(this._self, this._then);

  final RefundRequestEntity _self;
  final $Res Function(RefundRequestEntity) _then;

/// Create a copy of RefundRequestEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? reason = null,Object? requestedAt = null,Object? deniedAt = freezed,Object? deniedReason = freezed,}) {
  return _then(_self.copyWith(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,requestedAt: null == requestedAt ? _self.requestedAt : requestedAt // ignore: cast_nullable_to_non_nullable
as DateTime,deniedAt: freezed == deniedAt ? _self.deniedAt : deniedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,deniedReason: freezed == deniedReason ? _self.deniedReason : deniedReason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RefundRequestEntity].
extension RefundRequestEntityPatterns on RefundRequestEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RefundRequestEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RefundRequestEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RefundRequestEntity value)  $default,){
final _that = this;
switch (_that) {
case _RefundRequestEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RefundRequestEntity value)?  $default,){
final _that = this;
switch (_that) {
case _RefundRequestEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String reason,  DateTime requestedAt,  DateTime? deniedAt,  String? deniedReason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RefundRequestEntity() when $default != null:
return $default(_that.reason,_that.requestedAt,_that.deniedAt,_that.deniedReason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String reason,  DateTime requestedAt,  DateTime? deniedAt,  String? deniedReason)  $default,) {final _that = this;
switch (_that) {
case _RefundRequestEntity():
return $default(_that.reason,_that.requestedAt,_that.deniedAt,_that.deniedReason);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String reason,  DateTime requestedAt,  DateTime? deniedAt,  String? deniedReason)?  $default,) {final _that = this;
switch (_that) {
case _RefundRequestEntity() when $default != null:
return $default(_that.reason,_that.requestedAt,_that.deniedAt,_that.deniedReason);case _:
  return null;

}
}

}

/// @nodoc


class _RefundRequestEntity implements RefundRequestEntity {
  const _RefundRequestEntity({required this.reason, required this.requestedAt, this.deniedAt, this.deniedReason});
  

@override final  String reason;
@override final  DateTime requestedAt;
@override final  DateTime? deniedAt;
@override final  String? deniedReason;

/// Create a copy of RefundRequestEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RefundRequestEntityCopyWith<_RefundRequestEntity> get copyWith => __$RefundRequestEntityCopyWithImpl<_RefundRequestEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RefundRequestEntity&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.deniedAt, deniedAt) || other.deniedAt == deniedAt)&&(identical(other.deniedReason, deniedReason) || other.deniedReason == deniedReason));
}


@override
int get hashCode => Object.hash(runtimeType,reason,requestedAt,deniedAt,deniedReason);

@override
String toString() {
  return 'RefundRequestEntity(reason: $reason, requestedAt: $requestedAt, deniedAt: $deniedAt, deniedReason: $deniedReason)';
}


}

/// @nodoc
abstract mixin class _$RefundRequestEntityCopyWith<$Res> implements $RefundRequestEntityCopyWith<$Res> {
  factory _$RefundRequestEntityCopyWith(_RefundRequestEntity value, $Res Function(_RefundRequestEntity) _then) = __$RefundRequestEntityCopyWithImpl;
@override @useResult
$Res call({
 String reason, DateTime requestedAt, DateTime? deniedAt, String? deniedReason
});




}
/// @nodoc
class __$RefundRequestEntityCopyWithImpl<$Res>
    implements _$RefundRequestEntityCopyWith<$Res> {
  __$RefundRequestEntityCopyWithImpl(this._self, this._then);

  final _RefundRequestEntity _self;
  final $Res Function(_RefundRequestEntity) _then;

/// Create a copy of RefundRequestEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? reason = null,Object? requestedAt = null,Object? deniedAt = freezed,Object? deniedReason = freezed,}) {
  return _then(_RefundRequestEntity(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,requestedAt: null == requestedAt ? _self.requestedAt : requestedAt // ignore: cast_nullable_to_non_nullable
as DateTime,deniedAt: freezed == deniedAt ? _self.deniedAt : deniedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,deniedReason: freezed == deniedReason ? _self.deniedReason : deniedReason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on

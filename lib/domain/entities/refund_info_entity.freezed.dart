// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'refund_info_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RefundInfoEntity {

 String get cancellationKey; String get reason;/// 'customer' | 'owner' | 'store_reject'
 String get approvedBy; DateTime get processedAt; int get amount;
/// Create a copy of RefundInfoEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RefundInfoEntityCopyWith<RefundInfoEntity> get copyWith => _$RefundInfoEntityCopyWithImpl<RefundInfoEntity>(this as RefundInfoEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RefundInfoEntity&&(identical(other.cancellationKey, cancellationKey) || other.cancellationKey == cancellationKey)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.approvedBy, approvedBy) || other.approvedBy == approvedBy)&&(identical(other.processedAt, processedAt) || other.processedAt == processedAt)&&(identical(other.amount, amount) || other.amount == amount));
}


@override
int get hashCode => Object.hash(runtimeType,cancellationKey,reason,approvedBy,processedAt,amount);

@override
String toString() {
  return 'RefundInfoEntity(cancellationKey: $cancellationKey, reason: $reason, approvedBy: $approvedBy, processedAt: $processedAt, amount: $amount)';
}


}

/// @nodoc
abstract mixin class $RefundInfoEntityCopyWith<$Res>  {
  factory $RefundInfoEntityCopyWith(RefundInfoEntity value, $Res Function(RefundInfoEntity) _then) = _$RefundInfoEntityCopyWithImpl;
@useResult
$Res call({
 String cancellationKey, String reason, String approvedBy, DateTime processedAt, int amount
});




}
/// @nodoc
class _$RefundInfoEntityCopyWithImpl<$Res>
    implements $RefundInfoEntityCopyWith<$Res> {
  _$RefundInfoEntityCopyWithImpl(this._self, this._then);

  final RefundInfoEntity _self;
  final $Res Function(RefundInfoEntity) _then;

/// Create a copy of RefundInfoEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? cancellationKey = null,Object? reason = null,Object? approvedBy = null,Object? processedAt = null,Object? amount = null,}) {
  return _then(_self.copyWith(
cancellationKey: null == cancellationKey ? _self.cancellationKey : cancellationKey // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,approvedBy: null == approvedBy ? _self.approvedBy : approvedBy // ignore: cast_nullable_to_non_nullable
as String,processedAt: null == processedAt ? _self.processedAt : processedAt // ignore: cast_nullable_to_non_nullable
as DateTime,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [RefundInfoEntity].
extension RefundInfoEntityPatterns on RefundInfoEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RefundInfoEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RefundInfoEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RefundInfoEntity value)  $default,){
final _that = this;
switch (_that) {
case _RefundInfoEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RefundInfoEntity value)?  $default,){
final _that = this;
switch (_that) {
case _RefundInfoEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String cancellationKey,  String reason,  String approvedBy,  DateTime processedAt,  int amount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RefundInfoEntity() when $default != null:
return $default(_that.cancellationKey,_that.reason,_that.approvedBy,_that.processedAt,_that.amount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String cancellationKey,  String reason,  String approvedBy,  DateTime processedAt,  int amount)  $default,) {final _that = this;
switch (_that) {
case _RefundInfoEntity():
return $default(_that.cancellationKey,_that.reason,_that.approvedBy,_that.processedAt,_that.amount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String cancellationKey,  String reason,  String approvedBy,  DateTime processedAt,  int amount)?  $default,) {final _that = this;
switch (_that) {
case _RefundInfoEntity() when $default != null:
return $default(_that.cancellationKey,_that.reason,_that.approvedBy,_that.processedAt,_that.amount);case _:
  return null;

}
}

}

/// @nodoc


class _RefundInfoEntity implements RefundInfoEntity {
  const _RefundInfoEntity({required this.cancellationKey, required this.reason, required this.approvedBy, required this.processedAt, required this.amount});
  

@override final  String cancellationKey;
@override final  String reason;
/// 'customer' | 'owner' | 'store_reject'
@override final  String approvedBy;
@override final  DateTime processedAt;
@override final  int amount;

/// Create a copy of RefundInfoEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RefundInfoEntityCopyWith<_RefundInfoEntity> get copyWith => __$RefundInfoEntityCopyWithImpl<_RefundInfoEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RefundInfoEntity&&(identical(other.cancellationKey, cancellationKey) || other.cancellationKey == cancellationKey)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.approvedBy, approvedBy) || other.approvedBy == approvedBy)&&(identical(other.processedAt, processedAt) || other.processedAt == processedAt)&&(identical(other.amount, amount) || other.amount == amount));
}


@override
int get hashCode => Object.hash(runtimeType,cancellationKey,reason,approvedBy,processedAt,amount);

@override
String toString() {
  return 'RefundInfoEntity(cancellationKey: $cancellationKey, reason: $reason, approvedBy: $approvedBy, processedAt: $processedAt, amount: $amount)';
}


}

/// @nodoc
abstract mixin class _$RefundInfoEntityCopyWith<$Res> implements $RefundInfoEntityCopyWith<$Res> {
  factory _$RefundInfoEntityCopyWith(_RefundInfoEntity value, $Res Function(_RefundInfoEntity) _then) = __$RefundInfoEntityCopyWithImpl;
@override @useResult
$Res call({
 String cancellationKey, String reason, String approvedBy, DateTime processedAt, int amount
});




}
/// @nodoc
class __$RefundInfoEntityCopyWithImpl<$Res>
    implements _$RefundInfoEntityCopyWith<$Res> {
  __$RefundInfoEntityCopyWithImpl(this._self, this._then);

  final _RefundInfoEntity _self;
  final $Res Function(_RefundInfoEntity) _then;

/// Create a copy of RefundInfoEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? cancellationKey = null,Object? reason = null,Object? approvedBy = null,Object? processedAt = null,Object? amount = null,}) {
  return _then(_RefundInfoEntity(
cancellationKey: null == cancellationKey ? _self.cancellationKey : cancellationKey // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,approvedBy: null == approvedBy ? _self.approvedBy : approvedBy // ignore: cast_nullable_to_non_nullable
as String,processedAt: null == processedAt ? _self.processedAt : processedAt // ignore: cast_nullable_to_non_nullable
as DateTime,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on

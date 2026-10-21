// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_settings_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$NotificationSettingsEntity {

 bool get orderProgress; bool get pickupComplete; bool get newOrder; bool get refundRequest;
/// Create a copy of NotificationSettingsEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationSettingsEntityCopyWith<NotificationSettingsEntity> get copyWith => _$NotificationSettingsEntityCopyWithImpl<NotificationSettingsEntity>(this as NotificationSettingsEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationSettingsEntity&&(identical(other.orderProgress, orderProgress) || other.orderProgress == orderProgress)&&(identical(other.pickupComplete, pickupComplete) || other.pickupComplete == pickupComplete)&&(identical(other.newOrder, newOrder) || other.newOrder == newOrder)&&(identical(other.refundRequest, refundRequest) || other.refundRequest == refundRequest));
}


@override
int get hashCode => Object.hash(runtimeType,orderProgress,pickupComplete,newOrder,refundRequest);

@override
String toString() {
  return 'NotificationSettingsEntity(orderProgress: $orderProgress, pickupComplete: $pickupComplete, newOrder: $newOrder, refundRequest: $refundRequest)';
}


}

/// @nodoc
abstract mixin class $NotificationSettingsEntityCopyWith<$Res>  {
  factory $NotificationSettingsEntityCopyWith(NotificationSettingsEntity value, $Res Function(NotificationSettingsEntity) _then) = _$NotificationSettingsEntityCopyWithImpl;
@useResult
$Res call({
 bool orderProgress, bool pickupComplete, bool newOrder, bool refundRequest
});




}
/// @nodoc
class _$NotificationSettingsEntityCopyWithImpl<$Res>
    implements $NotificationSettingsEntityCopyWith<$Res> {
  _$NotificationSettingsEntityCopyWithImpl(this._self, this._then);

  final NotificationSettingsEntity _self;
  final $Res Function(NotificationSettingsEntity) _then;

/// Create a copy of NotificationSettingsEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? orderProgress = null,Object? pickupComplete = null,Object? newOrder = null,Object? refundRequest = null,}) {
  return _then(_self.copyWith(
orderProgress: null == orderProgress ? _self.orderProgress : orderProgress // ignore: cast_nullable_to_non_nullable
as bool,pickupComplete: null == pickupComplete ? _self.pickupComplete : pickupComplete // ignore: cast_nullable_to_non_nullable
as bool,newOrder: null == newOrder ? _self.newOrder : newOrder // ignore: cast_nullable_to_non_nullable
as bool,refundRequest: null == refundRequest ? _self.refundRequest : refundRequest // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationSettingsEntity].
extension NotificationSettingsEntityPatterns on NotificationSettingsEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationSettingsEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationSettingsEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationSettingsEntity value)  $default,){
final _that = this;
switch (_that) {
case _NotificationSettingsEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationSettingsEntity value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationSettingsEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool orderProgress,  bool pickupComplete,  bool newOrder,  bool refundRequest)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationSettingsEntity() when $default != null:
return $default(_that.orderProgress,_that.pickupComplete,_that.newOrder,_that.refundRequest);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool orderProgress,  bool pickupComplete,  bool newOrder,  bool refundRequest)  $default,) {final _that = this;
switch (_that) {
case _NotificationSettingsEntity():
return $default(_that.orderProgress,_that.pickupComplete,_that.newOrder,_that.refundRequest);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool orderProgress,  bool pickupComplete,  bool newOrder,  bool refundRequest)?  $default,) {final _that = this;
switch (_that) {
case _NotificationSettingsEntity() when $default != null:
return $default(_that.orderProgress,_that.pickupComplete,_that.newOrder,_that.refundRequest);case _:
  return null;

}
}

}

/// @nodoc


class _NotificationSettingsEntity extends NotificationSettingsEntity {
  const _NotificationSettingsEntity({this.orderProgress = true, this.pickupComplete = false, this.newOrder = true, this.refundRequest = true}): super._();
  

@override@JsonKey() final  bool orderProgress;
@override@JsonKey() final  bool pickupComplete;
@override@JsonKey() final  bool newOrder;
@override@JsonKey() final  bool refundRequest;

/// Create a copy of NotificationSettingsEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationSettingsEntityCopyWith<_NotificationSettingsEntity> get copyWith => __$NotificationSettingsEntityCopyWithImpl<_NotificationSettingsEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationSettingsEntity&&(identical(other.orderProgress, orderProgress) || other.orderProgress == orderProgress)&&(identical(other.pickupComplete, pickupComplete) || other.pickupComplete == pickupComplete)&&(identical(other.newOrder, newOrder) || other.newOrder == newOrder)&&(identical(other.refundRequest, refundRequest) || other.refundRequest == refundRequest));
}


@override
int get hashCode => Object.hash(runtimeType,orderProgress,pickupComplete,newOrder,refundRequest);

@override
String toString() {
  return 'NotificationSettingsEntity(orderProgress: $orderProgress, pickupComplete: $pickupComplete, newOrder: $newOrder, refundRequest: $refundRequest)';
}


}

/// @nodoc
abstract mixin class _$NotificationSettingsEntityCopyWith<$Res> implements $NotificationSettingsEntityCopyWith<$Res> {
  factory _$NotificationSettingsEntityCopyWith(_NotificationSettingsEntity value, $Res Function(_NotificationSettingsEntity) _then) = __$NotificationSettingsEntityCopyWithImpl;
@override @useResult
$Res call({
 bool orderProgress, bool pickupComplete, bool newOrder, bool refundRequest
});




}
/// @nodoc
class __$NotificationSettingsEntityCopyWithImpl<$Res>
    implements _$NotificationSettingsEntityCopyWith<$Res> {
  __$NotificationSettingsEntityCopyWithImpl(this._self, this._then);

  final _NotificationSettingsEntity _self;
  final $Res Function(_NotificationSettingsEntity) _then;

/// Create a copy of NotificationSettingsEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? orderProgress = null,Object? pickupComplete = null,Object? newOrder = null,Object? refundRequest = null,}) {
  return _then(_NotificationSettingsEntity(
orderProgress: null == orderProgress ? _self.orderProgress : orderProgress // ignore: cast_nullable_to_non_nullable
as bool,pickupComplete: null == pickupComplete ? _self.pickupComplete : pickupComplete // ignore: cast_nullable_to_non_nullable
as bool,newOrder: null == newOrder ? _self.newOrder : newOrder // ignore: cast_nullable_to_non_nullable
as bool,refundRequest: null == refundRequest ? _self.refundRequest : refundRequest // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on

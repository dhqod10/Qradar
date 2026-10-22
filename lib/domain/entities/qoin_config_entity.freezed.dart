// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'qoin_config_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$QoinConfigEntity {

/// 적립 비율 (0.03 = 3%). 문서 값이 number 가 아니거나 범위 밖이면 null (CF 도 적립하지 않음).
 double? get accrualRate;/// kill switch. 부재 → false (fail-closed).
 bool get enabled;
/// Create a copy of QoinConfigEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QoinConfigEntityCopyWith<QoinConfigEntity> get copyWith => _$QoinConfigEntityCopyWithImpl<QoinConfigEntity>(this as QoinConfigEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QoinConfigEntity&&(identical(other.accrualRate, accrualRate) || other.accrualRate == accrualRate)&&(identical(other.enabled, enabled) || other.enabled == enabled));
}


@override
int get hashCode => Object.hash(runtimeType,accrualRate,enabled);

@override
String toString() {
  return 'QoinConfigEntity(accrualRate: $accrualRate, enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class $QoinConfigEntityCopyWith<$Res>  {
  factory $QoinConfigEntityCopyWith(QoinConfigEntity value, $Res Function(QoinConfigEntity) _then) = _$QoinConfigEntityCopyWithImpl;
@useResult
$Res call({
 double? accrualRate, bool enabled
});




}
/// @nodoc
class _$QoinConfigEntityCopyWithImpl<$Res>
    implements $QoinConfigEntityCopyWith<$Res> {
  _$QoinConfigEntityCopyWithImpl(this._self, this._then);

  final QoinConfigEntity _self;
  final $Res Function(QoinConfigEntity) _then;

/// Create a copy of QoinConfigEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? accrualRate = freezed,Object? enabled = null,}) {
  return _then(_self.copyWith(
accrualRate: freezed == accrualRate ? _self.accrualRate : accrualRate // ignore: cast_nullable_to_non_nullable
as double?,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [QoinConfigEntity].
extension QoinConfigEntityPatterns on QoinConfigEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QoinConfigEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QoinConfigEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QoinConfigEntity value)  $default,){
final _that = this;
switch (_that) {
case _QoinConfigEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QoinConfigEntity value)?  $default,){
final _that = this;
switch (_that) {
case _QoinConfigEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double? accrualRate,  bool enabled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QoinConfigEntity() when $default != null:
return $default(_that.accrualRate,_that.enabled);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double? accrualRate,  bool enabled)  $default,) {final _that = this;
switch (_that) {
case _QoinConfigEntity():
return $default(_that.accrualRate,_that.enabled);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double? accrualRate,  bool enabled)?  $default,) {final _that = this;
switch (_that) {
case _QoinConfigEntity() when $default != null:
return $default(_that.accrualRate,_that.enabled);case _:
  return null;

}
}

}

/// @nodoc


class _QoinConfigEntity implements QoinConfigEntity {
  const _QoinConfigEntity({this.accrualRate, this.enabled = false});
  

/// 적립 비율 (0.03 = 3%). 문서 값이 number 가 아니거나 범위 밖이면 null (CF 도 적립하지 않음).
@override final  double? accrualRate;
/// kill switch. 부재 → false (fail-closed).
@override@JsonKey() final  bool enabled;

/// Create a copy of QoinConfigEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QoinConfigEntityCopyWith<_QoinConfigEntity> get copyWith => __$QoinConfigEntityCopyWithImpl<_QoinConfigEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QoinConfigEntity&&(identical(other.accrualRate, accrualRate) || other.accrualRate == accrualRate)&&(identical(other.enabled, enabled) || other.enabled == enabled));
}


@override
int get hashCode => Object.hash(runtimeType,accrualRate,enabled);

@override
String toString() {
  return 'QoinConfigEntity(accrualRate: $accrualRate, enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class _$QoinConfigEntityCopyWith<$Res> implements $QoinConfigEntityCopyWith<$Res> {
  factory _$QoinConfigEntityCopyWith(_QoinConfigEntity value, $Res Function(_QoinConfigEntity) _then) = __$QoinConfigEntityCopyWithImpl;
@override @useResult
$Res call({
 double? accrualRate, bool enabled
});




}
/// @nodoc
class __$QoinConfigEntityCopyWithImpl<$Res>
    implements _$QoinConfigEntityCopyWith<$Res> {
  __$QoinConfigEntityCopyWithImpl(this._self, this._then);

  final _QoinConfigEntity _self;
  final $Res Function(_QoinConfigEntity) _then;

/// Create a copy of QoinConfigEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? accrualRate = freezed,Object? enabled = null,}) {
  return _then(_QoinConfigEntity(
accrualRate: freezed == accrualRate ? _self.accrualRate : accrualRate // ignore: cast_nullable_to_non_nullable
as double?,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on

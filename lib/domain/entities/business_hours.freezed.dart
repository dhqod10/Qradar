// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'business_hours.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BusinessHours {

/// "HH:mm" 24시 포맷 (e.g. "09:00")
 String get openTime; String get closeTime; List<int> get closedDays;
/// Create a copy of BusinessHours
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BusinessHoursCopyWith<BusinessHours> get copyWith => _$BusinessHoursCopyWithImpl<BusinessHours>(this as BusinessHours, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BusinessHours&&(identical(other.openTime, openTime) || other.openTime == openTime)&&(identical(other.closeTime, closeTime) || other.closeTime == closeTime)&&const DeepCollectionEquality().equals(other.closedDays, closedDays));
}


@override
int get hashCode => Object.hash(runtimeType,openTime,closeTime,const DeepCollectionEquality().hash(closedDays));

@override
String toString() {
  return 'BusinessHours(openTime: $openTime, closeTime: $closeTime, closedDays: $closedDays)';
}


}

/// @nodoc
abstract mixin class $BusinessHoursCopyWith<$Res>  {
  factory $BusinessHoursCopyWith(BusinessHours value, $Res Function(BusinessHours) _then) = _$BusinessHoursCopyWithImpl;
@useResult
$Res call({
 String openTime, String closeTime, List<int> closedDays
});




}
/// @nodoc
class _$BusinessHoursCopyWithImpl<$Res>
    implements $BusinessHoursCopyWith<$Res> {
  _$BusinessHoursCopyWithImpl(this._self, this._then);

  final BusinessHours _self;
  final $Res Function(BusinessHours) _then;

/// Create a copy of BusinessHours
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? openTime = null,Object? closeTime = null,Object? closedDays = null,}) {
  return _then(_self.copyWith(
openTime: null == openTime ? _self.openTime : openTime // ignore: cast_nullable_to_non_nullable
as String,closeTime: null == closeTime ? _self.closeTime : closeTime // ignore: cast_nullable_to_non_nullable
as String,closedDays: null == closedDays ? _self.closedDays : closedDays // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}

}


/// Adds pattern-matching-related methods to [BusinessHours].
extension BusinessHoursPatterns on BusinessHours {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BusinessHours value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BusinessHours() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BusinessHours value)  $default,){
final _that = this;
switch (_that) {
case _BusinessHours():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BusinessHours value)?  $default,){
final _that = this;
switch (_that) {
case _BusinessHours() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String openTime,  String closeTime,  List<int> closedDays)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BusinessHours() when $default != null:
return $default(_that.openTime,_that.closeTime,_that.closedDays);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String openTime,  String closeTime,  List<int> closedDays)  $default,) {final _that = this;
switch (_that) {
case _BusinessHours():
return $default(_that.openTime,_that.closeTime,_that.closedDays);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String openTime,  String closeTime,  List<int> closedDays)?  $default,) {final _that = this;
switch (_that) {
case _BusinessHours() when $default != null:
return $default(_that.openTime,_that.closeTime,_that.closedDays);case _:
  return null;

}
}

}

/// @nodoc


class _BusinessHours implements BusinessHours {
  const _BusinessHours({required this.openTime, required this.closeTime, final  List<int> closedDays = const <int>[]}): _closedDays = closedDays;
  

/// "HH:mm" 24시 포맷 (e.g. "09:00")
@override final  String openTime;
@override final  String closeTime;
 final  List<int> _closedDays;
@override@JsonKey() List<int> get closedDays {
  if (_closedDays is EqualUnmodifiableListView) return _closedDays;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_closedDays);
}


/// Create a copy of BusinessHours
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BusinessHoursCopyWith<_BusinessHours> get copyWith => __$BusinessHoursCopyWithImpl<_BusinessHours>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BusinessHours&&(identical(other.openTime, openTime) || other.openTime == openTime)&&(identical(other.closeTime, closeTime) || other.closeTime == closeTime)&&const DeepCollectionEquality().equals(other._closedDays, _closedDays));
}


@override
int get hashCode => Object.hash(runtimeType,openTime,closeTime,const DeepCollectionEquality().hash(_closedDays));

@override
String toString() {
  return 'BusinessHours(openTime: $openTime, closeTime: $closeTime, closedDays: $closedDays)';
}


}

/// @nodoc
abstract mixin class _$BusinessHoursCopyWith<$Res> implements $BusinessHoursCopyWith<$Res> {
  factory _$BusinessHoursCopyWith(_BusinessHours value, $Res Function(_BusinessHours) _then) = __$BusinessHoursCopyWithImpl;
@override @useResult
$Res call({
 String openTime, String closeTime, List<int> closedDays
});




}
/// @nodoc
class __$BusinessHoursCopyWithImpl<$Res>
    implements _$BusinessHoursCopyWith<$Res> {
  __$BusinessHoursCopyWithImpl(this._self, this._then);

  final _BusinessHours _self;
  final $Res Function(_BusinessHours) _then;

/// Create a copy of BusinessHours
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? openTime = null,Object? closeTime = null,Object? closedDays = null,}) {
  return _then(_BusinessHours(
openTime: null == openTime ? _self.openTime : openTime // ignore: cast_nullable_to_non_nullable
as String,closeTime: null == closeTime ? _self.closeTime : closeTime // ignore: cast_nullable_to_non_nullable
as String,closedDays: null == closedDays ? _self._closedDays : closedDays // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}


}

// dart format on

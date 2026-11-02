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
mixin _$BusinessDayHours {

 String get open; String get close;
/// Create a copy of BusinessDayHours
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BusinessDayHoursCopyWith<BusinessDayHours> get copyWith => _$BusinessDayHoursCopyWithImpl<BusinessDayHours>(this as BusinessDayHours, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BusinessDayHours&&(identical(other.open, open) || other.open == open)&&(identical(other.close, close) || other.close == close));
}


@override
int get hashCode => Object.hash(runtimeType,open,close);

@override
String toString() {
  return 'BusinessDayHours(open: $open, close: $close)';
}


}

/// @nodoc
abstract mixin class $BusinessDayHoursCopyWith<$Res>  {
  factory $BusinessDayHoursCopyWith(BusinessDayHours value, $Res Function(BusinessDayHours) _then) = _$BusinessDayHoursCopyWithImpl;
@useResult
$Res call({
 String open, String close
});




}
/// @nodoc
class _$BusinessDayHoursCopyWithImpl<$Res>
    implements $BusinessDayHoursCopyWith<$Res> {
  _$BusinessDayHoursCopyWithImpl(this._self, this._then);

  final BusinessDayHours _self;
  final $Res Function(BusinessDayHours) _then;

/// Create a copy of BusinessDayHours
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? open = null,Object? close = null,}) {
  return _then(_self.copyWith(
open: null == open ? _self.open : open // ignore: cast_nullable_to_non_nullable
as String,close: null == close ? _self.close : close // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [BusinessDayHours].
extension BusinessDayHoursPatterns on BusinessDayHours {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BusinessDayHours value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BusinessDayHours() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BusinessDayHours value)  $default,){
final _that = this;
switch (_that) {
case _BusinessDayHours():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BusinessDayHours value)?  $default,){
final _that = this;
switch (_that) {
case _BusinessDayHours() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String open,  String close)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BusinessDayHours() when $default != null:
return $default(_that.open,_that.close);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String open,  String close)  $default,) {final _that = this;
switch (_that) {
case _BusinessDayHours():
return $default(_that.open,_that.close);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String open,  String close)?  $default,) {final _that = this;
switch (_that) {
case _BusinessDayHours() when $default != null:
return $default(_that.open,_that.close);case _:
  return null;

}
}

}

/// @nodoc


class _BusinessDayHours implements BusinessDayHours {
  const _BusinessDayHours({required this.open, required this.close});
  

@override final  String open;
@override final  String close;

/// Create a copy of BusinessDayHours
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BusinessDayHoursCopyWith<_BusinessDayHours> get copyWith => __$BusinessDayHoursCopyWithImpl<_BusinessDayHours>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BusinessDayHours&&(identical(other.open, open) || other.open == open)&&(identical(other.close, close) || other.close == close));
}


@override
int get hashCode => Object.hash(runtimeType,open,close);

@override
String toString() {
  return 'BusinessDayHours(open: $open, close: $close)';
}


}

/// @nodoc
abstract mixin class _$BusinessDayHoursCopyWith<$Res> implements $BusinessDayHoursCopyWith<$Res> {
  factory _$BusinessDayHoursCopyWith(_BusinessDayHours value, $Res Function(_BusinessDayHours) _then) = __$BusinessDayHoursCopyWithImpl;
@override @useResult
$Res call({
 String open, String close
});




}
/// @nodoc
class __$BusinessDayHoursCopyWithImpl<$Res>
    implements _$BusinessDayHoursCopyWith<$Res> {
  __$BusinessDayHoursCopyWithImpl(this._self, this._then);

  final _BusinessDayHours _self;
  final $Res Function(_BusinessDayHours) _then;

/// Create a copy of BusinessDayHours
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? open = null,Object? close = null,}) {
  return _then(_BusinessDayHours(
open: null == open ? _self.open : open // ignore: cast_nullable_to_non_nullable
as String,close: null == close ? _self.close : close // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$BusinessHours {

 Map<int, BusinessDayHours> get weeklyHours;
/// Create a copy of BusinessHours
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BusinessHoursCopyWith<BusinessHours> get copyWith => _$BusinessHoursCopyWithImpl<BusinessHours>(this as BusinessHours, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BusinessHours&&const DeepCollectionEquality().equals(other.weeklyHours, weeklyHours));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(weeklyHours));

@override
String toString() {
  return 'BusinessHours(weeklyHours: $weeklyHours)';
}


}

/// @nodoc
abstract mixin class $BusinessHoursCopyWith<$Res>  {
  factory $BusinessHoursCopyWith(BusinessHours value, $Res Function(BusinessHours) _then) = _$BusinessHoursCopyWithImpl;
@useResult
$Res call({
 Map<int, BusinessDayHours> weeklyHours
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
@pragma('vm:prefer-inline') @override $Res call({Object? weeklyHours = null,}) {
  return _then(_self.copyWith(
weeklyHours: null == weeklyHours ? _self.weeklyHours : weeklyHours // ignore: cast_nullable_to_non_nullable
as Map<int, BusinessDayHours>,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<int, BusinessDayHours> weeklyHours)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BusinessHours() when $default != null:
return $default(_that.weeklyHours);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<int, BusinessDayHours> weeklyHours)  $default,) {final _that = this;
switch (_that) {
case _BusinessHours():
return $default(_that.weeklyHours);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<int, BusinessDayHours> weeklyHours)?  $default,) {final _that = this;
switch (_that) {
case _BusinessHours() when $default != null:
return $default(_that.weeklyHours);case _:
  return null;

}
}

}

/// @nodoc


class _BusinessHours extends BusinessHours {
  const _BusinessHours({final  Map<int, BusinessDayHours> weeklyHours = const <int, BusinessDayHours>{}}): _weeklyHours = weeklyHours,super._();
  

 final  Map<int, BusinessDayHours> _weeklyHours;
@override@JsonKey() Map<int, BusinessDayHours> get weeklyHours {
  if (_weeklyHours is EqualUnmodifiableMapView) return _weeklyHours;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_weeklyHours);
}


/// Create a copy of BusinessHours
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BusinessHoursCopyWith<_BusinessHours> get copyWith => __$BusinessHoursCopyWithImpl<_BusinessHours>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BusinessHours&&const DeepCollectionEquality().equals(other._weeklyHours, _weeklyHours));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_weeklyHours));

@override
String toString() {
  return 'BusinessHours(weeklyHours: $weeklyHours)';
}


}

/// @nodoc
abstract mixin class _$BusinessHoursCopyWith<$Res> implements $BusinessHoursCopyWith<$Res> {
  factory _$BusinessHoursCopyWith(_BusinessHours value, $Res Function(_BusinessHours) _then) = __$BusinessHoursCopyWithImpl;
@override @useResult
$Res call({
 Map<int, BusinessDayHours> weeklyHours
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
@override @pragma('vm:prefer-inline') $Res call({Object? weeklyHours = null,}) {
  return _then(_BusinessHours(
weeklyHours: null == weeklyHours ? _self._weeklyHours : weeklyHours // ignore: cast_nullable_to_non_nullable
as Map<int, BusinessDayHours>,
  ));
}


}

// dart format on

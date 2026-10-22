// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sales_period.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SalesPeriod {

 SalesPeriodType get type; DateTime get start; DateTime get endExclusive;
/// Create a copy of SalesPeriod
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SalesPeriodCopyWith<SalesPeriod> get copyWith => _$SalesPeriodCopyWithImpl<SalesPeriod>(this as SalesPeriod, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SalesPeriod&&(identical(other.type, type) || other.type == type)&&(identical(other.start, start) || other.start == start)&&(identical(other.endExclusive, endExclusive) || other.endExclusive == endExclusive));
}


@override
int get hashCode => Object.hash(runtimeType,type,start,endExclusive);

@override
String toString() {
  return 'SalesPeriod(type: $type, start: $start, endExclusive: $endExclusive)';
}


}

/// @nodoc
abstract mixin class $SalesPeriodCopyWith<$Res>  {
  factory $SalesPeriodCopyWith(SalesPeriod value, $Res Function(SalesPeriod) _then) = _$SalesPeriodCopyWithImpl;
@useResult
$Res call({
 SalesPeriodType type, DateTime start, DateTime endExclusive
});




}
/// @nodoc
class _$SalesPeriodCopyWithImpl<$Res>
    implements $SalesPeriodCopyWith<$Res> {
  _$SalesPeriodCopyWithImpl(this._self, this._then);

  final SalesPeriod _self;
  final $Res Function(SalesPeriod) _then;

/// Create a copy of SalesPeriod
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? start = null,Object? endExclusive = null,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as SalesPeriodType,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as DateTime,endExclusive: null == endExclusive ? _self.endExclusive : endExclusive // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [SalesPeriod].
extension SalesPeriodPatterns on SalesPeriod {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SalesPeriod value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SalesPeriod() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SalesPeriod value)  $default,){
final _that = this;
switch (_that) {
case _SalesPeriod():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SalesPeriod value)?  $default,){
final _that = this;
switch (_that) {
case _SalesPeriod() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SalesPeriodType type,  DateTime start,  DateTime endExclusive)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SalesPeriod() when $default != null:
return $default(_that.type,_that.start,_that.endExclusive);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SalesPeriodType type,  DateTime start,  DateTime endExclusive)  $default,) {final _that = this;
switch (_that) {
case _SalesPeriod():
return $default(_that.type,_that.start,_that.endExclusive);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SalesPeriodType type,  DateTime start,  DateTime endExclusive)?  $default,) {final _that = this;
switch (_that) {
case _SalesPeriod() when $default != null:
return $default(_that.type,_that.start,_that.endExclusive);case _:
  return null;

}
}

}

/// @nodoc


class _SalesPeriod extends SalesPeriod {
  const _SalesPeriod({required this.type, required this.start, required this.endExclusive}): super._();
  

@override final  SalesPeriodType type;
@override final  DateTime start;
@override final  DateTime endExclusive;

/// Create a copy of SalesPeriod
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SalesPeriodCopyWith<_SalesPeriod> get copyWith => __$SalesPeriodCopyWithImpl<_SalesPeriod>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SalesPeriod&&(identical(other.type, type) || other.type == type)&&(identical(other.start, start) || other.start == start)&&(identical(other.endExclusive, endExclusive) || other.endExclusive == endExclusive));
}


@override
int get hashCode => Object.hash(runtimeType,type,start,endExclusive);

@override
String toString() {
  return 'SalesPeriod(type: $type, start: $start, endExclusive: $endExclusive)';
}


}

/// @nodoc
abstract mixin class _$SalesPeriodCopyWith<$Res> implements $SalesPeriodCopyWith<$Res> {
  factory _$SalesPeriodCopyWith(_SalesPeriod value, $Res Function(_SalesPeriod) _then) = __$SalesPeriodCopyWithImpl;
@override @useResult
$Res call({
 SalesPeriodType type, DateTime start, DateTime endExclusive
});




}
/// @nodoc
class __$SalesPeriodCopyWithImpl<$Res>
    implements _$SalesPeriodCopyWith<$Res> {
  __$SalesPeriodCopyWithImpl(this._self, this._then);

  final _SalesPeriod _self;
  final $Res Function(_SalesPeriod) _then;

/// Create a copy of SalesPeriod
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? start = null,Object? endExclusive = null,}) {
  return _then(_SalesPeriod(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as SalesPeriodType,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as DateTime,endExclusive: null == endExclusive ? _self.endExclusive : endExclusive // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on

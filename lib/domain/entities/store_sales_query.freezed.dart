// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'store_sales_query.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StoreSalesQuery {

 String get storeId; SalesPeriod get period;
/// Create a copy of StoreSalesQuery
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StoreSalesQueryCopyWith<StoreSalesQuery> get copyWith => _$StoreSalesQueryCopyWithImpl<StoreSalesQuery>(this as StoreSalesQuery, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StoreSalesQuery&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.period, period) || other.period == period));
}


@override
int get hashCode => Object.hash(runtimeType,storeId,period);

@override
String toString() {
  return 'StoreSalesQuery(storeId: $storeId, period: $period)';
}


}

/// @nodoc
abstract mixin class $StoreSalesQueryCopyWith<$Res>  {
  factory $StoreSalesQueryCopyWith(StoreSalesQuery value, $Res Function(StoreSalesQuery) _then) = _$StoreSalesQueryCopyWithImpl;
@useResult
$Res call({
 String storeId, SalesPeriod period
});


$SalesPeriodCopyWith<$Res> get period;

}
/// @nodoc
class _$StoreSalesQueryCopyWithImpl<$Res>
    implements $StoreSalesQueryCopyWith<$Res> {
  _$StoreSalesQueryCopyWithImpl(this._self, this._then);

  final StoreSalesQuery _self;
  final $Res Function(StoreSalesQuery) _then;

/// Create a copy of StoreSalesQuery
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? storeId = null,Object? period = null,}) {
  return _then(_self.copyWith(
storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as SalesPeriod,
  ));
}
/// Create a copy of StoreSalesQuery
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SalesPeriodCopyWith<$Res> get period {
  
  return $SalesPeriodCopyWith<$Res>(_self.period, (value) {
    return _then(_self.copyWith(period: value));
  });
}
}


/// Adds pattern-matching-related methods to [StoreSalesQuery].
extension StoreSalesQueryPatterns on StoreSalesQuery {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StoreSalesQuery value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StoreSalesQuery() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StoreSalesQuery value)  $default,){
final _that = this;
switch (_that) {
case _StoreSalesQuery():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StoreSalesQuery value)?  $default,){
final _that = this;
switch (_that) {
case _StoreSalesQuery() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String storeId,  SalesPeriod period)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StoreSalesQuery() when $default != null:
return $default(_that.storeId,_that.period);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String storeId,  SalesPeriod period)  $default,) {final _that = this;
switch (_that) {
case _StoreSalesQuery():
return $default(_that.storeId,_that.period);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String storeId,  SalesPeriod period)?  $default,) {final _that = this;
switch (_that) {
case _StoreSalesQuery() when $default != null:
return $default(_that.storeId,_that.period);case _:
  return null;

}
}

}

/// @nodoc


class _StoreSalesQuery implements StoreSalesQuery {
  const _StoreSalesQuery({required this.storeId, required this.period});
  

@override final  String storeId;
@override final  SalesPeriod period;

/// Create a copy of StoreSalesQuery
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StoreSalesQueryCopyWith<_StoreSalesQuery> get copyWith => __$StoreSalesQueryCopyWithImpl<_StoreSalesQuery>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StoreSalesQuery&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.period, period) || other.period == period));
}


@override
int get hashCode => Object.hash(runtimeType,storeId,period);

@override
String toString() {
  return 'StoreSalesQuery(storeId: $storeId, period: $period)';
}


}

/// @nodoc
abstract mixin class _$StoreSalesQueryCopyWith<$Res> implements $StoreSalesQueryCopyWith<$Res> {
  factory _$StoreSalesQueryCopyWith(_StoreSalesQuery value, $Res Function(_StoreSalesQuery) _then) = __$StoreSalesQueryCopyWithImpl;
@override @useResult
$Res call({
 String storeId, SalesPeriod period
});


@override $SalesPeriodCopyWith<$Res> get period;

}
/// @nodoc
class __$StoreSalesQueryCopyWithImpl<$Res>
    implements _$StoreSalesQueryCopyWith<$Res> {
  __$StoreSalesQueryCopyWithImpl(this._self, this._then);

  final _StoreSalesQuery _self;
  final $Res Function(_StoreSalesQuery) _then;

/// Create a copy of StoreSalesQuery
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? storeId = null,Object? period = null,}) {
  return _then(_StoreSalesQuery(
storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as SalesPeriod,
  ));
}

/// Create a copy of StoreSalesQuery
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SalesPeriodCopyWith<$Res> get period {
  
  return $SalesPeriodCopyWith<$Res>(_self.period, (value) {
    return _then(_self.copyWith(period: value));
  });
}
}

// dart format on

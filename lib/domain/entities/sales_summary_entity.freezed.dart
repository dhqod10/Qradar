// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sales_summary_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SalesSummaryEntity {

 SalesPeriod get period;/// 총 매출 (completed + 진행 중).
 int get netSales;/// 집계 대상 주문 건수 (completed + 진행 중).
 int get orderCount;/// 평균 객단가 (버림). 건수 0 이면 0.
 int get averageOrderValue; int get confirmedSales; int get confirmedCount; int get inProgressSales; int get inProgressCount; int get refundedAmount; int get refundedCount; int get cancelledCount;
/// Create a copy of SalesSummaryEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SalesSummaryEntityCopyWith<SalesSummaryEntity> get copyWith => _$SalesSummaryEntityCopyWithImpl<SalesSummaryEntity>(this as SalesSummaryEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SalesSummaryEntity&&(identical(other.period, period) || other.period == period)&&(identical(other.netSales, netSales) || other.netSales == netSales)&&(identical(other.orderCount, orderCount) || other.orderCount == orderCount)&&(identical(other.averageOrderValue, averageOrderValue) || other.averageOrderValue == averageOrderValue)&&(identical(other.confirmedSales, confirmedSales) || other.confirmedSales == confirmedSales)&&(identical(other.confirmedCount, confirmedCount) || other.confirmedCount == confirmedCount)&&(identical(other.inProgressSales, inProgressSales) || other.inProgressSales == inProgressSales)&&(identical(other.inProgressCount, inProgressCount) || other.inProgressCount == inProgressCount)&&(identical(other.refundedAmount, refundedAmount) || other.refundedAmount == refundedAmount)&&(identical(other.refundedCount, refundedCount) || other.refundedCount == refundedCount)&&(identical(other.cancelledCount, cancelledCount) || other.cancelledCount == cancelledCount));
}


@override
int get hashCode => Object.hash(runtimeType,period,netSales,orderCount,averageOrderValue,confirmedSales,confirmedCount,inProgressSales,inProgressCount,refundedAmount,refundedCount,cancelledCount);

@override
String toString() {
  return 'SalesSummaryEntity(period: $period, netSales: $netSales, orderCount: $orderCount, averageOrderValue: $averageOrderValue, confirmedSales: $confirmedSales, confirmedCount: $confirmedCount, inProgressSales: $inProgressSales, inProgressCount: $inProgressCount, refundedAmount: $refundedAmount, refundedCount: $refundedCount, cancelledCount: $cancelledCount)';
}


}

/// @nodoc
abstract mixin class $SalesSummaryEntityCopyWith<$Res>  {
  factory $SalesSummaryEntityCopyWith(SalesSummaryEntity value, $Res Function(SalesSummaryEntity) _then) = _$SalesSummaryEntityCopyWithImpl;
@useResult
$Res call({
 SalesPeriod period, int netSales, int orderCount, int averageOrderValue, int confirmedSales, int confirmedCount, int inProgressSales, int inProgressCount, int refundedAmount, int refundedCount, int cancelledCount
});


$SalesPeriodCopyWith<$Res> get period;

}
/// @nodoc
class _$SalesSummaryEntityCopyWithImpl<$Res>
    implements $SalesSummaryEntityCopyWith<$Res> {
  _$SalesSummaryEntityCopyWithImpl(this._self, this._then);

  final SalesSummaryEntity _self;
  final $Res Function(SalesSummaryEntity) _then;

/// Create a copy of SalesSummaryEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? period = null,Object? netSales = null,Object? orderCount = null,Object? averageOrderValue = null,Object? confirmedSales = null,Object? confirmedCount = null,Object? inProgressSales = null,Object? inProgressCount = null,Object? refundedAmount = null,Object? refundedCount = null,Object? cancelledCount = null,}) {
  return _then(_self.copyWith(
period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as SalesPeriod,netSales: null == netSales ? _self.netSales : netSales // ignore: cast_nullable_to_non_nullable
as int,orderCount: null == orderCount ? _self.orderCount : orderCount // ignore: cast_nullable_to_non_nullable
as int,averageOrderValue: null == averageOrderValue ? _self.averageOrderValue : averageOrderValue // ignore: cast_nullable_to_non_nullable
as int,confirmedSales: null == confirmedSales ? _self.confirmedSales : confirmedSales // ignore: cast_nullable_to_non_nullable
as int,confirmedCount: null == confirmedCount ? _self.confirmedCount : confirmedCount // ignore: cast_nullable_to_non_nullable
as int,inProgressSales: null == inProgressSales ? _self.inProgressSales : inProgressSales // ignore: cast_nullable_to_non_nullable
as int,inProgressCount: null == inProgressCount ? _self.inProgressCount : inProgressCount // ignore: cast_nullable_to_non_nullable
as int,refundedAmount: null == refundedAmount ? _self.refundedAmount : refundedAmount // ignore: cast_nullable_to_non_nullable
as int,refundedCount: null == refundedCount ? _self.refundedCount : refundedCount // ignore: cast_nullable_to_non_nullable
as int,cancelledCount: null == cancelledCount ? _self.cancelledCount : cancelledCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of SalesSummaryEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SalesPeriodCopyWith<$Res> get period {
  
  return $SalesPeriodCopyWith<$Res>(_self.period, (value) {
    return _then(_self.copyWith(period: value));
  });
}
}


/// Adds pattern-matching-related methods to [SalesSummaryEntity].
extension SalesSummaryEntityPatterns on SalesSummaryEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SalesSummaryEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SalesSummaryEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SalesSummaryEntity value)  $default,){
final _that = this;
switch (_that) {
case _SalesSummaryEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SalesSummaryEntity value)?  $default,){
final _that = this;
switch (_that) {
case _SalesSummaryEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SalesPeriod period,  int netSales,  int orderCount,  int averageOrderValue,  int confirmedSales,  int confirmedCount,  int inProgressSales,  int inProgressCount,  int refundedAmount,  int refundedCount,  int cancelledCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SalesSummaryEntity() when $default != null:
return $default(_that.period,_that.netSales,_that.orderCount,_that.averageOrderValue,_that.confirmedSales,_that.confirmedCount,_that.inProgressSales,_that.inProgressCount,_that.refundedAmount,_that.refundedCount,_that.cancelledCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SalesPeriod period,  int netSales,  int orderCount,  int averageOrderValue,  int confirmedSales,  int confirmedCount,  int inProgressSales,  int inProgressCount,  int refundedAmount,  int refundedCount,  int cancelledCount)  $default,) {final _that = this;
switch (_that) {
case _SalesSummaryEntity():
return $default(_that.period,_that.netSales,_that.orderCount,_that.averageOrderValue,_that.confirmedSales,_that.confirmedCount,_that.inProgressSales,_that.inProgressCount,_that.refundedAmount,_that.refundedCount,_that.cancelledCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SalesPeriod period,  int netSales,  int orderCount,  int averageOrderValue,  int confirmedSales,  int confirmedCount,  int inProgressSales,  int inProgressCount,  int refundedAmount,  int refundedCount,  int cancelledCount)?  $default,) {final _that = this;
switch (_that) {
case _SalesSummaryEntity() when $default != null:
return $default(_that.period,_that.netSales,_that.orderCount,_that.averageOrderValue,_that.confirmedSales,_that.confirmedCount,_that.inProgressSales,_that.inProgressCount,_that.refundedAmount,_that.refundedCount,_that.cancelledCount);case _:
  return null;

}
}

}

/// @nodoc


class _SalesSummaryEntity implements SalesSummaryEntity {
  const _SalesSummaryEntity({required this.period, required this.netSales, required this.orderCount, required this.averageOrderValue, required this.confirmedSales, required this.confirmedCount, required this.inProgressSales, required this.inProgressCount, required this.refundedAmount, required this.refundedCount, required this.cancelledCount});
  

@override final  SalesPeriod period;
/// 총 매출 (completed + 진행 중).
@override final  int netSales;
/// 집계 대상 주문 건수 (completed + 진행 중).
@override final  int orderCount;
/// 평균 객단가 (버림). 건수 0 이면 0.
@override final  int averageOrderValue;
@override final  int confirmedSales;
@override final  int confirmedCount;
@override final  int inProgressSales;
@override final  int inProgressCount;
@override final  int refundedAmount;
@override final  int refundedCount;
@override final  int cancelledCount;

/// Create a copy of SalesSummaryEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SalesSummaryEntityCopyWith<_SalesSummaryEntity> get copyWith => __$SalesSummaryEntityCopyWithImpl<_SalesSummaryEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SalesSummaryEntity&&(identical(other.period, period) || other.period == period)&&(identical(other.netSales, netSales) || other.netSales == netSales)&&(identical(other.orderCount, orderCount) || other.orderCount == orderCount)&&(identical(other.averageOrderValue, averageOrderValue) || other.averageOrderValue == averageOrderValue)&&(identical(other.confirmedSales, confirmedSales) || other.confirmedSales == confirmedSales)&&(identical(other.confirmedCount, confirmedCount) || other.confirmedCount == confirmedCount)&&(identical(other.inProgressSales, inProgressSales) || other.inProgressSales == inProgressSales)&&(identical(other.inProgressCount, inProgressCount) || other.inProgressCount == inProgressCount)&&(identical(other.refundedAmount, refundedAmount) || other.refundedAmount == refundedAmount)&&(identical(other.refundedCount, refundedCount) || other.refundedCount == refundedCount)&&(identical(other.cancelledCount, cancelledCount) || other.cancelledCount == cancelledCount));
}


@override
int get hashCode => Object.hash(runtimeType,period,netSales,orderCount,averageOrderValue,confirmedSales,confirmedCount,inProgressSales,inProgressCount,refundedAmount,refundedCount,cancelledCount);

@override
String toString() {
  return 'SalesSummaryEntity(period: $period, netSales: $netSales, orderCount: $orderCount, averageOrderValue: $averageOrderValue, confirmedSales: $confirmedSales, confirmedCount: $confirmedCount, inProgressSales: $inProgressSales, inProgressCount: $inProgressCount, refundedAmount: $refundedAmount, refundedCount: $refundedCount, cancelledCount: $cancelledCount)';
}


}

/// @nodoc
abstract mixin class _$SalesSummaryEntityCopyWith<$Res> implements $SalesSummaryEntityCopyWith<$Res> {
  factory _$SalesSummaryEntityCopyWith(_SalesSummaryEntity value, $Res Function(_SalesSummaryEntity) _then) = __$SalesSummaryEntityCopyWithImpl;
@override @useResult
$Res call({
 SalesPeriod period, int netSales, int orderCount, int averageOrderValue, int confirmedSales, int confirmedCount, int inProgressSales, int inProgressCount, int refundedAmount, int refundedCount, int cancelledCount
});


@override $SalesPeriodCopyWith<$Res> get period;

}
/// @nodoc
class __$SalesSummaryEntityCopyWithImpl<$Res>
    implements _$SalesSummaryEntityCopyWith<$Res> {
  __$SalesSummaryEntityCopyWithImpl(this._self, this._then);

  final _SalesSummaryEntity _self;
  final $Res Function(_SalesSummaryEntity) _then;

/// Create a copy of SalesSummaryEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? period = null,Object? netSales = null,Object? orderCount = null,Object? averageOrderValue = null,Object? confirmedSales = null,Object? confirmedCount = null,Object? inProgressSales = null,Object? inProgressCount = null,Object? refundedAmount = null,Object? refundedCount = null,Object? cancelledCount = null,}) {
  return _then(_SalesSummaryEntity(
period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as SalesPeriod,netSales: null == netSales ? _self.netSales : netSales // ignore: cast_nullable_to_non_nullable
as int,orderCount: null == orderCount ? _self.orderCount : orderCount // ignore: cast_nullable_to_non_nullable
as int,averageOrderValue: null == averageOrderValue ? _self.averageOrderValue : averageOrderValue // ignore: cast_nullable_to_non_nullable
as int,confirmedSales: null == confirmedSales ? _self.confirmedSales : confirmedSales // ignore: cast_nullable_to_non_nullable
as int,confirmedCount: null == confirmedCount ? _self.confirmedCount : confirmedCount // ignore: cast_nullable_to_non_nullable
as int,inProgressSales: null == inProgressSales ? _self.inProgressSales : inProgressSales // ignore: cast_nullable_to_non_nullable
as int,inProgressCount: null == inProgressCount ? _self.inProgressCount : inProgressCount // ignore: cast_nullable_to_non_nullable
as int,refundedAmount: null == refundedAmount ? _self.refundedAmount : refundedAmount // ignore: cast_nullable_to_non_nullable
as int,refundedCount: null == refundedCount ? _self.refundedCount : refundedCount // ignore: cast_nullable_to_non_nullable
as int,cancelledCount: null == cancelledCount ? _self.cancelledCount : cancelledCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of SalesSummaryEntity
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

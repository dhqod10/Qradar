// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'store_sales_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StoreSalesEntity {

 SalesSummaryEntity get summary;/// 기간 내 전체 주문 (createdAt 내림차순, 환불·취소 포함).
 List<OrderEntity> get orders;/// 조회 상한에 걸려 일부만 집계했는가.
 bool get isTruncated;
/// Create a copy of StoreSalesEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StoreSalesEntityCopyWith<StoreSalesEntity> get copyWith => _$StoreSalesEntityCopyWithImpl<StoreSalesEntity>(this as StoreSalesEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StoreSalesEntity&&(identical(other.summary, summary) || other.summary == summary)&&const DeepCollectionEquality().equals(other.orders, orders)&&(identical(other.isTruncated, isTruncated) || other.isTruncated == isTruncated));
}


@override
int get hashCode => Object.hash(runtimeType,summary,const DeepCollectionEquality().hash(orders),isTruncated);

@override
String toString() {
  return 'StoreSalesEntity(summary: $summary, orders: $orders, isTruncated: $isTruncated)';
}


}

/// @nodoc
abstract mixin class $StoreSalesEntityCopyWith<$Res>  {
  factory $StoreSalesEntityCopyWith(StoreSalesEntity value, $Res Function(StoreSalesEntity) _then) = _$StoreSalesEntityCopyWithImpl;
@useResult
$Res call({
 SalesSummaryEntity summary, List<OrderEntity> orders, bool isTruncated
});


$SalesSummaryEntityCopyWith<$Res> get summary;

}
/// @nodoc
class _$StoreSalesEntityCopyWithImpl<$Res>
    implements $StoreSalesEntityCopyWith<$Res> {
  _$StoreSalesEntityCopyWithImpl(this._self, this._then);

  final StoreSalesEntity _self;
  final $Res Function(StoreSalesEntity) _then;

/// Create a copy of StoreSalesEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? summary = null,Object? orders = null,Object? isTruncated = null,}) {
  return _then(_self.copyWith(
summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as SalesSummaryEntity,orders: null == orders ? _self.orders : orders // ignore: cast_nullable_to_non_nullable
as List<OrderEntity>,isTruncated: null == isTruncated ? _self.isTruncated : isTruncated // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of StoreSalesEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SalesSummaryEntityCopyWith<$Res> get summary {
  
  return $SalesSummaryEntityCopyWith<$Res>(_self.summary, (value) {
    return _then(_self.copyWith(summary: value));
  });
}
}


/// Adds pattern-matching-related methods to [StoreSalesEntity].
extension StoreSalesEntityPatterns on StoreSalesEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StoreSalesEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StoreSalesEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StoreSalesEntity value)  $default,){
final _that = this;
switch (_that) {
case _StoreSalesEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StoreSalesEntity value)?  $default,){
final _that = this;
switch (_that) {
case _StoreSalesEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SalesSummaryEntity summary,  List<OrderEntity> orders,  bool isTruncated)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StoreSalesEntity() when $default != null:
return $default(_that.summary,_that.orders,_that.isTruncated);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SalesSummaryEntity summary,  List<OrderEntity> orders,  bool isTruncated)  $default,) {final _that = this;
switch (_that) {
case _StoreSalesEntity():
return $default(_that.summary,_that.orders,_that.isTruncated);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SalesSummaryEntity summary,  List<OrderEntity> orders,  bool isTruncated)?  $default,) {final _that = this;
switch (_that) {
case _StoreSalesEntity() when $default != null:
return $default(_that.summary,_that.orders,_that.isTruncated);case _:
  return null;

}
}

}

/// @nodoc


class _StoreSalesEntity implements StoreSalesEntity {
  const _StoreSalesEntity({required this.summary, required final  List<OrderEntity> orders, required this.isTruncated}): _orders = orders;
  

@override final  SalesSummaryEntity summary;
/// 기간 내 전체 주문 (createdAt 내림차순, 환불·취소 포함).
 final  List<OrderEntity> _orders;
/// 기간 내 전체 주문 (createdAt 내림차순, 환불·취소 포함).
@override List<OrderEntity> get orders {
  if (_orders is EqualUnmodifiableListView) return _orders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_orders);
}

/// 조회 상한에 걸려 일부만 집계했는가.
@override final  bool isTruncated;

/// Create a copy of StoreSalesEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StoreSalesEntityCopyWith<_StoreSalesEntity> get copyWith => __$StoreSalesEntityCopyWithImpl<_StoreSalesEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StoreSalesEntity&&(identical(other.summary, summary) || other.summary == summary)&&const DeepCollectionEquality().equals(other._orders, _orders)&&(identical(other.isTruncated, isTruncated) || other.isTruncated == isTruncated));
}


@override
int get hashCode => Object.hash(runtimeType,summary,const DeepCollectionEquality().hash(_orders),isTruncated);

@override
String toString() {
  return 'StoreSalesEntity(summary: $summary, orders: $orders, isTruncated: $isTruncated)';
}


}

/// @nodoc
abstract mixin class _$StoreSalesEntityCopyWith<$Res> implements $StoreSalesEntityCopyWith<$Res> {
  factory _$StoreSalesEntityCopyWith(_StoreSalesEntity value, $Res Function(_StoreSalesEntity) _then) = __$StoreSalesEntityCopyWithImpl;
@override @useResult
$Res call({
 SalesSummaryEntity summary, List<OrderEntity> orders, bool isTruncated
});


@override $SalesSummaryEntityCopyWith<$Res> get summary;

}
/// @nodoc
class __$StoreSalesEntityCopyWithImpl<$Res>
    implements _$StoreSalesEntityCopyWith<$Res> {
  __$StoreSalesEntityCopyWithImpl(this._self, this._then);

  final _StoreSalesEntity _self;
  final $Res Function(_StoreSalesEntity) _then;

/// Create a copy of StoreSalesEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? summary = null,Object? orders = null,Object? isTruncated = null,}) {
  return _then(_StoreSalesEntity(
summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as SalesSummaryEntity,orders: null == orders ? _self._orders : orders // ignore: cast_nullable_to_non_nullable
as List<OrderEntity>,isTruncated: null == isTruncated ? _self.isTruncated : isTruncated // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of StoreSalesEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SalesSummaryEntityCopyWith<$Res> get summary {
  
  return $SalesSummaryEntityCopyWith<$Res>(_self.summary, (value) {
    return _then(_self.copyWith(summary: value));
  });
}
}

// dart format on

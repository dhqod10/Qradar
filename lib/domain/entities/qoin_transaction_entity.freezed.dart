// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'qoin_transaction_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$QoinTransactionEntity {

 String get txId;/// 미지 타입이면 null. 적립/회수 판정은 [amount] 부호로 한다.
 QoinTransactionType? get type;/// 부호 포함. 적립 양수, 회수 음수.
 int get amount;/// 이 거래 직후 잔액 (감사 추적).
 int get balanceAfter; String get orderId; String get storeId; String get storeName;/// 적립 산정 기준 결제액 (거래 당시). 누락 시 null.
 int? get orderTotalPrice;/// 적립 당시 적용 비율 (거래 당시). 누락 시 null.
 double? get accrualRate;/// 서버 타임스탬프 미확정(pending)이면 null.
 DateTime? get createdAt;
/// Create a copy of QoinTransactionEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QoinTransactionEntityCopyWith<QoinTransactionEntity> get copyWith => _$QoinTransactionEntityCopyWithImpl<QoinTransactionEntity>(this as QoinTransactionEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QoinTransactionEntity&&(identical(other.txId, txId) || other.txId == txId)&&(identical(other.type, type) || other.type == type)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.balanceAfter, balanceAfter) || other.balanceAfter == balanceAfter)&&(identical(other.orderId, orderId) || other.orderId == orderId)&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.storeName, storeName) || other.storeName == storeName)&&(identical(other.orderTotalPrice, orderTotalPrice) || other.orderTotalPrice == orderTotalPrice)&&(identical(other.accrualRate, accrualRate) || other.accrualRate == accrualRate)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,txId,type,amount,balanceAfter,orderId,storeId,storeName,orderTotalPrice,accrualRate,createdAt);

@override
String toString() {
  return 'QoinTransactionEntity(txId: $txId, type: $type, amount: $amount, balanceAfter: $balanceAfter, orderId: $orderId, storeId: $storeId, storeName: $storeName, orderTotalPrice: $orderTotalPrice, accrualRate: $accrualRate, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $QoinTransactionEntityCopyWith<$Res>  {
  factory $QoinTransactionEntityCopyWith(QoinTransactionEntity value, $Res Function(QoinTransactionEntity) _then) = _$QoinTransactionEntityCopyWithImpl;
@useResult
$Res call({
 String txId, QoinTransactionType? type, int amount, int balanceAfter, String orderId, String storeId, String storeName, int? orderTotalPrice, double? accrualRate, DateTime? createdAt
});




}
/// @nodoc
class _$QoinTransactionEntityCopyWithImpl<$Res>
    implements $QoinTransactionEntityCopyWith<$Res> {
  _$QoinTransactionEntityCopyWithImpl(this._self, this._then);

  final QoinTransactionEntity _self;
  final $Res Function(QoinTransactionEntity) _then;

/// Create a copy of QoinTransactionEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? txId = null,Object? type = freezed,Object? amount = null,Object? balanceAfter = null,Object? orderId = null,Object? storeId = null,Object? storeName = null,Object? orderTotalPrice = freezed,Object? accrualRate = freezed,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
txId: null == txId ? _self.txId : txId // ignore: cast_nullable_to_non_nullable
as String,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as QoinTransactionType?,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,balanceAfter: null == balanceAfter ? _self.balanceAfter : balanceAfter // ignore: cast_nullable_to_non_nullable
as int,orderId: null == orderId ? _self.orderId : orderId // ignore: cast_nullable_to_non_nullable
as String,storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,storeName: null == storeName ? _self.storeName : storeName // ignore: cast_nullable_to_non_nullable
as String,orderTotalPrice: freezed == orderTotalPrice ? _self.orderTotalPrice : orderTotalPrice // ignore: cast_nullable_to_non_nullable
as int?,accrualRate: freezed == accrualRate ? _self.accrualRate : accrualRate // ignore: cast_nullable_to_non_nullable
as double?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [QoinTransactionEntity].
extension QoinTransactionEntityPatterns on QoinTransactionEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QoinTransactionEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QoinTransactionEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QoinTransactionEntity value)  $default,){
final _that = this;
switch (_that) {
case _QoinTransactionEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QoinTransactionEntity value)?  $default,){
final _that = this;
switch (_that) {
case _QoinTransactionEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String txId,  QoinTransactionType? type,  int amount,  int balanceAfter,  String orderId,  String storeId,  String storeName,  int? orderTotalPrice,  double? accrualRate,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QoinTransactionEntity() when $default != null:
return $default(_that.txId,_that.type,_that.amount,_that.balanceAfter,_that.orderId,_that.storeId,_that.storeName,_that.orderTotalPrice,_that.accrualRate,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String txId,  QoinTransactionType? type,  int amount,  int balanceAfter,  String orderId,  String storeId,  String storeName,  int? orderTotalPrice,  double? accrualRate,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _QoinTransactionEntity():
return $default(_that.txId,_that.type,_that.amount,_that.balanceAfter,_that.orderId,_that.storeId,_that.storeName,_that.orderTotalPrice,_that.accrualRate,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String txId,  QoinTransactionType? type,  int amount,  int balanceAfter,  String orderId,  String storeId,  String storeName,  int? orderTotalPrice,  double? accrualRate,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _QoinTransactionEntity() when $default != null:
return $default(_that.txId,_that.type,_that.amount,_that.balanceAfter,_that.orderId,_that.storeId,_that.storeName,_that.orderTotalPrice,_that.accrualRate,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _QoinTransactionEntity implements QoinTransactionEntity {
  const _QoinTransactionEntity({required this.txId, this.type, required this.amount, required this.balanceAfter, this.orderId = '', this.storeId = '', this.storeName = '', this.orderTotalPrice, this.accrualRate, this.createdAt});
  

@override final  String txId;
/// 미지 타입이면 null. 적립/회수 판정은 [amount] 부호로 한다.
@override final  QoinTransactionType? type;
/// 부호 포함. 적립 양수, 회수 음수.
@override final  int amount;
/// 이 거래 직후 잔액 (감사 추적).
@override final  int balanceAfter;
@override@JsonKey() final  String orderId;
@override@JsonKey() final  String storeId;
@override@JsonKey() final  String storeName;
/// 적립 산정 기준 결제액 (거래 당시). 누락 시 null.
@override final  int? orderTotalPrice;
/// 적립 당시 적용 비율 (거래 당시). 누락 시 null.
@override final  double? accrualRate;
/// 서버 타임스탬프 미확정(pending)이면 null.
@override final  DateTime? createdAt;

/// Create a copy of QoinTransactionEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QoinTransactionEntityCopyWith<_QoinTransactionEntity> get copyWith => __$QoinTransactionEntityCopyWithImpl<_QoinTransactionEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QoinTransactionEntity&&(identical(other.txId, txId) || other.txId == txId)&&(identical(other.type, type) || other.type == type)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.balanceAfter, balanceAfter) || other.balanceAfter == balanceAfter)&&(identical(other.orderId, orderId) || other.orderId == orderId)&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.storeName, storeName) || other.storeName == storeName)&&(identical(other.orderTotalPrice, orderTotalPrice) || other.orderTotalPrice == orderTotalPrice)&&(identical(other.accrualRate, accrualRate) || other.accrualRate == accrualRate)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,txId,type,amount,balanceAfter,orderId,storeId,storeName,orderTotalPrice,accrualRate,createdAt);

@override
String toString() {
  return 'QoinTransactionEntity(txId: $txId, type: $type, amount: $amount, balanceAfter: $balanceAfter, orderId: $orderId, storeId: $storeId, storeName: $storeName, orderTotalPrice: $orderTotalPrice, accrualRate: $accrualRate, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$QoinTransactionEntityCopyWith<$Res> implements $QoinTransactionEntityCopyWith<$Res> {
  factory _$QoinTransactionEntityCopyWith(_QoinTransactionEntity value, $Res Function(_QoinTransactionEntity) _then) = __$QoinTransactionEntityCopyWithImpl;
@override @useResult
$Res call({
 String txId, QoinTransactionType? type, int amount, int balanceAfter, String orderId, String storeId, String storeName, int? orderTotalPrice, double? accrualRate, DateTime? createdAt
});




}
/// @nodoc
class __$QoinTransactionEntityCopyWithImpl<$Res>
    implements _$QoinTransactionEntityCopyWith<$Res> {
  __$QoinTransactionEntityCopyWithImpl(this._self, this._then);

  final _QoinTransactionEntity _self;
  final $Res Function(_QoinTransactionEntity) _then;

/// Create a copy of QoinTransactionEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? txId = null,Object? type = freezed,Object? amount = null,Object? balanceAfter = null,Object? orderId = null,Object? storeId = null,Object? storeName = null,Object? orderTotalPrice = freezed,Object? accrualRate = freezed,Object? createdAt = freezed,}) {
  return _then(_QoinTransactionEntity(
txId: null == txId ? _self.txId : txId // ignore: cast_nullable_to_non_nullable
as String,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as QoinTransactionType?,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,balanceAfter: null == balanceAfter ? _self.balanceAfter : balanceAfter // ignore: cast_nullable_to_non_nullable
as int,orderId: null == orderId ? _self.orderId : orderId // ignore: cast_nullable_to_non_nullable
as String,storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,storeName: null == storeName ? _self.storeName : storeName // ignore: cast_nullable_to_non_nullable
as String,orderTotalPrice: freezed == orderTotalPrice ? _self.orderTotalPrice : orderTotalPrice // ignore: cast_nullable_to_non_nullable
as int?,accrualRate: freezed == accrualRate ? _self.accrualRate : accrualRate // ignore: cast_nullable_to_non_nullable
as double?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on

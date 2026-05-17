// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'order_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$OrderEntity {

 String get id; String get userId; String get storeId; String get storeName; String? get brandId; List<OrderItemEntity> get items; int get subtotal; int? get discount; int get totalPrice; OrderStatus get status; PaymentInfoEntity get paymentInfo; RefundRequestEntity? get refundRequest; RefundInfoEntity? get refundInfo; DateTime get createdAt; DateTime get updatedAt; DateTime? get acceptedAt; DateTime? get cancelledAt; DateTime? get refundedAt;
/// Create a copy of OrderEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderEntityCopyWith<OrderEntity> get copyWith => _$OrderEntityCopyWithImpl<OrderEntity>(this as OrderEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrderEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.storeName, storeName) || other.storeName == storeName)&&(identical(other.brandId, brandId) || other.brandId == brandId)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.subtotal, subtotal) || other.subtotal == subtotal)&&(identical(other.discount, discount) || other.discount == discount)&&(identical(other.totalPrice, totalPrice) || other.totalPrice == totalPrice)&&(identical(other.status, status) || other.status == status)&&(identical(other.paymentInfo, paymentInfo) || other.paymentInfo == paymentInfo)&&(identical(other.refundRequest, refundRequest) || other.refundRequest == refundRequest)&&(identical(other.refundInfo, refundInfo) || other.refundInfo == refundInfo)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.acceptedAt, acceptedAt) || other.acceptedAt == acceptedAt)&&(identical(other.cancelledAt, cancelledAt) || other.cancelledAt == cancelledAt)&&(identical(other.refundedAt, refundedAt) || other.refundedAt == refundedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,userId,storeId,storeName,brandId,const DeepCollectionEquality().hash(items),subtotal,discount,totalPrice,status,paymentInfo,refundRequest,refundInfo,createdAt,updatedAt,acceptedAt,cancelledAt,refundedAt);

@override
String toString() {
  return 'OrderEntity(id: $id, userId: $userId, storeId: $storeId, storeName: $storeName, brandId: $brandId, items: $items, subtotal: $subtotal, discount: $discount, totalPrice: $totalPrice, status: $status, paymentInfo: $paymentInfo, refundRequest: $refundRequest, refundInfo: $refundInfo, createdAt: $createdAt, updatedAt: $updatedAt, acceptedAt: $acceptedAt, cancelledAt: $cancelledAt, refundedAt: $refundedAt)';
}


}

/// @nodoc
abstract mixin class $OrderEntityCopyWith<$Res>  {
  factory $OrderEntityCopyWith(OrderEntity value, $Res Function(OrderEntity) _then) = _$OrderEntityCopyWithImpl;
@useResult
$Res call({
 String id, String userId, String storeId, String storeName, String? brandId, List<OrderItemEntity> items, int subtotal, int? discount, int totalPrice, OrderStatus status, PaymentInfoEntity paymentInfo, RefundRequestEntity? refundRequest, RefundInfoEntity? refundInfo, DateTime createdAt, DateTime updatedAt, DateTime? acceptedAt, DateTime? cancelledAt, DateTime? refundedAt
});


$PaymentInfoEntityCopyWith<$Res> get paymentInfo;$RefundRequestEntityCopyWith<$Res>? get refundRequest;$RefundInfoEntityCopyWith<$Res>? get refundInfo;

}
/// @nodoc
class _$OrderEntityCopyWithImpl<$Res>
    implements $OrderEntityCopyWith<$Res> {
  _$OrderEntityCopyWithImpl(this._self, this._then);

  final OrderEntity _self;
  final $Res Function(OrderEntity) _then;

/// Create a copy of OrderEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? storeId = null,Object? storeName = null,Object? brandId = freezed,Object? items = null,Object? subtotal = null,Object? discount = freezed,Object? totalPrice = null,Object? status = null,Object? paymentInfo = null,Object? refundRequest = freezed,Object? refundInfo = freezed,Object? createdAt = null,Object? updatedAt = null,Object? acceptedAt = freezed,Object? cancelledAt = freezed,Object? refundedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,storeName: null == storeName ? _self.storeName : storeName // ignore: cast_nullable_to_non_nullable
as String,brandId: freezed == brandId ? _self.brandId : brandId // ignore: cast_nullable_to_non_nullable
as String?,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<OrderItemEntity>,subtotal: null == subtotal ? _self.subtotal : subtotal // ignore: cast_nullable_to_non_nullable
as int,discount: freezed == discount ? _self.discount : discount // ignore: cast_nullable_to_non_nullable
as int?,totalPrice: null == totalPrice ? _self.totalPrice : totalPrice // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as OrderStatus,paymentInfo: null == paymentInfo ? _self.paymentInfo : paymentInfo // ignore: cast_nullable_to_non_nullable
as PaymentInfoEntity,refundRequest: freezed == refundRequest ? _self.refundRequest : refundRequest // ignore: cast_nullable_to_non_nullable
as RefundRequestEntity?,refundInfo: freezed == refundInfo ? _self.refundInfo : refundInfo // ignore: cast_nullable_to_non_nullable
as RefundInfoEntity?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,acceptedAt: freezed == acceptedAt ? _self.acceptedAt : acceptedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancelledAt: freezed == cancelledAt ? _self.cancelledAt : cancelledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,refundedAt: freezed == refundedAt ? _self.refundedAt : refundedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of OrderEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PaymentInfoEntityCopyWith<$Res> get paymentInfo {
  
  return $PaymentInfoEntityCopyWith<$Res>(_self.paymentInfo, (value) {
    return _then(_self.copyWith(paymentInfo: value));
  });
}/// Create a copy of OrderEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RefundRequestEntityCopyWith<$Res>? get refundRequest {
    if (_self.refundRequest == null) {
    return null;
  }

  return $RefundRequestEntityCopyWith<$Res>(_self.refundRequest!, (value) {
    return _then(_self.copyWith(refundRequest: value));
  });
}/// Create a copy of OrderEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RefundInfoEntityCopyWith<$Res>? get refundInfo {
    if (_self.refundInfo == null) {
    return null;
  }

  return $RefundInfoEntityCopyWith<$Res>(_self.refundInfo!, (value) {
    return _then(_self.copyWith(refundInfo: value));
  });
}
}


/// Adds pattern-matching-related methods to [OrderEntity].
extension OrderEntityPatterns on OrderEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrderEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrderEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrderEntity value)  $default,){
final _that = this;
switch (_that) {
case _OrderEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrderEntity value)?  $default,){
final _that = this;
switch (_that) {
case _OrderEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String userId,  String storeId,  String storeName,  String? brandId,  List<OrderItemEntity> items,  int subtotal,  int? discount,  int totalPrice,  OrderStatus status,  PaymentInfoEntity paymentInfo,  RefundRequestEntity? refundRequest,  RefundInfoEntity? refundInfo,  DateTime createdAt,  DateTime updatedAt,  DateTime? acceptedAt,  DateTime? cancelledAt,  DateTime? refundedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrderEntity() when $default != null:
return $default(_that.id,_that.userId,_that.storeId,_that.storeName,_that.brandId,_that.items,_that.subtotal,_that.discount,_that.totalPrice,_that.status,_that.paymentInfo,_that.refundRequest,_that.refundInfo,_that.createdAt,_that.updatedAt,_that.acceptedAt,_that.cancelledAt,_that.refundedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String userId,  String storeId,  String storeName,  String? brandId,  List<OrderItemEntity> items,  int subtotal,  int? discount,  int totalPrice,  OrderStatus status,  PaymentInfoEntity paymentInfo,  RefundRequestEntity? refundRequest,  RefundInfoEntity? refundInfo,  DateTime createdAt,  DateTime updatedAt,  DateTime? acceptedAt,  DateTime? cancelledAt,  DateTime? refundedAt)  $default,) {final _that = this;
switch (_that) {
case _OrderEntity():
return $default(_that.id,_that.userId,_that.storeId,_that.storeName,_that.brandId,_that.items,_that.subtotal,_that.discount,_that.totalPrice,_that.status,_that.paymentInfo,_that.refundRequest,_that.refundInfo,_that.createdAt,_that.updatedAt,_that.acceptedAt,_that.cancelledAt,_that.refundedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String userId,  String storeId,  String storeName,  String? brandId,  List<OrderItemEntity> items,  int subtotal,  int? discount,  int totalPrice,  OrderStatus status,  PaymentInfoEntity paymentInfo,  RefundRequestEntity? refundRequest,  RefundInfoEntity? refundInfo,  DateTime createdAt,  DateTime updatedAt,  DateTime? acceptedAt,  DateTime? cancelledAt,  DateTime? refundedAt)?  $default,) {final _that = this;
switch (_that) {
case _OrderEntity() when $default != null:
return $default(_that.id,_that.userId,_that.storeId,_that.storeName,_that.brandId,_that.items,_that.subtotal,_that.discount,_that.totalPrice,_that.status,_that.paymentInfo,_that.refundRequest,_that.refundInfo,_that.createdAt,_that.updatedAt,_that.acceptedAt,_that.cancelledAt,_that.refundedAt);case _:
  return null;

}
}

}

/// @nodoc


class _OrderEntity implements OrderEntity {
  const _OrderEntity({required this.id, required this.userId, required this.storeId, required this.storeName, this.brandId, final  List<OrderItemEntity> items = const <OrderItemEntity>[], required this.subtotal, this.discount, required this.totalPrice, required this.status, required this.paymentInfo, this.refundRequest, this.refundInfo, required this.createdAt, required this.updatedAt, this.acceptedAt, this.cancelledAt, this.refundedAt}): _items = items;
  

@override final  String id;
@override final  String userId;
@override final  String storeId;
@override final  String storeName;
@override final  String? brandId;
 final  List<OrderItemEntity> _items;
@override@JsonKey() List<OrderItemEntity> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  int subtotal;
@override final  int? discount;
@override final  int totalPrice;
@override final  OrderStatus status;
@override final  PaymentInfoEntity paymentInfo;
@override final  RefundRequestEntity? refundRequest;
@override final  RefundInfoEntity? refundInfo;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  DateTime? acceptedAt;
@override final  DateTime? cancelledAt;
@override final  DateTime? refundedAt;

/// Create a copy of OrderEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderEntityCopyWith<_OrderEntity> get copyWith => __$OrderEntityCopyWithImpl<_OrderEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrderEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.storeName, storeName) || other.storeName == storeName)&&(identical(other.brandId, brandId) || other.brandId == brandId)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.subtotal, subtotal) || other.subtotal == subtotal)&&(identical(other.discount, discount) || other.discount == discount)&&(identical(other.totalPrice, totalPrice) || other.totalPrice == totalPrice)&&(identical(other.status, status) || other.status == status)&&(identical(other.paymentInfo, paymentInfo) || other.paymentInfo == paymentInfo)&&(identical(other.refundRequest, refundRequest) || other.refundRequest == refundRequest)&&(identical(other.refundInfo, refundInfo) || other.refundInfo == refundInfo)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.acceptedAt, acceptedAt) || other.acceptedAt == acceptedAt)&&(identical(other.cancelledAt, cancelledAt) || other.cancelledAt == cancelledAt)&&(identical(other.refundedAt, refundedAt) || other.refundedAt == refundedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,userId,storeId,storeName,brandId,const DeepCollectionEquality().hash(_items),subtotal,discount,totalPrice,status,paymentInfo,refundRequest,refundInfo,createdAt,updatedAt,acceptedAt,cancelledAt,refundedAt);

@override
String toString() {
  return 'OrderEntity(id: $id, userId: $userId, storeId: $storeId, storeName: $storeName, brandId: $brandId, items: $items, subtotal: $subtotal, discount: $discount, totalPrice: $totalPrice, status: $status, paymentInfo: $paymentInfo, refundRequest: $refundRequest, refundInfo: $refundInfo, createdAt: $createdAt, updatedAt: $updatedAt, acceptedAt: $acceptedAt, cancelledAt: $cancelledAt, refundedAt: $refundedAt)';
}


}

/// @nodoc
abstract mixin class _$OrderEntityCopyWith<$Res> implements $OrderEntityCopyWith<$Res> {
  factory _$OrderEntityCopyWith(_OrderEntity value, $Res Function(_OrderEntity) _then) = __$OrderEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String userId, String storeId, String storeName, String? brandId, List<OrderItemEntity> items, int subtotal, int? discount, int totalPrice, OrderStatus status, PaymentInfoEntity paymentInfo, RefundRequestEntity? refundRequest, RefundInfoEntity? refundInfo, DateTime createdAt, DateTime updatedAt, DateTime? acceptedAt, DateTime? cancelledAt, DateTime? refundedAt
});


@override $PaymentInfoEntityCopyWith<$Res> get paymentInfo;@override $RefundRequestEntityCopyWith<$Res>? get refundRequest;@override $RefundInfoEntityCopyWith<$Res>? get refundInfo;

}
/// @nodoc
class __$OrderEntityCopyWithImpl<$Res>
    implements _$OrderEntityCopyWith<$Res> {
  __$OrderEntityCopyWithImpl(this._self, this._then);

  final _OrderEntity _self;
  final $Res Function(_OrderEntity) _then;

/// Create a copy of OrderEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? storeId = null,Object? storeName = null,Object? brandId = freezed,Object? items = null,Object? subtotal = null,Object? discount = freezed,Object? totalPrice = null,Object? status = null,Object? paymentInfo = null,Object? refundRequest = freezed,Object? refundInfo = freezed,Object? createdAt = null,Object? updatedAt = null,Object? acceptedAt = freezed,Object? cancelledAt = freezed,Object? refundedAt = freezed,}) {
  return _then(_OrderEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,storeName: null == storeName ? _self.storeName : storeName // ignore: cast_nullable_to_non_nullable
as String,brandId: freezed == brandId ? _self.brandId : brandId // ignore: cast_nullable_to_non_nullable
as String?,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<OrderItemEntity>,subtotal: null == subtotal ? _self.subtotal : subtotal // ignore: cast_nullable_to_non_nullable
as int,discount: freezed == discount ? _self.discount : discount // ignore: cast_nullable_to_non_nullable
as int?,totalPrice: null == totalPrice ? _self.totalPrice : totalPrice // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as OrderStatus,paymentInfo: null == paymentInfo ? _self.paymentInfo : paymentInfo // ignore: cast_nullable_to_non_nullable
as PaymentInfoEntity,refundRequest: freezed == refundRequest ? _self.refundRequest : refundRequest // ignore: cast_nullable_to_non_nullable
as RefundRequestEntity?,refundInfo: freezed == refundInfo ? _self.refundInfo : refundInfo // ignore: cast_nullable_to_non_nullable
as RefundInfoEntity?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,acceptedAt: freezed == acceptedAt ? _self.acceptedAt : acceptedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancelledAt: freezed == cancelledAt ? _self.cancelledAt : cancelledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,refundedAt: freezed == refundedAt ? _self.refundedAt : refundedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of OrderEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PaymentInfoEntityCopyWith<$Res> get paymentInfo {
  
  return $PaymentInfoEntityCopyWith<$Res>(_self.paymentInfo, (value) {
    return _then(_self.copyWith(paymentInfo: value));
  });
}/// Create a copy of OrderEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RefundRequestEntityCopyWith<$Res>? get refundRequest {
    if (_self.refundRequest == null) {
    return null;
  }

  return $RefundRequestEntityCopyWith<$Res>(_self.refundRequest!, (value) {
    return _then(_self.copyWith(refundRequest: value));
  });
}/// Create a copy of OrderEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RefundInfoEntityCopyWith<$Res>? get refundInfo {
    if (_self.refundInfo == null) {
    return null;
  }

  return $RefundInfoEntityCopyWith<$Res>(_self.refundInfo!, (value) {
    return _then(_self.copyWith(refundInfo: value));
  });
}
}

// dart format on

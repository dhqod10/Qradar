// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'order_log_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$OrderLogItem {

 String get menuItemId; String get menuItemName; int get quantity; List<SelectedOption> get optionsSnapshot; int get lineTotal;
/// Create a copy of OrderLogItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderLogItemCopyWith<OrderLogItem> get copyWith => _$OrderLogItemCopyWithImpl<OrderLogItem>(this as OrderLogItem, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrderLogItem&&(identical(other.menuItemId, menuItemId) || other.menuItemId == menuItemId)&&(identical(other.menuItemName, menuItemName) || other.menuItemName == menuItemName)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&const DeepCollectionEquality().equals(other.optionsSnapshot, optionsSnapshot)&&(identical(other.lineTotal, lineTotal) || other.lineTotal == lineTotal));
}


@override
int get hashCode => Object.hash(runtimeType,menuItemId,menuItemName,quantity,const DeepCollectionEquality().hash(optionsSnapshot),lineTotal);

@override
String toString() {
  return 'OrderLogItem(menuItemId: $menuItemId, menuItemName: $menuItemName, quantity: $quantity, optionsSnapshot: $optionsSnapshot, lineTotal: $lineTotal)';
}


}

/// @nodoc
abstract mixin class $OrderLogItemCopyWith<$Res>  {
  factory $OrderLogItemCopyWith(OrderLogItem value, $Res Function(OrderLogItem) _then) = _$OrderLogItemCopyWithImpl;
@useResult
$Res call({
 String menuItemId, String menuItemName, int quantity, List<SelectedOption> optionsSnapshot, int lineTotal
});




}
/// @nodoc
class _$OrderLogItemCopyWithImpl<$Res>
    implements $OrderLogItemCopyWith<$Res> {
  _$OrderLogItemCopyWithImpl(this._self, this._then);

  final OrderLogItem _self;
  final $Res Function(OrderLogItem) _then;

/// Create a copy of OrderLogItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? menuItemId = null,Object? menuItemName = null,Object? quantity = null,Object? optionsSnapshot = null,Object? lineTotal = null,}) {
  return _then(_self.copyWith(
menuItemId: null == menuItemId ? _self.menuItemId : menuItemId // ignore: cast_nullable_to_non_nullable
as String,menuItemName: null == menuItemName ? _self.menuItemName : menuItemName // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,optionsSnapshot: null == optionsSnapshot ? _self.optionsSnapshot : optionsSnapshot // ignore: cast_nullable_to_non_nullable
as List<SelectedOption>,lineTotal: null == lineTotal ? _self.lineTotal : lineTotal // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [OrderLogItem].
extension OrderLogItemPatterns on OrderLogItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrderLogItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrderLogItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrderLogItem value)  $default,){
final _that = this;
switch (_that) {
case _OrderLogItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrderLogItem value)?  $default,){
final _that = this;
switch (_that) {
case _OrderLogItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String menuItemId,  String menuItemName,  int quantity,  List<SelectedOption> optionsSnapshot,  int lineTotal)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrderLogItem() when $default != null:
return $default(_that.menuItemId,_that.menuItemName,_that.quantity,_that.optionsSnapshot,_that.lineTotal);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String menuItemId,  String menuItemName,  int quantity,  List<SelectedOption> optionsSnapshot,  int lineTotal)  $default,) {final _that = this;
switch (_that) {
case _OrderLogItem():
return $default(_that.menuItemId,_that.menuItemName,_that.quantity,_that.optionsSnapshot,_that.lineTotal);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String menuItemId,  String menuItemName,  int quantity,  List<SelectedOption> optionsSnapshot,  int lineTotal)?  $default,) {final _that = this;
switch (_that) {
case _OrderLogItem() when $default != null:
return $default(_that.menuItemId,_that.menuItemName,_that.quantity,_that.optionsSnapshot,_that.lineTotal);case _:
  return null;

}
}

}

/// @nodoc


class _OrderLogItem implements OrderLogItem {
  const _OrderLogItem({required this.menuItemId, required this.menuItemName, required this.quantity, final  List<SelectedOption> optionsSnapshot = const <SelectedOption>[], required this.lineTotal}): _optionsSnapshot = optionsSnapshot;
  

@override final  String menuItemId;
@override final  String menuItemName;
@override final  int quantity;
 final  List<SelectedOption> _optionsSnapshot;
@override@JsonKey() List<SelectedOption> get optionsSnapshot {
  if (_optionsSnapshot is EqualUnmodifiableListView) return _optionsSnapshot;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_optionsSnapshot);
}

@override final  int lineTotal;

/// Create a copy of OrderLogItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderLogItemCopyWith<_OrderLogItem> get copyWith => __$OrderLogItemCopyWithImpl<_OrderLogItem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrderLogItem&&(identical(other.menuItemId, menuItemId) || other.menuItemId == menuItemId)&&(identical(other.menuItemName, menuItemName) || other.menuItemName == menuItemName)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&const DeepCollectionEquality().equals(other._optionsSnapshot, _optionsSnapshot)&&(identical(other.lineTotal, lineTotal) || other.lineTotal == lineTotal));
}


@override
int get hashCode => Object.hash(runtimeType,menuItemId,menuItemName,quantity,const DeepCollectionEquality().hash(_optionsSnapshot),lineTotal);

@override
String toString() {
  return 'OrderLogItem(menuItemId: $menuItemId, menuItemName: $menuItemName, quantity: $quantity, optionsSnapshot: $optionsSnapshot, lineTotal: $lineTotal)';
}


}

/// @nodoc
abstract mixin class _$OrderLogItemCopyWith<$Res> implements $OrderLogItemCopyWith<$Res> {
  factory _$OrderLogItemCopyWith(_OrderLogItem value, $Res Function(_OrderLogItem) _then) = __$OrderLogItemCopyWithImpl;
@override @useResult
$Res call({
 String menuItemId, String menuItemName, int quantity, List<SelectedOption> optionsSnapshot, int lineTotal
});




}
/// @nodoc
class __$OrderLogItemCopyWithImpl<$Res>
    implements _$OrderLogItemCopyWith<$Res> {
  __$OrderLogItemCopyWithImpl(this._self, this._then);

  final _OrderLogItem _self;
  final $Res Function(_OrderLogItem) _then;

/// Create a copy of OrderLogItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? menuItemId = null,Object? menuItemName = null,Object? quantity = null,Object? optionsSnapshot = null,Object? lineTotal = null,}) {
  return _then(_OrderLogItem(
menuItemId: null == menuItemId ? _self.menuItemId : menuItemId // ignore: cast_nullable_to_non_nullable
as String,menuItemName: null == menuItemName ? _self.menuItemName : menuItemName // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,optionsSnapshot: null == optionsSnapshot ? _self._optionsSnapshot : optionsSnapshot // ignore: cast_nullable_to_non_nullable
as List<SelectedOption>,lineTotal: null == lineTotal ? _self.lineTotal : lineTotal // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$OrderLogEntity {

 String get id; String get userId; String get storeId; String get storeName; List<OrderLogItem> get items; int get total; DateTime get paidAt; String get paymentMethod;
/// Create a copy of OrderLogEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderLogEntityCopyWith<OrderLogEntity> get copyWith => _$OrderLogEntityCopyWithImpl<OrderLogEntity>(this as OrderLogEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrderLogEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.storeName, storeName) || other.storeName == storeName)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.total, total) || other.total == total)&&(identical(other.paidAt, paidAt) || other.paidAt == paidAt)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod));
}


@override
int get hashCode => Object.hash(runtimeType,id,userId,storeId,storeName,const DeepCollectionEquality().hash(items),total,paidAt,paymentMethod);

@override
String toString() {
  return 'OrderLogEntity(id: $id, userId: $userId, storeId: $storeId, storeName: $storeName, items: $items, total: $total, paidAt: $paidAt, paymentMethod: $paymentMethod)';
}


}

/// @nodoc
abstract mixin class $OrderLogEntityCopyWith<$Res>  {
  factory $OrderLogEntityCopyWith(OrderLogEntity value, $Res Function(OrderLogEntity) _then) = _$OrderLogEntityCopyWithImpl;
@useResult
$Res call({
 String id, String userId, String storeId, String storeName, List<OrderLogItem> items, int total, DateTime paidAt, String paymentMethod
});




}
/// @nodoc
class _$OrderLogEntityCopyWithImpl<$Res>
    implements $OrderLogEntityCopyWith<$Res> {
  _$OrderLogEntityCopyWithImpl(this._self, this._then);

  final OrderLogEntity _self;
  final $Res Function(OrderLogEntity) _then;

/// Create a copy of OrderLogEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? storeId = null,Object? storeName = null,Object? items = null,Object? total = null,Object? paidAt = null,Object? paymentMethod = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,storeName: null == storeName ? _self.storeName : storeName // ignore: cast_nullable_to_non_nullable
as String,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<OrderLogItem>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,paidAt: null == paidAt ? _self.paidAt : paidAt // ignore: cast_nullable_to_non_nullable
as DateTime,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [OrderLogEntity].
extension OrderLogEntityPatterns on OrderLogEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrderLogEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrderLogEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrderLogEntity value)  $default,){
final _that = this;
switch (_that) {
case _OrderLogEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrderLogEntity value)?  $default,){
final _that = this;
switch (_that) {
case _OrderLogEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String userId,  String storeId,  String storeName,  List<OrderLogItem> items,  int total,  DateTime paidAt,  String paymentMethod)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrderLogEntity() when $default != null:
return $default(_that.id,_that.userId,_that.storeId,_that.storeName,_that.items,_that.total,_that.paidAt,_that.paymentMethod);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String userId,  String storeId,  String storeName,  List<OrderLogItem> items,  int total,  DateTime paidAt,  String paymentMethod)  $default,) {final _that = this;
switch (_that) {
case _OrderLogEntity():
return $default(_that.id,_that.userId,_that.storeId,_that.storeName,_that.items,_that.total,_that.paidAt,_that.paymentMethod);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String userId,  String storeId,  String storeName,  List<OrderLogItem> items,  int total,  DateTime paidAt,  String paymentMethod)?  $default,) {final _that = this;
switch (_that) {
case _OrderLogEntity() when $default != null:
return $default(_that.id,_that.userId,_that.storeId,_that.storeName,_that.items,_that.total,_that.paidAt,_that.paymentMethod);case _:
  return null;

}
}

}

/// @nodoc


class _OrderLogEntity implements OrderLogEntity {
  const _OrderLogEntity({required this.id, required this.userId, required this.storeId, required this.storeName, final  List<OrderLogItem> items = const <OrderLogItem>[], required this.total, required this.paidAt, this.paymentMethod = ''}): _items = items;
  

@override final  String id;
@override final  String userId;
@override final  String storeId;
@override final  String storeName;
 final  List<OrderLogItem> _items;
@override@JsonKey() List<OrderLogItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  int total;
@override final  DateTime paidAt;
@override@JsonKey() final  String paymentMethod;

/// Create a copy of OrderLogEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderLogEntityCopyWith<_OrderLogEntity> get copyWith => __$OrderLogEntityCopyWithImpl<_OrderLogEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrderLogEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.storeName, storeName) || other.storeName == storeName)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.total, total) || other.total == total)&&(identical(other.paidAt, paidAt) || other.paidAt == paidAt)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod));
}


@override
int get hashCode => Object.hash(runtimeType,id,userId,storeId,storeName,const DeepCollectionEquality().hash(_items),total,paidAt,paymentMethod);

@override
String toString() {
  return 'OrderLogEntity(id: $id, userId: $userId, storeId: $storeId, storeName: $storeName, items: $items, total: $total, paidAt: $paidAt, paymentMethod: $paymentMethod)';
}


}

/// @nodoc
abstract mixin class _$OrderLogEntityCopyWith<$Res> implements $OrderLogEntityCopyWith<$Res> {
  factory _$OrderLogEntityCopyWith(_OrderLogEntity value, $Res Function(_OrderLogEntity) _then) = __$OrderLogEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String userId, String storeId, String storeName, List<OrderLogItem> items, int total, DateTime paidAt, String paymentMethod
});




}
/// @nodoc
class __$OrderLogEntityCopyWithImpl<$Res>
    implements _$OrderLogEntityCopyWith<$Res> {
  __$OrderLogEntityCopyWithImpl(this._self, this._then);

  final _OrderLogEntity _self;
  final $Res Function(_OrderLogEntity) _then;

/// Create a copy of OrderLogEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? storeId = null,Object? storeName = null,Object? items = null,Object? total = null,Object? paidAt = null,Object? paymentMethod = null,}) {
  return _then(_OrderLogEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,storeName: null == storeName ? _self.storeName : storeName // ignore: cast_nullable_to_non_nullable
as String,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<OrderLogItem>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,paidAt: null == paidAt ? _self.paidAt : paidAt // ignore: cast_nullable_to_non_nullable
as DateTime,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on

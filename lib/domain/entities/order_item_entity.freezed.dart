// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'order_item_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$OrderItemEntity {

 String get menuItemId; String get menuItemName; String get imageUrl; int get quantity; List<SelectedOption> get selectedOptions; int get unitPriceWithOptions; int get lineTotal;
/// Create a copy of OrderItemEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderItemEntityCopyWith<OrderItemEntity> get copyWith => _$OrderItemEntityCopyWithImpl<OrderItemEntity>(this as OrderItemEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrderItemEntity&&(identical(other.menuItemId, menuItemId) || other.menuItemId == menuItemId)&&(identical(other.menuItemName, menuItemName) || other.menuItemName == menuItemName)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&const DeepCollectionEquality().equals(other.selectedOptions, selectedOptions)&&(identical(other.unitPriceWithOptions, unitPriceWithOptions) || other.unitPriceWithOptions == unitPriceWithOptions)&&(identical(other.lineTotal, lineTotal) || other.lineTotal == lineTotal));
}


@override
int get hashCode => Object.hash(runtimeType,menuItemId,menuItemName,imageUrl,quantity,const DeepCollectionEquality().hash(selectedOptions),unitPriceWithOptions,lineTotal);

@override
String toString() {
  return 'OrderItemEntity(menuItemId: $menuItemId, menuItemName: $menuItemName, imageUrl: $imageUrl, quantity: $quantity, selectedOptions: $selectedOptions, unitPriceWithOptions: $unitPriceWithOptions, lineTotal: $lineTotal)';
}


}

/// @nodoc
abstract mixin class $OrderItemEntityCopyWith<$Res>  {
  factory $OrderItemEntityCopyWith(OrderItemEntity value, $Res Function(OrderItemEntity) _then) = _$OrderItemEntityCopyWithImpl;
@useResult
$Res call({
 String menuItemId, String menuItemName, String imageUrl, int quantity, List<SelectedOption> selectedOptions, int unitPriceWithOptions, int lineTotal
});




}
/// @nodoc
class _$OrderItemEntityCopyWithImpl<$Res>
    implements $OrderItemEntityCopyWith<$Res> {
  _$OrderItemEntityCopyWithImpl(this._self, this._then);

  final OrderItemEntity _self;
  final $Res Function(OrderItemEntity) _then;

/// Create a copy of OrderItemEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? menuItemId = null,Object? menuItemName = null,Object? imageUrl = null,Object? quantity = null,Object? selectedOptions = null,Object? unitPriceWithOptions = null,Object? lineTotal = null,}) {
  return _then(_self.copyWith(
menuItemId: null == menuItemId ? _self.menuItemId : menuItemId // ignore: cast_nullable_to_non_nullable
as String,menuItemName: null == menuItemName ? _self.menuItemName : menuItemName // ignore: cast_nullable_to_non_nullable
as String,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,selectedOptions: null == selectedOptions ? _self.selectedOptions : selectedOptions // ignore: cast_nullable_to_non_nullable
as List<SelectedOption>,unitPriceWithOptions: null == unitPriceWithOptions ? _self.unitPriceWithOptions : unitPriceWithOptions // ignore: cast_nullable_to_non_nullable
as int,lineTotal: null == lineTotal ? _self.lineTotal : lineTotal // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [OrderItemEntity].
extension OrderItemEntityPatterns on OrderItemEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrderItemEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrderItemEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrderItemEntity value)  $default,){
final _that = this;
switch (_that) {
case _OrderItemEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrderItemEntity value)?  $default,){
final _that = this;
switch (_that) {
case _OrderItemEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String menuItemId,  String menuItemName,  String imageUrl,  int quantity,  List<SelectedOption> selectedOptions,  int unitPriceWithOptions,  int lineTotal)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrderItemEntity() when $default != null:
return $default(_that.menuItemId,_that.menuItemName,_that.imageUrl,_that.quantity,_that.selectedOptions,_that.unitPriceWithOptions,_that.lineTotal);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String menuItemId,  String menuItemName,  String imageUrl,  int quantity,  List<SelectedOption> selectedOptions,  int unitPriceWithOptions,  int lineTotal)  $default,) {final _that = this;
switch (_that) {
case _OrderItemEntity():
return $default(_that.menuItemId,_that.menuItemName,_that.imageUrl,_that.quantity,_that.selectedOptions,_that.unitPriceWithOptions,_that.lineTotal);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String menuItemId,  String menuItemName,  String imageUrl,  int quantity,  List<SelectedOption> selectedOptions,  int unitPriceWithOptions,  int lineTotal)?  $default,) {final _that = this;
switch (_that) {
case _OrderItemEntity() when $default != null:
return $default(_that.menuItemId,_that.menuItemName,_that.imageUrl,_that.quantity,_that.selectedOptions,_that.unitPriceWithOptions,_that.lineTotal);case _:
  return null;

}
}

}

/// @nodoc


class _OrderItemEntity implements OrderItemEntity {
  const _OrderItemEntity({required this.menuItemId, required this.menuItemName, this.imageUrl = '', required this.quantity, final  List<SelectedOption> selectedOptions = const <SelectedOption>[], required this.unitPriceWithOptions, required this.lineTotal}): _selectedOptions = selectedOptions;
  

@override final  String menuItemId;
@override final  String menuItemName;
@override@JsonKey() final  String imageUrl;
@override final  int quantity;
 final  List<SelectedOption> _selectedOptions;
@override@JsonKey() List<SelectedOption> get selectedOptions {
  if (_selectedOptions is EqualUnmodifiableListView) return _selectedOptions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_selectedOptions);
}

@override final  int unitPriceWithOptions;
@override final  int lineTotal;

/// Create a copy of OrderItemEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderItemEntityCopyWith<_OrderItemEntity> get copyWith => __$OrderItemEntityCopyWithImpl<_OrderItemEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrderItemEntity&&(identical(other.menuItemId, menuItemId) || other.menuItemId == menuItemId)&&(identical(other.menuItemName, menuItemName) || other.menuItemName == menuItemName)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&const DeepCollectionEquality().equals(other._selectedOptions, _selectedOptions)&&(identical(other.unitPriceWithOptions, unitPriceWithOptions) || other.unitPriceWithOptions == unitPriceWithOptions)&&(identical(other.lineTotal, lineTotal) || other.lineTotal == lineTotal));
}


@override
int get hashCode => Object.hash(runtimeType,menuItemId,menuItemName,imageUrl,quantity,const DeepCollectionEquality().hash(_selectedOptions),unitPriceWithOptions,lineTotal);

@override
String toString() {
  return 'OrderItemEntity(menuItemId: $menuItemId, menuItemName: $menuItemName, imageUrl: $imageUrl, quantity: $quantity, selectedOptions: $selectedOptions, unitPriceWithOptions: $unitPriceWithOptions, lineTotal: $lineTotal)';
}


}

/// @nodoc
abstract mixin class _$OrderItemEntityCopyWith<$Res> implements $OrderItemEntityCopyWith<$Res> {
  factory _$OrderItemEntityCopyWith(_OrderItemEntity value, $Res Function(_OrderItemEntity) _then) = __$OrderItemEntityCopyWithImpl;
@override @useResult
$Res call({
 String menuItemId, String menuItemName, String imageUrl, int quantity, List<SelectedOption> selectedOptions, int unitPriceWithOptions, int lineTotal
});




}
/// @nodoc
class __$OrderItemEntityCopyWithImpl<$Res>
    implements _$OrderItemEntityCopyWith<$Res> {
  __$OrderItemEntityCopyWithImpl(this._self, this._then);

  final _OrderItemEntity _self;
  final $Res Function(_OrderItemEntity) _then;

/// Create a copy of OrderItemEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? menuItemId = null,Object? menuItemName = null,Object? imageUrl = null,Object? quantity = null,Object? selectedOptions = null,Object? unitPriceWithOptions = null,Object? lineTotal = null,}) {
  return _then(_OrderItemEntity(
menuItemId: null == menuItemId ? _self.menuItemId : menuItemId // ignore: cast_nullable_to_non_nullable
as String,menuItemName: null == menuItemName ? _self.menuItemName : menuItemName // ignore: cast_nullable_to_non_nullable
as String,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,selectedOptions: null == selectedOptions ? _self._selectedOptions : selectedOptions // ignore: cast_nullable_to_non_nullable
as List<SelectedOption>,unitPriceWithOptions: null == unitPriceWithOptions ? _self.unitPriceWithOptions : unitPriceWithOptions // ignore: cast_nullable_to_non_nullable
as int,lineTotal: null == lineTotal ? _self.lineTotal : lineTotal // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on

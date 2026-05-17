// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payment_info_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PaymentInfoEntity {

 PaymentMethod get method; PaymentChannel get channel; String get paymentKey; String? get transactionId; String? get receiptUrl; DateTime get approvedAt; int get amount; String? get cardCompany; String? get cardNumberMasked; String? get easyPayProvider;
/// Create a copy of PaymentInfoEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentInfoEntityCopyWith<PaymentInfoEntity> get copyWith => _$PaymentInfoEntityCopyWithImpl<PaymentInfoEntity>(this as PaymentInfoEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentInfoEntity&&(identical(other.method, method) || other.method == method)&&(identical(other.channel, channel) || other.channel == channel)&&(identical(other.paymentKey, paymentKey) || other.paymentKey == paymentKey)&&(identical(other.transactionId, transactionId) || other.transactionId == transactionId)&&(identical(other.receiptUrl, receiptUrl) || other.receiptUrl == receiptUrl)&&(identical(other.approvedAt, approvedAt) || other.approvedAt == approvedAt)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.cardCompany, cardCompany) || other.cardCompany == cardCompany)&&(identical(other.cardNumberMasked, cardNumberMasked) || other.cardNumberMasked == cardNumberMasked)&&(identical(other.easyPayProvider, easyPayProvider) || other.easyPayProvider == easyPayProvider));
}


@override
int get hashCode => Object.hash(runtimeType,method,channel,paymentKey,transactionId,receiptUrl,approvedAt,amount,cardCompany,cardNumberMasked,easyPayProvider);

@override
String toString() {
  return 'PaymentInfoEntity(method: $method, channel: $channel, paymentKey: $paymentKey, transactionId: $transactionId, receiptUrl: $receiptUrl, approvedAt: $approvedAt, amount: $amount, cardCompany: $cardCompany, cardNumberMasked: $cardNumberMasked, easyPayProvider: $easyPayProvider)';
}


}

/// @nodoc
abstract mixin class $PaymentInfoEntityCopyWith<$Res>  {
  factory $PaymentInfoEntityCopyWith(PaymentInfoEntity value, $Res Function(PaymentInfoEntity) _then) = _$PaymentInfoEntityCopyWithImpl;
@useResult
$Res call({
 PaymentMethod method, PaymentChannel channel, String paymentKey, String? transactionId, String? receiptUrl, DateTime approvedAt, int amount, String? cardCompany, String? cardNumberMasked, String? easyPayProvider
});




}
/// @nodoc
class _$PaymentInfoEntityCopyWithImpl<$Res>
    implements $PaymentInfoEntityCopyWith<$Res> {
  _$PaymentInfoEntityCopyWithImpl(this._self, this._then);

  final PaymentInfoEntity _self;
  final $Res Function(PaymentInfoEntity) _then;

/// Create a copy of PaymentInfoEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? method = null,Object? channel = null,Object? paymentKey = null,Object? transactionId = freezed,Object? receiptUrl = freezed,Object? approvedAt = null,Object? amount = null,Object? cardCompany = freezed,Object? cardNumberMasked = freezed,Object? easyPayProvider = freezed,}) {
  return _then(_self.copyWith(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as PaymentMethod,channel: null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as PaymentChannel,paymentKey: null == paymentKey ? _self.paymentKey : paymentKey // ignore: cast_nullable_to_non_nullable
as String,transactionId: freezed == transactionId ? _self.transactionId : transactionId // ignore: cast_nullable_to_non_nullable
as String?,receiptUrl: freezed == receiptUrl ? _self.receiptUrl : receiptUrl // ignore: cast_nullable_to_non_nullable
as String?,approvedAt: null == approvedAt ? _self.approvedAt : approvedAt // ignore: cast_nullable_to_non_nullable
as DateTime,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,cardCompany: freezed == cardCompany ? _self.cardCompany : cardCompany // ignore: cast_nullable_to_non_nullable
as String?,cardNumberMasked: freezed == cardNumberMasked ? _self.cardNumberMasked : cardNumberMasked // ignore: cast_nullable_to_non_nullable
as String?,easyPayProvider: freezed == easyPayProvider ? _self.easyPayProvider : easyPayProvider // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PaymentInfoEntity].
extension PaymentInfoEntityPatterns on PaymentInfoEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentInfoEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentInfoEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentInfoEntity value)  $default,){
final _that = this;
switch (_that) {
case _PaymentInfoEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentInfoEntity value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentInfoEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PaymentMethod method,  PaymentChannel channel,  String paymentKey,  String? transactionId,  String? receiptUrl,  DateTime approvedAt,  int amount,  String? cardCompany,  String? cardNumberMasked,  String? easyPayProvider)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentInfoEntity() when $default != null:
return $default(_that.method,_that.channel,_that.paymentKey,_that.transactionId,_that.receiptUrl,_that.approvedAt,_that.amount,_that.cardCompany,_that.cardNumberMasked,_that.easyPayProvider);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PaymentMethod method,  PaymentChannel channel,  String paymentKey,  String? transactionId,  String? receiptUrl,  DateTime approvedAt,  int amount,  String? cardCompany,  String? cardNumberMasked,  String? easyPayProvider)  $default,) {final _that = this;
switch (_that) {
case _PaymentInfoEntity():
return $default(_that.method,_that.channel,_that.paymentKey,_that.transactionId,_that.receiptUrl,_that.approvedAt,_that.amount,_that.cardCompany,_that.cardNumberMasked,_that.easyPayProvider);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PaymentMethod method,  PaymentChannel channel,  String paymentKey,  String? transactionId,  String? receiptUrl,  DateTime approvedAt,  int amount,  String? cardCompany,  String? cardNumberMasked,  String? easyPayProvider)?  $default,) {final _that = this;
switch (_that) {
case _PaymentInfoEntity() when $default != null:
return $default(_that.method,_that.channel,_that.paymentKey,_that.transactionId,_that.receiptUrl,_that.approvedAt,_that.amount,_that.cardCompany,_that.cardNumberMasked,_that.easyPayProvider);case _:
  return null;

}
}

}

/// @nodoc


class _PaymentInfoEntity implements PaymentInfoEntity {
  const _PaymentInfoEntity({required this.method, required this.channel, required this.paymentKey, this.transactionId, this.receiptUrl, required this.approvedAt, required this.amount, this.cardCompany, this.cardNumberMasked, this.easyPayProvider});
  

@override final  PaymentMethod method;
@override final  PaymentChannel channel;
@override final  String paymentKey;
@override final  String? transactionId;
@override final  String? receiptUrl;
@override final  DateTime approvedAt;
@override final  int amount;
@override final  String? cardCompany;
@override final  String? cardNumberMasked;
@override final  String? easyPayProvider;

/// Create a copy of PaymentInfoEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentInfoEntityCopyWith<_PaymentInfoEntity> get copyWith => __$PaymentInfoEntityCopyWithImpl<_PaymentInfoEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentInfoEntity&&(identical(other.method, method) || other.method == method)&&(identical(other.channel, channel) || other.channel == channel)&&(identical(other.paymentKey, paymentKey) || other.paymentKey == paymentKey)&&(identical(other.transactionId, transactionId) || other.transactionId == transactionId)&&(identical(other.receiptUrl, receiptUrl) || other.receiptUrl == receiptUrl)&&(identical(other.approvedAt, approvedAt) || other.approvedAt == approvedAt)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.cardCompany, cardCompany) || other.cardCompany == cardCompany)&&(identical(other.cardNumberMasked, cardNumberMasked) || other.cardNumberMasked == cardNumberMasked)&&(identical(other.easyPayProvider, easyPayProvider) || other.easyPayProvider == easyPayProvider));
}


@override
int get hashCode => Object.hash(runtimeType,method,channel,paymentKey,transactionId,receiptUrl,approvedAt,amount,cardCompany,cardNumberMasked,easyPayProvider);

@override
String toString() {
  return 'PaymentInfoEntity(method: $method, channel: $channel, paymentKey: $paymentKey, transactionId: $transactionId, receiptUrl: $receiptUrl, approvedAt: $approvedAt, amount: $amount, cardCompany: $cardCompany, cardNumberMasked: $cardNumberMasked, easyPayProvider: $easyPayProvider)';
}


}

/// @nodoc
abstract mixin class _$PaymentInfoEntityCopyWith<$Res> implements $PaymentInfoEntityCopyWith<$Res> {
  factory _$PaymentInfoEntityCopyWith(_PaymentInfoEntity value, $Res Function(_PaymentInfoEntity) _then) = __$PaymentInfoEntityCopyWithImpl;
@override @useResult
$Res call({
 PaymentMethod method, PaymentChannel channel, String paymentKey, String? transactionId, String? receiptUrl, DateTime approvedAt, int amount, String? cardCompany, String? cardNumberMasked, String? easyPayProvider
});




}
/// @nodoc
class __$PaymentInfoEntityCopyWithImpl<$Res>
    implements _$PaymentInfoEntityCopyWith<$Res> {
  __$PaymentInfoEntityCopyWithImpl(this._self, this._then);

  final _PaymentInfoEntity _self;
  final $Res Function(_PaymentInfoEntity) _then;

/// Create a copy of PaymentInfoEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? method = null,Object? channel = null,Object? paymentKey = null,Object? transactionId = freezed,Object? receiptUrl = freezed,Object? approvedAt = null,Object? amount = null,Object? cardCompany = freezed,Object? cardNumberMasked = freezed,Object? easyPayProvider = freezed,}) {
  return _then(_PaymentInfoEntity(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as PaymentMethod,channel: null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as PaymentChannel,paymentKey: null == paymentKey ? _self.paymentKey : paymentKey // ignore: cast_nullable_to_non_nullable
as String,transactionId: freezed == transactionId ? _self.transactionId : transactionId // ignore: cast_nullable_to_non_nullable
as String?,receiptUrl: freezed == receiptUrl ? _self.receiptUrl : receiptUrl // ignore: cast_nullable_to_non_nullable
as String?,approvedAt: null == approvedAt ? _self.approvedAt : approvedAt // ignore: cast_nullable_to_non_nullable
as DateTime,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,cardCompany: freezed == cardCompany ? _self.cardCompany : cardCompany // ignore: cast_nullable_to_non_nullable
as String?,cardNumberMasked: freezed == cardNumberMasked ? _self.cardNumberMasked : cardNumberMasked // ignore: cast_nullable_to_non_nullable
as String?,easyPayProvider: freezed == easyPayProvider ? _self.easyPayProvider : easyPayProvider // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'quick_reorder_candidate_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$QuickReorderCandidateEntity {

 String get orderLogId; String get storeId; String get storeName;/// 메뉴 요약 — 첫 메뉴명 + 추가 항목 수. 예: `"아메리카노 외 1"`, 단일이면 `"아메리카노"`.
 String get summary; int get total; DateTime get paidAt;/// 카트 채울 때 items 그대로 사용.
 OrderLogEntity get sourceLog;
/// Create a copy of QuickReorderCandidateEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuickReorderCandidateEntityCopyWith<QuickReorderCandidateEntity> get copyWith => _$QuickReorderCandidateEntityCopyWithImpl<QuickReorderCandidateEntity>(this as QuickReorderCandidateEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuickReorderCandidateEntity&&(identical(other.orderLogId, orderLogId) || other.orderLogId == orderLogId)&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.storeName, storeName) || other.storeName == storeName)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.total, total) || other.total == total)&&(identical(other.paidAt, paidAt) || other.paidAt == paidAt)&&(identical(other.sourceLog, sourceLog) || other.sourceLog == sourceLog));
}


@override
int get hashCode => Object.hash(runtimeType,orderLogId,storeId,storeName,summary,total,paidAt,sourceLog);

@override
String toString() {
  return 'QuickReorderCandidateEntity(orderLogId: $orderLogId, storeId: $storeId, storeName: $storeName, summary: $summary, total: $total, paidAt: $paidAt, sourceLog: $sourceLog)';
}


}

/// @nodoc
abstract mixin class $QuickReorderCandidateEntityCopyWith<$Res>  {
  factory $QuickReorderCandidateEntityCopyWith(QuickReorderCandidateEntity value, $Res Function(QuickReorderCandidateEntity) _then) = _$QuickReorderCandidateEntityCopyWithImpl;
@useResult
$Res call({
 String orderLogId, String storeId, String storeName, String summary, int total, DateTime paidAt, OrderLogEntity sourceLog
});


$OrderLogEntityCopyWith<$Res> get sourceLog;

}
/// @nodoc
class _$QuickReorderCandidateEntityCopyWithImpl<$Res>
    implements $QuickReorderCandidateEntityCopyWith<$Res> {
  _$QuickReorderCandidateEntityCopyWithImpl(this._self, this._then);

  final QuickReorderCandidateEntity _self;
  final $Res Function(QuickReorderCandidateEntity) _then;

/// Create a copy of QuickReorderCandidateEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? orderLogId = null,Object? storeId = null,Object? storeName = null,Object? summary = null,Object? total = null,Object? paidAt = null,Object? sourceLog = null,}) {
  return _then(_self.copyWith(
orderLogId: null == orderLogId ? _self.orderLogId : orderLogId // ignore: cast_nullable_to_non_nullable
as String,storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,storeName: null == storeName ? _self.storeName : storeName // ignore: cast_nullable_to_non_nullable
as String,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,paidAt: null == paidAt ? _self.paidAt : paidAt // ignore: cast_nullable_to_non_nullable
as DateTime,sourceLog: null == sourceLog ? _self.sourceLog : sourceLog // ignore: cast_nullable_to_non_nullable
as OrderLogEntity,
  ));
}
/// Create a copy of QuickReorderCandidateEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OrderLogEntityCopyWith<$Res> get sourceLog {
  
  return $OrderLogEntityCopyWith<$Res>(_self.sourceLog, (value) {
    return _then(_self.copyWith(sourceLog: value));
  });
}
}


/// Adds pattern-matching-related methods to [QuickReorderCandidateEntity].
extension QuickReorderCandidateEntityPatterns on QuickReorderCandidateEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QuickReorderCandidateEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QuickReorderCandidateEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QuickReorderCandidateEntity value)  $default,){
final _that = this;
switch (_that) {
case _QuickReorderCandidateEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QuickReorderCandidateEntity value)?  $default,){
final _that = this;
switch (_that) {
case _QuickReorderCandidateEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String orderLogId,  String storeId,  String storeName,  String summary,  int total,  DateTime paidAt,  OrderLogEntity sourceLog)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QuickReorderCandidateEntity() when $default != null:
return $default(_that.orderLogId,_that.storeId,_that.storeName,_that.summary,_that.total,_that.paidAt,_that.sourceLog);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String orderLogId,  String storeId,  String storeName,  String summary,  int total,  DateTime paidAt,  OrderLogEntity sourceLog)  $default,) {final _that = this;
switch (_that) {
case _QuickReorderCandidateEntity():
return $default(_that.orderLogId,_that.storeId,_that.storeName,_that.summary,_that.total,_that.paidAt,_that.sourceLog);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String orderLogId,  String storeId,  String storeName,  String summary,  int total,  DateTime paidAt,  OrderLogEntity sourceLog)?  $default,) {final _that = this;
switch (_that) {
case _QuickReorderCandidateEntity() when $default != null:
return $default(_that.orderLogId,_that.storeId,_that.storeName,_that.summary,_that.total,_that.paidAt,_that.sourceLog);case _:
  return null;

}
}

}

/// @nodoc


class _QuickReorderCandidateEntity implements QuickReorderCandidateEntity {
  const _QuickReorderCandidateEntity({required this.orderLogId, required this.storeId, required this.storeName, required this.summary, required this.total, required this.paidAt, required this.sourceLog});
  

@override final  String orderLogId;
@override final  String storeId;
@override final  String storeName;
/// 메뉴 요약 — 첫 메뉴명 + 추가 항목 수. 예: `"아메리카노 외 1"`, 단일이면 `"아메리카노"`.
@override final  String summary;
@override final  int total;
@override final  DateTime paidAt;
/// 카트 채울 때 items 그대로 사용.
@override final  OrderLogEntity sourceLog;

/// Create a copy of QuickReorderCandidateEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuickReorderCandidateEntityCopyWith<_QuickReorderCandidateEntity> get copyWith => __$QuickReorderCandidateEntityCopyWithImpl<_QuickReorderCandidateEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QuickReorderCandidateEntity&&(identical(other.orderLogId, orderLogId) || other.orderLogId == orderLogId)&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.storeName, storeName) || other.storeName == storeName)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.total, total) || other.total == total)&&(identical(other.paidAt, paidAt) || other.paidAt == paidAt)&&(identical(other.sourceLog, sourceLog) || other.sourceLog == sourceLog));
}


@override
int get hashCode => Object.hash(runtimeType,orderLogId,storeId,storeName,summary,total,paidAt,sourceLog);

@override
String toString() {
  return 'QuickReorderCandidateEntity(orderLogId: $orderLogId, storeId: $storeId, storeName: $storeName, summary: $summary, total: $total, paidAt: $paidAt, sourceLog: $sourceLog)';
}


}

/// @nodoc
abstract mixin class _$QuickReorderCandidateEntityCopyWith<$Res> implements $QuickReorderCandidateEntityCopyWith<$Res> {
  factory _$QuickReorderCandidateEntityCopyWith(_QuickReorderCandidateEntity value, $Res Function(_QuickReorderCandidateEntity) _then) = __$QuickReorderCandidateEntityCopyWithImpl;
@override @useResult
$Res call({
 String orderLogId, String storeId, String storeName, String summary, int total, DateTime paidAt, OrderLogEntity sourceLog
});


@override $OrderLogEntityCopyWith<$Res> get sourceLog;

}
/// @nodoc
class __$QuickReorderCandidateEntityCopyWithImpl<$Res>
    implements _$QuickReorderCandidateEntityCopyWith<$Res> {
  __$QuickReorderCandidateEntityCopyWithImpl(this._self, this._then);

  final _QuickReorderCandidateEntity _self;
  final $Res Function(_QuickReorderCandidateEntity) _then;

/// Create a copy of QuickReorderCandidateEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? orderLogId = null,Object? storeId = null,Object? storeName = null,Object? summary = null,Object? total = null,Object? paidAt = null,Object? sourceLog = null,}) {
  return _then(_QuickReorderCandidateEntity(
orderLogId: null == orderLogId ? _self.orderLogId : orderLogId // ignore: cast_nullable_to_non_nullable
as String,storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,storeName: null == storeName ? _self.storeName : storeName // ignore: cast_nullable_to_non_nullable
as String,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,paidAt: null == paidAt ? _self.paidAt : paidAt // ignore: cast_nullable_to_non_nullable
as DateTime,sourceLog: null == sourceLog ? _self.sourceLog : sourceLog // ignore: cast_nullable_to_non_nullable
as OrderLogEntity,
  ));
}

/// Create a copy of QuickReorderCandidateEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OrderLogEntityCopyWith<$Res> get sourceLog {
  
  return $OrderLogEntityCopyWith<$Res>(_self.sourceLog, (value) {
    return _then(_self.copyWith(sourceLog: value));
  });
}
}

// dart format on

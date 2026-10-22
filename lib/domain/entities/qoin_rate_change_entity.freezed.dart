// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'qoin_rate_change_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$QoinRateChangeEntity {

 String get id; QoinRateScope get scope; String get targetId;/// 변경 당시 대상 이름 (박제). 옛 이력은 빈 문자열일 수 있다.
 String get targetName; QoinRateField get field; double? get beforeRate; double? get afterRate; bool? get beforeEnabled; bool? get afterEnabled;/// null = Console 등 out-of-band 편집 (행위자 알 수 없음).
 String? get changedBy; DateTime? get changedAt; String? get reason; QoinRateChangeSource get source; QoinRateChangeOp get op;// ── 일괄 적용 (op == bulkApply) ───────────────────────────────────────────
 QoinBulkMode? get bulkMode; QoinBulkStatus? get status;/// 서버가 실제로 센 값 (클라이언트 미리보기가 아니다).
 int? get affectedCount; int? get clearedCount; int? get preservedCount; int? get processedCount;/// 처리 대상(개별 설정이 있던) 매장 수.
 int? get totalCount; DateTime? get lastProgressAt;
/// Create a copy of QoinRateChangeEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QoinRateChangeEntityCopyWith<QoinRateChangeEntity> get copyWith => _$QoinRateChangeEntityCopyWithImpl<QoinRateChangeEntity>(this as QoinRateChangeEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QoinRateChangeEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.targetId, targetId) || other.targetId == targetId)&&(identical(other.targetName, targetName) || other.targetName == targetName)&&(identical(other.field, field) || other.field == field)&&(identical(other.beforeRate, beforeRate) || other.beforeRate == beforeRate)&&(identical(other.afterRate, afterRate) || other.afterRate == afterRate)&&(identical(other.beforeEnabled, beforeEnabled) || other.beforeEnabled == beforeEnabled)&&(identical(other.afterEnabled, afterEnabled) || other.afterEnabled == afterEnabled)&&(identical(other.changedBy, changedBy) || other.changedBy == changedBy)&&(identical(other.changedAt, changedAt) || other.changedAt == changedAt)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.source, source) || other.source == source)&&(identical(other.op, op) || other.op == op)&&(identical(other.bulkMode, bulkMode) || other.bulkMode == bulkMode)&&(identical(other.status, status) || other.status == status)&&(identical(other.affectedCount, affectedCount) || other.affectedCount == affectedCount)&&(identical(other.clearedCount, clearedCount) || other.clearedCount == clearedCount)&&(identical(other.preservedCount, preservedCount) || other.preservedCount == preservedCount)&&(identical(other.processedCount, processedCount) || other.processedCount == processedCount)&&(identical(other.totalCount, totalCount) || other.totalCount == totalCount)&&(identical(other.lastProgressAt, lastProgressAt) || other.lastProgressAt == lastProgressAt));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,scope,targetId,targetName,field,beforeRate,afterRate,beforeEnabled,afterEnabled,changedBy,changedAt,reason,source,op,bulkMode,status,affectedCount,clearedCount,preservedCount,processedCount,totalCount,lastProgressAt]);

@override
String toString() {
  return 'QoinRateChangeEntity(id: $id, scope: $scope, targetId: $targetId, targetName: $targetName, field: $field, beforeRate: $beforeRate, afterRate: $afterRate, beforeEnabled: $beforeEnabled, afterEnabled: $afterEnabled, changedBy: $changedBy, changedAt: $changedAt, reason: $reason, source: $source, op: $op, bulkMode: $bulkMode, status: $status, affectedCount: $affectedCount, clearedCount: $clearedCount, preservedCount: $preservedCount, processedCount: $processedCount, totalCount: $totalCount, lastProgressAt: $lastProgressAt)';
}


}

/// @nodoc
abstract mixin class $QoinRateChangeEntityCopyWith<$Res>  {
  factory $QoinRateChangeEntityCopyWith(QoinRateChangeEntity value, $Res Function(QoinRateChangeEntity) _then) = _$QoinRateChangeEntityCopyWithImpl;
@useResult
$Res call({
 String id, QoinRateScope scope, String targetId, String targetName, QoinRateField field, double? beforeRate, double? afterRate, bool? beforeEnabled, bool? afterEnabled, String? changedBy, DateTime? changedAt, String? reason, QoinRateChangeSource source, QoinRateChangeOp op, QoinBulkMode? bulkMode, QoinBulkStatus? status, int? affectedCount, int? clearedCount, int? preservedCount, int? processedCount, int? totalCount, DateTime? lastProgressAt
});




}
/// @nodoc
class _$QoinRateChangeEntityCopyWithImpl<$Res>
    implements $QoinRateChangeEntityCopyWith<$Res> {
  _$QoinRateChangeEntityCopyWithImpl(this._self, this._then);

  final QoinRateChangeEntity _self;
  final $Res Function(QoinRateChangeEntity) _then;

/// Create a copy of QoinRateChangeEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? scope = null,Object? targetId = null,Object? targetName = null,Object? field = null,Object? beforeRate = freezed,Object? afterRate = freezed,Object? beforeEnabled = freezed,Object? afterEnabled = freezed,Object? changedBy = freezed,Object? changedAt = freezed,Object? reason = freezed,Object? source = null,Object? op = null,Object? bulkMode = freezed,Object? status = freezed,Object? affectedCount = freezed,Object? clearedCount = freezed,Object? preservedCount = freezed,Object? processedCount = freezed,Object? totalCount = freezed,Object? lastProgressAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as QoinRateScope,targetId: null == targetId ? _self.targetId : targetId // ignore: cast_nullable_to_non_nullable
as String,targetName: null == targetName ? _self.targetName : targetName // ignore: cast_nullable_to_non_nullable
as String,field: null == field ? _self.field : field // ignore: cast_nullable_to_non_nullable
as QoinRateField,beforeRate: freezed == beforeRate ? _self.beforeRate : beforeRate // ignore: cast_nullable_to_non_nullable
as double?,afterRate: freezed == afterRate ? _self.afterRate : afterRate // ignore: cast_nullable_to_non_nullable
as double?,beforeEnabled: freezed == beforeEnabled ? _self.beforeEnabled : beforeEnabled // ignore: cast_nullable_to_non_nullable
as bool?,afterEnabled: freezed == afterEnabled ? _self.afterEnabled : afterEnabled // ignore: cast_nullable_to_non_nullable
as bool?,changedBy: freezed == changedBy ? _self.changedBy : changedBy // ignore: cast_nullable_to_non_nullable
as String?,changedAt: freezed == changedAt ? _self.changedAt : changedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as QoinRateChangeSource,op: null == op ? _self.op : op // ignore: cast_nullable_to_non_nullable
as QoinRateChangeOp,bulkMode: freezed == bulkMode ? _self.bulkMode : bulkMode // ignore: cast_nullable_to_non_nullable
as QoinBulkMode?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as QoinBulkStatus?,affectedCount: freezed == affectedCount ? _self.affectedCount : affectedCount // ignore: cast_nullable_to_non_nullable
as int?,clearedCount: freezed == clearedCount ? _self.clearedCount : clearedCount // ignore: cast_nullable_to_non_nullable
as int?,preservedCount: freezed == preservedCount ? _self.preservedCount : preservedCount // ignore: cast_nullable_to_non_nullable
as int?,processedCount: freezed == processedCount ? _self.processedCount : processedCount // ignore: cast_nullable_to_non_nullable
as int?,totalCount: freezed == totalCount ? _self.totalCount : totalCount // ignore: cast_nullable_to_non_nullable
as int?,lastProgressAt: freezed == lastProgressAt ? _self.lastProgressAt : lastProgressAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [QoinRateChangeEntity].
extension QoinRateChangeEntityPatterns on QoinRateChangeEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QoinRateChangeEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QoinRateChangeEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QoinRateChangeEntity value)  $default,){
final _that = this;
switch (_that) {
case _QoinRateChangeEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QoinRateChangeEntity value)?  $default,){
final _that = this;
switch (_that) {
case _QoinRateChangeEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  QoinRateScope scope,  String targetId,  String targetName,  QoinRateField field,  double? beforeRate,  double? afterRate,  bool? beforeEnabled,  bool? afterEnabled,  String? changedBy,  DateTime? changedAt,  String? reason,  QoinRateChangeSource source,  QoinRateChangeOp op,  QoinBulkMode? bulkMode,  QoinBulkStatus? status,  int? affectedCount,  int? clearedCount,  int? preservedCount,  int? processedCount,  int? totalCount,  DateTime? lastProgressAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QoinRateChangeEntity() when $default != null:
return $default(_that.id,_that.scope,_that.targetId,_that.targetName,_that.field,_that.beforeRate,_that.afterRate,_that.beforeEnabled,_that.afterEnabled,_that.changedBy,_that.changedAt,_that.reason,_that.source,_that.op,_that.bulkMode,_that.status,_that.affectedCount,_that.clearedCount,_that.preservedCount,_that.processedCount,_that.totalCount,_that.lastProgressAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  QoinRateScope scope,  String targetId,  String targetName,  QoinRateField field,  double? beforeRate,  double? afterRate,  bool? beforeEnabled,  bool? afterEnabled,  String? changedBy,  DateTime? changedAt,  String? reason,  QoinRateChangeSource source,  QoinRateChangeOp op,  QoinBulkMode? bulkMode,  QoinBulkStatus? status,  int? affectedCount,  int? clearedCount,  int? preservedCount,  int? processedCount,  int? totalCount,  DateTime? lastProgressAt)  $default,) {final _that = this;
switch (_that) {
case _QoinRateChangeEntity():
return $default(_that.id,_that.scope,_that.targetId,_that.targetName,_that.field,_that.beforeRate,_that.afterRate,_that.beforeEnabled,_that.afterEnabled,_that.changedBy,_that.changedAt,_that.reason,_that.source,_that.op,_that.bulkMode,_that.status,_that.affectedCount,_that.clearedCount,_that.preservedCount,_that.processedCount,_that.totalCount,_that.lastProgressAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  QoinRateScope scope,  String targetId,  String targetName,  QoinRateField field,  double? beforeRate,  double? afterRate,  bool? beforeEnabled,  bool? afterEnabled,  String? changedBy,  DateTime? changedAt,  String? reason,  QoinRateChangeSource source,  QoinRateChangeOp op,  QoinBulkMode? bulkMode,  QoinBulkStatus? status,  int? affectedCount,  int? clearedCount,  int? preservedCount,  int? processedCount,  int? totalCount,  DateTime? lastProgressAt)?  $default,) {final _that = this;
switch (_that) {
case _QoinRateChangeEntity() when $default != null:
return $default(_that.id,_that.scope,_that.targetId,_that.targetName,_that.field,_that.beforeRate,_that.afterRate,_that.beforeEnabled,_that.afterEnabled,_that.changedBy,_that.changedAt,_that.reason,_that.source,_that.op,_that.bulkMode,_that.status,_that.affectedCount,_that.clearedCount,_that.preservedCount,_that.processedCount,_that.totalCount,_that.lastProgressAt);case _:
  return null;

}
}

}

/// @nodoc


class _QoinRateChangeEntity extends QoinRateChangeEntity {
  const _QoinRateChangeEntity({required this.id, required this.scope, required this.targetId, this.targetName = '', required this.field, this.beforeRate, this.afterRate, this.beforeEnabled, this.afterEnabled, this.changedBy, this.changedAt, this.reason, required this.source, required this.op, this.bulkMode, this.status, this.affectedCount, this.clearedCount, this.preservedCount, this.processedCount, this.totalCount, this.lastProgressAt}): super._();
  

@override final  String id;
@override final  QoinRateScope scope;
@override final  String targetId;
/// 변경 당시 대상 이름 (박제). 옛 이력은 빈 문자열일 수 있다.
@override@JsonKey() final  String targetName;
@override final  QoinRateField field;
@override final  double? beforeRate;
@override final  double? afterRate;
@override final  bool? beforeEnabled;
@override final  bool? afterEnabled;
/// null = Console 등 out-of-band 편집 (행위자 알 수 없음).
@override final  String? changedBy;
@override final  DateTime? changedAt;
@override final  String? reason;
@override final  QoinRateChangeSource source;
@override final  QoinRateChangeOp op;
// ── 일괄 적용 (op == bulkApply) ───────────────────────────────────────────
@override final  QoinBulkMode? bulkMode;
@override final  QoinBulkStatus? status;
/// 서버가 실제로 센 값 (클라이언트 미리보기가 아니다).
@override final  int? affectedCount;
@override final  int? clearedCount;
@override final  int? preservedCount;
@override final  int? processedCount;
/// 처리 대상(개별 설정이 있던) 매장 수.
@override final  int? totalCount;
@override final  DateTime? lastProgressAt;

/// Create a copy of QoinRateChangeEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QoinRateChangeEntityCopyWith<_QoinRateChangeEntity> get copyWith => __$QoinRateChangeEntityCopyWithImpl<_QoinRateChangeEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QoinRateChangeEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.targetId, targetId) || other.targetId == targetId)&&(identical(other.targetName, targetName) || other.targetName == targetName)&&(identical(other.field, field) || other.field == field)&&(identical(other.beforeRate, beforeRate) || other.beforeRate == beforeRate)&&(identical(other.afterRate, afterRate) || other.afterRate == afterRate)&&(identical(other.beforeEnabled, beforeEnabled) || other.beforeEnabled == beforeEnabled)&&(identical(other.afterEnabled, afterEnabled) || other.afterEnabled == afterEnabled)&&(identical(other.changedBy, changedBy) || other.changedBy == changedBy)&&(identical(other.changedAt, changedAt) || other.changedAt == changedAt)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.source, source) || other.source == source)&&(identical(other.op, op) || other.op == op)&&(identical(other.bulkMode, bulkMode) || other.bulkMode == bulkMode)&&(identical(other.status, status) || other.status == status)&&(identical(other.affectedCount, affectedCount) || other.affectedCount == affectedCount)&&(identical(other.clearedCount, clearedCount) || other.clearedCount == clearedCount)&&(identical(other.preservedCount, preservedCount) || other.preservedCount == preservedCount)&&(identical(other.processedCount, processedCount) || other.processedCount == processedCount)&&(identical(other.totalCount, totalCount) || other.totalCount == totalCount)&&(identical(other.lastProgressAt, lastProgressAt) || other.lastProgressAt == lastProgressAt));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,scope,targetId,targetName,field,beforeRate,afterRate,beforeEnabled,afterEnabled,changedBy,changedAt,reason,source,op,bulkMode,status,affectedCount,clearedCount,preservedCount,processedCount,totalCount,lastProgressAt]);

@override
String toString() {
  return 'QoinRateChangeEntity(id: $id, scope: $scope, targetId: $targetId, targetName: $targetName, field: $field, beforeRate: $beforeRate, afterRate: $afterRate, beforeEnabled: $beforeEnabled, afterEnabled: $afterEnabled, changedBy: $changedBy, changedAt: $changedAt, reason: $reason, source: $source, op: $op, bulkMode: $bulkMode, status: $status, affectedCount: $affectedCount, clearedCount: $clearedCount, preservedCount: $preservedCount, processedCount: $processedCount, totalCount: $totalCount, lastProgressAt: $lastProgressAt)';
}


}

/// @nodoc
abstract mixin class _$QoinRateChangeEntityCopyWith<$Res> implements $QoinRateChangeEntityCopyWith<$Res> {
  factory _$QoinRateChangeEntityCopyWith(_QoinRateChangeEntity value, $Res Function(_QoinRateChangeEntity) _then) = __$QoinRateChangeEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, QoinRateScope scope, String targetId, String targetName, QoinRateField field, double? beforeRate, double? afterRate, bool? beforeEnabled, bool? afterEnabled, String? changedBy, DateTime? changedAt, String? reason, QoinRateChangeSource source, QoinRateChangeOp op, QoinBulkMode? bulkMode, QoinBulkStatus? status, int? affectedCount, int? clearedCount, int? preservedCount, int? processedCount, int? totalCount, DateTime? lastProgressAt
});




}
/// @nodoc
class __$QoinRateChangeEntityCopyWithImpl<$Res>
    implements _$QoinRateChangeEntityCopyWith<$Res> {
  __$QoinRateChangeEntityCopyWithImpl(this._self, this._then);

  final _QoinRateChangeEntity _self;
  final $Res Function(_QoinRateChangeEntity) _then;

/// Create a copy of QoinRateChangeEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? scope = null,Object? targetId = null,Object? targetName = null,Object? field = null,Object? beforeRate = freezed,Object? afterRate = freezed,Object? beforeEnabled = freezed,Object? afterEnabled = freezed,Object? changedBy = freezed,Object? changedAt = freezed,Object? reason = freezed,Object? source = null,Object? op = null,Object? bulkMode = freezed,Object? status = freezed,Object? affectedCount = freezed,Object? clearedCount = freezed,Object? preservedCount = freezed,Object? processedCount = freezed,Object? totalCount = freezed,Object? lastProgressAt = freezed,}) {
  return _then(_QoinRateChangeEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as QoinRateScope,targetId: null == targetId ? _self.targetId : targetId // ignore: cast_nullable_to_non_nullable
as String,targetName: null == targetName ? _self.targetName : targetName // ignore: cast_nullable_to_non_nullable
as String,field: null == field ? _self.field : field // ignore: cast_nullable_to_non_nullable
as QoinRateField,beforeRate: freezed == beforeRate ? _self.beforeRate : beforeRate // ignore: cast_nullable_to_non_nullable
as double?,afterRate: freezed == afterRate ? _self.afterRate : afterRate // ignore: cast_nullable_to_non_nullable
as double?,beforeEnabled: freezed == beforeEnabled ? _self.beforeEnabled : beforeEnabled // ignore: cast_nullable_to_non_nullable
as bool?,afterEnabled: freezed == afterEnabled ? _self.afterEnabled : afterEnabled // ignore: cast_nullable_to_non_nullable
as bool?,changedBy: freezed == changedBy ? _self.changedBy : changedBy // ignore: cast_nullable_to_non_nullable
as String?,changedAt: freezed == changedAt ? _self.changedAt : changedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as QoinRateChangeSource,op: null == op ? _self.op : op // ignore: cast_nullable_to_non_nullable
as QoinRateChangeOp,bulkMode: freezed == bulkMode ? _self.bulkMode : bulkMode // ignore: cast_nullable_to_non_nullable
as QoinBulkMode?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as QoinBulkStatus?,affectedCount: freezed == affectedCount ? _self.affectedCount : affectedCount // ignore: cast_nullable_to_non_nullable
as int?,clearedCount: freezed == clearedCount ? _self.clearedCount : clearedCount // ignore: cast_nullable_to_non_nullable
as int?,preservedCount: freezed == preservedCount ? _self.preservedCount : preservedCount // ignore: cast_nullable_to_non_nullable
as int?,processedCount: freezed == processedCount ? _self.processedCount : processedCount // ignore: cast_nullable_to_non_nullable
as int?,totalCount: freezed == totalCount ? _self.totalCount : totalCount // ignore: cast_nullable_to_non_nullable
as int?,lastProgressAt: freezed == lastProgressAt ? _self.lastProgressAt : lastProgressAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on

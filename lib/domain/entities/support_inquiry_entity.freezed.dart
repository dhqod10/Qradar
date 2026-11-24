// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'support_inquiry_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SupportInquiryAnswer {

 String get body; String get answeredBy; DateTime? get answeredAt;
/// Create a copy of SupportInquiryAnswer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SupportInquiryAnswerCopyWith<SupportInquiryAnswer> get copyWith => _$SupportInquiryAnswerCopyWithImpl<SupportInquiryAnswer>(this as SupportInquiryAnswer, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SupportInquiryAnswer&&(identical(other.body, body) || other.body == body)&&(identical(other.answeredBy, answeredBy) || other.answeredBy == answeredBy)&&(identical(other.answeredAt, answeredAt) || other.answeredAt == answeredAt));
}


@override
int get hashCode => Object.hash(runtimeType,body,answeredBy,answeredAt);

@override
String toString() {
  return 'SupportInquiryAnswer(body: $body, answeredBy: $answeredBy, answeredAt: $answeredAt)';
}


}

/// @nodoc
abstract mixin class $SupportInquiryAnswerCopyWith<$Res>  {
  factory $SupportInquiryAnswerCopyWith(SupportInquiryAnswer value, $Res Function(SupportInquiryAnswer) _then) = _$SupportInquiryAnswerCopyWithImpl;
@useResult
$Res call({
 String body, String answeredBy, DateTime? answeredAt
});




}
/// @nodoc
class _$SupportInquiryAnswerCopyWithImpl<$Res>
    implements $SupportInquiryAnswerCopyWith<$Res> {
  _$SupportInquiryAnswerCopyWithImpl(this._self, this._then);

  final SupportInquiryAnswer _self;
  final $Res Function(SupportInquiryAnswer) _then;

/// Create a copy of SupportInquiryAnswer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? body = null,Object? answeredBy = null,Object? answeredAt = freezed,}) {
  return _then(_self.copyWith(
body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,answeredBy: null == answeredBy ? _self.answeredBy : answeredBy // ignore: cast_nullable_to_non_nullable
as String,answeredAt: freezed == answeredAt ? _self.answeredAt : answeredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [SupportInquiryAnswer].
extension SupportInquiryAnswerPatterns on SupportInquiryAnswer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SupportInquiryAnswer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SupportInquiryAnswer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SupportInquiryAnswer value)  $default,){
final _that = this;
switch (_that) {
case _SupportInquiryAnswer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SupportInquiryAnswer value)?  $default,){
final _that = this;
switch (_that) {
case _SupportInquiryAnswer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String body,  String answeredBy,  DateTime? answeredAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SupportInquiryAnswer() when $default != null:
return $default(_that.body,_that.answeredBy,_that.answeredAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String body,  String answeredBy,  DateTime? answeredAt)  $default,) {final _that = this;
switch (_that) {
case _SupportInquiryAnswer():
return $default(_that.body,_that.answeredBy,_that.answeredAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String body,  String answeredBy,  DateTime? answeredAt)?  $default,) {final _that = this;
switch (_that) {
case _SupportInquiryAnswer() when $default != null:
return $default(_that.body,_that.answeredBy,_that.answeredAt);case _:
  return null;

}
}

}

/// @nodoc


class _SupportInquiryAnswer implements SupportInquiryAnswer {
  const _SupportInquiryAnswer({required this.body, required this.answeredBy, this.answeredAt});
  

@override final  String body;
@override final  String answeredBy;
@override final  DateTime? answeredAt;

/// Create a copy of SupportInquiryAnswer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SupportInquiryAnswerCopyWith<_SupportInquiryAnswer> get copyWith => __$SupportInquiryAnswerCopyWithImpl<_SupportInquiryAnswer>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SupportInquiryAnswer&&(identical(other.body, body) || other.body == body)&&(identical(other.answeredBy, answeredBy) || other.answeredBy == answeredBy)&&(identical(other.answeredAt, answeredAt) || other.answeredAt == answeredAt));
}


@override
int get hashCode => Object.hash(runtimeType,body,answeredBy,answeredAt);

@override
String toString() {
  return 'SupportInquiryAnswer(body: $body, answeredBy: $answeredBy, answeredAt: $answeredAt)';
}


}

/// @nodoc
abstract mixin class _$SupportInquiryAnswerCopyWith<$Res> implements $SupportInquiryAnswerCopyWith<$Res> {
  factory _$SupportInquiryAnswerCopyWith(_SupportInquiryAnswer value, $Res Function(_SupportInquiryAnswer) _then) = __$SupportInquiryAnswerCopyWithImpl;
@override @useResult
$Res call({
 String body, String answeredBy, DateTime? answeredAt
});




}
/// @nodoc
class __$SupportInquiryAnswerCopyWithImpl<$Res>
    implements _$SupportInquiryAnswerCopyWith<$Res> {
  __$SupportInquiryAnswerCopyWithImpl(this._self, this._then);

  final _SupportInquiryAnswer _self;
  final $Res Function(_SupportInquiryAnswer) _then;

/// Create a copy of SupportInquiryAnswer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? body = null,Object? answeredBy = null,Object? answeredAt = freezed,}) {
  return _then(_SupportInquiryAnswer(
body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,answeredBy: null == answeredBy ? _self.answeredBy : answeredBy // ignore: cast_nullable_to_non_nullable
as String,answeredAt: freezed == answeredAt ? _self.answeredAt : answeredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
mixin _$SupportInquiryOrderSnapshot {

 String get storeId; String get storeName; int? get pickupNumber; int get totalPrice; String get status; DateTime? get createdAt;
/// Create a copy of SupportInquiryOrderSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SupportInquiryOrderSnapshotCopyWith<SupportInquiryOrderSnapshot> get copyWith => _$SupportInquiryOrderSnapshotCopyWithImpl<SupportInquiryOrderSnapshot>(this as SupportInquiryOrderSnapshot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SupportInquiryOrderSnapshot&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.storeName, storeName) || other.storeName == storeName)&&(identical(other.pickupNumber, pickupNumber) || other.pickupNumber == pickupNumber)&&(identical(other.totalPrice, totalPrice) || other.totalPrice == totalPrice)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,storeId,storeName,pickupNumber,totalPrice,status,createdAt);

@override
String toString() {
  return 'SupportInquiryOrderSnapshot(storeId: $storeId, storeName: $storeName, pickupNumber: $pickupNumber, totalPrice: $totalPrice, status: $status, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $SupportInquiryOrderSnapshotCopyWith<$Res>  {
  factory $SupportInquiryOrderSnapshotCopyWith(SupportInquiryOrderSnapshot value, $Res Function(SupportInquiryOrderSnapshot) _then) = _$SupportInquiryOrderSnapshotCopyWithImpl;
@useResult
$Res call({
 String storeId, String storeName, int? pickupNumber, int totalPrice, String status, DateTime? createdAt
});




}
/// @nodoc
class _$SupportInquiryOrderSnapshotCopyWithImpl<$Res>
    implements $SupportInquiryOrderSnapshotCopyWith<$Res> {
  _$SupportInquiryOrderSnapshotCopyWithImpl(this._self, this._then);

  final SupportInquiryOrderSnapshot _self;
  final $Res Function(SupportInquiryOrderSnapshot) _then;

/// Create a copy of SupportInquiryOrderSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? storeId = null,Object? storeName = null,Object? pickupNumber = freezed,Object? totalPrice = null,Object? status = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,storeName: null == storeName ? _self.storeName : storeName // ignore: cast_nullable_to_non_nullable
as String,pickupNumber: freezed == pickupNumber ? _self.pickupNumber : pickupNumber // ignore: cast_nullable_to_non_nullable
as int?,totalPrice: null == totalPrice ? _self.totalPrice : totalPrice // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [SupportInquiryOrderSnapshot].
extension SupportInquiryOrderSnapshotPatterns on SupportInquiryOrderSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SupportInquiryOrderSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SupportInquiryOrderSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SupportInquiryOrderSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _SupportInquiryOrderSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SupportInquiryOrderSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _SupportInquiryOrderSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String storeId,  String storeName,  int? pickupNumber,  int totalPrice,  String status,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SupportInquiryOrderSnapshot() when $default != null:
return $default(_that.storeId,_that.storeName,_that.pickupNumber,_that.totalPrice,_that.status,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String storeId,  String storeName,  int? pickupNumber,  int totalPrice,  String status,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _SupportInquiryOrderSnapshot():
return $default(_that.storeId,_that.storeName,_that.pickupNumber,_that.totalPrice,_that.status,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String storeId,  String storeName,  int? pickupNumber,  int totalPrice,  String status,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _SupportInquiryOrderSnapshot() when $default != null:
return $default(_that.storeId,_that.storeName,_that.pickupNumber,_that.totalPrice,_that.status,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _SupportInquiryOrderSnapshot implements SupportInquiryOrderSnapshot {
  const _SupportInquiryOrderSnapshot({required this.storeId, required this.storeName, this.pickupNumber, required this.totalPrice, this.status = '', this.createdAt});
  

@override final  String storeId;
@override final  String storeName;
@override final  int? pickupNumber;
@override final  int totalPrice;
@override@JsonKey() final  String status;
@override final  DateTime? createdAt;

/// Create a copy of SupportInquiryOrderSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SupportInquiryOrderSnapshotCopyWith<_SupportInquiryOrderSnapshot> get copyWith => __$SupportInquiryOrderSnapshotCopyWithImpl<_SupportInquiryOrderSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SupportInquiryOrderSnapshot&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.storeName, storeName) || other.storeName == storeName)&&(identical(other.pickupNumber, pickupNumber) || other.pickupNumber == pickupNumber)&&(identical(other.totalPrice, totalPrice) || other.totalPrice == totalPrice)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,storeId,storeName,pickupNumber,totalPrice,status,createdAt);

@override
String toString() {
  return 'SupportInquiryOrderSnapshot(storeId: $storeId, storeName: $storeName, pickupNumber: $pickupNumber, totalPrice: $totalPrice, status: $status, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$SupportInquiryOrderSnapshotCopyWith<$Res> implements $SupportInquiryOrderSnapshotCopyWith<$Res> {
  factory _$SupportInquiryOrderSnapshotCopyWith(_SupportInquiryOrderSnapshot value, $Res Function(_SupportInquiryOrderSnapshot) _then) = __$SupportInquiryOrderSnapshotCopyWithImpl;
@override @useResult
$Res call({
 String storeId, String storeName, int? pickupNumber, int totalPrice, String status, DateTime? createdAt
});




}
/// @nodoc
class __$SupportInquiryOrderSnapshotCopyWithImpl<$Res>
    implements _$SupportInquiryOrderSnapshotCopyWith<$Res> {
  __$SupportInquiryOrderSnapshotCopyWithImpl(this._self, this._then);

  final _SupportInquiryOrderSnapshot _self;
  final $Res Function(_SupportInquiryOrderSnapshot) _then;

/// Create a copy of SupportInquiryOrderSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? storeId = null,Object? storeName = null,Object? pickupNumber = freezed,Object? totalPrice = null,Object? status = null,Object? createdAt = freezed,}) {
  return _then(_SupportInquiryOrderSnapshot(
storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,storeName: null == storeName ? _self.storeName : storeName // ignore: cast_nullable_to_non_nullable
as String,pickupNumber: freezed == pickupNumber ? _self.pickupNumber : pickupNumber // ignore: cast_nullable_to_non_nullable
as int?,totalPrice: null == totalPrice ? _self.totalPrice : totalPrice // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
mixin _$SupportInquiryEntity {

 String get id; String get userId; SupportInquiryCategory get category; String get title; String get body; List<String> get imageUrls; String? get orderId; SupportInquiryOrderSnapshot? get orderSnapshot; SupportInquiryStatus get status; SupportInquiryAnswer? get answer; DateTime? get answerReadAt; DateTime get createdAt; DateTime? get updatedAt; DateTime? get withdrawnAt; DateTime? get closedAt; String? get closedReason; bool get authorDeleted;
/// Create a copy of SupportInquiryEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SupportInquiryEntityCopyWith<SupportInquiryEntity> get copyWith => _$SupportInquiryEntityCopyWithImpl<SupportInquiryEntity>(this as SupportInquiryEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SupportInquiryEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.category, category) || other.category == category)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&const DeepCollectionEquality().equals(other.imageUrls, imageUrls)&&(identical(other.orderId, orderId) || other.orderId == orderId)&&(identical(other.orderSnapshot, orderSnapshot) || other.orderSnapshot == orderSnapshot)&&(identical(other.status, status) || other.status == status)&&(identical(other.answer, answer) || other.answer == answer)&&(identical(other.answerReadAt, answerReadAt) || other.answerReadAt == answerReadAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.withdrawnAt, withdrawnAt) || other.withdrawnAt == withdrawnAt)&&(identical(other.closedAt, closedAt) || other.closedAt == closedAt)&&(identical(other.closedReason, closedReason) || other.closedReason == closedReason)&&(identical(other.authorDeleted, authorDeleted) || other.authorDeleted == authorDeleted));
}


@override
int get hashCode => Object.hash(runtimeType,id,userId,category,title,body,const DeepCollectionEquality().hash(imageUrls),orderId,orderSnapshot,status,answer,answerReadAt,createdAt,updatedAt,withdrawnAt,closedAt,closedReason,authorDeleted);

@override
String toString() {
  return 'SupportInquiryEntity(id: $id, userId: $userId, category: $category, title: $title, body: $body, imageUrls: $imageUrls, orderId: $orderId, orderSnapshot: $orderSnapshot, status: $status, answer: $answer, answerReadAt: $answerReadAt, createdAt: $createdAt, updatedAt: $updatedAt, withdrawnAt: $withdrawnAt, closedAt: $closedAt, closedReason: $closedReason, authorDeleted: $authorDeleted)';
}


}

/// @nodoc
abstract mixin class $SupportInquiryEntityCopyWith<$Res>  {
  factory $SupportInquiryEntityCopyWith(SupportInquiryEntity value, $Res Function(SupportInquiryEntity) _then) = _$SupportInquiryEntityCopyWithImpl;
@useResult
$Res call({
 String id, String userId, SupportInquiryCategory category, String title, String body, List<String> imageUrls, String? orderId, SupportInquiryOrderSnapshot? orderSnapshot, SupportInquiryStatus status, SupportInquiryAnswer? answer, DateTime? answerReadAt, DateTime createdAt, DateTime? updatedAt, DateTime? withdrawnAt, DateTime? closedAt, String? closedReason, bool authorDeleted
});


$SupportInquiryOrderSnapshotCopyWith<$Res>? get orderSnapshot;$SupportInquiryAnswerCopyWith<$Res>? get answer;

}
/// @nodoc
class _$SupportInquiryEntityCopyWithImpl<$Res>
    implements $SupportInquiryEntityCopyWith<$Res> {
  _$SupportInquiryEntityCopyWithImpl(this._self, this._then);

  final SupportInquiryEntity _self;
  final $Res Function(SupportInquiryEntity) _then;

/// Create a copy of SupportInquiryEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? category = null,Object? title = null,Object? body = null,Object? imageUrls = null,Object? orderId = freezed,Object? orderSnapshot = freezed,Object? status = null,Object? answer = freezed,Object? answerReadAt = freezed,Object? createdAt = null,Object? updatedAt = freezed,Object? withdrawnAt = freezed,Object? closedAt = freezed,Object? closedReason = freezed,Object? authorDeleted = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as SupportInquiryCategory,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,imageUrls: null == imageUrls ? _self.imageUrls : imageUrls // ignore: cast_nullable_to_non_nullable
as List<String>,orderId: freezed == orderId ? _self.orderId : orderId // ignore: cast_nullable_to_non_nullable
as String?,orderSnapshot: freezed == orderSnapshot ? _self.orderSnapshot : orderSnapshot // ignore: cast_nullable_to_non_nullable
as SupportInquiryOrderSnapshot?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SupportInquiryStatus,answer: freezed == answer ? _self.answer : answer // ignore: cast_nullable_to_non_nullable
as SupportInquiryAnswer?,answerReadAt: freezed == answerReadAt ? _self.answerReadAt : answerReadAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,withdrawnAt: freezed == withdrawnAt ? _self.withdrawnAt : withdrawnAt // ignore: cast_nullable_to_non_nullable
as DateTime?,closedAt: freezed == closedAt ? _self.closedAt : closedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,closedReason: freezed == closedReason ? _self.closedReason : closedReason // ignore: cast_nullable_to_non_nullable
as String?,authorDeleted: null == authorDeleted ? _self.authorDeleted : authorDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of SupportInquiryEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SupportInquiryOrderSnapshotCopyWith<$Res>? get orderSnapshot {
    if (_self.orderSnapshot == null) {
    return null;
  }

  return $SupportInquiryOrderSnapshotCopyWith<$Res>(_self.orderSnapshot!, (value) {
    return _then(_self.copyWith(orderSnapshot: value));
  });
}/// Create a copy of SupportInquiryEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SupportInquiryAnswerCopyWith<$Res>? get answer {
    if (_self.answer == null) {
    return null;
  }

  return $SupportInquiryAnswerCopyWith<$Res>(_self.answer!, (value) {
    return _then(_self.copyWith(answer: value));
  });
}
}


/// Adds pattern-matching-related methods to [SupportInquiryEntity].
extension SupportInquiryEntityPatterns on SupportInquiryEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SupportInquiryEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SupportInquiryEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SupportInquiryEntity value)  $default,){
final _that = this;
switch (_that) {
case _SupportInquiryEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SupportInquiryEntity value)?  $default,){
final _that = this;
switch (_that) {
case _SupportInquiryEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String userId,  SupportInquiryCategory category,  String title,  String body,  List<String> imageUrls,  String? orderId,  SupportInquiryOrderSnapshot? orderSnapshot,  SupportInquiryStatus status,  SupportInquiryAnswer? answer,  DateTime? answerReadAt,  DateTime createdAt,  DateTime? updatedAt,  DateTime? withdrawnAt,  DateTime? closedAt,  String? closedReason,  bool authorDeleted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SupportInquiryEntity() when $default != null:
return $default(_that.id,_that.userId,_that.category,_that.title,_that.body,_that.imageUrls,_that.orderId,_that.orderSnapshot,_that.status,_that.answer,_that.answerReadAt,_that.createdAt,_that.updatedAt,_that.withdrawnAt,_that.closedAt,_that.closedReason,_that.authorDeleted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String userId,  SupportInquiryCategory category,  String title,  String body,  List<String> imageUrls,  String? orderId,  SupportInquiryOrderSnapshot? orderSnapshot,  SupportInquiryStatus status,  SupportInquiryAnswer? answer,  DateTime? answerReadAt,  DateTime createdAt,  DateTime? updatedAt,  DateTime? withdrawnAt,  DateTime? closedAt,  String? closedReason,  bool authorDeleted)  $default,) {final _that = this;
switch (_that) {
case _SupportInquiryEntity():
return $default(_that.id,_that.userId,_that.category,_that.title,_that.body,_that.imageUrls,_that.orderId,_that.orderSnapshot,_that.status,_that.answer,_that.answerReadAt,_that.createdAt,_that.updatedAt,_that.withdrawnAt,_that.closedAt,_that.closedReason,_that.authorDeleted);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String userId,  SupportInquiryCategory category,  String title,  String body,  List<String> imageUrls,  String? orderId,  SupportInquiryOrderSnapshot? orderSnapshot,  SupportInquiryStatus status,  SupportInquiryAnswer? answer,  DateTime? answerReadAt,  DateTime createdAt,  DateTime? updatedAt,  DateTime? withdrawnAt,  DateTime? closedAt,  String? closedReason,  bool authorDeleted)?  $default,) {final _that = this;
switch (_that) {
case _SupportInquiryEntity() when $default != null:
return $default(_that.id,_that.userId,_that.category,_that.title,_that.body,_that.imageUrls,_that.orderId,_that.orderSnapshot,_that.status,_that.answer,_that.answerReadAt,_that.createdAt,_that.updatedAt,_that.withdrawnAt,_that.closedAt,_that.closedReason,_that.authorDeleted);case _:
  return null;

}
}

}

/// @nodoc


class _SupportInquiryEntity extends SupportInquiryEntity {
  const _SupportInquiryEntity({required this.id, required this.userId, required this.category, required this.title, required this.body, final  List<String> imageUrls = const <String>[], this.orderId, this.orderSnapshot, required this.status, this.answer, this.answerReadAt, required this.createdAt, this.updatedAt, this.withdrawnAt, this.closedAt, this.closedReason, this.authorDeleted = false}): _imageUrls = imageUrls,super._();
  

@override final  String id;
@override final  String userId;
@override final  SupportInquiryCategory category;
@override final  String title;
@override final  String body;
 final  List<String> _imageUrls;
@override@JsonKey() List<String> get imageUrls {
  if (_imageUrls is EqualUnmodifiableListView) return _imageUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_imageUrls);
}

@override final  String? orderId;
@override final  SupportInquiryOrderSnapshot? orderSnapshot;
@override final  SupportInquiryStatus status;
@override final  SupportInquiryAnswer? answer;
@override final  DateTime? answerReadAt;
@override final  DateTime createdAt;
@override final  DateTime? updatedAt;
@override final  DateTime? withdrawnAt;
@override final  DateTime? closedAt;
@override final  String? closedReason;
@override@JsonKey() final  bool authorDeleted;

/// Create a copy of SupportInquiryEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SupportInquiryEntityCopyWith<_SupportInquiryEntity> get copyWith => __$SupportInquiryEntityCopyWithImpl<_SupportInquiryEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SupportInquiryEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.category, category) || other.category == category)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&const DeepCollectionEquality().equals(other._imageUrls, _imageUrls)&&(identical(other.orderId, orderId) || other.orderId == orderId)&&(identical(other.orderSnapshot, orderSnapshot) || other.orderSnapshot == orderSnapshot)&&(identical(other.status, status) || other.status == status)&&(identical(other.answer, answer) || other.answer == answer)&&(identical(other.answerReadAt, answerReadAt) || other.answerReadAt == answerReadAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.withdrawnAt, withdrawnAt) || other.withdrawnAt == withdrawnAt)&&(identical(other.closedAt, closedAt) || other.closedAt == closedAt)&&(identical(other.closedReason, closedReason) || other.closedReason == closedReason)&&(identical(other.authorDeleted, authorDeleted) || other.authorDeleted == authorDeleted));
}


@override
int get hashCode => Object.hash(runtimeType,id,userId,category,title,body,const DeepCollectionEquality().hash(_imageUrls),orderId,orderSnapshot,status,answer,answerReadAt,createdAt,updatedAt,withdrawnAt,closedAt,closedReason,authorDeleted);

@override
String toString() {
  return 'SupportInquiryEntity(id: $id, userId: $userId, category: $category, title: $title, body: $body, imageUrls: $imageUrls, orderId: $orderId, orderSnapshot: $orderSnapshot, status: $status, answer: $answer, answerReadAt: $answerReadAt, createdAt: $createdAt, updatedAt: $updatedAt, withdrawnAt: $withdrawnAt, closedAt: $closedAt, closedReason: $closedReason, authorDeleted: $authorDeleted)';
}


}

/// @nodoc
abstract mixin class _$SupportInquiryEntityCopyWith<$Res> implements $SupportInquiryEntityCopyWith<$Res> {
  factory _$SupportInquiryEntityCopyWith(_SupportInquiryEntity value, $Res Function(_SupportInquiryEntity) _then) = __$SupportInquiryEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String userId, SupportInquiryCategory category, String title, String body, List<String> imageUrls, String? orderId, SupportInquiryOrderSnapshot? orderSnapshot, SupportInquiryStatus status, SupportInquiryAnswer? answer, DateTime? answerReadAt, DateTime createdAt, DateTime? updatedAt, DateTime? withdrawnAt, DateTime? closedAt, String? closedReason, bool authorDeleted
});


@override $SupportInquiryOrderSnapshotCopyWith<$Res>? get orderSnapshot;@override $SupportInquiryAnswerCopyWith<$Res>? get answer;

}
/// @nodoc
class __$SupportInquiryEntityCopyWithImpl<$Res>
    implements _$SupportInquiryEntityCopyWith<$Res> {
  __$SupportInquiryEntityCopyWithImpl(this._self, this._then);

  final _SupportInquiryEntity _self;
  final $Res Function(_SupportInquiryEntity) _then;

/// Create a copy of SupportInquiryEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? category = null,Object? title = null,Object? body = null,Object? imageUrls = null,Object? orderId = freezed,Object? orderSnapshot = freezed,Object? status = null,Object? answer = freezed,Object? answerReadAt = freezed,Object? createdAt = null,Object? updatedAt = freezed,Object? withdrawnAt = freezed,Object? closedAt = freezed,Object? closedReason = freezed,Object? authorDeleted = null,}) {
  return _then(_SupportInquiryEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as SupportInquiryCategory,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,imageUrls: null == imageUrls ? _self._imageUrls : imageUrls // ignore: cast_nullable_to_non_nullable
as List<String>,orderId: freezed == orderId ? _self.orderId : orderId // ignore: cast_nullable_to_non_nullable
as String?,orderSnapshot: freezed == orderSnapshot ? _self.orderSnapshot : orderSnapshot // ignore: cast_nullable_to_non_nullable
as SupportInquiryOrderSnapshot?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SupportInquiryStatus,answer: freezed == answer ? _self.answer : answer // ignore: cast_nullable_to_non_nullable
as SupportInquiryAnswer?,answerReadAt: freezed == answerReadAt ? _self.answerReadAt : answerReadAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,withdrawnAt: freezed == withdrawnAt ? _self.withdrawnAt : withdrawnAt // ignore: cast_nullable_to_non_nullable
as DateTime?,closedAt: freezed == closedAt ? _self.closedAt : closedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,closedReason: freezed == closedReason ? _self.closedReason : closedReason // ignore: cast_nullable_to_non_nullable
as String?,authorDeleted: null == authorDeleted ? _self.authorDeleted : authorDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of SupportInquiryEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SupportInquiryOrderSnapshotCopyWith<$Res>? get orderSnapshot {
    if (_self.orderSnapshot == null) {
    return null;
  }

  return $SupportInquiryOrderSnapshotCopyWith<$Res>(_self.orderSnapshot!, (value) {
    return _then(_self.copyWith(orderSnapshot: value));
  });
}/// Create a copy of SupportInquiryEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SupportInquiryAnswerCopyWith<$Res>? get answer {
    if (_self.answer == null) {
    return null;
  }

  return $SupportInquiryAnswerCopyWith<$Res>(_self.answer!, (value) {
    return _then(_self.copyWith(answer: value));
  });
}
}

// dart format on

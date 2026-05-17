// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'frequent_store_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FrequentStoreEntity {

 String get storeId; String get storeName;/// 최근 lookbackDays 기간 내 OrderLog 매장별 카운트.
 int get visitCount;/// 사용자가 해당 매장을 즐겨찾기로 등록했는지.
 bool get isFavorite;/// `visitCount + (isFavorite ? favoriteScoreBoost : 0)`.
 int get score;/// 매장 메타 (StoreMenuPage 진입에 사용).
/// 매장 stream 에서 매칭되지 않으면 null — 카드 자체를 hide.
 StoreEntity? get store;
/// Create a copy of FrequentStoreEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FrequentStoreEntityCopyWith<FrequentStoreEntity> get copyWith => _$FrequentStoreEntityCopyWithImpl<FrequentStoreEntity>(this as FrequentStoreEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FrequentStoreEntity&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.storeName, storeName) || other.storeName == storeName)&&(identical(other.visitCount, visitCount) || other.visitCount == visitCount)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite)&&(identical(other.score, score) || other.score == score)&&(identical(other.store, store) || other.store == store));
}


@override
int get hashCode => Object.hash(runtimeType,storeId,storeName,visitCount,isFavorite,score,store);

@override
String toString() {
  return 'FrequentStoreEntity(storeId: $storeId, storeName: $storeName, visitCount: $visitCount, isFavorite: $isFavorite, score: $score, store: $store)';
}


}

/// @nodoc
abstract mixin class $FrequentStoreEntityCopyWith<$Res>  {
  factory $FrequentStoreEntityCopyWith(FrequentStoreEntity value, $Res Function(FrequentStoreEntity) _then) = _$FrequentStoreEntityCopyWithImpl;
@useResult
$Res call({
 String storeId, String storeName, int visitCount, bool isFavorite, int score, StoreEntity? store
});


$StoreEntityCopyWith<$Res>? get store;

}
/// @nodoc
class _$FrequentStoreEntityCopyWithImpl<$Res>
    implements $FrequentStoreEntityCopyWith<$Res> {
  _$FrequentStoreEntityCopyWithImpl(this._self, this._then);

  final FrequentStoreEntity _self;
  final $Res Function(FrequentStoreEntity) _then;

/// Create a copy of FrequentStoreEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? storeId = null,Object? storeName = null,Object? visitCount = null,Object? isFavorite = null,Object? score = null,Object? store = freezed,}) {
  return _then(_self.copyWith(
storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,storeName: null == storeName ? _self.storeName : storeName // ignore: cast_nullable_to_non_nullable
as String,visitCount: null == visitCount ? _self.visitCount : visitCount // ignore: cast_nullable_to_non_nullable
as int,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,store: freezed == store ? _self.store : store // ignore: cast_nullable_to_non_nullable
as StoreEntity?,
  ));
}
/// Create a copy of FrequentStoreEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StoreEntityCopyWith<$Res>? get store {
    if (_self.store == null) {
    return null;
  }

  return $StoreEntityCopyWith<$Res>(_self.store!, (value) {
    return _then(_self.copyWith(store: value));
  });
}
}


/// Adds pattern-matching-related methods to [FrequentStoreEntity].
extension FrequentStoreEntityPatterns on FrequentStoreEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FrequentStoreEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FrequentStoreEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FrequentStoreEntity value)  $default,){
final _that = this;
switch (_that) {
case _FrequentStoreEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FrequentStoreEntity value)?  $default,){
final _that = this;
switch (_that) {
case _FrequentStoreEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String storeId,  String storeName,  int visitCount,  bool isFavorite,  int score,  StoreEntity? store)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FrequentStoreEntity() when $default != null:
return $default(_that.storeId,_that.storeName,_that.visitCount,_that.isFavorite,_that.score,_that.store);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String storeId,  String storeName,  int visitCount,  bool isFavorite,  int score,  StoreEntity? store)  $default,) {final _that = this;
switch (_that) {
case _FrequentStoreEntity():
return $default(_that.storeId,_that.storeName,_that.visitCount,_that.isFavorite,_that.score,_that.store);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String storeId,  String storeName,  int visitCount,  bool isFavorite,  int score,  StoreEntity? store)?  $default,) {final _that = this;
switch (_that) {
case _FrequentStoreEntity() when $default != null:
return $default(_that.storeId,_that.storeName,_that.visitCount,_that.isFavorite,_that.score,_that.store);case _:
  return null;

}
}

}

/// @nodoc


class _FrequentStoreEntity implements FrequentStoreEntity {
  const _FrequentStoreEntity({required this.storeId, required this.storeName, this.visitCount = 0, this.isFavorite = false, this.score = 0, this.store});
  

@override final  String storeId;
@override final  String storeName;
/// 최근 lookbackDays 기간 내 OrderLog 매장별 카운트.
@override@JsonKey() final  int visitCount;
/// 사용자가 해당 매장을 즐겨찾기로 등록했는지.
@override@JsonKey() final  bool isFavorite;
/// `visitCount + (isFavorite ? favoriteScoreBoost : 0)`.
@override@JsonKey() final  int score;
/// 매장 메타 (StoreMenuPage 진입에 사용).
/// 매장 stream 에서 매칭되지 않으면 null — 카드 자체를 hide.
@override final  StoreEntity? store;

/// Create a copy of FrequentStoreEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FrequentStoreEntityCopyWith<_FrequentStoreEntity> get copyWith => __$FrequentStoreEntityCopyWithImpl<_FrequentStoreEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FrequentStoreEntity&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.storeName, storeName) || other.storeName == storeName)&&(identical(other.visitCount, visitCount) || other.visitCount == visitCount)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite)&&(identical(other.score, score) || other.score == score)&&(identical(other.store, store) || other.store == store));
}


@override
int get hashCode => Object.hash(runtimeType,storeId,storeName,visitCount,isFavorite,score,store);

@override
String toString() {
  return 'FrequentStoreEntity(storeId: $storeId, storeName: $storeName, visitCount: $visitCount, isFavorite: $isFavorite, score: $score, store: $store)';
}


}

/// @nodoc
abstract mixin class _$FrequentStoreEntityCopyWith<$Res> implements $FrequentStoreEntityCopyWith<$Res> {
  factory _$FrequentStoreEntityCopyWith(_FrequentStoreEntity value, $Res Function(_FrequentStoreEntity) _then) = __$FrequentStoreEntityCopyWithImpl;
@override @useResult
$Res call({
 String storeId, String storeName, int visitCount, bool isFavorite, int score, StoreEntity? store
});


@override $StoreEntityCopyWith<$Res>? get store;

}
/// @nodoc
class __$FrequentStoreEntityCopyWithImpl<$Res>
    implements _$FrequentStoreEntityCopyWith<$Res> {
  __$FrequentStoreEntityCopyWithImpl(this._self, this._then);

  final _FrequentStoreEntity _self;
  final $Res Function(_FrequentStoreEntity) _then;

/// Create a copy of FrequentStoreEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? storeId = null,Object? storeName = null,Object? visitCount = null,Object? isFavorite = null,Object? score = null,Object? store = freezed,}) {
  return _then(_FrequentStoreEntity(
storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,storeName: null == storeName ? _self.storeName : storeName // ignore: cast_nullable_to_non_nullable
as String,visitCount: null == visitCount ? _self.visitCount : visitCount // ignore: cast_nullable_to_non_nullable
as int,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,store: freezed == store ? _self.store : store // ignore: cast_nullable_to_non_nullable
as StoreEntity?,
  ));
}

/// Create a copy of FrequentStoreEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StoreEntityCopyWith<$Res>? get store {
    if (_self.store == null) {
    return null;
  }

  return $StoreEntityCopyWith<$Res>(_self.store!, (value) {
    return _then(_self.copyWith(store: value));
  });
}
}

// dart format on

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'frequent_menu_item_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FrequentMenuItemEntity {

 String get storeId; String get storeName; String get menuItemId; String get menuItemName;/// 메뉴 이미지 URL. 미존재 시 빈 문자열 (카드 fallback 아이콘).
 String get imageUrl;/// 기준 가격 (옵션 미반영). 표시용.
 int get basePrice;/// 최근 lookbackDays 기간 내 매장-메뉴 페어 카운트.
 int get orderCount;/// 사용자가 (storeId, menuItemId) 페어를 즐겨찾기로 등록했는지.
 bool get isFavorite;/// `orderCount + (isFavorite ? favoriteScoreBoost : 0)`.
 int get score;
/// Create a copy of FrequentMenuItemEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FrequentMenuItemEntityCopyWith<FrequentMenuItemEntity> get copyWith => _$FrequentMenuItemEntityCopyWithImpl<FrequentMenuItemEntity>(this as FrequentMenuItemEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FrequentMenuItemEntity&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.storeName, storeName) || other.storeName == storeName)&&(identical(other.menuItemId, menuItemId) || other.menuItemId == menuItemId)&&(identical(other.menuItemName, menuItemName) || other.menuItemName == menuItemName)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.basePrice, basePrice) || other.basePrice == basePrice)&&(identical(other.orderCount, orderCount) || other.orderCount == orderCount)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite)&&(identical(other.score, score) || other.score == score));
}


@override
int get hashCode => Object.hash(runtimeType,storeId,storeName,menuItemId,menuItemName,imageUrl,basePrice,orderCount,isFavorite,score);

@override
String toString() {
  return 'FrequentMenuItemEntity(storeId: $storeId, storeName: $storeName, menuItemId: $menuItemId, menuItemName: $menuItemName, imageUrl: $imageUrl, basePrice: $basePrice, orderCount: $orderCount, isFavorite: $isFavorite, score: $score)';
}


}

/// @nodoc
abstract mixin class $FrequentMenuItemEntityCopyWith<$Res>  {
  factory $FrequentMenuItemEntityCopyWith(FrequentMenuItemEntity value, $Res Function(FrequentMenuItemEntity) _then) = _$FrequentMenuItemEntityCopyWithImpl;
@useResult
$Res call({
 String storeId, String storeName, String menuItemId, String menuItemName, String imageUrl, int basePrice, int orderCount, bool isFavorite, int score
});




}
/// @nodoc
class _$FrequentMenuItemEntityCopyWithImpl<$Res>
    implements $FrequentMenuItemEntityCopyWith<$Res> {
  _$FrequentMenuItemEntityCopyWithImpl(this._self, this._then);

  final FrequentMenuItemEntity _self;
  final $Res Function(FrequentMenuItemEntity) _then;

/// Create a copy of FrequentMenuItemEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? storeId = null,Object? storeName = null,Object? menuItemId = null,Object? menuItemName = null,Object? imageUrl = null,Object? basePrice = null,Object? orderCount = null,Object? isFavorite = null,Object? score = null,}) {
  return _then(_self.copyWith(
storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,storeName: null == storeName ? _self.storeName : storeName // ignore: cast_nullable_to_non_nullable
as String,menuItemId: null == menuItemId ? _self.menuItemId : menuItemId // ignore: cast_nullable_to_non_nullable
as String,menuItemName: null == menuItemName ? _self.menuItemName : menuItemName // ignore: cast_nullable_to_non_nullable
as String,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,basePrice: null == basePrice ? _self.basePrice : basePrice // ignore: cast_nullable_to_non_nullable
as int,orderCount: null == orderCount ? _self.orderCount : orderCount // ignore: cast_nullable_to_non_nullable
as int,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [FrequentMenuItemEntity].
extension FrequentMenuItemEntityPatterns on FrequentMenuItemEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FrequentMenuItemEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FrequentMenuItemEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FrequentMenuItemEntity value)  $default,){
final _that = this;
switch (_that) {
case _FrequentMenuItemEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FrequentMenuItemEntity value)?  $default,){
final _that = this;
switch (_that) {
case _FrequentMenuItemEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String storeId,  String storeName,  String menuItemId,  String menuItemName,  String imageUrl,  int basePrice,  int orderCount,  bool isFavorite,  int score)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FrequentMenuItemEntity() when $default != null:
return $default(_that.storeId,_that.storeName,_that.menuItemId,_that.menuItemName,_that.imageUrl,_that.basePrice,_that.orderCount,_that.isFavorite,_that.score);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String storeId,  String storeName,  String menuItemId,  String menuItemName,  String imageUrl,  int basePrice,  int orderCount,  bool isFavorite,  int score)  $default,) {final _that = this;
switch (_that) {
case _FrequentMenuItemEntity():
return $default(_that.storeId,_that.storeName,_that.menuItemId,_that.menuItemName,_that.imageUrl,_that.basePrice,_that.orderCount,_that.isFavorite,_that.score);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String storeId,  String storeName,  String menuItemId,  String menuItemName,  String imageUrl,  int basePrice,  int orderCount,  bool isFavorite,  int score)?  $default,) {final _that = this;
switch (_that) {
case _FrequentMenuItemEntity() when $default != null:
return $default(_that.storeId,_that.storeName,_that.menuItemId,_that.menuItemName,_that.imageUrl,_that.basePrice,_that.orderCount,_that.isFavorite,_that.score);case _:
  return null;

}
}

}

/// @nodoc


class _FrequentMenuItemEntity implements FrequentMenuItemEntity {
  const _FrequentMenuItemEntity({required this.storeId, required this.storeName, required this.menuItemId, required this.menuItemName, this.imageUrl = '', this.basePrice = 0, this.orderCount = 0, this.isFavorite = false, this.score = 0});
  

@override final  String storeId;
@override final  String storeName;
@override final  String menuItemId;
@override final  String menuItemName;
/// 메뉴 이미지 URL. 미존재 시 빈 문자열 (카드 fallback 아이콘).
@override@JsonKey() final  String imageUrl;
/// 기준 가격 (옵션 미반영). 표시용.
@override@JsonKey() final  int basePrice;
/// 최근 lookbackDays 기간 내 매장-메뉴 페어 카운트.
@override@JsonKey() final  int orderCount;
/// 사용자가 (storeId, menuItemId) 페어를 즐겨찾기로 등록했는지.
@override@JsonKey() final  bool isFavorite;
/// `orderCount + (isFavorite ? favoriteScoreBoost : 0)`.
@override@JsonKey() final  int score;

/// Create a copy of FrequentMenuItemEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FrequentMenuItemEntityCopyWith<_FrequentMenuItemEntity> get copyWith => __$FrequentMenuItemEntityCopyWithImpl<_FrequentMenuItemEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FrequentMenuItemEntity&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.storeName, storeName) || other.storeName == storeName)&&(identical(other.menuItemId, menuItemId) || other.menuItemId == menuItemId)&&(identical(other.menuItemName, menuItemName) || other.menuItemName == menuItemName)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.basePrice, basePrice) || other.basePrice == basePrice)&&(identical(other.orderCount, orderCount) || other.orderCount == orderCount)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite)&&(identical(other.score, score) || other.score == score));
}


@override
int get hashCode => Object.hash(runtimeType,storeId,storeName,menuItemId,menuItemName,imageUrl,basePrice,orderCount,isFavorite,score);

@override
String toString() {
  return 'FrequentMenuItemEntity(storeId: $storeId, storeName: $storeName, menuItemId: $menuItemId, menuItemName: $menuItemName, imageUrl: $imageUrl, basePrice: $basePrice, orderCount: $orderCount, isFavorite: $isFavorite, score: $score)';
}


}

/// @nodoc
abstract mixin class _$FrequentMenuItemEntityCopyWith<$Res> implements $FrequentMenuItemEntityCopyWith<$Res> {
  factory _$FrequentMenuItemEntityCopyWith(_FrequentMenuItemEntity value, $Res Function(_FrequentMenuItemEntity) _then) = __$FrequentMenuItemEntityCopyWithImpl;
@override @useResult
$Res call({
 String storeId, String storeName, String menuItemId, String menuItemName, String imageUrl, int basePrice, int orderCount, bool isFavorite, int score
});




}
/// @nodoc
class __$FrequentMenuItemEntityCopyWithImpl<$Res>
    implements _$FrequentMenuItemEntityCopyWith<$Res> {
  __$FrequentMenuItemEntityCopyWithImpl(this._self, this._then);

  final _FrequentMenuItemEntity _self;
  final $Res Function(_FrequentMenuItemEntity) _then;

/// Create a copy of FrequentMenuItemEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? storeId = null,Object? storeName = null,Object? menuItemId = null,Object? menuItemName = null,Object? imageUrl = null,Object? basePrice = null,Object? orderCount = null,Object? isFavorite = null,Object? score = null,}) {
  return _then(_FrequentMenuItemEntity(
storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,storeName: null == storeName ? _self.storeName : storeName // ignore: cast_nullable_to_non_nullable
as String,menuItemId: null == menuItemId ? _self.menuItemId : menuItemId // ignore: cast_nullable_to_non_nullable
as String,menuItemName: null == menuItemName ? _self.menuItemName : menuItemName // ignore: cast_nullable_to_non_nullable
as String,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,basePrice: null == basePrice ? _self.basePrice : basePrice // ignore: cast_nullable_to_non_nullable
as int,orderCount: null == orderCount ? _self.orderCount : orderCount // ignore: cast_nullable_to_non_nullable
as int,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on

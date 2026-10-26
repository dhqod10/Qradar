// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'menu_search_hit_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MenuSearchHitEntity {

/// 메뉴 문서 ID (브랜드 마스터면 마스터 ID — 매장 화면 머지 목록의 id 와 같다).
 String get menuItemId; String get menuName;/// 없으면 `''`.
 String get menuImageUrl; String get mainCategoryCode; String get storeId; String get storeName;/// 스냅샷의 값 그대로.
 double? get distanceKm; MenuHitSource get source;
/// Create a copy of MenuSearchHitEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MenuSearchHitEntityCopyWith<MenuSearchHitEntity> get copyWith => _$MenuSearchHitEntityCopyWithImpl<MenuSearchHitEntity>(this as MenuSearchHitEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MenuSearchHitEntity&&(identical(other.menuItemId, menuItemId) || other.menuItemId == menuItemId)&&(identical(other.menuName, menuName) || other.menuName == menuName)&&(identical(other.menuImageUrl, menuImageUrl) || other.menuImageUrl == menuImageUrl)&&(identical(other.mainCategoryCode, mainCategoryCode) || other.mainCategoryCode == mainCategoryCode)&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.storeName, storeName) || other.storeName == storeName)&&(identical(other.distanceKm, distanceKm) || other.distanceKm == distanceKm)&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode => Object.hash(runtimeType,menuItemId,menuName,menuImageUrl,mainCategoryCode,storeId,storeName,distanceKm,source);

@override
String toString() {
  return 'MenuSearchHitEntity(menuItemId: $menuItemId, menuName: $menuName, menuImageUrl: $menuImageUrl, mainCategoryCode: $mainCategoryCode, storeId: $storeId, storeName: $storeName, distanceKm: $distanceKm, source: $source)';
}


}

/// @nodoc
abstract mixin class $MenuSearchHitEntityCopyWith<$Res>  {
  factory $MenuSearchHitEntityCopyWith(MenuSearchHitEntity value, $Res Function(MenuSearchHitEntity) _then) = _$MenuSearchHitEntityCopyWithImpl;
@useResult
$Res call({
 String menuItemId, String menuName, String menuImageUrl, String mainCategoryCode, String storeId, String storeName, double? distanceKm, MenuHitSource source
});




}
/// @nodoc
class _$MenuSearchHitEntityCopyWithImpl<$Res>
    implements $MenuSearchHitEntityCopyWith<$Res> {
  _$MenuSearchHitEntityCopyWithImpl(this._self, this._then);

  final MenuSearchHitEntity _self;
  final $Res Function(MenuSearchHitEntity) _then;

/// Create a copy of MenuSearchHitEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? menuItemId = null,Object? menuName = null,Object? menuImageUrl = null,Object? mainCategoryCode = null,Object? storeId = null,Object? storeName = null,Object? distanceKm = freezed,Object? source = null,}) {
  return _then(_self.copyWith(
menuItemId: null == menuItemId ? _self.menuItemId : menuItemId // ignore: cast_nullable_to_non_nullable
as String,menuName: null == menuName ? _self.menuName : menuName // ignore: cast_nullable_to_non_nullable
as String,menuImageUrl: null == menuImageUrl ? _self.menuImageUrl : menuImageUrl // ignore: cast_nullable_to_non_nullable
as String,mainCategoryCode: null == mainCategoryCode ? _self.mainCategoryCode : mainCategoryCode // ignore: cast_nullable_to_non_nullable
as String,storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,storeName: null == storeName ? _self.storeName : storeName // ignore: cast_nullable_to_non_nullable
as String,distanceKm: freezed == distanceKm ? _self.distanceKm : distanceKm // ignore: cast_nullable_to_non_nullable
as double?,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as MenuHitSource,
  ));
}

}


/// Adds pattern-matching-related methods to [MenuSearchHitEntity].
extension MenuSearchHitEntityPatterns on MenuSearchHitEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MenuSearchHitEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MenuSearchHitEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MenuSearchHitEntity value)  $default,){
final _that = this;
switch (_that) {
case _MenuSearchHitEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MenuSearchHitEntity value)?  $default,){
final _that = this;
switch (_that) {
case _MenuSearchHitEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String menuItemId,  String menuName,  String menuImageUrl,  String mainCategoryCode,  String storeId,  String storeName,  double? distanceKm,  MenuHitSource source)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MenuSearchHitEntity() when $default != null:
return $default(_that.menuItemId,_that.menuName,_that.menuImageUrl,_that.mainCategoryCode,_that.storeId,_that.storeName,_that.distanceKm,_that.source);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String menuItemId,  String menuName,  String menuImageUrl,  String mainCategoryCode,  String storeId,  String storeName,  double? distanceKm,  MenuHitSource source)  $default,) {final _that = this;
switch (_that) {
case _MenuSearchHitEntity():
return $default(_that.menuItemId,_that.menuName,_that.menuImageUrl,_that.mainCategoryCode,_that.storeId,_that.storeName,_that.distanceKm,_that.source);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String menuItemId,  String menuName,  String menuImageUrl,  String mainCategoryCode,  String storeId,  String storeName,  double? distanceKm,  MenuHitSource source)?  $default,) {final _that = this;
switch (_that) {
case _MenuSearchHitEntity() when $default != null:
return $default(_that.menuItemId,_that.menuName,_that.menuImageUrl,_that.mainCategoryCode,_that.storeId,_that.storeName,_that.distanceKm,_that.source);case _:
  return null;

}
}

}

/// @nodoc


class _MenuSearchHitEntity implements MenuSearchHitEntity {
  const _MenuSearchHitEntity({required this.menuItemId, required this.menuName, this.menuImageUrl = '', required this.mainCategoryCode, required this.storeId, required this.storeName, this.distanceKm, required this.source});
  

/// 메뉴 문서 ID (브랜드 마스터면 마스터 ID — 매장 화면 머지 목록의 id 와 같다).
@override final  String menuItemId;
@override final  String menuName;
/// 없으면 `''`.
@override@JsonKey() final  String menuImageUrl;
@override final  String mainCategoryCode;
@override final  String storeId;
@override final  String storeName;
/// 스냅샷의 값 그대로.
@override final  double? distanceKm;
@override final  MenuHitSource source;

/// Create a copy of MenuSearchHitEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MenuSearchHitEntityCopyWith<_MenuSearchHitEntity> get copyWith => __$MenuSearchHitEntityCopyWithImpl<_MenuSearchHitEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MenuSearchHitEntity&&(identical(other.menuItemId, menuItemId) || other.menuItemId == menuItemId)&&(identical(other.menuName, menuName) || other.menuName == menuName)&&(identical(other.menuImageUrl, menuImageUrl) || other.menuImageUrl == menuImageUrl)&&(identical(other.mainCategoryCode, mainCategoryCode) || other.mainCategoryCode == mainCategoryCode)&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.storeName, storeName) || other.storeName == storeName)&&(identical(other.distanceKm, distanceKm) || other.distanceKm == distanceKm)&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode => Object.hash(runtimeType,menuItemId,menuName,menuImageUrl,mainCategoryCode,storeId,storeName,distanceKm,source);

@override
String toString() {
  return 'MenuSearchHitEntity(menuItemId: $menuItemId, menuName: $menuName, menuImageUrl: $menuImageUrl, mainCategoryCode: $mainCategoryCode, storeId: $storeId, storeName: $storeName, distanceKm: $distanceKm, source: $source)';
}


}

/// @nodoc
abstract mixin class _$MenuSearchHitEntityCopyWith<$Res> implements $MenuSearchHitEntityCopyWith<$Res> {
  factory _$MenuSearchHitEntityCopyWith(_MenuSearchHitEntity value, $Res Function(_MenuSearchHitEntity) _then) = __$MenuSearchHitEntityCopyWithImpl;
@override @useResult
$Res call({
 String menuItemId, String menuName, String menuImageUrl, String mainCategoryCode, String storeId, String storeName, double? distanceKm, MenuHitSource source
});




}
/// @nodoc
class __$MenuSearchHitEntityCopyWithImpl<$Res>
    implements _$MenuSearchHitEntityCopyWith<$Res> {
  __$MenuSearchHitEntityCopyWithImpl(this._self, this._then);

  final _MenuSearchHitEntity _self;
  final $Res Function(_MenuSearchHitEntity) _then;

/// Create a copy of MenuSearchHitEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? menuItemId = null,Object? menuName = null,Object? menuImageUrl = null,Object? mainCategoryCode = null,Object? storeId = null,Object? storeName = null,Object? distanceKm = freezed,Object? source = null,}) {
  return _then(_MenuSearchHitEntity(
menuItemId: null == menuItemId ? _self.menuItemId : menuItemId // ignore: cast_nullable_to_non_nullable
as String,menuName: null == menuName ? _self.menuName : menuName // ignore: cast_nullable_to_non_nullable
as String,menuImageUrl: null == menuImageUrl ? _self.menuImageUrl : menuImageUrl // ignore: cast_nullable_to_non_nullable
as String,mainCategoryCode: null == mainCategoryCode ? _self.mainCategoryCode : mainCategoryCode // ignore: cast_nullable_to_non_nullable
as String,storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,storeName: null == storeName ? _self.storeName : storeName // ignore: cast_nullable_to_non_nullable
as String,distanceKm: freezed == distanceKm ? _self.distanceKm : distanceKm // ignore: cast_nullable_to_non_nullable
as double?,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as MenuHitSource,
  ));
}


}

// dart format on

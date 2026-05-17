// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'menu_item_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MenuItemEntity {

 String get id; String get storeId; String get name; String get imageUrl; String? get description; String get mainCategoryCode; String? get subCategoryId; int get basePrice; List<OptionGroupRef> get optionGroupRefs; bool get soldOut; int get displayOrder; DateTime? get createdAt;// ── Phase 1b (brand_master) 신규 필드 ─────────────────────────────
/// 메뉴 출처. 기존 매장 메뉴는 기본값 `store`.
 MenuItemScope get scope;/// 브랜드 마스터 메뉴이면 해당 brandId. 개인 매장 메뉴는 null.
 String? get brandId;/// 태그 목록 ('recommended' | 'new' | 'best').
 List<String> get tags;/// 고객에게 노출 여부. 기본값 true.
 bool get visible;/// 점주가 비활성화한 옵션 그룹 ID 목록 (sub-phase 5 활성).
 List<String> get disabledOptionGroupIds;/// 점주가 비활성화한 옵션 항목 ID 목록 (sub-phase 5 활성).
 List<String> get disabledOptionItemIds;/// 승인 상태. 개인 매장 메뉴는 null (승인 불필요).
 EntityApprovalStatus? get status; String? get submittedBy; DateTime? get submittedAt; String? get approvedBy; DateTime? get approvedAt; String? get rejectedReason; DateTime? get updatedAt;
/// Create a copy of MenuItemEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MenuItemEntityCopyWith<MenuItemEntity> get copyWith => _$MenuItemEntityCopyWithImpl<MenuItemEntity>(this as MenuItemEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MenuItemEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.name, name) || other.name == name)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.description, description) || other.description == description)&&(identical(other.mainCategoryCode, mainCategoryCode) || other.mainCategoryCode == mainCategoryCode)&&(identical(other.subCategoryId, subCategoryId) || other.subCategoryId == subCategoryId)&&(identical(other.basePrice, basePrice) || other.basePrice == basePrice)&&const DeepCollectionEquality().equals(other.optionGroupRefs, optionGroupRefs)&&(identical(other.soldOut, soldOut) || other.soldOut == soldOut)&&(identical(other.displayOrder, displayOrder) || other.displayOrder == displayOrder)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.brandId, brandId) || other.brandId == brandId)&&const DeepCollectionEquality().equals(other.tags, tags)&&(identical(other.visible, visible) || other.visible == visible)&&const DeepCollectionEquality().equals(other.disabledOptionGroupIds, disabledOptionGroupIds)&&const DeepCollectionEquality().equals(other.disabledOptionItemIds, disabledOptionItemIds)&&(identical(other.status, status) || other.status == status)&&(identical(other.submittedBy, submittedBy) || other.submittedBy == submittedBy)&&(identical(other.submittedAt, submittedAt) || other.submittedAt == submittedAt)&&(identical(other.approvedBy, approvedBy) || other.approvedBy == approvedBy)&&(identical(other.approvedAt, approvedAt) || other.approvedAt == approvedAt)&&(identical(other.rejectedReason, rejectedReason) || other.rejectedReason == rejectedReason)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,storeId,name,imageUrl,description,mainCategoryCode,subCategoryId,basePrice,const DeepCollectionEquality().hash(optionGroupRefs),soldOut,displayOrder,createdAt,scope,brandId,const DeepCollectionEquality().hash(tags),visible,const DeepCollectionEquality().hash(disabledOptionGroupIds),const DeepCollectionEquality().hash(disabledOptionItemIds),status,submittedBy,submittedAt,approvedBy,approvedAt,rejectedReason,updatedAt]);

@override
String toString() {
  return 'MenuItemEntity(id: $id, storeId: $storeId, name: $name, imageUrl: $imageUrl, description: $description, mainCategoryCode: $mainCategoryCode, subCategoryId: $subCategoryId, basePrice: $basePrice, optionGroupRefs: $optionGroupRefs, soldOut: $soldOut, displayOrder: $displayOrder, createdAt: $createdAt, scope: $scope, brandId: $brandId, tags: $tags, visible: $visible, disabledOptionGroupIds: $disabledOptionGroupIds, disabledOptionItemIds: $disabledOptionItemIds, status: $status, submittedBy: $submittedBy, submittedAt: $submittedAt, approvedBy: $approvedBy, approvedAt: $approvedAt, rejectedReason: $rejectedReason, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $MenuItemEntityCopyWith<$Res>  {
  factory $MenuItemEntityCopyWith(MenuItemEntity value, $Res Function(MenuItemEntity) _then) = _$MenuItemEntityCopyWithImpl;
@useResult
$Res call({
 String id, String storeId, String name, String imageUrl, String? description, String mainCategoryCode, String? subCategoryId, int basePrice, List<OptionGroupRef> optionGroupRefs, bool soldOut, int displayOrder, DateTime? createdAt, MenuItemScope scope, String? brandId, List<String> tags, bool visible, List<String> disabledOptionGroupIds, List<String> disabledOptionItemIds, EntityApprovalStatus? status, String? submittedBy, DateTime? submittedAt, String? approvedBy, DateTime? approvedAt, String? rejectedReason, DateTime? updatedAt
});




}
/// @nodoc
class _$MenuItemEntityCopyWithImpl<$Res>
    implements $MenuItemEntityCopyWith<$Res> {
  _$MenuItemEntityCopyWithImpl(this._self, this._then);

  final MenuItemEntity _self;
  final $Res Function(MenuItemEntity) _then;

/// Create a copy of MenuItemEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? storeId = null,Object? name = null,Object? imageUrl = null,Object? description = freezed,Object? mainCategoryCode = null,Object? subCategoryId = freezed,Object? basePrice = null,Object? optionGroupRefs = null,Object? soldOut = null,Object? displayOrder = null,Object? createdAt = freezed,Object? scope = null,Object? brandId = freezed,Object? tags = null,Object? visible = null,Object? disabledOptionGroupIds = null,Object? disabledOptionItemIds = null,Object? status = freezed,Object? submittedBy = freezed,Object? submittedAt = freezed,Object? approvedBy = freezed,Object? approvedAt = freezed,Object? rejectedReason = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,mainCategoryCode: null == mainCategoryCode ? _self.mainCategoryCode : mainCategoryCode // ignore: cast_nullable_to_non_nullable
as String,subCategoryId: freezed == subCategoryId ? _self.subCategoryId : subCategoryId // ignore: cast_nullable_to_non_nullable
as String?,basePrice: null == basePrice ? _self.basePrice : basePrice // ignore: cast_nullable_to_non_nullable
as int,optionGroupRefs: null == optionGroupRefs ? _self.optionGroupRefs : optionGroupRefs // ignore: cast_nullable_to_non_nullable
as List<OptionGroupRef>,soldOut: null == soldOut ? _self.soldOut : soldOut // ignore: cast_nullable_to_non_nullable
as bool,displayOrder: null == displayOrder ? _self.displayOrder : displayOrder // ignore: cast_nullable_to_non_nullable
as int,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as MenuItemScope,brandId: freezed == brandId ? _self.brandId : brandId // ignore: cast_nullable_to_non_nullable
as String?,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,visible: null == visible ? _self.visible : visible // ignore: cast_nullable_to_non_nullable
as bool,disabledOptionGroupIds: null == disabledOptionGroupIds ? _self.disabledOptionGroupIds : disabledOptionGroupIds // ignore: cast_nullable_to_non_nullable
as List<String>,disabledOptionItemIds: null == disabledOptionItemIds ? _self.disabledOptionItemIds : disabledOptionItemIds // ignore: cast_nullable_to_non_nullable
as List<String>,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as EntityApprovalStatus?,submittedBy: freezed == submittedBy ? _self.submittedBy : submittedBy // ignore: cast_nullable_to_non_nullable
as String?,submittedAt: freezed == submittedAt ? _self.submittedAt : submittedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,approvedBy: freezed == approvedBy ? _self.approvedBy : approvedBy // ignore: cast_nullable_to_non_nullable
as String?,approvedAt: freezed == approvedAt ? _self.approvedAt : approvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,rejectedReason: freezed == rejectedReason ? _self.rejectedReason : rejectedReason // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [MenuItemEntity].
extension MenuItemEntityPatterns on MenuItemEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MenuItemEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MenuItemEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MenuItemEntity value)  $default,){
final _that = this;
switch (_that) {
case _MenuItemEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MenuItemEntity value)?  $default,){
final _that = this;
switch (_that) {
case _MenuItemEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String storeId,  String name,  String imageUrl,  String? description,  String mainCategoryCode,  String? subCategoryId,  int basePrice,  List<OptionGroupRef> optionGroupRefs,  bool soldOut,  int displayOrder,  DateTime? createdAt,  MenuItemScope scope,  String? brandId,  List<String> tags,  bool visible,  List<String> disabledOptionGroupIds,  List<String> disabledOptionItemIds,  EntityApprovalStatus? status,  String? submittedBy,  DateTime? submittedAt,  String? approvedBy,  DateTime? approvedAt,  String? rejectedReason,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MenuItemEntity() when $default != null:
return $default(_that.id,_that.storeId,_that.name,_that.imageUrl,_that.description,_that.mainCategoryCode,_that.subCategoryId,_that.basePrice,_that.optionGroupRefs,_that.soldOut,_that.displayOrder,_that.createdAt,_that.scope,_that.brandId,_that.tags,_that.visible,_that.disabledOptionGroupIds,_that.disabledOptionItemIds,_that.status,_that.submittedBy,_that.submittedAt,_that.approvedBy,_that.approvedAt,_that.rejectedReason,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String storeId,  String name,  String imageUrl,  String? description,  String mainCategoryCode,  String? subCategoryId,  int basePrice,  List<OptionGroupRef> optionGroupRefs,  bool soldOut,  int displayOrder,  DateTime? createdAt,  MenuItemScope scope,  String? brandId,  List<String> tags,  bool visible,  List<String> disabledOptionGroupIds,  List<String> disabledOptionItemIds,  EntityApprovalStatus? status,  String? submittedBy,  DateTime? submittedAt,  String? approvedBy,  DateTime? approvedAt,  String? rejectedReason,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _MenuItemEntity():
return $default(_that.id,_that.storeId,_that.name,_that.imageUrl,_that.description,_that.mainCategoryCode,_that.subCategoryId,_that.basePrice,_that.optionGroupRefs,_that.soldOut,_that.displayOrder,_that.createdAt,_that.scope,_that.brandId,_that.tags,_that.visible,_that.disabledOptionGroupIds,_that.disabledOptionItemIds,_that.status,_that.submittedBy,_that.submittedAt,_that.approvedBy,_that.approvedAt,_that.rejectedReason,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String storeId,  String name,  String imageUrl,  String? description,  String mainCategoryCode,  String? subCategoryId,  int basePrice,  List<OptionGroupRef> optionGroupRefs,  bool soldOut,  int displayOrder,  DateTime? createdAt,  MenuItemScope scope,  String? brandId,  List<String> tags,  bool visible,  List<String> disabledOptionGroupIds,  List<String> disabledOptionItemIds,  EntityApprovalStatus? status,  String? submittedBy,  DateTime? submittedAt,  String? approvedBy,  DateTime? approvedAt,  String? rejectedReason,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _MenuItemEntity() when $default != null:
return $default(_that.id,_that.storeId,_that.name,_that.imageUrl,_that.description,_that.mainCategoryCode,_that.subCategoryId,_that.basePrice,_that.optionGroupRefs,_that.soldOut,_that.displayOrder,_that.createdAt,_that.scope,_that.brandId,_that.tags,_that.visible,_that.disabledOptionGroupIds,_that.disabledOptionItemIds,_that.status,_that.submittedBy,_that.submittedAt,_that.approvedBy,_that.approvedAt,_that.rejectedReason,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _MenuItemEntity implements MenuItemEntity {
  const _MenuItemEntity({required this.id, required this.storeId, required this.name, this.imageUrl = '', this.description, required this.mainCategoryCode, this.subCategoryId, required this.basePrice, final  List<OptionGroupRef> optionGroupRefs = const <OptionGroupRef>[], this.soldOut = false, this.displayOrder = 0, this.createdAt, this.scope = MenuItemScope.store, this.brandId, final  List<String> tags = const <String>[], this.visible = true, final  List<String> disabledOptionGroupIds = const <String>[], final  List<String> disabledOptionItemIds = const <String>[], this.status, this.submittedBy, this.submittedAt, this.approvedBy, this.approvedAt, this.rejectedReason, this.updatedAt}): _optionGroupRefs = optionGroupRefs,_tags = tags,_disabledOptionGroupIds = disabledOptionGroupIds,_disabledOptionItemIds = disabledOptionItemIds;
  

@override final  String id;
@override final  String storeId;
@override final  String name;
@override@JsonKey() final  String imageUrl;
@override final  String? description;
@override final  String mainCategoryCode;
@override final  String? subCategoryId;
@override final  int basePrice;
 final  List<OptionGroupRef> _optionGroupRefs;
@override@JsonKey() List<OptionGroupRef> get optionGroupRefs {
  if (_optionGroupRefs is EqualUnmodifiableListView) return _optionGroupRefs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_optionGroupRefs);
}

@override@JsonKey() final  bool soldOut;
@override@JsonKey() final  int displayOrder;
@override final  DateTime? createdAt;
// ── Phase 1b (brand_master) 신규 필드 ─────────────────────────────
/// 메뉴 출처. 기존 매장 메뉴는 기본값 `store`.
@override@JsonKey() final  MenuItemScope scope;
/// 브랜드 마스터 메뉴이면 해당 brandId. 개인 매장 메뉴는 null.
@override final  String? brandId;
/// 태그 목록 ('recommended' | 'new' | 'best').
 final  List<String> _tags;
/// 태그 목록 ('recommended' | 'new' | 'best').
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

/// 고객에게 노출 여부. 기본값 true.
@override@JsonKey() final  bool visible;
/// 점주가 비활성화한 옵션 그룹 ID 목록 (sub-phase 5 활성).
 final  List<String> _disabledOptionGroupIds;
/// 점주가 비활성화한 옵션 그룹 ID 목록 (sub-phase 5 활성).
@override@JsonKey() List<String> get disabledOptionGroupIds {
  if (_disabledOptionGroupIds is EqualUnmodifiableListView) return _disabledOptionGroupIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_disabledOptionGroupIds);
}

/// 점주가 비활성화한 옵션 항목 ID 목록 (sub-phase 5 활성).
 final  List<String> _disabledOptionItemIds;
/// 점주가 비활성화한 옵션 항목 ID 목록 (sub-phase 5 활성).
@override@JsonKey() List<String> get disabledOptionItemIds {
  if (_disabledOptionItemIds is EqualUnmodifiableListView) return _disabledOptionItemIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_disabledOptionItemIds);
}

/// 승인 상태. 개인 매장 메뉴는 null (승인 불필요).
@override final  EntityApprovalStatus? status;
@override final  String? submittedBy;
@override final  DateTime? submittedAt;
@override final  String? approvedBy;
@override final  DateTime? approvedAt;
@override final  String? rejectedReason;
@override final  DateTime? updatedAt;

/// Create a copy of MenuItemEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MenuItemEntityCopyWith<_MenuItemEntity> get copyWith => __$MenuItemEntityCopyWithImpl<_MenuItemEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MenuItemEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.name, name) || other.name == name)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.description, description) || other.description == description)&&(identical(other.mainCategoryCode, mainCategoryCode) || other.mainCategoryCode == mainCategoryCode)&&(identical(other.subCategoryId, subCategoryId) || other.subCategoryId == subCategoryId)&&(identical(other.basePrice, basePrice) || other.basePrice == basePrice)&&const DeepCollectionEquality().equals(other._optionGroupRefs, _optionGroupRefs)&&(identical(other.soldOut, soldOut) || other.soldOut == soldOut)&&(identical(other.displayOrder, displayOrder) || other.displayOrder == displayOrder)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.brandId, brandId) || other.brandId == brandId)&&const DeepCollectionEquality().equals(other._tags, _tags)&&(identical(other.visible, visible) || other.visible == visible)&&const DeepCollectionEquality().equals(other._disabledOptionGroupIds, _disabledOptionGroupIds)&&const DeepCollectionEquality().equals(other._disabledOptionItemIds, _disabledOptionItemIds)&&(identical(other.status, status) || other.status == status)&&(identical(other.submittedBy, submittedBy) || other.submittedBy == submittedBy)&&(identical(other.submittedAt, submittedAt) || other.submittedAt == submittedAt)&&(identical(other.approvedBy, approvedBy) || other.approvedBy == approvedBy)&&(identical(other.approvedAt, approvedAt) || other.approvedAt == approvedAt)&&(identical(other.rejectedReason, rejectedReason) || other.rejectedReason == rejectedReason)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,storeId,name,imageUrl,description,mainCategoryCode,subCategoryId,basePrice,const DeepCollectionEquality().hash(_optionGroupRefs),soldOut,displayOrder,createdAt,scope,brandId,const DeepCollectionEquality().hash(_tags),visible,const DeepCollectionEquality().hash(_disabledOptionGroupIds),const DeepCollectionEquality().hash(_disabledOptionItemIds),status,submittedBy,submittedAt,approvedBy,approvedAt,rejectedReason,updatedAt]);

@override
String toString() {
  return 'MenuItemEntity(id: $id, storeId: $storeId, name: $name, imageUrl: $imageUrl, description: $description, mainCategoryCode: $mainCategoryCode, subCategoryId: $subCategoryId, basePrice: $basePrice, optionGroupRefs: $optionGroupRefs, soldOut: $soldOut, displayOrder: $displayOrder, createdAt: $createdAt, scope: $scope, brandId: $brandId, tags: $tags, visible: $visible, disabledOptionGroupIds: $disabledOptionGroupIds, disabledOptionItemIds: $disabledOptionItemIds, status: $status, submittedBy: $submittedBy, submittedAt: $submittedAt, approvedBy: $approvedBy, approvedAt: $approvedAt, rejectedReason: $rejectedReason, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$MenuItemEntityCopyWith<$Res> implements $MenuItemEntityCopyWith<$Res> {
  factory _$MenuItemEntityCopyWith(_MenuItemEntity value, $Res Function(_MenuItemEntity) _then) = __$MenuItemEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String storeId, String name, String imageUrl, String? description, String mainCategoryCode, String? subCategoryId, int basePrice, List<OptionGroupRef> optionGroupRefs, bool soldOut, int displayOrder, DateTime? createdAt, MenuItemScope scope, String? brandId, List<String> tags, bool visible, List<String> disabledOptionGroupIds, List<String> disabledOptionItemIds, EntityApprovalStatus? status, String? submittedBy, DateTime? submittedAt, String? approvedBy, DateTime? approvedAt, String? rejectedReason, DateTime? updatedAt
});




}
/// @nodoc
class __$MenuItemEntityCopyWithImpl<$Res>
    implements _$MenuItemEntityCopyWith<$Res> {
  __$MenuItemEntityCopyWithImpl(this._self, this._then);

  final _MenuItemEntity _self;
  final $Res Function(_MenuItemEntity) _then;

/// Create a copy of MenuItemEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? storeId = null,Object? name = null,Object? imageUrl = null,Object? description = freezed,Object? mainCategoryCode = null,Object? subCategoryId = freezed,Object? basePrice = null,Object? optionGroupRefs = null,Object? soldOut = null,Object? displayOrder = null,Object? createdAt = freezed,Object? scope = null,Object? brandId = freezed,Object? tags = null,Object? visible = null,Object? disabledOptionGroupIds = null,Object? disabledOptionItemIds = null,Object? status = freezed,Object? submittedBy = freezed,Object? submittedAt = freezed,Object? approvedBy = freezed,Object? approvedAt = freezed,Object? rejectedReason = freezed,Object? updatedAt = freezed,}) {
  return _then(_MenuItemEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,mainCategoryCode: null == mainCategoryCode ? _self.mainCategoryCode : mainCategoryCode // ignore: cast_nullable_to_non_nullable
as String,subCategoryId: freezed == subCategoryId ? _self.subCategoryId : subCategoryId // ignore: cast_nullable_to_non_nullable
as String?,basePrice: null == basePrice ? _self.basePrice : basePrice // ignore: cast_nullable_to_non_nullable
as int,optionGroupRefs: null == optionGroupRefs ? _self._optionGroupRefs : optionGroupRefs // ignore: cast_nullable_to_non_nullable
as List<OptionGroupRef>,soldOut: null == soldOut ? _self.soldOut : soldOut // ignore: cast_nullable_to_non_nullable
as bool,displayOrder: null == displayOrder ? _self.displayOrder : displayOrder // ignore: cast_nullable_to_non_nullable
as int,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as MenuItemScope,brandId: freezed == brandId ? _self.brandId : brandId // ignore: cast_nullable_to_non_nullable
as String?,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,visible: null == visible ? _self.visible : visible // ignore: cast_nullable_to_non_nullable
as bool,disabledOptionGroupIds: null == disabledOptionGroupIds ? _self._disabledOptionGroupIds : disabledOptionGroupIds // ignore: cast_nullable_to_non_nullable
as List<String>,disabledOptionItemIds: null == disabledOptionItemIds ? _self._disabledOptionItemIds : disabledOptionItemIds // ignore: cast_nullable_to_non_nullable
as List<String>,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as EntityApprovalStatus?,submittedBy: freezed == submittedBy ? _self.submittedBy : submittedBy // ignore: cast_nullable_to_non_nullable
as String?,submittedAt: freezed == submittedAt ? _self.submittedAt : submittedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,approvedBy: freezed == approvedBy ? _self.approvedBy : approvedBy // ignore: cast_nullable_to_non_nullable
as String?,approvedAt: freezed == approvedAt ? _self.approvedAt : approvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,rejectedReason: freezed == rejectedReason ? _self.rejectedReason : rejectedReason // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on

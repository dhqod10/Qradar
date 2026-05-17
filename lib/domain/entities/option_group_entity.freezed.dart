// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'option_group_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$OptionGroupEntity {

 String get id; OptionScope get scope;/// brand scope 일 때 채움. store/master scope 에서는 null.
 String? get brandId;/// store scope 일 때 채움. brand/master scope 에서는 null.
 String? get storeId; String get name; OptionSelectionType get selectionType; bool get required; List<OptionItemEntity> get items; int get displayOrder;/// active=false 이면 메뉴 폼 및 고객 화면에서 숨겨짐.
 bool get active; DateTime? get createdAt; DateTime? get updatedAt;
/// Create a copy of OptionGroupEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OptionGroupEntityCopyWith<OptionGroupEntity> get copyWith => _$OptionGroupEntityCopyWithImpl<OptionGroupEntity>(this as OptionGroupEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OptionGroupEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.brandId, brandId) || other.brandId == brandId)&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.name, name) || other.name == name)&&(identical(other.selectionType, selectionType) || other.selectionType == selectionType)&&(identical(other.required, required) || other.required == required)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.displayOrder, displayOrder) || other.displayOrder == displayOrder)&&(identical(other.active, active) || other.active == active)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,scope,brandId,storeId,name,selectionType,required,const DeepCollectionEquality().hash(items),displayOrder,active,createdAt,updatedAt);

@override
String toString() {
  return 'OptionGroupEntity(id: $id, scope: $scope, brandId: $brandId, storeId: $storeId, name: $name, selectionType: $selectionType, required: $required, items: $items, displayOrder: $displayOrder, active: $active, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $OptionGroupEntityCopyWith<$Res>  {
  factory $OptionGroupEntityCopyWith(OptionGroupEntity value, $Res Function(OptionGroupEntity) _then) = _$OptionGroupEntityCopyWithImpl;
@useResult
$Res call({
 String id, OptionScope scope, String? brandId, String? storeId, String name, OptionSelectionType selectionType, bool required, List<OptionItemEntity> items, int displayOrder, bool active, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class _$OptionGroupEntityCopyWithImpl<$Res>
    implements $OptionGroupEntityCopyWith<$Res> {
  _$OptionGroupEntityCopyWithImpl(this._self, this._then);

  final OptionGroupEntity _self;
  final $Res Function(OptionGroupEntity) _then;

/// Create a copy of OptionGroupEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? scope = null,Object? brandId = freezed,Object? storeId = freezed,Object? name = null,Object? selectionType = null,Object? required = null,Object? items = null,Object? displayOrder = null,Object? active = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as OptionScope,brandId: freezed == brandId ? _self.brandId : brandId // ignore: cast_nullable_to_non_nullable
as String?,storeId: freezed == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,selectionType: null == selectionType ? _self.selectionType : selectionType // ignore: cast_nullable_to_non_nullable
as OptionSelectionType,required: null == required ? _self.required : required // ignore: cast_nullable_to_non_nullable
as bool,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<OptionItemEntity>,displayOrder: null == displayOrder ? _self.displayOrder : displayOrder // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [OptionGroupEntity].
extension OptionGroupEntityPatterns on OptionGroupEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OptionGroupEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OptionGroupEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OptionGroupEntity value)  $default,){
final _that = this;
switch (_that) {
case _OptionGroupEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OptionGroupEntity value)?  $default,){
final _that = this;
switch (_that) {
case _OptionGroupEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  OptionScope scope,  String? brandId,  String? storeId,  String name,  OptionSelectionType selectionType,  bool required,  List<OptionItemEntity> items,  int displayOrder,  bool active,  DateTime? createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OptionGroupEntity() when $default != null:
return $default(_that.id,_that.scope,_that.brandId,_that.storeId,_that.name,_that.selectionType,_that.required,_that.items,_that.displayOrder,_that.active,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  OptionScope scope,  String? brandId,  String? storeId,  String name,  OptionSelectionType selectionType,  bool required,  List<OptionItemEntity> items,  int displayOrder,  bool active,  DateTime? createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _OptionGroupEntity():
return $default(_that.id,_that.scope,_that.brandId,_that.storeId,_that.name,_that.selectionType,_that.required,_that.items,_that.displayOrder,_that.active,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  OptionScope scope,  String? brandId,  String? storeId,  String name,  OptionSelectionType selectionType,  bool required,  List<OptionItemEntity> items,  int displayOrder,  bool active,  DateTime? createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _OptionGroupEntity() when $default != null:
return $default(_that.id,_that.scope,_that.brandId,_that.storeId,_that.name,_that.selectionType,_that.required,_that.items,_that.displayOrder,_that.active,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _OptionGroupEntity implements OptionGroupEntity {
  const _OptionGroupEntity({required this.id, required this.scope, this.brandId, this.storeId, required this.name, required this.selectionType, this.required = false, final  List<OptionItemEntity> items = const <OptionItemEntity>[], this.displayOrder = 0, this.active = true, this.createdAt, this.updatedAt}): _items = items;
  

@override final  String id;
@override final  OptionScope scope;
/// brand scope 일 때 채움. store/master scope 에서는 null.
@override final  String? brandId;
/// store scope 일 때 채움. brand/master scope 에서는 null.
@override final  String? storeId;
@override final  String name;
@override final  OptionSelectionType selectionType;
@override@JsonKey() final  bool required;
 final  List<OptionItemEntity> _items;
@override@JsonKey() List<OptionItemEntity> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override@JsonKey() final  int displayOrder;
/// active=false 이면 메뉴 폼 및 고객 화면에서 숨겨짐.
@override@JsonKey() final  bool active;
@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of OptionGroupEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OptionGroupEntityCopyWith<_OptionGroupEntity> get copyWith => __$OptionGroupEntityCopyWithImpl<_OptionGroupEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OptionGroupEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.brandId, brandId) || other.brandId == brandId)&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.name, name) || other.name == name)&&(identical(other.selectionType, selectionType) || other.selectionType == selectionType)&&(identical(other.required, required) || other.required == required)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.displayOrder, displayOrder) || other.displayOrder == displayOrder)&&(identical(other.active, active) || other.active == active)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,scope,brandId,storeId,name,selectionType,required,const DeepCollectionEquality().hash(_items),displayOrder,active,createdAt,updatedAt);

@override
String toString() {
  return 'OptionGroupEntity(id: $id, scope: $scope, brandId: $brandId, storeId: $storeId, name: $name, selectionType: $selectionType, required: $required, items: $items, displayOrder: $displayOrder, active: $active, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$OptionGroupEntityCopyWith<$Res> implements $OptionGroupEntityCopyWith<$Res> {
  factory _$OptionGroupEntityCopyWith(_OptionGroupEntity value, $Res Function(_OptionGroupEntity) _then) = __$OptionGroupEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, OptionScope scope, String? brandId, String? storeId, String name, OptionSelectionType selectionType, bool required, List<OptionItemEntity> items, int displayOrder, bool active, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class __$OptionGroupEntityCopyWithImpl<$Res>
    implements _$OptionGroupEntityCopyWith<$Res> {
  __$OptionGroupEntityCopyWithImpl(this._self, this._then);

  final _OptionGroupEntity _self;
  final $Res Function(_OptionGroupEntity) _then;

/// Create a copy of OptionGroupEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? scope = null,Object? brandId = freezed,Object? storeId = freezed,Object? name = null,Object? selectionType = null,Object? required = null,Object? items = null,Object? displayOrder = null,Object? active = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_OptionGroupEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as OptionScope,brandId: freezed == brandId ? _self.brandId : brandId // ignore: cast_nullable_to_non_nullable
as String?,storeId: freezed == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,selectionType: null == selectionType ? _self.selectionType : selectionType // ignore: cast_nullable_to_non_nullable
as OptionSelectionType,required: null == required ? _self.required : required // ignore: cast_nullable_to_non_nullable
as bool,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<OptionItemEntity>,displayOrder: null == displayOrder ? _self.displayOrder : displayOrder // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
mixin _$OptionGroupRef {

 OptionScope get scope; String get id;
/// Create a copy of OptionGroupRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OptionGroupRefCopyWith<OptionGroupRef> get copyWith => _$OptionGroupRefCopyWithImpl<OptionGroupRef>(this as OptionGroupRef, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OptionGroupRef&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.id, id) || other.id == id));
}


@override
int get hashCode => Object.hash(runtimeType,scope,id);

@override
String toString() {
  return 'OptionGroupRef(scope: $scope, id: $id)';
}


}

/// @nodoc
abstract mixin class $OptionGroupRefCopyWith<$Res>  {
  factory $OptionGroupRefCopyWith(OptionGroupRef value, $Res Function(OptionGroupRef) _then) = _$OptionGroupRefCopyWithImpl;
@useResult
$Res call({
 OptionScope scope, String id
});




}
/// @nodoc
class _$OptionGroupRefCopyWithImpl<$Res>
    implements $OptionGroupRefCopyWith<$Res> {
  _$OptionGroupRefCopyWithImpl(this._self, this._then);

  final OptionGroupRef _self;
  final $Res Function(OptionGroupRef) _then;

/// Create a copy of OptionGroupRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? scope = null,Object? id = null,}) {
  return _then(_self.copyWith(
scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as OptionScope,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [OptionGroupRef].
extension OptionGroupRefPatterns on OptionGroupRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OptionGroupRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OptionGroupRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OptionGroupRef value)  $default,){
final _that = this;
switch (_that) {
case _OptionGroupRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OptionGroupRef value)?  $default,){
final _that = this;
switch (_that) {
case _OptionGroupRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( OptionScope scope,  String id)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OptionGroupRef() when $default != null:
return $default(_that.scope,_that.id);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( OptionScope scope,  String id)  $default,) {final _that = this;
switch (_that) {
case _OptionGroupRef():
return $default(_that.scope,_that.id);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( OptionScope scope,  String id)?  $default,) {final _that = this;
switch (_that) {
case _OptionGroupRef() when $default != null:
return $default(_that.scope,_that.id);case _:
  return null;

}
}

}

/// @nodoc


class _OptionGroupRef implements OptionGroupRef {
  const _OptionGroupRef({required this.scope, required this.id});
  

@override final  OptionScope scope;
@override final  String id;

/// Create a copy of OptionGroupRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OptionGroupRefCopyWith<_OptionGroupRef> get copyWith => __$OptionGroupRefCopyWithImpl<_OptionGroupRef>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OptionGroupRef&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.id, id) || other.id == id));
}


@override
int get hashCode => Object.hash(runtimeType,scope,id);

@override
String toString() {
  return 'OptionGroupRef(scope: $scope, id: $id)';
}


}

/// @nodoc
abstract mixin class _$OptionGroupRefCopyWith<$Res> implements $OptionGroupRefCopyWith<$Res> {
  factory _$OptionGroupRefCopyWith(_OptionGroupRef value, $Res Function(_OptionGroupRef) _then) = __$OptionGroupRefCopyWithImpl;
@override @useResult
$Res call({
 OptionScope scope, String id
});




}
/// @nodoc
class __$OptionGroupRefCopyWithImpl<$Res>
    implements _$OptionGroupRefCopyWith<$Res> {
  __$OptionGroupRefCopyWithImpl(this._self, this._then);

  final _OptionGroupRef _self;
  final $Res Function(_OptionGroupRef) _then;

/// Create a copy of OptionGroupRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? scope = null,Object? id = null,}) {
  return _then(_OptionGroupRef(
scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as OptionScope,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on

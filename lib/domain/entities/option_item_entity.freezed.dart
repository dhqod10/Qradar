// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'option_item_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$OptionItemEntity {

 String get id; String get label; int get priceDelta;
/// Create a copy of OptionItemEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OptionItemEntityCopyWith<OptionItemEntity> get copyWith => _$OptionItemEntityCopyWithImpl<OptionItemEntity>(this as OptionItemEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OptionItemEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.priceDelta, priceDelta) || other.priceDelta == priceDelta));
}


@override
int get hashCode => Object.hash(runtimeType,id,label,priceDelta);

@override
String toString() {
  return 'OptionItemEntity(id: $id, label: $label, priceDelta: $priceDelta)';
}


}

/// @nodoc
abstract mixin class $OptionItemEntityCopyWith<$Res>  {
  factory $OptionItemEntityCopyWith(OptionItemEntity value, $Res Function(OptionItemEntity) _then) = _$OptionItemEntityCopyWithImpl;
@useResult
$Res call({
 String id, String label, int priceDelta
});




}
/// @nodoc
class _$OptionItemEntityCopyWithImpl<$Res>
    implements $OptionItemEntityCopyWith<$Res> {
  _$OptionItemEntityCopyWithImpl(this._self, this._then);

  final OptionItemEntity _self;
  final $Res Function(OptionItemEntity) _then;

/// Create a copy of OptionItemEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? label = null,Object? priceDelta = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,priceDelta: null == priceDelta ? _self.priceDelta : priceDelta // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [OptionItemEntity].
extension OptionItemEntityPatterns on OptionItemEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OptionItemEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OptionItemEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OptionItemEntity value)  $default,){
final _that = this;
switch (_that) {
case _OptionItemEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OptionItemEntity value)?  $default,){
final _that = this;
switch (_that) {
case _OptionItemEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String label,  int priceDelta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OptionItemEntity() when $default != null:
return $default(_that.id,_that.label,_that.priceDelta);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String label,  int priceDelta)  $default,) {final _that = this;
switch (_that) {
case _OptionItemEntity():
return $default(_that.id,_that.label,_that.priceDelta);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String label,  int priceDelta)?  $default,) {final _that = this;
switch (_that) {
case _OptionItemEntity() when $default != null:
return $default(_that.id,_that.label,_that.priceDelta);case _:
  return null;

}
}

}

/// @nodoc


class _OptionItemEntity implements OptionItemEntity {
  const _OptionItemEntity({required this.id, required this.label, this.priceDelta = 0});
  

@override final  String id;
@override final  String label;
@override@JsonKey() final  int priceDelta;

/// Create a copy of OptionItemEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OptionItemEntityCopyWith<_OptionItemEntity> get copyWith => __$OptionItemEntityCopyWithImpl<_OptionItemEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OptionItemEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.priceDelta, priceDelta) || other.priceDelta == priceDelta));
}


@override
int get hashCode => Object.hash(runtimeType,id,label,priceDelta);

@override
String toString() {
  return 'OptionItemEntity(id: $id, label: $label, priceDelta: $priceDelta)';
}


}

/// @nodoc
abstract mixin class _$OptionItemEntityCopyWith<$Res> implements $OptionItemEntityCopyWith<$Res> {
  factory _$OptionItemEntityCopyWith(_OptionItemEntity value, $Res Function(_OptionItemEntity) _then) = __$OptionItemEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String label, int priceDelta
});




}
/// @nodoc
class __$OptionItemEntityCopyWithImpl<$Res>
    implements _$OptionItemEntityCopyWith<$Res> {
  __$OptionItemEntityCopyWithImpl(this._self, this._then);

  final _OptionItemEntity _self;
  final $Res Function(_OptionItemEntity) _then;

/// Create a copy of OptionItemEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? label = null,Object? priceDelta = null,}) {
  return _then(_OptionItemEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,priceDelta: null == priceDelta ? _self.priceDelta : priceDelta // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on

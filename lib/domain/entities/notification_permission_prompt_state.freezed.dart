// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_permission_prompt_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$NotificationPermissionPromptState {

/// OS 권한 시트 소진 이력 (다이얼로그에서 `허용` 선택).
 bool get prompted;/// `나중에` 선택 횟수. 필드 부재 시 0.
 int get laterCount;
/// Create a copy of NotificationPermissionPromptState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationPermissionPromptStateCopyWith<NotificationPermissionPromptState> get copyWith => _$NotificationPermissionPromptStateCopyWithImpl<NotificationPermissionPromptState>(this as NotificationPermissionPromptState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationPermissionPromptState&&(identical(other.prompted, prompted) || other.prompted == prompted)&&(identical(other.laterCount, laterCount) || other.laterCount == laterCount));
}


@override
int get hashCode => Object.hash(runtimeType,prompted,laterCount);

@override
String toString() {
  return 'NotificationPermissionPromptState(prompted: $prompted, laterCount: $laterCount)';
}


}

/// @nodoc
abstract mixin class $NotificationPermissionPromptStateCopyWith<$Res>  {
  factory $NotificationPermissionPromptStateCopyWith(NotificationPermissionPromptState value, $Res Function(NotificationPermissionPromptState) _then) = _$NotificationPermissionPromptStateCopyWithImpl;
@useResult
$Res call({
 bool prompted, int laterCount
});




}
/// @nodoc
class _$NotificationPermissionPromptStateCopyWithImpl<$Res>
    implements $NotificationPermissionPromptStateCopyWith<$Res> {
  _$NotificationPermissionPromptStateCopyWithImpl(this._self, this._then);

  final NotificationPermissionPromptState _self;
  final $Res Function(NotificationPermissionPromptState) _then;

/// Create a copy of NotificationPermissionPromptState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? prompted = null,Object? laterCount = null,}) {
  return _then(_self.copyWith(
prompted: null == prompted ? _self.prompted : prompted // ignore: cast_nullable_to_non_nullable
as bool,laterCount: null == laterCount ? _self.laterCount : laterCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationPermissionPromptState].
extension NotificationPermissionPromptStatePatterns on NotificationPermissionPromptState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationPermissionPromptState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationPermissionPromptState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationPermissionPromptState value)  $default,){
final _that = this;
switch (_that) {
case _NotificationPermissionPromptState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationPermissionPromptState value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationPermissionPromptState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool prompted,  int laterCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationPermissionPromptState() when $default != null:
return $default(_that.prompted,_that.laterCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool prompted,  int laterCount)  $default,) {final _that = this;
switch (_that) {
case _NotificationPermissionPromptState():
return $default(_that.prompted,_that.laterCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool prompted,  int laterCount)?  $default,) {final _that = this;
switch (_that) {
case _NotificationPermissionPromptState() when $default != null:
return $default(_that.prompted,_that.laterCount);case _:
  return null;

}
}

}

/// @nodoc


class _NotificationPermissionPromptState extends NotificationPermissionPromptState {
  const _NotificationPermissionPromptState({this.prompted = false, this.laterCount = 0}): super._();
  

/// OS 권한 시트 소진 이력 (다이얼로그에서 `허용` 선택).
@override@JsonKey() final  bool prompted;
/// `나중에` 선택 횟수. 필드 부재 시 0.
@override@JsonKey() final  int laterCount;

/// Create a copy of NotificationPermissionPromptState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationPermissionPromptStateCopyWith<_NotificationPermissionPromptState> get copyWith => __$NotificationPermissionPromptStateCopyWithImpl<_NotificationPermissionPromptState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationPermissionPromptState&&(identical(other.prompted, prompted) || other.prompted == prompted)&&(identical(other.laterCount, laterCount) || other.laterCount == laterCount));
}


@override
int get hashCode => Object.hash(runtimeType,prompted,laterCount);

@override
String toString() {
  return 'NotificationPermissionPromptState(prompted: $prompted, laterCount: $laterCount)';
}


}

/// @nodoc
abstract mixin class _$NotificationPermissionPromptStateCopyWith<$Res> implements $NotificationPermissionPromptStateCopyWith<$Res> {
  factory _$NotificationPermissionPromptStateCopyWith(_NotificationPermissionPromptState value, $Res Function(_NotificationPermissionPromptState) _then) = __$NotificationPermissionPromptStateCopyWithImpl;
@override @useResult
$Res call({
 bool prompted, int laterCount
});




}
/// @nodoc
class __$NotificationPermissionPromptStateCopyWithImpl<$Res>
    implements _$NotificationPermissionPromptStateCopyWith<$Res> {
  __$NotificationPermissionPromptStateCopyWithImpl(this._self, this._then);

  final _NotificationPermissionPromptState _self;
  final $Res Function(_NotificationPermissionPromptState) _then;

/// Create a copy of NotificationPermissionPromptState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? prompted = null,Object? laterCount = null,}) {
  return _then(_NotificationPermissionPromptState(
prompted: null == prompted ? _self.prompted : prompted // ignore: cast_nullable_to_non_nullable
as bool,laterCount: null == laterCount ? _self.laterCount : laterCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on

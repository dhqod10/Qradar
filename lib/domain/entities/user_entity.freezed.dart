// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UserEntity {

 String get uid; String? get email; String? get displayName; String? get photoUrl; String get provider;// 'google' | 'kakao' | 'naver' | 'email'
 UserRole get role; DateTime? get createdAt;/// role='brand' 일 때만 존재. Firestore 콘솔에서 수동 발급.
 String? get brandId;/// FCM 디바이스 토큰. 권한 거부/미발급 시 null.
 String? get fcmToken;/// 마지막 FCM 토큰 갱신 시각 (운영 가시성).
 DateTime? get fcmTokenUpdatedAt;/// 알림 권한 다이얼로그 노출 이력 (재요청 방지).
 bool get notificationPermissionPrompted;/// 알림 카테고리별 on/off (부재 시 기본값 fallback).
 NotificationSettingsEntity get notificationSettings;
/// Create a copy of UserEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserEntityCopyWith<UserEntity> get copyWith => _$UserEntityCopyWithImpl<UserEntity>(this as UserEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserEntity&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.email, email) || other.email == email)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.role, role) || other.role == role)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.brandId, brandId) || other.brandId == brandId)&&(identical(other.fcmToken, fcmToken) || other.fcmToken == fcmToken)&&(identical(other.fcmTokenUpdatedAt, fcmTokenUpdatedAt) || other.fcmTokenUpdatedAt == fcmTokenUpdatedAt)&&(identical(other.notificationPermissionPrompted, notificationPermissionPrompted) || other.notificationPermissionPrompted == notificationPermissionPrompted)&&(identical(other.notificationSettings, notificationSettings) || other.notificationSettings == notificationSettings));
}


@override
int get hashCode => Object.hash(runtimeType,uid,email,displayName,photoUrl,provider,role,createdAt,brandId,fcmToken,fcmTokenUpdatedAt,notificationPermissionPrompted,notificationSettings);

@override
String toString() {
  return 'UserEntity(uid: $uid, email: $email, displayName: $displayName, photoUrl: $photoUrl, provider: $provider, role: $role, createdAt: $createdAt, brandId: $brandId, fcmToken: $fcmToken, fcmTokenUpdatedAt: $fcmTokenUpdatedAt, notificationPermissionPrompted: $notificationPermissionPrompted, notificationSettings: $notificationSettings)';
}


}

/// @nodoc
abstract mixin class $UserEntityCopyWith<$Res>  {
  factory $UserEntityCopyWith(UserEntity value, $Res Function(UserEntity) _then) = _$UserEntityCopyWithImpl;
@useResult
$Res call({
 String uid, String? email, String? displayName, String? photoUrl, String provider, UserRole role, DateTime? createdAt, String? brandId, String? fcmToken, DateTime? fcmTokenUpdatedAt, bool notificationPermissionPrompted, NotificationSettingsEntity notificationSettings
});


$NotificationSettingsEntityCopyWith<$Res> get notificationSettings;

}
/// @nodoc
class _$UserEntityCopyWithImpl<$Res>
    implements $UserEntityCopyWith<$Res> {
  _$UserEntityCopyWithImpl(this._self, this._then);

  final UserEntity _self;
  final $Res Function(UserEntity) _then;

/// Create a copy of UserEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uid = null,Object? email = freezed,Object? displayName = freezed,Object? photoUrl = freezed,Object? provider = null,Object? role = null,Object? createdAt = freezed,Object? brandId = freezed,Object? fcmToken = freezed,Object? fcmTokenUpdatedAt = freezed,Object? notificationPermissionPrompted = null,Object? notificationSettings = null,}) {
  return _then(_self.copyWith(
uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as UserRole,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,brandId: freezed == brandId ? _self.brandId : brandId // ignore: cast_nullable_to_non_nullable
as String?,fcmToken: freezed == fcmToken ? _self.fcmToken : fcmToken // ignore: cast_nullable_to_non_nullable
as String?,fcmTokenUpdatedAt: freezed == fcmTokenUpdatedAt ? _self.fcmTokenUpdatedAt : fcmTokenUpdatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,notificationPermissionPrompted: null == notificationPermissionPrompted ? _self.notificationPermissionPrompted : notificationPermissionPrompted // ignore: cast_nullable_to_non_nullable
as bool,notificationSettings: null == notificationSettings ? _self.notificationSettings : notificationSettings // ignore: cast_nullable_to_non_nullable
as NotificationSettingsEntity,
  ));
}
/// Create a copy of UserEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NotificationSettingsEntityCopyWith<$Res> get notificationSettings {
  
  return $NotificationSettingsEntityCopyWith<$Res>(_self.notificationSettings, (value) {
    return _then(_self.copyWith(notificationSettings: value));
  });
}
}


/// Adds pattern-matching-related methods to [UserEntity].
extension UserEntityPatterns on UserEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserEntity value)  $default,){
final _that = this;
switch (_that) {
case _UserEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserEntity value)?  $default,){
final _that = this;
switch (_that) {
case _UserEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String uid,  String? email,  String? displayName,  String? photoUrl,  String provider,  UserRole role,  DateTime? createdAt,  String? brandId,  String? fcmToken,  DateTime? fcmTokenUpdatedAt,  bool notificationPermissionPrompted,  NotificationSettingsEntity notificationSettings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserEntity() when $default != null:
return $default(_that.uid,_that.email,_that.displayName,_that.photoUrl,_that.provider,_that.role,_that.createdAt,_that.brandId,_that.fcmToken,_that.fcmTokenUpdatedAt,_that.notificationPermissionPrompted,_that.notificationSettings);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String uid,  String? email,  String? displayName,  String? photoUrl,  String provider,  UserRole role,  DateTime? createdAt,  String? brandId,  String? fcmToken,  DateTime? fcmTokenUpdatedAt,  bool notificationPermissionPrompted,  NotificationSettingsEntity notificationSettings)  $default,) {final _that = this;
switch (_that) {
case _UserEntity():
return $default(_that.uid,_that.email,_that.displayName,_that.photoUrl,_that.provider,_that.role,_that.createdAt,_that.brandId,_that.fcmToken,_that.fcmTokenUpdatedAt,_that.notificationPermissionPrompted,_that.notificationSettings);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String uid,  String? email,  String? displayName,  String? photoUrl,  String provider,  UserRole role,  DateTime? createdAt,  String? brandId,  String? fcmToken,  DateTime? fcmTokenUpdatedAt,  bool notificationPermissionPrompted,  NotificationSettingsEntity notificationSettings)?  $default,) {final _that = this;
switch (_that) {
case _UserEntity() when $default != null:
return $default(_that.uid,_that.email,_that.displayName,_that.photoUrl,_that.provider,_that.role,_that.createdAt,_that.brandId,_that.fcmToken,_that.fcmTokenUpdatedAt,_that.notificationPermissionPrompted,_that.notificationSettings);case _:
  return null;

}
}

}

/// @nodoc


class _UserEntity implements UserEntity {
  const _UserEntity({required this.uid, this.email, this.displayName, this.photoUrl, required this.provider, this.role = UserRole.customer, this.createdAt, this.brandId, this.fcmToken, this.fcmTokenUpdatedAt, this.notificationPermissionPrompted = false, this.notificationSettings = const NotificationSettingsEntity()});
  

@override final  String uid;
@override final  String? email;
@override final  String? displayName;
@override final  String? photoUrl;
@override final  String provider;
// 'google' | 'kakao' | 'naver' | 'email'
@override@JsonKey() final  UserRole role;
@override final  DateTime? createdAt;
/// role='brand' 일 때만 존재. Firestore 콘솔에서 수동 발급.
@override final  String? brandId;
/// FCM 디바이스 토큰. 권한 거부/미발급 시 null.
@override final  String? fcmToken;
/// 마지막 FCM 토큰 갱신 시각 (운영 가시성).
@override final  DateTime? fcmTokenUpdatedAt;
/// 알림 권한 다이얼로그 노출 이력 (재요청 방지).
@override@JsonKey() final  bool notificationPermissionPrompted;
/// 알림 카테고리별 on/off (부재 시 기본값 fallback).
@override@JsonKey() final  NotificationSettingsEntity notificationSettings;

/// Create a copy of UserEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserEntityCopyWith<_UserEntity> get copyWith => __$UserEntityCopyWithImpl<_UserEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserEntity&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.email, email) || other.email == email)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.role, role) || other.role == role)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.brandId, brandId) || other.brandId == brandId)&&(identical(other.fcmToken, fcmToken) || other.fcmToken == fcmToken)&&(identical(other.fcmTokenUpdatedAt, fcmTokenUpdatedAt) || other.fcmTokenUpdatedAt == fcmTokenUpdatedAt)&&(identical(other.notificationPermissionPrompted, notificationPermissionPrompted) || other.notificationPermissionPrompted == notificationPermissionPrompted)&&(identical(other.notificationSettings, notificationSettings) || other.notificationSettings == notificationSettings));
}


@override
int get hashCode => Object.hash(runtimeType,uid,email,displayName,photoUrl,provider,role,createdAt,brandId,fcmToken,fcmTokenUpdatedAt,notificationPermissionPrompted,notificationSettings);

@override
String toString() {
  return 'UserEntity(uid: $uid, email: $email, displayName: $displayName, photoUrl: $photoUrl, provider: $provider, role: $role, createdAt: $createdAt, brandId: $brandId, fcmToken: $fcmToken, fcmTokenUpdatedAt: $fcmTokenUpdatedAt, notificationPermissionPrompted: $notificationPermissionPrompted, notificationSettings: $notificationSettings)';
}


}

/// @nodoc
abstract mixin class _$UserEntityCopyWith<$Res> implements $UserEntityCopyWith<$Res> {
  factory _$UserEntityCopyWith(_UserEntity value, $Res Function(_UserEntity) _then) = __$UserEntityCopyWithImpl;
@override @useResult
$Res call({
 String uid, String? email, String? displayName, String? photoUrl, String provider, UserRole role, DateTime? createdAt, String? brandId, String? fcmToken, DateTime? fcmTokenUpdatedAt, bool notificationPermissionPrompted, NotificationSettingsEntity notificationSettings
});


@override $NotificationSettingsEntityCopyWith<$Res> get notificationSettings;

}
/// @nodoc
class __$UserEntityCopyWithImpl<$Res>
    implements _$UserEntityCopyWith<$Res> {
  __$UserEntityCopyWithImpl(this._self, this._then);

  final _UserEntity _self;
  final $Res Function(_UserEntity) _then;

/// Create a copy of UserEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uid = null,Object? email = freezed,Object? displayName = freezed,Object? photoUrl = freezed,Object? provider = null,Object? role = null,Object? createdAt = freezed,Object? brandId = freezed,Object? fcmToken = freezed,Object? fcmTokenUpdatedAt = freezed,Object? notificationPermissionPrompted = null,Object? notificationSettings = null,}) {
  return _then(_UserEntity(
uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as UserRole,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,brandId: freezed == brandId ? _self.brandId : brandId // ignore: cast_nullable_to_non_nullable
as String?,fcmToken: freezed == fcmToken ? _self.fcmToken : fcmToken // ignore: cast_nullable_to_non_nullable
as String?,fcmTokenUpdatedAt: freezed == fcmTokenUpdatedAt ? _self.fcmTokenUpdatedAt : fcmTokenUpdatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,notificationPermissionPrompted: null == notificationPermissionPrompted ? _self.notificationPermissionPrompted : notificationPermissionPrompted // ignore: cast_nullable_to_non_nullable
as bool,notificationSettings: null == notificationSettings ? _self.notificationSettings : notificationSettings // ignore: cast_nullable_to_non_nullable
as NotificationSettingsEntity,
  ));
}

/// Create a copy of UserEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NotificationSettingsEntityCopyWith<$Res> get notificationSettings {
  
  return $NotificationSettingsEntityCopyWith<$Res>(_self.notificationSettings, (value) {
    return _then(_self.copyWith(notificationSettings: value));
  });
}
}

// dart format on

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserModel {

 String get uid; String? get email;@JsonKey(name: 'display_name') String? get displayName;@JsonKey(name: 'photo_url') String? get photoUrl; String get provider; String get role; DateTime? get createdAt;/// role='brand' 일 때만 존재. Firestore 콘솔에서 수동 발급.
 String? get brandId;/// FCM 디바이스 토큰 (Phase 3b). JSON 직렬화 제외 (Firestore 전용 필드).
@JsonKey(includeFromJson: false, includeToJson: false) String? get fcmToken;/// 마지막 FCM 토큰 갱신 시각 (Phase 3b). JSON 직렬화 제외.
@JsonKey(includeFromJson: false, includeToJson: false) DateTime? get fcmTokenUpdatedAt;/// OS 권한 시트 소진 이력 (`허용` 선택). JSON 직렬화 제외.
@JsonKey(includeFromJson: false, includeToJson: false) bool get notificationPermissionPrompted;/// `나중에` 선택 횟수 (Phase 3c-4). JSON 직렬화 제외.
@JsonKey(includeFromJson: false, includeToJson: false) int get notificationPermissionLaterCount;/// 알림 카테고리별 설정 (Phase 3c-3). JSON 직렬화 제외.
@JsonKey(includeFromJson: false, includeToJson: false) NotificationSettingsEntity get notificationSettings;
/// Create a copy of UserModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserModelCopyWith<UserModel> get copyWith => _$UserModelCopyWithImpl<UserModel>(this as UserModel, _$identity);

  /// Serializes this UserModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserModel&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.email, email) || other.email == email)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.role, role) || other.role == role)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.brandId, brandId) || other.brandId == brandId)&&(identical(other.fcmToken, fcmToken) || other.fcmToken == fcmToken)&&(identical(other.fcmTokenUpdatedAt, fcmTokenUpdatedAt) || other.fcmTokenUpdatedAt == fcmTokenUpdatedAt)&&(identical(other.notificationPermissionPrompted, notificationPermissionPrompted) || other.notificationPermissionPrompted == notificationPermissionPrompted)&&(identical(other.notificationPermissionLaterCount, notificationPermissionLaterCount) || other.notificationPermissionLaterCount == notificationPermissionLaterCount)&&(identical(other.notificationSettings, notificationSettings) || other.notificationSettings == notificationSettings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uid,email,displayName,photoUrl,provider,role,createdAt,brandId,fcmToken,fcmTokenUpdatedAt,notificationPermissionPrompted,notificationPermissionLaterCount,notificationSettings);

@override
String toString() {
  return 'UserModel(uid: $uid, email: $email, displayName: $displayName, photoUrl: $photoUrl, provider: $provider, role: $role, createdAt: $createdAt, brandId: $brandId, fcmToken: $fcmToken, fcmTokenUpdatedAt: $fcmTokenUpdatedAt, notificationPermissionPrompted: $notificationPermissionPrompted, notificationPermissionLaterCount: $notificationPermissionLaterCount, notificationSettings: $notificationSettings)';
}


}

/// @nodoc
abstract mixin class $UserModelCopyWith<$Res>  {
  factory $UserModelCopyWith(UserModel value, $Res Function(UserModel) _then) = _$UserModelCopyWithImpl;
@useResult
$Res call({
 String uid, String? email,@JsonKey(name: 'display_name') String? displayName,@JsonKey(name: 'photo_url') String? photoUrl, String provider, String role, DateTime? createdAt, String? brandId,@JsonKey(includeFromJson: false, includeToJson: false) String? fcmToken,@JsonKey(includeFromJson: false, includeToJson: false) DateTime? fcmTokenUpdatedAt,@JsonKey(includeFromJson: false, includeToJson: false) bool notificationPermissionPrompted,@JsonKey(includeFromJson: false, includeToJson: false) int notificationPermissionLaterCount,@JsonKey(includeFromJson: false, includeToJson: false) NotificationSettingsEntity notificationSettings
});


$NotificationSettingsEntityCopyWith<$Res> get notificationSettings;

}
/// @nodoc
class _$UserModelCopyWithImpl<$Res>
    implements $UserModelCopyWith<$Res> {
  _$UserModelCopyWithImpl(this._self, this._then);

  final UserModel _self;
  final $Res Function(UserModel) _then;

/// Create a copy of UserModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uid = null,Object? email = freezed,Object? displayName = freezed,Object? photoUrl = freezed,Object? provider = null,Object? role = null,Object? createdAt = freezed,Object? brandId = freezed,Object? fcmToken = freezed,Object? fcmTokenUpdatedAt = freezed,Object? notificationPermissionPrompted = null,Object? notificationPermissionLaterCount = null,Object? notificationSettings = null,}) {
  return _then(_self.copyWith(
uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,brandId: freezed == brandId ? _self.brandId : brandId // ignore: cast_nullable_to_non_nullable
as String?,fcmToken: freezed == fcmToken ? _self.fcmToken : fcmToken // ignore: cast_nullable_to_non_nullable
as String?,fcmTokenUpdatedAt: freezed == fcmTokenUpdatedAt ? _self.fcmTokenUpdatedAt : fcmTokenUpdatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,notificationPermissionPrompted: null == notificationPermissionPrompted ? _self.notificationPermissionPrompted : notificationPermissionPrompted // ignore: cast_nullable_to_non_nullable
as bool,notificationPermissionLaterCount: null == notificationPermissionLaterCount ? _self.notificationPermissionLaterCount : notificationPermissionLaterCount // ignore: cast_nullable_to_non_nullable
as int,notificationSettings: null == notificationSettings ? _self.notificationSettings : notificationSettings // ignore: cast_nullable_to_non_nullable
as NotificationSettingsEntity,
  ));
}
/// Create a copy of UserModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NotificationSettingsEntityCopyWith<$Res> get notificationSettings {
  
  return $NotificationSettingsEntityCopyWith<$Res>(_self.notificationSettings, (value) {
    return _then(_self.copyWith(notificationSettings: value));
  });
}
}


/// Adds pattern-matching-related methods to [UserModel].
extension UserModelPatterns on UserModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserModel value)  $default,){
final _that = this;
switch (_that) {
case _UserModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserModel value)?  $default,){
final _that = this;
switch (_that) {
case _UserModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String uid,  String? email, @JsonKey(name: 'display_name')  String? displayName, @JsonKey(name: 'photo_url')  String? photoUrl,  String provider,  String role,  DateTime? createdAt,  String? brandId, @JsonKey(includeFromJson: false, includeToJson: false)  String? fcmToken, @JsonKey(includeFromJson: false, includeToJson: false)  DateTime? fcmTokenUpdatedAt, @JsonKey(includeFromJson: false, includeToJson: false)  bool notificationPermissionPrompted, @JsonKey(includeFromJson: false, includeToJson: false)  int notificationPermissionLaterCount, @JsonKey(includeFromJson: false, includeToJson: false)  NotificationSettingsEntity notificationSettings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserModel() when $default != null:
return $default(_that.uid,_that.email,_that.displayName,_that.photoUrl,_that.provider,_that.role,_that.createdAt,_that.brandId,_that.fcmToken,_that.fcmTokenUpdatedAt,_that.notificationPermissionPrompted,_that.notificationPermissionLaterCount,_that.notificationSettings);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String uid,  String? email, @JsonKey(name: 'display_name')  String? displayName, @JsonKey(name: 'photo_url')  String? photoUrl,  String provider,  String role,  DateTime? createdAt,  String? brandId, @JsonKey(includeFromJson: false, includeToJson: false)  String? fcmToken, @JsonKey(includeFromJson: false, includeToJson: false)  DateTime? fcmTokenUpdatedAt, @JsonKey(includeFromJson: false, includeToJson: false)  bool notificationPermissionPrompted, @JsonKey(includeFromJson: false, includeToJson: false)  int notificationPermissionLaterCount, @JsonKey(includeFromJson: false, includeToJson: false)  NotificationSettingsEntity notificationSettings)  $default,) {final _that = this;
switch (_that) {
case _UserModel():
return $default(_that.uid,_that.email,_that.displayName,_that.photoUrl,_that.provider,_that.role,_that.createdAt,_that.brandId,_that.fcmToken,_that.fcmTokenUpdatedAt,_that.notificationPermissionPrompted,_that.notificationPermissionLaterCount,_that.notificationSettings);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String uid,  String? email, @JsonKey(name: 'display_name')  String? displayName, @JsonKey(name: 'photo_url')  String? photoUrl,  String provider,  String role,  DateTime? createdAt,  String? brandId, @JsonKey(includeFromJson: false, includeToJson: false)  String? fcmToken, @JsonKey(includeFromJson: false, includeToJson: false)  DateTime? fcmTokenUpdatedAt, @JsonKey(includeFromJson: false, includeToJson: false)  bool notificationPermissionPrompted, @JsonKey(includeFromJson: false, includeToJson: false)  int notificationPermissionLaterCount, @JsonKey(includeFromJson: false, includeToJson: false)  NotificationSettingsEntity notificationSettings)?  $default,) {final _that = this;
switch (_that) {
case _UserModel() when $default != null:
return $default(_that.uid,_that.email,_that.displayName,_that.photoUrl,_that.provider,_that.role,_that.createdAt,_that.brandId,_that.fcmToken,_that.fcmTokenUpdatedAt,_that.notificationPermissionPrompted,_that.notificationPermissionLaterCount,_that.notificationSettings);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserModel implements UserModel {
  const _UserModel({required this.uid, this.email, @JsonKey(name: 'display_name') this.displayName, @JsonKey(name: 'photo_url') this.photoUrl, required this.provider, this.role = 'customer', this.createdAt, this.brandId, @JsonKey(includeFromJson: false, includeToJson: false) this.fcmToken, @JsonKey(includeFromJson: false, includeToJson: false) this.fcmTokenUpdatedAt, @JsonKey(includeFromJson: false, includeToJson: false) this.notificationPermissionPrompted = false, @JsonKey(includeFromJson: false, includeToJson: false) this.notificationPermissionLaterCount = 0, @JsonKey(includeFromJson: false, includeToJson: false) this.notificationSettings = const NotificationSettingsEntity()});
  factory _UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);

@override final  String uid;
@override final  String? email;
@override@JsonKey(name: 'display_name') final  String? displayName;
@override@JsonKey(name: 'photo_url') final  String? photoUrl;
@override final  String provider;
@override@JsonKey() final  String role;
@override final  DateTime? createdAt;
/// role='brand' 일 때만 존재. Firestore 콘솔에서 수동 발급.
@override final  String? brandId;
/// FCM 디바이스 토큰 (Phase 3b). JSON 직렬화 제외 (Firestore 전용 필드).
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String? fcmToken;
/// 마지막 FCM 토큰 갱신 시각 (Phase 3b). JSON 직렬화 제외.
@override@JsonKey(includeFromJson: false, includeToJson: false) final  DateTime? fcmTokenUpdatedAt;
/// OS 권한 시트 소진 이력 (`허용` 선택). JSON 직렬화 제외.
@override@JsonKey(includeFromJson: false, includeToJson: false) final  bool notificationPermissionPrompted;
/// `나중에` 선택 횟수 (Phase 3c-4). JSON 직렬화 제외.
@override@JsonKey(includeFromJson: false, includeToJson: false) final  int notificationPermissionLaterCount;
/// 알림 카테고리별 설정 (Phase 3c-3). JSON 직렬화 제외.
@override@JsonKey(includeFromJson: false, includeToJson: false) final  NotificationSettingsEntity notificationSettings;

/// Create a copy of UserModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserModelCopyWith<_UserModel> get copyWith => __$UserModelCopyWithImpl<_UserModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserModel&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.email, email) || other.email == email)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.role, role) || other.role == role)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.brandId, brandId) || other.brandId == brandId)&&(identical(other.fcmToken, fcmToken) || other.fcmToken == fcmToken)&&(identical(other.fcmTokenUpdatedAt, fcmTokenUpdatedAt) || other.fcmTokenUpdatedAt == fcmTokenUpdatedAt)&&(identical(other.notificationPermissionPrompted, notificationPermissionPrompted) || other.notificationPermissionPrompted == notificationPermissionPrompted)&&(identical(other.notificationPermissionLaterCount, notificationPermissionLaterCount) || other.notificationPermissionLaterCount == notificationPermissionLaterCount)&&(identical(other.notificationSettings, notificationSettings) || other.notificationSettings == notificationSettings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uid,email,displayName,photoUrl,provider,role,createdAt,brandId,fcmToken,fcmTokenUpdatedAt,notificationPermissionPrompted,notificationPermissionLaterCount,notificationSettings);

@override
String toString() {
  return 'UserModel(uid: $uid, email: $email, displayName: $displayName, photoUrl: $photoUrl, provider: $provider, role: $role, createdAt: $createdAt, brandId: $brandId, fcmToken: $fcmToken, fcmTokenUpdatedAt: $fcmTokenUpdatedAt, notificationPermissionPrompted: $notificationPermissionPrompted, notificationPermissionLaterCount: $notificationPermissionLaterCount, notificationSettings: $notificationSettings)';
}


}

/// @nodoc
abstract mixin class _$UserModelCopyWith<$Res> implements $UserModelCopyWith<$Res> {
  factory _$UserModelCopyWith(_UserModel value, $Res Function(_UserModel) _then) = __$UserModelCopyWithImpl;
@override @useResult
$Res call({
 String uid, String? email,@JsonKey(name: 'display_name') String? displayName,@JsonKey(name: 'photo_url') String? photoUrl, String provider, String role, DateTime? createdAt, String? brandId,@JsonKey(includeFromJson: false, includeToJson: false) String? fcmToken,@JsonKey(includeFromJson: false, includeToJson: false) DateTime? fcmTokenUpdatedAt,@JsonKey(includeFromJson: false, includeToJson: false) bool notificationPermissionPrompted,@JsonKey(includeFromJson: false, includeToJson: false) int notificationPermissionLaterCount,@JsonKey(includeFromJson: false, includeToJson: false) NotificationSettingsEntity notificationSettings
});


@override $NotificationSettingsEntityCopyWith<$Res> get notificationSettings;

}
/// @nodoc
class __$UserModelCopyWithImpl<$Res>
    implements _$UserModelCopyWith<$Res> {
  __$UserModelCopyWithImpl(this._self, this._then);

  final _UserModel _self;
  final $Res Function(_UserModel) _then;

/// Create a copy of UserModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uid = null,Object? email = freezed,Object? displayName = freezed,Object? photoUrl = freezed,Object? provider = null,Object? role = null,Object? createdAt = freezed,Object? brandId = freezed,Object? fcmToken = freezed,Object? fcmTokenUpdatedAt = freezed,Object? notificationPermissionPrompted = null,Object? notificationPermissionLaterCount = null,Object? notificationSettings = null,}) {
  return _then(_UserModel(
uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,brandId: freezed == brandId ? _self.brandId : brandId // ignore: cast_nullable_to_non_nullable
as String?,fcmToken: freezed == fcmToken ? _self.fcmToken : fcmToken // ignore: cast_nullable_to_non_nullable
as String?,fcmTokenUpdatedAt: freezed == fcmTokenUpdatedAt ? _self.fcmTokenUpdatedAt : fcmTokenUpdatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,notificationPermissionPrompted: null == notificationPermissionPrompted ? _self.notificationPermissionPrompted : notificationPermissionPrompted // ignore: cast_nullable_to_non_nullable
as bool,notificationPermissionLaterCount: null == notificationPermissionLaterCount ? _self.notificationPermissionLaterCount : notificationPermissionLaterCount // ignore: cast_nullable_to_non_nullable
as int,notificationSettings: null == notificationSettings ? _self.notificationSettings : notificationSettings // ignore: cast_nullable_to_non_nullable
as NotificationSettingsEntity,
  ));
}

/// Create a copy of UserModel
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

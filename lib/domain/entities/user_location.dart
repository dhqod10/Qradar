import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_location.freezed.dart';

/// Qrator의 현재 위치. 권한 거부/오류 시 기본값(서울 시청) 사용.
@freezed
abstract class UserLocation with _$UserLocation {
  const factory UserLocation({
    required double latitude,
    required double longitude,
    @Default(false) bool isFallback,
  }) = _UserLocation;
}

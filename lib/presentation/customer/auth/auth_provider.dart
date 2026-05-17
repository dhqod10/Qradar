import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:qradar/data/datasources/remote/auth_remote_data_source.dart';
import 'package:qradar/data/repositories/auth_repository_impl.dart';
import 'package:qradar/domain/entities/user_entity.dart';
import 'package:qradar/domain/repositories/auth_repository.dart';
import 'package:qradar/domain/usecases/sign_in_with_email_use_case.dart';
import 'package:qradar/domain/usecases/sign_in_with_google_use_case.dart';
import 'package:qradar/domain/usecases/sign_in_with_kakao_use_case.dart';
import 'package:qradar/domain/usecases/sign_in_with_naver_use_case.dart';
import 'package:qradar/domain/usecases/sign_out_use_case.dart';
import 'package:qradar/domain/usecases/sign_up_with_email_use_case.dart';

// ── 인프라 Provider ────────────────────────────────────────────────────────

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(firebaseAuth: FirebaseAuth.instance);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider));
});

// ── UseCase Provider ───────────────────────────────────────────────────────

final signInWithGoogleUseCaseProvider = Provider<SignInWithGoogleUseCase>((ref) {
  return SignInWithGoogleUseCase(ref.watch(authRepositoryProvider));
});

final signInWithKakaoUseCaseProvider = Provider<SignInWithKakaoUseCase>((ref) {
  return SignInWithKakaoUseCase(ref.watch(authRepositoryProvider));
});

final signInWithNaverUseCaseProvider = Provider<SignInWithNaverUseCase>((ref) {
  return SignInWithNaverUseCase(ref.watch(authRepositoryProvider));
});

final signOutUseCaseProvider = Provider<SignOutUseCase>((ref) {
  return SignOutUseCase(ref.watch(authRepositoryProvider));
});

final signInWithEmailUseCaseProvider = Provider<SignInWithEmailUseCase>((ref) {
  return SignInWithEmailUseCase(ref.watch(authRepositoryProvider));
});

final signUpWithEmailUseCaseProvider = Provider<SignUpWithEmailUseCase>((ref) {
  return SignUpWithEmailUseCase(ref.watch(authRepositoryProvider));
});

// ── Auth Notifier ──────────────────────────────────────────────────────────

class AuthNotifier extends AsyncNotifier<UserEntity?> {
  @override
  Future<UserEntity?> build() async {
    // Firebase Auth 세션 확인 (Google, Email)
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      final provider = firebaseUser.providerData.isNotEmpty
          ? firebaseUser.providerData.first.providerId
          : 'unknown';
      return UserEntity(
        uid: firebaseUser.uid,
        email: firebaseUser.email,
        displayName: firebaseUser.displayName,
        photoUrl: firebaseUser.photoURL,
        provider: provider,
      );
    }

    // 카카오 토큰 확인
    try {
      if (await kakao.AuthApi.instance.hasToken()) {
        final kakaoUser = await kakao.UserApi.instance.me();
        return UserEntity(
          uid: 'kakao_${kakaoUser.id}',
          email: kakaoUser.kakaoAccount?.email,
          displayName: kakaoUser.kakaoAccount?.profile?.nickname,
          photoUrl: kakaoUser.kakaoAccount?.profile?.profileImageUrl,
          provider: 'kakao',
        );
      }
    } catch (_) {}

    // 네이버 토큰 확인
    try {
      final isNaverLoggedIn = await FlutterNaverLogin.isLoggedIn();
      if (isNaverLoggedIn) {
        final account = await FlutterNaverLogin.getCurrentAccount();
        return UserEntity(
          uid: 'naver_${account.id}',
          email: account.email,
          displayName: account.name,
          photoUrl: account.profileImage,
          provider: 'naver',
        );
      }
    } catch (_) {}

    return null;
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(signInWithGoogleUseCaseProvider).call(),
    );
  }

  Future<void> signInWithKakao() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        return await ref
            .read(signInWithKakaoUseCaseProvider)
            .call()
            .timeout(const Duration(seconds: 60));
      } on TimeoutException {
        // 60초 timeout — 카톡 강제 종료 등 SDK 응답 누락 안전망 (C안의 A)
        throw Exception('카카오 로그인이 취소되었습니다. (timeout)');
      }
    });
  }

  /// SNS 로그인 진행 중 사용자가 외부 앱(카톡 등)을 강제 종료한 뒤 우리 앱으로
  /// 돌아왔을 때 호출 — 무한 로딩 해제 (C안의 B). 현재 state 가 loading 일 때만
  /// silent cancel 처리.
  void cancelSignIn() {
    if (state is AsyncLoading) {
      state = const AsyncData(null);
    }
  }

  Future<void> signInWithNaver() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(signInWithNaverUseCaseProvider).call(),
    );
  }

  Future<void> signInWithEmail({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(signInWithEmailUseCaseProvider).call(email: email, password: password),
    );
  }

  Future<void> signUpWithEmail({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(signUpWithEmailUseCaseProvider).call(email: email, password: password),
    );
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    await ref.read(signOutUseCaseProvider).call();
    state = const AsyncData(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, UserEntity?>(
  AuthNotifier.new,
);

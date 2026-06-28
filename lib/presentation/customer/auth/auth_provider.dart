import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
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
import 'package:qradar/presentation/common/notification/providers/notification_providers.dart';

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
    // Firebase Auth 세션 확인
    // Naver/Kakao 로그인도 Custom Token을 통해 Firebase Auth 세션으로 통합되므로
    // FirebaseAuth.currentUser 하나만 확인하면 된다.
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return null;

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

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(signInWithGoogleUseCaseProvider).call(),
    );
    await _onSignInSuccess();
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
    await _onSignInSuccess();
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
    await _onSignInSuccess();
  }

  Future<void> signInWithEmail({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(signInWithEmailUseCaseProvider).call(email: email, password: password),
    );
    await _onSignInSuccess();
  }

  Future<void> signUpWithEmail({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(signUpWithEmailUseCaseProvider).call(email: email, password: password),
    );
    await _onSignInSuccess();
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    // FCM 토큰 정리 (Auth 끊기 전에 수행 — Rules: 본인 self-update 통과)
    final uid = state.asData?.value?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await ref.read(clearFcmTokenUseCaseProvider).call(uid);
    }
    await ref.read(signOutUseCaseProvider).call();
    state = const AsyncData(null);
  }

  /// 로그인 성공 후 FCM 토큰 자동 등록 (silent — 실패해도 로그인 영향 없음).
  Future<void> _onSignInSuccess() async {
    final uid = state.asData?.value?.uid;
    if (uid == null) return;
    await ref.read(registerFcmTokenUseCaseProvider).call(uid);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, UserEntity?>(
  AuthNotifier.new,
);

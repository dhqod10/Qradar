import 'dart:convert';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:qradar/data/models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> signInWithGoogle();
  Future<UserModel> signInWithKakao();
  Future<UserModel> signInWithNaver();
  Future<UserModel> signInWithEmail({required String email, required String password});
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
  });
  Future<void> signOut();
  Stream<UserModel?> get authStateChanges;

  /// 현재 로그인된 사용자 (없으면 null).
  ///
  /// Naver / Kakao 로그인도 Custom Token 으로 Firebase Auth 세션에 통합되므로
  /// 이 하나로 모든 provider 의 세션을 확인할 수 있다.
  UserModel? get currentUser;
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _firebaseAuth;

  AuthRemoteDataSourceImpl({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  /// Firebase `User` → `UserModel` 변환 (세션 조회 / authStateChanges 공용).
  static UserModel? _toModel(User? user) {
    if (user == null) return null;
    final provider = user.providerData.isNotEmpty
        ? user.providerData.first.providerId
        : 'unknown';
    return UserModel(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      provider: provider,
    );
  }

  @override
  UserModel? get currentUser => _toModel(_firebaseAuth.currentUser);

  // ── Google ────────────────────────────────────────────────────────────────

  @override
  Future<UserModel> signInWithGoogle() async {
    // google_sign_in v7: GoogleSignIn.instance 싱글톤 사용
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final result = await _firebaseAuth.signInWithCredential(credential);
    final user = result.user!;

    return UserModel(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      provider: 'google',
    );
  }

  // ── Kakao ─────────────────────────────────────────────────────────────────

  @override
  Future<UserModel> signInWithKakao() async {
    // KakaoTalk 설치 여부에 따라 로그인 방식 분기.
    // 카톡 앱 경로가 실패하면(계정 미연결 NotSupportError 등) 카카오계정(웹) 로그인으로 폴백한다.
    // 단 사용자가 명시적으로 취소(CANCELED)한 경우는 폴백하지 않고 그대로 전파한다. (카카오 공식 권장 패턴)
    if (await kakao.isKakaoTalkInstalled()) {
      try {
        await kakao.UserApi.instance.loginWithKakaoTalk();
      } catch (e) {
        if (e is PlatformException && e.code == 'CANCELED') rethrow;
        await kakao.UserApi.instance.loginWithKakaoAccount();
      }
    } else {
      await kakao.UserApi.instance.loginWithKakaoAccount();
    }

    // Kakao access token 취득
    final oauthToken =
        await kakao.TokenManagerProvider.instance.manager.getToken();
    if (oauthToken == null) {
      throw Exception('Kakao access token을 가져올 수 없습니다.');
    }

    // Cloud Function 으로 custom token 발급
    final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
        .httpsCallable('verifyKakaoToken');
    final response = await callable.call<Map<String, dynamic>>({
      'accessToken': oauthToken.accessToken,
    });
    final customToken = response.data['customToken'] as String;

    // Firebase Auth 세션 생성
    final credential = await _firebaseAuth.signInWithCustomToken(customToken);
    final user = credential.user!;

    // 프로필 정보는 Kakao SDK 에서 별도 조회
    final kakaoUser = await kakao.UserApi.instance.me();

    return UserModel(
      uid: user.uid,
      email: kakaoUser.kakaoAccount?.email,
      displayName: kakaoUser.kakaoAccount?.profile?.nickname,
      photoUrl: kakaoUser.kakaoAccount?.profile?.profileImageUrl,
      provider: 'kakao',
    );
  }

  // ── Naver ─────────────────────────────────────────────────────────────────

  // env.json (--dart-define-from-file) 로 주입. 코드 하드코딩 금지.
  static const String _naverClientId = String.fromEnvironment('NAVER_CLIENT_ID');

  // 네이버 콘솔 Callback URL(https 중계 페이지, landing/auth/naver.html).
  // 서버 NAVER_ALLOWED_REDIRECT_URIS 화이트리스트와 정확히 일치해야 한다.
  static const String _naverRedirectUri =
      'https://order-app-5957e.web.app/auth/naver.html';

  /// 암호학적 난수 state (CSRF 방지, 1회용).
  static String _generateState() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  @override
  Future<UserModel> signInWithNaver() async {
    if (_naverClientId.isEmpty) {
      throw Exception('NAVER_CLIENT_ID 가 주입되지 않았습니다. (env.json)');
    }

    final state = _generateState();
    final authorizeUrl = Uri.https('nid.naver.com', '/oauth2.0/authorize', {
      'response_type': 'code',
      'client_id': _naverClientId,
      'redirect_uri': _naverRedirectUri,
      'state': state,
    });

    // OS 웹 인증 시트. 중계 페이지가 qradar://auth/naver?code&state 로 bounce.
    // 사용자가 취소하면 PlatformException(CANCELED) 이 던져진다.
    final callback = await FlutterWebAuth2.authenticate(
      url: authorizeUrl.toString(),
      callbackUrlScheme: 'qradar',
    );
    final params = Uri.parse(callback).queryParameters;

    if (params['error'] != null) {
      throw Exception('네이버 로그인이 취소되었거나 실패했습니다.');
    }
    // CSRF: 돌아온 state 가 보낸 state 와 같아야 한다.
    if (params['state'] != state) {
      throw Exception('네이버 로그인 state 가 일치하지 않습니다.');
    }
    final code = params['code'];
    if (code == null || code.isEmpty) {
      throw Exception('네이버 인증 코드를 가져올 수 없습니다.');
    }

    // Cloud Function 에서 code → token 교환(client_secret 서버 전용) → custom token
    final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
        .httpsCallable('verifyNaverToken');
    final response = await callable.call<Map<String, dynamic>>({
      'code': code,
      'state': state,
      'redirect_uri': _naverRedirectUri,
    });
    final customToken = response.data['customToken'] as String;
    // CF 가 nid/me 에서 가져온 프로필 (구버전 CF 응답이면 부재 → 빈 값).
    final profile = response.data['profile'];
    final profileMap = profile is Map ? profile : const <dynamic, dynamic>{};
    String? str(String key) {
      final v = profileMap[key];
      return v is String && v.isNotEmpty ? v : null;
    }

    // Firebase Auth 세션 생성
    final credential = await _firebaseAuth.signInWithCustomToken(customToken);
    final user = credential.user!;

    // 커스텀 토큰 세션에는 프로필이 없으므로 CF 응답 프로필을 우선 사용한다.
    return UserModel(
      uid: user.uid,
      email: str('email') ?? user.email,
      displayName: str('name') ?? user.displayName,
      photoUrl: str('imageUrl') ?? user.photoURL,
      provider: 'naver',
    );
  }

  // ── Email ─────────────────────────────────────────────────────────────────

  @override
  Future<UserModel> signInWithEmail({required String email, required String password}) async {
    final result = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = result.user!;
    return UserModel(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      provider: 'email',
    );
  }

  @override
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    final result = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = result.user!;
    return UserModel(
      uid: user.uid,
      email: user.email,
      displayName: name,
      photoUrl: user.photoURL,
      phone: phone,
      provider: 'email',
    );
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    try { await kakao.UserApi.instance.logout(); } catch (_) {}
  }

  // ── Auth State ────────────────────────────────────────────────────────────

  @override
  Stream<UserModel?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map(_toModel);
  }
}

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:qradar/data/models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> signInWithGoogle();
  Future<UserModel> signInWithKakao();
  Future<UserModel> signInWithNaver();
  Future<UserModel> signInWithEmail({required String email, required String password});
  Future<UserModel> signUpWithEmail({required String email, required String password});
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
    // KakaoTalk 설치 여부에 따라 로그인 방식 분기
    if (await kakao.isKakaoTalkInstalled()) {
      await kakao.UserApi.instance.loginWithKakaoTalk();
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

  @override
  Future<UserModel> signInWithNaver() async {
    // Naver SDK 의 잔존 OAuth state 정리 (state mismatch 회피).
    // 이미 로그아웃 상태면 no-op.
    try {
      await FlutterNaverLogin.logOut();
    } catch (_) {}

    final result = await FlutterNaverLogin.logIn();
    if (result.status != NaverLoginStatus.loggedIn) {
      throw Exception('네이버 로그인이 취소되었습니다.');
    }

    final account = result.account;
    if (account == null) throw Exception('네이버 계정 정보를 가져올 수 없습니다.');

    // flutter_naver_login plugin Android 측은 logIn() 결과의 accessToken 자리에
    // 항상 null 을 넘긴다. token 은 별도 getCurrentAccessToken() 으로 가져옴.
    final naverToken = await FlutterNaverLogin.getCurrentAccessToken();
    if (naverToken.accessToken.isEmpty) {
      throw Exception('Naver access token을 가져올 수 없습니다.');
    }

    // Cloud Function 으로 custom token 발급
    final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
        .httpsCallable('verifyNaverToken');
    final response = await callable.call<Map<String, dynamic>>({
      'accessToken': naverToken.accessToken,
    });
    final customToken = response.data['customToken'] as String;

    // Firebase Auth 세션 생성
    final credential = await _firebaseAuth.signInWithCustomToken(customToken);
    final user = credential.user!;

    return UserModel(
      uid: user.uid,
      email: account.email,
      displayName: account.name,
      photoUrl: account.profileImage,
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
  Future<UserModel> signUpWithEmail({required String email, required String password}) async {
    final result = await _firebaseAuth.createUserWithEmailAndPassword(
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

  // ── Sign Out ──────────────────────────────────────────────────────────────

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    try { await kakao.UserApi.instance.logout(); } catch (_) {}
    try { await FlutterNaverLogin.logOut(); } catch (_) {}
  }

  // ── Auth State ────────────────────────────────────────────────────────────

  @override
  Stream<UserModel?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map(_toModel);
  }
}

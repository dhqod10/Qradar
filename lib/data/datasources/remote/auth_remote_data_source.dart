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
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _firebaseAuth;

  AuthRemoteDataSourceImpl({required FirebaseAuth firebaseAuth})
      : _firebaseAuth = firebaseAuth;

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

    final kakaoUser = await kakao.UserApi.instance.me();

    return UserModel(
      uid: 'kakao_${kakaoUser.id}',
      email: kakaoUser.kakaoAccount?.email,
      displayName: kakaoUser.kakaoAccount?.profile?.nickname,
      photoUrl: kakaoUser.kakaoAccount?.profile?.profileImageUrl,
      provider: 'kakao',
    );
  }

  // ── Naver ─────────────────────────────────────────────────────────────────

  @override
  Future<UserModel> signInWithNaver() async {
    final result = await FlutterNaverLogin.logIn();

    if (result.status != NaverLoginStatus.loggedIn) {
      throw Exception('네이버 로그인이 취소되었습니다.');
    }

    final account = result.account;
    if (account == null) throw Exception('네이버 계정 정보를 가져올 수 없습니다.');

    return UserModel(
      uid: 'naver_${account.id}',
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
    return _firebaseAuth.authStateChanges().map((user) {
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
    });
  }
}

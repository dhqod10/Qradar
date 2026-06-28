import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/common/q_logo.dart';
import 'package:qradar/presentation/common/widgets/error_dialog.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/common/role_router.dart';
import 'package:qradar/presentation/customer/auth/email_login_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with WidgetsBindingObserver {
  bool _externalAuthInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 외부 SNS 앱(카톡 등) 인증 중 사용자가 강제 종료 후 우리 앱으로 복귀하는
    // 경우 SDK 응답이 누락되어 무한 로딩이 발생. resumed 후 grace period 안에
    // 정상 응답이 오지 않으면 silent cancel 처리한다.
    //
    // grace period = 30초 — Cloud Function cold start + 외부 API verify 시간
    // 까지 충분히 흡수. 정상 응답 도착 시 ref.listen 에서 _externalAuthInProgress
    // 를 false 로 set 하므로 아래 delayed cancel 은 무력화된다 (state 가 이미
    // not-loading).
    if (state == AppLifecycleState.resumed && _externalAuthInProgress) {
      Future<void>.delayed(const Duration(seconds: 30), () {
        if (!mounted) return;
        if (!_externalAuthInProgress) return; // 정상 응답 도착 시 skip
        _externalAuthInProgress = false;
        ref.read(authProvider.notifier).cancelSignIn();
      });
    }
  }

  void _signInWithKakao() {
    _externalAuthInProgress = true;
    ref.read(authProvider.notifier).signInWithKakao();
  }

  void _signInWithNaver() {
    _externalAuthInProgress = true;
    ref.read(authProvider.notifier).signInWithNaver();
  }

  void _signInWithGoogle() {
    _externalAuthInProgress = true;
    ref.read(authProvider.notifier).signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (prev, next) {
      // 외부 인증 흐름이 끝나는 모든 케이스 (성공/실패/취소) 에서 lifecycle
      // 기반 silent cancel 무력화. AsyncLoading → 다른 상태 전이가 바로 그 신호.
      final wasLoading = prev?.isLoading ?? false;
      if (wasLoading && !next.isLoading) {
        _externalAuthInProgress = false;
      }
      next.whenOrNull(
        data: (user) {
          if (user != null) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const RoleRouter()),
              (route) => false,
            );
          }
        },
        error: (e, _) {
          // EmailLoginPage 등 다른 라우트가 위에 push 된 상태면 그 라우트가
          // 자체적으로 친화 메시지를 띄우므로 여기서 중복 다이얼로그 차단.
          final isTop = ModalRoute.of(context)?.isCurrent ?? true;
          if (!isTop) return;
          if (e is Exception) {
            final msg = e.toString().toLowerCase();
            if (msg.contains('canceled') ||
                msg.contains('cancelled') ||
                msg.contains('cancel') ||
                msg.contains('user canceled')) {
              return;
            }
          }
          showErrorDialog(context, '로그인이 실패하였습니다.');
        },
      );
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Center(
                      child: IntrinsicWidth(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 2),
                            const Text(
                              'QUALITY GRADE RADAR',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                                letterSpacing: 2.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildSocialLogin(ref),
                  _buildBottom(context, ref),
                ],
              ),
              // 로딩 오버레이
              if (authState.isLoading)
                const ColoredBox(
                  color: Color(0x55000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Center(child: QradarLogo(size: 110));
  }

  Widget _buildSocialLogin(WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Text(
            'SNS 계정으로 로그인',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          _SocialButton(
            onTap: _signInWithKakao,
            backgroundColor: AppColors.kakao,
            textColor: const Color(0xFF191919),
            icon: _KakaoIcon(),
            label: '카카오로 계속하기',
          ),
          const SizedBox(height: 12),
          _SocialButton(
            onTap: _signInWithNaver,
            backgroundColor: AppColors.naver,
            textColor: Colors.white,
            icon: _NaverIcon(),
            label: '네이버로 계속하기',
          ),
          const SizedBox(height: 12),
          _SocialButton(
            onTap: _signInWithGoogle,
            backgroundColor: AppColors.surfaceElevated,
            textColor: AppColors.textDefault,
            border: Border.all(color: const Color(0xFF334155)),
            icon: _GoogleIcon(),
            label: 'Google로 계속하기',
          ),
        ],
      ),
    );
  }

  Widget _buildBottom(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              const Expanded(child: Divider(color: AppColors.surfaceElevated)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '또는',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
              const Expanded(child: Divider(color: AppColors.surfaceElevated)),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const EmailLoginPage())),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primaryBright,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '이메일로 로그인',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '아직 계정이 없으신가요?  ',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EmailLoginPage()),
                ),
                child: const Text(
                  '회원가입',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color textColor;
  final Widget icon;
  final String label;
  final BoxBorder? border;

  const _SocialButton({
    required this.onTap,
    required this.backgroundColor,
    required this.textColor,
    required this.icon,
    required this.label,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: border,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 20, height: 20, child: icon),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KakaoIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Text(
      'K',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF191919),
      ),
    );
  }
}

class _NaverIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Text(
      'N',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GoogleLogoPainter());
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path1 = Path()
      ..moveTo(size.width * 0.94, size.height * 0.51)
      ..lineTo(size.width * 0.94, size.height * 0.51)
      ..cubicTo(
        size.width * 0.94,
        size.height * 0.48,
        size.width * 0.94,
        size.height * 0.46,
        size.width * 0.93,
        size.height * 0.44,
      )
      ..lineTo(size.width * 0.50, size.height * 0.44)
      ..lineTo(size.width * 0.50, size.height * 0.62)
      ..lineTo(size.width * 0.75, size.height * 0.62)
      ..cubicTo(
        size.width * 0.74,
        size.height * 0.68,
        size.width * 0.69,
        size.height * 0.73,
        size.width * 0.62,
        size.height * 0.75,
      )
      ..lineTo(size.width * 0.62, size.height * 0.75)
      ..lineTo(size.width * 0.77, size.height * 0.87)
      ..lineTo(size.width * 0.77, size.height * 0.87)
      ..cubicTo(
        size.width * 0.86,
        size.height * 0.79,
        size.width * 0.94,
        size.height * 0.66,
        size.width * 0.94,
        size.height * 0.51,
      );

    canvas.drawPath(path1, Paint()..color = const Color(0xFF4285F4));

    final path2 = Path()
      ..moveTo(size.width * 0.50, size.height * 0.96)
      ..cubicTo(
        size.width * 0.62,
        size.height * 0.96,
        size.width * 0.73,
        size.height * 0.92,
        size.width * 0.77,
        size.height * 0.87,
      )
      ..lineTo(size.width * 0.62, size.height * 0.75)
      ..cubicTo(
        size.width * 0.59,
        size.height * 0.77,
        size.width * 0.55,
        size.height * 0.78,
        size.width * 0.50,
        size.height * 0.78,
      )
      ..cubicTo(
        size.width * 0.38,
        size.height * 0.78,
        size.width * 0.28,
        size.height * 0.70,
        size.width * 0.24,
        size.height * 0.59,
      )
      ..lineTo(size.width * 0.09, size.height * 0.59)
      ..lineTo(size.width * 0.09, size.height * 0.71)
      ..cubicTo(
        size.width * 0.17,
        size.height * 0.85,
        size.width * 0.32,
        size.height * 0.96,
        size.width * 0.50,
        size.height * 0.96,
      );

    canvas.drawPath(path2, Paint()..color = const Color(0xFF34A853));

    final path3 = Path()
      ..moveTo(size.width * 0.24, size.height * 0.59)
      ..cubicTo(
        size.width * 0.23,
        size.height * 0.56,
        size.width * 0.22,
        size.height * 0.53,
        size.width * 0.22,
        size.height * 0.50,
      )
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.47,
        size.width * 0.23,
        size.height * 0.44,
        size.width * 0.24,
        size.height * 0.41,
      )
      ..lineTo(size.width * 0.09, size.height * 0.29)
      ..lineTo(size.width * 0.09, size.height * 0.29)
      ..cubicTo(
        size.width * 0.06,
        size.height * 0.36,
        size.width * 0.04,
        size.height * 0.43,
        size.width * 0.04,
        size.height * 0.50,
      )
      ..cubicTo(
        size.width * 0.04,
        size.height * 0.57,
        size.width * 0.06,
        size.height * 0.64,
        size.width * 0.09,
        size.height * 0.71,
      )
      ..lineTo(size.width * 0.24, size.height * 0.59);

    canvas.drawPath(path3, Paint()..color = const Color(0xFFFBBC05));

    final path4 = Path()
      ..moveTo(size.width * 0.50, size.height * 0.22)
      ..cubicTo(
        size.width * 0.57,
        size.height * 0.22,
        size.width * 0.63,
        size.height * 0.25,
        size.width * 0.68,
        size.height * 0.29,
      )
      ..lineTo(size.width * 0.81, size.height * 0.16)
      ..lineTo(size.width * 0.81, size.height * 0.16)
      ..cubicTo(
        size.width * 0.73,
        size.height * 0.09,
        size.width * 0.62,
        size.height * 0.04,
        size.width * 0.50,
        size.height * 0.04,
      )
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.04,
        size.width * 0.17,
        size.height * 0.14,
        size.width * 0.09,
        size.height * 0.29,
      )
      ..lineTo(size.width * 0.24, size.height * 0.41)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.30,
        size.width * 0.38,
        size.height * 0.22,
        size.width * 0.50,
        size.height * 0.22,
      );

    canvas.drawPath(path4, Paint()..color = const Color(0xFFEA4335));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

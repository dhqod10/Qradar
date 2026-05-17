import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/firebase_options.dart';
import 'package:qradar/presentation/common/q_logo.dart'; // QLogo, QradarLogo
import 'package:qradar/presentation/common/role_router.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/auth/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await GoogleSignIn.instance.initialize();
  KakaoSdk.init(nativeAppKey: 'f55c641ec30d25ae3c5f426305cc7a9a');
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: AppColors.brightness,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: AppColors.brightness,
          primary: AppColors.primary,
          surface: AppColors.surface,
          onPrimary: AppColors.onPrimary,
        ),
      ),
      // 글로벌: 외부 영역 탭 시 키보드 자동 dismiss.
      // - HitTestBehavior 미지정 (default = deferToChild) → 자식 hit 영역 회피.
      // - 추가 안전장치: 현재 focus 가 EditableText (TextField 내부 위젯) 이면
      //   글로벌 onTap 이 호출되더라도 unfocus 하지 않는다. TextField 탭 시
      //   focus 가 잡힌 직후 동시에 onTap 호출되어 키보드가 다시 dismiss 되는
      //   회귀 방지.
      builder: (context, child) => GestureDetector(
        onTap: () {
          final focus = FocusManager.instance.primaryFocus;
          if (focus == null || !focus.hasFocus) return;
          if (focus.context?.widget is EditableText) return;
          focus.unfocus();
        },
        child: child,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _radarController;

  @override
  void initState() {
    super.initState();

    // 페이드인 (1초)
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // 레이더 파동: 2.1s 주기로 반복 (3 * 0.7s)
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    )..repeat();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _fadeController.forward();
    });

    Future.delayed(const Duration(milliseconds: 2500), () async {
      if (!mounted) return;
      final authState = await ref.read(authProvider.future);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => authState != null ? const RoleRouter() : const LoginPage(),
        ),
      );
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Center(
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: _fadeController,
              curve: Curves.easeIn,
            ),
            // QradarLogo + 레이더 파동 (Q 위에 Stack으로 오버레이)
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 레이더 파동 — Q 중심(55,55) 기준, -10 offset으로 맞춤
                Positioned(
                  left: -10,
                  top: -10,
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _radarController,
                      builder: (_, _) => CustomPaint(
                        size: const Size(130, 130),
                        painter: _RadarPainter(progress: _radarController.value),
                      ),
                    ),
                  ),
                ),
                // QradarLogo (로그인 페이지와 동일한 위젯)
                const QradarLogo(size: 110),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double progress;

  const _RadarPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Q 링 외곽 반지름 기준 (QLogo size=110 → r=55, outer=55*0.75≈41)
    const rStart = 41.0;
    const rEnd = 72.0;

    // 3개 파동, 1/3씩 offset
    for (int i = 0; i < 3; i++) {
      final state = (progress + i / 3) % 1.0;
      final radius = rStart + (rEnd - rStart) * state;
      final opacity = 0.6 * (1.0 - state);

      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..color = AppColors.primaryBright.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.progress != progress;
}

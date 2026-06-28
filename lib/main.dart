import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/remote_notification_message.dart';
import 'package:qradar/firebase_options.dart';
import 'package:qradar/presentation/common/notification/notification_navigator.dart';
import 'package:qradar/presentation/common/q_logo.dart'; // QLogo, QradarLogo
import 'package:qradar/presentation/common/role_router.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/auth/login_page.dart';

/// 글로벌 NavigatorKey — NotificationNavigator 등에서 앱 전역 탐색에 사용.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// FCM 백그라운드 핸들러 (top-level 함수 필수 — isolate 제약).
///
/// data-only 메시지이므로 이 핸들러에서 직접 로컬 알림을 표시한다.
/// FlutterLocalNotificationsPlugin 은 별도 인스턴스로 생성 (isolate 분리).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background isolate 에서 Firebase 재초기화 필요
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final data = message.data;
  final title = data['title'] as String? ?? '알림';
  final body = data['body'] as String? ?? '';
  final orderId = data['orderId'] as String? ?? '';
  // 탭 시 navigator 가 사용할 정보 전체를 JSON 으로 payload 에 박는다.
  final payloadJson = jsonEncode(Map<String, dynamic>.from(data));

  // 백그라운드 로컬 알림 표시
  final plugin = FlutterLocalNotificationsPlugin();
  const androidChannel = AndroidNotificationChannel(
    'qradar_orders',
    'Qradar 주문 알림',
    description: '새 주문 및 환불 요청 알림',
    importance: Importance.high,
  );
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(androidChannel);

  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );
  await plugin.initialize(initSettings);

  await plugin.show(
    orderId.hashCode,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'qradar_orders',
        'Qradar 주문 알림',
        channelDescription: '새 주문 및 환불 요청 알림',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: payloadJson,
  );
}

/// 포그라운드 로컬 알림 플러그인 인스턴스 (main isolate 전용).
final FlutterLocalNotificationsPlugin _foregroundLocalNotifications =
    FlutterLocalNotificationsPlugin();

/// 포그라운드 로컬 알림 초기화 (앱 시작 시 1회).
Future<void> _initForegroundLocalNotifications() async {
  const androidChannel = AndroidNotificationChannel(
    'qradar_orders',
    'Qradar 주문 알림',
    description: '새 주문 및 환불 요청 알림',
    importance: Importance.high,
  );
  await _foregroundLocalNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(androidChannel);

  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );
  await _foregroundLocalNotifications.initialize(
    initSettings,
    // 로컬 알림 탭 콜백 — payload JSON 파싱 후 OrderDetailPage 진입.
    onDidReceiveNotificationResponse: _handleLocalNotificationTap,
  );

  // 종료 상태에서 알림 탭으로 앱이 시작된 경우 처리.
  final launchDetails =
      await _foregroundLocalNotifications.getNotificationAppLaunchDetails();
  if (launchDetails?.didNotificationLaunchApp ?? false) {
    final payload = launchDetails?.notificationResponse?.payload;
    if (payload != null && payload.isNotEmpty) {
      // 첫 frame 이후 navigator 준비 끝난 뒤 실행
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateFromPayload(payload, source: 'appLaunch');
      });
    }
  }
}

/// 로컬 알림 탭 시 호출되는 콜백 (포그라운드 + 백그라운드 양쪽).
void _handleLocalNotificationTap(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null || payload.isEmpty) {
    // ignore: avoid_print
    print('[NotifTap] localNotification tap with empty payload');
    return;
  }
  _navigateFromPayload(payload, source: 'localTap');
}

/// JSON payload 를 파싱해 NotificationNavigator 로 위임.
void _navigateFromPayload(String payload, {required String source}) {
  Map<String, dynamic> data;
  try {
    data = Map<String, dynamic>.from(jsonDecode(payload) as Map);
  } catch (e) {
    // ignore: avoid_print
    print('[NotifTap] payload parse failed source=$source error=$e payload=$payload');
    return;
  }
  final remoteMsg = RemoteNotificationMessage.fromData(data);
  final currentState = navigatorKey.currentState;
  // ignore: avoid_print
  print(
    '[NotifTap] _navigateFromPayload source=$source '
    'type=${remoteMsg.type} orderId=${remoteMsg.orderId} '
    'navigatorState=${currentState != null ? "ready" : "null"}',
  );
  NotificationNavigator.navigate(
    navigatorKey: navigatorKey,
    message: remoteMsg,
  );
}

/// 포그라운드 메시지 핸들러 — data-only 메시지를 받아 로컬 알림 표시.
void _registerForegroundMessageHandler() {
  FirebaseMessaging.onMessage.listen((message) async {
    final data = message.data;
    final title = data['title'] as String? ?? '알림';
    final body = data['body'] as String? ?? '';
    final orderId = data['orderId'] as String? ?? '';
    // 탭 시 navigator 가 사용할 정보 전체를 JSON 으로 payload 에 박는다.
    final payloadJson = jsonEncode(Map<String, dynamic>.from(data));

    await _foregroundLocalNotifications.show(
      orderId.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'qradar_orders',
          'Qradar 주문 알림',
          channelDescription: '새 주문 및 환불 요청 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payloadJson,
    );
  });
}

/// 알림 탭 → 화면 이동 핸들러 등록.
///
/// 1. 백그라운드 → 알림 탭: `onMessageOpenedApp`
/// 2. 종료 상태 → 알림 탭으로 앱 시작: `getInitialMessage`
/// 3. 포그라운드 로컬 알림 탭: `_foregroundLocalNotifications.initialize` 의 onTap 콜백
void _registerNotificationTapHandlers() {
  // (1) 백그라운드 → 탭
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    // ignore: avoid_print
    print('[NotifTap] onMessageOpenedApp data=${message.data}');
    final remoteMsg = RemoteNotificationMessage.fromData(
      Map<String, dynamic>.from(message.data),
    );
    _navigateFromNotification(remoteMsg, source: 'onMessageOpenedApp');
  });

  // (2) 종료 상태 → 앱 시작 직후 1회 확인
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message == null) {
      // ignore: avoid_print
      print('[NotifTap] getInitialMessage = null');
      return;
    }
    // ignore: avoid_print
    print('[NotifTap] getInitialMessage data=${message.data}');
    final remoteMsg = RemoteNotificationMessage.fromData(
      Map<String, dynamic>.from(message.data),
    );
    // 첫 frame 이후 navigator 준비 끝난 뒤 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateFromNotification(remoteMsg, source: 'getInitialMessage');
    });
  });
}

void _navigateFromNotification(
  RemoteNotificationMessage message, {
  required String source,
}) {
  final currentState = navigatorKey.currentState;
  // ignore: avoid_print
  print(
    '[NotifTap] _navigateFromNotification source=$source '
    'type=${message.type} orderId=${message.orderId} '
    'navigatorState=${currentState != null ? "ready" : "null"}',
  );
  NotificationNavigator.navigate(
    navigatorKey: navigatorKey,
    message: message,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // FCM 백그라운드 핸들러 등록 (Firebase 초기화 직후)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // FCM 포그라운드 핸들러 등록 — 로컬 알림 표시
  await _initForegroundLocalNotifications();
  _registerForegroundMessageHandler();

  // FCM 알림 탭 핸들러 등록 — 백그라운드/종료 상태에서 알림 탭 시 OrderDetailPage 진입
  _registerNotificationTapHandlers();

  await initializeDateFormatting('ko_KR', null);
  await GoogleSignIn.instance.initialize();
  KakaoSdk.init(nativeAppKey: 'f55c641ec30d25ae3c5f426305cc7a9a');
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
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

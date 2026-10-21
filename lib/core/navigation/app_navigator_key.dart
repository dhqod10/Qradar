import 'package:flutter/material.dart';

/// 앱 전역 Navigator 키.
///
/// `MaterialApp.navigatorKey` 에 주입되며, 알림 탭 등 BuildContext 없이
/// 화면 전환이 필요한 경로에서 사용한다.
///
/// main.dart 가 아닌 별도 파일에 두는 이유: RoleRouter 등 하위 위젯이
/// 참조할 때 main.dart 와의 순환 import 를 피하기 위함.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

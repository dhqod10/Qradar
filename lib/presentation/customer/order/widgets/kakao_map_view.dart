import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:qradar/core/config/map_config.dart';
import 'package:qradar/core/constants/grade_thresholds.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/user_location.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// WebView 로 Kakao Maps JS SDK 를 호스팅하는 지도 위젯.
///
/// - HTML 은 `assets/map/kakao_map.html` 로부터 로드
/// - JS ↔ Dart 브릿지는 `KakaoMapBridge` 이름의 JavaScriptChannel 사용
/// - 마커 탭/지도 빈 영역 탭/SDK 에러/ready 이벤트를 콜백으로 노출
class KakaoMapView extends StatefulWidget {
  final UserLocation? initialLocation;
  final VoidCallback? onReady;
  final ValueChanged<String>? onMarkerTap;
  final VoidCallback? onMapTap;
  final VoidCallback? onError;

  const KakaoMapView({
    super.key,
    this.initialLocation,
    this.onReady,
    this.onMarkerTap,
    this.onMapTap,
    this.onError,
  });

  @override
  State<KakaoMapView> createState() => KakaoMapViewState();
}

class KakaoMapViewState extends State<KakaoMapView> {
  WebViewController? _controller;
  bool _mapReady = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (MapConfig.kakaoJsKey.isEmpty) {
      _flagError();
      return;
    }

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.surface)
      ..addJavaScriptChannel(
        'KakaoMapBridge',
        onMessageReceived: _onBridgeMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (_) => _flagError(),
        ),
      );

    _controller = controller;
    await _loadHtml();
  }

  Future<void> _loadHtml() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final raw = await rootBundle.loadString('assets/map/kakao_map.html');
      final lat = widget.initialLocation?.latitude ??
          GradeThresholds.defaultLatitude;
      final lng = widget.initialLocation?.longitude ??
          GradeThresholds.defaultLongitude;
      final html = raw
          .replaceAll('__KAKAO_JS_KEY__', MapConfig.kakaoJsKey)
          .replaceAll('__INIT_LAT__', lat.toString())
          .replaceAll('__INIT_LNG__', lng.toString())
          .replaceAll('__INIT_LEVEL__', MapConfig.defaultZoomLevel.toString());
      await controller.loadHtmlString(
        html,
        baseUrl: MapConfig.webViewBaseUrl,
      );
    } catch (_) {
      _flagError();
    }
  }

  void _onBridgeMessage(JavaScriptMessage message) {
    if (!mounted) return;
    Map<String, dynamic>? data;
    try {
      data = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final type = data['type'];
    if (type is! String) return;
    switch (type) {
      case 'ready':
        _mapReady = true;
        widget.onReady?.call();
        break;
      case 'markerTap':
        final id = data['id'];
        if (id is String) widget.onMarkerTap?.call(id);
        break;
      case 'mapTap':
        widget.onMapTap?.call();
        break;
      case 'sdkError':
        _flagError();
        break;
    }
  }

  void _flagError() {
    if (!mounted) return;
    if (_hasError) return;
    setState(() => _hasError = true);
    widget.onError?.call();
  }

  Future<void> setStores(Map<String, dynamic> payload) async {
    final controller = _controller;
    if (controller == null || !_mapReady) return;
    final encoded = jsonEncode(payload);
    await controller.runJavaScript('window.flutterMap.setStores($encoded);');
  }

  Future<void> moveTo(double lat, double lng) async {
    final controller = _controller;
    if (controller == null || !_mapReady) return;
    await controller.runJavaScript('window.flutterMap.moveTo($lat, $lng);');
  }

  Future<void> setSelected(String? id) async {
    final controller = _controller;
    if (controller == null || !_mapReady) return;
    final arg = id == null ? 'null' : jsonEncode(id);
    await controller.runJavaScript('window.flutterMap.setSelected($arg);');
  }

  Future<void> reload() async {
    setState(() {
      _mapReady = false;
      _hasError = false;
    });
    await _init();
  }

  bool get isReady => _mapReady;

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _MapErrorState(onRetry: reload);
    }
    final controller = _controller;
    if (controller == null) {
      return const ColoredBox(color: AppColors.surface);
    }
    return ColoredBox(
      color: AppColors.surface,
      child: WebViewWidget(controller: controller),
    );
  }
}

class _MapErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _MapErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.map_outlined, size: 40, color: AppColors.error),
          const SizedBox(height: 12),
          const Text(
            '지도를 표시할 수 없어요',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '네트워크 연결을 확인해주세요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '다시 시도',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// Toss 영수증 URL 을 앱 내 WebView 로 표시하는 풀스크린 위젯.
///
/// 사용 예:
/// ```dart
/// Navigator.of(context).push(MaterialPageRoute(
///   builder: (_) => ReceiptWebView(receiptUrl: order.receiptUrl!),
/// ));
/// ```
class ReceiptWebView extends StatefulWidget {
  const ReceiptWebView({super.key, required this.receiptUrl});

  final String receiptUrl;

  @override
  State<ReceiptWebView> createState() => _ReceiptWebViewState();
}

class _ReceiptWebViewState extends State<ReceiptWebView> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onPageStarted: (_) {
          if (mounted) setState(() => _hasError = false);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _progress = 100);
        },
        onWebResourceError: (_) {
          if (mounted) setState(() => _hasError = true);
        },
      ))
      ..loadRequest(Uri.parse(widget.receiptUrl));
  }

  void _reload() {
    setState(() {
      _hasError = false;
      _progress = 0;
    });
    _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          '영수증',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textHeading,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textHeading),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_hasError)
            _ErrorView(onRetry: _reload)
          else
            WebViewWidget(controller: _controller),
          if (!_hasError && _progress < 100)
            LinearProgressIndicator(
              value: _progress / 100,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
        ],
      ),
    );
  }
}

// ── Error View ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: AppColors.textBody,
            ),
            const SizedBox(height: 16),
            const Text(
              '영수증을 불러오지 못했습니다.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textHeading,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              '네트워크 연결을 확인한 후 다시 시도해 주세요.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textBody,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
                minimumSize: const Size(120, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

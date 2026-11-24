import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// 첨부 확대 뷰어 (단순). 로컬 파일·네트워크 모두 [ImageProvider] 로 받는다.
class SupportInquiryImageViewer extends StatefulWidget {
  const SupportInquiryImageViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  final List<ImageProvider> images;
  final int initialIndex;

  static Future<void> open(
    BuildContext context, {
    required List<ImageProvider> images,
    int initialIndex = 0,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => SupportInquiryImageViewer(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  State<SupportInquiryImageViewer> createState() =>
      _SupportInquiryImageViewerState();
}

class _SupportInquiryImageViewerState extends State<SupportInquiryImageViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.images.length;
    return Scaffold(
      backgroundColor: AppColors.primaryDeep,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: total,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image(
                  image: widget.images[i],
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.onPrimary,
                          ),
                        ),
                  errorBuilder: (_, _, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        size: 40,
                        color: AppColors.onPrimary.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '불러오지 못했어요',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.onPrimary.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: SizedBox(
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: '닫기',
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 24,
                        color: AppColors.onPrimary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  if (total > 1)
                    Text(
                      '${_index + 1} / $total',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.onPrimary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

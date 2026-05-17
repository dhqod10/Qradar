import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// 이미지 선택 → 로컬 미리보기 → 업로드 progress → 완료 위젯.
///
/// 브랜드 로고 / 마스터 메뉴 이미지 공통 사용.
/// 5MB 초과 시 에러 메시지 표시 (S7).
///
/// 업로드는 폼 제출 시점에 호출부가 직접 수행한다.
/// 이 위젯은 로컬 파일 선택 + 미리보기 + 오류 표시만 담당.
class ImageUploadField extends StatefulWidget {
  /// 이미 저장된 네트워크 이미지 URL (수정 모드 초기값).
  final String? initialUrl;

  /// 위젯 높이. 브랜드 로고: 160, 메뉴 이미지: 180.
  final double height;

  /// placeholder 아이콘. 브랜드 로고: storefront, 메뉴: local_cafe.
  final IconData placeholderIcon;

  /// 로컬 파일이 선택됐을 때 호출.
  final ValueChanged<File?> onFileChanged;

  /// 업로드 진행률 (0.0 ~ 1.0). null 이면 progress 미표시.
  final double? uploadProgress;

  /// 외부에서 주입하는 에러 메시지.
  final String? errorMessage;

  const ImageUploadField({
    super.key,
    this.initialUrl,
    this.height = 180,
    this.placeholderIcon = Icons.local_cafe_outlined,
    required this.onFileChanged,
    this.uploadProgress,
    this.errorMessage,
  });

  @override
  State<ImageUploadField> createState() => _ImageUploadFieldState();
}

class _ImageUploadFieldState extends State<ImageUploadField> {
  final _picker = ImagePicker();
  File? _localFile;
  String? _validationError;

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final file = File(picked.path);
    // 5MB 검증 (S7)
    const maxBytes = 5 * 1024 * 1024;
    if (file.lengthSync() > maxBytes) {
      setState(() {
        _validationError = '이미지 용량이 5MB를 초과했습니다.';
        _localFile = null;
      });
      widget.onFileChanged(null);
      return;
    }

    setState(() {
      _localFile = file;
      _validationError = null;
    });
    widget.onFileChanged(file);
  }

  void _clearImage() {
    setState(() {
      _localFile = null;
      _validationError = null;
    });
    widget.onFileChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final errorText = _validationError ?? widget.errorMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: widget.uploadProgress != null ? null : _pickImage,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: double.infinity,
              height: widget.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImageContent(),
                  if (widget.uploadProgress != null) _buildUploadOverlay(),
                  if ((_localFile != null || widget.initialUrl != null) &&
                      widget.uploadProgress == null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _buildRemoveButton(),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImageContent() {
    if (_localFile != null) {
      return Image.file(_localFile!, fit: BoxFit.cover);
    }
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      return Image.network(widget.initialUrl!, fit: BoxFit.cover);
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.placeholderIcon,
            size: 36,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 8),
          const Text(
            '탭하여 이미지 선택',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          const Text(
            'JPG / PNG, 최대 5MB',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadOverlay() {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: AppColors.primary.withValues(alpha: 0.4),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: LinearProgressIndicator(
            value: widget.uploadProgress,
            minHeight: 4,
            backgroundColor: AppColors.surface,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.primaryBright),
          ),
        ),
      ],
    );
  }

  Widget _buildRemoveButton() {
    return GestureDetector(
      onTap: _clearImage,
      child: Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: AppColors.surfaceElevated,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.cancel_rounded,
          size: 22,
          color: AppColors.error,
        ),
      ),
    );
  }
}

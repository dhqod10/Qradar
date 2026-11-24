import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/customer/support/widgets/support_inquiry_image_viewer.dart';

/// 다중 첨부 picker (최대 [maxCount]장, 장당 5MB). 사진 보관함 + 카메라.
///
/// 파일 상태는 부모(컨트롤러)가 갖는다 — 이 위젯은 선택·표시만 한다.
/// 리사이즈는 picker 파라미터(`maxWidth 1600 / imageQuality 85`, `store_form_page` 선례)로 처리한다.
/// image_picker 는 `store_form_page` / `ImageUploadField` 선례를 따라 presentation 에서 직접 쓴다.
class SupportInquiryAttachmentPicker extends StatelessWidget {
  const SupportInquiryAttachmentPicker({
    super.key,
    required this.files,
    required this.onAdd,
    required this.onRemove,
    this.busy = false,
    this.uploadedCount = 0,
    this.uploadFailed = false,
  });

  static const int maxCount = 3;
  static const int maxBytes = 5 * 1024 * 1024;

  final List<File> files;
  final ValueChanged<List<File>> onAdd;
  final ValueChanged<int> onRemove;

  /// 제출/업로드 중 — 추가·삭제 비활성.
  final bool busy;

  /// 업로드 완료 장수 (앞에서부터). busy 일 때 타일 진행 표시에 쓴다.
  final int uploadedCount;

  /// 직전 제출에서 업로드 실패.
  final bool uploadFailed;

  @override
  Widget build(BuildContext context) {
    final canAdd = files.length < maxCount;
    final tiles = <Widget>[
      for (var i = 0; i < files.length; i++)
        _ImageSlot(
          file: files[i],
          index: i,
          total: files.length,
          busy: busy,
          done: busy && i < uploadedCount,
          uploading: busy && i == uploadedCount,
          failed: uploadFailed,
          onRemove: () => onRemove(i),
          onOpen: () => SupportInquiryImageViewer.open(
            context,
            images: [for (final f in files) FileImage(f)],
            initialIndex: i,
          ),
        ),
      if (canAdd)
        _AddTile(
          count: files.length,
          enabled: !busy,
          onTap: () => _showSourceSheet(context),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < maxCount; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: i < tiles.length
                    ? AspectRatio(aspectRatio: 1, child: tiles[i])
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
        if (uploadFailed) ...[
          const SizedBox(height: 8),
          const Text(
            '이미지 업로드에 실패했어요. 다시 시도해 주세요.',
            style: TextStyle(fontSize: 12, color: AppColors.error),
          ),
        ] else if (!canAdd) ...[
          const SizedBox(height: 8),
          const Text(
            '최대 3장까지 첨부할 수 있어요 (3/3)',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }

  // ── 선택 시트 ──────────────────────────────────────────────────────────────

  Future<void> _showSourceSheet(BuildContext context) async {
    final remaining = maxCount - files.length;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '사진 추가',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHeading,
                  ),
                ),
              ),
            ),
            _SourceRow(
              icon: Icons.photo_library_outlined,
              title: '사진 보관함',
              subtitle: '최대 $remaining장까지 선택할 수 있어요',
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            _SourceRow(
              icon: Icons.photo_camera_outlined,
              title: '카메라로 촬영',
              subtitle: '촬영한 사진을 바로 첨부해요',
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;
    await _pick(context, source, remaining);
  }

  Future<void> _pick(
    BuildContext context,
    ImageSource source,
    int remaining,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    void toast(String m) => messenger.showSnackBar(SnackBar(content: Text(m)));
    try {
      final picker = ImagePicker();
      final List<XFile> picked;
      if (source == ImageSource.gallery && remaining >= 2) {
        picked = await picker.pickMultiImage(
          maxWidth: 1600,
          imageQuality: 85,
          limit: remaining,
        );
      } else {
        // 카메라(1회 1장) 또는 남은 장수 1 (pickMultiImage 의 limit 은 2 이상만 허용).
        final one = await picker.pickImage(
          source: source,
          maxWidth: 1600,
          imageQuality: 85,
        );
        picked = one == null ? const <XFile>[] : [one];
      }
      if (picked.isEmpty) return;

      var overflow = false;
      var tooBig = false;
      final accepted = <File>[];
      for (final x in picked) {
        if (accepted.length >= remaining) {
          overflow = true;
          break;
        }
        final f = File(x.path);
        final len = await f.length();
        if (len > maxBytes) {
          tooBig = true;
          continue;
        }
        accepted.add(f);
      }
      if (accepted.isNotEmpty) onAdd(accepted);
      if (overflow) toast('사진은 최대 3장까지 첨부할 수 있어요');
      if (tooBig) toast('5MB 이하 사진만 첨부할 수 있어요');
    } on PlatformException catch (e) {
      if (!context.mounted) return;
      final code = e.code;
      if (code == 'camera_access_denied' ||
          code == 'camera_access_restricted') {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              '카메라를 사용할 수 없어요',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeading,
              ),
            ),
            content: const Text(
              '카메라 권한이 꺼져 있어요. 기기 설정 > Qradar > 카메라에서 허용하면 바로 촬영할 수 있어요. 지금은 사진 보관함에서 선택해 주세요.',
              style: TextStyle(fontSize: 14, color: AppColors.textBody),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  '확인',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ),
        );
      } else if (code == 'no_available_camera') {
        toast('이 기기에서는 카메라를 사용할 수 없어요. 사진 보관함에서 선택해 주세요.');
      } else if (code == 'photo_access_denied') {
        toast('사진 접근 권한이 필요해요. 기기 설정에서 허용해 주세요.');
      } else {
        toast('사진을 불러오지 못했어요');
      }
    } catch (_) {
      toast('사진을 불러오지 못했어요');
    }
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 56,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(icon, size: 22, color: AppColors.textBody),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textHeading,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
      onTap: onTap,
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.count,
    required this.enabled,
    required this.onTap,
  });

  final int count;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '사진 추가, 현재 $count장, 최대 3장',
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 24,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 4),
                Text(
                  '$count/3',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageSlot extends StatelessWidget {
  const _ImageSlot({
    required this.file,
    required this.index,
    required this.total,
    required this.busy,
    required this.done,
    required this.uploading,
    required this.failed,
    required this.onRemove,
    required this.onOpen,
  });

  final File file;
  final int index;
  final int total;
  final bool busy;
  final bool done;
  final bool uploading;
  final bool failed;
  final VoidCallback onRemove;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '첨부 사진 ${index + 1} / $total, 확대 보기',
      child: GestureDetector(
        onTap: onOpen,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: failed ? AppColors.error : AppColors.border,
                  width: failed ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.file(file, fit: BoxFit.cover),
            ),
            if (uploading)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
              ),
            if (done)
              const Positioned(
                right: 4,
                bottom: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 16,
                    color: AppColors.success,
                  ),
                ),
              ),
            if (failed && !busy)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.refresh_rounded,
                    size: 24,
                    color: AppColors.error,
                  ),
                ),
              ),
            if (!busy)
              Positioned(
                top: 0,
                right: 0,
                child: Semantics(
                  button: true,
                  label: '첨부 사진 ${index + 1} 삭제',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onRemove,
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.75),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: AppColors.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

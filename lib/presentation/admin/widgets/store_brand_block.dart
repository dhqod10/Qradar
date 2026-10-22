import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/store_brand_link.dart';
import 'package:qradar/presentation/admin/providers/admin_store_brand_link_providers.dart';
import 'package:qradar/presentation/brand/providers/brand_info_providers.dart';
import 'package:qradar/presentation/common/providers/qoin_config_providers.dart';

/// 매장 승인 상세의 `소속 브랜드` 블록 (brand_authorization_hardening design §2-e).
///
/// 승인 화면은 가맹 관계의 유일한 실질 통제다 (`brandKey` 는 공개라 Rules 가 증명하지 못한다). 그래서 admin 이 무엇을 승인하는지
/// 숨김 없이 보여준다: 브랜드 **이름**(폴백 금지) · **승인하면 상속되는 적립률** · 미존재/미승인/조회 실패는 서로 다른 경고 plate.
/// 개인 매장에는 그리지 않는다 (호출 쪽에서 분기).
class StoreBrandBlock extends ConsumerWidget {
  const StoreBrandBlock({super.key, required this.link});
  final StoreBrandLink link;

  static const String header = '소속 브랜드';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            header,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          _body(context, ref),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref) {
    switch (link.kind) {
      case StoreBrandLinkKind.personal:
        return const SizedBox.shrink();
      case StoreBrandLinkKind.checking:
        return Semantics(
          liveRegion: true,
          label: '브랜드를 확인하고 있어요',
          excludeSemantics: true,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Skeleton(width: 120, height: 17),
              SizedBox(height: 8),
              _Skeleton(width: 160, height: 14),
            ],
          ),
        );
      case StoreBrandLinkKind.approved:
        return _Approved(link: link);
      case StoreBrandLinkKind.unapproved:
        return _Plate(
          title: '아직 승인되지 않은 브랜드예요',
          semantics: '경고. 아직 승인되지 않은 브랜드예요. 가맹 관계를 확인할 수 없어 승인할 수 없어요',
          lines: [
            '이 매장이 가리키는 브랜드 "${link.brand!.name}" 은 승인 대기/반려 상태예요. 가맹 관계를 확인할 수 없어 승인할 수 없어요.',
            '점주에게 확인하거나 반려해 주세요',
          ],
          brandId: link.brandId,
        );
      case StoreBrandLinkKind.missing:
        return _Plate(
          title: '존재하지 않는 브랜드예요',
          semantics: '경고. 존재하지 않는 브랜드예요. 승인할 수 없어요',
          lines: [
            '이 매장이 가리키는 브랜드를 찾을 수 없어요. 잘못 입력됐거나 지워진 브랜드일 수 있어요.',
            '승인할 수 없으니 점주에게 확인하거나 반려해 주세요',
          ],
          brandId: link.brandId,
        );
      case StoreBrandLinkKind.lookupFailed:
        return _Plate(
          title: '브랜드를 확인하지 못했어요',
          semantics: '경고. 브랜드를 확인하지 못했어요. 다시 시도 버튼이 있어요',
          lines: const ['네트워크나 권한 문제로 브랜드 정보를 읽지 못했어요.', '확인되기 전에는 승인할 수 없어요'],
          retry: () => ref.invalidate(brandByIdProvider(link.brandId!)),
        );
    }
  }
}

class _Approved extends ConsumerWidget {
  const _Approved({required this.link});
  final StoreBrandLink link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = link.brand!;
    final inherited = ref.watch(inheritedRateProvider(link.brandId));
    final rateLine = inherited.when(
      loading: () => const _Skeleton(width: 160, height: 14),
      error: (_, _) => Row(
        children: [
          const Expanded(
            child: Text(
              '적립률을 확인하지 못했어요',
              style: TextStyle(fontSize: 13, color: AppColors.textBody),
            ),
          ),
          // 적립률 읽기 실패는 승인을 막지 않는다 — 다만 비어 있음을 숨기지 않는다.
          TextButton(
            onPressed: () => ref.invalidate(qoinConfigProvider),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text(
              '다시 시도',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      data: (r) => r == null
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (r.kind == InheritedRateKind.brandDisabled ||
                        r.kind == InheritedRateKind.invalid)
                      const Padding(
                        padding: EdgeInsets.only(top: 1, right: 6),
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: AppColors.warning,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        r.sentence,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textBody,
                        ),
                      ),
                    ),
                  ],
                ),
                if (r.sub != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    r.sub!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
    );
    return Semantics(
      container: true,
      label: '소속 브랜드 ${brand.name}, 승인됨',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  brand.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textHeading,
                  ),
                ),
              ),
              Container(
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '승인됨',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textBody,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            '승인하면 이 매장은 이 브랜드의 가맹점이 돼요',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const Divider(height: 20, color: AppColors.border),
          const Text(
            '적립률',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          rateLine,
        ],
      ),
    );
  }
}

/// 경고 plate (미승인 / 없음 / 조회 실패). `error` 색이 아니다 — 데이터가 깨진 것이 아니라 점주 입력을 검증하는 정상 운영 상황.
class _Plate extends StatelessWidget {
  const _Plate({
    required this.title,
    required this.semantics,
    required this.lines,
    this.brandId,
    this.retry,
  });
  final String title;
  final String semantics;
  final List<String> lines;
  final String? brandId;
  final VoidCallback? retry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semantics,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ExcludeSemantics(
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textBody,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final l in lines)
              Text(
                l,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textBody,
                ),
              ),
            if (brandId != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      '브랜드 ID  $brandId',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '브랜드 ID 복사',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: brandId!));
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('복사했어요')));
                      }
                    },
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
            if (retry != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: retry,
                  style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
                  child: const Text(
                    '다시 시도',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
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

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.border,
      borderRadius: BorderRadius.circular(6),
    ),
  );
}

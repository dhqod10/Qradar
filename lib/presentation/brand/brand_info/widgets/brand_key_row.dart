import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/brand_private_profile_entity.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/presentation/brand/providers/brand_info_providers.dart';

/// 브랜드 정보 화면의 브랜드 키 행 (payment_server_authority B1, design §5).
///
/// brandKey 는 이제 부모 문서가 아니라 `brands/{id}/private/profile` 에서 **별도 비동기**로 읽는다.
/// 이 행은 `loading / data / error` 와 키 유무를 분리해 5상태로 그린다:
///
/// | 상태 | 조건 |
/// |---|---|
/// | S0 로딩 | 읽기 진행 중 (재시도 직후 포함 — 이전 상태를 남기지 않는다) |
/// | S1 발급됨 | 읽기 성공 + 키 있음 |
/// | S1′ 발급됨 + 승인 대기 회귀 | 키 있음 + `status == pending` |
/// | S2 미발급 | 읽기 성공 + 키 없음 + `pending` |
/// | S3 읽기 실패 | 읽기 예외 — **"관리자 승인 후" 문구로 떨어지지 않는다** (U4) |
/// | S4 이상 | 키 없음 + 이미 `approved` |
///
/// 이 행이 실패해도 화면 나머지는 정상으로 그린다 (행 단독 상태). 서버 예외 문자열은 그리지 않는다.
class BrandKeyRow extends ConsumerStatefulWidget {
  const BrandKeyRow({super.key, required this.brand});
  final BrandEntity brand;

  @override
  ConsumerState<BrandKeyRow> createState() => _BrandKeyRowState();
}

class _BrandKeyRowState extends ConsumerState<BrandKeyRow> {
  /// `다시 시도` 를 누른 횟수 (읽기 성공 시 0 으로 되돌린다). 1 이상이고 또 실패면 "연속 2회 이상 실패".
  int _retries = 0;

  void _retry() {
    setState(() => _retries++);
    ref.invalidate(brandPrivateProfileProvider(widget.brand.id));
  }

  @override
  Widget build(BuildContext context) {
    final provider = brandPrivateProfileProvider(widget.brand.id);
    ref.listen<AsyncValue<BrandPrivateProfileEntity?>>(provider, (_, next) {
      if (next is AsyncData) _retries = 0;
    });
    final async = ref.watch(provider);

    final Widget child = async.when(
      // 재시도(invalidate) 시 이전 error 를 그대로 두지 않고 스켈레톤으로 돌아간다.
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: false,
      loading: () => const _KeySkeleton(),
      error: (_, _) => _KeyReadFailed(onRetry: _retry, repeated: _retries >= 1),
      data: (profile) {
        final key = profile?.brandKey ?? '';
        final status = widget.brand.status;
        if (key.isNotEmpty) {
          return _KeyIssued(
            brandKey: key,
            revisionPending: status == EntityApprovalStatus.pending,
          );
        }
        if (status == EntityApprovalStatus.approved) {
          return const _KeyAnomaly();
        }
        return const _KeyNotIssued();
      },
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topLeft,
      child: SizedBox(width: double.infinity, child: child),
    );
  }
}

/// S0 — 라벨 아래 스켈레톤 막대 (16 x 160, 반경 4).
class _KeySkeleton extends StatelessWidget {
  const _KeySkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('brandKeyRow.loading'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '브랜드 키',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 6),
        Container(
          width: 160,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

/// S1 / S1′ — 키 값 + 복사. S1′ 은 공유 문구 대신 재승인 안내(복사는 막지 않는다).
class _KeyIssued extends StatelessWidget {
  const _KeyIssued({required this.brandKey, required this.revisionPending});
  final String brandKey;
  final bool revisionPending;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey(
        revisionPending ? 'brandKeyRow.issuedPending' : 'brandKeyRow.issued',
      ),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '브랜드 키',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    brandKey,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHeading,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.copy_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              tooltip: '복사',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: brandKey));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('복사됐어요'),
                    backgroundColor: AppColors.primary,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            revisionPending
                ? '재승인이 끝나기 전에는 점주가 이 키로 등록할 수 없어요'
                : '이 키를 점주에게 공유하면 가맹점 등록 시 사용할 수 있어요',
            style: TextStyle(
              fontSize: 11,
              color: revisionPending ? AppColors.warning : AppColors.textMuted,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// S2 — 미발급 (정상: 아직 승인 전).
class _KeyNotIssued extends StatelessWidget {
  const _KeyNotIssued();

  @override
  Widget build(BuildContext context) {
    return const Row(
      key: ValueKey('brandKeyRow.notIssued'),
      children: [
        Icon(Icons.lock_clock_rounded, size: 16, color: AppColors.textMuted),
        SizedBox(width: 8),
        Flexible(
          child: Text(
            '관리자 승인 후 브랜드 키가 발급됩니다',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}

/// S3 — 읽기 실패 (일시 장애일 수 있다). 미발급과 다른 아이콘·문구·`다시 시도`.
class _KeyReadFailed extends StatelessWidget {
  const _KeyReadFailed({required this.onRetry, required this.repeated});
  final VoidCallback onRetry;
  final bool repeated;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('brandKeyRow.readFailed'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: AppColors.error,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '브랜드 키를 불러오지 못했어요',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBody,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '발급된 키에는 영향이 없어요. 잠시 후 다시 시도해 주세요',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
              if (repeated) ...[
                const SizedBox(height: 2),
                const Text(
                  '계속 안 되면 관리자에게 문의해 주세요',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text(
            '다시 시도',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryBright,
            ),
          ),
        ),
      ],
    );
  }
}

/// S4 — 이상: 승인은 됐는데 키가 없다. 발급 버튼은 만들지 않는다 (admin 승인 CF 가 발급).
class _KeyAnomaly extends StatelessWidget {
  const _KeyAnomaly();

  @override
  Widget build(BuildContext context) {
    return const Row(
      key: ValueKey('brandKeyRow.anomaly'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.warning,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '브랜드 키가 아직 발급되지 않았어요',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBody,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '승인은 완료됐어요. 관리자에게 키 발급을 요청해 주세요',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/brand/providers/brand_info_providers.dart';
import 'package:qradar/presentation/common/providers/qoin_config_providers.dart';
import 'package:qradar/presentation/common/providers/qoin_rate_providers.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_labels.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_source_badge.dart';

/// 점주·브랜드 **읽기 전용** 적립률 행의 variant.
enum QoinRateInfoVariant {
  /// `my_store_page` — 아이콘 + 라벨 + 값 + 배지 + 출처 문장 + 안내 + (전체 중단 plate) + 이력 링크.
  block,

  /// `brand_info_page` — 라벨(좌) / 값+배지(우) + 출처 문장 + 우선순위 안내 + 이력 링크.
  summary,

  /// `brand_stores_page` 가맹점 타일 — 1줄 요약 + 이력 링크.
  tile,
}

/// 읽기 행 카피 (design §15-c). 점주·브랜드가 같은 위젯을 쓴다.
class QoinRateInfoCopy {
  QoinRateInfoCopy._();

  static const String label = 'Qoin 적립률';
  static const String contactAdmin = '변경이 필요하면 관리자에게 문의해 주세요';
  static const String brandPriorityNote =
      '매장이 따로 설정한 적립률이 있으면 그 값이 우선해요. 가맹점별 적립률은 가맹점 목록에서 확인할 수 있어요';
  static const String brandPriorityNoteDisabled =
      '가맹점별 적립률은 가맹점 목록에서 확인할 수 있어요';
  static const String allStopped = '현재 전체 적립이 중단되어 있어요';
  static const String historyLink = '적립률 변경 이력 보기';
  static const String historyLinkShort = '이력';
  static const String loadFailed = '적립률을 불러오지 못했어요';
  static const String retry = '다시 시도';

  /// 점주(매장) 출처 문장.
  static String storeSource(QoinRateBadgeKind kind, {String? brandName}) {
    switch (kind) {
      case QoinRateBadgeKind.storeSet:
        return '이 매장에 직접 설정된 값이에요';
      case QoinRateBadgeKind.brandInherit:
        return brandName == null || brandName.isEmpty
            ? '브랜드의 설정을 따르고 있어요'
            : '브랜드 "$brandName" 의 설정을 따르고 있어요';
      case QoinRateBadgeKind.globalInherit:
        return '기본 적립률을 따르고 있어요';
      case QoinRateBadgeKind.storeStopped:
        return '이 매장은 Qoin 을 적립하지 않아요';
      // 원인이 브랜드 스위치일 때 (N4: 개별 적립률이 있어도 마찬가지다).
      case QoinRateBadgeKind.brandStopped:
        return '브랜드 설정에 따라 이 매장은 Qoin 을 적립하지 않아요';
      case QoinRateBadgeKind.invalid:
        return '적립률 설정에 문제가 있어 적립이 되지 않을 수 있어요';
      case QoinRateBadgeKind.brandSet:
        // 매장 시점에서는 발생하지 않는다 (브랜드 값은 `브랜드 상속`). 방어적 폴백.
        return '브랜드에 직접 설정된 값이에요';
    }
  }

  /// 브랜드 출처 문장.
  static String brandSource(QoinRateBadgeKind kind) {
    switch (kind) {
      case QoinRateBadgeKind.brandSet:
        return '브랜드에 직접 설정된 값이에요';
      case QoinRateBadgeKind.brandStopped:
        return '이 브랜드는 Qoin 을 적립하지 않아요. 산하 매장 전체가 적립되지 않아요';
      case QoinRateBadgeKind.storeStopped:
      case QoinRateBadgeKind.invalid:
        return '적립률 설정에 문제가 있어 적립이 되지 않을 수 있어요';
      case QoinRateBadgeKind.globalInherit:
      case QoinRateBadgeKind.storeSet:
      case QoinRateBadgeKind.brandInherit:
        return '기본 적립률을 따르고 있어요';
    }
  }
}

/// 적립률 읽기 행 (점주·브랜드). **편집 어피던스 0**: 입력란·`수정`/`변경` 라벨·값 chevron·ripple 없음.
/// 이력 진입만 별도 `보기` 링크로 둔다.
///
/// 순수 표시 위젯이다 — 해석 결과([effective])는 호출자가 준다. 로딩 중에는 `0%` 나 이전 값을 그리지 않는다.
class QoinRateInfoRow extends StatelessWidget {
  const QoinRateInfoRow({
    super.key,
    required this.variant,
    required this.target,
    required this.effective,
    required this.allStopped,
    this.brandName,
    this.onOpenHistory,
    this.onRetry,
  });

  final QoinRateInfoVariant variant;

  /// 보는 대상 범위 (brand 또는 store).
  final QoinRateScope target;

  /// 3소스가 모두 준비된 뒤에만 data.
  final AsyncValue<EffectiveQoinRate> effective;

  /// 전역 `enabled == false` (전체 중단) 인가.
  final bool allStopped;

  /// 점주 화면의 `브랜드 "{이름}"` 문장용. null 이면 이름 로딩 중 문구.
  final String? brandName;

  final VoidCallback? onOpenHistory;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case QoinRateInfoVariant.block:
        return _Block(this);
      case QoinRateInfoVariant.summary:
        return _Summary(this);
      case QoinRateInfoVariant.tile:
        return _Tile(this);
    }
  }

  // ── 공통 계산 ────────────────────────────────────────────────────────────
  QoinRateBadgeKind kindOf(EffectiveQoinRate e) =>
      QoinRateBadgeKind.of(e, target: target);

  String sourceSentence(EffectiveQoinRate e) {
    final kind = kindOf(e);
    if (target == QoinRateScope.brand) return QoinRateInfoCopy.brandSource(kind);
    return QoinRateInfoCopy.storeSource(kind, brandName: brandName);
  }

  /// 브랜드 요약에서 우선순위 안내 첫 문장(`매장이 따로 설정한 적립률이…`)을 보일 수 있는가.
  /// 브랜드가 꺼져 있으면 개별 적립률은 효력이 없으므로 그 문장은 거짓이다 (N4) → 숨긴다.
  String brandNote(EffectiveQoinRate e) => e.isDisabled
      ? QoinRateInfoCopy.brandPriorityNoteDisabled
      : QoinRateInfoCopy.brandPriorityNote;
}

// ── 이력 링크 ──────────────────────────────────────────────────────────────────

class _HistoryLink extends StatelessWidget {
  const _HistoryLink({required this.onTap, this.short = false});
  final VoidCallback? onTap;
  final bool short;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return const SizedBox.shrink();
    return Semantics(
      button: true,
      label: short
          ? '이 가맹점의 적립률 변경 이력 보기'
          : QoinRateInfoCopy.historyLink,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: 44,
            minWidth: short ? 44 : 0,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history_rounded,
                size: short ? 14 : 16,
                color: short ? AppColors.textBody : AppColors.primary,
              ),
              const SizedBox(width: 4),
              Text(
                short
                    ? QoinRateInfoCopy.historyLinkShort
                    : QoinRateInfoCopy.historyLink,
                style: TextStyle(
                  fontSize: short ? 12 : 13,
                  fontWeight: short ? FontWeight.w500 : FontWeight.w600,
                  color: short ? AppColors.textBody : AppColors.primary,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: short ? 14 : 16,
                color: short ? AppColors.textBody : AppColors.primary,
              ),
            ],
          ),
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

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.onRetry});
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          QoinRateInfoCopy.loadFailed,
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            child: const Text(
              QoinRateInfoCopy.retry,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

class _AllStoppedPlate extends StatelessWidget {
  const _AllStoppedPlate();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.pause_circle_outline_rounded,
            size: 16,
            color: AppColors.warning,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              QoinRateInfoCopy.allStopped,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textBody,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── block (점주 내 매장) ───────────────────────────────────────────────────────

class _Block extends StatelessWidget {
  const _Block(this.row);
  final QoinRateInfoRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ExcludeSemantics(
          child: Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.toll_rounded, size: 20, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: row.effective.when(
            loading: () => const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  QoinRateInfoCopy.label,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    _Skeleton(width: 64, height: 20),
                    SizedBox(width: 8),
                    _Skeleton(width: 72, height: 22),
                  ],
                ),
              ],
            ),
            error: (_, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  QoinRateInfoCopy.label,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                _ErrorLine(onRetry: row.onRetry),
                _HistoryLink(onTap: row.onOpenHistory),
              ],
            ),
            data: (e) {
              final kind = row.kindOf(e);
              final sentence = row.sourceSentence(e);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    // 값 영역은 버튼이 아니다 (button:false) — 편집 가능한 곳으로 인식되지 않게.
                    button: false,
                    label:
                        '${QoinRateInfoCopy.label} ${QoinRateValueLabel.spokenEffective(e, sentence: true)}, ${kind.label}. '
                        '$sentence. ${QoinRateInfoCopy.contactAdmin}',
                    excludeSemantics: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          QoinRateInfoCopy.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            QoinRateValueText(
                              effective: e,
                              kind: kind,
                              fontSize: 20,
                              disabledSentence: true,
                            ),
                            QoinRateSourceBadge(kind: kind),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sentence,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          QoinRateInfoCopy.contactAdmin,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (row.allStopped) const _AllStoppedPlate(),
                  const SizedBox(height: 4),
                  _HistoryLink(onTap: row.onOpenHistory),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── summary (브랜드 정보) ──────────────────────────────────────────────────────

class _Summary extends StatelessWidget {
  const _Summary(this.row);
  final QoinRateInfoRow row;

  @override
  Widget build(BuildContext context) {
    return row.effective.when(
      loading: () => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                QoinRateInfoCopy.label,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              _Skeleton(width: 64, height: 20),
            ],
          ),
          SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: _Skeleton(width: 72, height: 22),
          ),
        ],
      ),
      error: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            QoinRateInfoCopy.label,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          _ErrorLine(onRetry: row.onRetry),
          _HistoryLink(onTap: row.onOpenHistory),
        ],
      ),
      data: (e) {
        final kind = row.kindOf(e);
        final sentence = row.sourceSentence(e);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: false,
              label:
                  '${QoinRateInfoCopy.label} ${QoinRateValueLabel.spokenEffective(e, sentence: true)}, ${kind.label}. '
                  '$sentence. ${row.brandNote(e)}',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Text(
                          QoinRateInfoCopy.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            QoinRateValueText(
                              effective: e,
                              kind: kind,
                              fontSize: 18,
                              disabledSentence: true,
                            ),
                            const SizedBox(height: 4),
                            QoinRateSourceBadge(kind: kind),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sentence,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    row.brandNote(e),
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (row.allStopped) const _AllStoppedPlate(),
            const Divider(height: 24, color: AppColors.border),
            _HistoryLink(onTap: row.onOpenHistory),
          ],
        );
      },
    );
  }
}

// ── tile (가맹점 타일 행) ──────────────────────────────────────────────────────

class _Tile extends StatelessWidget {
  const _Tile(this.row);
  final QoinRateInfoRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const ExcludeSemantics(
          child: Icon(Icons.toll_rounded, size: 13, color: AppColors.textMuted),
        ),
        const SizedBox(width: 4),
        const ExcludeSemantics(
          child: Text(
            'Qoin',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: row.effective.when(
            loading: () => const Align(
              alignment: Alignment.centerLeft,
              child: _Skeleton(width: 40, height: 14),
            ),
            // 타일은 행을 숨기지 않고 값 자리에만 표시. 스트림이라 재구독은 자동 (별도 재시도 없음).
            error: (_, _) => const Text(
              '불러오지 못했어요',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            data: (e) {
              final kind = row.kindOf(e);
              return Semantics(
                button: false,
                label:
                    'Qoin 적립률 ${QoinRateValueLabel.spokenEffective(e)}, ${kind.label}',
                excludeSemantics: true,
                child: Row(
                  children: [
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: QoinRateValueText(
                          effective: e,
                          kind: kind,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    QoinRateSourceBadge(kind: kind),
                  ],
                ),
              );
            },
          ),
        ),
        _HistoryLink(onTap: row.onOpenHistory, short: true),
      ],
    );
  }
}

/// 점주 `내 매장` / 브랜드 정보에서 쓰는 provider 결합 래퍼. 읽기 행에 필요한 3소스를 구독해
/// [QoinRateInfoRow] 에 넘긴다 (로딩 중 `0%` 금지 — 3소스 준비 전엔 loading).
class QoinStoreRateInfo extends ConsumerWidget {
  const QoinStoreRateInfo({
    super.key,
    required this.store,
    required this.onOpenHistory,
  });

  final StoreEntity store;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (
      store: store.qoinAccrualRate,
      storeSwitch: store.qoinAccrualEnabled,
      brandId: store.brandId,
    );
    final effective = ref.watch(effectiveStoreQoinRateProvider(key));
    final cfg = ref.watch(qoinConfigProvider);
    final brandId = store.brandId;
    final brandName = (brandId == null || brandId.isEmpty)
        ? null
        : ref.watch(brandByIdProvider(brandId)).asData?.value?.name;
    return QoinRateInfoRow(
      variant: QoinRateInfoVariant.block,
      target: QoinRateScope.store,
      effective: effective,
      allStopped: cfg.asData?.value?.enabled == false,
      brandName: brandName,
      onOpenHistory: onOpenHistory,
      onRetry: () => ref.invalidate(qoinConfigProvider),
    );
  }
}

/// 브랜드 정보 화면용 래퍼.
class QoinBrandRateInfo extends ConsumerWidget {
  const QoinBrandRateInfo({
    super.key,
    required this.brand,
    required this.onOpenHistory,
  });

  final BrandEntity brand;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effective = ref.watch(effectiveBrandQoinRateProvider(brand.id));
    final cfg = ref.watch(qoinConfigProvider);
    return QoinRateInfoRow(
      variant: QoinRateInfoVariant.summary,
      target: QoinRateScope.brand,
      effective: effective,
      allStopped: cfg.asData?.value?.enabled == false,
      onOpenHistory: onOpenHistory,
      onRetry: () => ref.invalidate(qoinConfigProvider),
    );
  }
}

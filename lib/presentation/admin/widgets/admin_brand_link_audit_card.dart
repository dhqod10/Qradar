// TRANSITIONAL(brand_authorization_hardening §4): 임시 브랜드 링크 점검 카드. 정리 커밋에서 이 파일째 삭제한다.
// 정리 커밋 = 이 파일 삭제 + 허브의 마운트 한 줄 삭제 +
//   audit_brand_links_use_case / brand_link_audit_* (domain·data) 삭제.
// 상태·provider·UseCase 호출을 전부 이 파일 안에 둔다 (공용 위젯·공용 provider 재사용 금지, Qoin 마이그레이션 카드와 서로 참조 금지).
//
// 핵심 원칙: **쓰기 0.** 자동 교정 버튼이 없다 — `점검하기`(조회)와 ID 복사만 있다. `mismatch` 는 공격 증거가 아니다
// (admin 이 수동 발급한 레거시 계정도 submittedBy 가 admin 이거나 없다). 화면 어디에도 `의심`/`공격`/`사칭` 을 쓰지 않는다.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/data/datasources/remote/brand_link_audit_remote_data_source.dart';
import 'package:qradar/data/repositories/brand_link_audit_repository_impl.dart';
import 'package:qradar/domain/entities/brand_link_audit_result.dart';
import 'package:qradar/domain/repositories/brand_link_audit_repository.dart';
import 'package:qradar/domain/usecases/audit_brand_links_use_case.dart';

final _auditRepositoryProvider = Provider<BrandLinkAuditRepository>(
  (ref) => BrandLinkAuditRepositoryImpl(BrandLinkAuditRemoteDataSource()),
);

/// 테스트가 대체할 수 있도록 공개한다.
final auditBrandLinksUseCaseProvider = Provider<AuditBrandLinksUseCase>(
  (ref) => AuditBrandLinksUseCase(ref.watch(_auditRepositoryProvider)),
);

enum _Phase { idle, checking, done, failed }

/// 분류 라벨 · 의미 · 조치 안내 (design §4-d). 조치 안내는 문장일 뿐 탭 타깃이 아니다.
class _ClassCopy {
  const _ClassCopy(this.label, this.meaning, this.action);
  final String label;
  final String meaning;
  final String? action;
}

const Map<BrandLinkClass, _ClassCopy> _copy = {
  BrandLinkClass.dangling: _ClassCopy(
    '연결 끊김',
    '브랜드 계정이 존재하지 않는 브랜드를 가리켜요',
    'Console 에서 users/{uid} 의 brandId 를 삭제하세요. 사용자는 다시 등록하면 올바르게 연결돼요',
  ),
  BrandLinkClass.duplicate: _ClassCopy(
    '중복 연결',
    '한 브랜드에 계정이 둘 이상 연결돼 있어요',
    '브랜드를 제출한 계정만 남기고 나머지 계정의 brandId 를 삭제하세요',
  ),
  BrandLinkClass.storeDanglingBrand: _ClassCopy(
    '매장의 브랜드 없음',
    '매장이 존재하지 않는 브랜드를 가리켜요 (적립률 상속 근거)',
    'stores/{id} 의 brandId 를 고치거나 매장을 승인 대기로 되돌려 다시 승인하세요. 그동안 이 매장은 전역 적립률로 적립돼요',
  ),
  BrandLinkClass.storeUnapprovedBrand: _ClassCopy(
    '매장의 브랜드 미승인',
    '매장이 승인되지 않은 브랜드를 가리켜요 (적립률 상속 근거)',
    'stores/{id} 의 brandId 를 고치거나 매장을 승인 대기로 되돌려 다시 승인하세요. 그동안 이 매장은 전역 적립률로 적립돼요',
  ),
  BrandLinkClass.mismatch: _ClassCopy(
    '제출자 불일치',
    '브랜드를 제출한 계정과 연결된 계정이 달라요. 직접 발급한 계정일 수 있어요',
    '직접 발급한 계정이면 그대로 두세요. 기억에 없는 계정이면 brandId 삭제 후 해당 브랜드의 메뉴 변경을 확인하세요',
  ),
  BrandLinkClass.orphanBrand: _ClassCopy(
    '고아 브랜드',
    '아무 계정도 가리키지 않는 브랜드예요',
    '승인 대기 상태이고 아무도 가리키지 않으면 삭제해도 돼요',
  ),
  BrandLinkClass.ok: _ClassCopy('정상', '문제 없어요', null),
  BrandLinkClass.okOnboarding: _ClassCopy('등록 전', '브랜드 등록 전 단계예요', null),
};

class AdminBrandLinkAuditCard extends ConsumerStatefulWidget {
  const AdminBrandLinkAuditCard({super.key});

  @override
  ConsumerState<AdminBrandLinkAuditCard> createState() =>
      _AdminBrandLinkAuditCardState();
}

class _AdminBrandLinkAuditCardState
    extends ConsumerState<AdminBrandLinkAuditCard> {
  _Phase _phase = _Phase.idle;
  BrandLinkAuditResult? _result;
  final Set<BrandLinkClass> _expanded = {};

  Future<void> _run() async {
    setState(() => _phase = _Phase.checking);
    try {
      final r = await ref.read(auditBrandLinksUseCaseProvider)();
      if (!mounted) return;
      setState(() {
        _result = r;
        _expanded.clear();
        _phase = _Phase.done;
      });
    } catch (_) {
      // 실패를 "문제 없음" 으로 읽히게 두지 않는다 — 건수 영역을 그리지 않는다.
      if (mounted) setState(() => _phase = _Phase.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '브랜드 링크 점검',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHeading,
                    ),
                  ),
                ),
                Container(
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '임시',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textBody,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _body(),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    switch (_phase) {
      case _Phase.idle:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '브랜드 계정과 매장의 브랜드 연결이 올바른지 확인해요. 읽기만 하고 아무것도 바꾸지 않아요',
              style: TextStyle(fontSize: 13, color: AppColors.textBody),
            ),
            const SizedBox(height: 12),
            _outlined('점검하기', _run),
          ],
        );
      case _Phase.checking:
        return Semantics(
          liveRegion: true,
          label: '점검하고 있어요',
          excludeSemantics: true,
          child: const Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 10),
              Text(
                '점검하고 있어요',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
          ),
        );
      case _Phase.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 18,
                  color: AppColors.error,
                ),
                SizedBox(width: 6),
                Text(
                  '점검하지 못했어요',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textBody,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            const Text(
              '잠시 후 다시 시도해주세요',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            _outlined('다시 시도', _run),
          ],
        );
      case _Phase.done:
        return _resultView(_result!);
    }
  }

  Widget _resultView(BrandLinkAuditResult r) {
    final t = r.checkedAt;
    final when =
        '${t.month}월 ${t.day}일 ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final spoken = StringBuffer('점검 결과. 바로 교정이 필요한 곳 ${r.fixNowTotal}곳');
    for (final c in BrandLinkAuditResult.fixNow) {
      spoken.write(', ${_copy[c]!.label} ${r.count(c)}곳');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          liveRegion: true,
          label: spoken.toString(),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '점검 결과',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
              Text(
                when,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (r.allClear) ...[
          const Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Text(
                '연결 문제가 없어요',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHeading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '다시 점검해서 0건이 유지되면 이 카드는 이후 업데이트에서 사라져요',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ] else ...[
          Text(
            '바로 교정이 필요한 곳 ${r.fixNowTotal}곳',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 4),
          // 건수는 0 도 숨기지 않는다 — 빠진 분류가 "없음" 인지 "안 보여준 것" 인지 헷갈리지 않게.
          Text(
            [
              for (final c in BrandLinkAuditResult.fixNow)
                '${_copy[c]!.label} ${r.count(c)}',
              for (final c in BrandLinkAuditResult.judge)
                '${_copy[c]!.label} ${r.count(c)}',
            ].join(' · '),
            style: const TextStyle(fontSize: 13, color: AppColors.textBody),
          ),
        ],
        for (final c in BrandLinkAuditResult.fixNow)
          if (r.count(c) > 0) _classPlate(r, c, warning: true),
        for (final c in BrandLinkAuditResult.judge)
          if (r.count(c) > 0) _classPlate(r, c, warning: false),
        const SizedBox(height: 12),
        Text(
          '정상 ${r.count(BrandLinkClass.ok)} · 등록 전 ${r.count(BrandLinkClass.okOnboarding)}',
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        _outlined('다시 점검', _run),
      ],
    );
  }

  Widget _classPlate(
    BrandLinkAuditResult r,
    BrandLinkClass c, {
    required bool warning,
  }) {
    final copy = _copy[c]!;
    final items = r.itemsOf(c);
    final expanded = _expanded.contains(c);
    final shown = expanded ? items : items.take(5).toList();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warning
            ? AppColors.warning.withValues(alpha: 0.10)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${copy.label} ${r.count(c)}곳',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textBody,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            copy.meaning,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          for (final it in shown) _itemRow(c, it),
          if (items.length > 5)
            TextButton(
              onPressed: () => setState(
                () => expanded ? _expanded.remove(c) : _expanded.add(c),
              ),
              style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
              child: Text(
                expanded ? '접기' : '전체 보기',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          if (r.truncated.contains(c))
            Text(
              '건수는 ${r.count(c)}곳이지만 ${items.length}곳까지만 보여요',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          if (copy.action != null) ...[
            const SizedBox(height: 6),
            Text(
              copy.action!,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemRow(BrandLinkClass c, BrandLinkAuditItem it) {
    final isStore = it.storeId != null;
    final title = isStore
        ? (it.storeName?.isNotEmpty == true ? it.storeName! : it.storeId!)
        : (it.email?.isNotEmpty == true
              ? it.email!
              : (it.brandName?.isNotEmpty == true
                    ? it.brandName!
                    : (it.uid ?? it.brandId ?? '-')));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '· $title',
            style: const TextStyle(fontSize: 13, color: AppColors.textBody),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 0,
            children: [
              if (it.uid != null) _IdCopy('계정 UID', it.uid!),
              if (it.storeId != null) _IdCopy('매장 ID', it.storeId!),
              if (it.brandId != null) _IdCopy('브랜드 ID', it.brandId!),
              if (c == BrandLinkClass.mismatch && it.submittedBy != null)
                _IdCopy('제출자 UID', it.submittedBy!),
            ],
          ),
          if (it.brandName != null &&
              (it.uid != null || it.storeId != null) &&
              it.brandName!.isNotEmpty)
            Text(
              '브랜드 ${it.brandName}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }

  Widget _outlined(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _IdCopy extends StatelessWidget {
  const _IdCopy(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SelectableText(
            '$label $value',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ),
        IconButton(
          tooltip: '$label 복사',
          visualDensity: VisualDensity.compact,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
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
    );
  }
}

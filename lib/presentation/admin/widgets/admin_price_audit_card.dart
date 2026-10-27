// TEMP_PRICE_AUDIT_CARD — payment_price_authority 배포 ②⑨ 용 **임시** admin 카드. 배포 ⑩ 정리 커밋에서 이 파일째 삭제한다.
//
// 읽기 전용 감사다 — 이 화면에는 데이터를 바꾸는 버튼이 없다 (측정 버튼 1개). 서버가 고치지 않고 멈추고 보고하는 도구다.
//  - 세 분류(ⓐ 주문 정합성 ⓑ self-approved override ⓒ store-scope 참조)를 항상 그린다. 0건이어도 행을 숨기지 않고,
//    응답에 분류 자체가 없으면 "응답에 없음" 으로 다르게 그린다.
//  - 실패(권한/시간초과/네트워크/형식)는 건수 영역 없이 종류별 문구로만 그린다. 서버 문자열은 보간하지 않는다.
//  - 기준선 판정: ⓐ 위반 또는 ⓑ 가 0 이 아니면 "enforce 로 넘어가지 않는다" 를 빨갛게 알린다 (런북 중단 기준).
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/data/datasources/remote/price_audit_remote_data_source.dart';
import 'package:qradar/data/repositories/price_audit_repository_impl.dart';
import 'package:qradar/domain/entities/migration_call_exception.dart';
import 'package:qradar/domain/entities/price_audit_report.dart';
import 'package:qradar/domain/repositories/price_audit_repository.dart';
import 'package:qradar/domain/usecases/run_price_audit_use_case.dart';

final _priceAuditRepositoryProvider = Provider<PriceAuditRepository>(
  (ref) => PriceAuditRepositoryImpl(PriceAuditRemoteDataSource()),
);

/// 테스트가 대체할 수 있도록 공개한다.
final runPriceAuditUseCaseProvider = Provider<RunPriceAuditUseCase>(
  (ref) => RunPriceAuditUseCase(ref.watch(_priceAuditRepositoryProvider)),
);

enum _Phase { idle, running, done, failed }

const _muted = TextStyle(fontSize: 12, color: AppColors.textMuted);
const _body = TextStyle(fontSize: 13, color: AppColors.textBody);

class AdminPriceAuditCard extends ConsumerStatefulWidget {
  const AdminPriceAuditCard({super.key});

  @override
  ConsumerState<AdminPriceAuditCard> createState() =>
      _AdminPriceAuditCardState();
}

class _AdminPriceAuditCardState extends ConsumerState<AdminPriceAuditCard> {
  _Phase _phase = _Phase.idle;
  PriceAuditReport? _report;
  MigrationCallFailure? _failure;

  Future<void> _run() async {
    if (_phase == _Phase.running) return;
    setState(() {
      _phase = _Phase.running;
      _report = null;
      _failure = null;
    });
    try {
      final r = await ref.read(runPriceAuditUseCaseProvider)();
      if (!mounted) return;
      setState(() {
        _report = r;
        _phase = _Phase.done;
      });
    } on MigrationCallException catch (e) {
      if (!mounted) return;
      setState(() {
        _failure = e.kind;
        _phase = _Phase.failed;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failure = MigrationCallFailure.failed;
        _phase = _Phase.failed;
      });
    }
  }

  static String _failureText(MigrationCallFailure f) => switch (f) {
    MigrationCallFailure.permissionDenied => '관리자 권한이 필요해요.',
    MigrationCallFailure.timeout =>
      '시간이 초과됐어요. 서버는 계속 읽고 있을 수 있어요. 결과가 없다는 뜻이 아니에요.',
    MigrationCallFailure.network => '서버에 닿지 못했어요. 네트워크를 확인하고 다시 측정해 주세요.',
    MigrationCallFailure.stoppedByServer => '서버가 멈췄어요.',
    MigrationCallFailure.malformedResponse => '응답 형식을 알아볼 수 없어요. 값을 믿지 마세요.',
    MigrationCallFailure.failed => '측정하지 못했어요. 잠시 후 다시 시도해 주세요.',
  };

  @override
  Widget build(BuildContext context) {
    final running = _phase == _Phase.running;
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
            const Text(
              '② ⑨ 가격 감사 (읽기 전용)',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeading,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '주문 금액의 내부 정합성, 점주가 직접 승인 상태로 쓴 가격 오버라이드, 브랜드 메뉴가 가맹점 옵션 그룹을 가리키는 건수를 잽니다. 데이터를 고치지 않습니다.',
              style: _muted,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: running ? null : _run,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: running ? AppColors.border : AppColors.primary,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: running
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        '측정 실행',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
              ),
            ),
            if (_phase == _Phase.failed && _failure != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _failureText(_failure!),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ),
            if (_phase == _Phase.done && _report != null)
              _ReportView(report: _report!),
          ],
        ),
      ),
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({required this.report});
  final PriceAuditReport report;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final t = r.receivedAt;
    final at =
        '${t.month}월 ${t.day}일 ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final blocks = r.blocksEnforce;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (blocks ? AppColors.error : AppColors.primary).withValues(
              alpha: 0.10,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            blocks
                ? '기준선이 0 이 아니거나 응답이 불완전해요. 보고하고 enforce 로 넘어가지 않습니다 · $at'
                : '측정 결과 — ⓐ 위반 0건, ⓑ 0건 (아무것도 바꾸지 않았어요) · $at',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: blocks ? AppColors.error : AppColors.primary,
            ),
          ),
        ),
        _Row(
          label: 'ⓐ 주문 금액 정합성 위반',
          hint:
              '스캔 ${r.ordersScanned ?? '?'}건${r.ordersTruncated == true ? ' (한도에서 잘림 — 기간을 줄여 다시 측정)' : ''} · 라인합·소계·총액·승인액 4개 불변식',
          count: r.ordersViolationCount,
          expectZero: true,
          children: [
            if (r.byCheck != null)
              for (final e in r.byCheck!.entries)
                Text('· ${e.key}: ${e.value}건', style: _body),
            for (final v
                in r.orderViolations ?? const <PriceAuditOrderViolation>[])
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText('주문 ${v.orderId}', style: _body),
                    Text(
                      '${v.failed.join(', ')} · 소계 ${v.clientSubtotal ?? '?'} · 라인합 ${v.sumOfLineTotals ?? '?'} · 승인액 ${v.amount ?? '?'}',
                      style: _muted,
                    ),
                  ],
                ),
              ),
          ],
        ),
        _Row(
          label: 'ⓑ 점주가 직접 승인한 가격 오버라이드',
          hint:
              '스캔 ${r.overridesScanned ?? '?'}건 · 효력 있는 핵심 필드가 있고 승인자가 없거나 점주 본인 · 운영 필드만 있는 승인 문서 ${r.opsOnlyApproved ?? '?'}건은 정상',
          count: r.selfApprovedCount,
          expectZero: true,
          children: [
            for (final o in r.selfApproved ?? const <PriceAuditOverrideItem>[])
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      '매장 ${o.storeId} · 메뉴 ${o.masterMenuItemId}',
                      style: _body,
                    ),
                    Text(
                      '가격 ${o.priceOverride ?? '-'} · 중단 ${o.excluded} · 상태 ${o.status ?? '-'} · 승인자 ${o.approvedBy ?? '없음'}',
                      style: _muted,
                    ),
                  ],
                ),
              ),
          ],
        ),
        _Row(
          label: 'ⓒ 브랜드 메뉴 → 가맹점 옵션 그룹 참조',
          hint:
              '가맹점 수를 곱한 영향 범위 ${r.refStorePairs ?? '?'}건 · 가맹점이 승인 없이 가격을 바꿀 수 있는 옵션 (다음 판단을 위한 측정)',
          count: r.refCount,
          children: [
            for (final i in r.refItems ?? const <PriceAuditRefItem>[])
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: SelectableText(
                  '브랜드 ${i.brandId} · 메뉴 ${i.menuItemId} · 그룹 ${i.groupId} · 가맹점 ${i.franchiseStores}곳',
                  style: _body,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.hint,
    required this.count,
    this.expectZero = false,
    this.children = const [],
  });
  final String label;
  final String hint;
  final int? count;
  final bool expectZero;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final missing = count == null;
    final bad = expectZero && !missing && count! > 0;
    final color = missing || bad ? AppColors.error : AppColors.textHeading;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bad || missing
            ? AppColors.error.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBody,
                  ),
                ),
              ),
              Text(
                missing ? '응답에 없음' : '$count건',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(hint, style: _muted),
          ...children,
        ],
      ),
    );
  }
}

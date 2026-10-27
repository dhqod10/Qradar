// TEMP_MIGRATION_CARD — payment_server_authority 배포 ③⑤⑨ 용 **임시** admin 카드. 배포 ⑪ 정리 커밋에서 이 파일째 삭제한다.
// (선례: qoin_accrual_rate_hierarchy 의 임시 admin 허브 카드. 삭제 대상 전체 목록은 implementation.md §11.)
//
// 핵심 원칙
//  - 시험 실행(dryRun:true)과 실행(dryRun:false)은 버튼·색·배너가 다른 행위다. 실행은 (1) 이 화면에서 시험 실행을 본 뒤에만
//    활성화되고 (2) 서버가 멈출 조건이 있으면 비활성화되며 (3) 확인 다이얼로그를 거친다. 실행이 끝나면 시험 실행 결과를 버린다
//    (다시 시험 실행을 해야 다음 실행을 누를 수 있다 — 런북 "재 dry-run 이 전부 0" 확인).
//  - 리포트의 모든 분류를 항상 그린다. 0건이어도 행을 숨기지 않고, 응답에 분류 자체가 없으면 "응답에 없음" 으로 다르게 그린다.
//  - 실패(권한/시간초과/네트워크/서버 중단/형식)를 각각 구분해 그리고, 실패일 때는 건수 영역을 그리지 않는다. 서버 문자열은 보간하지 않는다.
//  - 상태·provider·UseCase 호출을 이 파일 안에 둔다.

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/data/datasources/remote/migration_remote_data_source.dart';
import 'package:qradar/data/repositories/migration_repository_impl.dart';
import 'package:qradar/domain/entities/migration_call_exception.dart';
import 'package:qradar/domain/entities/migration_report.dart';
import 'package:qradar/domain/repositories/migration_repository.dart';
import 'package:qradar/domain/usecases/run_migration_use_cases.dart';

final _migrationRepositoryProvider = Provider<MigrationRepository>(
  (ref) => MigrationRepositoryImpl(MigrationRemoteDataSource()),
);

/// 테스트가 대체할 수 있도록 공개한다.
final runStoreApprovalMigrationUseCaseProvider =
    Provider<RunStoreApprovalMigrationUseCase>(
      (ref) => RunStoreApprovalMigrationUseCase(
        ref.watch(_migrationRepositoryProvider),
      ),
    );

final runBrandProfileMigrationUseCaseProvider =
    Provider<RunBrandProfileMigrationUseCase>(
      (ref) => RunBrandProfileMigrationUseCase(
        ref.watch(_migrationRepositoryProvider),
      ),
    );

enum _Phase { idle, running, done, failed }

// ───────────────────────── 공통 조각 ─────────────────────────

class _CardShell extends StatelessWidget {
  const _CardShell({required this.title, required this.child});
  final String title;
  final Widget child;

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
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeading,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

Widget _button(String label, VoidCallback? onTap, {bool filled = false}) {
  final enabled = onTap != null;
  return SizedBox(
    width: double.infinity,
    height: 44,
    child: filled
        ? FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              disabledBackgroundColor: AppColors.border,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.onPrimary,
              ),
            ),
          )
        : OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: enabled ? AppColors.primary : AppColors.border,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: enabled ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ),
  );
}

const _muted = TextStyle(fontSize: 12, color: AppColors.textMuted);
const _body = TextStyle(fontSize: 13, color: AppColors.textBody);

/// 모드 배너 — 시험 실행과 실행을 화면에서 확실히 구분한다.
class _ModeBanner extends StatelessWidget {
  const _ModeBanner({
    required this.dryRun,
    required this.written,
    required this.at,
  });
  final bool? dryRun;
  final int? written;
  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final t =
        '${at.month}월 ${at.day}일 ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    final String text;
    final Color color;
    if (dryRun == true) {
      text = '시험 실행 결과 — 아무것도 바꾸지 않았어요 · $t';
      color = AppColors.primary;
    } else if (dryRun == false) {
      text = '실행 완료 — 데이터를 바꿨어요 (${written ?? '?'}건 기록) · $t';
      color = AppColors.error;
    } else {
      text = '서버가 시험 실행인지 실행인지 알려주지 않았어요. 값을 믿지 마세요 · $t';
      color = AppColors.warning;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// 분류 1행. count == null 이면 "응답에 없음". 0 이어도 행은 그린다.
class _ClassRow extends StatelessWidget {
  const _ClassRow({
    required this.label,
    required this.hint,
    required this.count,
    this.expectZero = false,
    this.children = const [],
  });
  final String label;
  final String hint;
  final int? count;

  /// 0 이 아니면 멈춰야 하는 분류.
  final bool expectZero;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final missing = count == null;
    final bad = expectZero && !missing && count! > 0;
    final value = missing ? '응답에 없음' : '$count건';
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
                value,
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

/// 잘라내지 않는 목록. 길면 이 영역 안에서 스크롤된다 ("전부 확인" 이 거짓이 되지 않게 take(n) 을 쓰지 않는다).
class _FullList extends StatefulWidget {
  const _FullList({required this.rows});
  final List<Widget> rows;

  @override
  State<_FullList> createState() => _FullListState();
}

class _FullListState extends State<_FullList> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: Scrollbar(
          controller: _controller,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _controller,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.rows,
            ),
          ),
        ),
      ),
    );
  }
}

Widget _storeRow(String id, String? name, {String? extra}) {
  final title = name != null && name.isNotEmpty ? name : '(이름 없음)';
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('· $title', style: _body),
        SelectableText('ID $id', style: _muted),
        if (extra != null) Text(extra, style: _muted),
      ],
    ),
  );
}

Widget _failureView(Object? error, VoidCallback onRetry) {
  final MigrationCallFailure kind = error is MigrationCallException
      ? error.kind
      : MigrationCallFailure.failed;
  final String title;
  final String detail;
  switch (kind) {
    case MigrationCallFailure.permissionDenied:
      title = '권한이 없어요';
      detail = 'admin 계정으로 로그인했는지 확인하세요. 아무것도 실행되지 않았어요';
    case MigrationCallFailure.timeout:
      title = '응답을 기다리다 시간이 지났어요';
      detail = '서버에서는 계속 실행 중일 수 있어요. 결과를 모르는 상태예요 — 시험 실행으로 현재 상태를 먼저 확인하세요';
    case MigrationCallFailure.network:
      title = '서버에 닿지 못했어요';
      detail = '네트워크를 확인하고 다시 시도하세요. 실행 중이었다면 시험 실행으로 상태를 먼저 확인하세요';
    case MigrationCallFailure.stoppedByServer:
      title = '서버가 이상치를 이유로 실행을 멈췄어요';
      detail = '아무것도 쓰지 않았어요. 아래 목록을 확인하세요';
    case MigrationCallFailure.malformedResponse:
      title = '응답 형식을 알아볼 수 없어요';
      detail = '건수를 믿을 수 없어요. 결과가 없는 것이 아니에요';
    case MigrationCallFailure.failed:
      title = '호출하지 못했어요';
      detail = '결과를 모르는 상태예요 — 0건이라는 뜻이 아니에요';
  }
  final code = error is MigrationCallException ? error.code : null;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.error,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 2),
      Text(detail, style: _muted),
      if (code != null) Text('코드 $code', style: _muted),
      if (error is MigrationCallException &&
          kind == MigrationCallFailure.stoppedByServer) ...[
        if (error.anomalies != null)
          _ClassRow(
            label: 'ⓒ 이상치 (anomalies)',
            hint: '승인 전인데 approvedAt 이 있고 approvedBy 가 없는 매장 ID',
            count: error.anomalies!.length,
            expectZero: true,
            children: [
              _FullList(
                rows: [
                  for (final id in error.anomalies!)
                    SelectableText('· $id', style: _body),
                ],
              ),
            ],
          ),
        if (error.invalid != null)
          _ClassRow(
            label: '무효 (invalid)',
            hint: '서버가 멈춘 이유가 된 항목',
            count: error.invalid!.length,
            expectZero: true,
            children: [
              _FullList(
                rows: [
                  for (final i in error.invalid!)
                    SelectableText('· ${i.id} — ${i.detail}', style: _body),
                ],
              ),
            ],
          ),
      ],
      const SizedBox(height: 12),
      _button('다시 시험 실행', onRetry),
    ],
  );
}

Widget _running(String label) => Semantics(
  liveRegion: true,
  label: label,
  excludeSemantics: true,
  child: Row(
    children: [
      const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: _muted)),
    ],
  ),
);

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            '실행',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  return ok == true;
}

// ───────────────────────── ③ 매장 승인 메타 ─────────────────────────

class AdminStoreApprovalMigrationCard extends ConsumerStatefulWidget {
  const AdminStoreApprovalMigrationCard({super.key});

  @override
  ConsumerState<AdminStoreApprovalMigrationCard> createState() =>
      _StoreCardState();
}

class _StoreCardState extends ConsumerState<AdminStoreApprovalMigrationCard> {
  _Phase _phase = _Phase.idle;
  StoreApprovalMigrationReport? _report;

  /// 이 화면에서 본 시험 실행 결과. 실행 버튼의 전제다. 실행/실패 뒤에는 버린다.
  StoreApprovalMigrationReport? _seenDryRun;
  Object? _error;

  Future<void> _call({required bool dryRun}) async {
    setState(() => _phase = _Phase.running);
    try {
      final r = await ref.read(runStoreApprovalMigrationUseCaseProvider)(
        dryRun: dryRun,
      );
      if (!mounted) return;
      setState(() {
        _report = r;
        _seenDryRun = dryRun ? r : null;
        _phase = _Phase.done;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _seenDryRun = null;
        _report = null;
        _phase = _Phase.failed;
      });
    }
  }

  Future<void> _execute() async {
    final s = _seenDryRun;
    if (s == null) return;
    final n =
        (s.setStatusApproved?.length ?? 0) +
        (s.backfillApprovedAt?.length ?? 0);
    final ok = await _confirm(
      context,
      title: '매장 데이터를 실제로 바꿀까요?',
      body:
          'stores 문서에 status/approvedAt 을 씁니다 (시험 실행 기준 status ${s.setStatusApproved?.length ?? '?'}건, approvedAt ${s.backfillApprovedAt?.length ?? '?'}건, 합 $n건). '
          '되돌리지 않는 작업이에요. 시험 실행의 거절 예정 목록을 전부 확인했나요?',
    );
    if (ok && mounted) await _call(dryRun: false);
  }

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: '③ 매장 승인 메타 정상화 (임시)',
      child: switch (_phase) {
        _Phase.idle => _idle(),
        _Phase.running => _running('서버가 stores 전체를 읽고 있어요. 최대 몇 분 걸려요'),
        _Phase.failed => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_failureView(_error, () => _call(dryRun: true))],
        ),
        _Phase.done => _result(_report!),
      },
    );
  }

  Widget _idle() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'migrateStoreApprovalMeta. 먼저 시험 실행으로 리포트를 보세요. 시험 실행은 아무것도 바꾸지 않아요. 실행은 시험 실행을 본 뒤에만 눌러져요',
        style: _body,
      ),
      const SizedBox(height: 12),
      _button('시험 실행 (dryRun)', () => _call(dryRun: true)),
    ],
  );

  Widget _result(StoreApprovalMigrationReport r) {
    final wasDry = r.dryRun == true;
    final canExecute = _seenDryRun != null && !_seenDryRun!.blocksExecution;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ModeBanner(dryRun: r.dryRun, written: r.written, at: r.receivedAt),
        const SizedBox(height: 8),
        Text('전체 매장 ${r.total ?? '응답에 없음'}', style: _body),
        _ClassRow(
          label: 'setStatusApproved',
          hint: 'status 가 없는 문서에 approved 를 씀',
          count: r.setStatusApproved?.length,
        ),
        _ClassRow(
          label: 'backfillApprovedAt',
          hint: 'approved 인데 approvedAt 이 없는 문서에 채움',
          count: r.backfillApprovedAt?.length,
        ),
        _ClassRow(
          label: 'invalid (무효 status)',
          hint: '있으면 멈추고 보고. 실행도 서버가 거부해요',
          count: r.invalid?.length,
          expectZero: true,
          children: [
            _FullList(
              rows: [
                for (final i in r.invalid ?? const <MigrationInvalidItem>[])
                  SelectableText(
                    '· ${i.id} — status ${i.detail}',
                    style: _body,
                  ),
              ],
            ),
          ],
        ),
        _ClassRow(
          label: 'ⓒ anomalies (이상치)',
          hint: '승인 전인데 approvedAt 이 있고 approvedBy 가 없음. 있으면 멈추고 보고',
          count: r.anomalies?.length,
          expectZero: true,
          children: [
            _FullList(
              rows: [
                for (final id in r.anomalies ?? const <String>[])
                  SelectableText('· $id', style: _body),
              ],
            ),
          ],
        ),
        _ClassRow(
          label: 'ⓔ ambiguousRejected (모호: 반려 + approvedAt)',
          hint: '0건이 아니어도 배포를 막지 않아요. 목록을 남기고 사람이 판단 (④ 가 반드시 배포된다는 전제)',
          count: r.ambiguousRejected?.length,
          children: [
            _FullList(
              rows: [
                for (final s
                    in r.ambiguousRejected ?? const <MigrationStoreRef>[])
                  _storeRow(s.id, s.name),
              ],
            ),
          ],
        ),
        _ClassRow(
          label: 'ⓔ ambiguousSelfRegress (모호: 대기 + 반려사유 + approvedAt)',
          hint: '0건이 아니어도 배포를 막지 않아요. 목록을 남기고 사람이 판단',
          count: r.ambiguousSelfRegress?.length,
          children: [
            _FullList(
              rows: [
                for (final s
                    in r.ambiguousSelfRegress ?? const <MigrationStoreRef>[])
                  _storeRow(s.id, s.name),
              ],
            ),
          ],
        ),
        _ClassRow(
          label: 'ⓓ willBeRejected (거절 예정)',
          hint:
              '백필 후에도 결제 게이트에 막힐 매장 — 목록을 전부 눈으로 확인하세요. 영업 중인 매장이 있으면 멈추고 원인부터 찾아요',
          count: r.willBeRejected?.length,
          children: [
            _FullList(
              rows: [
                for (final s
                    in r.willBeRejected ?? const <MigrationWillBeRejected>[])
                  _storeRow(
                    s.id,
                    s.name,
                    extra:
                        'status ${s.status ?? 'null'} · approvedAt ${s.hasApprovedAt == null ? '?' : (s.hasApprovedAt! ? '있음' : '없음')}',
                  ),
              ],
            ),
          ],
        ),
        if (!wasDry && r.dryRun == false)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              '이제 시험 실행을 다시 해서 setStatusApproved / backfillApprovedAt / invalid / anomalies 가 전부 0 인지 확인하세요',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeading,
              ),
            ),
          ),
        const SizedBox(height: 12),
        _button('시험 실행 (dryRun)', () => _call(dryRun: true)),
        const SizedBox(height: 8),
        _button(
          '실행 (dryRun:false)',
          canExecute ? _execute : null,
          filled: true,
        ),
        if (!canExecute)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _seenDryRun == null
                  ? '실행은 시험 실행을 본 직후에만 눌러져요'
                  : '무효/이상치가 있거나 응답에 없어서 실행할 수 없어요',
              style: _muted,
            ),
          ),
      ],
    );
  }
}

// ───────────────────────── ⑤⑨ 브랜드 private profile ─────────────────────────

class AdminBrandProfileMigrationCard extends ConsumerStatefulWidget {
  const AdminBrandProfileMigrationCard({super.key});

  @override
  ConsumerState<AdminBrandProfileMigrationCard> createState() =>
      _BrandCardState();
}

class _BrandCardState extends ConsumerState<AdminBrandProfileMigrationCard> {
  _Phase _phase = _Phase.idle;
  BrandMigrationStage _stage = BrandMigrationStage.copy;
  BrandProfileMigrationReport? _report;
  BrandMigrationStage? _reportStage;
  BrandProfileMigrationReport? _seenDryRun;
  BrandMigrationStage? _seenStage;
  Object? _error;

  Future<void> _call({required bool dryRun}) async {
    final stage = _stage;
    setState(() => _phase = _Phase.running);
    try {
      final r = await ref.read(runBrandProfileMigrationUseCaseProvider)(
        stage: stage,
        dryRun: dryRun,
      );
      if (!mounted) return;
      setState(() {
        _report = r;
        _reportStage = stage;
        _seenDryRun = dryRun ? r : null;
        _seenStage = dryRun ? stage : null;
        _phase = _Phase.done;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _report = null;
        _seenDryRun = null;
        _seenStage = null;
        _phase = _Phase.failed;
      });
    }
  }

  Future<void> _execute() async {
    if (_seenDryRun == null || _seenStage != _stage) return;
    final copy = _stage == BrandMigrationStage.copy;
    final ok = await _confirm(
      context,
      title: copy ? '브랜드 정보를 private 로 복사할까요?' : '브랜드 부모 문서의 필드를 지울까요?',
      body: copy
          ? 'stage copy (⑤). 부모 필드는 지우지 않고 private/profile 과 brandKeys 를 만듭니다.'
          : 'stage cleanup (⑨). 부모 문서의 brandKey 와 PII 5개 필드를 지웁니다. 되돌릴 수 없어요. '
                '⑧(Rules-B+C) 이후이고 구버전 앱이 없음을 확인했나요?',
    );
    if (ok && mounted) await _call(dryRun: false);
  }

  void _setStage(BrandMigrationStage s) {
    if (s == _stage || _phase == _Phase.running) return;
    setState(() {
      _stage = s;
      // 다른 stage 의 시험 실행/리포트는 이 stage 의 것이 아니다.
      _seenDryRun = null;
      _seenStage = null;
      _report = null;
      _phase = _Phase.idle;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: '⑤⑨ 브랜드 private profile 이동 (임시)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final s in BrandMigrationStage.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      s == BrandMigrationStage.copy
                          ? 'copy (⑤ 복사)'
                          : 'cleanup (⑨ 제거)',
                    ),
                    selected: _stage == s,
                    onSelected: (_) => _setStage(s),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          switch (_phase) {
            _Phase.idle => _idle(),
            _Phase.running => _running('서버가 brands 전체를 읽고 있어요. 최대 몇 분 걸려요'),
            _Phase.failed => _failureView(_error, () => _call(dryRun: true)),
            _Phase.done => _result(_report!),
          },
        ],
      ),
    );
  }

  Widget _idle() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _stage == BrandMigrationStage.copy
            ? 'stage copy (⑤): 부모 필드를 지우지 않고 복사만 해요. 시험 실행은 아무것도 바꾸지 않아요'
            : 'stage cleanup (⑨): 부모의 6개 필드를 지워요. ⑧ 이후, 구버전 앱이 없을 때만. 시험 실행은 아무것도 바꾸지 않아요',
        style: _body,
      ),
      const SizedBox(height: 12),
      _button('시험 실행 (dryRun)', () => _call(dryRun: true)),
    ],
  );

  Widget _result(BrandProfileMigrationReport r) {
    final stage = _reportStage ?? _stage;
    final canExecute =
        _seenDryRun != null &&
        _seenStage == _stage &&
        !_seenDryRun!.blocksExecution;
    final stageMismatch = r.stage != null && r.stage != stage.code;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ModeBanner(dryRun: r.dryRun, written: r.written, at: r.receivedAt),
        const SizedBox(height: 8),
        Text(
          'stage ${r.stage ?? '응답에 없음'} · 전체 브랜드 ${r.total ?? '응답에 없음'}'
          '${stageMismatch ? ' (요청한 stage 와 달라요 — 값을 믿지 마세요)' : ''}',
          style: _body,
        ),
        if (stage == BrandMigrationStage.copy)
          _ClassRow(
            label: 'toCopy',
            hint: 'private/profile 로 복사할 브랜드',
            count: r.toCopy,
          )
        else
          _ClassRow(
            label: 'toClean',
            hint: '부모의 6개 필드를 지울 브랜드 (private 와 값이 같은 것만)',
            count: r.toClean,
          ),
        _ClassRow(
          label: 'invalid (무효)',
          hint: '있으면 멈추고 보고. 실행도 서버가 거부해요',
          count: r.invalid?.length,
          expectZero: true,
          children: [
            _FullList(
              rows: [
                for (final i in r.invalid ?? const <MigrationInvalidItem>[])
                  SelectableText('· ${i.id} — ${i.detail}', style: _body),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        _button('시험 실행 (dryRun)', () => _call(dryRun: true)),
        const SizedBox(height: 8),
        _button(
          '실행 (dryRun:false)',
          canExecute ? _execute : null,
          filled: true,
        ),
        if (!canExecute)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _seenDryRun == null
                  ? '실행은 시험 실행을 본 직후에만 눌러져요'
                  : '무효가 있거나 응답에 없어서 실행할 수 없어요',
              style: _muted,
            ),
          ),
      ],
    );
  }
}

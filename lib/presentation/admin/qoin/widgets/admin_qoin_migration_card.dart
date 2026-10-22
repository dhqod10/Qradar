// TRANSITIONAL(spec §20.4.5): 임시 마이그레이션 카드. 정리 커밋에서 이 파일째 삭제한다.
// 정리 커밋 = 이 파일 삭제 + 허브의 마운트 한 줄 삭제 + 아래 DI provider 와 함께
//   migrate_qoin_zero_rates_use_case / qoin_zero_migration_* (domain·data) / qoin_zero_migration_result 삭제.
// 상태·provider·UseCase 호출을 전부 이 파일 안에 둔다 (공용 위젯·공용 provider 재사용 금지).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/data/datasources/remote/qoin_zero_migration_remote_data_source.dart';
import 'package:qradar/data/repositories/qoin_zero_migration_repository_impl.dart';
import 'package:qradar/domain/entities/qoin_zero_migration_result.dart';
import 'package:qradar/domain/repositories/qoin_zero_migration_repository.dart';
import 'package:qradar/domain/usecases/migrate_qoin_zero_rates_use_case.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_dialog_shell.dart';

final _migrationRepositoryProvider = Provider<QoinZeroMigrationRepository>(
  (ref) => QoinZeroMigrationRepositoryImpl(QoinZeroMigrationRemoteDataSource()),
);

/// 테스트가 대체할 수 있도록 공개한다.
final qoinZeroMigrationUseCaseProvider = Provider<MigrateQoinZeroRatesUseCase>(
  (ref) => MigrateQoinZeroRatesUseCase(ref.watch(_migrationRepositoryProvider)),
);

enum _Phase { idle, checking, checked, checkFailed, running, done, runFailed }

/// 허브 맨 위의 1회성 카드: 대상 확인(dry-run) → 실행 → 결과 (design §18-9).
/// 실행 실패 뒤에는 곧바로 재실행을 주지 않고 반드시 dry-run 으로 돌아가게 한다.
class AdminQoinMigrationCard extends ConsumerStatefulWidget {
  const AdminQoinMigrationCard({super.key});

  /// 무효 값의 원형 표시. 서버(`describeRaw`)는 값의 **JSON 표기**를 보낸다: 문자열 `"3"` · 숫자 `0.5` · `true` · `[1]` · `{}` · `null`
  /// (NaN / Infinity / `(absent)` 는 JSON 이 아니라 그대로). 이미 그 표기이므로 **그대로 보여준다** — 따옴표를 한 번 더 두르면
  /// `true` 가 `"true"` 로 보여 "어떤 타입의 쓰레기 값이 들어 있나" 를 보여주는 `raw` 의 존재 이유가 깨진다.
  /// 어느 형태로도 해석되지 않는 문자열만 따옴표로 감싼다 (방어).
  @visibleForTesting
  static String formatRaw(String? raw) {
    if (raw == null) return 'null';
    if (const {'NaN', 'Infinity', '-Infinity', '(absent)'}.contains(raw)) {
      return raw;
    }
    // 100자에서 잘린 문자열·배열·객체는 JSON 으로 완결되지 않아도 그 표기를 그대로 둔다.
    if (raw.startsWith('"') || raw.startsWith('[') || raw.startsWith('{')) {
      return raw;
    }
    try {
      jsonDecode(raw); // null · true · false · 숫자
      return raw;
    } catch (_) {
      return '"$raw"';
    }
  }

  @override
  ConsumerState<AdminQoinMigrationCard> createState() =>
      _AdminQoinMigrationCardState();
}

class _AdminQoinMigrationCardState
    extends ConsumerState<AdminQoinMigrationCard> {
  _Phase _phase = _Phase.idle;
  QoinZeroMigrationResult? _checked;
  QoinZeroMigrationResult? _done;
  bool _expanded = false;

  Future<void> _check() async {
    setState(() => _phase = _Phase.checking);
    try {
      final r = await ref.read(qoinZeroMigrationUseCaseProvider)(dryRun: true);
      if (!mounted) return;
      setState(() {
        _checked = r;
        _expanded = false;
        _phase = _Phase.checked;
      });
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.checkFailed);
    }
  }

  Future<void> _run() async {
    final c = _checked;
    if (c == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => QoinDialogShell.text(
        title: 'Qoin 설정을 이전할까요?',
        cancelLabel: '취소',
        confirmLabel: '이전 실행',
        content: [
          Text(
            '매장 ${c.zeroStores.length}곳 · 브랜드 ${c.zeroBrands.length}곳의 ‘적립률 0%’ 를 지우고 ‘적립 사용 안 함’ 으로 바꿔요',
            style: QoinDialogShell.bodyStyle,
          ),
          const SizedBox(height: 6),
          const Text('곳마다 변경 이력이 남아요', style: QoinDialogShell.bodyStyle),
          const SizedBox(height: 8),
          const Text(
            '방금 확인한 목록 기준이에요. 그사이 바뀐 곳은 건너뛰어요',
            style: QoinDialogShell.noteStyle,
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _phase = _Phase.running);
    try {
      final r = await ref.read(qoinZeroMigrationUseCaseProvider)(dryRun: false);
      if (!mounted) return;
      setState(() {
        _done = r;
        _phase = _Phase.done;
      });
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.runFailed);
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
                    'Qoin 설정 이전',
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
                    borderRadius: BorderRadius.circular(6),
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
              '예전 방식으로 ‘적립률 0%’ 를 써 둔 매장·브랜드를 ‘적립 사용 안 함’ 으로 옮겨요. 먼저 대상을 확인한 뒤 실행해요',
              style: QoinDialogShell.bodyStyle,
            ),
            const SizedBox(height: 12),
            _outlined('대상 확인하기', _check),
          ],
        );
      case _Phase.checking:
        return const _Busy(title: '대상을 확인하고 있어요');
      case _Phase.running:
        return const _Busy(title: '이전하고 있어요', note: '끝날 때까지 이 화면을 유지해주세요');
      case _Phase.checkFailed:
        return _Failure(
          title: '대상을 확인하지 못했어요',
          note: '잠시 후 다시 시도해주세요',
          action: TextButton(
            onPressed: _check,
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
        );
      case _Phase.runFailed:
        // 실패 후 곧바로 재실행하지 않는다 — 실제 상태를 모른 채 같은 실행을 되풀이하지 않는다.
        return _Failure(
          title: '이전 결과를 확인하지 못했어요',
          note: '이미 일부가 옮겨졌을 수 있어요. 대상을 다시 확인해 주세요',
          action: _outlined('대상 다시 확인하기', _check),
        );
      case _Phase.checked:
        return _checkedView(_checked!);
      case _Phase.done:
        return _doneView(_done!);
    }
  }

  Widget _outlined(String label, VoidCallback onTap) => SizedBox(
    height: 44,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _checkedView(QoinZeroMigrationResult r) {
    if (r.zeroCount == 0 && r.invalidCount == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Text(
                '이전할 대상이 없어요',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHeading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('0% 로 설정된 매장·브랜드가 없어요', style: QoinDialogShell.noteStyle),
          const SizedBox(height: 12),
          _outlined('다시 확인', _check),
        ],
      );
    }

    final lines = <String>[
      for (final s in r.zeroStores) '· ${s.name}',
      for (final b in r.zeroBrands) '· 브랜드 ${b.name}',
    ];
    final shown = _expanded ? lines : lines.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('0% 로 설정된 곳', style: QoinDialogShell.noteStyle),
        const SizedBox(height: 2),
        Text(
          '매장 ${r.zeroStores.length}곳 · 브랜드 ${r.zeroBrands.length}곳',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textHeading,
          ),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final l in shown)
                  Text(l, style: QoinDialogShell.bodyStyle),
              ],
            ),
          ),
        ),
        if (lines.length > 5 && !_expanded)
          TextButton(
            onPressed: () => setState(() => _expanded = true),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text(
              '전체 목록 보기 ▾',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        if (r.invalidCount > 0) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '확인이 필요한 값 ${r.invalidCount}곳',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBody,
                  ),
                ),
                const SizedBox(height: 4),
                for (final t in r.invalidStores)
                  Text(
                    '· ${t.name}  값 ${AdminQoinMigrationCard.formatRaw(t.raw)}',
                    style: QoinDialogShell.bodyStyle,
                  ),
                for (final t in r.invalidBrands)
                  Text(
                    '· 브랜드 ${t.name}  값 ${AdminQoinMigrationCard.formatRaw(t.raw)}',
                    style: QoinDialogShell.bodyStyle,
                  ),
                const SizedBox(height: 4),
                const Text(
                  '이 값은 자동으로 바꾸지 않아요. 각 매장·브랜드 화면에서 직접 정해주세요',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textBody,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (r.zeroCount > 0)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _run,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '이전 실행',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onPrimary,
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        _outlined('다시 확인', _check),
      ],
    );
  }

  Widget _doneView(QoinZeroMigrationResult r) {
    final expected = _checked?.zeroCount;
    final mismatch = expected != null && r.migrated + r.skipped != expected;
    return Semantics(
      label: '이전을 마쳤어요. 옮긴 곳 ${r.migrated}곳, 건너뛴 곳 ${r.skipped}곳',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primaryBright.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primaryBright.withValues(alpha: 0.30),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                SizedBox(width: 6),
                Text(
                  '이전을 마쳤어요',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBody,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('옮긴 곳 ${r.migrated}곳', style: QoinDialogShell.bodyStyle),
            if (r.skipped > 0) ...[
              Text('건너뛴 곳 ${r.skipped}곳', style: QoinDialogShell.bodyStyle),
              const Text('이미 옮겨진 곳은 건너뛰어요', style: QoinDialogShell.noteStyle),
            ],
            if (mismatch)
              const Text(
                '확인했던 수와 달라요. 다시 확인해 주세요',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBody,
                ),
              ),
            const SizedBox(height: 8),
            _outlined('다시 확인', _check),
            const SizedBox(height: 8),
            const Text(
              '‘다시 확인’ 에서 대상이 없다고 나오면 이 카드는 이후 업데이트에서 사라져요',
              style: QoinDialogShell.noteStyle,
            ),
          ],
        ),
      ),
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy({required this.title, this.note});
  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: title,
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textBody,
                  ),
                ),
                if (note != null) Text(note!, style: QoinDialogShell.noteStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({
    required this.title,
    required this.note,
    required this.action,
  });
  final String title;
  final String note;
  final Widget action;

  @override
  Widget build(BuildContext context) {
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
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBody,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(note, style: QoinDialogShell.noteStyle),
        const SizedBox(height: 8),
        action,
      ],
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_results.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/domain/repositories/qoin_rate_repository.dart';
import 'package:qradar/domain/usecases/apply_brand_qoin_rate_use_case.dart';
import 'package:qradar/domain/usecases/set_qoin_accrual_rate_use_case.dart';

class _Call {
  _Call(this.scope, this.targetId, this.rate, this.clear, this.reason);
  final QoinRateScope scope;
  final String? targetId;
  final double? rate;
  final bool clear;
  final String? reason;
}

class _FakeRepo implements QoinRateRepository {
  final List<_Call> sets = [];
  final List<Map<String, Object?>> applies = [];

  @override
  Future<QoinRateSetResult> setRate({
    required QoinRateScope scope,
    String? targetId,
    double? rate,
    bool clear = false,
    String? reason,
  }) async {
    sets.add(_Call(scope, targetId, rate, clear, reason));
    return const QoinRateSetResult(before: null, after: null, changed: true);
  }

  @override
  Future<QoinBulkApplyResult> applyBrandRate({
    required String brandId,
    double? rate,
    bool clear = false,
    required QoinBulkMode mode,
    String? reason,
    String? resumeHistoryId,
  }) async {
    applies.add({
      'brandId': brandId,
      'rate': rate,
      'clear': clear,
      'mode': mode,
      'reason': reason,
      'resume': resumeHistoryId,
    });
    return const QoinBulkApplyResult(
      changed: true,
      status: QoinBulkStatus.completed,
      affectedCount: 0,
      clearedCount: 0,
      preservedCount: 0,
      processedCount: 0,
      totalCount: 0,
    );
  }

  @override
  Stream<List<QoinRateChangeEntity>> watchHistory(
    QoinRateScope scope,
    String targetId, {
    required int limit,
  }) => const Stream.empty();

  @override
  Stream<List<QoinRateChangeEntity>> watchAllHistory({required int limit}) =>
      const Stream.empty();
}

void main() {
  group('SetQoinAccrualRateUseCase — 화면 우회 방어', () {
    late _FakeRepo repo;
    late SetQoinAccrualRateUseCase uc;
    setUp(() {
      repo = _FakeRepo();
      uc = SetQoinAccrualRateUseCase(repo);
    });

    test('tenths 30 -> 0.03 으로 변환해 전달', () async {
      await uc(
        scope: QoinRateScope.store,
        targetId: 's1',
        value: const QoinRateValue.rate(30),
      );
      expect(repo.sets.single.rate, 0.03);
      expect(repo.sets.single.clear, isFalse);
    });

    test('범위 밖 tenths (0, 201, -1) -> ArgumentError, 서버 호출 없음', () {
      for (final t in [0, 201, -1, 1000]) {
        expect(
          () => uc(
            scope: QoinRateScope.store,
            targetId: 's1',
            value: QoinRateValue.rate(t),
          ),
          throwsArgumentError,
          reason: 'tenths=$t',
        );
      }
      expect(repo.sets, isEmpty);
    });

    test('경계 1 / 200 은 통과', () async {
      await uc(
        scope: QoinRateScope.brand,
        targetId: 'b1',
        value: const QoinRateValue.rate(1),
      );
      await uc(
        scope: QoinRateScope.brand,
        targetId: 'b1',
        value: const QoinRateValue.rate(200),
      );
      expect(repo.sets.map((c) => c.rate), [0.001, 0.2]);
    });

    test('stop -> rate 0, inherit -> clear', () async {
      await uc(
        scope: QoinRateScope.store,
        targetId: 's1',
        value: const QoinRateValue.stop(),
      );
      await uc(
        scope: QoinRateScope.store,
        targetId: 's1',
        value: const QoinRateValue.inherit(),
      );
      expect(repo.sets[0].rate, 0);
      expect(repo.sets[1].clear, isTrue);
      expect(repo.sets[1].rate, isNull);
    });

    test('전역은 stop / inherit 불가 (항상 유효한 숫자)', () {
      expect(
        () =>
            uc(scope: QoinRateScope.global, value: const QoinRateValue.stop()),
        throwsArgumentError,
      );
      expect(
        () => uc(
          scope: QoinRateScope.global,
          value: const QoinRateValue.inherit(),
        ),
        throwsArgumentError,
      );
      expect(repo.sets, isEmpty);
    });

    test('전역은 targetId 불필요 / 브랜드·매장은 필요', () async {
      await uc(
        scope: QoinRateScope.global,
        value: const QoinRateValue.rate(30),
      );
      expect(repo.sets.single.targetId, isNull);
      expect(
        () =>
            uc(scope: QoinRateScope.store, value: const QoinRateValue.rate(30)),
        throwsArgumentError,
      );
      expect(
        () => uc(
          scope: QoinRateScope.brand,
          targetId: '',
          value: const QoinRateValue.rate(30),
        ),
        throwsArgumentError,
      );
    });

    test('사유: trim, 빈 문자열 -> null, 201자 -> ArgumentError', () async {
      await uc(
        scope: QoinRateScope.global,
        value: const QoinRateValue.rate(30),
        reason: '  프로모션 ',
      );
      await uc(
        scope: QoinRateScope.global,
        value: const QoinRateValue.rate(30),
        reason: '   ',
      );
      expect(repo.sets[0].reason, '프로모션');
      expect(repo.sets[1].reason, isNull);
      expect(
        () => uc(
          scope: QoinRateScope.global,
          value: const QoinRateValue.rate(30),
          reason: 'x' * 201,
        ),
        throwsArgumentError,
      );
      await uc(
        scope: QoinRateScope.global,
        value: const QoinRateValue.rate(30),
        reason: 'x' * 200,
      );
    });
  });

  group('ApplyBrandQoinRateUseCase', () {
    late _FakeRepo repo;
    late ApplyBrandQoinRateUseCase uc;
    setUp(() {
      repo = _FakeRepo();
      uc = ApplyBrandQoinRateUseCase(repo);
    });

    test('rate / stop / inherit 변환', () async {
      await uc(
        brandId: 'b',
        value: const QoinRateValue.rate(50),
        mode: QoinBulkMode.preserve,
      );
      await uc(
        brandId: 'b',
        value: const QoinRateValue.stop(),
        mode: QoinBulkMode.overwrite,
      );
      await uc(
        brandId: 'b',
        value: const QoinRateValue.inherit(),
        mode: QoinBulkMode.overwrite,
      );
      expect(repo.applies[0]['rate'], 0.05);
      expect(repo.applies[1]['rate'], 0);
      expect(repo.applies[2]['clear'], isTrue);
    });

    test('범위 밖 -> ArgumentError', () {
      expect(
        () => uc(
          brandId: 'b',
          value: const QoinRateValue.rate(201),
          mode: QoinBulkMode.preserve,
        ),
        throwsArgumentError,
      );
      expect(
        () => uc(brandId: 'b', mode: QoinBulkMode.preserve),
        throwsArgumentError,
      );
      expect(
        () => uc(
          brandId: '',
          value: const QoinRateValue.rate(50),
          mode: QoinBulkMode.preserve,
        ),
        throwsArgumentError,
      );
      expect(repo.applies, isEmpty);
    });

    test('재개는 값을 보내지 않고 overwrite 만 허용', () async {
      await uc(
        brandId: 'b',
        mode: QoinBulkMode.overwrite,
        resumeHistoryId: 'h1',
      );
      expect(repo.applies.single['resume'], 'h1');
      expect(repo.applies.single['rate'], isNull);
      expect(repo.applies.single['clear'], isFalse);
      expect(
        () => uc(
          brandId: 'b',
          mode: QoinBulkMode.preserve,
          resumeHistoryId: 'h1',
        ),
        throwsArgumentError,
      );
    });
  });
}

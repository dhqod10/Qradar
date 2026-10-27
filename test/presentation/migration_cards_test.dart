// TEMP_MIGRATION_CARD — 임시 카드의 테스트. 배포 ⑪ 정리 커밋에서 카드와 함께 삭제한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/migration_remote_data_source.dart';
import 'package:qradar/domain/entities/migration_call_exception.dart';
import 'package:qradar/domain/entities/migration_report.dart';
import 'package:qradar/domain/repositories/migration_repository.dart';
import 'package:qradar/domain/usecases/run_migration_use_cases.dart';
import 'package:qradar/presentation/admin/widgets/admin_migration_cards.dart';

class _Repo implements MigrationRepository {
  final calls = <String>[];
  Object? error;
  Map<String, dynamic> storeResp = {};
  Map<String, dynamic> brandResp = {};

  @override
  Future<StoreApprovalMigrationReport> migrateStoreApprovalMeta({
    required bool dryRun,
  }) async {
    calls.add('store:$dryRun');
    if (error != null) throw error!;
    return MigrationRemoteDataSource.parseStore({
      ...storeResp,
      'dryRun': dryRun,
    });
  }

  @override
  Future<BrandProfileMigrationReport> migrateBrandPrivateProfile({
    required BrandMigrationStage stage,
    required bool dryRun,
  }) async {
    calls.add('brand:${stage.code}:$dryRun');
    if (error != null) throw error!;
    return MigrationRemoteDataSource.parseBrand({
      ...brandResp,
      'stage': stage.code,
      'dryRun': dryRun,
    });
  }
}

Map<String, dynamic> _store({
  List<Map<String, dynamic>> willBe = const [],
  List<String> anomalies = const [],
}) => {
  'total': 40,
  'setStatusApproved': ['a', 'b'],
  'backfillApprovedAt': ['a'],
  'invalid': [],
  'anomalies': anomalies,
  'ambiguousRejected': [],
  'ambiguousSelfRegress': [],
  'willBeRejected': willBe,
};

void main() {
  group('파서', () {
    test('없는 분류는 null, 빈 분류는 0건 — 구분된다', () {
      final r = MigrationRemoteDataSource.parseStore({
        'total': 1,
        'anomalies': [],
      });
      expect(r.anomalies, isEmpty);
      expect(r.invalid, isNull);
      expect(r.willBeRejected, isNull);
      expect(r.blocksExecution, isTrue, reason: '분류가 없으면 실행하지 않는다');
    });
    test('깨진 항목은 건너뛰지 않고 형식 오류다', () {
      expect(
        () => MigrationRemoteDataSource.parseStore({
          'willBeRejected': ['broken'],
        }),
        throwsA(isA<MigrationCallException>()),
      );
    });
    test('오류 코드 분류 + failed-precondition details', () {
      MigrationCallFailure k(String c) =>
          MigrationRemoteDataSource.classifyError(c, null, brand: false).kind;
      expect(k('permission-denied'), MigrationCallFailure.permissionDenied);
      expect(k('unauthenticated'), MigrationCallFailure.permissionDenied);
      expect(k('deadline-exceeded'), MigrationCallFailure.timeout);
      expect(k('unavailable'), MigrationCallFailure.network);
      expect(k('internal'), MigrationCallFailure.failed);
      final e = MigrationRemoteDataSource.classifyError('failed-precondition', {
        'anomalies': ['s1'],
        'invalid': [
          {'id': 's2', 'status': 'weird'},
        ],
      }, brand: false);
      expect(e.kind, MigrationCallFailure.stoppedByServer);
      expect(e.anomalies, ['s1']);
      expect(e.invalid!.single.detail, 'weird');
    });
  });

  group('임시 마이그레이션 카드', () {
    late _Repo repo;
    setUp(() => repo = _Repo());

    Widget host() => ProviderScope(
      overrides: [
        runStoreApprovalMigrationUseCaseProvider.overrideWithValue(
          RunStoreApprovalMigrationUseCase(repo),
        ),
        runBrandProfileMigrationUseCaseProvider.overrideWithValue(
          RunBrandProfileMigrationUseCase(repo),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                AdminStoreApprovalMigrationCard(),
                AdminBrandProfileMigrationCard(),
              ],
            ),
          ),
        ),
      ),
    );

    void big(WidgetTester t) {
      t.view.physicalSize = const Size(800, 9000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
    }

    Future<void> dryStore(WidgetTester t) async {
      await t.tap(find.text('시험 실행 (dryRun)').first);
      await t.pumpAndSettle();
    }

    testWidgets('처음에는 실행 버튼이 없고 시험 실행만 있다', (t) async {
      big(t);
      await t.pumpWidget(host());
      expect(find.text('실행 (dryRun:false)'), findsNothing);
      expect(find.text('시험 실행 (dryRun)'), findsNWidgets(2));
      expect(repo.calls, isEmpty);
    });

    testWidgets('시험 실행: 모든 분류 행이 보이고, 0건도 숨기지 않으며, willBeRejected 는 전부 나열', (
      t,
    ) async {
      big(t);
      repo.storeResp = _store(
        willBe: [
          for (var i = 0; i < 30; i++)
            {
              'id': 'id$i',
              'name': '매장$i',
              'status': 'pending',
              'hasApprovedAt': false,
            },
        ],
      );
      await t.pumpWidget(host());
      await dryStore(t);
      expect(repo.calls, ['store:true']);
      expect(find.textContaining('시험 실행 결과'), findsOneWidget);
      for (final l in [
        'setStatusApproved',
        'backfillApprovedAt',
        'invalid (무효 status)',
        'ⓒ anomalies (이상치)',
        'ⓔ ambiguousRejected (모호: 반려 + approvedAt)',
        'ⓔ ambiguousSelfRegress (모호: 대기 + 반려사유 + approvedAt)',
        'ⓓ willBeRejected (거절 예정)',
      ]) {
        expect(find.text(l), findsOneWidget, reason: l);
      }
      expect(find.text('0건'), findsNWidgets(4));
      expect(find.text('30건'), findsOneWidget);
      // 잘라내지 않는다: 마지막 항목까지 위젯 트리에 있다.
      expect(find.text('· 매장29', skipOffstage: false), findsOneWidget);
      expect(find.text('ID id29', skipOffstage: false), findsOneWidget);
      expect(find.text('응답에 없음'), findsNothing);
    });

    testWidgets('응답에 분류가 없으면 0건이 아니라 "응답에 없음", 실행은 막힌다', (t) async {
      big(t);
      repo.storeResp = {
        'total': 3,
        'setStatusApproved': [],
        'backfillApprovedAt': [],
        'anomalies': [],
      };
      await t.pumpWidget(host());
      await dryStore(t);
      expect(find.text('응답에 없음'), findsNWidgets(4));
      final run = find.widgetWithText(FilledButton, '실행 (dryRun:false)');
      expect(t.widget<FilledButton>(run).onPressed, isNull);
    });

    testWidgets('이상치가 있으면 실행 비활성', (t) async {
      big(t);
      repo.storeResp = _store(anomalies: ['s9']);
      await t.pumpWidget(host());
      await dryStore(t);
      final run = find.widgetWithText(FilledButton, '실행 (dryRun:false)');
      expect(t.widget<FilledButton>(run).onPressed, isNull);
      expect(find.text('· s9'), findsOneWidget);
    });

    testWidgets('실행: 확인 다이얼로그를 거치고 취소하면 호출 없음, 실행 후 시험 실행 결과를 버린다', (t) async {
      big(t);
      repo.storeResp = _store();
      await t.pumpWidget(host());
      await dryStore(t);
      final run = find.widgetWithText(FilledButton, '실행 (dryRun:false)');
      await t.tap(run);
      await t.pumpAndSettle();
      expect(find.text('매장 데이터를 실제로 바꿀까요?'), findsOneWidget);
      await t.tap(find.text('취소'));
      await t.pumpAndSettle();
      expect(repo.calls, ['store:true']);

      await t.tap(run);
      await t.pumpAndSettle();
      await t.tap(find.text('실행').last);
      await t.pumpAndSettle();
      expect(repo.calls, ['store:true', 'store:false']);
      expect(find.textContaining('실행 완료'), findsOneWidget);
      expect(t.widget<FilledButton>(run).onPressed, isNull);
    });

    testWidgets('실패 4종은 각각 다른 문구이고 건수 행을 그리지 않는다', (t) async {
      big(t);
      final cases = {
        MigrationCallFailure.permissionDenied: '권한이 없어요',
        MigrationCallFailure.timeout: '응답을 기다리다 시간이 지났어요',
        MigrationCallFailure.network: '서버에 닿지 못했어요',
        MigrationCallFailure.malformedResponse: '응답 형식을 알아볼 수 없어요',
      };
      for (final e in cases.entries) {
        repo.error = MigrationCallException(e.key);
        await t.pumpWidget(host());
        await dryStore(t);
        expect(find.text(e.value), findsOneWidget, reason: e.key.name);
        expect(find.textContaining('0건'), findsNothing);
        expect(find.text('setStatusApproved'), findsNothing);
        await t.pumpWidget(const SizedBox());
      }
    });

    testWidgets('서버가 멈춘 경우 details 목록을 보여준다', (t) async {
      big(t);
      repo.error = const MigrationCallException(
        MigrationCallFailure.stoppedByServer,
        anomalies: ['s1'],
        invalid: [MigrationInvalidItem('s2', 'weird')],
      );
      await t.pumpWidget(host());
      await dryStore(t);
      expect(find.text('서버가 이상치를 이유로 실행을 멈췄어요'), findsOneWidget);
      expect(find.text('· s1'), findsOneWidget);
      expect(find.text('· s2 — weird'), findsOneWidget);
    });

    testWidgets('브랜드: stage 별 행, stage 를 바꾸면 시험 실행이 무효', (t) async {
      big(t);
      repo.brandResp = {'total': 5, 'toCopy': 2, 'toClean': 0, 'invalid': []};
      await t.pumpWidget(host());
      await t.tap(find.text('시험 실행 (dryRun)').last);
      await t.pumpAndSettle();
      expect(repo.calls, ['brand:copy:true']);
      expect(find.text('toCopy'), findsOneWidget);
      expect(find.text('invalid (무효)'), findsOneWidget);
      expect(find.text('2건'), findsOneWidget);
      final run = find.widgetWithText(FilledButton, '실행 (dryRun:false)');
      expect(t.widget<FilledButton>(run).onPressed, isNotNull);

      await t.tap(find.text('cleanup (⑨ 제거)'));
      await t.pumpAndSettle();
      expect(
        find.widgetWithText(FilledButton, '실행 (dryRun:false)'),
        findsNothing,
      );
      expect(find.textContaining('부모의 6개 필드를 지워요'), findsOneWidget);
    });
  });
}

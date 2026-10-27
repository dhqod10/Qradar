// TEMP_PRICE_AUDIT_CARD — 임시 감사 카드의 테스트. 배포 ⑩ 정리 커밋에서 카드와 함께 삭제한다.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/price_audit_remote_data_source.dart';
import 'package:qradar/domain/entities/migration_call_exception.dart';
import 'package:qradar/domain/entities/price_audit_report.dart';
import 'package:qradar/domain/repositories/price_audit_repository.dart';
import 'package:qradar/domain/usecases/run_price_audit_use_case.dart';
import 'package:qradar/presentation/admin/widgets/admin_price_audit_card.dart';

class _Repo implements PriceAuditRepository {
  int calls = 0;
  Object? error;
  Map<String, dynamic> resp = {};
  Completer<void>? gate;

  @override
  Future<PriceAuditReport> audit() async {
    calls++;
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return PriceAuditRemoteDataSource.parse(resp);
  }
}

Map<String, dynamic> _clean() => {
  'window': {
    'from': '1970-01-01T00:00:00.000Z',
    'to': '2026-10-28T00:00:00.000Z',
    'limit': 20000,
  },
  'orders': {
    'scanned': 320,
    'violationCount': 0,
    'byCheck': {
      'lineMath': 0,
      'subtotalSum': 0,
      'totalEqSubtotal': 0,
      'amountEqTotal': 0,
    },
    'violations': [],
    'truncated': false,
  },
  'selfApprovedOverrides': {
    'scanned': 12,
    'count': 0,
    'opsOnlyApproved': 3,
    'items': [],
  },
  'storeScopeRefs': {
    'brandsWithFranchise': 2,
    'count': 4,
    'storePairs': 9,
    'items': [
      {
        'brandId': 'b1',
        'menuItemId': 'm1',
        'groupId': 'g1',
        'franchiseStores': 3,
      },
    ],
  },
};

void main() {
  group('파서', () {
    test('없는 분류는 null, 빈 분류는 0건 — 구분된다', () {
      final r = PriceAuditRemoteDataSource.parse({
        'orders': {'scanned': 1, 'violationCount': 0},
      });
      expect(r.ordersViolationCount, 0);
      expect(r.selfApprovedCount, isNull);
      expect(r.refCount, isNull);
      expect(r.blocksEnforce, isTrue, reason: '분류가 없으면 enforce 로 넘어가지 않는다');
    });
    test('깨진 항목은 건너뛰지 않고 형식 오류다', () {
      expect(
        () => PriceAuditRemoteDataSource.parse({
          'orders': {
            'violations': ['broken'],
          },
        }),
        throwsA(isA<MigrationCallException>()),
      );
    });
    test('기준선 판정: 위반 0 + self-approved 0 이면 통과, 하나라도 있으면 막는다', () {
      expect(PriceAuditRemoteDataSource.parse(_clean()).blocksEnforce, isFalse);
      final bad = _clean();
      (bad['orders'] as Map)['violationCount'] = 1;
      expect(PriceAuditRemoteDataSource.parse(bad).blocksEnforce, isTrue);
      final bad2 = _clean();
      (bad2['selfApprovedOverrides'] as Map)['count'] = 2;
      expect(PriceAuditRemoteDataSource.parse(bad2).blocksEnforce, isTrue);
    });
  });

  group('카드', () {
    late _Repo repo;
    setUp(() => repo = _Repo());
    Widget host() => ProviderScope(
      overrides: [
        runPriceAuditUseCaseProvider.overrideWithValue(
          RunPriceAuditUseCase(repo),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: AdminPriceAuditCard()),
        ),
      ),
    );

    testWidgets('쓰기 버튼이 없다: 측정 실행 버튼 하나뿐 (읽기 전용)', (tester) async {
      await tester.pumpWidget(host());
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('측정 실행'), findsOneWidget);
    });

    testWidgets('세 분류를 0건이어도 항상 그린다', (tester) async {
      repo.resp = _clean();
      await tester.pumpWidget(host());
      await tester.tap(find.text('측정 실행'));
      await tester.pumpAndSettle();
      expect(find.text('ⓐ 주문 금액 정합성 위반'), findsOneWidget);
      expect(find.text('ⓑ 점주가 직접 승인한 가격 오버라이드'), findsOneWidget);
      expect(find.text('ⓒ 브랜드 메뉴 → 가맹점 옵션 그룹 참조'), findsOneWidget);
      expect(find.text('0건'), findsNWidgets(2));
      expect(find.text('4건'), findsOneWidget);
      expect(find.textContaining('enforce 로 넘어가지 않습니다'), findsNothing);
    });

    testWidgets('위반이 있으면 목록과 중단 배너를 그린다', (tester) async {
      final d = _clean();
      d['orders'] = {
        'scanned': 10,
        'violationCount': 1,
        'truncated': false,
        'byCheck': {
          'lineMath': 0,
          'subtotalSum': 1,
          'totalEqSubtotal': 0,
          'amountEqTotal': 0,
        },
        'violations': [
          {
            'orderId': 'o1',
            'storeId': 's1',
            'failed': ['subtotalSum'],
            'malformed': false,
            'clientSubtotal': 1,
            'sumOfLineTotals': 17000,
            'amount': 1,
          },
        ],
      };
      repo.resp = d;
      await tester.pumpWidget(host());
      await tester.tap(find.text('측정 실행'));
      await tester.pumpAndSettle();
      expect(find.textContaining('enforce 로 넘어가지 않습니다'), findsOneWidget);
      expect(find.text('1건'), findsOneWidget);
      expect(
        find.textContaining('subtotalSum · 소계 1 · 라인합 17000 · 승인액 1'),
        findsOneWidget,
      );
    });

    testWidgets('응답에 분류가 없으면 "응답에 없음" (0건과 다르다)', (tester) async {
      repo.resp = {
        'orders': {'scanned': 1, 'violationCount': 0},
      };
      await tester.pumpWidget(host());
      await tester.tap(find.text('측정 실행'));
      await tester.pumpAndSettle();
      expect(find.text('응답에 없음'), findsNWidgets(2));
    });

    for (final k in MigrationCallFailure.values) {
      testWidgets('실패 ${k.name}: 건수 영역 없이 종류별 문구만, 서버 문자열 보간 없음', (
        tester,
      ) async {
        repo.error = MigrationCallException(k, code: 'SECRET-CODE');
        await tester.pumpWidget(host());
        await tester.tap(find.text('측정 실행'));
        await tester.pumpAndSettle();
        expect(find.text('ⓐ 주문 금액 정합성 위반'), findsNothing);
        expect(find.textContaining('SECRET-CODE'), findsNothing);
        expect(find.textContaining('요'), findsWidgets, reason: '실패 문구는 그려진다');
      });
    }

    testWidgets('측정 중에는 버튼이 막혀 중복 호출이 없다', (tester) async {
      repo.resp = _clean();
      repo.gate = Completer<void>();
      await tester.pumpWidget(host());
      await tester.tap(find.text('측정 실행'));
      await tester.pump();
      final b = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(b.onPressed, isNull);
      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(repo.calls, 1);
    });
  });
}

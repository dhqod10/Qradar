import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/brand_link_audit_remote_data_source.dart';
import 'package:qradar/domain/entities/brand_link_audit_result.dart';
import 'package:qradar/domain/repositories/brand_link_audit_repository.dart';
import 'package:qradar/domain/usecases/audit_brand_links_use_case.dart';
import 'package:qradar/presentation/admin/widgets/admin_brand_link_audit_card.dart';


class _Repo implements BrandLinkAuditRepository {
  int calls = 0;
  Object? error;
  late BrandLinkAuditResult result;

  @override
  Future<BrandLinkAuditResult> audit() async {
    calls++;
    if (error != null) throw error!;
    return result;
  }
}

Map<String, dynamic> _resp({
  Map<String, int> counts = const {},
  Map<String, List<Map<String, dynamic>>> items = const {},
  Set<String> truncated = const {},
}) => {
  'counts': {
    for (final c in BrandLinkClass.values) c.code: counts[c.code] ?? 0,
  },
  'items': {for (final e in items.entries) e.key: e.value},
  'truncated': {
    for (final c in BrandLinkClass.values) c.code: truncated.contains(c.code),
  },
};

void main() {
  group('auditBrandLinks 응답 파서', () {
    test('8분류 건수는 0 도 보존하고, 모르는 분류·깨진 항목은 건너뛴다', () {
      final r = BrandLinkAuditRemoteDataSource.parse({
        'counts': {'dangling': 1, 'ok': 12, 'something_new': 9},
        'items': {
          'dangling': [
            {'uid': 'u1', 'email': 'a@b.com', 'brandId': 'b1'},
            'broken',
          ],
          'something_new': [
            {'uid': 'x'},
          ],
        },
        'truncated': {'dangling': true},
      });
      expect(r.count(BrandLinkClass.dangling), 1);
      expect(r.count(BrandLinkClass.duplicate), 0);
      expect(r.count(BrandLinkClass.ok), 12);
      expect(r.itemsOf(BrandLinkClass.dangling).single.uid, 'u1');
      expect(r.truncated, {BrandLinkClass.dangling});
      expect(BrandLinkClass.values.length, 8);
    });
    test('빈 응답도 예외 없이 전부 0', () {
      final r = BrandLinkAuditRemoteDataSource.parse({});
      expect(r.allClear, isTrue);
      expect(BrandLinkClass.values.map(r.count), everyElement(0));
    });
  });

  group('브랜드 링크 점검 카드', () {
    late _Repo repo;
    setUp(() => repo = _Repo());

    Widget host() => ProviderScope(
      overrides: [
        auditBrandLinksUseCaseProvider.overrideWithValue(
          AuditBrandLinksUseCase(repo),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: AdminBrandLinkAuditCard()),
        ),
      ),
    );

    void big(WidgetTester t) {
      t.view.physicalSize = const Size(800, 4000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
    }

    testWidgets('idle: 읽기만 한다는 설명 + 점검하기 외에 교정/삭제/정리 버튼이 없다', (t) async {
      big(t);
      await t.pumpWidget(host());
      expect(find.text('브랜드 링크 점검'), findsOneWidget);
      expect(find.text('임시'), findsNothing, reason: '상시 도구로 승격');
      expect(find.textContaining('읽기만 하고 아무것도 바꾸지 않아요'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.text('점검하기'), findsOneWidget);
      for (final w in ['교정', '삭제', '자동 정리', '의심', '공격', '사칭']) {
        expect(find.textContaining(w), findsNothing, reason: w);
      }
    });

    testWidgets('결과: 건수는 0 도 보여주고, 분류별 목록은 5건까지 + 전체 보기, 호출은 1회', (t) async {
      big(t);
      repo.result = BrandLinkAuditRemoteDataSource.parse(
        _resp(
          counts: {
            'dangling': 1,
            'duplicate': 2,
            'mismatch': 1,
            'orphan_brand': 7,
            'ok': 12,
            'ok_onboarding': 3,
          },
          items: {
            'dangling': [
              {'uid': 'u9f1', 'email': 'a@b.com', 'brandId': 'abc123'},
            ],
            'duplicate': [
              {'uid': 'd1', 'brandId': 'dupB', 'brandName': '중복브랜드'},
              {'uid': 'd2', 'brandId': 'dupB', 'brandName': '중복브랜드'},
            ],
            'mismatch': [
              {'uid': 'm1', 'brandId': 'mB', 'submittedBy': 'someoneElse'},
            ],
            'orphan_brand': [
              for (var i = 0; i < 7; i++)
                {'brandId': 'o$i', 'brandName': '고아$i', 'status': 'pending'},
            ],
          },
        ),
        now: DateTime(2026, 10, 22, 14, 35),
      );
      await t.pumpWidget(host());
      await t.tap(find.text('점검하기'));
      await t.pumpAndSettle();
      expect(repo.calls, 1);
      expect(find.text('10월 22일 14:35'), findsOneWidget);
      expect(find.text('바로 교정이 필요한 곳 3곳'), findsOneWidget);
      // 8개 분류 중 정상/등록 전을 뺀 6개 건수는 0 도 숨기지 않는다.
      expect(
        find.text(
          '연결 끊김 1 · 중복 연결 2 · 매장의 브랜드 없음 0 · 매장의 브랜드 미승인 0 · 제출자 불일치 1 · 고아 브랜드 7',
        ),
        findsOneWidget,
      );
      expect(find.text('정상 12 · 등록 전 3'), findsOneWidget);
      expect(find.text('연결 끊김 1곳'), findsOneWidget);
      expect(find.text('고아 브랜드 7곳'), findsOneWidget);
      expect(find.text('· 고아4'), findsOneWidget);
      expect(find.text('· 고아5'), findsNothing, reason: '5건까지만 먼저 보인다');
      await t.ensureVisible(find.text('전체 보기'));
      await t.tap(find.text('전체 보기'));
      await t.pumpAndSettle();
      expect(find.text('· 고아6'), findsOneWidget);
      // 조치 안내는 문장일 뿐 탭 타깃이 아니다.
      expect(
        find.textContaining('Console 에서 users/{uid} 의 brandId 를 삭제하세요'),
        findsOneWidget,
      );
      expect(find.textContaining('직접 발급한 계정이면 그대로 두세요'), findsOneWidget);
      // 어떤 분류 라벨에도 공격/사칭 어휘가 없다 (mismatch 는 공격 증거가 아니다).
      for (final w in ['의심', '공격', '사칭']) {
        expect(find.textContaining(w), findsNothing, reason: w);
      }
      // 다시 점검 -> 호출 2회 (쓰기 경로는 없다)
      await t.ensureVisible(find.text('다시 점검'));
      await t.tap(find.text('다시 점검'));
      await t.pumpAndSettle();
      expect(repo.calls, 2);
    });

    testWidgets('전부 0: "연결 문제가 없어요". 판단 필요 항목이 있으면 이 문구를 쓰지 않는다', (
      t,
    ) async {
      big(t);
      repo.result = BrandLinkAuditRemoteDataSource.parse(
        _resp(counts: {'ok': 2}),
      );
      await t.pumpWidget(host());
      await t.tap(find.text('점검하기'));
      await t.pumpAndSettle();
      expect(find.text('연결 문제가 없어요'), findsOneWidget);
      expect(find.textContaining('사라져요'), findsNothing, reason: '상시 도구 — 사라진다고 말하지 않는다');

      repo.result = BrandLinkAuditRemoteDataSource.parse(
        _resp(
          counts: {'orphan_brand': 1},
          items: {
            'orphan_brand': [
              {'brandId': 'o', 'brandName': 'x'},
            ],
          },
        ),
      );
      await t.tap(find.text('다시 점검'));
      await t.pumpAndSettle();
      expect(find.text('연결 문제가 없어요'), findsNothing);
      expect(find.text('바로 교정이 필요한 곳 0곳'), findsOneWidget);
    });

    testWidgets('점검 실패: "문제 없음" 으로 읽히지 않게 건수 영역을 그리지 않는다 + 다시 시도', (t) async {
      big(t);
      repo.error = StateError('permission');
      await t.pumpWidget(host());
      await t.tap(find.text('점검하기'));
      await t.pumpAndSettle();
      expect(find.text('점검하지 못했어요'), findsOneWidget);
      expect(find.textContaining('곳'), findsNothing);
      expect(find.text('연결 문제가 없어요'), findsNothing);
      expect(find.text('정상 0 · 등록 전 0'), findsNothing);
      repo.error = null;
      repo.result = BrandLinkAuditRemoteDataSource.parse(_resp());
      await t.tap(find.text('다시 시도'));
      await t.pumpAndSettle();
      expect(find.text('연결 문제가 없어요'), findsOneWidget);
    });
  });
}

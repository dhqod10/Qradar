import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/errors/qoin_rate_exception.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/qoin_rate_results.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/domain/repositories/qoin_rate_repository.dart';
import 'package:qradar/domain/usecases/set_qoin_accrual_enabled_use_case.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_accrual_switch_card.dart';
import 'package:qradar/presentation/common/providers/qoin_di_providers.dart';

class _Repo implements QoinRateRepository {
  final List<Map<String, Object?>> calls = [];
  Object? failWith;

  @override
  Future<QoinAccrualEnabledResult> setAccrualEnabled({
    required QoinRateScope scope,
    required String targetId,
    required bool enabled,
    String? reason,
  }) async {
    calls.add({
      'scope': scope,
      'id': targetId,
      'enabled': enabled,
      'reason': reason,
    });
    if (failWith != null) throw failWith!;
    return QoinAccrualEnabledResult(
      before: enabled ? false : null,
      after: enabled ? null : false,
      changed: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

EffectiveQoinRate eff({
  QoinSwitchSetting storeSwitch = QoinSwitchSetting.enabled,
  QoinSwitchSetting brandSwitch = QoinSwitchSetting.enabled,
}) => resolveEffectiveQoinRate(
  store: QoinRateSetting.absent,
  storeSwitch: storeSwitch,
  brand: QoinRateSetting.valid(0.05),
  brandSwitch: brandSwitch,
  global: QoinRateSetting.valid(0.03),
);

void main() {
  late _Repo repo;
  setUp(() => repo = _Repo());

  Widget host({
    required QoinRateScope scope,
    required QoinSwitchSetting setting,
    required EffectiveQoinRate effective,
    int? total,
    int? overridden,
  }) => ProviderScope(
    overrides: [
      setQoinAccrualEnabledUseCaseProvider.overrideWithValue(
        SetQoinAccrualEnabledUseCase(repo),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: QoinAccrualSwitchCard(
            scope: scope,
            targetId: 'x1',
            targetName: scope == QoinRateScope.brand ? 'Q브루어리' : '강남점',
            switchSetting: setting,
            effective: effective,
            subStoreTotal: total,
            subStoreOverridden: overridden,
          ),
        ),
      ),
    ),
  );

  testWidgets('매장 켜짐: 제목/설명/하단, 탭 -> 끄기 다이얼로그(환불 회수 계속) -> 취소하면 호출 없음', (
    t,
  ) async {
    await t.pumpWidget(
      host(
        scope: QoinRateScope.store,
        setting: QoinSwitchSetting.enabled,
        effective: eff(),
      ),
    );
    expect(find.text('이 매장 적립 사용'), findsOneWidget);
    expect(find.text('이 매장의 주문은 픽업 완료 시 Qoin 이 적립돼요'), findsOneWidget);
    expect(find.text('위 ‘매장 설정 저장’ 과 별개로 바로 적용돼요'), findsOneWidget);
    expect(t.widget<Switch>(find.byType(Switch)).value, isTrue);
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    expect(find.text('매장 "강남점"'), findsOneWidget);
    expect(find.text('적립을 중단할까요?'), findsOneWidget);
    expect(
      find.text('이후 픽업이 완료되는 주문은 적립되지 않아요. 이미 적립된 Qoin 의 환불 회수는 계속돼요'),
      findsOneWidget,
    );
    expect(find.text('이 변경은 바로 적용돼요. 다시 켜면 현재 요율로 적립돼요'), findsOneWidget);
    await t.tap(find.text('취소'));
    await t.pumpAndSettle();
    expect(repo.calls, isEmpty);
    expect(
      t.widget<Switch>(find.byType(Switch)).value,
      isTrue,
      reason: '낙관적으로 움직이지 않는다',
    );
  });

  testWidgets('끄기 확정: enabled=false + 사유 전달, SnackBar', (t) async {
    await t.pumpWidget(
      host(
        scope: QoinRateScope.store,
        setting: QoinSwitchSetting.enabled,
        effective: eff(),
      ),
    );
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '  점검  ');
    await t.tap(find.text('적립 중단'));
    await t.pumpAndSettle();
    expect(repo.calls.single, {
      'scope': QoinRateScope.store,
      'id': 'x1',
      'enabled': false,
      'reason': '점검',
    });
    expect(find.text('이 매장의 적립을 중단했어요'), findsOneWidget);
  });

  testWidgets('브랜드 끄기 다이얼로그: 산하 전부 멈춤 + N/M + 운영 안내', (t) async {
    await t.pumpWidget(
      host(
        scope: QoinRateScope.brand,
        setting: QoinSwitchSetting.enabled,
        effective: eff(),
        total: 12,
        overridden: 3,
      ),
    );
    expect(find.textContaining('산하 매장 12곳'), findsOneWidget);
    expect(
      find.textContaining('일부 매장만 멈추려면 이 스위치가 아니라 각 매장의 ‘적립 사용’ 을 끄세요'),
      findsOneWidget,
    );
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    expect(find.text('산하 매장 전부가 적립을 멈춰요'), findsOneWidget);
    expect(find.text('이 화면 기준 12곳 · 적립률을 따로 정한 3곳도 포함이에요'), findsOneWidget);
    expect(find.text('일부 매장만 멈추려면 브랜드는 켠 채 매장별로 끄세요'), findsOneWidget);
  });

  testWidgets('브랜드 정보 로딩 전에도 끌 수 있다 (숫자 괄호만 생략)', (t) async {
    await t.pumpWidget(
      host(
        scope: QoinRateScope.brand,
        setting: QoinSwitchSetting.enabled,
        effective: eff(),
      ),
    );
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    expect(find.text('산하 매장 전부가 적립을 멈춰요'), findsOneWidget);
    expect(find.textContaining('이 화면 기준'), findsNothing);
  });

  testWidgets('꺼진 매장: 상태 칩 + 설명 + 켜기 다이얼로그는 사슬과 같은 다시 켜면 문장', (t) async {
    final e = eff(storeSwitch: QoinSwitchSetting.disabled);
    await t.pumpWidget(
      host(
        scope: QoinRateScope.store,
        setting: QoinSwitchSetting.disabled,
        effective: e,
      ),
    );
    expect(find.text('사용 안 함'), findsOneWidget);
    expect(find.text('이 매장은 Qoin 을 적립하지 않아요. 환불로 인한 회수는 계속돼요'), findsOneWidget);
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    expect(find.text('적립을 다시 시작할까요?'), findsOneWidget);
    expect(find.text('다시 켜면 브랜드 5% 가 적용돼요'), findsOneWidget);
    expect(find.text('끄기 전에 어떤 값이었는지와 관계없이 지금의 요율이에요'), findsOneWidget);
    await t.tap(find.text('적립 시작'));
    await t.pumpAndSettle();
    expect(repo.calls.single['enabled'], isTrue);
    expect(find.text('이 매장의 적립을 다시 시작했어요'), findsOneWidget);
  });

  testWidgets('브랜드가 꺼져 있으면 매장 켜기 다이얼로그가 달라진다 (D)', (t) async {
    final e = eff(
      storeSwitch: QoinSwitchSetting.disabled,
      brandSwitch: QoinSwitchSetting.disabled,
    );
    await t.pumpWidget(
      host(
        scope: QoinRateScope.store,
        setting: QoinSwitchSetting.disabled,
        effective: e,
      ),
    );
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    expect(find.text('다시 켜도 브랜드가 사용 안 함이라 적립되지 않아요'), findsOneWidget);
  });

  testWidgets(
    '일괄 적용 진행 중(failed-precondition): 확정 실패 문구, 결과 불명은 재시도를 권하지 않는다',
    (t) async {
      repo.failWith = const QoinRateException(
        QoinRateFailureKind.rejected,
        code: 'failed-precondition',
      );
      await t.pumpWidget(
        host(
          scope: QoinRateScope.brand,
          setting: QoinSwitchSetting.enabled,
          effective: eff(),
        ),
      );
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      await t.tap(find.text('적립 중단'));
      await t.pumpAndSettle();
      expect(
        find.text('이 브랜드에 일괄 적용이 진행 중이에요. 끝난 뒤 다시 시도해주세요'),
        findsOneWidget,
      );
      expect(t.widget<Switch>(find.byType(Switch)).value, isTrue);

      repo.failWith = const QoinRateException(
        QoinRateFailureKind.unknownOutcome,
      );
      await t.pump(const Duration(seconds: 5));
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      await t.tap(find.text('적립 중단'));
      await t.pumpAndSettle();
      expect(find.text('결과를 확인하지 못했어요. 변경 이력에서 적용 여부를 확인해주세요'), findsOneWidget);
    },
  );

  testWidgets('QoinSwitchFocusController.go 는 스위치를 대신 누르지 않는다', (t) async {
    final c = QoinSwitchFocusController();
    final sc = ScrollController();
    addTearDown(c.dispose);
    addTearDown(sc.dispose);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          setQoinAccrualEnabledUseCaseProvider.overrideWithValue(
            SetQoinAccrualEnabledUseCase(repo),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: sc,
              child: Column(
                children: [
                  const SizedBox(height: 1200),
                  QoinAccrualSwitchCard(
                    scope: QoinRateScope.store,
                    targetId: 'x',
                    targetName: 'n',
                    switchSetting: QoinSwitchSetting.enabled,
                    effective: eff(),
                    controller: c,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(sc.offset, 0);
    unawaited(c.go());
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(sc.offset, greaterThan(0), reason: '카드로 스크롤');
    expect(find.text('이 매장 적립 사용'), findsOneWidget);
    expect(repo.calls, isEmpty);
    expect(t.widget<Switch>(find.byType(Switch)).value, isTrue);
    await t.pump(const Duration(milliseconds: 1300));
  });
}

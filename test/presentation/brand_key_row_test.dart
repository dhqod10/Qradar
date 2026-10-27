import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/brand_private_profile_entity.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/presentation/brand/brand_info/widgets/brand_key_row.dart';
import 'package:qradar/presentation/brand/providers/brand_info_providers.dart';

/// payment_server_authority B1 design §5: brandKey 행은 읽기 상태(loading/data/error)와 키 유무를 분리한 5상태다.
/// 핵심 불변: 읽기 실패(S3)는 "관리자 승인 후 ..." 문구로 떨어지지 않는다 (U4).
const _kApprovalWait = '관리자 승인 후 브랜드 키가 발급됩니다';
const _kFailed = '브랜드 키를 불러오지 못했어요';
const _kShare = '이 키를 점주에게 공유하면 가맹점 등록 시 사용할 수 있어요';
const _kRevision = '재승인이 끝나기 전에는 점주가 이 키로 등록할 수 없어요';
const _kAnomaly = '브랜드 키가 아직 발급되지 않았어요';
const _kRepeated = '계속 안 되면 관리자에게 문의해 주세요';

BrandEntity _brand(EntityApprovalStatus s) =>
    BrandEntity(id: 'b1', name: 'B', status: s);

Widget _app(
  BrandEntity brand,
  Stream<BrandPrivateProfileEntity?> Function(int call) source,
) {
  var calls = 0;
  return ProviderScope(
    overrides: [
      brandPrivateProfileProvider.overrideWith((ref, id) => source(++calls)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Center(child: BrandKeyRow(brand: brand)),
      ),
    ),
  );
}

Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('S0 로딩: 스켈레톤 + 라벨, 어떤 안내 문구도 없다', (t) async {
    final c = StreamController<BrandPrivateProfileEntity?>();
    addTearDown(c.close);
    await t.pumpWidget(
      _app(_brand(EntityApprovalStatus.approved), (_) => c.stream),
    );
    await t.pump();
    expect(find.byKey(const ValueKey('brandKeyRow.loading')), findsOneWidget);
    expect(find.text('브랜드 키'), findsOneWidget);
    for (final s in [_kApprovalWait, _kFailed, _kAnomaly, _kShare]) {
      expect(find.text(s), findsNothing, reason: s);
    }
  });

  testWidgets('S1 발급됨: 키 + 복사 + 공유 문구', (t) async {
    await t.pumpWidget(
      _app(
        _brand(EntityApprovalStatus.approved),
        (_) => Stream.value(
          const BrandPrivateProfileEntity(brandKey: 'BR-ABCDEFGH'),
        ),
      ),
    );
    await settle(t);
    expect(find.text('BR-ABCDEFGH'), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    expect(find.text(_kShare), findsOneWidget);
    expect(find.text(_kApprovalWait), findsNothing);
  });

  testWidgets(
    'S1′ 발급됨 + 승인 대기 회귀: 키 + 복사 유지, 공유 문구 대신 재승인 안내, "승인 후 발급" 문구 없음',
    (t) async {
      await t.pumpWidget(
        _app(
          _brand(EntityApprovalStatus.pending),
          (_) => Stream.value(
            const BrandPrivateProfileEntity(brandKey: 'BR-ABCDEFGH'),
          ),
        ),
      );
      await settle(t);
      expect(find.text('BR-ABCDEFGH'), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
      expect(find.text(_kRevision), findsOneWidget);
      expect(find.text(_kShare), findsNothing);
      expect(find.text(_kApprovalWait), findsNothing);
    },
  );

  testWidgets('S2 미발급(승인 대기, 키 없음 / 문서 없음 모두)', (t) async {
    for (final profile in <BrandPrivateProfileEntity?>[
      null,
      const BrandPrivateProfileEntity(),
    ]) {
      await t.pumpWidget(
        _app(
          _brand(EntityApprovalStatus.pending),
          (_) => Stream.value(profile),
        ),
      );
      await settle(t);
      expect(find.text(_kApprovalWait), findsOneWidget);
      expect(find.byIcon(Icons.lock_clock_rounded), findsOneWidget);
      expect(find.text(_kFailed), findsNothing);
      expect(find.text('다시 시도'), findsNothing);
    }
  });

  testWidgets('S3 읽기 실패: 실패 문구 + 다시 시도, "관리자 승인 후" 문구가 없다 (pending 이어도)', (
    t,
  ) async {
    for (final status in [
      EntityApprovalStatus.pending,
      EntityApprovalStatus.approved,
    ]) {
      await t.pumpWidget(
        _app(
          _brand(status),
          (_) => Stream.error(StateError('permission-denied')),
        ),
      );
      await settle(t);
      expect(find.text(_kFailed), findsOneWidget, reason: status.name);
      expect(find.text('다시 시도'), findsOneWidget);
      expect(find.text('발급된 키에는 영향이 없어요. 잠시 후 다시 시도해 주세요'), findsOneWidget);
      expect(find.text(_kApprovalWait), findsNothing, reason: 'S3 는 미발급이 아니다');
      expect(find.text(_kAnomaly), findsNothing);
      expect(find.byIcon(Icons.copy_rounded), findsNothing);
      expect(find.text(_kRepeated), findsNothing, reason: '첫 실패에는 추가 줄 없음');
      // 서버 예외 문자열이 화면에 새지 않는다.
      expect(find.textContaining('permission-denied'), findsNothing);
      expect(find.textContaining('StateError'), findsNothing);
    }
  });

  testWidgets('S3 -> 다시 시도: 스켈레톤으로 복귀 후 결과로. 2회 연속 실패면 추가 한 줄', (t) async {
    final c2 = StreamController<BrandPrivateProfileEntity?>();
    addTearDown(c2.close);
    await t.pumpWidget(
      _app(_brand(EntityApprovalStatus.pending), (call) {
        if (call == 1) return Stream.error(StateError('x'));
        if (call == 2) return c2.stream; // 응답 대기 중 -> 스켈레톤
        return Stream.error(StateError('y'));
      }),
    );
    await settle(t);
    expect(find.text(_kFailed), findsOneWidget);

    await t.tap(find.text('다시 시도'));
    await t.pump();
    // 재시도 중에는 이전 실패 문구를 두지 않는다.
    expect(find.byKey(const ValueKey('brandKeyRow.loading')), findsOneWidget);
    expect(find.text(_kFailed), findsNothing);

    c2.addError(StateError('again'));
    await settle(t);
    expect(find.text(_kFailed), findsOneWidget);
    expect(find.text(_kRepeated), findsOneWidget, reason: '연속 2회 실패');
  });

  testWidgets('S3 -> 다시 시도 성공 -> S1 (실패 카운터 초기화)', (t) async {
    await t.pumpWidget(
      _app(
        _brand(EntityApprovalStatus.approved),
        (call) => call == 1
            ? Stream.error(StateError('x'))
            : Stream.value(
                const BrandPrivateProfileEntity(brandKey: 'BR-ABCDEFGH'),
              ),
      ),
    );
    await settle(t);
    await t.tap(find.text('다시 시도'));
    await settle(t);
    expect(find.text('BR-ABCDEFGH'), findsOneWidget);
    expect(find.text(_kFailed), findsNothing);
  });

  testWidgets('S4 이상: 승인됐는데 키 없음 -> 발급 버튼 없이 문의 안내', (t) async {
    await t.pumpWidget(
      _app(_brand(EntityApprovalStatus.approved), (_) => Stream.value(null)),
    );
    await settle(t);
    expect(find.text(_kAnomaly), findsOneWidget);
    expect(find.text('승인은 완료됐어요. 관리자에게 키 발급을 요청해 주세요'), findsOneWidget);
    expect(find.text(_kApprovalWait), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
  });
}

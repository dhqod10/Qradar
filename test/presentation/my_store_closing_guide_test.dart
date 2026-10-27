import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/store_grade.dart';
import 'package:qradar/domain/entities/user_location.dart';
import 'package:qradar/presentation/brand/providers/brand_info_providers.dart';
import 'package:qradar/presentation/owner/my_store/my_store_page.dart';
import 'package:qradar/presentation/owner/providers/owner_providers.dart';

/// payment_server_authority D1 design §6: 점주 화면의 `매장 삭제` 버튼은 사라지고 안내 한 줄(`_ClosingGuide`)이 온다.
/// 불변: 삭제 버튼 부재 · 임시 휴업 안내 부재(temporaryClosed 는 주문을 막지 못한다 — spec §6.8).
const _kApproved = '매장 운영을 그만두려면 관리자에게 문의해 주세요.';
const _kOther = '매장을 삭제하거나 잘못 등록한 매장을 정리하려면 관리자에게 문의해 주세요.';

StoreEntity _store({
  EntityApprovalStatus status = EntityApprovalStatus.approved,
  String? brandId,
}) => StoreEntity(
  id: 's1',
  name: '강남점',
  imageUrl: '',
  location: const UserLocation(latitude: 37, longitude: 127),
  grade: StoreGrade.c,
  averageScore: 0,
  reviewCount: 0,
  menuCategories: const ['커피'],
  createdAt: DateTime(2026),
  ownerId: 'o1',
  address: '서울시',
  status: status,
  brandId: brandId,
);

void main() {
  group('closingGuideMessage (design §6.2 문구표)', () {
    test('개인 매장 approved -> 폐업 문구', () {
      expect(closingGuideMessage(_store()), _kApproved);
    });
    test('개인 매장 pending / rejected -> 정리 문구', () {
      for (final s in [
        EntityApprovalStatus.pending,
        EntityApprovalStatus.rejected,
      ]) {
        expect(closingGuideMessage(_store(status: s)), _kOther, reason: s.name);
      }
    });
    test('브랜드 가맹 매장은 상태와 무관하게 정리 문구', () {
      for (final s in EntityApprovalStatus.values) {
        expect(
          closingGuideMessage(_store(status: s, brandId: 'b1')),
          _kOther,
          reason: s.name,
        );
      }
    });
    test('어떤 문구에도 임시 휴업/휴무를 권하지 않는다', () {
      for (final m in [_kApproved, _kOther]) {
        expect(m.contains('휴업'), isFalse);
        expect(m.contains('휴무'), isFalse);
      }
    });
  });

  group('MyStorePage', () {
    Future<void> pump(WidgetTester t, StoreEntity store) async {
      t.view.physicalSize = const Size(900, 3200);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            myStoreProvider.overrideWith((ref) => Stream.value(store)),
            brandByIdProvider.overrideWith(
              (ref, id) => Stream.value(
                BrandEntity(
                  id: id,
                  name: 'Q브루어리',
                  status: EntityApprovalStatus.approved,
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: MyStorePage())),
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
    }

    void expectGuideNoDelete(WidgetTester t, String message) {
      expect(find.text(message), findsOneWidget);
      expect(find.text('매장 삭제'), findsNothing);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
      expect(find.textContaining('휴업'), findsNothing);
      expect(find.textContaining('임시'), findsNothing);
      // 안내 줄에 버튼·링크가 없다 (눌러도 아무 일도 없는 어피던스 금지).
      final guide = find
          .ancestor(of: find.text(message), matching: find.byType(Row))
          .first;
      expect(
        find.descendant(of: guide, matching: find.byType(TextButton)),
        findsNothing,
      );
      expect(
        find.descendant(of: guide, matching: find.byType(InkWell)),
        findsNothing,
      );
    }

    testWidgets('개인 매장 approved: 폐업 안내, 삭제 버튼 없음', (t) async {
      await pump(t, _store());
      expectGuideNoDelete(t, _kApproved);
    });

    testWidgets('개인 매장 pending: 정리 안내, 삭제 버튼 없음', (t) async {
      await pump(t, _store(status: EntityApprovalStatus.pending));
      expectGuideNoDelete(t, _kOther);
    });

    testWidgets('브랜드 가맹 매장: 정리 안내, 삭제 버튼 없음', (t) async {
      await pump(t, _store(brandId: 'b1'));
      expectGuideNoDelete(t, _kOther);
    });
  });
}

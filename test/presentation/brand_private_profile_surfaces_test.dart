import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/brand_private_profile_entity.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/presentation/admin/approval/admin_brand_approval_detail_page.dart';
import 'package:qradar/presentation/brand/brand_info/brand_info_form_page.dart';
import 'package:qradar/presentation/brand/providers/brand_info_providers.dart';

/// payment_server_authority B1: PII 는 부모 문서가 아니라 private/profile 에서 읽는다.
/// 불변: 읽기 실패를 빈 값으로 폴백하지 않는다 (폼은 열지 않고, admin 상세는 해당 섹션만 오류).
const _brand = BrandEntity(
  id: 'b1',
  name: 'Q브루어리',
  companyName: '(주)Q',
  status: EntityApprovalStatus.pending,
);
const _profile = BrandPrivateProfileEntity(
  brandKey: 'BR-ABCDEFGH',
  businessRegistrationNumber: '123-45-67890',
  contactName: '홍길동',
  contactPhone: '010-1234-5678',
  headOfficeAddress: '서울시 강남구',
  representativeName: '김대표',
);

Finder _field(String text) => find.byWidgetPredicate(
  (w) => w is EditableText && w.controller.text == text,
);

void main() {
  group('BrandInfoFormPage 수정 모드', () {
    Widget app(Future<BrandPrivateProfileEntity?> Function(int) src) {
      var calls = 0;
      return ProviderScope(
        overrides: [
          brandPrivateProfileFetchProvider.overrideWith(
            (ref, id) => src(++calls),
          ),
        ],
        child: const MaterialApp(home: BrandInfoFormPage(brand: _brand)),
      );
    }

    testWidgets('읽기 성공: private/profile 값으로 PII 필드를 채운다', (t) async {
      t.view.physicalSize = const Size(900, 3000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(app((_) async => _profile));
      await t.pump();
      await t.pump();
      expect(_field('123-45-67890'), findsOneWidget);
      expect(_field('홍길동'), findsOneWidget);
      expect(_field('010-1234-5678'), findsOneWidget);
      expect(find.text('서울시 강남구'), findsOneWidget);
      expect(_field('김대표'), findsOneWidget);
    });

    testWidgets('읽기 실패: 빈 폼으로 폴백하지 않고 다시 시도만 준다. 재시도하면 폼이 열린다', (t) async {
      t.view.physicalSize = const Size(900, 3000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        app(
          (call) => call == 1
              ? Future.error(StateError('denied'))
              : Future.value(_profile),
        ),
      );
      await t.pump();
      await t.pump();
      expect(find.text('사업자 정보를 불러오지 못했어요'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.textContaining('denied'), findsNothing);
      await t.tap(find.text('다시 시도'));
      await t.pump();
      await t.pump();
      expect(_field('123-45-67890'), findsOneWidget);
    });
  });

  group('AdminBrandApprovalDetailPage 사업자 정보', () {
    Widget app(Stream<BrandPrivateProfileEntity?> s) => ProviderScope(
      overrides: [brandPrivateProfileProvider.overrideWith((ref, id) => s)],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BrandBusinessInfoSection(brand: _brand),
          ),
        ),
      ),
    );

    testWidgets('PII 5개 + 회사명(부모)을 표시. brandKey 는 표시하지 않는다', (t) async {
      await t.pumpWidget(app(Stream.value(_profile)));
      await t.pump();
      await t.pump();
      expect(find.text('(주)Q'), findsOneWidget);
      expect(find.text('123-45-67890'), findsOneWidget);
      expect(find.text('홍길동 / 010-1234-5678'), findsOneWidget);
      expect(find.text('서울시 강남구'), findsOneWidget);
      expect(find.text('김대표'), findsOneWidget);
      expect(find.text('BR-ABCDEFGH'), findsNothing);
    });

    testWidgets('읽기 실패: 이 섹션만 오류(회사명은 유지), 빈 정보로 폴백하지 않는다', (t) async {
      await t.pumpWidget(app(Stream.error(StateError('denied'))));
      await t.pump();
      await t.pump();
      expect(find.text('사업자 정보를 불러오지 못했어요'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
      expect(find.text('(주)Q'), findsOneWidget);
      expect(find.text('사업자번호'), findsNothing);
    });
  });
}

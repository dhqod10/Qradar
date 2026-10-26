import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/presentation/brand/brand_info/brand_info_form_page.dart';

/// 브랜드 등록 폼: 로고 필수 표시 + 제출이 막힐 때 어느 항목인지 지목한다 (아무 일도 안 일어난 것을 설명 없이 두지 않는다).
void main() {
  List<String> missing({
    bool hasLogo = true,
    String name = '브랜드',
    String company = '(주)회사',
    String biz = '123-45-67890',
    String contact = '홍길동',
    String phone = '010-1234-5678',
  }) => missingBrandFormFields(
    hasLogo: hasLogo,
    name: name,
    companyName: company,
    bizRegNo: biz,
    contactName: contact,
    contactPhone: phone,
  );

  test('모두 채우면 비어 있다', () => expect(missing(), isEmpty));

  test('다른 필수 항목을 다 채우고 로고만 빠진 경우 — 실제로 막혔던 사례', () {
    expect(missing(hasLogo: false), ['브랜드 로고']);
  });

  test('빠진 항목은 화면 순서대로, 형식 오류는 형식을 함께 말한다', () {
    expect(
      missing(
        hasLogo: false,
        name: ' ',
        company: '',
        biz: '123',
        contact: '',
        phone: '01012345678',
      ),
      [
        '브랜드 로고',
        '브랜드 이름',
        '회사명',
        '사업자등록번호(000-00-00000 형식)',
        '담당자 이름',
        '담당자 연락처(010-1234-5678 형식)',
      ],
    );
    expect(missing(biz: ''), ['사업자등록번호']);
    expect(missing(phone: ''), ['담당자 연락처']);
  });

  test('안내 문구는 항목을 지목한다', () {
    expect(
      missingBrandFormFieldsMessage(['브랜드 로고', '회사명']),
      '다음 항목을 확인해주세요: 브랜드 로고, 회사명',
    );
  });

  testWidgets('폼: 로고 라벨에 * 가 있고, 비어 있는 채로 저장하면 SnackBar 가 빠진 항목을 지목한다', (
    t,
  ) async {
    t.view.physicalSize = const Size(800, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: BrandInfoFormPage(brand: null)),
      ),
    );
    expect(find.text('브랜드 로고 *'), findsOneWidget);
    expect(find.text('브랜드 로고'), findsNothing);
    // 필수 라벨은 전부 * 로 통일
    for (final l in [
      '브랜드 이름 *',
      '회사명 *',
      '사업자등록번호 *',
      '담당자 이름 *',
      '담당자 연락처 *',
    ]) {
      expect(find.text(l), findsOneWidget, reason: l);
    }
    await t.tap(find.byType(ElevatedButton).last);
    await t.pump();
    expect(
      find.text('다음 항목을 확인해주세요: 브랜드 로고, 브랜드 이름, 회사명, 사업자등록번호, 담당자 이름, 담당자 연락처'),
      findsOneWidget,
    );
    expect(find.text('필수 항목을 모두 올바르게 입력해주세요'), findsNothing);

    // 로고 외 전부 채웠는데도 막히면 로고를 지목한다
    final fields = find.byType(TextFormField);
    await t.enterText(fields.at(0), '새 브랜드');
    await t.enterText(fields.at(2), '(주)새');
    await t.enterText(fields.at(3), '123-45-67890');
    await t.enterText(fields.at(4), '홍길동');
    await t.enterText(fields.at(5), '010-1234-5678');
    ScaffoldMessenger.of(t.element(find.byType(Scaffold).first)).clearSnackBars();
    await t.pump();
    await t.tap(find.byType(ElevatedButton).last);
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('다음 항목을 확인해주세요: 브랜드 로고'), findsOneWidget);
  });
}

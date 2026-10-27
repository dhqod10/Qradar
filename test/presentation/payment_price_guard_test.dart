import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// payment_price_authority 구조 가드 (spec §19-2 · design §7.1) — grep 항목을 파일 스캔으로 자동화한다.
/// 주석(`//`, `///`, `/* */`)은 설명을 위해 금지어를 언급하므로 스캔 전에 제거한다.
///
/// 이 가드는 **변이로 실제로 깨지는지** 확인했다 (implementation.md §테스트 > 변이 검증).
String _stripComments(String src) {
  final noBlock = src.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  return noBlock
      .split('\n')
      .map((l) {
        final i = l.indexOf('//');
        return i < 0 ? l : l.substring(0, i);
      })
      .join('\n');
}

List<File> _files(String dir, String ext, {List<String> skip = const []}) =>
    Directory(dir)
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith(ext) &&
              !f.path.endsWith('.freezed.dart') &&
              !f.path.endsWith('.g.dart') &&
              !skip.any(f.path.contains),
        )
        .toList();

String _code(String path) => _stripComments(File(path).readAsStringSync());

/// 앱 코드 전체 (개발용 시드 `lib/dev/` 는 운영 경로가 아니다).
List<File> get _appFiles => _files('lib', '.dart', skip: ['lib/dev/']);
List<File> get _tsFiles => _files('functions/src', '.ts');

/// 거절 화면·카트 가격 변동·시트가 문구를 그리는 곳 — **디렉터리 단위**로 스캔한다 (닫힌 파일 목록은 새 문구 파일이 생기면
/// 무방비다, test_report F-05). 결제·카트 presentation 전체 + 담기 상한 안내가 있는 메뉴 상세.
final List<String> _copyFiles = [
  for (final dir in [
    'lib/presentation/customer/checkout',
    'lib/presentation/customer/cart',
  ])
    for (final f in _files(dir, '.dart')) f.path,
  'lib/presentation/customer/order/menu/menu_item_detail_page.dart',
  'lib/presentation/admin/widgets/admin_price_audit_card.dart',
];

void main() {
  group('R7 · 가격 산술은 Dart·TS 각 1곳 (spec §19-2 1·2)', () {
    // `priceDelta` 를 합산하는 형태: `+= ... priceDelta`, `fold/reduce ... priceDelta`.
    final summing = RegExp(
      r'\+=[^;\n]*[pP]riceDelta|(fold|reduce)\b[^;\n]*[pP]riceDelta',
    );

    test(
      '1. Dart: priceDelta 합산은 lib/core/utils/cart_pricing.dart 에만 있다 (메뉴 상세의 중복 계산이 제거됐다)',
      () {
        final offenders = [
          for (final f in _appFiles)
            if (!f.path.endsWith('core/utils/cart_pricing.dart') &&
                summing.hasMatch(_stripComments(f.readAsStringSync())))
              f.path,
        ];
        expect(
          offenders,
          isEmpty,
          reason: '금액 산술은 서버와 같은 식 하나 — computeLinePrice',
        );
        // 양성 대조: 정규식이 죽어 있지 않다 + 합산이 실제로 그 파일에 있다.
        final cp = _code('lib/core/utils/cart_pricing.dart');
        expect(cp.contains('int computeLinePrice('), isTrue);
        expect(cp.contains('unit += d'), isTrue);
        expect(summing.hasMatch('unit += item.priceDelta;'), isTrue);
        expect(
          summing.hasMatch(
            'final s = deltas.fold(0, (a, b) => a + b.priceDelta);',
          ),
          isTrue,
        );
      },
    );

    test(
      '1-b. Dart: 소비자 3곳(메뉴 상세 담기 · 실시간 합계 · 카트 저장소)이 computeLinePrice / computeLineTotal 을 쓴다',
      () {
        for (final p in [
          'lib/presentation/customer/order/menu/menu_item_detail_page.dart',
          'lib/presentation/customer/order/menu/providers/menu_detail_providers.dart',
          'lib/data/datasources/local/cart_local_data_source.dart',
          'lib/domain/usecases/validate_checkout_use_case.dart',
        ]) {
          final c = _code(p);
          expect(c.contains('computeLine'), isTrue, reason: p);
        }
      },
    );

    test('2. TS: priceDelta 합산은 functions/src/cartPricing.ts 에만 있다', () {
      final tsSumming = RegExp(
        r'\+=[^;\n]*[pP]riceDelta|(fold|reduce)\b[^;\n]*[pP]riceDelta|[pP]riceDeltas\b[^;\n]*\+=',
      );
      final offenders = [
        for (final f in _tsFiles)
          if (!f.path.endsWith('cartPricing.ts') &&
              tsSumming.hasMatch(_stripComments(f.readAsStringSync())))
            f.path,
      ];
      expect(offenders, isEmpty);
      expect(
        tsSumming.hasMatch(_code('functions/src/cartPricing.ts')),
        isTrue,
        reason: '양성 대조 — 합산이 그 파일에 있다',
      );
    });

    test(
      'presentation 은 금액을 직접 곱하거나 나누지 않는다 (UseCase 가 계산한 값만 그린다, spec §15)',
      () {
        for (final f in _files('lib/presentation', '.dart')) {
          final c = _stripComments(f.readAsStringSync());
          // 수량 곱셈 / 단가 역산. 예외는 아래 quick_reorder 1건 (테스트 3번).
          expect(
            RegExp(
              r'unitPrice\w*\s*\*\s*\w*[qQ]uantity|[qQ]uantity\s*\*\s*\w*[uU]nitPrice',
            ).hasMatch(c),
            isFalse,
            reason: f.path,
          );
        }
      },
    );
  });

  group('R6 · 옵션 선택 가능 판정은 1곳', () {
    test(
      '3. composite `{groupId}_{itemId}` 판정 조립: Dart option_availability.dart · TS optionPricing.ts 각 1곳',
      () {
        final dartCompose = RegExp(
          r'\$\{(groupId|group\.id)\}_\$\{?(itemId|item\.id)',
        );
        final dart = {
          for (final f in _appFiles)
            if (dartCompose.hasMatch(_stripComments(f.readAsStringSync())))
              f.path,
        };
        // 판정(읽기) 쪽은 option_availability.dart 1곳. 아래 3곳은 점주·브랜드가 비활성 키를 **쓰는** 화면이라 같은 형식을
        // 만든다 — 이 task 의 범위 밖이다 (implementation.md 후속). 새 조립 지점이 생기면 이 목록이 깨져 대조가 강제된다.
        expect(dart, {
          'lib/core/utils/option_availability.dart',
          'lib/presentation/brand/master_menu/widgets/option_group_selector.dart',
          'lib/presentation/common/option_disable_sheet/menu_option_disable_sheet.dart',
        });
        final ts = {
          for (final f in _tsFiles)
            if (RegExp(
              r'\$\{groupId\}_\$\{itemId\}',
            ).hasMatch(_stripComments(f.readAsStringSync())))
              f.path,
        };
        expect(ts, {'functions/src/optionPricing.ts'});
        // 판정은 Repository 구현에 남아 있지 않다 (추출 완료).
        final repo = _code('lib/data/repositories/option_repository_impl.dart');
        expect(repo.contains('resolveSelectableOptions'), isTrue);
        expect(repo.contains('disabledItemIds.contains'), isFalse);
        expect(repo.contains('.active'), isFalse);
      },
    );

    test(
      '4. functions/src 에 optionGroupId / optionId 가 0건이다 (서버 타입이 런타임과 달랐던 §1-5 재발 방지)',
      () {
        for (final f in _tsFiles) {
          final c = _stripComments(f.readAsStringSync());
          expect(c.contains('optionGroupId'), isFalse, reason: f.path);
          expect(RegExp(r'\boptionId\b').hasMatch(c), isFalse, reason: f.path);
        }
      },
    );

    test(
      '5. priceOverride 승인 분기: TS 는 menuVisibility.ts 가 유일한 구현이다 — 기록·보고 파일은 status 비교를 하지 않는다',
      () {
        // 기록·보고만 하는 2개 (payment_authority_guard_test.dart 허용 목록과 같다).
        for (final p in [
          'functions/src/onMenuPriceWritten.ts',
          'functions/src/auditOrderPriceIntegrity.ts',
        ]) {
          final c = _code(p);
          expect(
            RegExp(r'''['"](approved|pending|rejected)['"]''').hasMatch(c),
            isFalse,
            reason: '$p : 승인 판정은 menuVisibility.ts overrideIsApproved 를 가져다 쓴다',
          );
        }
        expect(
          _code(
            'functions/src/auditOrderPriceIntegrity.ts',
          ).contains('overrideIsApproved'),
          isTrue,
        );
        // 금액 게이트는 priceOverride / status 를 직접 읽지 않는다 (MergedMenu.basePrice 만).
        for (final p in [
          'functions/src/priceGate.ts',
          'functions/src/cartPricing.ts',
          'functions/src/optionPricing.ts',
        ]) {
          final c = _code(p);
          expect(c.contains('priceOverride'), isFalse, reason: p);
          expect(RegExp(r'\.status\b').hasMatch(c), isFalse, reason: p);
        }
      },
    );

    test(
      '6. lib/data/models 에 금액 비방어 cast(as int?)가 없다 (Dart 는 예외, TS 는 통과 → 같은 문서를 두 쪽이 다르게 읽는다)',
      () {
        for (final f in _files('lib/data/models', '.dart')) {
          expect(
            RegExp(r'as int\?').hasMatch(_stripComments(f.readAsStringSync())),
            isFalse,
            reason: f.path,
          );
        }
      },
    );

    test(
      '7. 단가 역산(lineTotal ~/ quantity)은 quick_reorder_section.dart 밖에 없다 (허용 목록 1건 — 체크아웃 재가격이 돈 경로를 덮는다)',
      () {
        final offenders = [
          for (final f in _appFiles)
            if (RegExp(
              r'~/\s*[\w.]*[qQ]uantity',
            ).hasMatch(_stripComments(f.readAsStringSync())))
              f.path,
        ];
        expect(offenders, [
          'lib/presentation/customer/home/widgets/quick_reorder_section.dart',
        ]);
        // 허용 사유 주석 필수.
        final src = File(
          'lib/presentation/customer/home/widgets/quick_reorder_section.dart',
        ).readAsStringSync();
        expect(src.contains('역산'), isTrue, reason: '허용 목록의 사유 주석');
      },
    );
  });

  group('원칙 2 · 클라이언트 선언값을 권위로 삼지 않는다 (F1)', () {
    List<String> fields(String path, String className) {
      final src = _code(path);
      final start = src.indexOf('const factory $className(');
      final end = src.indexOf('}) =', start);
      final body = src.substring(start, end);
      return [
        for (final m in RegExp(
          r'(?:required\s+)?(?:@Default\([^)]*\)\s*)?[\w<>?]+\s+(\w+),',
        ).allMatches(body))
          m.group(1)!,
      ];
    }

    test(
      'CartItemEntity / CartEntity 의 필드 집합이 고정이다 — 서버가 믿을 신뢰 필드를 추가하지 않는다',
      () {
        expect(
          fields(
            'lib/domain/entities/cart_item_entity.dart',
            '_CartItemEntity'.replaceFirst('_', ''),
          ),
          [
            'cartItemId',
            'menuItemId',
            'menuItemName',
            'imageUrl',
            'quantity',
            'selectedOptions',
            'unitPriceWithOptions',
            'lineTotal',
          ],
        );
        expect(fields('lib/domain/entities/cart_entity.dart', 'CartEntity'), [
          'storeId',
          'storeName',
          'items',
          'subtotal',
        ]);
      },
    );

    test(
      '서버: 금액 판정은 menuItemId · quantity · selectedOptions.{groupId,itemId} 만 읽고 선언된 priceDelta 는 읽지 않는다',
      () {
        final c = _code('functions/src/priceGate.ts');
        expect(c.contains('m.priceDelta'), isFalse);
        expect(RegExp(r'\.priceDelta\b').hasMatch(c), isFalse);
      },
    );
  });

  group('R13 · 모드 스위치 (서버 설정 전용)', () {
    test(
      'PAYMENT_PRICE_MODE 는 verifyTossPayment.ts 의 defineString 한 곳에서만 읽고 기본값은 off 다',
      () {
        final c = _code('functions/src/verifyTossPayment.ts');
        expect(
          c.contains('defineString("PAYMENT_PRICE_MODE", { default: "off" })'),
          isTrue,
        );
        expect(c.contains('resolvePriceMode(deps.priceMode?.())'), isTrue);
        expect(
          c.contains('priceMode !== "off"'),
          isTrue,
          reason: 'off 면 메뉴도 옵션 그룹도 읽지 않는다',
        );
        for (final f in _tsFiles) {
          if (f.path.endsWith('verifyTossPayment.ts')) continue;
          expect(
            _stripComments(f.readAsStringSync()).contains('PAYMENT_PRICE_MODE'),
            isFalse,
            reason: f.path,
          );
        }
      },
    );

    test('P7. 앱(admin 포함)에 모드 참조·토글이 없다', () {
      for (final f in _appFiles) {
        final c = f.readAsStringSync();
        expect(c.contains('PAYMENT_PRICE_MODE'), isFalse, reason: f.path);
        expect(c.contains('PAYMENT_GATE_MODE'), isFalse, reason: f.path);
      }
    });
  });

  group('문구 가드 (design §7.1) — 거절 화면·카트 가격 변동·시트', () {
    test('금지어(조작·비정상·위조·변조·부정·의심)가 문자열 상수 어디에도 없다', () {
      const banned = ['조작', '비정상', '위조', '변조', '부정', '의심'];
      for (final p in _copyFiles) {
        final c = _code(p);
        for (final w in banned) {
          expect(c.contains(w), isFalse, reason: '$p : "$w"');
        }
      }
    });

    test(
      '원 단위 숫자 정규식이 변형을 잡는다 (양성 대조: 17,000원 · 17000원 · 17000 원 · 17,000 원)',
      () {
        final re = RegExp(r'\d[\d,]*\s*원');
        for (final t in ['17,000원', '17000원', '17000 원', '17,000 원']) {
          expect(re.hasMatch(t), isTrue, reason: t);
        }
        expect(re.hasMatch('최신 가격으로 다시 담기'), isFalse);
      },
    );

    test('금지어 가드는 결제·카트 디렉터리 전체를 본다 (파일이 늘어도 무방비가 아니다)', () {
      expect(_copyFiles.length, greaterThanOrEqualTo(15));
      expect(
        _copyFiles.any((p) => p.endsWith('payment_menu_list_card.dart')),
        isTrue,
        reason: '이전 9파일 목록 밖이던 파일',
      );
    });

    test('문구에 마크다운 백틱이 없다 (F-04 재발 방지: 화면에 백틱이 그대로 찍힌다)', () {
      for (final p in _copyFiles) {
        expect(_code(p).contains('`'), isFalse, reason: p);
      }
    });

    test(
      '거절 화면 문구 상수에 원 단위 숫자가 없고, 거절 화면은 금액 포맷터를 쓰지 않는다 (Q6=ⓒ — 숫자는 카트에서)',
      () {
        final copy = _code(
          'lib/presentation/customer/checkout/payment_failure_copy.dart',
        );
        final result = _code(
          'lib/presentation/customer/checkout/payment_result_page.dart',
        );
        for (final c in [copy, result]) {
          expect(RegExp(r'\d[\d,]*\s*원').hasMatch(c), isFalse);
          expect(c.contains('PriceFormatter'), isFalse);
          expect(c.contains('price_formatter.dart'), isFalse);
        }
      },
    );

    test(
      '거절 화면에 서버 문자열이 보간되지 않는다 (D4) — failure 의 message/details 를 읽지 않는다',
      () {
        final result = _code(
          'lib/presentation/customer/checkout/payment_result_page.dart',
        );
        expect(
          RegExp(r'failure\.(message|details|toString)').hasMatch(result),
          isFalse,
        );
        expect(result.contains('.toString()'), isFalse);
        // 연산자 보간 `$name` 에서 쓰는 값은 코드 상수·카트 값뿐이다: rawCode 는 형식 검증을 통과한 식별자.
        expect(result.contains('widget.failure.rawCode'), isTrue);
      },
    );

    test(
      '가격 변동 위젯과 PRICE_MISMATCH 본문에 AppColors.success 가 없다 (내림은 info — 초록은 "검증 통과" 로 읽힌다)',
      () {
        for (final p in [
          'lib/presentation/customer/cart/widgets/cart_price_change_banner.dart',
          'lib/presentation/customer/cart/widgets/cart_line_tile.dart',
          'lib/presentation/customer/checkout/widgets/checkout_price_changed_sheet.dart',
          'lib/presentation/customer/checkout/payment_failure_copy.dart',
        ]) {
          expect(_code(p).contains('AppColors.success'), isFalse, reason: p);
        }
        final result = _code(
          'lib/presentation/customer/checkout/payment_result_page.dart',
        );
        final s = result.indexOf('class _PriceMismatchBody ');
        final e = result.indexOf('class _UnknownFailBody');
        expect(s, greaterThan(0));
        expect(e, greaterThan(s));
        expect(result.substring(s, e).contains('AppColors.success'), isFalse);
      },
    );

    test('Color(0x...) 하드코딩이 새 파일에 없다 (AppColors 토큰만 — 기존 파일의 선행 이슈는 범위 밖)', () {
      for (final p in const [
        'lib/presentation/customer/checkout/payment_failure_copy.dart',
        'lib/presentation/customer/checkout/widgets/checkout_price_changed_sheet.dart',
        'lib/presentation/customer/cart/widgets/cart_price_change_banner.dart',
        'lib/presentation/admin/widgets/admin_price_audit_card.dart',
      ]) {
        expect(RegExp(r'Color\(0x').hasMatch(_code(p)), isFalse, reason: p);
        expect(
          RegExp(r'Colors\.(white|black)').hasMatch(_code(p)),
          isFalse,
          reason: p,
        );
      }
    });

    test(
      'PaymentFailureAction.repriceAndReturn 은 PRICE_MISMATCH 기본형 주 버튼 하나에만 쓴다',
      () {
        final copy = _code(
          'lib/presentation/customer/checkout/payment_failure_copy.dart',
        );
        expect(
          RegExp(
            r'primaryAction:\s*PaymentFailureAction\.repriceAndReturn',
          ).allMatches(copy).length,
          1,
        );
        expect(
          RegExp(
            r'secondaryAction:\s*PaymentFailureAction\.repriceAndReturn',
          ).hasMatch(copy),
          isFalse,
        );
      },
    );

    test(
      'CartLineAvailability 에 "확인됨" 계열 값(verified / ok / priceChecked)이 없다',
      () {
        final c = _code(
          'lib/presentation/customer/cart/cart_line_availability.dart',
        );
        final enumBody = c.substring(
          c.indexOf('enum CartLineAvailability'),
          c.indexOf('}', c.indexOf('enum CartLineAvailability')),
        );
        for (final w in [
          'verified',
          'ok',
          'priceChecked',
          'checked',
          'confirmed',
        ]) {
          expect(RegExp('\\b$w\\b').hasMatch(enumBody), isFalse, reason: w);
        }
      },
    );
  });

  group('Firestore 쓰기 경로: 이력은 Rules 가 아니라 트리거 (R16)', () {
    test('priceHistory 는 클라이언트 쓰기가 없다 (앱 코드에 컬렉션 참조 0)', () {
      for (final f in _appFiles) {
        expect(
          f.readAsStringSync().contains('priceHistory'),
          isFalse,
          reason: f.path,
        );
      }
    });
  });
}

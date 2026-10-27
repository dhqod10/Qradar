import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// payment_server_authority 구조 가드 (spec §18.3 · §6.7) — tester 의 grep 항목을 파일 스캔으로 자동화한다.
/// 주석(`//`, `///`, `/* */`)은 설명을 위해 금지어를 언급하므로 스캔 전에 제거한다.
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

List<File> _files(String dir, String ext) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where(
      (f) =>
          f.path.endsWith(ext) &&
          !f.path.endsWith('.freezed.dart') &&
          !f.path.endsWith('.g.dart'),
    )
    .toList();

String _code(File f) => _stripComments(f.readAsStringSync());

void main() {
  group('TS: 판정 구현은 1곳', () {
    test(
      '1. soldOut / override status 비교는 functions/src/menuVisibility.ts 에만 있다',
      () {
        final offenders = <String>[];
        for (final f in _files('functions/src', '.ts')) {
          if (f.path.endsWith('menuVisibility.ts')) continue;
          final c = _code(f);
          if (RegExp(r'\bsoldOut\b').hasMatch(c) ||
              RegExp(r'excluded\b').hasMatch(c) ||
              RegExp(r'priceOverride').hasMatch(c)) {
            offenders.add(f.path);
          }
        }
        expect(
          offenders,
          isEmpty,
          reason: '메뉴 판정은 menuVisibility.ts 한 곳 (포팅, 복제 금지)',
        );
      },
    );

    test('2-a. 결제 게이트 TS 경로에 status 문자열 리터럴 비교가 없다 (canSellNow 만)', () {
      for (final p in [
        'functions/src/verifyTossPayment.ts',
        'functions/src/paymentGate.ts',
        'functions/src/paymentGateReader.ts',
      ]) {
        final c = _code(File(p));
        expect(
          RegExp(r'''['"](approved|pending|rejected)['"]''').hasMatch(c),
          isFalse,
          reason: '$p : 게이트 목적의 status 비교는 canSellNow 만',
        );
      }
    });
  });

  group('Dart: 결제 경로', () {
    final paymentDirs = [
      'lib/presentation/customer/checkout',
      'lib/presentation/customer/cart',
    ];

    test('2-b. checkout_* / cart_* 에 status·soldOut 직접 비교와 리터럴 비교가 없다', () {
      for (final dir in paymentDirs) {
        for (final f in _files(dir, '.dart')) {
          final c = _code(f);
          expect(
            RegExp(r'''['"](approved|pending|rejected)['"]''').hasMatch(c),
            isFalse,
            reason: '${f.path}: status 리터럴',
          );
          expect(
            RegExp(r'\.status\s*[!=]=').hasMatch(c),
            isFalse,
            reason: '${f.path}: status 직접 비교',
          );
          expect(
            RegExp(r'\.soldOut\s*[!=]=').hasMatch(c),
            isFalse,
            reason: '${f.path}: soldOut 직접 비교',
          );
        }
      }
    });

    test(
      '3. 게이트 판정 경로에서 EntityApprovalStatus.fromString 을 호출하지 않는다 (fail-open 복제 금지)',
      () {
        final gatePath = <File>[
          File('lib/core/utils/store_sellability.dart'),
          File('lib/core/utils/checkout_menu_gate.dart'),
          File('lib/domain/usecases/validate_checkout_use_case.dart'),
          File('lib/domain/entities/checkout_validation.dart'),
          File(
            'lib/data/datasources/remote/checkout_validation_remote_data_source.dart',
          ),
          for (final d in paymentDirs) ..._files(d, '.dart'),
        ];
        for (final f in gatePath) {
          expect(
            _code(f).contains('EntityApprovalStatus.fromString'),
            isFalse,
            reason: f.path,
          );
        }
      },
    );

    test('6. payment_result_page 가 원시 예외 문자열을 노출하지 않는다', () {
      final c = _code(
        File('lib/presentation/customer/checkout/payment_result_page.dart'),
      );
      expect(c.contains('.toString()'), isFalse);
      expect(c.contains('errorMessage'), isFalse);
      expect(RegExp(r'\$\{?e\b').hasMatch(c), isFalse);
      expect(c.contains('_mapErrorCode'), isFalse, reason: '원문 폴백을 가진 구 매핑 제거');
      final co = _code(
        File('lib/presentation/customer/checkout/checkout_page.dart'),
      );
      expect(co.contains('e.toString()'), isFalse);
    });

    test(
      'CartEntity / CartItemEntity 는 scope·brandId 를 갖지 않는다 (클라 선언값을 권위로 삼지 않는다, 원칙 2)',
      () {
        for (final p in [
          'lib/domain/entities/cart_entity.dart',
          'lib/domain/entities/cart_item_entity.dart',
        ]) {
          final c = _code(File(p));
          expect(RegExp(r'\bbrandId\b').hasMatch(c), isFalse, reason: p);
          expect(RegExp(r'\bscope\b').hasMatch(c), isFalse, reason: p);
        }
      },
    );
  });

  group('Dart: 삭제 · brandKey', () {
    test('4. 클라이언트 코드에 stores 하드 삭제가 없다', () {
      final offenders = <String>[];
      for (final f in _files('lib', '.dart')) {
        final c = _code(f);
        if (RegExp(
          r'''(_stores|collection\(\s*['"]stores['"]\s*\)|FirestorePaths\.stores\s*\))[^;]*\.delete\(\)''',
        ).hasMatch(c)) {
          offenders.add(f.path);
        }
      }
      expect(offenders, isEmpty);
    });

    test('5. 클라이언트 코드에 brandKey 쿼리가 없다 (조회는 lookupBrandByKey CF)', () {
      for (final f in _files('lib', '.dart')) {
        final c = _code(f);
        expect(
          RegExp(r'''where\(\s*['"]brandKey['"]''').hasMatch(c),
          isFalse,
          reason: f.path,
        );
      }
    });
  });

  group('Rules-A 성립 조건 (spec §6.5, 6-b)', () {
    String fnBody(String src, String name) {
      final start = src.indexOf(name);
      expect(start, greaterThanOrEqualTo(0), reason: name);
      final end = src.indexOf('};', start);
      return _stripComments(src.substring(start, end));
    }

    test(
      '6-b. StoreModel create payload 2개에 approvedBy/approvedAt/rejectedReason 키가 없다',
      () {
        final src = File('lib/data/models/store_model.dart').readAsStringSync();
        for (final name in [
          'toFirestoreForCreate',
          'toFirestoreForBrandCreate',
        ]) {
          final body = fnBody(src, name);
          for (final key in ['approvedBy', 'approvedAt', 'rejectedReason']) {
            expect(
              body.contains("'$key'"),
              isFalse,
              reason: '$name 에 $key 가 있으면 Rules-A 가 매장 등록을 전면 거부한다',
            );
          }
        }
      },
    );

    test('firestore.rules 의 stores create 가 승인 메타 3종을 막는다', () {
      final rules = File('firestore.rules').readAsStringSync();
      for (final key in ['approvedAt', 'approvedBy', 'rejectedReason']) {
        expect(
          rules.contains("get('$key', null) == null"),
          isTrue,
          reason: key,
        );
      }
    });
  });

  group('허용 목록 (spec §6.3 · §12 사실 1)', () {
    test('7. 고객 매장 목록 노출 필터는 게이트가 아니며 2번의 예외다 — 필터가 여전히 존재한다', () {
      // "보여줄까" vs "돈을 받을까" 는 다른 질문이다. 통합하지 않는다.
      final c = _code(File('lib/data/repositories/store_repository_impl.dart'));
      expect(c.contains('approved'), isTrue);
    });
  });
}

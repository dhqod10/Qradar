import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Qoin 적립률 계층화의 구조 규칙을 파일 스캔으로 지킨다 (tester 가 grep 으로 확인하는 항목의 자동화).
void main() {
  List<File> dartFiles(String dir) => Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (f) => f.path.endsWith('.dart') && !f.path.endsWith('.freezed.dart'),
      )
      .toList();

  String read(File f) => f.readAsStringSync();

  final qoinAdminPages = Directory('lib/presentation/admin/qoin')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('_page.dart'))
      .toList();

  const validationPhrases = [
    '이상 입력해주세요',
    '까지 입력할 수 있어요',
    '소수 첫째 자리',
    '2배 이상이거나',
  ];
  const allowedValidationFiles = [
    'qoin_rate_input_field.dart',
    'qoin_rate_confirm_dialog.dart',
  ];

  test('관리자 페이지가 있다 (스캔 대상 확인)', () {
    expect(qoinAdminPages.length, greaterThanOrEqualTo(6));
  });

  test('검증 문구는 공용 위젯 2개에만 존재한다', () {
    for (final f in dartFiles('lib')) {
      final text = read(f);
      for (final p in validationPhrases) {
        if (text.contains(p)) {
          expect(
            allowedValidationFiles.any(f.path.endsWith),
            isTrue,
            reason: '"$p" 가 ${f.path} 에 있다 — 공용 위젯 2개에만 있어야 한다',
          );
        }
      }
    }
  });

  test('범위 페이지가 validateRateInput 을 직접 호출하지 않는다', () {
    for (final f in qoinAdminPages) {
      expect(read(f).contains('validateRateInput'), isFalse, reason: f.path);
    }
  });

  test('경계 상수(minTenths / maxTenths)는 QoinPolicy 1곳에서만 선언한다', () {
    final decl = RegExp(
      r'(static\s+)?(const|final)\s+int\s+(minTenths|maxTenths)\b',
    );
    final hits = <String>[];
    for (final f in dartFiles('lib')) {
      if (decl.hasMatch(read(f))) hits.add(f.path);
    }
    expect(hits, ['lib/core/utils/qoin_policy.dart']);
  });

  test('presentation / domain 에서 Firebase 를 import 하지 않는다 (절대 규칙 2)', () {
    final bad = RegExp(
      r"import\s+'package:(cloud_firestore|cloud_functions|firebase_[a-z_]+)/",
    );
    for (final dir in ['lib/presentation', 'lib/domain']) {
      for (final f in dartFiles(dir)) {
        expect(bad.hasMatch(read(f)), isFalse, reason: f.path);
      }
    }
  });

  test('Color(0x…) 하드코딩이 없다 (신규 Qoin 파일, 절대 규칙 3)', () {
    final dirs = [
      'lib/presentation/admin/qoin',
      'lib/presentation/common/widgets/qoin',
    ];
    for (final dir in dirs) {
      for (final f in dartFiles(dir)) {
        expect(
          RegExp(r'Color\(\s*0x').hasMatch(read(f)),
          isFalse,
          reason: f.path,
        );
      }
    }
  });

  test('owner / brand / common 이 admin 화면을 import 하지 않는다 (역할 간 import)', () {
    final adminImport = RegExp(r"import\s+'package:qradar/presentation/admin/");
    for (final dir in [
      'lib/presentation/common/widgets/qoin',
      'lib/presentation/common/providers',
    ]) {
      for (final f in dartFiles(dir)) {
        expect(adminImport.hasMatch(read(f)), isFalse, reason: f.path);
      }
    }
  });

  test('적립률 쓰기는 Firestore 직접 쓰기가 아니다: data 레이어의 qoinAccrualRate 쓰기 맵 0건', () {
    // 모델/데이터소스에서 qoinAccrualRate 를 쓰는 맵 키로 선언하지 않는다 (읽기 전용 필드).
    final writeKey = RegExp('[\'"]qoinAccrualRate[\'"]\\s*:');
    for (final f in dartFiles('lib/data')) {
      expect(writeKey.hasMatch(read(f)), isFalse, reason: f.path);
    }
  });

  group('개정 2 (Q1/N4/F1) 구조 규칙', () {
    final qoinDirs = [
      'lib/presentation/admin/qoin',
      'lib/presentation/common/widgets/qoin',
      'lib/presentation/common/providers',
    ];
    Iterable<File> qoinFiles() sync* {
      for (final d in qoinDirs) {
        yield* dartFiles(d);
      }
    }

    test(
      'H-3: "asData?.value == null -> SizedBox.shrink()" 로 에러를 삼키는 패턴이 없다',
      () {
        // 같은 문장 안에서 `asData?.value` 가 null 이면 곧바로 shrink 하는 형태.
        final swallow = RegExp(
          r'asData\??\.value\s*==\s*null[\s\S]{0,80}SizedBox\.shrink',
        );
        for (final f in qoinFiles()) {
          expect(swallow.hasMatch(read(f)), isFalse, reason: f.path);
        }
      },
    );

    test(
      '허브: partial 배너/최근 변경은 AsyncValue.when 세 분기를 모두 구현하고 asData 로 에러를 삼키지 않는다',
      () {
        final hub = read(
          File('lib/presentation/admin/qoin/admin_qoin_settings_page.dart'),
        );
        final partial = hub.substring(
          hub.indexOf('class _PartialSection'),
          hub.indexOf('class _ScopeTile'),
        );
        final history = hub.substring(
          hub.indexOf('class _HistoryTile'),
          hub.indexOf('class _PartialSection'),
        );
        for (final block in [partial, history]) {
          expect(block.contains('.when('), isTrue);
          expect(block.contains('loading:'), isTrue);
          expect(block.contains('error:'), isTrue);
          expect(block.contains('data:'), isTrue);
          expect(block.contains('.asData'), isFalse);
        }
        // 중단 판정의 데이터 출처는 브랜드 포인터이지 이력 쿼리가 아니다 (D-1).
        expect(partial.contains('qoinUnfinishedBulkBrandsProvider'), isTrue);
        expect(partial.contains('qoinAllRateHistoryProvider'), isFalse);
      },
    );

    test(
      '삭제된 개념이 lib/ 에 남아 있지 않다 (explicitOffRate / allowZero / clearedZeroCount / skipped_rate_zero)',
      () {
        const gone = [
          'explicitOffRate',
          'allowZero',
          'clearedZeroCount',
          'skipped_rate_zero',
          'overriddenStopped',
        ];
        for (final f in dartFiles('lib')) {
          final t = read(f);
          for (final g in gone) {
            expect(t.contains(g), isFalse, reason: '$g in ${f.path}');
          }
        }
      },
    );

    test('design §18-12 삭제 대상 문구가 lib/ 에 없다', () {
      const gone = [
        '적립 안 함 (0%)',
        '0% · 적립 안 함',
        '그중 적립 안 함',
        '개별 설정 \$_clearCount곳이 지워지는 것을 확인했어요',
        '지워지는 것을 확인했어요',
        '적립 안 함 (0%) 으로 설정했어요',
        '새 설정 적립 안 함',
        '의 설정(적립 안 함)을 따라요',
        '→ 적립 없음',
        '\'적립 안 함\'',
      ];
      // `결제 N원 → 적립 없음` 은 스위치 카드/현재 값 카드의 별개 문구라 허용(위 `→ 적립 없음` 은 환산 변형).
      for (final f in dartFiles('lib')) {
        final t = read(f);
        for (final g in gone) {
          if (g == '→ 적립 없음') {
            // 환산 줄 변형(`500 Q → 적립 없음` / `적립 없음 → …`)만 금지. `결제 … → 적립 없음` 은 허용.
            expect(
              RegExp(r"Q\s*→ 적립 없음|적립 없음 →").hasMatch(t),
              isFalse,
              reason: '$g in ${f.path}',
            );
            continue;
          }
          expect(t.contains(g), isFalse, reason: '$g in ${f.path}');
        }
      }
    });

    test('data 레이어 어떤 쓰기 맵에도 qoin 스위치·포인터 키가 없다 (CF 전담)', () {
      final writeKey = RegExp(
        '[\'"](qoinAccrualEnabled|qoinBulkHistoryId|qoinBulkStatus|qoinBulkAt)[\'"]\\s*:',
      );
      for (final f in dartFiles('lib/data')) {
        expect(writeKey.hasMatch(read(f)), isFalse, reason: f.path);
      }
    });

    test('과도기 자산: 마이그레이션 카드는 한 파일, 허브에는 마운트 한 줄만', () {
      final hub = read(
        File('lib/presentation/admin/qoin/admin_qoin_settings_page.dart'),
      );
      expect(
        RegExp(r'const AdminQoinMigrationCard\(\)').allMatches(hub),
        hasLength(1),
      );
      // 카드의 상태·provider·UseCase 호출은 카드 파일 안에 있다.
      final card = read(
        File(
          'lib/presentation/admin/qoin/widgets/admin_qoin_migration_card.dart',
        ),
      );
      expect(card.contains('qoinZeroMigrationUseCaseProvider'), isTrue);
      // 다른 곳에서 카드 파일이나 마이그레이션 UseCase 를 쓰지 않는다.
      for (final f in dartFiles('lib')) {
        if (f.path.endsWith('admin_qoin_migration_card.dart') ||
            f.path.endsWith('admin_qoin_settings_page.dart')) {
          continue;
        }
        final t = read(f);
        if (f.path.contains('qoin_zero_migration') ||
            f.path.endsWith('migrate_qoin_zero_rates_use_case.dart')) {
          continue;
        }
        expect(
          t.contains('admin_qoin_migration_card'),
          isFalse,
          reason: f.path,
        );
        expect(
          t.contains('MigrateQoinZeroRatesUseCase'),
          isFalse,
          reason: f.path,
        );
      }
    });

    test('TRANSITIONAL 표식이 정리 커밋의 grep 대상으로 모여 있다', () {
      final marked = <String>[];
      for (final f in dartFiles('lib')) {
        if (read(f).contains('TRANSITIONAL(spec §20.4.5)')) marked.add(f.path);
      }
      expect(
        marked,
        containsAll([
          'lib/core/utils/qoin_rate_resolver.dart',
          'lib/presentation/admin/qoin/widgets/admin_qoin_migration_card.dart',
          'lib/domain/usecases/migrate_qoin_zero_rates_use_case.dart',
        ]),
      );
    });

    test('QoinReenableHint 문장을 위젯에서 조립하지 않는다 (resolver 결과로만)', () {
      for (final f in qoinFiles()) {
        if (f.path.endsWith('qoin_reenable_hint.dart')) continue;
        final t = read(f);
        expect(t.contains('다시 켜면 브랜드'), isFalse, reason: f.path);
        expect(t.contains('다시 켜도 브랜드가'), isFalse, reason: f.path);
      }
    });
  });
}

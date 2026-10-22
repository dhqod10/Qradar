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

  // ════════════════════════════════════════════════════════════════════════════
  // 개정 4 (spec §21): S6 과도기 자산 목록 · S1 판정 출처 · S3 changed 소비 · 보안 task 구조 규칙
  // ════════════════════════════════════════════════════════════════════════════
  group('S6: 과도기 자산 — 기계가 목록을 소유한다 (마커가 아니라 토큰을 grep)', () {
    // 레거시를 실제로 만드는 토큰. 마커는 사람에게 보여주는 표지이고, 기계가 보는 것은 이 토큰이다.
    const tokens = [
      'legacyZero',
      'isLegacyZero',
      'QoinRateCellKind.legacyZero',
      'resolve_legacy',
      'transitionalExpect',
      'legacyZeroCount',
      'LEGACY_MESSAGE_PREFIX',
      'migrateQoinZeroRates',
      'migratedFromRate',
      'auditBrandLinks',
    ];
    const scanDirs = [
      'lib',
      'functions/src',
      'functions/test',
      'test',
      'test_fixtures',
    ];
    // 이 테스트 파일 자신은 토큰을 선언하므로 제외한다. 생성 파일(freezed/g)은 원본(.dart)이 마커를 가진다.
    const selfPath = 'test/presentation/qoin_architecture_guard_test.dart';

    /// **허용 목록** — 정리 커밋(spec §20.4.5 6·7 / 보안 task §8-A2)에서 토큰을 제거하면서 이 목록을 빈 집합으로 만든다.
    /// 새 파일에 레거시 분기를 넣으면 이 목록에 추가해야 테스트가 통과하고, 추가하는 순간 마커도 요구받는다.
    const allowed = <String>[
      'functions/src/applyBrandQoinRate.ts',
      'functions/src/auditBrandLinks.ts',
      'functions/src/index.ts',
      'functions/src/migrateQoinZeroRates.ts',
      'functions/src/qoinAdmin.ts',
      'functions/src/qoinRate.ts',
      'functions/src/setQoinAccrualRate.ts',
      'functions/test/emulator.test.mjs',
      'functions/test/qoinRate.test.mjs',
      'lib/core/errors/qoin_rate_exception.dart',
      'lib/core/utils/qoin_rate_resolver.dart',
      'lib/data/datasources/remote/brand_link_audit_remote_data_source.dart',
      'lib/data/datasources/remote/qoin_callable.dart',
      'lib/data/datasources/remote/qoin_zero_migration_remote_data_source.dart',
      'lib/data/models/qoin_config_model.dart',
      'lib/data/models/qoin_rate_change_model.dart',
      'lib/domain/entities/brand_link_audit_result.dart',
      'lib/domain/entities/qoin_rate_change_entity.dart',
      'lib/domain/entities/qoin_zero_migration_result.dart',
      'lib/presentation/admin/qoin/admin_qoin_settings_page.dart',
      'lib/presentation/admin/qoin/widgets/qoin_admin_ui.dart',
      'lib/presentation/admin/qoin/widgets/qoin_rate_chain.dart',
      'lib/presentation/admin/widgets/admin_brand_link_audit_card.dart',
      'lib/presentation/common/widgets/qoin/qoin_rate_labels.dart',
      'lib/presentation/common/widgets/qoin/qoin_reenable_hint.dart',
      'test/data/qoin_rate_models_test.dart',
      'test/domain/qoin_rate_resolution_test.dart',
      'test/presentation/brand_link_audit_card_test.dart',
      'test/presentation/qoin_history_tile_test.dart',
      'test_fixtures/qoin_rate_truth_table.json',
    ];
    final markerRe = RegExp(
      r'TRANSITIONAL\(spec §20\.4\.5\)|TRANSITIONAL\(brand_authorization_hardening §4\)',
    );

    /// 저장소 전체를 토큰으로 grep 해 나온 파일 집합.
    Set<String> found() {
      final hits = <String>{};
      for (final dir in scanDirs) {
        for (final e in Directory(dir).listSync(recursive: true)) {
          if (e is! File) continue;
          final path = e.path;
          if (path.contains('/node_modules/') || path.contains('/lib/lib/')) {
            continue;
          }
          if (path == selfPath) continue;
          if (path.endsWith('.freezed.dart') || path.endsWith('.g.dart')) {
            continue;
          }
          final isText =
              path.endsWith('.dart') ||
              path.endsWith('.ts') ||
              path.endsWith('.mjs') ||
              path.endsWith('.json');
          if (!isText) continue;
          final t = read(e);
          if (tokens.any(t.contains)) hits.add(path);
        }
      }
      return hits;
    }

    test('토큰으로 grep 한 파일 집합 == 허용 목록 (초과도 FAIL, 누락도 FAIL)', () {
      final actual = found();
      final expected = allowed.toSet();
      expect(
        actual.difference(expected).toList()..sort(),
        isEmpty,
        reason: '허용 목록에 없는 파일이 레거시 토큰을 쓴다 — 목록에 추가하고 마커를 붙이거나 토큰을 제거하라',
      );
      expect(
        expected.difference(actual).toList()..sort(),
        isEmpty,
        reason: '허용 목록에 있는데 토큰이 사라진 파일 — 목록에서 지워라 (정리가 진행된 것이다)',
      );
    });

    test('허용 목록의 모든 파일에 마커가 있다 (JSON 은 _transitional 메타 키)', () {
      for (final path in allowed) {
        final f = File(path);
        expect(f.existsSync(), isTrue, reason: '$path 없음');
        final t = read(f);
        if (path.endsWith('.json')) {
          expect(t.contains('"_transitional"'), isTrue, reason: path);
        } else {
          expect(
            markerRe.hasMatch(t),
            isTrue,
            reason: '$path 에 TRANSITIONAL 마커 없음',
          );
        }
      }
    });

    test('truth table 의 _transitional 메타 키는 정리 대상(배열·키)을 가리킨다', () {
      final t = read(File('test_fixtures/qoin_rate_truth_table.json'));
      expect(t.contains('"resolve_legacy"'), isTrue);
      expect(t.contains('"transitionalExpect"'), isTrue);
      final meta = RegExp(r'"_transitional"\s*:\s*\{[^}]*\}').firstMatch(t);
      expect(meta, isNotNull);
      expect(meta!.group(0)!.contains('resolve_legacy'), isTrue);
      expect(meta.group(0)!.contains('transitionalExpect'), isTrue);
    });
  });

  group('S1/R3: 중단 판정은 판정 함수 한 곳에서만', () {
    const judgeFile = 'lib/domain/entities/qoin_bulk_banner.dart';
    // 브랜드 문서가 포인터 값을 "싣는" 파일 (판정이 아니라 필드 운반).
    const carriers = <String>[
      'lib/domain/entities/brand_entity.dart',
      'lib/data/models/brand_model.dart',
      'lib/core/constants/firestore_paths.dart',
    ];

    test(
      '`isUnfinished(` 호출과 `qoinBulkStatus` 직접 비교는 resolveBulkBanner 가 있는 파일 1곳에서만 나온다',
      () {
        final directCompare = RegExp(
          r'qoinBulkStatus\s*(==|!=)|(==|!=)\s*[\w.]*qoinBulkStatus\b|\.qoinBulkStatus\b',
        );
        final isUnfinishedCall = RegExp(r'\bisUnfinished\s*\(');
        for (final f in dartFiles('lib')) {
          final p = f.path;
          final t = read(f);
          if (p == judgeFile) {
            expect(t.contains('resolveBulkBanner'), isTrue);
            continue;
          }
          expect(
            isUnfinishedCall.hasMatch(t),
            isFalse,
            reason:
                '$p 가 isUnfinished( 를 호출한다 — 판정 함수(resolveBulkBanner)를 통과해야 한다',
          );
          if (carriers.contains(p)) continue;
          expect(
            directCompare.hasMatch(t),
            isFalse,
            reason: '$p 가 qoinBulkStatus 를 직접 읽는다 — 판정 함수 밖에서 원시 출처를 읽는다',
          );
        }
      },
    );

    test('허브 · 브랜드 목록 · 브랜드 편집 3곳이 같은 판정 함수를 호출한다', () {
      for (final p in const [
        'lib/presentation/admin/qoin/providers/qoin_admin_providers.dart', // 허브 배너(_PartialSection 이 이 provider 를 쓴다)
        'lib/presentation/admin/qoin/admin_qoin_brand_rates_page.dart',
        'lib/presentation/admin/qoin/admin_qoin_brand_rate_edit_page.dart',
        'lib/presentation/common/widgets/qoin/qoin_rate_info_row.dart', // 브랜드 읽기 화면
        'lib/presentation/common/widgets/qoin/qoin_rate_history_tile.dart', // 이력 행(포인터 일치 조건)
      ]) {
        expect(read(File(p)).contains('resolveBulkBanner('), isTrue, reason: p);
      }
    });

    test('브랜드 편집 페이지는 이력 스트림을 중단 판정에 쓰지 않는다 (PROBE1)', () {
      final t = read(
        File(
          'lib/presentation/admin/qoin/admin_qoin_brand_rate_edit_page.dart',
        ),
      );
      expect(t.contains('qoinRateHistoryProvider'), isFalse);
      expect(t.contains('qoinBulkHistoryDocProvider'), isTrue); // 수치만 이력 문서 1건
    });
  });

  group('S3-b: Qoin 쓰기 응답을 소비하는 모든 화면이 changed 를 읽는다', () {
    // 쓰기 응답을 만드는 진입점. 정의 파일(provider 정의 · runBulkResume 정의)은 소비자가 아니다.
    const entryPoints = [
      'setQoinAccrualRateUseCaseProvider',
      'setQoinAccrualEnabledUseCaseProvider',
      'applyBrandQoinRateUseCaseProvider',
      'runBulkResume(',
    ];
    const definers = [
      'lib/presentation/common/providers/qoin_di_providers.dart',
      'lib/presentation/admin/qoin/widgets/qoin_bulk_resume.dart',
    ];
    const successPhrases = [
      'QoinMessages.saved(',
      'QoinMessages.switchChanged(',
      "'적용을 마쳤어요'",
    ];

    test('소비 화면은 changed 를 읽고, changed 분기가 성공 문구보다 앞선다', () {
      final consumers = <String>[];
      for (final f in dartFiles('lib/presentation')) {
        if (definers.any(f.path.endsWith)) continue;
        final t = read(f);
        if (entryPoints.any(t.contains)) consumers.add(f.path);
      }
      // 현재 소비자: 전역 · 매장 편집, 스위치 카드, 브랜드 편집, 이력 화면 (사라지면 이 테스트가 먼저 알려준다).
      expect(
        consumers.length,
        greaterThanOrEqualTo(5),
        reason: consumers.join('\n'),
      );
      for (final p in consumers) {
        final t = read(File(p));
        final readsChanged = RegExp(r'\.changed\b').hasMatch(t);
        expect(
          readsChanged,
          isTrue,
          reason: '$p 가 쓰기 응답을 소비하는데 changed 를 읽지 않는다',
        );
        final firstChanged = t.indexOf(RegExp(r'!\s*\w+\.changed\b'));
        for (final phrase in successPhrases) {
          final at = t.indexOf(phrase);
          if (at < 0) continue;
          expect(
            firstChanged,
            isNonNegative,
            reason: '$p: changed==false 분기가 없다',
          );
          expect(
            firstChanged < at,
            isTrue,
            reason: '$p: changed==false 분기가 성공 문구($phrase)보다 뒤에 있다',
          );
        }
      }
    });

    test('changed==false 경로의 문구에 성공 동사가 없다', () {
      const forbidden = ['변경했어요', '적용했어요', '적용을 마쳤어요', '시작했어요', '중단했어요'];
      final ui = read(
        File('lib/presentation/admin/qoin/widgets/qoin_admin_ui.dart'),
      );
      final start = ui.indexOf('static const String alreadyTitle');
      final end = ui.indexOf('/// 스위치 변경 성공 SnackBar');
      expect(start, isNonNegative);
      expect(end, greaterThan(start));
      // 문서 주석(///, //)은 금지어를 설명하므로 제외하고 코드·문자열만 본다.
      final block = ui
          .substring(start, end)
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      for (final w in forbidden) {
        expect(
          block.contains(w),
          isFalse,
          reason: '"$w" 가 changed:false 문구에 있다',
        );
      }
    });
  });

  group('보안 task: 브랜드 권한 구조 규칙', () {
    test('data 레이어가 users 문서에 brandId 를 쓰지 않는다 (CF 전담)', () {
      for (final f in dartFiles('lib/data')) {
        final t = read(f);
        // users 컬렉션 경로를 쓰는 파일에서 brandId 를 쓰기 맵 키로 선언하지 않는다.
        if (!t.contains('FirestorePaths.users')) continue;
        expect(
          RegExp('[\'"]brandId[\'"]\\s*:').hasMatch(t),
          isFalse,
          reason: f.path,
        );
      }
      final repo = read(
        File('lib/data/repositories/brand_repository_impl.dart'),
      );
      expect(repo.contains('FirestorePaths.users'), isFalse);
      expect(repo.contains('.batch()'), isFalse);
    });

    test("승인 화면에 '브랜드' 이름 폴백이 없다 (조회 실패·미존재를 가짜 이름으로 덮지 않는다)", () {
      // 매장 승인 표면(배지 · 상세 · 대기 목록)만 본다. 메뉴 승인 큐의 브랜드 묶음 타일은 다른 표면이다.
      final fallback = RegExp("\\?\\?\\s*'브랜드'");
      for (final p in const [
        'lib/presentation/admin/widgets/brand_scope_badge.dart',
        'lib/presentation/admin/widgets/store_brand_block.dart',
        'lib/presentation/admin/approval/admin_store_approval_detail_page.dart',
        'lib/presentation/admin/approval/admin_pending_stores_page.dart',
      ]) {
        expect(fallback.hasMatch(read(File(p))), isFalse, reason: p);
      }
    });

    test('매장 승인 배지·상세·승인 버튼이 같은 분류 함수를 공유한다', () {
      for (final p in const [
        'lib/presentation/admin/providers/admin_store_brand_link_providers.dart',
      ]) {
        expect(
          read(File(p)).contains('resolveStoreBrandLink('),
          isTrue,
          reason: p,
        );
      }
      for (final p in const [
        'lib/presentation/admin/widgets/brand_scope_badge.dart',
        'lib/presentation/admin/approval/admin_store_approval_detail_page.dart',
      ]) {
        expect(
          read(File(p)).contains('storeBrandLinkProvider'),
          isTrue,
          reason: p,
        );
      }
    });

    test('브랜드 링크 점검 카드: 쓰기 호출 코드가 없고 허브 마운트는 한 줄이다', () {
      final card = read(
        File('lib/presentation/admin/widgets/admin_brand_link_audit_card.dart'),
      );
      for (final w in const ['.set(', '.update(', '.delete(', 'dryRun']) {
        expect(card.contains(w), isFalse, reason: w);
      }
      final ds = read(
        File(
          'lib/data/datasources/remote/brand_link_audit_remote_data_source.dart',
        ),
      );
      expect(ds.contains('dryRun'), isFalse);
      final hub = read(
        File('lib/presentation/admin/qoin/admin_qoin_settings_page.dart'),
      );
      expect(
        RegExp(r'const AdminBrandLinkAuditCard\(\)').allMatches(hub),
        hasLength(1),
      );
      // 카드 파일 밖에서 점검 UseCase 를 쓰지 않는다.
      for (final f in dartFiles('lib')) {
        if (f.path.contains('brand_link_audit') ||
            f.path.endsWith('audit_brand_links_use_case.dart') ||
            f.path.endsWith('admin_brand_link_audit_card.dart') ||
            f.path.endsWith('admin_qoin_settings_page.dart')) {
          continue;
        }
        expect(
          read(f).contains('AuditBrandLinksUseCase'),
          isFalse,
          reason: f.path,
        );
      }
    });

    test('등록 폼은 BrandScaffold 게이트 안에서만 직접 그려진다 (조회 전·실패 시 폼 금지)', () {
      final scaffold = read(File('lib/presentation/brand/brand_scaffold.dart'));
      expect(scaffold.contains('BrandInfoFormPage'), isFalse);
      expect(scaffold.contains('BrandIdMissingView'), isTrue);
      final view = read(
        File('lib/presentation/brand/brand_id_missing_view.dart'),
      );
      // 폼은 NeedsRegistration 분기 한 곳에서만 나온다.
      expect(RegExp(r'BrandInfoFormPage\(').allMatches(view), hasLength(1));
      expect(
        view.indexOf('BrandGateNeedsRegistration') <
            view.indexOf('BrandInfoFormPage('),
        isTrue,
      );
    });
  });
}

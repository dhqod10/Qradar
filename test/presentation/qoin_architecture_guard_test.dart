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
}

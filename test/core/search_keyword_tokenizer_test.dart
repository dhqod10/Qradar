import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/utils/search_keyword_tokenizer.dart';
import 'package:qradar/data/models/store_model.dart';

void main() {
  final golden =
      jsonDecode(File('test_fixtures/search_keyword_contract.json').readAsStringSync())
          as Map<String, dynamic>;

  test('golden: maxKeywords 상수가 계약과 일치', () {
    expect(SearchKeywordTokenizer.maxKeywords, golden['maxKeywords']);
  });

  for (final c in (golden['build'] as List)) {
    test('golden build: ${c['name']}', () {
      expect(
        SearchKeywordTokenizer.buildKeywords(List<String>.from(c['sources'] as List)),
        List<String>.from(c['expect'] as List),
      );
    });
  }

  test('golden buildCap', () {
    final c = golden['buildCap'] as Map<String, dynamic>;
    expect(
      SearchKeywordTokenizer.buildKeywords(
        List<String>.from(c['sources'] as List),
        maxKeywords: c['max'] as int,
      ),
      List<String>.from(c['expect'] as List),
    );
  });

  for (final c in (golden['query'] as List)) {
    test('golden query: ${jsonEncode(c['raw'])}', () {
      expect(
        SearchKeywordTokenizer.queryTokens(c['raw'] as String),
        List<String>.from(c['expect'] as List),
      );
    });
  }

  test('기본 상한 300 초과 입력은 잘린다', () {
    expect(
      SearchKeywordTokenizer.buildKeywords([List.filled(200, 'a').join(), List.filled(200, 'b').join()]).length,
      300,
    );
  });

  test('StoreModel.searchKeywords 는 읽기 전용 — 어떤 toFirestore 맵에도 없다', () {
    final m = StoreModel(
      id: 's', name: 'n', imageUrl: '', latitude: 1, longitude: 2,
      averageScore: 0, reviewCount: 0, menuCategories: const ['coffee'],
      createdAt: DateTime(2026), searchKeywords: const ['n'],
    );
    expect(m.toEntity().searchKeywords, ['n']);
    expect(m.toFirestoreForCreate().containsKey('searchKeywords'), isFalse);
    expect(m.toFirestoreForCoreUpdate(isResubmit: false).containsKey('searchKeywords'), isFalse);
    expect(m.toFirestoreForOperationUpdate().containsKey('searchKeywords'), isFalse);
    expect(m.toFirestoreForBrandCreate().containsKey('searchKeywords'), isFalse);
  });
}

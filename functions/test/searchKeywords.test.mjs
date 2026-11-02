// search_keyword_enhancement — 토크나이저 cross-golden(Dart↔TS 동일 벡터) + 트리거 게이트 + 소스 조립.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildKeywords, queryTokens, sameKeywords, MAX_KEYWORDS } from '../lib/searchKeywords.js';
import { storeSearchSourceChanged, brandNameChanged } from '../lib/onSearchKeywordsSourceWritten.js';
import { assembleSources } from '../lib/recomputeSearchKeywords.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const golden = JSON.parse(fs.readFileSync(path.join(here, '../../test_fixtures/search_keyword_contract.json'), 'utf8'));
const src = (n) => fs.readFileSync(path.join(here, '../src', n), 'utf8');

test('golden: maxKeywords 상수가 계약과 일치', () => assert.equal(MAX_KEYWORDS, golden.maxKeywords));
for (const c of golden.build) {
  test(`golden build: ${c.name}`, () => assert.deepEqual(buildKeywords(c.sources), c.expect));
}
test('golden buildCap', () => assert.deepEqual(buildKeywords(golden.buildCap.sources, golden.buildCap.max), golden.buildCap.expect));
for (const c of golden.query) {
  test(`golden query: ${JSON.stringify(c.raw)}`, () => assert.deepEqual(queryTokens(c.raw), c.expect));
}

test('기본 상한 300 초과 입력은 잘린다', () => {
  const r = buildKeywords(['a'.repeat(200), 'b'.repeat(200)]);
  assert.equal(r.length, 300);
});

test('sameKeywords: 순서 포함 비교, 비배열은 다름', () => {
  assert.equal(sameKeywords(['a', 'b'], ['a', 'b']), true);
  assert.equal(sameKeywords(['b', 'a'], ['a', 'b']), false);
  assert.equal(sameKeywords(undefined, []), false);
});

test('트리거 게이트: 생성은 true, 삭제는 false', () => {
  assert.equal(storeSearchSourceChanged(undefined, { name: 'a' }), true);
  assert.equal(storeSearchSourceChanged({ name: 'a' }, undefined), false);
});
test('트리거 게이트: searchKeywords 만 바뀐 쓰기는 무시 (루프 가드)', () => {
  assert.equal(storeSearchSourceChanged({ name: 'a', searchKeywords: [] }, { name: 'a', searchKeywords: ['a'] }), false);
});
test('트리거 게이트: 무관 필드(phone, 평점)만 바뀌면 무시', () => {
  assert.equal(storeSearchSourceChanged({ name: 'a', phone: '1' }, { name: 'a', phone: '2', averageScore: 4 }), false);
});
test('트리거 게이트: name/brandId/menuCategories 변경은 true', () => {
  assert.equal(storeSearchSourceChanged({ name: 'a' }, { name: 'b' }), true);
  assert.equal(storeSearchSourceChanged({ name: 'a' }, { name: 'a', brandId: 'x' }), true);
  assert.equal(storeSearchSourceChanged({ name: 'a', menuCategories: ['coffee'] }, { name: 'a', menuCategories: ['coffee', 'dessert'] }), true);
});
test('브랜드 게이트: name 변경만 true, 생성/삭제/무관 변경은 false', () => {
  assert.equal(brandNameChanged({ name: 'a' }, { name: 'b' }), true);
  assert.equal(brandNameChanged({ name: 'a', x: 1 }, { name: 'a', x: 2 }), false);
  assert.equal(brandNameChanged(undefined, { name: 'a' }), false);
  assert.equal(brandNameChanged({ name: 'a' }, undefined), false);
});

test('소스 조립: 매장명 + 브랜드명 + menuCategories (문자열만)', () => {
  assert.deepEqual(assembleSources({ name: 'N', menuCategories: ['coffee', 3, 'dessert'] }, 'B'), ['N', 'B', 'coffee', 'dessert']);
  assert.deepEqual(assembleSources({ name: 'N' }, null), ['N']);
});

test('소스 가드: backfill 은 dryRun 기본 + migrationHistory, 코어는 searchKeywords 1필드만 쓴다', () => {
  const b = src('backfillStoreSearchKeywords.ts');
  assert.match(b, /dryRun\?: unknown[\s\S]*!== false/);
  assert.match(b, /migrationHistory/);
  assert.match(b, /requireAdmin/);
  assert.match(src('recomputeSearchKeywords.ts'), /batch\.update\(.*\{ \[FIELD\]: p\.after \}\)/);
});

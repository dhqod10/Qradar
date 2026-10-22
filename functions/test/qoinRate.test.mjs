// qoinRate.ts 단위 테스트 — `npm test` (functions/ 에서). 환경 불필요.
// 진리표는 Dart 테스트(test/domain/qoin_rate_resolution_test.dart)와 같은 파일을 읽는다.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import {
  MIN_RATE, MAX_RATE, classifyRate, resolveEffectiveRate, isValidCallableRate, computeEarnAmount,
} from '../lib/qoinRate.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const table = JSON.parse(
  fs.readFileSync(path.join(here, '../../test_fixtures/qoin_rate_truth_table.json'), 'utf8'));

/** 픽스처 셀 표기 → 실제 값. 'absent' 는 undefined (필드 부재). */
function decode(cell) {
  if (cell === 'absent') return undefined;
  if (cell === 'nan') return NaN;
  if (cell === 'null') return null;
  if (typeof cell === 'string' && cell.startsWith('str:')) return cell.slice(4);
  return cell;
}

test('경계 상수는 화면(0.1~20%)과 같다', () => {
  assert.equal(MIN_RATE, 0.001);
  assert.equal(MAX_RATE, 0.2);
});

for (const row of table.resolve) {
  test(`resolve ${row.id}`, () => {
    const r = resolveEffectiveRate(
      classifyRate(decode(row.store)),
      classifyRate(decode(row.brand)),
      classifyRate(decode(row.global), false));
    if (row.expect.invalid) {
      assert.equal(r.ok, false);
      assert.equal(r.reason, `invalid_${row.expect.invalid}`);
    } else {
      assert.equal(r.ok, true);
      assert.equal(r.rate, row.expect.rate);
      assert.equal(r.source, row.expect.source);
    }
  });
}

for (const row of table.classify) {
  test(`classify ${row.raw} allowZero=${row.allowZero}`, () => {
    assert.equal(classifyRate(decode(row.raw), row.allowZero).kind, row.expect);
  });
}

for (const row of table.callable) {
  test(`callable ${row.raw} allowZero=${row.allowZero}`, () => {
    assert.equal(isValidCallableRate(decode(row.raw), row.allowZero), row.expect);
  });
}

test('산식: floor, ppm 정수 환산 (4500*0.03=135)', () => {
  assert.equal(computeEarnAmount(4500, 0.03), 135);
  assert.equal(computeEarnAmount(10000, 0.001), 10);
  assert.equal(computeEarnAmount(999, 0.001), 0);
});

test('경계 상수는 qoinRate.ts 1곳에서만 선언된다 (F3 재발 방지)', () => {
  const src = path.join(here, '../src');
  const decl = [];
  const literal = [];
  for (const f of fs.readdirSync(src)) {
    if (!f.endsWith('.ts')) continue;
    const text = fs.readFileSync(path.join(src, f), 'utf8');
    if (/\b(MIN_RATE|MAX_RATE)\s*=/.test(text)) decl.push(f);
    // 주석을 제외한 코드에서 경계 리터럴(0.001 / 0.2)이 다른 파일에 있으면 중복 선언이다.
    const code = text.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');
    if (f !== 'qoinRate.ts' && /(?<![\d.])(0\.001|0\.2)(?![\d])/.test(code)) literal.push(f);
  }
  assert.deepEqual(decl, ['qoinRate.ts']);
  assert.deepEqual(literal, []);
});

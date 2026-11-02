// qoinRate.ts 단위 테스트 — `npm test` (functions/ 에서). 환경 불필요.
// 진리표는 Dart 테스트(test/domain/qoin_rate_resolution_test.dart)와 같은 파일을 읽는다.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import {
  MIN_RATE, MAX_RATE, BULK_STALE_MS, classifyRate, classifySwitch, resolveEffectiveRate, isValidCallableRate, isValidCallableSwitch,
  computeEarnAmount,
} from '../lib/qoinRate.js';
import { buildOrderData, buildOrderLogData, CONSUMED_CART_KEYS, CONSUMED_INPUT_KEYS, CONSUMED_ITEM_KEYS, CONSUMED_OPTION_KEYS } from '../lib/orderBuilder.js';
import { describeRaw, BULK_STATUS } from '../lib/qoinAdmin.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const table = JSON.parse(
  fs.readFileSync(path.join(here, '../../test_fixtures/qoin_rate_truth_table.json'), 'utf8'));
const cartContract = JSON.parse(
  fs.readFileSync(path.join(here, '../../test_fixtures/qoin_cart_contract.json'), 'utf8'));

/** 픽스처 셀 표기 → 실제 값. 'absent' 는 undefined (필드 부재). */
function decode(cell) {
  if (cell === 'absent') return undefined;
  if (cell === 'nan') return NaN;
  if (cell === 'null') return null;
  if (typeof cell === 'string' && cell.startsWith('str:')) return cell.slice(4);
  return cell;
}


/** resolve 5입력 해석 (fixture 행 → 결과). */
function resolveRow(row) {
  return resolveEffectiveRate(
    classifySwitch(decode(row.storeEnabled ?? 'absent')),
    classifyRate(decode(row.store)),
    classifySwitch(decode(row.brandEnabled ?? 'absent')),
    classifyRate(decode(row.brand)),
    classifyRate(decode(row.global)));
}

function assertResolved(r, exp) {
  if (exp.invalid) {
    assert.equal(r.ok, false);
    assert.equal(r.reason, `invalid_${exp.invalid}`);
  } else if (exp.disabled) {
    assert.equal(r.ok, true);
    assert.equal(r.disabled, true);
    assert.equal(r.source, exp.disabled);
  } else {
    assert.equal(r.ok, true);
    assert.equal(r.disabled, false);
    assert.equal(r.rate, exp.rate);
    assert.equal(r.source, exp.source);
  }
}

test('경계 상수는 화면(0.1~20%)과 같다', () => {
  assert.equal(MIN_RATE, 0.001);
  assert.equal(MAX_RATE, 0.2);
});

test('진리표 행 수: resolve 32 / classify 13 / classifySwitch 7 / callable 12 / callableSwitch 4', () => {
  assert.deepEqual(
    [table.resolve.length, table.classify.length, table.classifySwitch.length,
      table.callable.length, table.callableSwitch.length],
    [32, 13, 7, 12, 4]);
});

for (const row of table.resolve) {
  test(`resolve ${row.id}`, () => assertResolved(resolveRow(row), row.expect));
}

for (const row of table.classify) {
  test(`classify ${row.raw}`, () => {
    assert.equal(classifyRate(decode(row.raw)).kind, row.expect);
  });
}

for (const row of table.classifySwitch) {
  test(`classifySwitch ${row.id} ${row.raw}`, () => {
    assert.equal(classifySwitch(decode(row.raw)).kind, row.expect);
  });
}

for (const row of table.callable) {
  test(`callable ${row.raw}`, () => {
    assert.equal(isValidCallableRate(decode(row.raw)), row.expect);
  });
}

for (const row of table.callableSwitch) {
  test(`callableSwitch ${row.id}`, () => {
    assert.equal(isValidCallableSwitch(decode(row.enabled)), row.expect === 'accept');
  });
}

test('N4: 스위치 단계가 숫자 단계를 통째로 앞선다 / disabled 가 invalid 보다 앞선다 (분기 순서 고정)', () => {
  const en = { kind: 'enabled' }; const off = { kind: 'disabled' }; const bad = { kind: 'invalid', raw: 1 };
  const abs = { kind: 'absent' }; const v = (rate) => ({ kind: 'valid', rate });
  // R06: 브랜드 off + 매장 개별 10%
  assert.equal(resolveEffectiveRate(en, v(0.1), off, v(0.05), v(0.03)).source, 'brand');
  // R21b: 매장 switch 무효 + 브랜드 off → disabled 가 먼저
  assert.equal(resolveEffectiveRate(bad, abs, off, v(0.05), v(0.03)).ok, true);
  // R22b: 브랜드 switch 무효 + 매장 10% → 무효
  assert.equal(resolveEffectiveRate(en, v(0.1), bad, v(0.05), v(0.03)).ok, false);
});

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

// ── F1 재발 방지 (T1 / T2 / T4) ────────────────────────────────────────────────

const sampleCart = {
  storeId: 'st1', storeName: '매장', items: [], subtotal: 10000, discount: null, totalPrice: 10000,
};
const times = { approvedAt: 'A', now: 'N' };

test('T1 buildOrderData: brandId 는 항상 null — 클라이언트가 보낸 cart.brandId 는 읽지도 저장하지도 않는다 (스푸핑 차단)', () => {
  const spoofed = { ...sampleCart, brandId: 'brand_20pct' };
  const order = buildOrderData(spoofed, 'u1', {}, times);
  assert.equal(order.brandId, null);
  assert.equal(buildOrderData(sampleCart, 'u1', {}, times).brandId, null);
  const log = buildOrderLogData(spoofed, { logId: 'l', orderId: 'o', paymentMethod: 'card' }, times);
  assert.equal(log.brandId, null);
});

test('T1 buildOrderData: 주문 문서 키 집합 고정 (운영이 쓰는 모양 = 테스트가 쓰는 모양)', () => {
  const order = buildOrderData(sampleCart, 'u1', { method: 'card' }, times);
  assert.deepEqual(Object.keys(order).sort(), [
    'acceptedAt', 'brandId', 'cancelledAt', 'createdAt', 'discount', 'items', 'paymentInfo', 'refundInfo',
    'refundRequest', 'refundedAt', 'status', 'storeId', 'storeName', 'subtotal', 'totalPrice', 'updatedAt', 'userId',
  ]);
  assert.equal(order.status, 'paid');
  assert.equal(order.storeId, 'st1');
  assert.equal(order.userId, 'u1');
});

test('T2 cart 입력 계약: TS 가 소비하는 키 집합 = test_fixtures/qoin_cart_contract.json (Dart 가 보내는 키 집합과 같은 파일)', () => {
  assert.deepEqual([...CONSUMED_CART_KEYS].sort(), [...cartContract.keys].sort());
  assert.ok(!CONSUMED_CART_KEYS.includes('brandId'), 'brandId 는 소비 키가 아니다');
});

test('T2-b item 레벨 입력 계약 (payment_price_authority §1-5): items[] 와 selectedOptions[] 키 집합 = 골든 (Dart 가 보내는 키와 같은 파일)', () => {
  assert.deepEqual([...CONSUMED_ITEM_KEYS].sort(), [...cartContract.itemKeys].sort());
  assert.deepEqual([...CONSUMED_OPTION_KEYS].sort(), [...cartContract.selectedOptionKeys].sort());
  // 거짓 타입 재발 방지: 옵션 키는 groupId/itemId 다 (optionGroupId/optionId 가 아니다).
  assert.ok(!CONSUMED_OPTION_KEYS.includes('optionGroupId') && !CONSUMED_OPTION_KEYS.includes('optionId'));
  // imageUrl 은 주문상세 썸네일용으로 보낸다(order_flow_phase1 UI 캐싱 의도 복원).
  assert.ok(CONSUMED_ITEM_KEYS.includes('imageUrl'));
});

test('T2 qoin_spend 최상위 입력 계약: TS 가 소비하는 입력 키 집합 = fixture.inputKeys (qoinToUse 는 cart 밖 최상위)', () => {
  assert.deepEqual([...CONSUMED_INPUT_KEYS].sort(), [...cartContract.inputKeys].sort());
  assert.ok(CONSUMED_INPUT_KEYS.includes('qoinToUse'));
  assert.ok(!CONSUMED_CART_KEYS.includes('qoinToUse'), 'qoinToUse 는 cart 키가 아니다');
  for (const k of cartContract.requiredInputKeys) assert.ok(cartContract.inputKeys.includes(k));
});

test('T2 buildOrderData 가 cart 에서 읽는 키는 CONSUMED_CART_KEYS 와 일치 (Proxy 로 접근 키 수집)', () => {
  const touched = new Set();
  const proxy = new Proxy(sampleCart, { get: (t, k) => { if (typeof k === 'string') touched.add(k); return t[k]; } });
  buildOrderData(proxy, 'u1', {}, times);
  buildOrderLogData(proxy, { logId: 'l', orderId: 'o', paymentMethod: 'card' }, times);
  assert.deepEqual([...touched].sort(), [...CONSUMED_CART_KEYS].sort());
});

test('T4 금액·원장 경로에서 주문/카트의 brandId 참조 0건', () => {
  const src = path.join(here, '../src');
  const hits = [];
  for (const f of fs.readdirSync(src)) {
    if (!f.endsWith('.ts')) continue;
    const code = fs.readFileSync(path.join(src, f), 'utf8')
      .replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');
    if (/\b(after|before)\??\.(get\(["']brandId["']\)|brandId)/.test(code)) hits.push(`${f}: after/before.brandId`);
    if (/\bcart\??\.brandId/.test(code) || /\bdata\.cart\.brandId/.test(code)) hits.push(`${f}: cart.brandId`);
  }
  assert.deepEqual(hits, []);
});

test('삭제 대상 식별자 잔존 0건: allowZero / explicitOffRate / clearedZeroCount / skipped_rate_zero', () => {
  const dirs = [path.join(here, '../src'), path.join(here, '../test')];
  const hits = [];
  for (const d of dirs) for (const f of fs.readdirSync(d)) {
    if (f === 'qoinRate.test.mjs') continue; // 이 검사 자신
    const text = fs.readFileSync(path.join(d, f), 'utf8');
    const code = text.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');
    for (const w of ['allowZero', 'explicitOffRate', 'clearedZeroCount', 'skipped_rate_zero']) {
      if (code.includes(w)) hits.push(`${f}: ${w}`);
    }
  }
  assert.deepEqual(hits, []);
});

test('describeRaw: 값의 JSON 표기를 그대로 — bool·배열·객체에 따옴표가 덧붙지 않는다 (마이그레이션 raw 의 존재 이유)', () => {
  assert.equal(describeRaw(true), 'true');
  assert.equal(describeRaw(false), 'false');
  assert.equal(describeRaw([1, 2]), '[1,2]');
  assert.equal(describeRaw({ a: 1 }), '{"a":1}');
  assert.equal(describeRaw(null), 'null');
  assert.equal(describeRaw(0.5), '0.5');
  assert.equal(describeRaw(NaN), 'NaN');
  assert.equal(describeRaw(undefined), '(absent)');
  // 문자열만 따옴표 (3 과 "3" 을 구별한다)
  assert.equal(describeRaw('3'), '"3"');
  assert.equal(describeRaw('x'.repeat(200)).length, 100);
});

test('포인터 상태 기계: 4값 (in_progress / partial / completed / superseded) — Dart QoinBulkStatus 와 같은 코드', () => {
  assert.deepEqual(Object.values(BULK_STATUS).sort(), ['completed', 'in_progress', 'partial', 'superseded']);
});

test('auditBrandLinks 는 쓰기 호출이 하나도 없다 (읽기 전용 · 요청 인자 없음)', () => {
  const code = fs.readFileSync(path.join(here, '../src/auditBrandLinks.ts'), 'utf8')
    .replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');
  for (const w of ['.update(', '.delete(', '.create(', '.batch(', 'runTransaction', 'FieldValue', 'bulkWriter', 'recursiveDelete']) {
    assert.equal(code.includes(w), false, `쓰기 호출 ${w}`);
  }
  // `.set(` 은 메모리 Map 에만 쓴다 (Firestore 문서 ref 에 쓰지 않는다).
  const receivers = [...code.matchAll(/(\w+)\.set\(/g)].map((m) => m[1]);
  for (const r of receivers) assert.ok(['out', 'allBrands', 'holders'].includes(r), `.set( 수신자 ${r} 가 메모리 Map 이 아니다`);
  assert.equal(/request\.data/.test(code), false, '요청 인자를 읽지 않는다 (dryRun 같은 모드 인자 없음)');
});

test('claimSubmittedBrand: users 에 쓰는 필드는 brandId 와 roleHistory 1건뿐이고 기존 값을 덮지 않는다', () => {
  const code = fs.readFileSync(path.join(here, '../src/claimSubmittedBrand.ts'), 'utf8')
    .replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');
  assert.match(code, /t\.update\(userRef, \{ brandId \}\)/);
  assert.equal((code.match(/t\.set\(/g) ?? []).length, 1, 'roleHistory 1건');
  assert.match(code, /failed-precondition/);
  assert.match(code, /submittedBy/);
});

test('stale 판정 기준(5분)은 Dart 와 같은 공유 픽스처를 읽는다 — test_fixtures/qoin_bulk_policy.json', () => {
  const policy = JSON.parse(
    fs.readFileSync(path.join(here, '../../test_fixtures/qoin_bulk_policy.json'), 'utf8'));
  assert.equal(BULK_STALE_MS, policy.bulkStaleMs);
  // 상수는 qoinRate.ts 1곳에서만 선언한다.
  const src = path.join(here, '../src');
  const decl = [];
  for (const f of fs.readdirSync(src)) {
    if (!f.endsWith('.ts')) continue;
    if (/\b(const|let)\s+BULK_STALE_MS\b/.test(fs.readFileSync(path.join(src, f), 'utf8'))) decl.push(f);
  }
  assert.deepEqual(decl, ['qoinRate.ts']);
});

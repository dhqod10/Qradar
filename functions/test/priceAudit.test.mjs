// payment_price_authority — 감사 도구(auditOrderPriceIntegrity) 순수 판정 + 가격 이력 트리거(onMenuPriceWritten) 핵심 + 소스 가드.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { checkOrderTier1, classifyOverride, storeScopeGroupIds } from '../lib/auditOrderPriceIntegrity.js';
import { diffPriceChange, recordPriceChange, buildPriceHistoryDoc, priceSnapshot } from '../lib/onMenuPriceWritten.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const src = (n) => fs.readFileSync(path.join(here, '../src', n), 'utf8');

// ── ⓐ Tier 1 ────────────────────────────────────────────────────────────────
const okOrder = () => ({
  items: [{ unitPriceWithOptions: 4500, quantity: 2, lineTotal: 9000 }, { unitPriceWithOptions: 4000, quantity: 1, lineTotal: 4000 }],
  subtotal: 13000, totalPrice: 13000, paymentInfo: { amount: 13000 },
});

test('Tier1: 정합한 주문은 4개 불변식 모두 통과 (현행 클라이언트는 항상 정합 — 오탐 0)', () => {
  const r = checkOrderTier1(okOrder());
  assert.deepEqual(r.checks, { lineMath: true, subtotalSum: true, totalEqSubtotal: true, amountEqTotal: true });
  assert.equal(r.sumOfLineTotals, 13000);
  assert.equal(r.malformed, false);
});

test('Tier1: §0 의 공격 (amount 1 + 17,000원어치 items) 은 subtotalSum 으로 반드시 걸린다', () => {
  const r = checkOrderTier1({
    items: [{ unitPriceWithOptions: 4250, quantity: 4, lineTotal: 17000 }],
    subtotal: 1, totalPrice: 1, paymentInfo: { amount: 1 },
  });
  assert.equal(r.checks.subtotalSum, false);
  assert.equal(r.checks.lineMath, true);
  assert.equal(r.clientSubtotal, 1);
  assert.equal(r.sumOfLineTotals, 17000);
  assert.equal(r.amount, 1);
});

test('Tier1: 각 불변식이 독립적으로 걸린다', () => {
  const lineMath = okOrder(); lineMath.items[0].lineTotal = 8999; lineMath.subtotal = 12999; lineMath.totalPrice = 12999; lineMath.paymentInfo.amount = 12999;
  assert.deepEqual(checkOrderTier1(lineMath).checks, { lineMath: false, subtotalSum: true, totalEqSubtotal: true, amountEqTotal: true });
  const tot = okOrder(); tot.totalPrice = 1; tot.paymentInfo.amount = 1;
  assert.deepEqual(checkOrderTier1(tot).checks, { lineMath: true, subtotalSum: true, totalEqSubtotal: false, amountEqTotal: true });
  const amt = okOrder(); amt.paymentInfo.amount = 1;
  assert.deepEqual(checkOrderTier1(amt).checks, { lineMath: true, subtotalSum: true, totalEqSubtotal: true, amountEqTotal: false });
});

test('Tier1: items 가 배열이 아니면 malformed (판정 불가 = 위반으로 센다)', () => {
  const r = checkOrderTier1({ subtotal: 1, totalPrice: 1, paymentInfo: { amount: 1 } });
  assert.equal(r.malformed, true);
  assert.equal(r.checks.lineMath, false);
});

// ── ⓑ self-approved ─────────────────────────────────────────────────────────
test('self-approved: 점주가 approved + priceOverride 를 직접 쓴 문서 (approvedBy 없음 / 점주 uid) 는 selfApproved', () => {
  assert.equal(classifyOverride({ status: 'approved', priceOverride: 1 }, 'owner1'), 'selfApproved');
  assert.equal(classifyOverride({ status: 'approved', priceOverride: 1, approvedBy: 'owner1' }, 'owner1'), 'selfApproved');
  assert.equal(classifyOverride({ status: 'approved', excluded: true, approvedBy: null }, 'owner1'), 'selfApproved');
  assert.equal(classifyOverride({ status: 'weird', priceOverride: 1 }, 'owner1'), 'selfApproved', '앱은 모르는 status 를 approved 로 읽는다');
});
test('self-approved: admin/브랜드가 승인한 문서·pending·rejected·핵심 필드 없는 운영 문서는 위반이 아니다', () => {
  assert.equal(classifyOverride({ status: 'approved', priceOverride: 3000, approvedBy: 'adminX' }, 'owner1'), 'ok');
  assert.equal(classifyOverride({ status: 'pending', priceOverride: 1 }, 'owner1'), 'ok');
  assert.equal(classifyOverride({ priceOverride: 1 }, 'owner1'), 'ok', 'status 부재 = pending');
  assert.equal(classifyOverride({ status: 'rejected', priceOverride: 1 }, 'owner1'), 'ok');
  // W2 upsert 가 만드는 정상 문서: approved + 승인 메타 null + 핵심 필드 없음
  assert.equal(classifyOverride({ status: 'approved', priceOverride: null, excluded: false, soldOut: true, approvedBy: null }, 'owner1'), 'opsOnlyApproved');
});

// ── ⓒ store-scope ref ───────────────────────────────────────────────────────
test('store-scope ref: 마스터 메뉴의 scope==store 그룹 id 만 뽑는다', () => {
  assert.deepEqual(storeScopeGroupIds({ optionGroupRefs: [{ scope: 'store', id: 'a' }, { scope: 'brand', id: 'b' }, { scope: 'master', id: 'c' }, { scope: 'store', id: '' }, 'x', null] }), ['a']);
  assert.deepEqual(storeScopeGroupIds({}), []);
});

// ── 감사 도구는 고치지 않는다 ────────────────────────────────────────────────
test('감사 도구는 읽기 전용이다: 쓰기 호출은 migrationHistory 실행 기록 add 1건뿐', () => {
  // Map.set (메모리) 은 쓰기가 아니다 — 지역 Map 두 개만 걸러 낸 뒤 검사한다.
  const code = src('auditOrderPriceIntegrity.ts').replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '').replace(/(ownerOf|franchiseCount)\.set\(/g, '$1.MEM(');
  for (const w of ['.update(', '.delete(', '.set(', '.batch(', 'runTransaction', 'bulkWriter']) {
    assert.ok(!code.includes(w), `쓰기 호출 ${w} 금지`);
  }
  assert.equal((code.match(/\.add\(/g) ?? []).length, 1);
  assert.ok(code.includes('collection("migrationHistory").add('));
});

// ── 가격 이력 ───────────────────────────────────────────────────────────────
test('이력: basePrice 가 바뀌면 1건, 다른 필드만 바뀌면 기록하지 않는다', () => {
  const c = diffPriceChange('menuItem', { basePrice: 4000, name: 'a' }, { basePrice: 4500, name: 'a' });
  assert.deepEqual(c, { kind: 'menuItem', before: { basePrice: 4000 }, after: { basePrice: 4500 } });
  assert.equal(diffPriceChange('menuItem', { basePrice: 4000, name: 'a' }, { basePrice: 4000, name: 'b' }), null);
});
test('이력: 생성·삭제도 기록한다 (한쪽이 null)', () => {
  assert.deepEqual(diffPriceChange('menuItem', null, { basePrice: 100 }), { kind: 'menuItem', before: null, after: { basePrice: 100 } });
  assert.deepEqual(diffPriceChange('menuItem', { basePrice: 100 }, undefined), { kind: 'menuItem', before: { basePrice: 100 }, after: null });
});
test('이력: override 는 priceOverride 와 status 를 함께 본다 (승인 여부가 효력을 정한다)', () => {
  const c = diffPriceChange('menuOverride', { priceOverride: 3000, status: 'pending' }, { priceOverride: 3000, status: 'approved', approvedBy: 'a' });
  assert.equal(c?.after?.status, 'approved');
  assert.equal(c?.before?.status, 'pending');
  assert.equal(diffPriceChange('menuOverride', { priceOverride: 3000, status: 'approved', soldOut: false }, { priceOverride: 3000, status: 'approved', soldOut: true }), null);
});
test('이력: 옵션 그룹은 items[].priceDelta 맵만 본다 — 라벨·active·순서 변경은 기록하지 않는다', () => {
  const g = (items, extra = {}) => ({ name: 'n', active: true, items, ...extra });
  assert.equal(diffPriceChange('optionGroup', g([{ id: 'a', label: 'A', priceDelta: 500 }, { id: 'b', priceDelta: 0 }]), g([{ id: 'b', priceDelta: 0 }, { id: 'a', label: 'AA', priceDelta: 500 }], { active: false })), null);
  const c = diffPriceChange('optionGroup', g([{ id: 'a', priceDelta: 500 }]), g([{ id: 'a', priceDelta: 0 }]));
  assert.deepEqual(c?.before, { priceDeltas: { a: 500 } });
  assert.deepEqual(c?.after, { priceDeltas: { a: 0 } });
  assert.notEqual(diffPriceChange('optionGroup', g([{ id: 'a', priceDelta: 500 }]), g([{ id: 'a', priceDelta: 500 }, { id: 'z', priceDelta: -9000 }])), null, '항목 추가도 가격 변경이다');
});
test('이력: 원시 값을 정규화하지 않는다 (증거 — 0.5 는 0.5 로)', () => {
  assert.deepEqual(priceSnapshot('menuItem', { basePrice: 0.5 }), { basePrice: 0.5 });
});

function fakeDb({ fail = false } = {}) {
  const writes = [];
  return {
    writes,
    collection(name) {
      return { doc(id) { return { async set(data) { if (fail) throw new Error('boom'); writes.push([name, id, data]); } }; } };
    },
  };
}

test('이력: 기록은 priceHistory/{eventId} 1건 — 이벤트 재전달이 와도 같은 문서에 덮어써 중복이 없다', async () => {
  const db = fakeDb();
  const args = {
    eventId: 'evt1', kind: 'menuItem', target: { scope: 'store', storeId: 's1', brandId: null, targetId: 'm1' },
    before: { basePrice: 4000 }, after: { basePrice: 4500 }, actor: { authType: 'authenticated', authId: 'ownerUid' },
  };
  assert.equal(await recordPriceChange(db, args), true);
  assert.equal(await recordPriceChange(db, args), true);
  assert.equal(db.writes.length, 2);
  assert.ok(db.writes.every(([c, id]) => c === 'priceHistory' && id === 'evt1'));
  const doc = db.writes[0][2];
  assert.equal(doc.changedBy, 'ownerUid');
  assert.equal(doc.scope, 'store');
  assert.equal(doc.storeId, 's1');
  assert.equal(doc.targetId, 'm1');
  assert.deepEqual(doc.before, { basePrice: 4000 });
  assert.deepEqual(doc.after, { basePrice: 4500 });
  assert.ok('changedAt' in doc);
});
test('이력: 변경이 없으면 쓰지 않고, 쓰기 실패는 삼킨다 (원 쓰기·트리거 재시도에 영향 없음)', async () => {
  const db = fakeDb();
  assert.equal(await recordPriceChange(db, { eventId: 'e', kind: 'menuItem', target: { scope: 'store', storeId: 's', brandId: null, targetId: 'm' }, before: { basePrice: 1 }, after: { basePrice: 1 }, actor: { authType: null, authId: null } }), false);
  assert.equal(db.writes.length, 0);
  const bad = fakeDb({ fail: true });
  assert.equal(await recordPriceChange(bad, { eventId: 'e', kind: 'menuItem', target: { scope: 'store', storeId: 's', brandId: null, targetId: 'm' }, before: { basePrice: 1 }, after: { basePrice: 2 }, actor: { authType: null, authId: null } }), false);
});
test('이력: 트리거는 쓰기 경로를 건드리지 않는다 — priceHistory 외 컬렉션에는 쓰지 않는다 (소스 가드)', () => {
  const code = src('onMenuPriceWritten.ts').replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');
  const writes = [...code.matchAll(/collection\("([A-Za-z]+)"\)[\s\S]{0,60}?\.(set|add|update|delete)\(/g)].map((m) => m[1]);
  assert.deepEqual([...new Set(writes)], ['priceHistory']);
});
test('buildPriceHistoryDoc: 스펙 필드 (changedBy/before/after/targetId/scope/changedAt) 를 모두 가진다', () => {
  const d = buildPriceHistoryDoc({ kind: 'menuItem', before: null, after: { basePrice: 1 } }, { scope: 'brand', storeId: null, brandId: 'b', targetId: 'm' }, { authType: 'authenticated', authId: 'u' }, 'T');
  for (const k of ['changedBy', 'before', 'after', 'targetId', 'scope', 'changedAt']) assert.ok(k in d, k);
});

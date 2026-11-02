// qoin_spend — Qoin 사용: 순수 판정 골든 + 금액 게이트 일반화(할인 인식형) + verifyTossPayment 사용 경로(차감·롤백·거절·멱등) 단위 테스트.
// `npm test` (functions/ 에서). 실 Firestore 접촉 0 — 인메모리 fake. 트리거(복원)는 emulator.test.mjs 에서 검증한다.
// Dart 쪽 골든: test/core/qoin_spend_calculator_test.dart (같은 fixture 를 읽는다)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { handleVerifyTossPayment } from '../lib/verifyTossPayment.js';
import { resolveSpendPolicy, validateQoinSpend, maxSpendable, parseQoinToUse, SPEND_REJECT_TOKEN } from '../lib/qoinSpend.js';
import { evaluatePriceAuthority } from '../lib/priceGate.js';
import { applyServerPricing, buildOrderData, buildOrderLogData } from '../lib/orderBuilder.js';
import { optionRefKey } from '../lib/optionPricing.js';
import { GATE_HTTPS_CODE, buildRejectionMessage } from '../lib/paymentGate.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const spendContract = JSON.parse(fs.readFileSync(path.join(here, '../../test_fixtures/qoin_spend_contract.json'), 'utf8'));

// ═════════════════════════════════════════════════════════════════════════════
// 교차 골든 (Dart 와 같은 fixture)
// ═════════════════════════════════════════════════════════════════════════════
test('qoin_spend 골든 fixture 가 충분하다', () => {
  assert.ok(spendContract.policyCases.length >= 12);
  assert.ok(spendContract.maxCases.length >= 10);
  assert.ok(spendContract.validateCases.length >= 12);
  assert.ok(spendContract.requestCases.length >= 6);
});

for (const c of spendContract.policyCases) {
  test(`spend policy: ${c.name}`, () => {
    const p = resolveSpendPolicy(c.config);
    assert.equal(p.spendEnabled, c.expect.spendEnabled);
    if (c.expect.spendEnabled) {
      assert.equal(p.minUnit, c.expect.minUnit);
      assert.equal(p.minCashFloor, c.expect.minCashFloor);
    }
  });
}
test('spend policy: config/qoin 문서 부재 → 차단', () => assert.equal(resolveSpendPolicy(undefined).spendEnabled, false));

for (const c of spendContract.maxCases) {
  test(`spend max: ${c.name}`, () => {
    assert.equal(maxSpendable({ balance: c.balance, subtotal: c.subtotal, minUnit: c.minUnit, minCashFloor: c.minCashFloor }), c.expect);
  });
}

for (const c of spendContract.validateCases) {
  test(`spend validate: ${c.name}`, () => {
    const r = validateQoinSpend({ requested: c.requested, balance: c.balance, serverSubtotal: c.subtotal, policy: { ...c.policy, disabledBecause: c.policy.spendEnabled ? null : 'spendDisabled' } });
    assert.equal(r.ok, c.expect.ok);
    if (r.ok) assert.equal(r.validatedQ, c.expect.validatedQ);
    else assert.equal(r.reason, c.expect.reason);
  });
}

for (const c of spendContract.requestCases) {
  test(`spend request parse: ${c.name}`, () => {
    assert.equal(parseQoinToUse(c.absent ? undefined : c.raw), c.expect);
  });
}

test('거절 토큰: QOIN_* 문법이 앱 토큰 정규식([A-Z][A-Z0-9_]{2,39})을 통과하고 모두 failed-precondition + 문구가 있다', () => {
  for (const tok of Object.values(SPEND_REJECT_TOKEN)) {
    assert.match(tok, /^[A-Z][A-Z0-9_]{2,39}$/);
    assert.equal(GATE_HTTPS_CODE[tok], 'failed-precondition');
    assert.match(buildRejectionMessage(tok), new RegExp(`\\[${tok}\\]$`));
  }
});

// ═════════════════════════════════════════════════════════════════════════════
// 금액 게이트 일반화 — D=0 은 현행과 동일, D>0 은 할인 인식형
// ═════════════════════════════════════════════════════════════════════════════
function gateReader({ menus = { m1: 4000 } } = {}) {
  return {
    async getStore() { return { status: 'approved', approvedAt: {} }; },
    async getMenuDocs(_s, _b, ids) {
      const m = { storeMenus: new Map(), overrides: new Map(), masters: new Map() };
      for (const id of ids) m.storeMenus.set(id, menus[id] === undefined ? null : { basePrice: menus[id], soldOut: false, visible: true, optionGroupRefs: [] });
      return m;
    },
    async getOptionGroups(_s, _b, refs) { const out = new Map(); for (const r of refs) out.set(optionRefKey(r.scope, r.id), null); return out; },
  };
}
const item = (id, unit, qty = 1) => ({ menuItemId: id, menuItemName: id, quantity: qty, selectedOptions: [], unitPriceWithOptions: unit, lineTotal: unit * qty });
async function gate({ cart, amount, discount, menus }) {
  const { resolveMenusForPricing } = await import('../lib/priceGate.js');
  const reader = gateReader({ menus });
  const resolved = await resolveMenusForPricing(reader, { storeId: 's1', items: cart.items });
  return evaluatePriceAuthority(reader, { storeId: 's1', storeBrandId: resolved.storeBrandId, menus: resolved.menus, amount, cart, ...(discount === undefined ? {} : { discount }) });
}
const cartOf = (items, over = {}) => { const sum = items.reduce((a, i) => a + i.lineTotal, 0); return { items, subtotal: sum, totalPrice: sum, ...over }; };

test('priceGate D 생략 = D 0 = 현행 판정과 동일 (ok 결과의 pricing 모양 포함)', async () => {
  const cart = cartOf([item('m1', 4000, 2)]);
  const a = await gate({ cart, amount: 8000 });
  const b = await gate({ cart, amount: 8000, discount: 0 });
  assert.deepEqual(a, b);
  assert.equal(a.ok, true);
  assert.deepEqual(a.pricing.expected, 8000);
  assert.deepEqual(Object.keys(a.pricing).sort(), ['expected', 'lines', 'subtotal']);
});

test('priceGate D 생략: 할인 없는 카트가 amount≠subtotal 이면 거절 (현행)', async () => {
  const cart = cartOf([item('m1', 4000)], { totalPrice: 3500 });
  const r = await gate({ cart, amount: 3500 });
  assert.equal(r.ok, false);
  assert.equal(r.reason, 'PRICE_MISMATCH');
  assert.ok(!('discount' in r.detail), 'D=0 거절 기록 모양은 현행과 같다 (discount 키 없음)');
});

test('priceGate D>0: 정합한 할인 카트 통과, pricing.expected = 서버 소계 − D', async () => {
  const cart = cartOf([item('m1', 4000, 2)], { totalPrice: 7300 }); // subtotal 8000, Q 700
  const r = await gate({ cart, amount: 7300, discount: 700 });
  assert.equal(r.ok, true);
  assert.equal(r.pricing.subtotal, 8000);
  assert.equal(r.pricing.expected, 7300);
});

test('priceGate D>0: 소계 뻥튀기 + 큰 할인 (공짜 돈 공격) → 거절 (서버 소계 기준)', async () => {
  // 서버 소계 4000. 클라는 40000 이라 주장하고 Q=39700 → 결제 300원.
  const cart = cartOf([item('m1', 40000)], { totalPrice: 300 });
  const r = await gate({ cart, amount: 300, discount: 39700 });
  assert.equal(r.ok, false);
  assert.equal(r.reason, 'PRICE_MISMATCH');
  assert.equal(r.detail.discount, 39700);
  assert.equal(r.detail.checks.c4, false);
});

test('priceGate D>0: amount 가 소계−D 가 아니면 거절 (D 를 안 뺀 채 Q 요청)', async () => {
  const cart = cartOf([item('m1', 4000)]); // totalPrice = subtotal = 4000 (할인 미반영)
  const r = await gate({ cart, amount: 4000, discount: 500 });
  assert.equal(r.ok, false);
  assert.equal(r.reason, 'PRICE_MISMATCH');
  assert.equal(r.detail.checks.c2, false);
});

test('priceGate D>0: 클라 subtotal 이 정수가 아니면 c2 거절', async () => {
  const cart = { ...cartOf([item('m1', 4000)]), subtotal: '4000', totalPrice: 3500 };
  const r = await gate({ cart, amount: 3500, discount: 500 });
  assert.equal(r.ok, false);
});

test('applyServerPricing: discount 생략 = 현행 (discount 키 불변), D>0 이면 discount 주입', () => {
  const cart = { storeId: 's1', storeName: 'S', items: [item('m1', 4000)], subtotal: 4000, discount: null, totalPrice: 4000 };
  const pricing = { lines: [{ unitPrice: 4000, lineTotal: 4000 }], subtotal: 4000, expected: 4000 };
  const a = applyServerPricing(cart, pricing);
  assert.equal(a.discount, null);
  assert.deepEqual(a, applyServerPricing(cart, pricing, 0));
  const b = applyServerPricing(cart, { ...pricing, expected: 3300 }, 700);
  assert.equal(b.discount, 700);
  assert.equal(b.totalPrice, 3300);
  assert.equal(b.subtotal, 4000);
});

test('buildOrderLogData: discount 인자 없으면 키 없음 (현행), 있으면 기록', () => {
  const cart = { storeId: 's1', storeName: 'S', items: [], subtotal: 4000, discount: 999, totalPrice: 4000 };
  const t = { approvedAt: 1, now: 2 };
  assert.ok(!('discount' in buildOrderLogData(cart, { logId: 'l', orderId: 'o', paymentMethod: 'card' }, t)), '클라 cart.discount 를 로그에 새기지 않는다');
  assert.equal(buildOrderLogData(cart, { logId: 'l', orderId: 'o', paymentMethod: 'card', discount: 700 }, t).discount, 700);
  assert.equal(buildOrderData(cart, 'u', {}, t).discount, 999, '기존 동작 유지(주문 문서는 cart.discount 그대로) — enforce 에서만 서버값');
});

// ═════════════════════════════════════════════════════════════════════════════
// verifyTossPayment — 인메모리 Firestore
// ═════════════════════════════════════════════════════════════════════════════
const clone = (v) => (v === undefined ? v : structuredClone(v));
function memDb(seed = {}, opts = {}) {
  const store = new Map(Object.entries(seed).map(([k, v]) => [k, clone(v)]));
  const log = { reads: [], rejections: [], txCount: 0, batchCount: 0, issues: [] };
  let chain = Promise.resolve();
  const snap = (p) => ({ exists: store.has(p), data: () => clone(store.get(p)), get: (f) => clone(store.get(p)?.[f]) });
  const docRef = (p) => ({
    _path: p,
    id: p.split('/').pop(),
    async get() { log.reads.push(p); return snap(p); },
    collection(sub) { return colRef(`${p}/${sub}`); },
    async create(d) {
      if (store.has(p)) { const e = new Error('exists'); e.code = 6; throw e; }
      store.set(p, clone(d)); if (p.startsWith('qoinSettlementIssues/')) log.issues.push(clone(d));
    },
  });
  const colRef = (p) => ({
    doc: (id) => docRef(`${p}/${id}`),
    async add(d) { if (p === 'paymentGateRejections') log.rejections.push(clone(d)); return { id: 'r' }; },
  });
  const applyWrites = (writes) => {
    for (const [op, ref, d] of writes) {
      if (op === 'set') store.set(ref._path, clone(d));
      else if (op === 'update') store.set(ref._path, { ...store.get(ref._path), ...clone(d) });
    }
  };
  return {
    store, log,
    collection: (n) => colRef(n),
    batch() {
      const writes = [];
      return {
        set: (ref, d) => writes.push(['set', ref, d]),
        async commit() { log.batchCount++; if (opts.failBatch) throw new Error('batch boom'); applyWrites(writes); },
      };
    },
    // Firestore 트랜잭션의 직렬화 의미를 모사한다 (충돌 시 재시도 = 결과적으로 한 번에 하나씩).
    runTransaction(fn) {
      const run = async () => {
        log.txCount++;
        if (opts.failTxAt && opts.failTxAt === log.txCount) throw new Error('tx boom');
        const writes = [];
        const t = {
          get: async (ref) => snap(ref._path),
          set: (ref, d) => writes.push(['set', ref, d]),
          update: (ref, d) => { if (!store.has(ref._path)) throw new Error('update of missing doc'); writes.push(['update', ref, d]); },
        };
        const r = await fn(t);
        applyWrites(writes);
        return r;
      };
      const p = chain.then(run);
      chain = p.then(() => {}, () => {});
      return p;
    },
  };
}

const CONFIG_ON = { enabled: true, accrualRate: 0.03, spendEnabled: true, minCashFloor: 300 };
const seedBase = (over = {}) => ({
  'config/qoin': CONFIG_ON,
  'users/u1': { uid: 'u1', role: 'customer', qoinBalance: 5000 },
  'stores/s1': { ownerId: 'owner1', status: 'approved', brandId: 'b1' },
  ...over,
});
const ledgerOf = (db, id, uid = 'u1') => db.store.get(`users/${uid}/qoinTransactions/${id}`);
const balanceOf = (db, uid = 'u1') => db.store.get(`users/${uid}`).qoinBalance;

async function runVerify({ db, priceMode, qoin, request, confirm, cancel, menus }) {
  const spy = { confirm: 0, cancel: 0, confirmAmount: null };
  const deps = {
    db,
    secretKey: () => 'live_sk_real',
    gateReader: gateReader({ menus }),
    gateMode: () => 'off',
    priceMode: priceMode === undefined ? undefined : () => priceMode,
    confirm: confirm ?? (async (_k, p) => { spy.confirm++; spy.confirmAmount = p.amount; return { paymentKey: p.paymentKey, orderId: p.orderId, status: 'DONE', totalAmount: p.amount, approvedAt: new Date().toISOString(), easyPay: null }; }),
    cancel: cancel ?? (async () => { spy.cancel++; return {}; }),
  };
  if (confirm) { const inner = confirm; deps.confirm = async (...a) => { spy.confirm++; return inner(...a); }; }
  if (cancel) { const inner = cancel; deps.cancel = async (...a) => { spy.cancel++; return inner(...a); }; }
  try { return { result: await handleVerifyTossPayment(deps, request), err: null, spy }; } catch (err) { return { result: null, err, spy }; }
}

/** items 4000 × qty, Q 요청. 클라는 정합하게 보낸다 (amount = totalPrice = subtotal − Q). */
function req({ qty = 1, q, unit = 4000, key = 'idem1', cartOver = {}, over = {} } = {}) {
  const items = [item('m1', unit, qty)];
  const subtotal = unit * qty;
  const total = subtotal - (q ?? 0);
  return {
    auth: { uid: 'u1' },
    data: {
      paymentKey: 'pk', orderId: key, amount: total, idempotencyKey: key, paymentMethod: 'card',
      cart: { storeId: 's1', storeName: '강남점', items, subtotal, discount: q ? q : null, totalPrice: total, ...cartOver },
      ...(q === undefined ? {} : { qoinToUse: q }),
      ...over,
    },
  };
}

// ── 회귀: Q=0 ────────────────────────────────────────────────────────────────
for (const priceMode of [undefined, 'off', 'shadow', 'enforce']) {
  test(`회귀 Q=0 (qoinToUse 미전송, priceMode=${priceMode ?? 'none'}): 배치 경로, 트랜잭션·config·users 읽기 0, 주문 discount=null, totalPrice=소계`, async () => {
    const db = memDb(seedBase());
    const r = await runVerify({ db, priceMode, request: req() });
    assert.equal(r.err, null);
    assert.deepEqual(r.result, { orderId: 'idem1', status: 'paid' });
    assert.equal(db.log.txCount, 0);
    assert.equal(db.log.batchCount, 1);
    assert.ok(!db.log.reads.includes('config/qoin'), 'Q=0 은 config/qoin 을 읽지 않는다');
    assert.ok(!db.log.reads.some((p) => p === 'users/u1/qoinTransactions/spend_idem1'));
    const order = db.store.get('orders/idem1');
    assert.equal(order.discount, null);
    assert.equal(order.totalPrice, 4000);
    assert.equal(r.spy.confirmAmount, 4000);
    assert.equal(balanceOf(db), 5000);
    assert.equal(ledgerOf(db, 'spend_idem1'), undefined);
  });
}

test('회귀 Q=0 명시(qoinToUse:0) 와 null 도 미전송과 같다', async () => {
  for (const q of [0, null]) {
    const db = memDb(seedBase());
    const request = req(); request.data.qoinToUse = q;
    const r = await runVerify({ db, request });
    assert.equal(r.err, null);
    assert.equal(db.log.txCount, 0);
    assert.equal(db.store.get('orders/idem1').discount, null);
  }
});

test('회귀 Q=0: 가격 모드 off 에서는 클라 금액을 그대로 믿는다 (현행 — Qoin 강제 enforce 는 Q>0 에만)', async () => {
  const db = memDb(seedBase());
  const request = req({ unit: 99999 }); // 서버 가격은 4000 인데 클라는 99999
  const r = await runVerify({ db, priceMode: 'off', request });
  assert.equal(r.err, null);
  assert.equal(db.store.get('orders/idem1').totalPrice, 99999);
});

// ── Q>0 정상 ─────────────────────────────────────────────────────────────────
test('Q>0 정상 (가격 모드 off 여도 서버 재계산 강제): 차감·원장·잔액·주문 discount/totalPrice·confirm 금액', async () => {
  const db = memDb(seedBase());
  const r = await runVerify({ db, priceMode: 'off', request: req({ qty: 2, q: 700 }) });
  assert.equal(r.err, null);
  assert.deepEqual(r.result, { orderId: 'idem1', status: 'paid' });
  assert.equal(r.spy.confirmAmount, 7300, 'Toss 에는 소계 − Q 만 승인 요청');
  const order = db.store.get('orders/idem1');
  assert.equal(order.discount, 700);
  assert.equal(order.subtotal, 8000);
  assert.equal(order.totalPrice, 7300, '적립 기준 = 현금 결제액 (D-4)');
  assert.equal(order.brandId, null);
  const spend = ledgerOf(db, 'spend_idem1');
  assert.equal(spend.type, 'spend');
  assert.equal(spend.amount, -700);
  assert.equal(spend.balanceAfter, 4300);
  assert.equal(spend.orderId, 'idem1');
  assert.equal(spend.storeId, 's1');
  assert.equal(spend.brandId, 'b1', '자기거래 가드가 읽은 stores.brandId 재사용');
  assert.equal(spend.orderSubtotal, 8000);
  assert.equal(spend.orderTotalPrice, 7300);
  assert.equal(balanceOf(db), 4300);
  assert.equal(db.log.txCount, 1);
  const logDoc = [...db.store.entries()].find(([k]) => k.startsWith('users/u1/orderLogs/'));
  assert.equal(logDoc[1].discount, 700);
  assert.equal(logDoc[1].totalPrice, 7300);
});

test('Q>0 경계: 소계−최소현금 정확히 (3700/4000, floor 300) 통과', async () => {
  const db = memDb(seedBase({ 'users/u1': { qoinBalance: 99999 } }));
  const r = await runVerify({ db, request: req({ q: 3700 }) });
  assert.equal(r.err, null);
  assert.equal(r.spy.confirmAmount, 300);
});

test('Q>0 경계: 잔액 = Q 정확히 → 잔액 0', async () => {
  const db = memDb(seedBase({ 'users/u1': { qoinBalance: 700 } }));
  const r = await runVerify({ db, request: req({ q: 700 }) });
  assert.equal(r.err, null);
  assert.equal(balanceOf(db), 0);
});

// ── Q>0 거절 (confirm 전, 돈·Qoin 불변) ──────────────────────────────────────
async function expectRejected({ seed = seedBase(), request, reason, priceMode, menus }) {
  const db = memDb(seed);
  const before = db.store.get('users/u1')?.qoinBalance;
  const r = await runVerify({ db, priceMode, request, menus });
  assert.ok(r.err, '거절되어야 한다');
  assert.equal(r.spy.confirm, 0, 'Toss confirm 호출 0');
  assert.equal(r.spy.cancel, 0);
  assert.equal(db.log.batchCount, 0);
  assert.equal(db.store.has('orders/idem1'), false);
  assert.equal(db.store.get('users/u1')?.qoinBalance, before, '잔액 불변');
  assert.equal([...db.store.keys()].filter((k) => k.includes('/qoinTransactions/')).length, 0, '원장 불변');
  if (reason) {
    assert.match(r.err.message, new RegExp(`\\[${reason}(:[A-Za-z0-9_,-]+)?\\]$`));
    assert.equal(db.log.rejections.at(-1).reason, reason, 'paymentGateRejections 기록');
  }
  return { db, r };
}

test('거절: spendEnabled 부재 (fail-closed) → QOIN_SPEND_DISABLED', async () => {
  const seed = seedBase({ 'config/qoin': { enabled: true, minCashFloor: 300 } });
  const { r } = await expectRejected({ seed, request: req({ q: 500 }), reason: 'QOIN_SPEND_DISABLED' });
  assert.equal(r.err.code, 'failed-precondition');
});
test('거절: spendEnabled=false → QOIN_SPEND_DISABLED', async () => {
  await expectRejected({ seed: seedBase({ 'config/qoin': { ...CONFIG_ON, spendEnabled: false } }), request: req({ q: 500 }), reason: 'QOIN_SPEND_DISABLED' });
});
test('거절: 전역 enabled=false (상위 비상정지) → QOIN_SPEND_DISABLED', async () => {
  await expectRejected({ seed: seedBase({ 'config/qoin': { ...CONFIG_ON, enabled: false } }), request: req({ q: 500 }), reason: 'QOIN_SPEND_DISABLED' });
});
test('거절: config/qoin 문서 없음 → QOIN_SPEND_DISABLED', async () => {
  const seed = seedBase(); delete seed['config/qoin'];
  await expectRejected({ seed, request: req({ q: 500 }), reason: 'QOIN_SPEND_DISABLED' });
});
test('거절: minCashFloor 부재 → QOIN_SPEND_DISABLED (fail-closed)', async () => {
  await expectRejected({ seed: seedBase({ 'config/qoin': { enabled: true, spendEnabled: true } }), request: req({ q: 500 }), reason: 'QOIN_SPEND_DISABLED' });
});
test('거절: 잔액 부족 → QOIN_INSUFFICIENT_BALANCE', async () => {
  await expectRejected({ seed: seedBase({ 'users/u1': { qoinBalance: 699 } }), request: req({ q: 700 }), reason: 'QOIN_INSUFFICIENT_BALANCE' });
});
test('거절: 사용자 문서 없음 → QOIN_INSUFFICIENT_BALANCE', async () => {
  const seed = seedBase(); delete seed['users/u1'];
  await expectRejected({ seed, request: req({ q: 100 }), reason: 'QOIN_INSUFFICIENT_BALANCE' });
});
test('거절: 음수 잔액 → QOIN_INSUFFICIENT_BALANCE', async () => {
  await expectRejected({ seed: seedBase({ 'users/u1': { qoinBalance: -50 } }), request: req({ q: 1 }), reason: 'QOIN_INSUFFICIENT_BALANCE' });
});
test('거절: 최소현금 침범 (3701/4000) → QOIN_BELOW_CASH_FLOOR', async () => {
  await expectRejected({ seed: seedBase({ 'users/u1': { qoinBalance: 99999 } }), request: req({ q: 3701 }), reason: 'QOIN_BELOW_CASH_FLOOR' });
});
test('거절: 전액 Qoin 결제(4000/4000) 시도는 결제금액 0 이라 amount 검증에서 막힌다 (Toss 0원 불가)', async () => {
  const request = req({ q: 4000 });
  const db = memDb(seedBase({ 'users/u1': { qoinBalance: 99999 } }));
  const r = await runVerify({ db, request });
  assert.ok(r.err);
  assert.equal(r.spy.confirm, 0);
  assert.equal(balanceOf(db), 99999);
});
test('거절: 단위 위반 (minSpendUnit 100, 250) → QOIN_NOT_UNIT_MULTIPLE', async () => {
  await expectRejected({ seed: seedBase({ 'config/qoin': { ...CONFIG_ON, minSpendUnit: 100 } }), request: req({ q: 250 }), reason: 'QOIN_NOT_UNIT_MULTIPLE' });
});
test('거절: 음수/소수/문자열 qoinToUse → invalid-argument (confirm 0)', async () => {
  for (const q of [-1, 1.5, '100', true]) {
    const db = memDb(seedBase());
    const request = req(); request.data.qoinToUse = q;
    const r = await runVerify({ db, request });
    assert.equal(r.err?.code, 'invalid-argument', String(q));
    assert.equal(r.spy.confirm, 0);
    assert.equal(balanceOf(db), 5000);
  }
});

// ── 금액 권위 (공짜 돈 공격) ─────────────────────────────────────────────────
test('거절: 소계 뻥튀기 (서버 4000, 클라 40000, Q=39700) — 가격 모드 off 여도 막힌다', async () => {
  const { r } = await expectRejected({
    seed: seedBase({ 'users/u1': { qoinBalance: 99999 } }),
    priceMode: 'off',
    request: req({ unit: 40000, q: 39700 }),
    reason: 'PRICE_MISMATCH',
  });
  assert.equal(r.err.code, 'failed-precondition');
});
test('거절: 가격 모드 shadow 여도 Q>0 은 enforce (shadow 면 통과해 버릴 불일치)', async () => {
  await expectRejected({ seed: seedBase({ 'users/u1': { qoinBalance: 99999 } }), priceMode: 'shadow', request: req({ unit: 40000, q: 39700 }), reason: 'PRICE_MISMATCH' });
});
test('거절: Q 를 amount 에 반영하지 않은 요청 (amount = 소계) → PRICE_MISMATCH', async () => {
  const request = req({ q: 500 });
  request.data.amount = 4000; request.data.cart.totalPrice = 4000;
  await expectRejected({ request, reason: 'PRICE_MISMATCH' });
});
test('거절: 서버 소계 재계산 불가 (메뉴 없음) → READ_FAILED/MENU_NOT_FOUND 계열로 거절, 통과 금지', async () => {
  const { r } = await expectRejected({ request: req({ q: 500 }), menus: {} });
  assert.ok(r.err);
});

// ── 롤백 ─────────────────────────────────────────────────────────────────────
function assertRolledBack(db, q, balance0 = 5000) {
  assert.equal(balanceOf(db), balance0, '잔액 원복');
  const spend = ledgerOf(db, 'spend_idem1');
  const refund = ledgerOf(db, 'spendRefund_idem1');
  assert.equal(spend.amount, -q, 'spend 원장 보존 (append-only)');
  assert.equal(refund.type, 'spendRefund');
  assert.equal(refund.amount, q);
  assert.equal(refund.balanceAfter, balance0);
  assert.equal(refund.orderSubtotal, spend.orderSubtotal);
  assert.equal(refund.brandId, spend.brandId);
  assert.ok(refund.rollbackReason);
  const sum = [...db.store.entries()].filter(([k]) => k.startsWith('users/u1/qoinTransactions/')).reduce((a, [, v]) => a + v.amount, 0);
  assert.equal(sum, 0, '불변식: 원장 합이 0 (사용 + 복원)');
  assert.equal(db.store.has('orders/idem1'), false);
}

test('롤백: Toss confirm 이 throw → 잔액 원복 + spendRefund 반전 원장, 에러 전파', async () => {
  const db = memDb(seedBase());
  const r = await runVerify({ db, request: req({ q: 700 }), confirm: async () => { throw new Error('toss down'); } });
  assert.equal(r.err.message, 'toss down');
  assert.equal(r.spy.confirm, 1);
  assert.equal(r.spy.cancel, 0, 'confirm 이 던졌으면 승인된 적 없다 — cancel 시도 안 함');
  assertRolledBack(db, 700);
  assert.equal(ledgerOf(db, 'spendRefund_idem1').rollbackReason, 'payment_confirm_failed');
});

test('롤백: Toss 응답 검증 실패 (status != DONE) → cancel 시도 + 잔액 원복', async () => {
  const db = memDb(seedBase());
  const r = await runVerify({ db, request: req({ q: 700 }), confirm: async (_k, p) => ({ paymentKey: 'pk', orderId: p.orderId, status: 'ABORTED', totalAmount: p.amount, approvedAt: new Date().toISOString() }) });
  assert.equal(r.err.code, 'invalid-argument');
  assert.equal(r.spy.cancel, 1);
  assertRolledBack(db, 700);
});

test('롤백: 주문 쓰기(batch) 실패 → Toss cancel + 잔액 원복 (승인된 돈과 Qoin 둘 다 되돌린다)', async () => {
  const db = memDb(seedBase(), { failBatch: true });
  const r = await runVerify({ db, request: req({ q: 700 }) });
  assert.equal(r.err.message, 'batch boom');
  assert.equal(r.spy.confirm, 1);
  assert.equal(r.spy.cancel, 1, '승인된 결제는 취소');
  assertRolledBack(db, 700);
  assert.equal(ledgerOf(db, 'spendRefund_idem1').rollbackReason, 'order_write_failed');
});

test('롤백 자체가 실패하면 qoinSettlementIssues 에 기록 (고객 돈 — 로그에만 두지 않는다), 원본 에러 유지', async () => {
  const db = memDb(seedBase(), { failTxAt: 2 }); // 1번째 트랜잭션(예약)은 성공, 2번째(롤백) 실패
  const r = await runVerify({ db, request: req({ q: 700 }), confirm: async () => { throw new Error('toss down'); } });
  assert.equal(r.err.message, 'toss down');
  assert.equal(db.log.issues.length, 1);
  assert.equal(db.log.issues[0].reason, 'spend_rollback_failed');
  assert.equal(db.log.issues[0].orderId, 'idem1');
  assert.equal(balanceOf(db), 4300, '롤백 실패 상태 — 이슈 목록이 수동 복구 대상');
});

test('Q=0 에서 confirm 실패는 롤백 코드를 타지 않는다 (트랜잭션 0, 원본 에러)', async () => {
  const db = memDb(seedBase());
  const r = await runVerify({ db, request: req(), confirm: async () => { throw new Error('toss down'); } });
  assert.equal(r.err.message, 'toss down');
  assert.equal(db.log.txCount, 0);
});

// ── 멱등 · 동시성 ────────────────────────────────────────────────────────────
test('멱등: 같은 주문 키로 성공 후 재호출 → 기존 결과 반환, 이중 차감 0, confirm 1회', async () => {
  const db = memDb(seedBase());
  const request = req({ q: 700 });
  const a = await runVerify({ db, request });
  assert.equal(a.err, null);
  assert.equal(balanceOf(db), 4300);
  const b = await runVerify({ db, request });
  assert.equal(b.err, null);
  assert.deepEqual(b.result, { orderId: 'idem1', status: 'paid' });
  assert.equal(b.spy.confirm, 0, '재호출은 confirm 하지 않는다');
  assert.equal(balanceOf(db), 4300, '이중 차감 없음');
});

test('멱등: spend 원장만 남은 예약(주문 없음) + 같은 키 재호출 → aborted, 차감·롤백·confirm 0 (남의 예약을 건드리지 않는다)', async () => {
  const db = memDb(seedBase({
    'users/u1': { qoinBalance: 4300 },
    'users/u1/qoinTransactions/spend_idem1': { type: 'spend', amount: -700, balanceAfter: 4300 },
  }));
  const r = await runVerify({ db, request: req({ q: 700 }) });
  assert.equal(r.err.code, 'aborted');
  assert.equal(r.spy.confirm, 0);
  assert.equal(balanceOf(db), 4300);
  assert.equal(ledgerOf(db, 'spendRefund_idem1'), undefined, '롤백하지 않는다');
  assert.equal(ledgerOf(db, 'spend_idem1').amount, -700);
});

test('동시 결제 2건(같은 사용자, 합이 잔액 초과): 두 번째는 confirm 전에 QOIN_INSUFFICIENT_BALANCE — confirm 후 잔액 부족 케이스가 없다', async () => {
  const db = memDb(seedBase({ 'users/u1': { qoinBalance: 3000 } }));
  const a = await runVerify({ db, request: req({ q: 2000, key: 'idemA' }) });
  const b = await runVerify({ db, request: req({ q: 2000, key: 'idemB' }) });
  assert.equal(a.err, null);
  assert.ok(b.err);
  assert.match(b.err.message, /\[QOIN_INSUFFICIENT_BALANCE\]$/);
  assert.equal(b.spy.confirm, 0);
  assert.equal(balanceOf(db), 1000);
  assert.equal(db.store.has('orders/idemB'), false);
});

test('Promise.all 동시 2건 (트랜잭션 직렬 의미): 정확히 한 건만 성공, 잔액 음수 없음', async () => {
  const db = memDb(seedBase({ 'users/u1': { qoinBalance: 3000 } }));
  const [a, b] = await Promise.all([
    runVerify({ db, request: req({ q: 2000, key: 'idemA' }) }),
    runVerify({ db, request: req({ q: 2000, key: 'idemB' }) }),
  ]);
  assert.equal([a, b].filter((x) => x.err === null).length, 1);
  assert.equal(balanceOf(db), 1000);
  assert.equal([a, b].reduce((n, x) => n + x.spy.confirm, 0), 1, 'confirm 은 성공한 한 건만');
});

// ── 자기거래 가드와 정합 ─────────────────────────────────────────────────────
test('자기거래 가드가 먼저 거절하면 Qoin 도 안 움직인다', async () => {
  const db = memDb(seedBase({ 'stores/s1': { ownerId: 'u1', status: 'approved' } }));
  const r = await runVerify({ db, request: req({ q: 700 }) });
  assert.equal(r.err.code, 'permission-denied');
  assert.equal(balanceOf(db), 5000);
  assert.equal(db.log.txCount, 0);
});

// payment_price_authority — 교차 골든(옵션 판정 · 카트 산술) + 금액 게이트 단위 테스트. `npm test` (functions/ 에서). 환경 불필요.
//  Dart 쪽: test/core/payment_price_contract_test.dart (같은 fixture 를 읽는다)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { handleVerifyTossPayment } from '../lib/verifyTossPayment.js';
import { classifyCartMenu } from '../lib/menuVisibility.js';
import { resolveSelectableOptions, validateSelection, parseOptionGroup, optionRefKey } from '../lib/optionPricing.js';
import { computeCartAmount, isValidLineQuantity, mergeLineQuantity, MAX_LINE_QUANTITY } from '../lib/cartPricing.js';
import { applyServerPricing } from '../lib/orderBuilder.js';
import { resolvePriceMode, MAX_OPTION_GROUP_DOCS } from '../lib/priceGate.js';
import { buildRejectionMessage } from '../lib/paymentGate.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const load = (n) => JSON.parse(fs.readFileSync(path.join(here, '../../test_fixtures', n), 'utf8'));

// ═════════════════════════════════════════════════════════════════════════════
// 교차 골든
// ═════════════════════════════════════════════════════════════════════════════
const optionContract = load('option_availability_contract.json');
const pricingContract = load('cart_pricing_contract.json');

test('골든 fixture 가 충분하다 (옵션 ≥12 / 산술 ≥10)', () => {
  assert.ok(optionContract.cases.length >= 12);
  assert.ok(pricingContract.cases.length >= 10);
});

for (const c of optionContract.cases) {
  test(`option_availability: ${c.name}`, () => {
    if (c.kind === 'resolve') {
      const groups = c.groups.map((g) => parseOptionGroup(g.id, g.doc));
      const r = resolveSelectableOptions({
        groups,
        disabledGroupIds: new Set(c.disabledGroupIds),
        disabledItemIds: new Set(c.disabledItemIds),
      });
      const view = r.map((g) => ({
        id: g.id, selectionType: g.selectionType, required: g.required,
        items: g.items.map((i) => ({ id: i.id, priceDelta: i.priceDelta })),
      }));
      assert.deepEqual(view, c.expect);
    } else {
      const groupsByRefKey = new Map();
      for (const ref of c.refs) {
        const key = optionRefKey(ref.scope, ref.id);
        const doc = c.groups[key];
        if (doc !== undefined) groupsByRefKey.set(key, doc === null ? null : parseOptionGroup(ref.id, doc));
      }
      // 맵 키 중 refs 에 없는 그룹(notInRefs 케이스)도 읽혀 있는 척 넣는다 — refs 에 없으면 판정이 무시해야 한다.
      for (const [key, doc] of Object.entries(c.groups)) {
        if (!groupsByRefKey.has(key)) groupsByRefKey.set(key, doc === null ? null : parseOptionGroup(key.split(':')[1], doc));
      }
      const r = validateSelection({
        refs: c.refs,
        groupsByRefKey,
        disabledGroupIds: new Set(c.disabledGroupIds),
        disabledItemIds: new Set(c.disabledItemIds),
        selected: c.selected,
      });
      assert.deepEqual(r, { issues: c.expect.issues, priceDeltas: c.expect.priceDeltas });
    }
  });
}

for (const c of pricingContract.cases) {
  test(`cart_pricing: ${c.name}`, () => {
    const lines = c.lines.map((l) => {
      const v = classifyCartMenu({ hasBrand: l.menu.hasBrand, storeMenu: l.menu.storeMenu, master: l.menu.master, override: l.menu.override });
      assert.notEqual(v.merged, null, '골든 케이스의 메뉴는 판매 중이어야 한다');
      return { basePrice: v.merged.basePrice, priceDeltas: l.deltas, quantity: l.quantity };
    });
    const r = computeCartAmount(lines);
    assert.deepEqual(r.lines.map((x) => ({ unit: x.unitPrice, total: x.lineTotal })), c.expect.lines);
    assert.equal(r.subtotal, c.expect.subtotal);
    assert.equal(r.expected, c.expect.expected);
    assert.equal(r.discount, 0);
  });
}

for (const c of pricingContract.quantityCases) {
  test(`quantity 경계: ${c.name}`, () => assert.equal(isValidLineQuantity(c.quantity), c.valid));
}
for (const c of pricingContract.mergeCases) {
  test(`quantity 병합: ${c.name}`, () => assert.equal(mergeLineQuantity(c.existing, c.added), c.expect));
}
test('quantity 상한 상수는 99 (Dart kMaxLineQuantity 와 같은 값 — 골든이 경계를 고정)', () => assert.equal(MAX_LINE_QUANTITY, 99));

// ═════════════════════════════════════════════════════════════════════════════
// 금액 게이트 (verifyTossPayment 2-c)
// ═════════════════════════════════════════════════════════════════════════════
function fakeDb() {
  const state = { rejections: [], batchSets: [], committed: false };
  return {
    state,
    collection(name) {
      return {
        doc(id) {
          return {
            _path: `${name}/${id}`,
            async get() { return { exists: false, data: () => undefined }; },
            collection(sub) { return { doc: (sid) => ({ _path: `${name}/${id}/${sub}/${sid}` }) }; },
          };
        },
        async add(data) {
          // Firestore 는 undefined 필드를 거부한다(ignoreUndefinedProperties 미설정). recordGateRejection 은 실패를 삼키므로
          // 여기서 던지면 기록이 사라져 테스트가 실패한다 — 기록이 조용히 유실되는 것을 막는 장치다.
          const walk = (v, path) => {
            if (v === undefined) throw new Error(`undefined at ${path}`);
            if (Array.isArray(v)) v.forEach((x, i) => walk(x, `${path}[${i}]`));
            else if (v && typeof v === 'object' && !(v instanceof Date)) for (const [k, x] of Object.entries(v)) walk(x, `${path}.${k}`);
          };
          walk(data, name);
          if (name === 'paymentGateRejections') state.rejections.push(data);
          return { id: 'r' };
        },
      };
    },
    runTransaction: async (fn) => {
      const t = { get: async () => ({ exists: false, data: () => undefined }), set: (ref, data) => state.batchSets.push([ref._path, data]) };
      const r = await fn(t);
      state.committed = true;
      return r;
    },
  };
}

/** groups: { 'scope:id': rawDoc|null } */
function fakeReader({ store = { status: 'approved', approvedAt: {} }, storeMenus = {}, overrides = {}, masters = {}, groups = {}, failGroups = false, failStore = false } = {}) {
  const calls = { getStore: 0, getMenuDocs: 0, getOptionGroups: 0, groupRefs: 0 };
  return {
    calls,
    async getStore() { calls.getStore++; if (failStore) throw new Error('boom'); return store; },
    async getMenuDocs(_s, brandId, ids) {
      calls.getMenuDocs++;
      const m = { storeMenus: new Map(), overrides: new Map(), masters: new Map() };
      for (const id of ids) {
        m.storeMenus.set(id, storeMenus[id] ?? null);
        if (brandId !== null) { m.overrides.set(id, overrides[id] ?? null); m.masters.set(id, masters[id] ?? null); }
      }
      return m;
    },
    async getOptionGroups(_s, _b, refs) {
      calls.getOptionGroups++;
      calls.groupRefs = refs.length;
      if (failGroups) throw new Error('boom');
      const out = new Map();
      for (const r of refs) { const k = optionRefKey(r.scope, r.id); out.set(k, groups[k] ?? null); }
      return out;
    },
  };
}

function run({ reader, gateMode = () => 'off', priceMode = () => 'enforce', secret = 'live_sk_real' }, request) {
  const db = fakeDb();
  const spy = { confirm: 0 };
  const deps = {
    db, secretKey: () => secret, gateReader: reader, gateMode, priceMode: priceMode === 'none' ? undefined : priceMode,
    confirm: async (_k, p) => { spy.confirm++; return { paymentKey: p.paymentKey, orderId: p.orderId, status: 'DONE', totalAmount: p.amount, approvedAt: new Date().toISOString(), easyPay: null }; },
    cancel: async () => ({}),
  };
  return handleVerifyTossPayment(deps, request).then(
    (result) => ({ result, err: null, spy, db }),
    (err) => ({ result: null, err, spy, db })
  );
}

const sel = (groupId, itemId, priceDelta = 0) => ({ groupId, groupName: groupId, itemId, label: itemId, priceDelta });
const line = (id, { unit = 4000, qty = 1, total, opts = [] } = {}) => ({
  menuItemId: id, menuItemName: id, quantity: qty, selectedOptions: opts, unitPriceWithOptions: unit, lineTotal: total ?? unit * qty,
});
/** 클라가 내부적으로 정합한 카트를 만든다 (amount = totalPrice = subtotal = Σ lineTotal). 아니면 over 로 깬다. */
const cartReq = (items, over = {}, cartOver = {}) => {
  const sum = items.reduce((a, i) => a + i.lineTotal, 0);
  return {
    auth: { uid: 'u1' },
    data: {
      paymentKey: 'pk', orderId: 'idem1', amount: sum, idempotencyKey: 'idem1', paymentMethod: 'card',
      cart: { storeId: 's1', storeName: '강남점', items, subtotal: sum, totalPrice: sum, ...cartOver },
      ...over,
    },
  };
};

const M = { basePrice: 4000, soldOut: false, visible: true };
const MOPT = (refs, extra = {}) => ({ ...M, optionGroupRefs: refs, ...extra });
const G = (items, extra = {}) => ({ selectionType: 'single', required: false, items, ...extra });

// ── 통과 ────────────────────────────────────────────────────────────────────
test('통과: 옵션 없는 정상 결제 (enforce) — confirm 1회, 주문 문서 작성', async () => {
  const reader = fakeReader({ storeMenus: { m1: M } });
  const r = await run({ reader }, cartReq([line('m1')]));
  assert.equal(r.err, null);
  assert.equal(r.spy.confirm, 1);
  assert.equal(r.db.state.rejections.length, 0);
  assert.ok(r.db.state.committed);
});

test('통과(불변식): 옵션이 붙은 정상 결제 — 음수 priceDelta 포함, 같은 메뉴 2줄', async () => {
  const reader = fakeReader({
    storeMenus: { m1: MOPT([{ scope: 'brand', id: 'g1' }, { scope: 'store', id: 'g2' }]) },
    store: { status: 'approved', approvedAt: {}, brandId: 'b1' },
    groups: {
      'brand:g1': G([{ id: 'shot', priceDelta: 500 }, { id: 'none', priceDelta: 0 }]),
      'store:g2': G([{ id: 'tumbler', priceDelta: -300 }], { selectionType: 'multi' }),
    },
  });
  const items = [
    line('m1', { unit: 4500, opts: [sel('g1', 'shot', 500)] }),
    line('m1', { unit: 4200, qty: 2, opts: [sel('g1', 'shot', 500), sel('g2', 'tumbler', -300)] }),
  ];
  const r = await run({ reader }, cartReq(items));
  assert.equal(r.err, null, r.err?.message);
  assert.equal(r.spy.confirm, 1);
  assert.equal(reader.calls.getOptionGroups, 1, '옵션 그룹은 getAll 1 round-trip');
  assert.equal(reader.calls.groupRefs, 2);
});

// ── §4-3 판정식 ① ~ ⑥ ────────────────────────────────────────────────────────
function assertMismatch(r, { checks, ids, reasonCode = 'failed-precondition' }) {
  assert.equal(r.err?.code, reasonCode, r.err?.message);
  assert.equal(r.spy.confirm, 0, 'R5: 거절 경로에서 Toss confirm 을 호출하지 않는다');
  assert.equal(r.db.state.committed, false);
  assert.equal(r.db.state.rejections.length, 1);
  const rec = r.db.state.rejections[0];
  assert.deepEqual(rec.detail.checks, checks);
  return rec;
}

test('① amount ≠ cart.totalPrice: 기존 검사가 그대로 거절한다 (invalid-argument, confirm 0)', async () => {
  const reader = fakeReader({ storeMenus: { m1: M } });
  const r = await run({ reader }, cartReq([line('m1')], { amount: 1 }));
  assert.equal(r.err?.code, 'invalid-argument');
  assert.equal(r.spy.confirm, 0);
});

test('② totalPrice ≠ subtotal (amount = totalPrice): PRICE_MISMATCH', async () => {
  const reader = fakeReader({ storeMenus: { m1: M } });
  const r = await run({ reader }, cartReq([line('m1')], { amount: 4000 }, { subtotal: 5000 }));
  const rec = assertMismatch(r, { checks: { c1: true, c2: false, c3: false, c4: true, c5: true, c6: true } });
  assert.equal(rec.reason, 'PRICE_MISMATCH');
  assert.ok(r.err.message.endsWith('[PRICE_MISMATCH]'), r.err.message);
});

test('③ 이 task 의 존재 이유: amount 1 + 17,000원어치 items — 거절, confirm 0, 부호 있는 delta 기록', async () => {
  const reader = fakeReader({ storeMenus: { m1: M } });
  const items = [line('m1', { unit: 4000, qty: 4, total: 16000 }), line('m1', { unit: 1000, total: 1000 })];
  const r = await run({ reader }, cartReq(items, { amount: 1 }, { subtotal: 1, totalPrice: 1 }));
  const rec = assertMismatch(r, { checks: { c1: true, c2: true, c3: false, c4: false, c5: false, c6: false } });
  assert.equal(rec.detail.clientAmount, 1);
  assert.equal(rec.detail.serverExpected, 20000);
  assert.equal(rec.detail.delta, -19999, '공격자는 적게 낸다 — 음수로 크게 치우친다');
  assert.equal(rec.detail.lines.length, 2);
  assert.equal(rec.detail.lines[1].clientLineTotal, 1000);
  assert.equal(rec.detail.lines[1].serverLineTotal, 4000);
  assert.ok(r.err.message.endsWith('[PRICE_MISMATCH:m1]'), r.err.message);
});

test('④ 클라가 내부적으로 정합하지만 문서 가격과 다르다 (가격이 바뀐 뒤의 카트): c4 위반, delta 양수/음수', async () => {
  const reader = fakeReader({ storeMenus: { m1: { ...M, basePrice: 4500 } } });
  const r = await run({ reader }, cartReq([line('m1', { unit: 4000 })]));
  const rec = assertMismatch(r, { checks: { c1: true, c2: true, c3: true, c4: false, c5: false, c6: false } });
  assert.equal(rec.detail.delta, -500);
  const reader2 = fakeReader({ storeMenus: { m1: { ...M, basePrice: 3500 } } });
  const r2 = await run({ reader: reader2 }, cartReq([line('m1', { unit: 4000 })]));
  assert.equal(r2.db.state.rejections[0].detail.delta, 500, '가격이 내려간 쪽도 거절한다 (통과시키면 정상 고객을 과다 청구)');
  assert.equal(r2.spy.confirm, 0);
});

test('⑤ 총액은 맞는데 라인 배분이 다르다 (items 만 거짓): c5·c6 위반, c4 는 통과', async () => {
  const reader = fakeReader({ storeMenus: { m1: M, m2: { ...M, basePrice: 6000 } } });
  const items = [line('m1', { unit: 5000 }), line('m2', { unit: 5000 })]; // 서버: 4000 + 6000 = 10000, 클라: 5000 + 5000 = 10000
  const r = await run({ reader }, cartReq(items));
  const rec = assertMismatch(r, { checks: { c1: true, c2: true, c3: true, c4: true, c5: false, c6: false } });
  assert.deepEqual(rec.detail.lines.map((l) => l.serverLineTotal), [4000, 6000]);
  assert.ok(r.err.message.endsWith('[PRICE_MISMATCH:m1,m2]'), r.err.message);
});

test('⑥ lineTotal 은 맞는데 unitPriceWithOptions 가 거짓: c6 만 위반', async () => {
  const reader = fakeReader({ storeMenus: { m1: M } });
  const r = await run({ reader }, cartReq([line('m1', { unit: 3999, total: 4000 })]));
  assertMismatch(r, { checks: { c1: true, c2: true, c3: true, c4: true, c5: true, c6: false } });
  assert.ok(r.err.message.endsWith('[PRICE_MISMATCH:m1]'), r.err.message);
});

test('수량 조작: 음수·0·소수·100 초과는 가격을 깎는 입력이므로 거절', async () => {
  for (const q of [-1, 0, 1.5, 100]) {
    const reader = fakeReader({ storeMenus: { m1: M, m2: M } });
    const bad = { ...line('m2'), quantity: q, lineTotal: 4000 * q };
    const r = await run({ reader }, cartReq([line('m1', { qty: 3 }), bad]));
    assert.equal(r.err?.code, 'failed-precondition', `quantity ${q}`);
    assert.equal(r.spy.confirm, 0);
    assert.equal(r.db.state.rejections[0].detail.lines[1].unusable, 'badQuantity');
  }
});

// ── 옵션 사유 ────────────────────────────────────────────────────────────────
const optionCases = [
  ['notInRefs: 메뉴에 연결되지 않은 그룹 (더 싼 그룹을 끌어옴)', { refs: [{ scope: 'store', id: 'g1' }], groups: { 'store:g1': G([{ id: 'a', priceDelta: 0 }]), 'store:gX': G([{ id: 'x', priceDelta: -3000 }]) }, opts: [sel('gX', 'x', -3000)], kind: 'notInRefs' }],
  ['missing: 유령 ref (그룹 문서 부재)', { refs: [{ scope: 'store', id: 'g1' }], groups: {}, opts: [sel('g1', 'a')], kind: 'missing' }],
  ['missing: 그룹에 없는 항목', { refs: [{ scope: 'store', id: 'g1' }], groups: { 'store:g1': G([{ id: 'a' }]) }, opts: [sel('g1', 'zzz')], kind: 'missing' }],
  ['inactive: active=false 그룹', { refs: [{ scope: 'store', id: 'g1' }], groups: { 'store:g1': G([{ id: 'a' }], { active: false }) }, opts: [sel('g1', 'a')], kind: 'inactive' }],
  ['disabled: 점주가 끈 항목 (composite)', { refs: [{ scope: 'store', id: 'g1' }], groups: { 'store:g1': G([{ id: 'a' }]) }, opts: [sel('g1', 'a')], kind: 'disabled', menuExtra: { disabledOptionItemIds: ['g1_a'] } }],
  ['disabled: 점주가 끈 그룹', { refs: [{ scope: 'store', id: 'g1' }], groups: { 'store:g1': G([{ id: 'a' }]) }, opts: [sel('g1', 'a')], kind: 'disabled', menuExtra: { disabledOptionGroupIds: ['g1'] } }],
  ['requiredEmpty: 필수 그룹에 선택 없음', { refs: [{ scope: 'store', id: 'g1' }], groups: { 'store:g1': G([{ id: 'a' }], { required: true }) }, opts: [], kind: 'requiredEmpty' }],
  ['multiInSingle: single 그룹에 2개', { refs: [{ scope: 'store', id: 'g1' }], groups: { 'store:g1': G([{ id: 'a' }, { id: 'b' }]) }, opts: [sel('g1', 'a'), sel('g1', 'b')], kind: 'multiInSingle' }],
  ['duplicate: 음수 priceDelta 를 반복해 가격을 깎는다', { refs: [{ scope: 'store', id: 'g1' }], groups: { 'store:g1': G([{ id: 't', priceDelta: -300 }], { selectionType: 'multi' }) }, opts: [sel('g1', 't', -300), sel('g1', 't', -300)], kind: 'duplicate' }],
];
for (const [name, c] of optionCases) {
  test(`옵션 사유 OPTION_UNAVAILABLE — ${name}`, async () => {
    const reader = fakeReader({ storeMenus: { m1: MOPT(c.refs, c.menuExtra ?? {}) }, groups: c.groups });
    // 클라는 자기가 본 가격을 그대로 선언한다 (priceDelta 합) — 금액은 맞아 보이는데 옵션이 위반이다.
    const unit = 4000 + c.opts.reduce((a, o) => a + o.priceDelta, 0);
    const r = await run({ reader }, cartReq([line('m1', { unit, opts: c.opts })]));
    assert.equal(r.err?.code, 'failed-precondition', r.err?.message);
    assert.ok(r.err.message.endsWith('[OPTION_UNAVAILABLE:m1]'), r.err.message);
    assert.equal(r.spy.confirm, 0);
    assert.equal(r.db.state.rejections.length, 1);
    assert.equal(r.db.state.rejections[0].reason, 'OPTION_UNAVAILABLE');
    assert.ok(r.db.state.rejections[0].detail.optionIssues.some((x) => x.kind === c.kind && x.menuItemId === 'm1'), JSON.stringify(r.db.state.rejections[0].detail.optionIssues));
  });
}

test('사유 우선순위: 옵션 위반 + 금액 불일치 = OPTION_UNAVAILABLE (옵션이 고객이 고칠 수 있는 쪽)', async () => {
  const reader = fakeReader({ storeMenus: { m1: MOPT([{ scope: 'store', id: 'g1' }]) }, groups: { 'store:g1': G([{ id: 'a' }], { required: true }) } });
  const r = await run({ reader }, cartReq([line('m1', { unit: 1, total: 1 })]));
  assert.ok(r.err.message.endsWith('[OPTION_UNAVAILABLE:m1]'), r.err.message);
});

// ── 읽기 실패 / 상한 ─────────────────────────────────────────────────────────
test('옵션 그룹 읽기 실패 = READ_FAILED (unavailable) + 기록 — 통과시키지 않는다', async () => {
  const reader = fakeReader({ storeMenus: { m1: MOPT([{ scope: 'store', id: 'g1' }]) }, failGroups: true });
  const r = await run({ reader }, cartReq([line('m1')]));
  assert.equal(r.err?.code, 'unavailable');
  assert.ok(r.err.message.endsWith('[READ_FAILED]'));
  assert.equal(r.spy.confirm, 0);
  assert.equal(r.db.state.rejections[0].detail.failure, 'optionGroupsUnreadable');
});

test('매장 읽기 실패(게이트 off + 가격 enforce 직접 읽기) = READ_FAILED, 통과 아님', async () => {
  const reader = fakeReader({ failStore: true });
  const r = await run({ reader }, cartReq([line('m1')]));
  assert.equal(r.err?.code, 'unavailable');
  assert.equal(r.spy.confirm, 0);
  assert.equal(r.db.state.rejections[0].detail.failure, 'storeUnreadable');
});

test('옵션 그룹 수 상한(MAX_OPTION_GROUP_DOCS) 초과 = READ_FAILED + failure 기록, 옵션 그룹은 읽지 않는다', async () => {
  const refs = Array.from({ length: MAX_OPTION_GROUP_DOCS + 1 }, (_, i) => ({ scope: 'store', id: `g${i}` }));
  const reader = fakeReader({ storeMenus: { m1: MOPT(refs) } });
  const r = await run({ reader }, cartReq([line('m1')]));
  assert.equal(r.err?.code, 'unavailable');
  assert.equal(r.db.state.rejections[0].detail.failure, 'optionGroupCapExceeded');
  assert.equal(reader.calls.getOptionGroups, 0);
  assert.equal(r.spy.confirm, 0);
});

test('같은 그룹을 가리키는 메뉴 둘 = 중복 제거해 1회만 읽는다', async () => {
  const refs = [{ scope: 'store', id: 'g1' }];
  const reader = fakeReader({ storeMenus: { m1: MOPT(refs), m2: MOPT(refs) }, groups: { 'store:g1': G([{ id: 'a' }]) } });
  const r = await run({ reader }, cartReq([line('m1'), line('m2')]));
  assert.equal(r.err, null);
  assert.equal(reader.calls.groupRefs, 1);
});

// ── 모드 ────────────────────────────────────────────────────────────────────
test('모드 resolvePriceMode: 정확 일치만 — 없음/오타/대소문자/공백은 off (resolveGateMode 와 같은 폴백)', () => {
  assert.equal(resolvePriceMode('shadow'), 'shadow');
  assert.equal(resolvePriceMode('enforce'), 'enforce');
  for (const raw of [undefined, null, '', 'off', 'Enforce', 'ENFORCE', 'enforce ', ' shadow', 'true', 1, {}]) {
    assert.equal(resolvePriceMode(raw), 'off', String(raw));
  }
});

for (const raw of [undefined, '', 'off', 'Enforce', 'enforce ', 'weird']) {
  test(`모드 off(${JSON.stringify(raw)}): 매장·메뉴·옵션 그룹 읽기 0회, 금액이 틀려도 결제 성립 (현행 동작)`, async () => {
    const reader = fakeReader({ storeMenus: { m1: M } });
    const r = await run({ reader, priceMode: () => raw }, cartReq([line('m1', { unit: 1, total: 1 })]));
    assert.equal(r.err, null);
    assert.equal(r.spy.confirm, 1);
    assert.deepEqual(reader.calls, { getStore: 0, getMenuDocs: 0, getOptionGroups: 0, groupRefs: 0 });
    assert.equal(r.db.state.rejections.length, 0);
  });
}

test('priceMode thunk 자체가 없어도 off', async () => {
  const reader = fakeReader({ storeMenus: { m1: M } });
  const r = await run({ reader, priceMode: 'none' }, cartReq([line('m1', { unit: 1, total: 1 })]));
  assert.equal(r.err, null);
  assert.equal(reader.calls.getOptionGroups, 0);
});

test('shadow: 금액이 틀려도 결제 성립 + 기록 1건(detail.shadow:true) + 주문 문서는 클라 값 그대로 (R8: shadow 는 쓰지 않는다)', async () => {
  const reader = fakeReader({ storeMenus: { m1: M } });
  const items = [line('m1', { unit: 1, total: 1 })];
  const r = await run({ reader, priceMode: () => 'shadow' }, cartReq(items));
  assert.equal(r.err, null);
  assert.equal(r.spy.confirm, 1);
  assert.equal(r.db.state.rejections.length, 1);
  assert.equal(r.db.state.rejections[0].detail.shadow, true);
  assert.equal(r.db.state.rejections[0].detail.delta, -3999);
  const order = r.db.state.batchSets.find(([p]) => p.startsWith('orders/'))[1];
  assert.equal(order.totalPrice, 1, 'shadow 는 관측만 — 주문 문서를 서버 값으로 바꾸지 않는다');
  assert.equal(order.items[0].unitPriceWithOptions, 1);
});

test('shadow: 정상 결제는 기록 0건', async () => {
  const reader = fakeReader({ storeMenus: { m1: M } });
  const r = await run({ reader, priceMode: () => 'shadow' }, cartReq([line('m1')]));
  assert.equal(r.err, null);
  assert.equal(r.db.state.rejections.length, 0);
});

test('shadow: 옵션 그룹 읽기 실패도 거절하지 않는다 (READ_FAILED 는 기록만)', async () => {
  const reader = fakeReader({ storeMenus: { m1: M } });
  reader.getOptionGroups = async () => { throw new Error('boom'); };
  reader.getMenuDocs = async (...a) => { const m = await fakeReader({ storeMenus: { m1: MOPT([{ scope: 'store', id: 'g1' }]) } }).getMenuDocs(...a); return m; };
  const r = await run({ reader, priceMode: () => 'shadow' }, cartReq([line('m1')]));
  assert.equal(r.err, null, 'READ_FAILED 는 기록이고 shadow 는 거절하지 않는다');
  assert.equal(r.spy.confirm, 1);
});

test('enforce: 주문·로그 문서의 금액 필드는 서버 재계산값이다 (R8)', async () => {
  const reader = fakeReader({ storeMenus: { m1: MOPT([{ scope: 'store', id: 'g1' }]) }, groups: { 'store:g1': G([{ id: 'a', priceDelta: 500 }]) } });
  const r = await run({ reader }, cartReq([line('m1', { unit: 4500, qty: 2, opts: [sel('g1', 'a', 500)] })]));
  assert.equal(r.err, null);
  for (const [p, doc] of r.db.state.batchSets.filter(([p]) => !p.includes('/pickupCounters/'))) { // 카운터 문서는 금액 문서가 아니다
    assert.equal(doc.totalPrice, 9000, p);
    assert.equal(doc.items[0].lineTotal, 9000, p);
    assert.equal(doc.items[0].unitPriceWithOptions, 4500, p);
  }
  const order = r.db.state.batchSets.find(([p]) => p.startsWith('orders/'))[1];
  assert.equal(order.subtotal, 9000);
  assert.equal(order.discount, null);
});

test('applyServerPricing: 금액 필드만 서버 값으로 바꾸고 이름·옵션 라벨·discount 는 그대로 (Q4 ⓐ)', () => {
  const cart = { storeId: 's', storeName: 'n', discount: null, subtotal: 1, totalPrice: 1,
    items: [{ menuItemId: 'm', menuItemName: '이름', quantity: 2, selectedOptions: [sel('g', 'a', 5)], unitPriceWithOptions: 1, lineTotal: 1 }] };
  const out = applyServerPricing(cart, { lines: [{ unitPrice: 4500, lineTotal: 9000 }], subtotal: 9000, expected: 9000 });
  assert.equal(out.items[0].unitPriceWithOptions, 4500);
  assert.equal(out.items[0].lineTotal, 9000);
  assert.equal(out.subtotal, 9000);
  assert.equal(out.totalPrice, 9000);
  assert.equal(out.items[0].menuItemName, '이름');
  assert.deepEqual(out.items[0].selectedOptions, cart.items[0].selectedOptions);
  assert.equal(cart.totalPrice, 1, '원본을 바꾸지 않는다');
});

// ── 플래그 조합 (spec §8) ─────────────────────────────────────────────────────
test('조합: 게이트 off + 가격 enforce — 조용히 통과하지 않는다 (가격 모드가 메뉴를 직접 읽어 거절)', async () => {
  const reader = fakeReader({ storeMenus: { m1: M } });
  const r = await run({ reader, gateMode: () => 'off', priceMode: () => 'enforce' }, cartReq([line('m1', { unit: 1, total: 1 })]));
  assert.equal(r.err?.code, 'failed-precondition');
  assert.ok(r.err.message.endsWith('[PRICE_MISMATCH:m1]'));
  assert.equal(r.spy.confirm, 0);
  assert.equal(reader.calls.getMenuDocs, 1);
});

test('H-01: 거절 기록에 clientLevel 이 남는다 (신버전 = 숫자, 구버전 = null) — 구버전 비율을 재는 수단, 판정에는 쓰지 않는다', async () => {
  const mk = (extra) => { const q = cartReq([line('m1', { unit: 1, total: 1 })]); Object.assign(q.data, extra); return q; };
  const reader = fakeReader({ storeMenus: { m1: M } });
  const a = await run({ reader, priceMode: () => 'shadow' }, mk({ clientLevel: 1 }));
  assert.equal(a.db.state.rejections[0].detail.clientLevel, 1);
  const b = await run({ reader, priceMode: () => 'shadow' }, mk({}));
  assert.equal(b.db.state.rejections[0].detail.clientLevel, null);
  const c = await run({ reader, priceMode: () => 'shadow' }, mk({ clientLevel: 'evil' }));
  assert.equal(c.db.state.rejections[0].detail.clientLevel, null);
  assert.equal(b.err, null, '구버전이어도 shadow 는 결제를 막지 않는다');
});

test('조합: 게이트 off + 가격 enforce — 정상 카트는 통과', async () => {
  const reader = fakeReader({ storeMenus: { m1: M } });
  const r = await run({ reader, gateMode: () => 'off', priceMode: () => 'enforce' }, cartReq([line('m1')]));
  assert.equal(r.err, null);
  assert.equal(r.spy.confirm, 1);
});

test('조합: 게이트 off 일 때 가격 모드는 품절을 판정하지 않는다 (가격이 필요할 뿐)', async () => {
  const reader = fakeReader({ storeMenus: { m1: { ...M, soldOut: true } } });
  const r = await run({ reader, gateMode: () => 'off', priceMode: () => 'enforce' }, cartReq([line('m1')]));
  assert.equal(r.err, null, '품절 거절은 PAYMENT_GATE_MODE 의 일이다');
});

test('조합: 게이트 off + 가격 enforce — 해석 불가한 메뉴(문서 없음)는 계산할 수 없으므로 거절', async () => {
  const reader = fakeReader({});
  const r = await run({ reader, gateMode: () => 'off', priceMode: () => 'enforce' }, cartReq([line('ghost')]));
  assert.equal(r.err?.code, 'failed-precondition');
  assert.equal(r.db.state.rejections[0].detail.lines[0].unusable, 'menuUnresolved');
});

test('조합: 게이트 enforce + 가격 enforce — 메뉴 문서는 1회만 읽는다 (G2 산출물 재사용, 추가 읽기 0)', async () => {
  const reader = fakeReader({ storeMenus: { m1: M } });
  const r = await run({ reader, gateMode: () => 'enforce', priceMode: () => 'enforce' }, cartReq([line('m1')]));
  assert.equal(r.err, null);
  assert.equal(reader.calls.getStore, 1);
  assert.equal(reader.calls.getMenuDocs, 1);
});

test('조합: 게이트 shadow(위반) + 가격 enforce — 가격 모드가 직접 읽어 계속 판정한다', async () => {
  const reader = fakeReader({ storeMenus: { m1: { ...M, soldOut: true } } });
  const r = await run({ reader, gateMode: () => 'shadow', priceMode: () => 'enforce' }, cartReq([line('m1', { unit: 1, total: 1 })]));
  assert.equal(r.err?.code, 'failed-precondition');
  assert.ok(r.err.message.endsWith('[PRICE_MISMATCH:m1]'));
  assert.equal(r.db.state.rejections.length, 2, '품절 shadow 기록 + 가격 거절 기록');
});

test('조합: 게이트 enforce 의 품절 거절이 가격 게이트보다 먼저다 (가격 모드 읽기 없이 거절)', async () => {
  const reader = fakeReader({ storeMenus: { m1: { ...M, soldOut: true } } });
  const r = await run({ reader, gateMode: () => 'enforce', priceMode: () => 'enforce' }, cartReq([line('m1')]));
  assert.ok(r.err.message.endsWith('[MENU_SOLD_OUT:m1]'));
  assert.equal(reader.calls.getOptionGroups, 0);
});

// ── 토큰 문법 (선행 §15.1 을 그대로 잇는다) ─────────────────────────────────────
test('토큰: 금액 사유 2종도 메뉴 사유와 같은 문법 — id 있으면 [R:id1,id2], 없으면 [R]', () => {
  assert.ok(buildRejectionMessage('PRICE_MISMATCH', ['a', 'b']).endsWith('[PRICE_MISMATCH:a,b]'));
  assert.ok(buildRejectionMessage('PRICE_MISMATCH', []).endsWith('[PRICE_MISMATCH]'));
  assert.ok(buildRejectionMessage('OPTION_UNAVAILABLE', ['m1']).endsWith('[OPTION_UNAVAILABLE:m1]'));
  assert.ok(buildRejectionMessage('OPTION_UNAVAILABLE', ['bad,id', 'ok']).endsWith('[OPTION_UNAVAILABLE:ok]'), '문법을 통과하지 못한 id 는 싣지 않는다');
});

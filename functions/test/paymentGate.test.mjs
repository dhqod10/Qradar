// 결제 게이트 단위 테스트 — `npm test` (functions/ 에서). 환경 불필요 (Firestore·Toss 주입).
// spec payment_server_authority §18.4: 매장 상태 6케이스 × 메뉴 5케이스, confirm 미호출 단언, 거절 기록 1건, 토큰 문법.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { handleVerifyTossPayment } from '../lib/verifyTossPayment.js';
import { buildRejectionMessage, TOKEN_ID_RE, MAX_CART_ITEMS } from '../lib/paymentGate.js';

// ── fakes ───────────────────────────────────────────────────────────────────
function fakeDb({ existingOrder = null } = {}) {
  const state = { rejections: [], batchSets: [], committed: false };
  const db = {
    state,
    collection(name) {
      return {
        doc(id) {
          return {
            _path: `${name}/${id}`,
            async get() {
              if (name === 'orders' && existingOrder) return { exists: true, data: () => existingOrder };
              return { exists: false, data: () => undefined };
            },
            collection(sub) {
              return { doc: (sid) => ({ _path: `${name}/${id}/${sub}/${sid}` }) };
            },
          };
        },
        async add(data) {
          if (name === 'paymentGateRejections') state.rejections.push(data);
          return { id: 'rej1' };
        },
      };
    },
    batch() {
      return {
        set: (ref, data) => state.batchSets.push([ref._path, data]),
        commit: async () => { state.committed = true; },
      };
    },
  };
  return db;
}

/** stores / menu 문서를 맵으로 받는 reader. */
function fakeReader({ store, storeMenus = {}, overrides = {}, masters = {}, failStore = false, failMenus = false }) {
  const calls = { getMenuDocs: 0, brandId: undefined };
  return {
    calls,
    async getStore() {
      if (failStore) throw new Error('boom');
      return store ?? null;
    },
    async getMenuDocs(_s, brandId, ids) {
      calls.getMenuDocs++;
      calls.brandId = brandId;
      if (failMenus) throw new Error('boom');
      const m = { storeMenus: new Map(), overrides: new Map(), masters: new Map() };
      for (const id of ids) {
        m.storeMenus.set(id, storeMenus[id] ?? null);
        if (brandId !== null) {
          m.overrides.set(id, overrides[id] ?? null);
          m.masters.set(id, masters[id] ?? null);
        }
      }
      return m;
    },
  };
}

function setup({ reader, db = fakeDb(), secret = 'live_sk_real' }) {
  const spy = { confirm: 0, cancel: 0 };
  const deps = {
    db,
    secretKey: () => secret,
    confirm: async (_k, p) => {
      spy.confirm++;
      return { paymentKey: p.paymentKey, orderId: p.orderId, status: 'DONE', totalAmount: p.amount, approvedAt: new Date().toISOString(), easyPay: null };
    },
    cancel: async () => { spy.cancel++; return {}; },
    gateReader: reader,
  };
  return { deps, spy, db };
}

const item = (id, name = id) => ({
  menuItemId: id, menuItemName: name, imageUrl: '', quantity: 1, selectedOptions: [],
  unitPriceWithOptions: 4000, lineTotal: 4000,
});
const req = (items, over = {}) => ({
  auth: { uid: 'u1' },
  data: {
    paymentKey: 'pk', orderId: 'idem1', amount: 4000 * items.length, idempotencyKey: 'idem1', paymentMethod: 'card',
    cart: { storeId: 's1', storeName: '강남점', items, subtotal: 4000 * items.length, totalPrice: 4000 * items.length },
    ...over,
  },
});

async function run(setupArgs, request) {
  const { deps, spy, db } = setup(setupArgs);
  let err = null;
  let result = null;
  try { result = await handleVerifyTossPayment(deps, request); } catch (e) { err = e; }
  return { err, result, spy, db, deps };
}

const OKSTORE = { status: 'approved', approvedAt: {} };
const OKMENU = { basePrice: 4000, soldOut: false, visible: true };

// ── 매장 상태 6케이스 ────────────────────────────────────────────────────────
const storeCases = [
  ['approved', OKSTORE, null, null],
  ['pending + approvedAt (정보 수정 직후 — R2 불변식)', { status: 'pending', approvedAt: {} }, null, null],
  ['pending 단독', { status: 'pending' }, 'STORE_NOT_SELLABLE', 'failed-precondition'],
  ['rejected', { status: 'rejected', approvedAt: {} }, 'STORE_NOT_SELLABLE', 'failed-precondition'],
  ['status 부재 (legacy — M1 전)', { approvedAt: {} }, 'STORE_NOT_SELLABLE', 'failed-precondition'],
  ['알 수 없는 status', { status: 'weird', approvedAt: {} }, 'STORE_NOT_SELLABLE', 'failed-precondition'],
];
for (const [name, store, reason, code] of storeCases) {
  test(`G1 매장: ${name}`, async () => {
    const reader = fakeReader({ store, storeMenus: { m1: OKMENU } });
    const r = await run({ reader }, req([item('m1')]));
    if (reason === null) {
      assert.equal(r.err, null);
      assert.equal(r.spy.confirm, 1);
      assert.equal(r.db.state.rejections.length, 0);
      assert.ok(r.db.state.committed);
    } else {
      assert.equal(r.err?.code, code);
      assert.ok(r.err.message.endsWith(`[${reason}]`), r.err.message);
      assert.equal(r.spy.confirm, 0, 'R5: 거절 경로에서 Toss confirm 을 호출하지 않는다');
      assert.equal(r.db.state.rejections.length, 1);
      assert.equal(r.db.state.rejections[0].reason, reason);
      assert.equal(r.db.state.rejections[0].uid, 'u1');
      assert.equal(r.db.state.rejections[0].storeId, 's1');
      assert.equal(r.db.state.rejections[0].amount, 4000);
      assert.equal(r.db.state.committed, false);
    }
  });
}

test('G1 매장 문서 부재 → STORE_NOT_FOUND (not-found)', async () => {
  const r = await run({ reader: fakeReader({ store: null }) }, req([item('m1')]));
  assert.equal(r.err?.code, 'not-found');
  assert.ok(r.err.message.endsWith('[STORE_NOT_FOUND]'));
  assert.equal(r.spy.confirm, 0);
  assert.equal(r.db.state.rejections[0].reason, 'STORE_NOT_FOUND');
});

test('G1 매장 읽기 실패 → READ_FAILED (unavailable), 게이트를 무력화하지 않는다', async () => {
  const r = await run({ reader: fakeReader({ failStore: true }) }, req([item('m1')]));
  assert.equal(r.err?.code, 'unavailable');
  assert.ok(r.err.message.endsWith('[READ_FAILED]'));
  assert.equal(r.spy.confirm, 0);
  assert.equal(r.db.state.rejections[0].reason, 'READ_FAILED');
});

// ── 메뉴 5케이스 ────────────────────────────────────────────────────────────
test('G2 개인 매장 메뉴 정상 → 통과, 마스터는 읽지 않는다 (brandId null)', async () => {
  const reader = fakeReader({ store: OKSTORE, storeMenus: { m1: OKMENU } });
  const r = await run({ reader }, req([item('m1')]));
  assert.equal(r.err, null);
  assert.equal(reader.calls.brandId, null);
  assert.equal(r.spy.confirm, 1);
});

test('G2 품절 → MENU_SOLD_OUT + id 토큰, 이름은 토큰에 없다', async () => {
  const reader = fakeReader({ store: OKSTORE, storeMenus: { m1: OKMENU, m2: { ...OKMENU, soldOut: true } } });
  const r = await run({ reader }, req([item('m1'), item('m2', '품절 라떼')]));
  assert.equal(r.err?.code, 'failed-precondition');
  assert.ok(r.err.message.endsWith('[MENU_SOLD_OUT:m2]'), r.err.message);
  assert.ok(!r.err.message.includes('품절 라떼'), '메뉴명은 서버가 보내지 않는다');
  assert.equal(r.spy.confirm, 0);
  const rec = r.db.state.rejections[0];
  assert.deepEqual(rec.detail.violatedMenuItemIds, ['m2']);
  assert.deepEqual(rec.detail.violatedMenuNames, ['품절 라떼']);
});

test('G2 여러 메뉴 품절 + 같은 메뉴 옵션 2줄 → 종류 단위로 id 한 번씩', async () => {
  const sold = { ...OKMENU, soldOut: true };
  const reader = fakeReader({ store: OKSTORE, storeMenus: { a: sold, b: sold } });
  const r = await run({ reader }, req([item('a'), item('a'), item('b')]));
  assert.ok(r.err.message.endsWith('[MENU_SOLD_OUT:a,b]'), r.err.message);
});

test('G2 가맹점: pending override + soldOut 거절 / pending override + excluded 허용 (applyOverrideForCustomer 와 동일)', async () => {
  const store = { ...OKSTORE, brandId: 'b1' };
  const master = { basePrice: 4000, soldOut: false };
  const soldOut = await run(
    { reader: fakeReader({ store, masters: { m1: master }, overrides: { m1: { status: 'pending', soldOut: true } } }) },
    req([item('m1')])
  );
  assert.ok(soldOut.err.message.endsWith('[MENU_SOLD_OUT:m1]'));
  const excludedPending = await run(
    { reader: fakeReader({ store, masters: { m1: master }, overrides: { m1: { status: 'pending', excluded: true } } }) },
    req([item('m1')])
  );
  assert.equal(excludedPending.err, null, 'excluded 는 approved 일 때만 적용');
  const excludedApproved = await run(
    { reader: fakeReader({ store, masters: { m1: master }, overrides: { m1: { status: 'approved', excluded: true } } }) },
    req([item('m1')])
  );
  assert.ok(excludedApproved.err.message.endsWith('[MENU_EXCLUDED:m1]'));
  assert.equal(excludedApproved.spy.confirm, 0);
});

test('G2 메뉴 문서 부재 → MENU_NOT_FOUND (not-found)', async () => {
  const r = await run({ reader: fakeReader({ store: OKSTORE }) }, req([item('ghost')]));
  assert.equal(r.err?.code, 'not-found');
  assert.ok(r.err.message.endsWith('[MENU_NOT_FOUND:ghost]'));
});

test('G2 메뉴 읽기 실패 → READ_FAILED', async () => {
  const r = await run({ reader: fakeReader({ store: OKSTORE, failMenus: true }) }, req([item('m1')]));
  assert.equal(r.err?.code, 'unavailable');
  assert.ok(r.err.message.endsWith('[READ_FAILED]'));
  assert.equal(r.spy.confirm, 0);
});

test('G2 사유가 섞이면 SOLD_OUT 이 우선하고 토큰은 그 사유의 id 만 싣는다 (기록에는 전부)', async () => {
  const reader = fakeReader({ store: OKSTORE, storeMenus: { a: { ...OKMENU, soldOut: true }, b: { ...OKMENU, visible: false } } });
  const r = await run({ reader }, req([item('a'), item('b'), item('c')]));
  assert.ok(r.err.message.endsWith('[MENU_SOLD_OUT:a]'), r.err.message);
  assert.deepEqual(r.db.state.rejections[0].detail.violatedMenuItemIds.sort(), ['a', 'b', 'c']);
});

test('경로를 오염시킬 수 있는 menuItemId 는 읽지 않고 NOT_FOUND, 토큰에 싣지 않는다', async () => {
  const reader = fakeReader({ store: OKSTORE, storeMenus: { m1: OKMENU } });
  const r = await run({ reader }, req([item('m1'), item('x/../../users/u1')]));
  assert.equal(r.err?.code, 'not-found');
  assert.ok(r.err.message.endsWith('[MENU_NOT_FOUND]'), r.err.message);
  assert.equal(r.spy.confirm, 0);
});

// ── 입력 상한 / 멱등 / 기록 실패 ────────────────────────────────────────────
test(`cart.items > ${MAX_CART_ITEMS} → invalid-argument, 토큰 없음 (갈래 C), 게이트·confirm 미도달`, async () => {
  const items = Array.from({ length: MAX_CART_ITEMS + 1 }, (_, i) => item(`m${i}`));
  const reader = fakeReader({ store: OKSTORE });
  const r = await run({ reader }, req(items));
  assert.equal(r.err?.code, 'invalid-argument');
  assert.ok(!/\[[A-Z_]+(:[^\]]*)?\]$/.test(r.err.message));
  assert.equal(reader.calls.getMenuDocs, 0);
  assert.equal(r.spy.confirm, 0);
});

test(`cart.items == ${MAX_CART_ITEMS} 는 통과`, async () => {
  const items = Array.from({ length: MAX_CART_ITEMS }, (_, i) => item(`m${i}`));
  const storeMenus = Object.fromEntries(items.map((i) => [i.menuItemId, OKMENU]));
  const r = await run({ reader: fakeReader({ store: OKSTORE, storeMenus }) }, req(items));
  assert.equal(r.err, null);
});

test('멱등 히트(이미 처리된 주문)는 게이트를 타지 않고 기존 결과를 돌려준다', async () => {
  const reader = fakeReader({ store: { status: 'rejected' } });
  const r = await run({ reader, db: fakeDb({ existingOrder: { status: 'paid' } }) }, req([item('m1')]));
  assert.equal(r.err, null);
  assert.deepEqual(r.result, { orderId: 'idem1', status: 'paid' });
  assert.equal(r.spy.confirm, 0);
  assert.equal(r.db.state.rejections.length, 0);
});

test('거절 기록 쓰기가 실패해도 거절 결과는 그대로다', async () => {
  const db = fakeDb();
  const origCollection = db.collection.bind(db);
  db.collection = (name) => {
    const c = origCollection(name);
    if (name === 'paymentGateRejections') c.add = async () => { throw new Error('write failed'); };
    return c;
  };
  const r = await run({ reader: fakeReader({ store: { status: 'pending' } }), db }, req([item('m1')]));
  assert.equal(r.err?.code, 'failed-precondition');
  assert.ok(r.err.message.endsWith('[STORE_NOT_SELLABLE]'));
  assert.equal(r.spy.confirm, 0);
});

test('통과 시 단가 포함 해석 결과가 만들어진다 (N1 이 소비할 반환 구조)', async () => {
  const { evaluatePaymentGate } = await import('../lib/paymentGate.js');
  const store = { ...OKSTORE, brandId: 'b1' };
  const reader = fakeReader({
    store,
    masters: { m1: { basePrice: 4000, soldOut: false } },
    overrides: { m1: { status: 'approved', priceOverride: 3500 } },
    storeMenus: { s1m: { basePrice: 2000, soldOut: false } },
  });
  const g = await evaluatePaymentGate(reader, { storeId: 's1', items: [item('m1'), item('s1m')] });
  assert.equal(g.ok, true);
  const byId = Object.fromEntries(g.resolved.map((x) => [x.menuItemId, x]));
  assert.equal(byId.m1.merged.basePrice, 3500);
  assert.equal(byId.m1.source, 'master');
  assert.equal(byId.s1m.merged.basePrice, 2000);
  assert.equal(byId.s1m.source, 'store');
});

// ── 토큰 문법 (spec §15.1) ───────────────────────────────────────────────────
const TOKEN_RE = /\[(?<reason>[A-Z][A-Z0-9_]{2,39})(?::(?<ids>[A-Za-z0-9_,-]{1,2048}))?\]$/;

test('토큰은 §15.1 문법을 만족하고 message 맨 끝에 온다', () => {
  for (const [reason, ids] of [
    ['MENU_SOLD_OUT', ['id1', 'id2']], ['MENU_EXCLUDED', ['id1']], ['MENU_NOT_FOUND', ['a', 'b', 'c']],
    ['STORE_NOT_SELLABLE', []], ['STORE_NOT_FOUND', []], ['READ_FAILED', []],
  ]) {
    const m = buildRejectionMessage(reason, ids).match(TOKEN_RE);
    assert.ok(m, reason);
    assert.equal(m.groups.reason, reason);
    assert.equal(m.groups.ids, ids.length ? ids.join(',') : undefined);
  }
});

test('매장 사유 3종은 ids 를 받아도 싣지 않는다 / 문법 밖 id 는 버린다', () => {
  assert.ok(buildRejectionMessage('STORE_NOT_SELLABLE', ['x']).endsWith('[STORE_NOT_SELLABLE]'));
  assert.ok(buildRejectionMessage('MENU_SOLD_OUT', ['ok', 'b:ad', 'x,y', 'ü']).endsWith('[MENU_SOLD_OUT:ok]'));
  assert.ok(buildRejectionMessage('MENU_SOLD_OUT', ['b:ad']).endsWith('[MENU_SOLD_OUT]'));
});

test('최대 품목 수의 토큰 길이가 ids 상한 2048 안이다 (절단이 구조적으로 발생하지 않는다)', () => {
  const ids = Array.from({ length: MAX_CART_ITEMS }, () => 'x'.repeat(20) + '12');
  const msg = buildRejectionMessage('MENU_SOLD_OUT', ids);
  const m = msg.match(TOKEN_RE);
  assert.ok(m);
  assert.ok(m.groups.ids.length <= 2048);
  assert.ok(ids.every((i) => TOKEN_ID_RE.test(i)));
});

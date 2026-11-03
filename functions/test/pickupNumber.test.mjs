// order_pickup_number — 매장·일별(KST) 픽업번호 발급: KST 경계, 순증·유니크, 동시 경합, 멱등, 오펀 방지.
// 실 Firestore 접촉 0. 인메모리 fake 는 Firestore 트랜잭션의 낙관적 동시성(읽은 문서가 바뀌면 재시도)을 모사한다.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { handleVerifyTossPayment } from '../lib/verifyTossPayment.js';
import { kstDateKey, nextPickupNumber } from '../lib/pickupCounter.js';
import { buildOrderData, buildOrderLogData } from '../lib/orderBuilder.js';

// ── 순수 ─────────────────────────────────────────────────────────────────────
test('kstDateKey: UTC 15:00 = KST 자정 경계', () => {
  assert.equal(kstDateKey(new Date('2026-11-03T14:59:59Z')), '20261103');
  assert.equal(kstDateKey(new Date('2026-11-03T15:00:00Z')), '20261104');
  assert.equal(kstDateKey(new Date('2026-11-03T00:00:00+09:00')), '20261103');
  assert.equal(kstDateKey(new Date('2026-11-02T23:59:59+09:00')), '20261102');
});
test('kstDateKey: 연말 / 월말 경계', () => {
  assert.equal(kstDateKey(new Date('2026-12-31T15:00:00Z')), '20270101');
  assert.equal(kstDateKey(new Date('2026-02-28T15:00:00Z')), '20260301');
});
test('nextPickupNumber: 문서 없음/비정상 → 1, 정상 → +1', () => {
  assert.equal(nextPickupNumber(undefined), 1);
  assert.equal(nextPickupNumber(null), 1);
  assert.equal(nextPickupNumber(0), 1);
  assert.equal(nextPickupNumber(-3), 1);
  assert.equal(nextPickupNumber(2.5), 1);
  assert.equal(nextPickupNumber('3'), 1);
  assert.equal(nextPickupNumber(3), 4);
});
test('orderBuilder: pickupNumber 는 값이 있을 때만 키가 생긴다', () => {
  const cart = { storeId: 's1', storeName: 'S', items: [], subtotal: 1, totalPrice: 1 };
  const t = { approvedAt: 1, now: 2 };
  assert.ok(!('pickupNumber' in buildOrderData(cart, 'u', {}, t)));
  assert.equal(buildOrderData(cart, 'u', {}, t, 3).pickupNumber, 3);
  assert.ok(!('pickupNumber' in buildOrderLogData(cart, { logId: 'l', orderId: 'o', paymentMethod: 'card' }, t)));
  assert.equal(buildOrderLogData(cart, { logId: 'l', orderId: 'o', paymentMethod: 'card', pickupNumber: 3 }, t).pickupNumber, 3);
});

// ── 낙관적 동시성 인메모리 db ─────────────────────────────────────────────────
const clone = (v) => (v === undefined ? v : structuredClone(v));
function memDb(seed = {}, opts = {}) {
  const store = new Map(Object.entries(seed).map(([k, v]) => [k, clone(v)]));
  const versions = new Map();
  const ver = (p) => versions.get(p) ?? 0;
  const stats = { retries: 0, commits: 0 };
  const snap = (p) => ({ exists: store.has(p), data: () => clone(store.get(p)) });
  const docRef = (p) => ({ _path: p, id: p.split('/').pop(), async get() { return snap(p); }, collection: (sub) => colRef(`${p}/${sub}`) });
  const colRef = (p) => ({ doc: (id) => docRef(`${p}/${id}`), async add() { return { id: 'r' }; } });
  return {
    store, stats,
    collection: (n) => colRef(n),
    async runTransaction(fn) {
      for (let attempt = 0; attempt < 20; attempt++) {
        const reads = new Map();
        const writes = [];
        const t = {
          get: async (ref) => { reads.set(ref._path, ver(ref._path)); return snap(ref._path); },
          set: (ref, d) => { writes.push([ref._path, d]); },
        };
        const r = await fn(t);
        await new Promise((res) => setImmediate(res)); // 다른 호출이 끼어들 틈 — 경합 재현
        if ([...reads].some(([p, v]) => ver(p) !== v)) { stats.retries++; continue; }
        if (opts.failCommit) throw new Error('commit boom');
        for (const [p, d] of writes) { store.set(p, clone(d)); versions.set(p, ver(p) + 1); }
        stats.commits++;
        return r;
      }
      throw new Error('too much contention');
    },
  };
}

const item = (id, unit) => ({ menuItemId: id, menuItemName: id, quantity: 1, selectedOptions: [], unitPriceWithOptions: unit, lineTotal: unit });
const gateReader = () => ({
  async getStore() { return { status: 'approved', approvedAt: {} }; },
  async getMenuDocs(_s, _b, ids) { const m = { storeMenus: new Map(), overrides: new Map(), masters: new Map() }; for (const i of ids) m.storeMenus.set(i, null); return m; },
  async getOptionGroups() { return new Map(); },
});
const req = ({ key = 'o1', storeId = 's1', uid = 'u1' } = {}) => ({
  auth: { uid },
  data: {
    paymentKey: 'pk-' + key, orderId: key, amount: 4000, idempotencyKey: key, paymentMethod: 'card',
    cart: { storeId, storeName: storeId, items: [item('m1', 4000)], subtotal: 4000, discount: null, totalPrice: 4000 },
  },
});
async function run(db, request, { approvedAt = '2026-11-03T10:00:00+09:00', onConfirm } = {}) {
  const spy = { cancel: 0 };
  const deps = {
    db, secretKey: () => 'live_sk_real', gateReader: gateReader(), gateMode: () => 'off',
    confirm: async (_k, p) => { if (onConfirm) onConfirm(); return { paymentKey: p.paymentKey, orderId: p.orderId, status: 'DONE', totalAmount: p.amount, approvedAt, easyPay: null }; },
    cancel: async () => { spy.cancel++; return {}; },
  };
  try { return { result: await handleVerifyTossPayment(deps, request), err: null, spy }; } catch (err) { return { result: null, err, spy }; }
}
const numOf = (db, id) => db.store.get(`orders/${id}`)?.pickupNumber;
const logs = (db) => [...db.store.entries()].filter(([k]) => k.startsWith('users/'));

test('같은 매장·같은 날: 1,2,3 순증, 주문·로그 번호 동일, 카운터 current 일치', async () => {
  const db = memDb();
  for (const k of ['a', 'b', 'c']) assert.equal((await run(db, req({ key: k }))).err, null);
  assert.deepEqual(['a', 'b', 'c'].map((k) => numOf(db, k)), [1, 2, 3]);
  assert.equal(db.store.get('stores/s1/pickupCounters/20261103').current, 3);
  const logNums = logs(db).map(([, d]) => [d.orderId, d.pickupNumber]).sort();
  assert.deepEqual(logNums, [['a', 1], ['b', 2], ['c', 3]]);
});

test('매장이 다르면 카운터가 독립', async () => {
  const db = memDb();
  await run(db, req({ key: 'a', storeId: 's1' }));
  await run(db, req({ key: 'b', storeId: 's2' }));
  await run(db, req({ key: 'c', storeId: 's1' }));
  assert.deepEqual([numOf(db, 'a'), numOf(db, 'b'), numOf(db, 'c')], [1, 1, 2]);
});

test('KST 자정 경계: 직전은 어제 카운터 이어서, 직후는 새 날 1부터', async () => {
  const db = memDb();
  await run(db, req({ key: 'a' }), { approvedAt: '2026-11-03T23:59:59+09:00' });
  await run(db, req({ key: 'b' }), { approvedAt: '2026-11-03T14:59:59Z' }); // = KST 23:59:59 (UTC 표기)
  await run(db, req({ key: 'c' }), { approvedAt: '2026-11-04T00:00:00+09:00' });
  await run(db, req({ key: 'd' }), { approvedAt: '2026-11-03T15:00:01Z' }); // = KST 11/04 00:00:01
  assert.deepEqual(['a', 'b', 'c', 'd'].map((k) => numOf(db, k)), [1, 2, 1, 2]);
  assert.equal(db.store.get('stores/s1/pickupCounters/20261103').current, 2);
  assert.equal(db.store.get('stores/s1/pickupCounters/20261104').current, 2);
});

test('동시 경합: 12건 동시 결제 → 번호 중복 없이 1..12 (트랜잭션 재시도)', async () => {
  const db = memDb();
  const keys = Array.from({ length: 12 }, (_, i) => `k${i}`);
  const rs = await Promise.all(keys.map((k) => run(db, req({ key: k }))));
  assert.ok(rs.every((r) => r.err === null));
  const nums = keys.map((k) => numOf(db, k)).sort((a, b) => a - b);
  assert.deepEqual(nums, Array.from({ length: 12 }, (_, i) => i + 1));
  assert.equal(db.store.get('stores/s1/pickupCounters/20261103').current, 12);
  assert.ok(db.stats.retries > 0, '경합이 실제로 재현돼 재시도가 일어났다');
});

test('멱등 (3-pre): 이미 커밋된 주문 재호출 → 재발급 없음, 카운터 불변, 새 로그 없음', async () => {
  const db = memDb();
  await run(db, req({ key: 'a' }));
  const before = clone(db.store.get('stores/s1/pickupCounters/20261103'));
  const r = await run(db, req({ key: 'a' }));
  assert.deepEqual(r.result, { orderId: 'a', status: 'paid' });
  assert.deepEqual(db.store.get('stores/s1/pickupCounters/20261103'), before);
  assert.equal(numOf(db, 'a'), 1);
  assert.equal(logs(db).length, 1);
});

test('멱등 (트랜잭션 재확인): 3-pre 통과 후 confirm 중 동시 호출이 먼저 커밋 → 재발급·덮어쓰기 없음', async () => {
  const db = memDb();
  const r = await run(db, req({ key: 'a' }), {
    onConfirm: () => {
      db.store.set('orders/a', { status: 'accepted', pickupNumber: 7 });
      db.store.set('stores/s1/pickupCounters/20261103', { current: 7 });
    },
  });
  assert.equal(r.err, null);
  assert.deepEqual(r.result, { orderId: 'a', status: 'accepted' });
  assert.equal(numOf(db, 'a'), 7, '기존 주문의 번호 그대로');
  assert.equal(db.store.get('stores/s1/pickupCounters/20261103').current, 7, '카운터 불변');
  assert.equal(logs(db).length, 0, '중복 로그 없음');
  assert.equal(r.spy.cancel, 0, '이미 커밋된 주문의 결제를 취소하지 않는다');
});

test('오펀 방지: 커밋 실패 → 카운터·주문·로그 모두 미생성', async () => {
  const db = memDb({ 'stores/s1/pickupCounters/20261103': { current: 4 } }, { failCommit: true });
  const r = await run(db, req({ key: 'a' }));
  assert.equal(r.err.message, 'commit boom');
  assert.equal(db.store.get('stores/s1/pickupCounters/20261103').current, 4, '카운터 불변 — 번호를 낭비하지 않는다');
  assert.equal(db.store.has('orders/a'), false);
  assert.equal(logs(db).length, 0);
});

test('카운터 문서가 이미 있으면 이어서 발급', async () => {
  const db = memDb({ 'stores/s1/pickupCounters/20261103': { current: 41 } });
  await run(db, req({ key: 'a' }));
  assert.equal(numOf(db, 'a'), 42);
});

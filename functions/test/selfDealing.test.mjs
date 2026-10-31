// prelaunch_security_bundle — 자기거래 가드(Layer1) + 신호수집(Layer2) 단위 테스트. 실 Firestore 접촉 0.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { handleVerifyTossPayment } from '../lib/verifyTossPayment.js';
import { matchSelfDealing, findSelfDealing } from '../lib/selfDealing.js';
import { buildOrderSignalDoc, hashSignal } from '../lib/orderSignals.js';

// ── 순수 판정 ────────────────────────────────────────────────────────────────
test('matchSelfDealing: 점주 일치 → owner', () => {
  assert.equal(matchSelfDealing('u1', { ownerId: 'u1', brandId: null }), 'owner');
});
test('matchSelfDealing: 타인 매장 → null', () => {
  assert.equal(matchSelfDealing('u1', { ownerId: 'u2', brandId: null }), null);
  assert.equal(matchSelfDealing('u1', { ownerId: 'u2' }, { role: 'brand', brandId: 'B' }), null); // 매장 brandId 없음
});
test('matchSelfDealing: 브랜드 보유자 → brandHolder', () => {
  assert.equal(matchSelfDealing('u1', { ownerId: 'u2', brandId: 'B1' }, { role: 'brand', brandId: 'B1' }), 'brandHolder');
});
test('matchSelfDealing: 다른 브랜드 / 역할 불일치 / 공백 brandId → null', () => {
  assert.equal(matchSelfDealing('u1', { ownerId: 'u2', brandId: 'B1' }, { role: 'brand', brandId: 'B2' }), null);
  assert.equal(matchSelfDealing('u1', { ownerId: 'u2', brandId: 'B1' }, { role: 'customer', brandId: 'B1' }), null);
  assert.equal(matchSelfDealing('u1', { ownerId: 'u2', brandId: '' }, { role: 'brand', brandId: '' }), null);
});
test('matchSelfDealing: ownerId 부재/빈 문자열은 uid 와 매칭되지 않는다', () => {
  assert.equal(matchSelfDealing('', { ownerId: '' }), null);
  assert.equal(matchSelfDealing('u1', {}), null);
});

// ── fake db ─────────────────────────────────────────────────────────────────
function fakeDb({ stores = {}, users = {}, failStore = false, failSignal = false } = {}) {
  const state = { rejections: [], batchSets: [], committed: false, signals: [], userReads: 0 };
  return {
    state,
    collection(name) {
      return {
        doc(id) {
          return {
            _path: `${name}/${id}`,
            async get() {
              if (name === 'stores') {
                if (failStore) throw new Error('boom');
                const d = stores[id];
                return { exists: !!d, data: () => d };
              }
              if (name === 'users') { state.userReads++; const d = users[id]; return { exists: !!d, data: () => d }; }
              return { exists: false, data: () => undefined };
            },
            async create(data) {
              if (name !== 'orderSignals') throw new Error('unexpected create');
              if (failSignal) throw new Error('signal boom');
              state.signals.push([id, data]);
            },
            collection(sub) { return { doc: (sid) => ({ _path: `${name}/${id}/${sub}/${sid}` }) }; },
          };
        },
        async add(data) { if (name === 'paymentGateRejections') state.rejections.push(data); return { id: 'r' }; },
      };
    },
    batch() { return { set: (ref, data) => state.batchSets.push([ref._path, data]), commit: async () => { state.committed = true; } }; },
  };
}

const req = (over = {}, extra = {}) => ({
  auth: { uid: 'u1' },
  rawRequest: { ip: '1.2.3.4' },
  data: {
    paymentKey: 'pk', orderId: 'idem1', amount: 4000, idempotencyKey: 'idem1', paymentMethod: 'card', deviceId: 'dev-1',
    cart: { storeId: 's1', storeName: '강남점', items: [], subtotal: 4000, totalPrice: 4000 },
    ...over,
  },
  ...extra,
});

async function run(db, request, opts = {}) {
  const salt = 'salt' in opts ? opts.salt : 'salt';
  const card = 'card' in opts ? opts.card : { company: '현대', number: '43301234****123*' };
  const spy = { confirm: 0 };
  const deps = {
    db, secretKey: () => 'live_sk_real', signalSalt: () => salt,
    confirm: async (_k, p) => { spy.confirm++; return { paymentKey: p.paymentKey, orderId: p.orderId, status: 'DONE', totalAmount: p.amount, approvedAt: new Date().toISOString(), card }; },
    cancel: async () => ({}),
  };
  try { return { result: await handleVerifyTossPayment(deps, request), err: null, spy }; } catch (err) { return { result: null, err, spy }; }
}

// ── Layer1-A ────────────────────────────────────────────────────────────────
test('A: 자기 매장(점주) → permission-denied, confirm 0회, SELF_DEALING 기록 1건, 주문 미생성', async () => {
  const db = fakeDb({ stores: { s1: { ownerId: 'u1' } } });
  const r = await run(db, req());
  assert.equal(r.err?.code, 'permission-denied');
  assert.match(r.err.message, /\[SELF_DEALING\]$/);
  assert.equal(r.spy.confirm, 0);
  assert.equal(db.state.rejections.length, 1);
  assert.equal(db.state.rejections[0].reason, 'SELF_DEALING');
  assert.equal(db.state.rejections[0].detail.matchedBy, 'owner');
  assert.equal(db.state.committed, false);
});
test('A: 브랜드 보유자 → 거절 (matchedBy brandHolder)', async () => {
  const db = fakeDb({ stores: { s1: { ownerId: 'u2', brandId: 'B1' } }, users: { u1: { role: 'brand', brandId: 'B1' } } });
  const r = await run(db, req());
  assert.equal(r.err?.code, 'permission-denied');
  assert.equal(r.spy.confirm, 0);
  assert.equal(db.state.rejections[0].detail.matchedBy, 'brandHolder');
});
test('A: 타인 매장(개인) → 통과, users read 0, 주문 커밋', async () => {
  const db = fakeDb({ stores: { s1: { ownerId: 'u2', brandId: null } } });
  const r = await run(db, req());
  assert.equal(r.err, null);
  assert.deepEqual(r.result, { orderId: 'idem1', status: 'paid' });
  assert.equal(r.spy.confirm, 1);
  assert.equal(db.state.userReads, 0);
  assert.equal(db.state.rejections.length, 0);
  assert.equal(db.state.committed, true);
});
test('A: 타인 가맹 매장 + 일반 고객 → 통과', async () => {
  const db = fakeDb({ stores: { s1: { ownerId: 'u2', brandId: 'B1' } }, users: { u1: { role: 'customer' } } });
  const r = await run(db, req());
  assert.equal(r.err, null);
  assert.equal(r.spy.confirm, 1);
});
test('A: 매장 문서 없음 → 가드 건너뜀 (기존 동작 유지, 신호는 owner null)', async () => {
  const db = fakeDb();
  const r = await run(db, req());
  assert.equal(r.err, null);
  assert.equal(db.state.signals[0][1].storeOwnerId, null);
});
test('A: 매장 read 실패 → unavailable, confirm 0회 (통과시키지 않는다)', async () => {
  const db = fakeDb({ failStore: true });
  const r = await run(db, req());
  assert.equal(r.err?.code, 'unavailable');
  assert.equal(r.spy.confirm, 0);
});
test('A: 기록 실패가 거절 결과를 바꾸지 않는다', async () => {
  const db = fakeDb({ stores: { s1: { ownerId: 'u1' } } });
  db.collection = ((orig) => (n) => { const c = orig(n); if (n === 'paymentGateRejections') c.add = async () => { throw new Error('x'); }; return c; })(db.collection.bind(db));
  const r = await run(db, req());
  assert.equal(r.err?.code, 'permission-denied');
});

// ── Layer2 ──────────────────────────────────────────────────────────────────
test('L2: 신호 문서 — 해시/마스킹형만, 원본 없음', async () => {
  const db = fakeDb({ stores: { s1: { ownerId: 'u2', brandId: 'B1' } }, users: { u1: { role: 'customer' } } });
  await run(db, req());
  assert.equal(db.state.signals.length, 1);
  const [id, doc] = db.state.signals[0];
  assert.equal(id, 'idem1');
  assert.equal(doc.userId, 'u1');
  assert.equal(doc.storeOwnerId, 'u2');
  assert.equal(doc.storeBrandId, 'B1');
  assert.equal(doc.deviceIdHash, createHmac('sha256', 'salt').update('device:dev-1').digest('hex'));
  assert.equal(doc.ipHash, createHmac('sha256', 'salt').update('ip:1.2.3.4').digest('hex'));
  assert.equal(doc.cardCompany, '현대');
  assert.match(doc.cardFingerprint, /^[0-9a-f]{64}$/);
  const dump = JSON.stringify(doc);
  assert.ok(!dump.includes('dev-1') && !dump.includes('1.2.3.4') && !dump.includes('43301234'));
});
test('L2: deviceId 누락(구버전) → deviceIdHash null, 결제 정상', async () => {
  const db = fakeDb({ stores: { s1: { ownerId: 'u2' } } });
  const r = await run(db, req({ deviceId: undefined }));
  assert.equal(r.err, null);
  assert.equal(db.state.signals[0][1].deviceIdHash, null);
});
test('L2: 비카드(card 없음) → cardFingerprint/cardCompany null', async () => {
  const db = fakeDb({ stores: { s1: { ownerId: 'u2' } } });
  await run(db, req(), { card: undefined });
  assert.equal(db.state.signals[0][1].cardFingerprint, null);
  assert.equal(db.state.signals[0][1].cardCompany, null);
});
test('L2 best-effort: 신호 write 실패해도 주문 성공', async () => {
  const db = fakeDb({ stores: { s1: { ownerId: 'u2' } }, failSignal: true });
  const r = await run(db, req());
  assert.equal(r.err, null);
  assert.deepEqual(r.result, { orderId: 'idem1', status: 'paid' });
  assert.equal(db.state.committed, true);
});
test('L2 best-effort: salt 없음 → 신호 생략, 주문 성공', async () => {
  const db = fakeDb({ stores: { s1: { ownerId: 'u2' } } });
  const r = await run(db, req(), { salt: undefined });
  assert.equal(r.err, null);
  assert.equal(db.state.signals.length, 0);
});
test('L2: hashSignal — 종류 분리, 비문자열 null', () => {
  assert.notEqual(hashSignal('s', 'device', 'x'), hashSignal('s', 'ip', 'x'));
  assert.equal(hashSignal('s', 'device', undefined), null);
  assert.equal(hashSignal('s', 'device', ''), null);
});
test('L2: buildOrderSignalDoc 는 주입된 createdAt 을 그대로 쓴다', () => {
  const d = buildOrderSignalDoc('s', { orderId: 'o', userId: 'u', storeId: 's', storeOwnerId: null, storeBrandId: null, deviceId: null, card: undefined, ip: undefined }, 'TS');
  assert.equal(d.createdAt, 'TS');
});

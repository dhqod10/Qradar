// admin_user_moderation — setUserSuspension / adminDeleteUser / 결제 유저 상태 가드. 실 Firestore·Auth 접촉 0.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { runSetUserSuspension } from '../lib/setUserSuspension.js';
import { runAdminDeleteUser } from '../lib/adminDeleteUser.js';
import { runDeleteMyAccount } from '../lib/deleteMyAccount.js';
import { buyerBlockReason, ownerBlockReason } from '../lib/userStateGuard.js';
import { handleVerifyTossPayment } from '../lib/verifyTossPayment.js';
import { buildRejectionMessage, GATE_HTTPS_CODE } from '../lib/paymentGate.js';

// ── setUserSuspension ───────────────────────────────────────────────────────
function susPorts(user) {
  const st = { user: user ? { ...user } : null, commits: [], authCalls: [], revokes: 0 };
  return {
    st,
    async readUser() { return st.user ? { ...st.user } : null; },
    async commit(a) { st.commits.push(a); st.user = { ...st.user, suspended: a.userPatch.suspended }; },
    async setAuthDisabled(uid, d) { st.authCalls.push([uid, d]); return true; },
    async revokeTokens() { st.revokes++; },
  };
}
const sus = (p, over = {}) => runSetUserSuspension(p, { actorUid: 'adm', targetUid: 't1', action: 'suspend', reason: null, now: () => 123, ...over });

test('suspend: 이력 1건 + 플래그 + Auth disabled + revoke', async () => {
  const p = susPorts({ role: 'customer' });
  const r = await sus(p, { reason: '분쟁' });
  assert.deepEqual(r, { changed: true, action: 'suspend', historyId: 't1_123' });
  assert.equal(p.st.commits.length, 1);
  const c = p.st.commits[0];
  assert.equal(c.history.action, 'suspend');
  assert.equal(c.history.changedBy, 'adm');
  assert.deepEqual(c.history.before, { suspended: false });
  assert.deepEqual(c.history.after, { suspended: true });
  assert.equal(c.history.role, 'customer');
  assert.equal(c.history.reason, '분쟁');
  assert.equal(c.userPatch.suspended, true);
  assert.equal(c.userPatch.suspendedBy, 'adm');
  assert.deepEqual(p.st.authCalls, [['t1', true]]);
  assert.equal(p.st.revokes, 1);
});
test('suspend 멱등: 이미 정지면 이력 중복 없음 (Auth 는 재정합)', async () => {
  const p = susPorts({ role: 'owner', suspended: true });
  const r = await sus(p);
  assert.equal(r.changed, false);
  assert.equal(r.historyId, null);
  assert.equal(p.st.commits.length, 0);
});
test('unsuspend: 플래그 해제 + Auth enabled, revoke 없음', async () => {
  const p = susPorts({ role: 'brand', suspended: true });
  const r = await sus(p, { action: 'unsuspend' });
  assert.equal(r.changed, true);
  assert.equal(p.st.commits[0].userPatch.suspended, false);
  assert.equal(p.st.commits[0].history.action, 'unsuspend');
  assert.deepEqual(p.st.authCalls, [['t1', false]]);
  assert.equal(p.st.revokes, 0);
});
test('unsuspend 멱등: 정상 계정이면 no-op', async () => {
  const p = susPorts({ role: 'customer' });
  const r = await sus(p, { action: 'unsuspend' });
  assert.equal(r.changed, false);
  assert.equal(p.st.commits.length, 0);
});
test('admin 대상 거부 [CANNOT_MODERATE_ADMIN], 쓰기 0', async () => {
  const p = susPorts({ role: 'admin' });
  await assert.rejects(() => sus(p), (e) => e.code === 'permission-denied' && e.message.endsWith('[CANNOT_MODERATE_ADMIN]'));
  assert.equal(p.st.commits.length + p.st.authCalls.length, 0);
});
test('본인 대상 거부', async () => {
  const p = susPorts({ role: 'customer' });
  await assert.rejects(() => sus(p, { targetUid: 'adm' }), (e) => e.message.endsWith('[CANNOT_MODERATE_ADMIN]'));
});
test('대상 없음 → not-found', async () => {
  await assert.rejects(() => sus(susPorts(null)), (e) => e.code === 'not-found');
});

// ── adminDeleteUser ─────────────────────────────────────────────────────────
function delPorts({ user, inFlight = 0 }) {
  const st = { user: { ...user }, writes: [], authDeletes: 0 };
  return {
    st,
    async readUser() { return st.user ? { ...st.user } : null; },
    async findIncompleteHistory() { return null; },
    async writeHistory(id, patch) { st.writes.push([id, patch]); },
    async countInFlightOrders() { return inFlight; },
    async forfeitQoin() { return st.user.qoinBalance ?? 0; },
    async anonymizeUser() {},
    async deleteFavorites() { return { favoriteStores: 0, favoriteMenuItems: 0 }; },
    async deleteAuthUser() { st.authDeletes++; },
  };
}
const adel = (p, over = {}) => runAdminDeleteUser(p, { actorUid: 'adm', targetUid: 'c1', reason: null, dryRun: false, ...over });

test('adminDeleteUser: customer → deletedBy=admin, byAdmin:true, 코어 완료', async () => {
  const p = delPorts({ user: { role: 'customer', qoinBalance: 500 } });
  const r = await adel(p);
  assert.equal(r.phase, 'done');
  const started = p.st.writes.find(([, w]) => w.phase === 'started')[1];
  assert.equal(started.deletedBy, 'adm');
  assert.equal(started.byAdmin, true);
  assert.equal(started.uid, 'c1');
  assert.equal(p.st.authDeletes, 1);
});
test('adminDeleteUser: owner/brand → [FORCE_DELETE_CUSTOMER_ONLY], 쓰기 0', async () => {
  for (const role of ['owner', 'brand']) {
    const p = delPorts({ user: { role } });
    await assert.rejects(() => adel(p), (e) => e.message.endsWith('[FORCE_DELETE_CUSTOMER_ONLY]'));
    assert.equal(p.st.writes.length, 0);
  }
});
test('adminDeleteUser: admin 대상 / 본인 → [CANNOT_MODERATE_ADMIN]', async () => {
  await assert.rejects(() => adel(delPorts({ user: { role: 'admin' } })), (e) => e.message.endsWith('[CANNOT_MODERATE_ADMIN]'));
  await assert.rejects(() => adel(delPorts({ user: { role: 'customer' } }), { targetUid: 'adm' }), (e) => e.message.endsWith('[CANNOT_MODERATE_ADMIN]'));
});
test('adminDeleteUser: 진행중 주문 → 코어 가드 승계, 이력 없음', async () => {
  const p = delPorts({ user: { role: 'customer' }, inFlight: 2 });
  await assert.rejects(() => adel(p), (e) => e.code === 'failed-precondition' && e.message.endsWith('[ACCOUNT_HAS_INFLIGHT_ORDERS]'));
  assert.equal(p.st.writes.length, 0);
});
test('adminDeleteUser: dryRun 쓰기 0', async () => {
  const p = delPorts({ user: { role: 'customer', qoinBalance: 300 }, inFlight: 1 });
  const r = await adel(p, { dryRun: true });
  assert.deepEqual(r, { dryRun: true, inFlightOrders: 1, qoinToForfeit: 300, canDelete: false });
  assert.equal(p.st.writes.length, 0);
});
test('self-탈퇴 회귀: actorUid 없으면 deletedBy=uid, byAdmin 키 없음', async () => {
  const p = delPorts({ user: { role: 'customer' } });
  await runDeleteMyAccount(p, { uid: 'c1', reason: null, dryRun: false });
  const started = p.st.writes.find(([, w]) => w.phase === 'started')[1];
  assert.equal(started.deletedBy, 'c1');
  assert.equal('byAdmin' in started, false);
});

// ── 순수 판정 ───────────────────────────────────────────────────────────────
test('buyerBlockReason / ownerBlockReason', () => {
  assert.equal(buyerBlockReason(null), null);
  assert.equal(buyerBlockReason({ role: 'customer' }), null);
  assert.equal(buyerBlockReason({ suspended: false }), null);
  assert.equal(buyerBlockReason({ suspended: true }), 'USER_SUSPENDED');
  assert.equal(buyerBlockReason({ deleted: true }), 'USER_DELETED');
  assert.equal(buyerBlockReason({ deleted: true, suspended: true }), 'USER_DELETED');
  assert.equal(ownerBlockReason({ suspended: true }), 'STORE_OWNER_SUSPENDED');
  assert.equal(ownerBlockReason({ deleted: true }), 'STORE_OWNER_SUSPENDED');
  assert.equal(ownerBlockReason({}), null);
  assert.equal(ownerBlockReason(null), null);
});
test('게이트 사유 토큰/코드', () => {
  assert.match(buildRejectionMessage('USER_SUSPENDED'), /\[USER_SUSPENDED\]$/);
  assert.match(buildRejectionMessage('USER_DELETED'), /\[USER_DELETED\]$/);
  assert.match(buildRejectionMessage('STORE_OWNER_SUSPENDED'), /\[STORE_OWNER_SUSPENDED\]$/);
  assert.equal(GATE_HTTPS_CODE.USER_SUSPENDED, 'permission-denied');
});

// ── verifyTossPayment 통합 (fake db) ────────────────────────────────────────
function fakeDb({ stores = {}, users = {}, failUsers = false } = {}) {
  const state = { rejections: [], committed: false };
  return {
    state,
    collection(name) {
      return {
        doc(id) {
          return {
            _path: `${name}/${id}`,
            async get() {
              if (name === 'stores') { const d = stores[id]; return { exists: !!d, data: () => d }; }
              if (name === 'users') { if (failUsers) throw new Error('boom'); const d = users[id]; return { exists: !!d, data: () => d }; }
              return { exists: false, data: () => undefined };
            },
            async create() {},
            collection(sub) { return { doc: (sid) => ({ _path: `${name}/${id}/${sub}/${sid}` }) }; },
          };
        },
        async add(data) { if (name === 'paymentGateRejections') state.rejections.push(data); return { id: 'r' }; },
      };
    },
    runTransaction: async (fn) => {
      const t = { get: async () => ({ exists: false, data: () => undefined }), set: () => {} };
      const r = await fn(t); state.committed = true; return r;
    },
  };
}
const req = () => ({
  auth: { uid: 'u1' }, rawRequest: { ip: '1.2.3.4' },
  data: { paymentKey: 'pk', orderId: 'idem1', amount: 4000, idempotencyKey: 'idem1', paymentMethod: 'card',
    cart: { storeId: 's1', storeName: '강남점', items: [], subtotal: 4000, totalPrice: 4000 } },
});
async function run(db) {
  const spy = { confirm: 0 };
  const deps = {
    db, secretKey: () => 'k',
    confirm: async (_k, p) => { spy.confirm++; return { paymentKey: p.paymentKey, orderId: p.orderId, status: 'DONE', totalAmount: p.amount, approvedAt: new Date().toISOString(), card: { company: 'x', number: '1' } }; },
    cancel: async () => ({}),
  };
  try { return { err: null, result: await handleVerifyTossPayment(deps, req()), spy }; } catch (err) { return { err, spy }; }
}

test('결제: 결제자 정지 → USER_SUSPENDED, confirm 0, 기록 1건', async () => {
  const db = fakeDb({ stores: { s1: { ownerId: 'u2' } }, users: { u1: { suspended: true } } });
  const r = await run(db);
  assert.equal(r.err?.code, 'permission-denied');
  assert.match(r.err.message, /\[USER_SUSPENDED\]$/);
  assert.equal(r.spy.confirm, 0);
  assert.equal(db.state.rejections[0].reason, 'USER_SUSPENDED');
  assert.equal(db.state.committed, false);
});
test('결제: 결제자 deleted → USER_DELETED (tester 보류 해소)', async () => {
  const db = fakeDb({ stores: { s1: { ownerId: 'u2' } }, users: { u1: { deleted: true } } });
  const r = await run(db);
  assert.match(r.err.message, /\[USER_DELETED\]$/);
  assert.equal(r.spy.confirm, 0);
});
test('결제: 매장 점주 정지 → STORE_OWNER_SUSPENDED, confirm 0', async () => {
  const db = fakeDb({ stores: { s1: { ownerId: 'u2' } }, users: { u1: { role: 'customer' }, u2: { suspended: true } } });
  const r = await run(db);
  assert.equal(r.err?.code, 'failed-precondition');
  assert.match(r.err.message, /\[STORE_OWNER_SUSPENDED\]$/);
  assert.equal(r.spy.confirm, 0);
  assert.equal(db.state.rejections[0].reason, 'STORE_OWNER_SUSPENDED');
});
test('결제: 정상 유저 + 정상 점주 → 통과', async () => {
  const db = fakeDb({ stores: { s1: { ownerId: 'u2' } }, users: { u1: { role: 'customer' }, u2: { role: 'owner' } } });
  const r = await run(db);
  assert.equal(r.err, null);
  assert.equal(r.spy.confirm, 1);
});
test('결제: 유저 문서 없음 → 판정 안 함 (기존 동작)', async () => {
  const db = fakeDb({ stores: { s1: { ownerId: 'u2' } } });
  const r = await run(db);
  assert.equal(r.err, null);
});
test('결제: users read 실패 → unavailable, confirm 0 (통과시키지 않는다)', async () => {
  const db = fakeDb({ stores: { s1: { ownerId: 'u2' } }, failUsers: true });
  const r = await run(db);
  assert.equal(r.err?.code, 'unavailable');
  assert.equal(r.spy.confirm, 0);
});

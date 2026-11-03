// account_deletion — deleteMyAccount Core (진행중주문 차단 · 익명화 · Qoin 소멸 · 멱등). `npm test` (functions/ 에서).
// Firestore 비의존: in-memory 포트로 검증한다 (deleteStore 테스트와 같은 방식).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { runDeleteMyAccount, ANONYMIZED_NAME } from '../lib/deleteMyAccount.js';

function ports({ user, inFlight = 0, failAt = null, history = [] } = {}) {
  const st = {
    user: user ? { ...user } : null,
    histories: new Map(history.map((h) => [h.id, { ...h }])),
    writes: [], ledger: [], favDeletes: 0, authDeletes: 0, anonymizes: 0, calls: [],
  };
  const maybeFail = (s) => { if (failAt === s) { failAt = null; throw new Error(`fail:${s}`); } };
  return {
    st,
    async readUser() { return st.user ? { ...st.user } : null; },
    async findIncompleteHistory(uid) { return [...st.histories.values()].find((h) => h.uid === uid && h.phase !== 'done') ?? null; },
    async writeHistory(id, patch) {
      st.calls.push(`h:${patch.phase ?? '-'}`);
      st.writes.push([id, patch]);
      st.histories.set(id, { ...(st.histories.get(id) ?? { id }), ...patch, id });
    },
    async countInFlightOrders() { return inFlight; },
    async forfeitQoin() {
      maybeFail('qoin');
      const already = st.ledger.find((l) => l.type === 'forfeit');
      if (already) return -already.amount;
      const b = st.user?.qoinBalance ?? 0;
      if (b <= 0) return 0;
      st.ledger.push({ type: 'forfeit', amount: -b, balanceAfter: 0 });
      st.user.qoinBalance = 0;
      return b;
    },
    async anonymizeUser() {
      maybeFail('anon'); st.anonymizes++; st.calls.push('anon');
      const u = st.user; delete u.email; delete u.phone; delete u.photoUrl; delete u.fcmToken; delete u.fcmTokenUpdatedAt;
      u.displayName = ANONYMIZED_NAME; u.deleted = true;
    },
    async deleteFavorites() { maybeFail('fav'); st.favDeletes++; return { favoriteStores: 2, favoriteMenuItems: 1 }; },
    async deleteAuthUser() { maybeFail('auth'); st.authDeletes++; st.calls.push('auth'); },
  };
}
const USER = { uid: 'u1', role: 'customer', provider: 'kakao', displayName: '홍길동', email: 'a@b.c', phone: '01012345678', photoUrl: 'x', fcmToken: 't', qoinBalance: 1200 };
const run = (p, over = {}) => runDeleteMyAccount(p, { uid: 'u1', reason: null, dryRun: false, ...over });

test('deleteMyAccount: dryRun 은 쓰기 0건, 진행중주문·소멸Qoin 반환', async () => {
  const p = ports({ user: USER, inFlight: 2 });
  const r = await run(p, { dryRun: true });
  assert.deepEqual(r, { dryRun: true, inFlightOrders: 2, qoinToForfeit: 1200, canDelete: false });
  assert.equal(p.st.writes.length, 0);
  assert.equal(p.st.authDeletes, 0);
});

test('deleteMyAccount: 진행 중 주문이 있으면 토큰으로 차단, 이력·삭제 없음', async () => {
  const p = ports({ user: USER, inFlight: 1 });
  await assert.rejects(() => run(p), (e) => e.code === 'failed-precondition' && e.message.endsWith('[ACCOUNT_HAS_INFLIGHT_ORDERS]'));
  assert.equal(p.st.writes.length, 0);
  assert.equal(p.st.authDeletes, 0);
  assert.equal(p.st.user.deleted, undefined);
});

test('deleteMyAccount: 정상 — PII 제거·displayName 치환·deleted, Qoin 소멸 원장 1건, 이력 스냅샷, Auth 마지막', async () => {
  const p = ports({ user: USER });
  const r = await run(p);
  assert.equal(r.phase, 'done');
  assert.equal(r.forfeitedQoin, 1200);
  const u = p.st.user;
  assert.equal(u.displayName, ANONYMIZED_NAME);
  assert.equal(u.deleted, true);
  for (const k of ['email', 'phone', 'photoUrl', 'fcmToken']) assert.equal(u[k], undefined, k);
  assert.equal(u.uid, 'u1'); assert.equal(u.role, 'customer'); // 앵커 보존
  assert.equal(u.qoinBalance, 0);
  assert.deepEqual(p.st.ledger, [{ type: 'forfeit', amount: -1200, balanceAfter: 0 }]);
  assert.equal(p.st.histories.size, 1);
  const h = [...p.st.histories.values()][0];
  assert.equal(h.snapshot.phone, '01012345678', '익명화 직전 스냅샷');
  assert.equal(h.deletedBy, 'u1');
  assert.equal(h.forfeitedQoin, 1200);
  assert.deepEqual(h.affected, { favoriteStores: 2, favoriteMenuItems: 1 });
  assert.equal(h.phase, 'done');
  assert.ok(p.st.calls.indexOf('h:started') < p.st.calls.indexOf('anon'), '이력이 익명화보다 먼저');
  assert.ok(p.st.calls.indexOf('anon') < p.st.calls.indexOf('auth'), 'Auth 삭제는 Firestore 작업 뒤');
  assert.equal(p.st.calls.at(-1), 'h:done');
});

test('deleteMyAccount: Qoin 0 이면 원장을 만들지 않는다', async () => {
  const p = ports({ user: { ...USER, qoinBalance: 0 } });
  const r = await run(p);
  assert.equal(r.forfeitedQoin, 0);
  assert.equal(p.st.ledger.length, 0);
});

test('deleteMyAccount: 이미 탈퇴한 계정은 no-op', async () => {
  const p = ports({ user: { ...USER, deleted: true } });
  assert.deepEqual(await run(p), { alreadyDeleted: true });
  assert.equal(p.st.writes.length, 0);
  assert.equal(p.st.authDeletes, 0);
});

test('deleteMyAccount: owner/brand 는 서버에서도 거부', async () => {
  for (const role of ['owner', 'brand', 'admin']) {
    const p = ports({ user: { ...USER, role } });
    await assert.rejects(() => run(p), (e) => e.code === 'permission-denied');
    assert.equal(p.st.writes.length, 0);
  }
});

test('deleteMyAccount: 사용자 없음 + 이력 없음 → not-found', async () => {
  await assert.rejects(() => run(ports({ user: null })), (e) => e.code === 'not-found');
});

for (const step of ['qoin', 'anon', 'fav', 'auth']) {
  test(`deleteMyAccount: ${step} 단계 중단 → 재호출 시 이어서 진행, 이력 1건·원장 1건·이중 처리 없음`, async () => {
    const p = ports({ user: USER, failAt: step });
    await assert.rejects(() => run(p), /fail:/);
    assert.equal(p.st.histories.size, 1);
    const r = await run(p);
    assert.equal(r.phase, 'done');
    assert.equal(p.st.histories.size, 1);
    assert.equal(p.st.ledger.length, 1);
    assert.equal(p.st.authDeletes, 1);
    assert.equal(r.forfeitedQoin, 1200);
    assert.equal([...p.st.histories.values()][0].phase, 'done');
  });
}

test('deleteMyAccount: 완료 후 재호출은 no-op (Auth 이중 삭제 없음)', async () => {
  const p = ports({ user: USER });
  await run(p);
  assert.deepEqual(await run(p), { alreadyDeleted: true });
  assert.equal(p.st.authDeletes, 1);
  assert.equal(p.st.ledger.length, 1);
});

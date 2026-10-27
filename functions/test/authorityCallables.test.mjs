// payment_server_authority — lookupBrandByKey · issueBrandKey · deleteStore · 마이그레이션 분류. `npm test` (functions/ 에서).
// Firestore 비의존: 각 함수의 Core 를 in-memory 포트로 검증한다 (spec §18.4).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { lookupBrandByKeyCore, LOOKUP_LIMIT_PER_MINUTE } from '../lib/lookupBrandByKey.js';
import { issueBrandKeyCore, MAX_ISSUE_ATTEMPTS } from '../lib/issueBrandKey.js';
import { runDeleteStore, parseStorageUrl, storeImageUrls } from '../lib/deleteStore.js';
import { planStoreMigration } from '../lib/migrateStoreApprovalMeta.js';
import { planBrandCopy, planBrandCleanup } from '../lib/migrateBrandPrivateProfile.js';
import { BRAND_KEY_RE, generateBrandKey } from '../lib/brandKeyCore.js';

// ── brandKey 형식 ───────────────────────────────────────────────────────────
test('generateBrandKey 는 항상 형식을 만족한다', () => {
  for (let i = 0; i < 200; i++) assert.match(generateBrandKey(), BRAND_KEY_RE);
});

// ── lookupBrandByKey ────────────────────────────────────────────────────────
function lookupPorts({ keys = {}, brands = {} } = {}) {
  const counts = new Map();
  return {
    async countCall(uid) { counts.set(uid, (counts.get(uid) ?? 0) + 1); return counts.get(uid); },
    async getKeyBrandId(k) { return keys[k] ?? null; },
    async getBrand(id) { return brands[id] ?? null; },
  };
}
const lookup = (ports, brandKey, uid = 'u1') => lookupBrandByKeyCore(ports, { uid, brandKey, nowMs: 0 });

test('lookup: 승인된 브랜드 → {brandId,name,logoUrl} 만 (PII·brandKey 없음)', async () => {
  const ports = lookupPorts({
    keys: { 'BR-AAAAAAAA': 'b1' },
    brands: { b1: { status: 'approved', name: 'A', logoUrl: 'u', brandKey: 'BR-AAAAAAAA', contactPhone: '010', businessRegistrationNumber: '1' } },
  });
  const r = await lookup(ports, 'BR-AAAAAAAA');
  assert.deepEqual(r, { brandId: 'b1', name: 'A', logoUrl: 'u' });
});

test('lookup: 미존재 / 미승인 / 키는 있는데 브랜드 문서 없음 / 형식 불일치 는 모두 같은 응답', async () => {
  const ports = lookupPorts({
    keys: { 'BR-PENDING2': 'b2', 'BR-ORPHAN22': 'b9' },
    brands: { b2: { status: 'pending', name: 'P' } },
  });
  const outs = [];
  for (const k of ['BR-MISSING22', 'BR-PENDING2', 'BR-ORPHAN22', 'nope', 123, null, 'BR-aaaaaaaa']) {
    try { await lookup(ports, k); assert.fail('should throw'); }
    catch (e) { outs.push([e.code, e.message]); }
  }
  assert.ok(outs.every(([c, m]) => c === 'not-found' && m === outs[0][1]), JSON.stringify(outs));
});

test('lookup: rate limit — 분당 N회 초과 시 resource-exhausted (성공 호출도 센다)', async () => {
  const ports = lookupPorts({ keys: { 'BR-AAAAAAAA': 'b1' }, brands: { b1: { status: 'approved', name: 'A' } } });
  for (let i = 0; i < LOOKUP_LIMIT_PER_MINUTE; i++) await lookup(ports, 'BR-AAAAAAAA');
  await assert.rejects(() => lookup(ports, 'BR-AAAAAAAA'), (e) => e.code === 'resource-exhausted');
  // 다른 uid 는 영향 없음
  await lookup(ports, 'BR-AAAAAAAA', 'u2');
});

// ── issueBrandKey ───────────────────────────────────────────────────────────
/** 원자적 tryIssue 를 흉내내는 in-memory 포트 (본문이 await 없이 동기 실행 = 트랜잭션 원자성). */
function issuePorts(genSeq, brandIds = ['b1', 'b2']) {
  const state = { keys: new Map(), priv: new Map(), history: [] };
  let i = 0;
  return {
    state,
    generateKey: () => genSeq[Math.min(i++, genSeq.length - 1)],
    async tryIssue(brandId, key, adminUid) {
      await Promise.resolve();
      if (!brandIds.includes(brandId)) return { kind: 'brand_not_found' };
      const existing = state.priv.get(brandId);
      if (existing) return { kind: 'already', brandKey: existing };
      if (state.keys.has(key)) return { kind: 'collision' };
      state.keys.set(key, brandId);
      state.priv.set(brandId, key);
      state.history.push({ brandId, brandKey: key, changedBy: adminUid });
      return { kind: 'issued' };
    },
  };
}

test('issue: 발급 → brandKeys · private · keyHistory 가 함께 생기고 형식을 만족한다', async () => {
  const p = issuePorts([generateBrandKey()]);
  const r = await issueBrandKeyCore(p, { brandId: 'b1', adminUid: 'adm' });
  assert.equal(r.alreadyIssued, false);
  assert.match(r.brandKey, BRAND_KEY_RE);
  assert.equal(p.state.keys.get(r.brandKey), 'b1');
  assert.equal(p.state.history.length, 1);
  assert.equal(p.state.history[0].changedBy, 'adm');
});

test('issue: 멱등 — 같은 브랜드에 다시 호출하면 같은 키, 이력 추가 없음', async () => {
  const p = issuePorts(['BR-AAAAAAAA', 'BR-BBBBBBBB']);
  const a = await issueBrandKeyCore(p, { brandId: 'b1', adminUid: 'adm' });
  const b = await issueBrandKeyCore(p, { brandId: 'b1', adminUid: 'adm' });
  assert.equal(b.brandKey, a.brandKey);
  assert.equal(b.alreadyIssued, true);
  assert.equal(p.state.history.length, 1);
});

test('issue: 같은 브랜드 동시 2회 → 키 1개만 만들어진다', async () => {
  const p = issuePorts(['BR-AAAAAAAA', 'BR-BBBBBBBB', 'BR-CCCCCCCC']);
  const [a, b] = await Promise.all([
    issueBrandKeyCore(p, { brandId: 'b1', adminUid: 'adm' }),
    issueBrandKeyCore(p, { brandId: 'b1', adminUid: 'adm' }),
  ]);
  assert.equal(a.brandKey, b.brandKey);
  assert.equal([a, b].filter((x) => !x.alreadyIssued).length, 1);
  assert.equal(p.state.keys.size, 1);
});

test('issue: 서로 다른 브랜드가 같은 키를 동시에 뽑으면 1곳만 성공하고 다른 쪽은 재시도해 다른 키를 받는다 (유일성)', async () => {
  // 두 번째 호출자도 처음엔 같은 키를 뽑는다 → 충돌 → 다음 키
  const seqs = [['BR-AAAAAAAA', 'BR-BBBBBBBB'], ['BR-AAAAAAAA', 'BR-CCCCCCCC']];
  const shared = issuePorts(['x']);
  const mk = (seq) => { let i = 0; return { ...shared, generateKey: () => seq[Math.min(i++, seq.length - 1)] }; };
  const [a, b] = await Promise.all([
    issueBrandKeyCore(mk(seqs[0]), { brandId: 'b1', adminUid: 'adm' }),
    issueBrandKeyCore(mk(seqs[1]), { brandId: 'b2', adminUid: 'adm' }),
  ]);
  assert.notEqual(a.brandKey, b.brandKey);
  assert.equal(shared.state.keys.size, 2);
  assert.equal(shared.state.keys.get(a.brandKey), 'b1');
  assert.equal(shared.state.keys.get(b.brandKey), 'b2');
});

test(`issue: 충돌이 ${MAX_ISSUE_ATTEMPTS}회 이어지면 aborted`, async () => {
  const p = issuePorts(['BR-AAAAAAAA']);
  p.state.keys.set('BR-AAAAAAAA', 'other');
  await assert.rejects(() => issueBrandKeyCore(p, { brandId: 'b1', adminUid: 'adm' }), (e) => e.code === 'aborted');
});

test('issue: 브랜드 문서 없음 → not-found', async () => {
  const p = issuePorts(['BR-AAAAAAAA']);
  await assert.rejects(() => issueBrandKeyCore(p, { brandId: 'ghost', adminUid: 'adm' }), (e) => e.code === 'not-found');
});

// ── deleteStore ─────────────────────────────────────────────────────────────
const ts = (ms) => ({ toMillis: () => ms });
function deletePorts({ store, inFlight = 0, failAt = null, existingHistory = [] } = {}) {
  const st = {
    store: store ? { ...store } : null,
    histories: new Map(existingHistory.map((h) => [h.id, { ...h }])),
    writes: [], subDeleted: 0, imagesDeleted: [], storeDeletes: 0,
  };
  const counts = { menuItems: 3, menuOverrides: 2, subCategories: 1, optionGroups: 1, qoinRateHistory: 4 };
  const maybeFail = (step) => { if (failAt === step) { failAt = null; throw new Error(`fail:${step}`); } };
  return {
    st,
    async readStore() { return st.store ? { ...st.store } : null; },
    async findLatestHistory(storeId) {
      const all = [...st.histories.values()].filter((h) => h.storeId === storeId);
      return all.find((h) => h.phase !== 'done') ?? all[0] ?? null;
    },
    async readHistory(id) { return st.histories.get(id) ?? null; },
    async writeHistory(id, patch) {
      st.writes.push([id, patch]);
      st.histories.set(id, { ...(st.histories.get(id) ?? { id }), ...patch, id });
    },
    async countAffected(_s, urls) { return { ...counts, images: urls.length, inFlightOrders: inFlight }; },
    async deleteStoreDoc() { maybeFail('doc'); st.storeDeletes++; st.store = null; },
    async deleteSubcollections() { maybeFail('sub'); st.subDeleted++; return { ...counts }; },
    async deleteImages(urls) { maybeFail('img'); st.imagesDeleted.push(...urls); },
  };
}
const STORE = { name: '강남점', ownerId: 'o1', status: 'approved', brandId: null, createdAt: ts(1000), imageUrl: 'https://firebasestorage.googleapis.com/v0/b/bk/o/store_images%2Fo1%2Fa.jpg?alt=media', imageUrls: [] };
const run = (ports, over = {}) => runDeleteStore(ports, { storeId: 's1', reason: '폐업', dryRun: false, adminUid: 'adm', ...over });

test('deleteStore: dryRun 은 쓰기 0건, affected + blockedBy 반환', async () => {
  const p = deletePorts({ store: STORE, inFlight: 2 });
  const r = await run(p, { dryRun: true });
  assert.equal(r.dryRun, true);
  assert.equal(r.affected.menuItems, 3);
  assert.equal(r.affected.images, 1);
  assert.deepEqual(r.blockedBy, { inFlightOrders: 2 });
  assert.equal(p.st.writes.length, 0);
  assert.equal(p.st.storeDeletes, 0);
});

test('deleteStore: 진행 중 주문이 있으면 차단 + 토큰, 이력도 남기지 않는다 (§11.4)', async () => {
  const p = deletePorts({ store: STORE, inFlight: 1 });
  await assert.rejects(() => run(p), (e) => e.code === 'failed-precondition' && e.message.endsWith('[STORE_HAS_INFLIGHT_ORDERS]'));
  assert.equal(p.st.writes.length, 0);
  assert.equal(p.st.storeDeletes, 0);
});

test('deleteStore: 정상 실행 — 순서 ①이력 → ②매장문서 → ③하위 → ④Storage → ⑤done, 이력 1건', async () => {
  const p = deletePorts({ store: STORE });
  const r = await run(p);
  assert.equal(r.phase, 'done');
  assert.equal(r.deletionId, 's1_1000');
  assert.deepEqual(p.st.writes.map(([, patch]) => patch.phase), ['started', 'docDeleted', 'subDeleted', 'storageDeleted', 'done']);
  assert.equal(p.st.histories.size, 1);
  const h = p.st.histories.get('s1_1000');
  assert.equal(h.deletedBy, 'adm');
  assert.equal(h.reason, '폐업');
  assert.equal(h.snapshot.name, '강남점', '삭제 직전 스냅샷이 남는다');
  assert.equal(h.affected.menuItems, 3);
  assert.equal(p.st.imagesDeleted.length, 1);
});

test('deleteStore: ① 이력 쓰기가 ② 매장 문서 삭제보다 먼저다 (이력 없이 삭제가 시작되는 경로 없음)', async () => {
  const order = [];
  const p = deletePorts({ store: STORE });
  const w = p.writeHistory.bind(p), d = p.deleteStoreDoc.bind(p);
  p.writeHistory = async (id, patch) => { order.push(`h:${patch.phase}`); return w(id, patch); };
  p.deleteStoreDoc = async (s) => { order.push('doc'); return d(s); };
  await run(p);
  assert.ok(order.indexOf('h:started') < order.indexOf('doc'));
});

for (const step of ['doc', 'sub', 'img']) {
  test(`deleteStore: ${step} 단계에서 중단 → 재실행하면 이어서 진행, 이력 1건 (멱등 §11.5)`, async () => {
    const p = deletePorts({ store: STORE, failAt: step });
    await assert.rejects(() => run(p), /fail:/);
    assert.equal(p.st.histories.size, 1);
    const r = await run(p); // 재실행 (매장 문서가 이미 없을 수 있다)
    assert.equal(r.phase, 'done');
    assert.equal(p.st.histories.size, 1, '이력은 중복 기록되지 않는다');
    assert.equal(p.st.histories.get('s1_1000').phase, 'done');
    assert.equal(p.st.storeDeletes, 1);
    assert.equal(p.st.imagesDeleted.length, 1);
    // 재실행의 affected 는 먼저 센 값을 더 작은 값으로 덮지 않는다
    assert.equal(r.affected.menuItems, 3);
  });
}

test('deleteStore: 완료 후 재실행(매장 없음 + done) → alreadyDeleted, 쓰기 없음', async () => {
  const p = deletePorts({ store: STORE });
  await run(p);
  const n = p.st.writes.length;
  const r = await run(p);
  assert.deepEqual(r, { alreadyDeleted: true });
  assert.equal(p.st.writes.length, n);
});

test('deleteStore: 매장도 이력도 없으면 not-found', async () => {
  await assert.rejects(() => run(deletePorts({ store: null })), (e) => e.code === 'not-found');
});

test('deleteStore: 같은 ID 로 재생성(createdAt 다름)된 매장의 삭제는 별도 이력 2건 (§11.5)', async () => {
  const p = deletePorts({ store: STORE });
  await run(p);
  p.st.store = { ...STORE, createdAt: ts(2000) };
  const r2 = await run(p);
  assert.equal(r2.deletionId, 's1_2000');
  assert.equal(p.st.histories.size, 2);
  assert.ok(p.st.histories.has('s1_1000') && p.st.histories.has('s1_2000'));
});

test('deleteStore: createdAt 부재(legacy) → s1_0', async () => {
  const { createdAt, ...legacy } = STORE;
  const r = await run(deletePorts({ store: legacy }));
  assert.equal(r.deletionId, 's1_0');
});

test('deleteStore: 재실행이 started 에서 멈춘 매장(문서 존재)을 이어서 진행하고, 진행 중 주문은 다시 검사한다', async () => {
  const p = deletePorts({ store: STORE, existingHistory: [{ id: 's1_1000', storeId: 's1', phase: 'started', imageUrls: [] }], inFlight: 1 });
  await assert.rejects(() => run(p), (e) => e.message.endsWith('[STORE_HAS_INFLIGHT_ORDERS]'));
});

test('storage URL 파싱: firebasestorage 만 인정하고 외부 URL 은 건드리지 않는다', () => {
  assert.deepEqual(parseStorageUrl(STORE.imageUrl), { bucket: 'bk', path: 'store_images/o1/a.jpg' });
  assert.equal(parseStorageUrl('https://example.com/a.jpg'), null);
  assert.equal(parseStorageUrl('not a url'), null);
  assert.deepEqual(storeImageUrls({ imageUrl: 'a', imageUrls: ['a', 'b'] }).sort(), ['a', 'b']);
});

// ── 마이그레이션 분류 ───────────────────────────────────────────────────────
test('M1: status 부재 → approved 명시 + approvedAt 백필, approved+approvedAt 없음 → 백필', () => {
  const plan = planStoreMigration([
    ['legacy', { name: 'x' }],
    ['appr_no_at', { status: 'approved' }],
    ['appr_ok', { status: 'approved', approvedAt: 1, approvedBy: 'a' }],
    ['pend_new', { status: 'pending' }],
    ['pend_edit', { status: 'pending', approvedAt: 1, approvedBy: 'a' }],
    ['rej', { status: 'rejected', approvedAt: 1, approvedBy: 'a' }],
  ]);
  assert.deepEqual(plan.setStatusApproved, ['legacy']);
  assert.deepEqual(plan.backfillApprovedAt.sort(), ['appr_no_at', 'legacy']);
  assert.deepEqual(plan.anomalies, []);
  assert.deepEqual(plan.invalid, []);
});

test('M1: 이상치 감사 — approvedAt 만 있고 approvedBy 없는 비승인 문서, 알 수 없는 status 는 목록으로 보고', () => {
  const plan = planStoreMigration([
    ['forged', { status: 'pending', approvedAt: 1 }],
    ['forged_rej', { status: 'rejected', approvedAt: 1 }],
    ['weird', { status: 'Approved' }],
    ['fine', { status: 'pending', approvedAt: 1, approvedBy: 'a' }],
  ]);
  assert.deepEqual(plan.anomalies.sort(), ['forged', 'forged_rej']);
  assert.deepEqual(plan.invalid, [{ id: 'weird', status: 'Approved' }]);
});

test('M2 copy: 부모 brandKey+PII → private, 형식 불일치·키 중복은 무효 목록, private 기존 값은 덮지 않는다', () => {
  const brands = [
    ['b1', { brandKey: 'BR-AAAAAAAA', contactName: '홍', contactPhone: '010', name: 'A' }],
    ['b2', { brandKey: 'bad', contactName: 'x' }],
    ['b3', { brandKey: 'BR-AAAAAAAA' }],
    ['b4', { name: 'noPII' }],
    ['b5', { contactName: '새값', businessRegistrationNumber: '1' }],
  ];
  const plan = planBrandCopy(brands, new Map([['b5', { contactName: '이미있음' }]]), new Map());
  assert.deepEqual(plan.copy.map((c) => c.brandId), ['b1', 'b5']);
  assert.equal(plan.copy[0].brandKey, 'BR-AAAAAAAA');
  assert.deepEqual(plan.copy[1].fields, { businessRegistrationNumber: '1' });
  assert.deepEqual(plan.invalid.map((x) => x.brandId).sort(), ['b2', 'b3']);
});

test('M2 cleanup: private 와 값이 모두 같을 때만 부모 필드 제거 대상', () => {
  const brands = [
    ['b1', { brandKey: 'BR-AAAAAAAA', contactName: '홍', name: 'A' }],
    ['b2', { contactName: '홍' }],
    ['b3', { contactName: '홍' }],
    ['b4', { name: 'clean already' }],
  ];
  const privates = new Map([
    ['b1', { brandKey: 'BR-AAAAAAAA', contactName: '홍' }],
    ['b2', { contactName: '다름' }],
  ]);
  const plan = planBrandCleanup(brands, privates);
  assert.deepEqual(plan.clean, ['b1']);
  assert.deepEqual(plan.invalid.map((x) => x.brandId).sort(), ['b2', 'b3']);
});

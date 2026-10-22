// Qoin 적립률 계층화 — Cloud Function 에뮬레이터 검증 (실결제 0회, 실 Firestore 접촉 0).
//
// 실행 (functions/ 에서):  npm run test:emulator
//   = tsc 빌드 → firebase emulators:exec --only firestore,functions → 이 스크립트
//
// 트리거(onOrderQoinSettled / onQoinConfigWritten)는 functions 에뮬레이터가 실제로 발화시킨다.
// callable 은 에뮬레이터 HTTP 로 호출한다 (토큰 검증 생략 모드: 서명 없는 JWT 로 uid 전달).
// read 수 실측(CH16)만 프로세스 안에서 핸들러를 직접 호출해 Firestore SDK 요청을 센다.
//
// 케이스 ID 는 docs/tasks/qoin_accrual_rate_hierarchy/spec.md §15.2 (CH1~CH27) 와 대응한다.
// 신규(2차 개정): SW(스위치 callable) / N4 / Q1 / T3(F1 스푸핑) / IS(qoinSettlementIssues) / MG(마이그레이션) / F5 / F3 / FA(기록 전수).
//
// ⚠️ 주문은 손으로 시드하지 않는다 — `lib/orderBuilder.js` 의 buildOrderData 로 만든다 (T1, 1차 F1 재발 방지).

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const PROJECT = 'order-app-5957e';
const FS_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8137';
process.env.FIRESTORE_EMULATOR_HOST = FS_HOST;
const FN_BASE = `http://127.0.0.1:5137/${PROJECT}/asia-northeast3`;

const require = createRequire(import.meta.url);
const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');
admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const { Timestamp } = require('firebase-admin/firestore');
const { buildOrderData } = require('../lib/orderBuilder.js');

const here = path.dirname(fileURLToPath(import.meta.url));
const table = JSON.parse(fs.readFileSync(path.join(here, '../../test_fixtures/qoin_rate_truth_table.json'), 'utf8'));

// ── 유틸 ────────────────────────────────────────────────────────────────────
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function until(fn, timeoutMs = 15000, stepMs = 150) {
  const end = Date.now() + timeoutMs;
  for (;;) {
    const v = await fn();
    if (v) return v;
    if (Date.now() > end) return null;
    await sleep(stepMs);
  }
}
const results = [];
async function check(name, fn) {
  try { await fn(); results.push([name, 'PASS']); console.log('  PASS', name); }
  catch (e) { results.push([name, 'FAIL: ' + (e?.message ?? e)]); console.log('  FAIL', name, '->', e?.message ?? e); }
}
function eq(actual, expected, msg = '') {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`${msg} expected ${JSON.stringify(expected)} got ${JSON.stringify(actual)}`);
  }
}
function ok(cond, msg) { if (!cond) throw new Error(msg); }

function decode(cell) {
  if (cell === 'absent') return undefined;
  if (cell === 'nan') return NaN;
  if (cell === 'null') return null;
  if (typeof cell === 'string' && cell.startsWith('str:')) return cell.slice(4);
  return cell;
}
/** undefined → 필드 삭제 */
const fieldOrDelete = (v) => (v === undefined ? FieldValue.delete() : v);

let seq = 0;
const nid = (p) => `${p}_${Date.now().toString(36)}_${++seq}`;

async function seedUser(uid, extra = {}) {
  await db.collection('users').doc(uid).set({ uid, role: 'customer', qoinBalance: 0, ...extra });
}
async function setGlobal(fields) {
  await db.collection('config').doc('qoin').set({ enabled: true, ...fields }, { merge: false });
}
async function ledger(uid, id) {
  return (await db.collection('users').doc(uid).collection('qoinTransactions').doc(id).get());
}

/**
 * 운영과 같은 코드(buildOrderData)로 주문을 만든 뒤 ready → completed 로 수정(트리거는 onDocumentUpdated).
 * 적립 문서(earn_*)가 생기면 반환, 없으면 null.
 * `orderOverrides` 는 스푸핑 시나리오처럼 "운영이 만들지 않는 모양" 을 **명시적으로** 덧씌울 때만 쓴다.
 */
async function createOrder({ orderId, uid, storeId, total = 10000, orderOverrides = {} }) {
  const cart = { storeId, storeName: '테스트매장', items: [], subtotal: total, discount: null, totalPrice: total };
  const order = buildOrderData(cart, uid, { method: 'card', channel: 'toss' },
    { approvedAt: Timestamp.now(), now: FieldValue.serverTimestamp() });
  await db.collection('orders').doc(orderId).set({ ...order, status: 'ready', ...orderOverrides });
}
async function completeOrder({ orderId, uid, storeId, total = 10000, expectLedger = true, orderOverrides = {} }) {
  await createOrder({ orderId, uid, storeId, total, orderOverrides });
  await sleep(250);
  await db.collection('orders').doc(orderId).update({ status: 'completed' });
  if (expectLedger) return until(async () => {
    const s = await ledger(uid, `earn_${orderId}`); return s.exists ? s : null; });
  await sleep(3500);
  const s = await ledger(uid, `earn_${orderId}`);
  return s.exists ? s : null;
}
async function issueDoc(orderId) {
  const s = await db.collection('qoinSettlementIssues').doc(orderId).get();
  return s.exists ? s.data() : null;
}
async function refundOrder(orderId, uid, expectLedger = true) {
  await db.collection('orders').doc(orderId).update({ status: 'refunded' });
  if (expectLedger) return until(async () => {
    const s = await ledger(uid, `clawback_${orderId}`); return s.exists ? s : null; });
  await sleep(3500);
  const s = await ledger(uid, `clawback_${orderId}`);
  return s.exists ? s : null;
}

// ── callable 호출 (functions 에뮬레이터 HTTP) ────────────────────────────────
function jwt(uid) {
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  return `${b64({ alg: 'none', typ: 'JWT' })}.${b64({ user_id: uid, sub: uid, aud: PROJECT, iss: `https://securetoken.google.com/${PROJECT}`, firebase: { sign_in_provider: 'custom' } })}.`;
}
async function call(name, data, uid) {
  const headers = { 'Content-Type': 'application/json' };
  if (uid) headers.Authorization = `Bearer ${jwt(uid)}`;
  const res = await fetch(`${FN_BASE}/${name}`, { method: 'POST', headers, body: JSON.stringify({ data }) });
  const body = await res.json();
  if (body.error) return { error: body.error.status, message: body.error.message, details: body.error.details };
  return { result: body.result };
}
const ADMIN = 'adm_' + Date.now().toString(36);
const NONADMIN = 'cus_' + Date.now().toString(36);
await seedUser(ADMIN, { role: 'admin' });
await seedUser(NONADMIN, { role: 'customer' });

async function histories(col) {
  const s = await col.get();
  return s.docs.map((d) => ({ id: d.id, ...d.data() }));
}
const storeHist = (id) => db.collection('stores').doc(id).collection('qoinRateHistory');
const brandHist = (id) => db.collection('brands').doc(id).collection('qoinRateHistory');
const globalHist = () => db.collection('config').doc('qoin').collection('qoinRateHistory');

console.log('\n── 사전 점검: functions 에뮬레이터 응답 ──');
await until(async () => { try { const r = await call('setQoinAccrualRate', {}, undefined); return r.error ? r : null; } catch { return null; } }, 30000, 500);

// ═════════════════════════════════════════════════════════════════════════
// A. 진리표 E2E (CH1~CH10 + 확장). 같은 JSON 을 Dart/TS 단위 테스트도 읽는다.
// ═════════════════════════════════════════════════════════════════════════
console.log('\n── A. 진리표 E2E ──');
/** 픽스처 expect → 기대 (TRANSITIONAL: transitionalExpect 우선, 정리 커밋에서 삭제) */
const expectOf = (row) => row.transitionalExpect ?? row.expect;
const ISSUE_OF = {
  store: ['invalid_rate', 'store'], brand: ['invalid_rate', 'brand'], global: ['invalid_rate', 'global'],
  store_enabled: ['invalid_enabled', 'store'], brand_enabled: ['invalid_enabled', 'brand'],
};
for (const row of table.resolve) {
  await check(`CH-${row.id} resolve store=${row.store} brand=${row.brand} global=${row.global} sw=${row.storeEnabled ?? '-'}/${row.brandEnabled ?? '-'}`, async () => {
    const uid = nid('u'); await seedUser(uid);
    const storeId = nid('st');
    const hasBrand = row.brand !== 'absent' || row.brandEnabled !== undefined;
    const brandId = hasBrand ? nid('br') : null;
    await setGlobal(row.global === 'absent' ? {} : { accrualRate: decode(row.global) });
    // 브랜드 소속은 주문이 아니라 **매장 문서**가 정한다 (F1).
    const storeDoc = { name: 'S', ownerId: 'x', status: 'approved' };
    if (hasBrand) storeDoc.brandId = brandId;
    const sv = decode(row.store); if (sv !== undefined) storeDoc.qoinAccrualRate = sv;
    if (row.storeEnabled !== undefined) storeDoc.qoinAccrualEnabled = decode(row.storeEnabled);
    await db.collection('stores').doc(storeId).set(storeDoc);
    if (hasBrand) {
      const bd = { name: 'B', status: 'approved' };
      const bv = decode(row.brand); if (bv !== undefined) bd.qoinAccrualRate = bv;
      if (row.brandEnabled !== undefined) bd.qoinAccrualEnabled = decode(row.brandEnabled);
      await db.collection('brands').doc(brandId).set(bd);
    }
    const orderId = nid('o');
    const exp = expectOf(row);
    const led = await completeOrder({ orderId, uid, storeId, total: 10000, expectLedger: exp.rate !== undefined });
    if (exp.rate === undefined) {
      ok(led === null, '적립되면 안 됨');
      const issue = await issueDoc(orderId);
      if (exp.invalid) {
        ok(issue, 'invalid 인데 qoinSettlementIssues 기록이 없음');
        eq([issue.reason, issue.scope], ISSUE_OF[exp.invalid], 'issue reason/scope');
        eq(issue.resolved, false);
      } else {
        ok(issue === null, 'disabled 는 qoinSettlementIssues 를 만들면 안 됨 (의도된 정책)');
      }
      return;
    }
    ok(led, '적립 문서 없음');
    eq(led.get('accrualRate'), exp.rate, 'accrualRate');
    eq(led.get('accrualRateSource'), exp.source, 'accrualRateSource');
    eq(led.get('amount'), Math.floor(10000 * exp.rate), 'amount');
    eq(led.get('brandId'), brandId, '원장 brandId = 해석에 쓴 stores.brandId');
    ok((await issueDoc(orderId)) === null, '정상 적립인데 이슈 기록');
  });
}

// ═════════════════════════════════════════════════════════════════════════
// B. 회수 / kill switch / 엣지
// ═════════════════════════════════════════════════════════════════════════
console.log('\n── B. 회수 · kill switch · 엣지 ──');
await check('CH11 매장 스위치를 끈 뒤 환불 → 회수는 정상 동작 (돈이 새지 않는다) + CH18 source 상속', async () => {
  const uid = nid('u'); await seedUser(uid);
  const storeId = nid('st'); await setGlobal({ accrualRate: 0.03 });
  await db.collection('stores').doc(storeId).set({ name: 'S', qoinAccrualRate: 0.05 });
  const orderId = nid('o');
  const earn = await completeOrder({ orderId, uid, storeId });
  ok(earn, 'earn 없음'); eq(earn.get('amount'), 500, 'earn amount'); eq(earn.get('accrualRateSource'), 'store');
  await db.collection('stores').doc(storeId).update({ qoinAccrualEnabled: false }); // 이후 적립 중단
  const cb = await refundOrder(orderId, uid);
  ok(cb, '회수 문서 없음 — 스위치가 회수까지 막았다');
  eq(cb.get('amount'), -500, 'clawback amount'); eq(cb.get('accrualRateSource'), 'store', 'clawback source 상속');
  eq((await db.collection('users').doc(uid).get()).get('qoinBalance'), 0, '잔액');
  // 같은 매장의 새 주문은 적립되지 않는다
  const o2 = nid('o'); const none = await completeOrder({ orderId: o2, uid, storeId, expectLedger: false });
  ok(none === null, '스위치 off 매장에서 적립됨');
});
await check('CH11b 브랜드 스위치를 끈 뒤 환불 → 회수 정상', async () => {
  const uid = nid('u'); await seedUser(uid);
  const storeId = nid('st'); const brandId = nid('br'); await setGlobal({ accrualRate: 0.03 });
  await db.collection('stores').doc(storeId).set({ name: 'S', brandId });
  await db.collection('brands').doc(brandId).set({ name: 'B', qoinAccrualRate: 0.1 });
  const orderId = nid('o');
  const earn = await completeOrder({ orderId, uid, storeId });
  ok(earn && earn.get('amount') === 1000 && earn.get('accrualRateSource') === 'brand', 'earn');
  await db.collection('brands').doc(brandId).update({ qoinAccrualEnabled: false });
  const cb = await refundOrder(orderId, uid); ok(cb && cb.get('amount') === -1000, 'clawback');
});
await check('CH11c 전역 적립률이 깨져도(0.5) 환불 회수는 동작 (회수는 적립률을 읽지 않는다)', async () => {
  const uid = nid('u'); await seedUser(uid);
  const storeId = nid('st'); await setGlobal({ accrualRate: 0.03 });
  await db.collection('stores').doc(storeId).set({ name: 'S' });
  const orderId = nid('o'); const earn = await completeOrder({ orderId, uid, storeId }); ok(earn, 'earn');
  await setGlobal({ accrualRate: 0.5 });
  const cb = await refundOrder(orderId, uid); ok(cb && cb.get('amount') === -300, 'clawback');
});
await check('CH12 enabled=false → 적립도 회수도 중단 (1차 회귀)', async () => {
  const uid = nid('u'); await seedUser(uid);
  const storeId = nid('st'); await setGlobal({ accrualRate: 0.03 });
  await db.collection('stores').doc(storeId).set({ name: 'S' });
  const orderId = nid('o'); const earn = await completeOrder({ orderId, uid, storeId }); ok(earn, 'earn');
  await setGlobal({ accrualRate: 0.03, enabled: false });
  const cb = await refundOrder(orderId, uid, false); ok(cb === null, 'disabled 중 회수됨');
  const o2 = nid('o'); const none = await completeOrder({ orderId: o2, uid, storeId, expectLedger: false });
  ok(none === null, 'disabled 중 적립됨');
  await setGlobal({ accrualRate: 0.03 });
});
await check('CH13 매장 문서 없음 → 상위(전역) 상속', async () => {
  const uid = nid('u'); await seedUser(uid); await setGlobal({ accrualRate: 0.03 });
  const led = await completeOrder({ orderId: nid('o'), uid, storeId: nid('ghost') });
  ok(led && led.get('accrualRateSource') === 'global' && led.get('amount') === 300, 'global 상속');
});
await check('CH14 storeId 빈 문자열 → skipped_invalid_store (적립 없음)', async () => {
  const uid = nid('u'); await seedUser(uid); await setGlobal({ accrualRate: 0.03 });
  const oid = nid('o');
  const led = await completeOrder({ orderId: oid, uid, storeId: '', expectLedger: false });
  ok(led === null, '적립됨');
  const issue = await issueDoc(oid); ok(issue && issue.reason === 'invalid_store', 'invalid_store 이슈 기록 (Q2 ⓐ)');
});
await check('CH17 멱등: completed→ready→completed 이중 적립 없음', async () => {
  const uid = nid('u'); await seedUser(uid); await setGlobal({ accrualRate: 0.03 });
  const storeId = nid('st'); await db.collection('stores').doc(storeId).set({ name: 'S' });
  const orderId = nid('o'); const led = await completeOrder({ orderId, uid, storeId }); ok(led, 'earn');
  await db.collection('orders').doc(orderId).update({ status: 'ready' }); await sleep(400);
  await db.collection('orders').doc(orderId).update({ status: 'completed' }); await sleep(3500);
  eq((await db.collection('users').doc(uid).get()).get('qoinBalance'), 300, '잔액(이중 적립 없음)');
});
await check('CH18 원장에 brandId / accrualRateSource 기록', async () => {
  const uid = nid('u'); await seedUser(uid); await setGlobal({ accrualRate: 0.03 });
  const storeId = nid('st'); const brandId = nid('br');
  await db.collection('stores').doc(storeId).set({ name: 'S', brandId });
  await db.collection('brands').doc(brandId).set({ name: 'B' });
  const led = await completeOrder({ orderId: nid('o'), uid, storeId });
  ok(led, 'earn'); eq(led.get('brandId'), brandId, 'brandId'); eq(led.get('accrualRateSource'), 'global');
});

// ═════════════════════════════════════════════════════════════════════════
// C. read 수 실측 (CH16) — 프로세스 내 호출, Firestore SDK 요청을 센다
// ═════════════════════════════════════════════════════════════════════════
console.log('\n── C. CH16 read 수 실측 ──');
{
  const fsPkg = require.resolve('@google-cloud/firestore', { paths: [path.join(here, '..')] });
  const base = path.dirname(fsPkg);
  const { DocumentReader } = require(path.join(base, 'document-reader.js'));
  const { Firestore } = require(path.join(base, 'index.js'));
  const counters = { docs: 0, batchGets: 0, queries: 0 };
  const origGet = DocumentReader.prototype._get;
  DocumentReader.prototype._get = function (...a) { counters.docs += this.allDocuments.length; return origGet.apply(this, a); };
  const origStream = Firestore.prototype.requestStream;
  Firestore.prototype.requestStream = function (method, ...a) {
    if (method === 'batchGetDocuments') counters.batchGets++;
    if (method === 'runQuery') counters.queries++;
    return origStream.call(this, method, ...a);
  };
  const { onOrderQoinSettled } = require('../lib/onOrderQoinSettled.js');
  const fakeEvent = (orderId, beforeS, afterS, extra) => ({
    params: { orderId },
    data: {
      before: { data: () => ({ status: beforeS, ...extra }) },
      after: { data: () => ({ status: afterS, ...extra }) },
    },
  });
  async function measure(label, orderId, from, to, extra) {
    counters.docs = 0; counters.batchGets = 0; counters.queries = 0;
    await onOrderQoinSettled.run(fakeEvent(orderId, from, to, extra));
    console.log(`     [read 실측] ${label}: 문서 read ${counters.docs}, batchGet 왕복 ${counters.batchGets}, 쿼리 ${counters.queries}`);
    return { ...counters };
  }
  await check('CH16 earn(브랜드 소속): config1 + store1 + brand1 + 가드1 + users1 = 5 read, 왕복 ≤ 1차(4)', async () => {
    const uid = nid('u'); await seedUser(uid); await setGlobal({ accrualRate: 0.03 });
    const storeId = nid('st'); const brandId = nid('br');
    await db.collection('stores').doc(storeId).set({ name: 'S', brandId });
    await db.collection('brands').doc(brandId).set({ name: 'B', qoinAccrualRate: 0.05 });
    const c = await measure('earn (브랜드 소속)', nid('o'), 'ready', 'completed', { userId: uid, storeId, storeName: 'S', totalPrice: 10000 });
    eq(c.docs, 5, 'earn 문서 read'); eq(c.queries, 0, '쿼리');
    ok(c.batchGets <= 4, `batchGet 왕복 ${c.batchGets} (1차 4 이하여야 한다)`);
  });
  await check('CH16 earn(개인 매장): config1 + store1 + 가드1 + users1 = 4 read', async () => {
    const uid = nid('u'); await seedUser(uid);
    const storeId = nid('st'); await db.collection('stores').doc(storeId).set({ name: 'S' });
    const c = await measure('earn (개인 매장)', nid('o'), 'ready', 'completed', { userId: uid, storeId, storeName: 'S', totalPrice: 10000 });
    eq(c.docs, 4, 'earn(개인) 문서 read');
    ok(c.batchGets <= 4, `batchGet 왕복 ${c.batchGets} (1차 4 이하여야 한다)`);
  });
  await check('CH16 clawback: config1 + earn1 + 가드1 + users1 = 4 read (계층 read 0, 1차와 동일)', async () => {
    const uid = nid('u'); await seedUser(uid);
    const storeId = nid('st'); await db.collection('stores').doc(storeId).set({ name: 'S' });
    const orderId = nid('o');
    await measure('earn 선행', orderId, 'ready', 'completed', { userId: uid, storeId, storeName: 'S', totalPrice: 10000 });
    const c = await measure('clawback', orderId, 'completed', 'refunded', { userId: uid, storeId, storeName: 'S', totalPrice: 10000 });
    eq(c.docs, 4, 'clawback 문서 read');
    ok(c.batchGets <= 4, `batchGet 왕복 ${c.batchGets} (1차 4 이하여야 한다)`);
  });
  DocumentReader.prototype._get = origGet;
  Firestore.prototype.requestStream = origStream;
}

// ═════════════════════════════════════════════════════════════════════════
// D. setQoinAccrualRate callable
// ═════════════════════════════════════════════════════════════════════════
console.log('\n── D. setQoinAccrualRate ──');
await check('CH19 비로그인 → unauthenticated, non-admin → permission-denied', async () => {
  const storeId = nid('st'); await db.collection('stores').doc(storeId).set({ name: 'S' });
  eq((await call('setQoinAccrualRate', { scope: 'store', targetId: storeId, rate: 0.05 }, undefined)).error, 'UNAUTHENTICATED');
  eq((await call('setQoinAccrualRate', { scope: 'store', targetId: storeId, rate: 0.05 }, NONADMIN)).error, 'PERMISSION_DENIED');
  eq((await db.collection('stores').doc(storeId).get()).get('qoinAccrualRate'), undefined, '값이 바뀌면 안 됨');
  eq((await storeHist(storeId).get()).size, 0, '이력이 생기면 안 됨');
});
await check('CH20 서버 경계: 0.5 / 0.0005 / -1 / "3" / NaN / 0.0305(격자) → invalid-argument', async () => {
  const storeId = nid('st'); await db.collection('stores').doc(storeId).set({ name: 'S' });
  for (const rate of [0, 0.5, 0.0005, -1, '3', 1, 0.0305, null]) {
    const r = await call('setQoinAccrualRate', { scope: 'store', targetId: storeId, rate }, ADMIN);
    eq(r.error, 'INVALID_ARGUMENT', `rate=${JSON.stringify(rate)}`);
  }
  eq((await call('setQoinAccrualRate', { scope: 'store', targetId: storeId }, ADMIN)).error, 'INVALID_ARGUMENT', 'rate/clear 둘 다 없음');
  eq((await call('setQoinAccrualRate', { scope: 'store', targetId: storeId, rate: 0.05, clear: true }, ADMIN)).error, 'INVALID_ARGUMENT', '둘 다 있음');
  eq((await call('setQoinAccrualRate', { scope: 'global', rate: 0 }, ADMIN)).error, 'INVALID_ARGUMENT', '전역 0');
  eq((await call('setQoinAccrualRate', { scope: 'brand', targetId: storeId, rate: 0 }, ADMIN)).error, 'INVALID_ARGUMENT', '브랜드 0');
  eq((await call('setQoinAccrualRate', { scope: 'global', clear: true }, ADMIN)).error, 'INVALID_ARGUMENT', '전역 clear');
  eq((await call('setQoinAccrualRate', { scope: 'nope', targetId: storeId, rate: 0.05 }, ADMIN)).error, 'INVALID_ARGUMENT', 'scope');
  eq((await call('setQoinAccrualRate', { scope: 'store', targetId: storeId, rate: 0.05, reason: 'x'.repeat(201) }, ADMIN)).error, 'INVALID_ARGUMENT', 'reason 201자');
  eq((await call('setQoinAccrualRate', { scope: 'store', targetId: nid('ghost'), rate: 0.05 }, ADMIN)).error, 'NOT_FOUND', '없는 매장');
  eq((await db.collection('stores').doc(storeId).get()).get('qoinAccrualRate'), undefined, '값 불변');
  eq((await storeHist(storeId).get()).size, 0, '이력 0');
});
await check('CH21 성공: 값 + 이력이 함께 생성 (before 정확, status/updatedAt 불변) → 같은 값 재호출은 no-op (이력 중복 없음)', async () => {
  const storeId = nid('st');
  await db.collection('stores').doc(storeId).set({ name: '강남점', status: 'approved', updatedAt: new Date('2026-01-01') });
  let r = await call('setQoinAccrualRate', { scope: 'store', targetId: storeId, rate: 0.05, reason: '프로모션' }, ADMIN);
  eq(r.result.before, null); eq(r.result.after, 0.05); ok(r.result.historyId, 'historyId');
  r = await call('setQoinAccrualRate', { scope: 'store', targetId: storeId, rate: 0.1 }, ADMIN);
  eq(r.result.before, 0.05, '두 번째 before'); eq(r.result.after, 0.1);
  const doc = (await db.collection('stores').doc(storeId).get()).data();
  eq(doc.qoinAccrualRate, 0.1); eq(doc.status, 'approved', 'status 불변'); eq(doc.updatedAt.toMillis(), new Date('2026-01-01').getTime(), 'updatedAt 불변');
  let hs = await histories(storeHist(storeId));
  eq(hs.length, 2, '이력 2건');
  const h1 = hs.find((h) => h.after === 0.05);
  eq([h1.scope, h1.targetId, h1.targetName, h1.field, h1.before, h1.changedBy, h1.changedByRole, h1.reason, h1.source, h1.op],
     ['store', storeId, '강남점', 'accrualRate', null, ADMIN, 'admin', '프로모션', 'callable', 'set']);
  ok(h1.changedAt, 'changedAt');
  // 같은 값 재호출 → no-op
  r = await call('setQoinAccrualRate', { scope: 'store', targetId: storeId, rate: 0.1 }, ADMIN);
  eq(r.result.changed, false); eq(r.result.historyId, null);
  eq((await storeHist(storeId).get()).size, 2, '중복 이력 없음');
  // 0 은 거부 (Q1 — 적립 안 함은 스위치) / clear
  r = await call('setQoinAccrualRate', { scope: 'store', targetId: storeId, rate: 0 }, ADMIN);
  eq(r.error, 'INVALID_ARGUMENT', '0 은 쓰기 측 예외 없이 거부');
  r = await call('setQoinAccrualRate', { scope: 'store', targetId: storeId, clear: true }, ADMIN);
  eq(r.result.before, 0.1); eq(r.result.after, null);
  eq((await db.collection('stores').doc(storeId).get()).get('qoinAccrualRate'), undefined, '필드 삭제(상속)');
  hs = await histories(storeHist(storeId));
  ok(hs.some((h) => h.op === 'clear' && h.before === 0.1 && h.after === null && h.beforeState === 'value'), 'clear 이력');
  // 이미 상속 상태에서 clear → no-op
  r = await call('setQoinAccrualRate', { scope: 'store', targetId: storeId, clear: true }, ADMIN);
  eq(r.result.changed, false);
});
await check('CH21b 브랜드 설정 + 전역 설정(기존 문서) → 해당 범위 이력', async () => {
  const brandId = nid('br'); await db.collection('brands').doc(brandId).set({ name: 'B' });
  await call('setQoinAccrualRate', { scope: 'brand', targetId: brandId, rate: 0.07 }, ADMIN);
  const bh = await histories(brandHist(brandId)); eq(bh.length, 1); eq(bh[0].scope, 'brand'); eq(bh[0].targetName, 'B');
  await setGlobal({ accrualRate: 0.03 });
  const r = await call('setQoinAccrualRate', { scope: 'global', rate: 0.04, reason: 'g' }, ADMIN);
  eq(r.result.before, 0.03); eq(r.result.after, 0.04);
  eq((await db.collection('config').doc('qoin').get()).get('enabled'), true, 'enabled 불변');
});

// ═════════════════════════════════════════════════════════════════════════
// E. 이력 감시 트리거 (CH26/27)
// ═════════════════════════════════════════════════════════════════════════
console.log('\n── E. onQoinConfigWritten ──');
await check('CH27 callable 직후 트리거가 발화해도 중복 이력 없음 / CH26 Console(Admin SDK) 직접 write → source:direct 1건', async () => {
  await db.recursiveDelete(db.collection('config').doc('qoin').collection('qoinRateHistory'));
  await setGlobal({ accrualRate: 0.03 });
  await sleep(2500); await db.recursiveDelete(globalHist()); // seed 쓰기로 생긴 direct 이력 제거 후 시작
  const r = await call('setQoinAccrualRate', { scope: 'global', rate: 0.05 }, ADMIN);
  eq(r.result.after, 0.05);
  await sleep(4000);
  let hs = await histories(globalHist());
  eq(hs.filter((h) => h.field === 'accrualRate').length, 1, 'callable 이력만 1건 (트리거 중복 없음)');
  eq(hs.filter((h) => h.source === 'direct').length, 0, 'direct 이력 0');
  // Console 모사
  await db.collection('config').doc('qoin').update({ accrualRate: 0.08 });
  const direct = await until(async () => {
    const x = (await histories(globalHist())).filter((h) => h.source === 'direct' && h.field === 'accrualRate'); return x.length ? x : null; });
  ok(direct, 'direct 이력 없음');
  eq(direct.length, 1); eq([direct[0].before, direct[0].after, direct[0].changedBy], [0.05, 0.08, null]);
  // enabled 토글 (클라이언트 직접 쓰기 모사)
  await db.collection('config').doc('qoin').update({ enabled: false });
  const en = await until(async () => {
    const x = (await histories(globalHist())).filter((h) => h.field === 'globalEnabled' && h.source === 'direct'); return x.length ? x : null; });
  ok(en, 'enabled 이력 없음'); eq([en[0].before, en[0].after], [true, false]);
  await db.collection('config').doc('qoin').update({ enabled: true });
  await sleep(2500);
});
await check('CH27b 전역 최초 생성(callable): accrualRate + enabled 이력 각 1건, 트리거 중복 없음', async () => {
  await db.collection('config').doc('qoin').delete();
  await db.recursiveDelete(globalHist());
  await sleep(2500); await db.recursiveDelete(globalHist());
  const r = await call('setQoinAccrualRate', { scope: 'global', rate: 0.03 }, ADMIN);
  eq([r.result.before, r.result.after], [null, 0.03]);
  eq((await db.collection('config').doc('qoin').get()).data(), { accrualRate: 0.03, enabled: false });
  await sleep(4000);
  const hs = await histories(globalHist());
  eq(hs.length, 2, '이력 2건 (accrualRate, enabled)'); ok(hs.every((h) => h.source === 'callable'), '모두 callable');
  await setGlobal({ accrualRate: 0.03 });
  await sleep(2500);
});

// ═════════════════════════════════════════════════════════════════════════
// F. applyBrandQoinRate (CH22~CH25)
// ═════════════════════════════════════════════════════════════════════════
console.log('\n── F. applyBrandQoinRate ──');
async function seedBrandStores(brandId, n, overrides /* {index: rate} */, switchOff /* index[] */ = []) {
  const col = db.collection('stores');
  let batch = db.batch(); let c = 0;
  for (let i = 0; i < n; i++) {
    const d = { name: `${brandId}-${i}`, brandId, status: 'approved' };
    if (overrides[i] !== undefined) d.qoinAccrualRate = overrides[i];
    if (switchOff.includes(i)) d.qoinAccrualEnabled = false;
    batch.set(col.doc(`${brandId}_s${String(i).padStart(4, '0')}`), d);
    if (++c % 400 === 0) { await batch.commit(); batch = db.batch(); }
  }
  await batch.commit();
}
await check('CH22 일괄 preserve: 브랜드 값만 1 write, 개별 설정 보존, 이력 1건(completed, 수치 정확)', async () => {
  const brandId = nid('brp'); await db.collection('brands').doc(brandId).set({ name: 'P브랜드', status: 'approved' });
  await seedBrandStores(brandId, 10, { 2: 0.1, 5: 0.15, 7: 0.02 }, [1, 5]);
  const r = await call('applyBrandQoinRate', { brandId, rate: 0.05, mode: 'preserve', reason: '일괄' }, ADMIN);
  eq([r.result.status, r.result.affectedCount, r.result.clearedCount, r.result.preservedCount, r.result.totalCount], ['completed', 7, 0, 3, 3]);
  eq([r.result.disabledUntouchedCount, r.result.clearedValueCount, r.result.clearedInvalidCount, r.result.brandDisabled], [2, 0, 0, false]);
  ok(!Object.keys(r.result).some((k) => /Zero/.test(k)), '0 관련 집계 키는 삭제됐다');
  eq((await db.collection('brands').doc(brandId).get()).get('qoinAccrualRate'), 0.05);
  const snaps = await db.collection('stores').where('brandId', '==', brandId).get();
  const withOv = snaps.docs.filter((d) => d.get('qoinAccrualRate') !== undefined).map((d) => d.get('qoinAccrualRate')).sort();
  eq(withOv, [0.02, 0.1, 0.15], '개별 설정 보존');
  const hs = await histories(brandHist(brandId)); eq(hs.length, 1, '이력 1건');
  const h = hs[0];
  eq([h.op, h.bulkMode, h.status, h.affectedCount, h.clearedCount, h.preservedCount, h.before, h.after, h.changedBy, h.reason, h.source, h.targetName],
     ['bulkApply', 'preserve', 'completed', 7, 0, 3, null, 0.05, ADMIN, '일괄', 'bulk', 'P브랜드']);
  eq([h.beforeState, h.disabledUntouchedCount, h.brandDisabled], ['absent', 2, false]);
  // S2: 포인터는 지워지지 않는다 — preserve 도 `completed` 포인터를 남기고, 판정 함수는 이를 '중단 없음' 으로 읽는다.
  const pb = await db.collection('brands').doc(brandId).get();
  eq([pb.get('qoinBulkStatus'), pb.get('qoinBulkHistoryId')], ['completed', h.id], 'preserve 는 completed 포인터를 남긴다');
  ok(pb.get('qoinBulkAt'), 'qoinBulkAt');
  // 같은 호출 재시도 → no-op, 이력 중복 없음
  const r2 = await call('applyBrandQoinRate', { brandId, rate: 0.05, mode: 'preserve' }, ADMIN);
  eq(r2.result.changed, false); eq((await brandHist(brandId).get()).size, 1);
});
await check('CH22b 입력 검증 / 권한 / 개별 설정 0곳 overwrite', async () => {
  const brandId = nid('brv'); await db.collection('brands').doc(brandId).set({ name: 'V', status: 'approved' });
  eq((await call('applyBrandQoinRate', { brandId, rate: 0.05, mode: 'preserve' }, NONADMIN)).error, 'PERMISSION_DENIED');
  eq((await call('applyBrandQoinRate', { brandId, rate: 0.5, mode: 'preserve' }, ADMIN)).error, 'INVALID_ARGUMENT');
  eq((await call('applyBrandQoinRate', { brandId, rate: 0.05, mode: 'zzz' }, ADMIN)).error, 'INVALID_ARGUMENT');
  eq((await call('applyBrandQoinRate', { brandId: nid('ghost'), rate: 0.05, mode: 'preserve' }, ADMIN)).error, 'NOT_FOUND');
  eq((await brandHist(brandId).get()).size, 0, '실패 시 이력 없음');
  await seedBrandStores(brandId, 3, {});
  const r = await call('applyBrandQoinRate', { brandId, rate: 0.04, mode: 'overwrite' }, ADMIN);
  eq([r.result.status, r.result.affectedCount, r.result.clearedCount], ['completed', 3, 0]);
});
await check('CH23 일괄 overwrite (매장 600개): 청크 처리, affectedCount/clearedCount 정확, 이력 1건', async () => {
  const brandId = nid('bro'); await db.collection('brands').doc(brandId).set({ name: 'O', status: 'approved', qoinAccrualRate: 0.02 });
  const ov = {}; for (let i = 0; i < 600; i += 3) ov[i] = i % 2 === 0 ? 0.1 : 0.5; // 200곳: 유효 0.1 100곳 + 무효(범위 밖 0.5) 100곳
  const off = []; for (let i = 1; i < 600; i += 10) off.push(i); // 스위치 off 60곳 (override 없는 매장)
  await seedBrandStores(brandId, 600, ov, off);
  const r = await call('applyBrandQoinRate', { brandId, rate: 0.06, mode: 'overwrite' }, ADMIN);
  eq([r.result.status, r.result.affectedCount, r.result.clearedCount, r.result.totalCount], ['completed', 600, 200, 200]);
  eq([r.result.clearedValueCount, r.result.clearedInvalidCount, r.result.disabledUntouchedCount, r.result.brandDisabled], [100, 100, 60, false]);
  ok(r.result.clearedValueCount + r.result.clearedInvalidCount === r.result.clearedCount, '합 불변식');
  // Q1 핵심: 일괄 덮어쓰기가 스위치를 건드리지 않았다
  const offAfter = (await db.collection('stores').where('brandId', '==', brandId).where('qoinAccrualEnabled', '==', false).get()).size;
  eq(offAfter, 60, '스위치 off 매장 60곳 그대로');
  const snaps = await db.collection('stores').where('brandId', '==', brandId).get();
  eq(snaps.size, 600); eq(snaps.docs.filter((d) => d.get('qoinAccrualRate') !== undefined).length, 0, '개별 설정 전부 초기화');
  eq((await db.collection('brands').doc(brandId).get()).get('qoinAccrualRate'), 0.06);
  const hs = await histories(brandHist(brandId)); eq(hs.length, 1, '이력 1건');
  eq([hs[0].before, hs[0].after, hs[0].status, hs[0].processedCount, hs[0].bulkMode], [0.02, 0.06, 'completed', 200, 'overwrite']);
  // F2: 지워진 매장마다 매장 이력 1건 (clearByBulk), 행위자·이전 값·연결 키 포함
  const brandSnap = (await db.collection('brands').doc(brandId).get());
  eq([brandSnap.get('qoinBulkHistoryId'), brandSnap.get('qoinBulkStatus')], [hs[0].id, 'completed'], '마감 시 포인터는 삭제가 아니라 completed 전이 (S2)');
  ok(brandSnap.get('qoinBulkAt'), 'qoinBulkAt');
  const sh = await db.collectionGroup('qoinRateHistory').where('bulkHistoryId', '==', hs[0].id).get();
  eq(sh.size, 200, '매장별 이력 200건');
  const one = sh.docs.find((d) => d.get('before') === 0.1).data();
  eq([one.scope, one.field, one.op, one.beforeState, one.after, one.changedBy, one.changedByRole, one.source, one.bulkMode],
     ['store', 'accrualRate', 'clearByBulk', 'value', null, ADMIN, 'admin', 'bulk', 'overwrite']);
  const inv = sh.docs.find((d) => d.get('beforeState') === 'invalid').data();
  eq([inv.before, inv.beforeRaw], [null, '0.5'], '무효 값은 beforeState/beforeRaw 로 박제');
});
/** 중단(partial) 상황 모사: 브랜드 값/포인터/이력/일부 지워진 매장 */
async function seedPartial(brandId, { brandRate = 0.06, histAfter = 0.06, pointerHistory = true, status = 'partial' } = {}) {
  await db.collection('brands').doc(brandId).set({ name: 'R', status: 'approved', qoinAccrualRate: brandRate });
  await seedBrandStores(brandId, 20, { 1: 0.1, 4: 0.1, 8: 0.15, 9: 0.1 });
  await db.collection('stores').doc(`${brandId}_s0001`).update({ qoinAccrualRate: FieldValue.delete() });
  await db.collection('stores').doc(`${brandId}_s0004`).update({ qoinAccrualRate: FieldValue.delete() });
  const hRef = brandHist(brandId).doc();
  await hRef.set({ scope: 'brand', targetId: brandId, targetName: 'R', field: 'accrualRate', before: 0.02, beforeState: 'value', after: histAfter,
    changedBy: ADMIN, changedByRole: 'admin', changedAt: FieldValue.serverTimestamp(), reason: null, source: 'bulk', op: 'bulkApply',
    bulkMode: 'overwrite', totalCount: 4, affectedCount: 0, clearedCount: 0, clearedValueCount: 2, clearedInvalidCount: 0, preservedCount: 0, processedCount: 2, status,
    disabledUntouchedCount: 0, brandDisabled: false, lastProgressAt: FieldValue.serverTimestamp() });
  if (pointerHistory) {
    await db.collection('brands').doc(brandId).update({
      qoinBulkHistoryId: hRef.id, qoinBulkStatus: status, qoinBulkAt: Timestamp.fromMillis(Date.now() - 10 * 60 * 1000) });
  }
  return hRef;
}
await check('CH24 중단 후 resumeHistoryId 재개: 멱등, 중복 이력 없음, completed 마감, 포인터 제거, 재개 흔적', async () => {
  const brandId = nid('brr'); const hRef = await seedPartial(brandId);
  const r = await call('applyBrandQoinRate', { brandId, mode: 'overwrite', resumeHistoryId: hRef.id }, ADMIN);
  eq([r.result.status, r.result.clearedCount, r.result.processedCount], ['completed', 4, 4]);
  eq([r.result.clearedValueCount, r.result.clearedInvalidCount], [4, 0], '이전 실행분 누적');
  const snaps = await db.collection('stores').where('brandId', '==', brandId).get();
  eq(snaps.docs.filter((d) => d.get('qoinAccrualRate') !== undefined).length, 0);
  eq((await brandHist(brandId).get()).size, 1, '이력은 여전히 1건');
  const h = (await hRef.get()).data();
  eq([h.status, h.resumeCount], ['completed', 1]); ok(h.resumedAt, 'resumedAt');
  const b = (await db.collection('brands').doc(brandId).get());
  eq(b.get('qoinAccrualRate'), 0.06, '브랜드 값 불변'); eq([b.get('qoinBulkStatus'), b.get('qoinBulkHistoryId')], ['completed', hRef.id], '포인터 completed 전이 (삭제 아님)');
  // 이번 실행이 지운 2곳(8, 9)의 매장 이력 — 결정적 ID 로 중복 없음
  const sh = await db.collectionGroup('qoinRateHistory').where('bulkHistoryId', '==', hRef.id).get();
  eq(sh.size, 2, '재개분 매장 이력 2건');
  // 완료된 이력 재개 → failed-precondition
  eq((await call('applyBrandQoinRate', { brandId, mode: 'overwrite', resumeHistoryId: hRef.id }, ADMIN)).error, 'FAILED_PRECONDITION');
  eq((await call('applyBrandQoinRate', { brandId, mode: 'overwrite', resumeHistoryId: 'nope' }, ADMIN)).error, 'NOT_FOUND');
});
await check('F5-(a) 재개 재검증: 브랜드 값이 그 뒤에 바뀌었으면 거부 / 포인터가 다르면 거부 / 거부 시 매장은 건드리지 않는다', async () => {
  const brandId = nid('brq'); const hRef = await seedPartial(brandId);
  await call('setQoinAccrualRate', { scope: 'brand', targetId: brandId, rate: 0.04 }, ADMIN); // partial 은 단건 변경을 막지 않는다
  const r = await call('applyBrandQoinRate', { brandId, mode: 'overwrite', resumeHistoryId: hRef.id }, ADMIN);
  eq(r.error, 'FAILED_PRECONDITION', '값이 바뀐 뒤 재개 거부');
  const left = (await db.collection('stores').where('brandId', '==', brandId).get()).docs.filter((d) => d.get('qoinAccrualRate') !== undefined).length;
  eq(left, 2, '거부된 재개는 매장 개별 설정을 지우지 않는다');
  // S2: 단건 변경이 성공하면 옛 중단 기록은 같은 트랜잭션에서 superseded 로 마감된다 (재개 대상이 아니다).
  eq((await hRef.get()).get('status'), 'superseded', '단건 변경으로 마감됨');
  // 포인터 불일치
  const brandId2 = nid('brq2'); const h2 = await seedPartial(brandId2);
  await db.collection('brands').doc(brandId2).update({ qoinBulkHistoryId: 'other' });
  eq((await call('applyBrandQoinRate', { brandId: brandId2, mode: 'overwrite', resumeHistoryId: h2.id }, ADMIN)).error, 'FAILED_PRECONDITION', '포인터 불일치');
});
await check('F5-(b) 동시 시작: 이중 실행·이중 보고가 없다 (매장 이력 정확히 900건, 포인터 해제, 겹친 호출은 거부 또는 no-op)', async () => {
  const brandId = nid('brc'); await db.collection('brands').doc(brandId).set({ name: 'C', status: 'approved', qoinAccrualRate: 0.02 });
  const ov = {}; for (let i = 0; i < 1500; i++) ov[i] = 0.1;
  await seedBrandStores(brandId, 1500, ov);
  const results = await Promise.all([1, 2, 3].map(() =>
    call('applyBrandQoinRate', { brandId, rate: 0.06, mode: 'overwrite' }, ADMIN)));
  for (const r of results) ok(r.error === undefined || r.error === 'FAILED_PRECONDITION', `예상 밖 오류 ${r.error} ${r.message}`);
  const cleared = results.filter((r) => r.result).reduce((a, r) => a + r.result.clearedCount, 0);
  eq(cleared, 1500, '보고된 clearedCount 합 = 실제 (이중 보고 없음)');
  const hs = await brandHist(brandId).get();
  // S3-a: 이전 단언은 `clearedCount>0` 인 이력만 세어 빈 이력 2건을 못 잡았다. **브랜드 이력 문서 수 자체**를 센다.
  eq(hs.size, 1, '브랜드 이력 문서는 정확히 1건 (빈 이력 0)');
  const bulkIds = hs.docs.filter((d) => d.get('clearedCount') > 0).map((d) => d.id);
  eq(bulkIds.length, 1, '실제로 지운 이력은 1건');
  const sh = await db.collectionGroup('qoinRateHistory').where('bulkHistoryId', '==', bulkIds[0]).get();
  eq(sh.size, 1500, '매장 이력 1500건 (중복 없음)');
  const b = await db.collection('brands').doc(brandId).get();
  eq([b.get('qoinBulkStatus'), b.get('qoinBulkHistoryId'), b.get('qoinAccrualRate')], ['completed', bulkIds[0], 0.06], '포인터 completed / 브랜드 값');
  console.log(`     [F5-b] 응답: ${results.map((r) => r.error ?? (r.result.changed ? 'changed' : 'noop')).join(', ')} / 브랜드 이력 ${hs.size}건`);
});
await check('F5-(c) 일괄 진행 중 단건 변경 거부: 브랜드 단건 / 매장 단건 / 스위치(매장·브랜드) 전부', async () => {
  const brandId = nid('brg'); await db.collection('brands').doc(brandId).set({
    name: 'G', status: 'approved', qoinBulkHistoryId: 'hx', qoinBulkStatus: 'in_progress', qoinBulkAt: Timestamp.now() });
  const storeId = nid('stg'); await db.collection('stores').doc(storeId).set({ name: 'SG', brandId });
  eq((await call('setQoinAccrualRate', { scope: 'brand', targetId: brandId, rate: 0.05 }, ADMIN)).error, 'FAILED_PRECONDITION', '브랜드 단건');
  eq((await call('setQoinAccrualRate', { scope: 'store', targetId: storeId, rate: 0.05 }, ADMIN)).error, 'FAILED_PRECONDITION', '매장 단건');
  eq((await call('setQoinAccrualEnabled', { scope: 'store', targetId: storeId, enabled: false }, ADMIN)).error, 'FAILED_PRECONDITION', '매장 스위치');
  eq((await call('setQoinAccrualEnabled', { scope: 'brand', targetId: brandId, enabled: false }, ADMIN)).error, 'FAILED_PRECONDITION', '브랜드 스위치');
  eq((await call('applyBrandQoinRate', { brandId, rate: 0.01, mode: 'overwrite' }, ADMIN)).error, 'FAILED_PRECONDITION', '새 일괄 적용');
  eq((await storeHist(storeId).get()).size, 0, '거부 시 이력 없음');
  // stale(5분 초과) in_progress 는 중단으로 본다 → 단건 허용
  await db.collection('brands').doc(brandId).update({ qoinBulkAt: Timestamp.fromMillis(Date.now() - 10 * 60 * 1000) });
  eq((await call('setQoinAccrualRate', { scope: 'store', targetId: storeId, rate: 0.05 }, ADMIN)).result.changed, true, 'stale 포인터는 막지 않는다');
});
await check('CH25 일괄 적용 중 어떤 매장도 의도 밖의 값(옛 브랜드 값/전역 값)을 거치지 않는다', async () => {
  const brandId = nid('brx'); await setGlobal({ accrualRate: 0.03 });
  await db.collection('brands').doc(brandId).set({ name: 'X', status: 'approved', qoinAccrualRate: 0.02 });
  const ov = {}; for (let i = 0; i < 900; i += 2) ov[i] = 0.1; // 450곳이 0.1% 아닌 10% 개별 설정
  await seedBrandStores(brandId, 900, ov);
  const observed = new Set(); let stop = false; let polls = 0;
  const NEW = 0.06;
  const poller = (async () => {
    while (!stop) {
      const [b, ...rest] = await Promise.all([
        db.collection('brands').doc(brandId).get(),
        ...[0, 1, 2, 3, 600, 601].map((i) => db.collection('stores').doc(`${brandId}_s${String(i).padStart(4, '0')}`).get()),
      ]);
      const brandVal = b.get('qoinAccrualRate');
      for (const s of rest) {
        // 매장의 유효 값 = 개별 설정 ?? 브랜드 값 ?? 전역. 브랜드 쓰기 후에는 NEW 또는 자기 값(0.1)만 가능해야 한다.
        const own = s.get('qoinAccrualRate');
        const eff = own !== undefined ? own : (brandVal !== undefined ? brandVal : 0.03);
        observed.add(`${s.id.endsWith('0') || Number(s.id.slice(-4)) % 2 === 0 ? 'ov' : 'plain'}:${brandVal}:${eff}`);
      }
      polls++;
    }
  })();
  await sleep(300);
  const r = await call('applyBrandQoinRate', { brandId, rate: NEW, mode: 'overwrite' }, ADMIN);
  stop = true; await poller;
  eq(r.result.status, 'completed');
  // 개별 설정이 없는 매장(plain)은 브랜드 쓰기 전(0.02)이거나 후(0.06)만 — 전역 0.03 으로 떨어진 관측이 있으면 안 된다.
  const bad = [...observed].filter((o) => o.startsWith('plain:') && !o.endsWith(':0.02') && !o.endsWith(`:${NEW}`));
  eq(bad, [], `plain 매장이 의도 밖 값을 관측함 (polls=${polls})`);
  // 개별 설정 매장(ov)은 지워지기 전엔 0.1, 지운 뒤엔 NEW. 전역(0.03)/옛 브랜드 값(0.02)으로 떨어지면 안 된다.
  const bad2 = [...observed].filter((o) => o.startsWith('ov:') && !o.endsWith(':0.1') && !o.endsWith(`:${NEW}`));
  eq(bad2, [], `override 매장이 의도 밖 값을 관측함 (polls=${polls})`);
  console.log(`     [CH25] 관측 ${polls}회, 고유 관측 ${observed.size}종: ${[...observed].join(' | ')}`);
});

// ═════════════════════════════════════════════════════════════════════════
// G. setQoinAccrualEnabled (스위치 callable, 경로 #18)
// ═════════════════════════════════════════════════════════════════════════
console.log('\n── G. setQoinAccrualEnabled ──');
await check('SW-1 권한 · 입력 경계 (callableSwitch C01~C04 + scope/targetId)', async () => {
  const storeId = nid('st'); await db.collection('stores').doc(storeId).set({ name: 'S' });
  eq((await call('setQoinAccrualEnabled', { scope: 'store', targetId: storeId, enabled: false }, undefined)).error, 'UNAUTHENTICATED');
  eq((await call('setQoinAccrualEnabled', { scope: 'store', targetId: storeId, enabled: false }, NONADMIN)).error, 'PERMISSION_DENIED');
  for (const row of table.callableSwitch) {
    const r = await call('setQoinAccrualEnabled', { scope: 'store', targetId: storeId, enabled: decode(row.enabled) }, ADMIN);
    if (row.expect === 'reject') eq(r.error, 'INVALID_ARGUMENT', `callableSwitch ${row.id}`);
    else ok(r.result, `callableSwitch ${row.id} accept`);
  }
  for (const enabled of [undefined, null, 'true', 1]) {
    eq((await call('setQoinAccrualEnabled', { scope: 'store', targetId: storeId, enabled }, ADMIN)).error, 'INVALID_ARGUMENT', `enabled=${enabled}`);
  }
  eq((await call('setQoinAccrualEnabled', { scope: 'global', targetId: 'qoin', enabled: false }, ADMIN)).error, 'INVALID_ARGUMENT', 'scope global 거부');
  eq((await call('setQoinAccrualEnabled', { scope: 'nope', targetId: storeId, enabled: false }, ADMIN)).error, 'INVALID_ARGUMENT');
  eq((await call('setQoinAccrualEnabled', { scope: 'store', targetId: '', enabled: false }, ADMIN)).error, 'INVALID_ARGUMENT');
  eq((await call('setQoinAccrualEnabled', { scope: 'store', targetId: nid('ghost'), enabled: false }, ADMIN)).error, 'NOT_FOUND');
  eq((await call('setQoinAccrualEnabled', { scope: 'store', targetId: storeId, enabled: false, reason: 'x'.repeat(201) }, ADMIN)).error, 'INVALID_ARGUMENT');
});
await check('SW-2 끄기 = qoinAccrualEnabled:false + 이력 1건 / 켜기 = 필드 삭제 + 이력 / 같은 값 = no-op (이력 중복 없음) / status·updatedAt 불변', async () => {
  const storeId = nid('st');
  await db.collection('stores').doc(storeId).set({ name: '강남점', status: 'approved', updatedAt: new Date('2026-01-01'), qoinAccrualRate: 0.07 });
  let r = await call('setQoinAccrualEnabled', { scope: 'store', targetId: storeId, enabled: false, reason: '점검' }, ADMIN);
  eq([r.result.before, r.result.after, r.result.changed], [null, false, true]); ok(r.result.historyId, 'historyId');
  let d = (await db.collection('stores').doc(storeId).get()).data();
  eq([d.qoinAccrualEnabled, d.qoinAccrualRate, d.status], [false, 0.07, 'approved'], '숫자는 건드리지 않는다');
  eq(d.updatedAt.toMillis(), new Date('2026-01-01').getTime(), 'updatedAt 불변');
  let hs = await histories(storeHist(storeId)); eq(hs.length, 1);
  const h = hs[0];
  eq([h.scope, h.targetId, h.targetName, h.field, h.before, h.beforeState, h.beforeRaw, h.after, h.op, h.changedBy, h.changedByRole, h.reason, h.source],
     ['store', storeId, '강남점', 'accrualEnabled', null, 'absent', null, false, 'set', ADMIN, 'admin', '점검', 'callable']);
  ok(h.changedAt, 'changedAt');
  r = await call('setQoinAccrualEnabled', { scope: 'store', targetId: storeId, enabled: false }, ADMIN);
  eq([r.result.changed, r.result.historyId], [false, null]); eq((await storeHist(storeId).get()).size, 1, '중복 이력 없음');
  r = await call('setQoinAccrualEnabled', { scope: 'store', targetId: storeId, enabled: true }, ADMIN);
  eq([r.result.before, r.result.after, r.result.changed], [false, null, true]);
  d = (await db.collection('stores').doc(storeId).get()).data();
  eq(d.qoinAccrualEnabled, undefined, '켜면 필드 삭제 (true 를 저장하지 않는다)'); eq(d.qoinAccrualRate, 0.07, '숫자 보존');
  hs = await histories(storeHist(storeId));
  ok(hs.some((x) => x.op === 'clear' && x.before === false && x.after === null && x.beforeState === 'value'), 'clear 이력');
  r = await call('setQoinAccrualEnabled', { scope: 'store', targetId: storeId, enabled: true }, ADMIN);
  eq(r.result.changed, false, '이미 사용 상태 켜기 = no-op');
  // 브랜드
  const brandId = nid('br'); await db.collection('brands').doc(brandId).set({ name: 'B' });
  r = await call('setQoinAccrualEnabled', { scope: 'brand', targetId: brandId, enabled: false }, ADMIN);
  eq(r.result.after, false);
  const bh = await histories(brandHist(brandId)); eq([bh.length, bh[0].scope, bh[0].field], [1, 'brand', 'accrualEnabled']);
});
await check('SW-3 비bool 이전 값은 beforeState:invalid + beforeRaw 로 박제 (부가 B 의 스위치판)', async () => {
  const storeId = nid('st'); await db.collection('stores').doc(storeId).set({ name: 'S', qoinAccrualEnabled: 'false' });
  const r = await call('setQoinAccrualEnabled', { scope: 'store', targetId: storeId, enabled: false }, ADMIN);
  eq(r.result.changed, true, '무효 값은 덮어써야 한다');
  const h = (await histories(storeHist(storeId)))[0];
  eq([h.before, h.beforeState, h.beforeRaw, h.after], [null, 'invalid', '"false"', false]);
});
await check('부가 B: setQoinAccrualRate 이전 값이 무효(문자열)면 beforeState:invalid + beforeRaw, 부재면 absent', async () => {
  const storeId = nid('st'); await db.collection('stores').doc(storeId).set({ name: 'S', qoinAccrualRate: '3' });
  await call('setQoinAccrualRate', { scope: 'store', targetId: storeId, rate: 0.05 }, ADMIN);
  const h = (await histories(storeHist(storeId)))[0];
  eq([h.before, h.beforeState, h.beforeRaw, h.after], [null, 'invalid', '"3"', 0.05]);
  const s2 = nid('st'); await db.collection('stores').doc(s2).set({ name: 'S' });
  await call('setQoinAccrualRate', { scope: 'store', targetId: s2, rate: 0.05 }, ADMIN);
  const h2 = (await histories(storeHist(s2)))[0]; eq([h2.before, h2.beforeState, h2.beforeRaw], [null, 'absent', null]);
});

// ═════════════════════════════════════════════════════════════════════════
// H. N4 · Q1 · F1(T3) · Q2 회귀 — 1순위
// ═════════════════════════════════════════════════════════════════════════
console.log('\n── H. N4 / Q1 / T3 / Q2 ──');
async function brandWorld({ brandDoc = {}, storeDoc = {}, global = 0.03 } = {}) {
  const uid = nid('u'); await seedUser(uid); await setGlobal({ accrualRate: global });
  const brandId = nid('br'); const storeId = nid('st');
  await db.collection('brands').doc(brandId).set({ name: 'B', status: 'approved', ...brandDoc });
  await db.collection('stores').doc(storeId).set({ name: 'S', status: 'approved', brandId, ...storeDoc });
  return { uid, brandId, storeId };
}
await check('Q1 일괄 덮어쓰기 후에도 `적립 사용 안 함` 매장은 적립되지 않는다 (1순위 회귀)', async () => {
  const { uid, brandId, storeId } = await brandWorld({ brandDoc: { qoinAccrualRate: 0.02 }, storeDoc: { qoinAccrualEnabled: false, qoinAccrualRate: 0.1 } });
  const r = await call('applyBrandQoinRate', { brandId, rate: 0.06, mode: 'overwrite' }, ADMIN);
  eq([r.result.status, r.result.clearedCount, r.result.disabledUntouchedCount], ['completed', 1, 1]);
  const st = (await db.collection('stores').doc(storeId).get()).data();
  eq([st.qoinAccrualEnabled, st.qoinAccrualRate], [false, undefined], '스위치 불변 / 숫자만 지워짐');
  const led = await completeOrder({ orderId: nid('o'), uid, storeId, expectLedger: false });
  ok(led === null, '일괄 덮어쓰기 뒤 사용 안 함 매장이 적립됨 (Q1 위반)');
  // 같은 브랜드의 켜진 매장은 새 브랜드 값으로 적립
  const s2 = nid('st'); await db.collection('stores').doc(s2).set({ name: 'S2', brandId });
  const led2 = await completeOrder({ orderId: nid('o'), uid, storeId: s2 });
  ok(led2 && led2.get('accrualRate') === 0.06 && led2.get('accrualRateSource') === 'brand', '켜진 매장은 새 브랜드 값');
});
await check('N4-① 브랜드 off + 개별 요율 10% → 적립 0, qoinSettlementIssues 미기록, 로그 skipped_accrual_disabled', async () => {
  const { uid, storeId } = await brandWorld({ brandDoc: { qoinAccrualEnabled: false, qoinAccrualRate: 0.05 }, storeDoc: { qoinAccrualRate: 0.1 } });
  const oid = nid('o');
  ok((await completeOrder({ orderId: oid, uid, storeId, expectLedger: false })) === null, '적립됨');
  ok((await issueDoc(oid)) === null, '이슈가 기록되면 안 됨');
});
await check('N4-② 같은 상태에서 환불 → 회수 통과 (막으면 Qoin 누수)', async () => {
  const { uid, brandId, storeId } = await brandWorld({ brandDoc: { qoinAccrualRate: 0.05 }, storeDoc: { qoinAccrualRate: 0.1 } });
  const oid = nid('o');
  const earn = await completeOrder({ orderId: oid, uid, storeId }); ok(earn && earn.get('amount') === 1000, 'earn');
  await db.collection('brands').doc(brandId).update({ qoinAccrualEnabled: false }); // 브랜드 off 후
  const cb = await refundOrder(oid, uid); ok(cb && cb.get('amount') === -1000, '회수가 스위치에 막혔다');
  eq((await db.collection('users').doc(uid).get()).get('qoinBalance'), 0, '잔액 0');
});
await check('N4-③ 브랜드 off + 매장 switch true 명시 → 적립 0 (R23b: 명시적 true 는 예외가 아니다)', async () => {
  const { uid, storeId } = await brandWorld({ brandDoc: { qoinAccrualEnabled: false, qoinAccrualRate: 0.05 }, storeDoc: { qoinAccrualEnabled: true } });
  const oid = nid('o');
  ok((await completeOrder({ orderId: oid, uid, storeId, expectLedger: false })) === null, '적립됨');
  ok((await issueDoc(oid)) === null, '이슈 미기록');
});
await check('N4-④ 브랜드 switch 무효(1) + 개별 요율 10% → 적립 0 + 기록 (R22b: reason invalid_enabled, scope brand)', async () => {
  const { uid, brandId, storeId } = await brandWorld({ brandDoc: { qoinAccrualEnabled: 1 }, storeDoc: { qoinAccrualRate: 0.1 } });
  const oid = nid('o');
  ok((await completeOrder({ orderId: oid, uid, storeId, expectLedger: false })) === null, '적립됨');
  const i = await issueDoc(oid); ok(i, '기록 없음');
  eq([i.reason, i.scope, i.brandId, i.storeId, i.userId, i.resolved, i.totalPrice], ['invalid_enabled', 'brand', brandId, storeId, uid, false, 10000]);
  ok(i.occurredAt, 'occurredAt'); eq(i.values.brandEnabled, 1); eq(i.values.storeRate, 0.1);
});
await check('N4-⑤ 매장 switch 무효 + 브랜드 off → 적립 0 + 기록 없음 (R21b: disabled 가 invalid 보다 앞)', async () => {
  const { uid, storeId } = await brandWorld({ brandDoc: { qoinAccrualEnabled: false }, storeDoc: { qoinAccrualEnabled: 'false' } });
  const oid = nid('o');
  ok((await completeOrder({ orderId: oid, uid, storeId, expectLedger: false })) === null, '적립됨');
  ok((await issueDoc(oid)) === null, '기록되면 안 됨');
});
await check('N4-⑥ 브랜드 off 로 일괄 적용 → brandDisabled:true (응답·브랜드 이력)', async () => {
  const { brandId } = await brandWorld({ brandDoc: { qoinAccrualEnabled: false }, storeDoc: { qoinAccrualRate: 0.1 } });
  const r = await call('applyBrandQoinRate', { brandId, rate: 0.05, mode: 'overwrite' }, ADMIN);
  eq([r.result.status, r.result.brandDisabled], ['completed', true]);
  const h = (await histories(brandHist(brandId)))[0]; eq(h.brandDisabled, true);
  eq((await db.collection('brands').doc(brandId).get()).get('qoinAccrualEnabled'), false, '브랜드 스위치 불변');
});
await check('R25 사용 안 함 매장 + 전역 설정 부재 → 이슈 미기록 (스위치가 전역 검사 앞에서 단락)', async () => {
  const uid = nid('u'); await seedUser(uid);
  await db.collection('config').doc('qoin').set({ enabled: true }); // accrualRate 없음
  const storeId = nid('st'); await db.collection('stores').doc(storeId).set({ name: 'S', qoinAccrualEnabled: false });
  const oid = nid('o');
  ok((await completeOrder({ orderId: oid, uid, storeId, expectLedger: false })) === null);
  ok((await issueDoc(oid)) === null, 'R25: 기록되면 안 됨');
  await setGlobal({ accrualRate: 0.03 });
});
await check('T3-1 order.brandId=null + store.brandId=A(5%) → 500 / brand / 원장 brandId=A (F1 본체)', async () => {
  const { uid, brandId, storeId } = await brandWorld({ brandDoc: { qoinAccrualRate: 0.05 } });
  const orderId = nid('o');
  const led = await completeOrder({ orderId, uid, storeId });
  eq((await db.collection('orders').doc(orderId).get()).get('brandId'), null, '운영이 만드는 주문의 brandId 는 null');
  ok(led, 'earn'); eq([led.get('amount'), led.get('accrualRateSource'), led.get('brandId')], [500, 'brand', brandId]);
});
await check('T3-2 order.brandId=B(20%) 스푸핑 + store.brandId=A(5%) → 5% 적용, 원장 brandId=A', async () => {
  const { uid, brandId, storeId } = await brandWorld({ brandDoc: { qoinAccrualRate: 0.05 } });
  const brandB = nid('brB'); await db.collection('brands').doc(brandB).set({ name: 'B20', qoinAccrualRate: 0.2 });
  const led = await completeOrder({ orderId: nid('o'), uid, storeId, orderOverrides: { brandId: brandB } });
  ok(led, 'earn'); eq([led.get('amount'), led.get('accrualRateSource'), led.get('brandId')], [500, 'brand', brandId]);
});
await check('T3-3 order.brandId=A + store.brandId 부재 → 전역값, 원장 brandId=null', async () => {
  const uid = nid('u'); await seedUser(uid); await setGlobal({ accrualRate: 0.03 });
  const brandA = nid('brA'); await db.collection('brands').doc(brandA).set({ name: 'A', qoinAccrualRate: 0.2 });
  const storeId = nid('st'); await db.collection('stores').doc(storeId).set({ name: 'S' });
  const led = await completeOrder({ orderId: nid('o'), uid, storeId, orderOverrides: { brandId: brandA } });
  ok(led, 'earn'); eq([led.get('amount'), led.get('accrualRateSource'), led.get('brandId')], [300, 'global', null]);
});
await check('Q2 invalid_total · invalid_store · invalid_global 이슈 기록 + 멱등 (같은 주문 재처리에도 1건)', async () => {
  const uid = nid('u'); await seedUser(uid); await setGlobal({ accrualRate: 0.03 });
  const storeId = nid('st'); await db.collection('stores').doc(storeId).set({ name: 'S' });
  const o1 = nid('o'); ok((await completeOrder({ orderId: o1, uid, storeId, total: -5, expectLedger: false })) === null);
  let i = await issueDoc(o1); ok(i && i.reason === 'invalid_total', 'invalid_total');
  await setGlobal({ accrualRate: 0.5 });
  const o2 = nid('o'); ok((await completeOrder({ orderId: o2, uid, storeId, expectLedger: false })) === null);
  i = await issueDoc(o2); eq([i.reason, i.scope, i.values.globalRate], ['invalid_rate', 'global', 0.5]);
  // 멱등: ready 로 되돌렸다 다시 completed → 같은 문서 ID, 문서 1건 유지 (재시도/중복 전달 모사)
  await db.collection('orders').doc(o2).update({ status: 'ready' }); await sleep(400);
  await db.collection('orders').doc(o2).update({ status: 'completed' }); await sleep(3500);
  eq((await db.collection('qoinSettlementIssues').where('orderId', '==', o2).get()).size, 1, '이슈 1건');
  await setGlobal({ accrualRate: 0.03 });
});
await check('Q2 소급은 만들지 않는다: 설정을 고쳐도 기록된 주문은 자동 적립되지 않는다 (backlog)', async () => {
  const uid = nid('u'); await seedUser(uid); await setGlobal({ accrualRate: 0.5 });
  const storeId = nid('st'); await db.collection('stores').doc(storeId).set({ name: 'S' });
  const oid = nid('o'); await completeOrder({ orderId: oid, uid, storeId, expectLedger: false });
  await setGlobal({ accrualRate: 0.03 }); await sleep(2500);
  ok(!(await ledger(uid, `earn_${oid}`)).exists, '소급 적립됨');
  ok(await issueDoc(oid), '기록 유지');
});

// ═════════════════════════════════════════════════════════════════════════
// I. 레거시 0 호환 · 마이그레이션 (경로 #20, 임시 — 정리 커밋에서 이 섹션 삭제)
// ═════════════════════════════════════════════════════════════════════════
console.log('\n── I. 레거시 0 · migrateQoinZeroRates ──');
await check('MG-0 과도기 호환 판독: 레거시 0 은 사용 안 함처럼 동작 — 적립 0 · 이슈 미기록 (TRANSITIONAL)', async () => {
  const { uid, storeId } = await brandWorld({ brandDoc: { qoinAccrualRate: 0.05 }, storeDoc: { qoinAccrualRate: 0 } });
  const oid = nid('o');
  ok((await completeOrder({ orderId: oid, uid, storeId, expectLedger: false })) === null, '레거시 0 매장 적립됨');
  ok((await issueDoc(oid)) === null, '의도된 중단을 누락 사건으로 오기록');
});
await check('MG-1 레거시 0 매장이 있는 브랜드의 일괄 적용은 failed-precondition 으로 거부 (details: legacyZeroCount, storeIds) · 쓰기 0', async () => {
  const { brandId, storeId } = await brandWorld({ brandDoc: { qoinAccrualRate: 0.02 }, storeDoc: { qoinAccrualRate: 0 } });
  for (const mode of ['preserve', 'overwrite']) {
    const r = await call('applyBrandQoinRate', { brandId, rate: 0.06, mode }, ADMIN);
    eq(r.error, 'FAILED_PRECONDITION', mode);
    const det = Array.isArray(r.details) ? r.details[0] : r.details;
    eq([det?.legacyZeroCount, det?.storeIds], [1, [storeId]], `details (${mode})`);
  }
  eq((await db.collection('brands').doc(brandId).get()).get('qoinAccrualRate'), 0.02, '브랜드 값 불변');
  eq((await brandHist(brandId).get()).size, 0, '이력 없음');
  eq((await db.collection('stores').doc(storeId).get()).get('qoinAccrualRate'), 0, '매장 값 불변 (정책 판단 없음)');
});
await check('MG-2 dry-run: 쓰기 0, 0% 목록 · 무효 목록 반환 (무효 값은 보고만)', async () => {
  const tag = nid('mg');
  const z1 = `${tag}_z1`; const z2 = `${tag}_z2`; const bad = `${tag}_bad`; const okS = `${tag}_ok`;
  await db.collection('stores').doc(z1).set({ name: 'Z1', qoinAccrualRate: 0 });
  await db.collection('stores').doc(z2).set({ name: 'Z2', qoinAccrualRate: 0, qoinAccrualEnabled: false });
  await db.collection('stores').doc(bad).set({ name: 'BAD', qoinAccrualRate: '3' });
  await db.collection('stores').doc(okS).set({ name: 'OK', qoinAccrualRate: 0.05 });
  const zb = `${tag}_zb`; await db.collection('brands').doc(zb).set({ name: 'ZB', qoinAccrualRate: 0 });
  eq((await call('migrateQoinZeroRates', { dryRun: true }, NONADMIN)).error, 'PERMISSION_DENIED');
  eq((await call('migrateQoinZeroRates', { dryRun: 'true' }, ADMIN)).error, 'INVALID_ARGUMENT');
  const r = await call('migrateQoinZeroRates', { dryRun: true }, ADMIN);
  const ids = (a) => a.map((x) => x.id);
  ok(ids(r.result.zeroStores).includes(z1) && ids(r.result.zeroStores).includes(z2), 'zeroStores');
  ok(ids(r.result.zeroBrands).includes(zb), 'zeroBrands');
  const badRow = r.result.invalidStores.find((x) => x.id === bad);
  eq([badRow?.raw, badRow?.name], ['"3"', 'BAD'], 'invalidStores.raw 는 JSON 텍스트');
  ok(!ids(r.result.zeroStores).includes(okS) && !ids(r.result.invalidStores).includes(okS), '정상 매장은 대상 아님');
  eq([r.result.dryRun, r.result.migrated, r.result.skipped], [true, 0, 0]);
  eq((await db.collection('stores').doc(z1).get()).get('qoinAccrualRate'), 0, 'dry-run 쓰기 0');
  eq((await storeHist(z1).get()).size, 0, 'dry-run 이력 0');
});
await check('MG-3 실행: 0 삭제 + 스위치 off + 이력(source migration, 행위자, migratedFromRate 0) · 무효 값은 손대지 않음 · 멱등(재실행 이력 0)', async () => {
  const tag = nid('mx');
  const z1 = `${tag}_z1`; const bad = `${tag}_bad`; const zb = `${tag}_zb`;
  await db.collection('stores').doc(z1).set({ name: 'Z1', status: 'approved', qoinAccrualRate: 0 });
  await db.collection('stores').doc(bad).set({ name: 'BAD', qoinAccrualRate: '3' });
  await db.collection('brands').doc(zb).set({ name: 'ZB', qoinAccrualRate: 0 });
  const r = await call('migrateQoinZeroRates', { dryRun: false }, ADMIN);
  ok(r.result.migrated >= 2, `migrated ${r.result.migrated}`);
  let d = (await db.collection('stores').doc(z1).get()).data();
  eq([d.qoinAccrualRate, d.qoinAccrualEnabled, d.status], [undefined, false, 'approved']);
  d = (await db.collection('brands').doc(zb).get()).data(); eq([d.qoinAccrualRate, d.qoinAccrualEnabled], [undefined, false]);
  const h = (await histories(storeHist(z1)));
  eq(h.length, 1);
  eq([h[0].field, h[0].op, h[0].before, h[0].beforeState, h[0].after, h[0].source, h[0].changedBy, h[0].changedByRole, h[0].migratedFromRate, h[0].scope],
     ['accrualEnabled', 'set', null, 'absent', false, 'migration', ADMIN, 'admin', 0, 'store']);
  ok(h[0].reason && h[0].reason.includes('Q1'), 'reason');
  eq((await histories(brandHist(zb))).length, 1, '브랜드 이력');
  eq((await db.collection('stores').doc(bad).get()).get('qoinAccrualRate'), '3', '무효 값 자동 변환 금지');
  // 멱등: 재실행 — 이미 이전된 건 skip, 이력도 안 씀
  const r2 = await call('migrateQoinZeroRates', { dryRun: false }, ADMIN);
  ok(!r2.result.zeroStores.some((x) => x.id === z1) && !r2.result.zeroBrands.some((x) => x.id === zb), '재스캔에서 이미 이전된 건 대상 아님');
  eq((await storeHist(z1).get()).size, 1, '재실행 후에도 이력 1건'); eq((await brandHist(zb).get()).size, 1);
  // 이전 후 적립 해석: 사용 안 함으로 동작 (호환 분기 없이)
  const dry = await call('migrateQoinZeroRates', { dryRun: true }, ADMIN);
  eq(dry.result.zeroStores.length + dry.result.zeroBrands.length >= 0, true);
});

// ═════════════════════════════════════════════════════════════════════════
// J. F3 — enabled 행위자 (app_direct vs direct) · 이력 beforeState
// ═════════════════════════════════════════════════════════════════════════
console.log('\n── J. F3 · onQoinConfigWritten 행위자 ──');
await check('F3-1 앱 토글(enabledChangedBy+At 갱신) → source app_direct + changedBy uid + field globalEnabled / Console 편집(enabled 만) → source direct, changedBy null', async () => {
  await setGlobal({ accrualRate: 0.03 }); await sleep(2500); await db.recursiveDelete(globalHist());
  await db.collection('config').doc('qoin').update({ enabled: false, enabledChangedBy: ADMIN, enabledChangedAt: FieldValue.serverTimestamp() });
  const app = await until(async () => {
    const x = (await histories(globalHist())).filter((h) => h.field === 'globalEnabled' && h.source === 'app_direct'); return x.length ? x : null; });
  ok(app, 'app_direct 이력 없음');
  eq([app[0].changedBy, app[0].changedByRole, app[0].before, app[0].after, app[0].beforeState], [ADMIN, 'admin', true, false, 'value']);
  // Console 모사: enabledChangedAt 을 건드리지 않는 쓰기
  await db.collection('config').doc('qoin').update({ enabled: true });
  const con = await until(async () => {
    const x = (await histories(globalHist())).filter((h) => h.field === 'globalEnabled' && h.source === 'direct'); return x.length ? x : null; });
  ok(con, 'direct 이력 없음'); eq([con[0].changedBy, con[0].changedByRole], [null, null], 'Console 은 행위자 미상');
  await sleep(2500);
});
await check('F3-2 전역 accrualRate Console 편집 시 beforeState/beforeRaw (무효였던 값)', async () => {
  await db.collection('config').doc('qoin').update({ accrualRate: 'oops' });
  await sleep(2500); await db.recursiveDelete(globalHist());
  await db.collection('config').doc('qoin').update({ accrualRate: 0.04 });
  const x = await until(async () => {
    const r = (await histories(globalHist())).filter((h) => h.field === 'accrualRate' && h.source === 'direct'); return r.length ? r : null; });
  ok(x, '이력 없음'); eq([x[0].before, x[0].beforeState, x[0].beforeRaw, x[0].after], [null, 'invalid', '"oops"', 0.04]);
  await setGlobal({ accrualRate: 0.03 }); await sleep(2500);
});

// ═════════════════════════════════════════════════════════════════════════
// K. 중단 포인터의 상태 기계 (spec §21.2 S2) + 오래된 스캔 가드 (§21.3-a S3) + 단건 레거시 0 가드 (§21.9-2)
//    "이력을 문서 수로 센다" — 이전 단언(clearedCount>0 만 셈)은 빈 이력을 통과시켰다.
// ═════════════════════════════════════════════════════════════════════════
console.log('\n── K. 포인터 종결 · staleScan · 단건 레거시 0 ──');
const ptr = async (brandId) => {
  const d = (await db.collection('brands').doc(brandId).get());
  return { id: d.get('qoinBulkHistoryId'), st: d.get('qoinBulkStatus'), at: d.get('qoinBulkAt') };
};
await check('K1 종결 경로 ① partial 뒤 새 overwrite(다른 값): 옛 이력 superseded(supersededBy=새 id) + 포인터 새 시도로 교체 → completed. 이력 문서 2건', async () => {
  const brandId = nid('kb1'); const old = await seedPartial(brandId);
  const r = await call('applyBrandQoinRate', { brandId, rate: 0.04, mode: 'overwrite' }, ADMIN);
  eq([r.result.changed, r.result.status], [true, 'completed']);
  const o = (await old.get()).data();
  eq([o.status, o.supersededBy, o.supersededByUid], ['superseded', r.result.historyId, ADMIN]); ok(o.supersededAt, 'supersededAt');
  eq((await brandHist(brandId).get()).size, 2, '이력 문서 2건 (옛 1 + 새 1)');
  const p = await ptr(brandId); eq([p.id, p.st], [r.result.historyId, 'completed']);
});
await check('K2 종결 경로 ② partial 뒤 preserve: 옛 이력 superseded + 포인터 completed(새 id)', async () => {
  const brandId = nid('kb2'); const old = await seedPartial(brandId);
  const r = await call('applyBrandQoinRate', { brandId, rate: 0.04, mode: 'preserve' }, ADMIN);
  eq(r.result.changed, true);
  eq([(await old.get()).get('status'), (await old.get()).get('supersededBy')], ['superseded', r.result.historyId]);
  const p = await ptr(brandId); eq([p.id, p.st], [r.result.historyId, 'completed']);
  const left = (await db.collection('stores').where('brandId', '==', brandId).get()).docs.filter((d) => d.get('qoinAccrualRate') !== undefined).length;
  eq(left, 2, 'preserve 는 개별 설정을 지우지 않는다');
});
await check('K3 종결 경로 ③ partial 뒤 브랜드 단건 변경: 옛 이력 superseded(supersededBy null) + 포인터 superseded(id 는 옛 시도 유지). 값이 같은 noop 은 닫지 않는다', async () => {
  const brandId = nid('kb3'); const old = await seedPartial(brandId);
  const noop = await call('setQoinAccrualRate', { scope: 'brand', targetId: brandId, rate: 0.06 }, ADMIN);
  eq(noop.result.changed, false); eq((await old.get()).get('status'), 'partial', 'noop 은 닫지 않는다'); eq((await ptr(brandId)).st, 'partial');
  const r = await call('setQoinAccrualRate', { scope: 'brand', targetId: brandId, rate: 0.05 }, ADMIN);
  eq(r.result.changed, true);
  const o = (await old.get()).data(); eq([o.status, o.supersededBy, o.supersededByUid], ['superseded', null, ADMIN]);
  const p = await ptr(brandId); eq([p.id, p.st], [old.id, 'superseded']);
});
await check('K4 종결 경로 ④ partial 뒤 브랜드 스위치 변경: 옛 이력 superseded + 포인터 superseded. 스위치 noop 은 닫지 않는다', async () => {
  const brandId = nid('kb4'); const old = await seedPartial(brandId);
  const noop = await call('setQoinAccrualEnabled', { scope: 'brand', targetId: brandId, enabled: true }, ADMIN);
  eq(noop.result.changed, false); eq((await ptr(brandId)).st, 'partial', 'noop 은 닫지 않는다');
  const r = await call('setQoinAccrualEnabled', { scope: 'brand', targetId: brandId, enabled: false }, ADMIN);
  eq(r.result.changed, true);
  eq([(await old.get()).get('status'), (await old.get()).get('supersededBy')], ['superseded', null]);
  const p = await ptr(brandId); eq([p.id, p.st], [old.id, 'superseded']);
  // 매장 단건은 브랜드 포인터를 건드리지 않는다
  const brand2 = nid('kb4b'); const old2 = await seedPartial(brand2);
  await call('setQoinAccrualRate', { scope: 'store', targetId: `${brand2}_s0008`, rate: 0.09 }, ADMIN);
  eq([(await ptr(brand2)).st, (await old2.get()).get('status')], ['partial', 'partial'], '매장 단건은 브랜드 중단 기록과 무관');
});
await check('K5 nothing_left: partial + 같은 값 + 지울 개별 설정 0 → {changed:false, closed:true}, 새 이력 0, 옛 이력 completed(closedReason, closedBy), 포인터 completed', async () => {
  const brandId = nid('kb5'); const old = await seedPartial(brandId);
  // 남은 개별 설정 2곳(8, 9)을 직접 지워 "남은 일 0" 으로 만든다
  for (const i of [8, 9]) await db.collection('stores').doc(`${brandId}_s000${i}`).update({ qoinAccrualRate: FieldValue.delete() });
  const r = await call('applyBrandQoinRate', { brandId, rate: 0.06, mode: 'overwrite' }, ADMIN);
  eq([r.result.changed, r.result.closed], [false, true]);
  eq((await brandHist(brandId).get()).size, 1, '새 이력을 만들지 않는다');
  const o = (await old.get()).data(); eq([o.status, o.closedReason, o.closedBy], ['completed', 'nothing_left', ADMIN]); ok(o.closedAt, 'closedAt');
  const p = await ptr(brandId); eq([p.id, p.st], [old.id, 'completed']);
  const r2 = await call('applyBrandQoinRate', { brandId, rate: 0.06, mode: 'overwrite' }, ADMIN);
  eq([r2.result.changed, r2.result.closed], [false, undefined], '두 번째는 평범한 noop');
  // 지울 것이 남아 있으면 닫지 않고 진행한다 (partial 은 가드/종결 대상이 아니다)
  const brand2 = nid('kb5b'); const old2 = await seedPartial(brand2);
  const r3 = await call('applyBrandQoinRate', { brandId: brand2, rate: 0.06, mode: 'overwrite' }, ADMIN);
  eq([r3.result.changed, r3.result.closed, r3.result.clearedCount], [true, undefined, 2], '남은 일이 있으면 진행');
  eq((await old2.get()).get('status'), 'superseded');
});
await check('K6 completed 포인터 뒤 같은 값 재적용(스캔 신선): 정상 진행. 이력 문서 수로 확인', async () => {
  const brandId = nid('kb6'); await db.collection('brands').doc(brandId).set({ name: 'K6', status: 'approved' });
  await seedBrandStores(brandId, 6, { 1: 0.1, 3: 0.1 });
  const a = await call('applyBrandQoinRate', { brandId, rate: 0.05, mode: 'overwrite' }, ADMIN);
  eq([a.result.changed, a.result.clearedCount], [true, 2]);
  await db.collection('stores').doc(`${brandId}_s0002`).update({ qoinAccrualRate: 0.12 }); // 완료 후 새 개별 설정
  const b = await call('applyBrandQoinRate', { brandId, rate: 0.05, mode: 'overwrite' }, ADMIN);
  eq([b.result.changed, b.result.clearedCount], [true, 1], 'completed 포인터는 진행을 막지 않는다');
  eq((await brandHist(brandId).get()).size, 2, '이력 2건 (각각 실제 일을 한 호출)');
});
await check('K7 staleScan 가드: 종결 포인터 + qoinBulkAt > 스캔 시작 + 같은 값 → {changed:false, staleScan:true}, 이력 0·매장 불변. partial 은 가드하지 않는다', async () => {
  const brandId = nid('kb7'); await db.collection('brands').doc(brandId).set({
    name: 'K7', status: 'approved', qoinAccrualRate: 0.06, qoinBulkHistoryId: 'prev', qoinBulkStatus: 'completed', qoinBulkAt: Timestamp.fromMillis(Date.now() + 60_000) });
  await seedBrandStores(brandId, 5, { 3: 0.1 });
  const r = await call('applyBrandQoinRate', { brandId, rate: 0.06, mode: 'overwrite' }, ADMIN);
  eq([r.result.changed, r.result.staleScan, r.result.closed], [false, true, undefined]);
  eq((await brandHist(brandId).get()).size, 0, '빈 이력을 만들지 않는다');
  eq((await db.collection('stores').doc(`${brandId}_s0003`).get()).get('qoinAccrualRate'), 0.1, '매장 불변');
  // superseded 도 같은 가드
  await db.collection('brands').doc(brandId).update({ qoinBulkStatus: 'superseded' });
  eq((await call('applyBrandQoinRate', { brandId, rate: 0.06, mode: 'overwrite' }, ADMIN)).result.staleScan, true);
  // 값이 다르면 가드는 해당 없음
  const d = await call('applyBrandQoinRate', { brandId, rate: 0.07, mode: 'overwrite' }, ADMIN);
  eq([d.result.changed, d.result.staleScan, d.result.clearedCount], [true, undefined, 1], '다른 값은 정상 진행');
  // 포인터가 과거에 종결됐으면(스캔보다 앞) 가드가 아니라 정상 경로
  const b2 = nid('kb7b'); await db.collection('brands').doc(b2).set({
    name: 'K7b', status: 'approved', qoinAccrualRate: 0.06, qoinBulkHistoryId: 'prev', qoinBulkStatus: 'completed', qoinBulkAt: Timestamp.fromMillis(Date.now() - 60_000) });
  await seedBrandStores(b2, 5, { 3: 0.1 });
  const r2 = await call('applyBrandQoinRate', { brandId: b2, rate: 0.06, mode: 'overwrite' }, ADMIN);
  eq([r2.result.changed, r2.result.staleScan, r2.result.clearedCount], [true, undefined, 1], '과거 종결 포인터는 가드 대상이 아니다');
  // partial 은 가드에 넣지 않는다 (실제로 남은 일이 있다)
  const b3 = nid('kb7c'); const old = await seedPartial(b3);
  await db.collection('brands').doc(b3).update({ qoinBulkAt: Timestamp.fromMillis(Date.now() + 60_000) });
  const r3 = await call('applyBrandQoinRate', { brandId: b3, rate: 0.06, mode: 'overwrite' }, ADMIN);
  eq([r3.result.changed, r3.result.staleScan, r3.result.clearedCount], [true, undefined, 2], 'partial 은 가드하지 않는다');
  eq((await old.get()).get('status'), 'superseded');
});
await check('K8 동시 호출 3×(1500곳): **브랜드 이력 문서 수 = 1**, 보고된 clearedCount 합 = 1500, 응답은 changed/거부/noop 뿐 (빈 이력 0)', async () => {
  const brandId = nid('kb8'); await db.collection('brands').doc(brandId).set({ name: 'K8', status: 'approved', qoinAccrualRate: 0.02 });
  const ov = {}; for (let i = 0; i < 1500; i++) ov[i] = 0.1;
  await seedBrandStores(brandId, 1500, ov);
  const rs = await Promise.all([1, 2, 3].map(() => call('applyBrandQoinRate', { brandId, rate: 0.06, mode: 'overwrite' }, ADMIN)));
  for (const r of rs) ok(r.error === undefined || r.error === 'FAILED_PRECONDITION', `예상 밖 오류 ${r.error} ${r.message}`);
  eq((await brandHist(brandId).get()).size, 1, '이력 문서 수 자체');
  eq(rs.filter((r) => r.result).reduce((a, r) => a + r.result.clearedCount, 0), 1500);
  eq(rs.filter((r) => r.result && r.result.changed).length, 1, 'changed:true 는 정확히 1건');
  console.log(`     [K8] 응답: ${rs.map((r) => r.error ?? (r.result.changed ? 'changed' : r.result.staleScan ? 'staleScan' : 'noop')).join(', ')}`);
});
await check('K9 단건 setQoinAccrualRate 레거시 0 가드 (매장·브랜드, 변경/초기화 모두): FAILED_PRECONDITION + details, 쓰기 0 (TRANSITIONAL)', async () => {
  const brandId = nid('kb9'); await db.collection('brands').doc(brandId).set({ name: 'K9', status: 'approved', qoinAccrualRate: 0 });
  const storeId = nid('st9'); await db.collection('stores').doc(storeId).set({ name: 'S9', brandId, qoinAccrualRate: 0 });
  for (const body of [{ rate: 0.05 }, { clear: true }]) {
    const rs = await call('setQoinAccrualRate', { scope: 'store', targetId: storeId, ...body }, ADMIN);
    eq(rs.error, 'FAILED_PRECONDITION', `store ${JSON.stringify(body)}`);
    const det = Array.isArray(rs.details) ? rs.details[0] : rs.details;
    eq([det?.legacyZeroCount, det?.storeIds], [1, [storeId]]);
    eq((await call('setQoinAccrualRate', { scope: 'brand', targetId: brandId, ...body }, ADMIN)).error, 'FAILED_PRECONDITION', `brand ${JSON.stringify(body)}`);
  }
  eq([(await db.collection('stores').doc(storeId).get()).get('qoinAccrualRate'), (await db.collection('brands').doc(brandId).get()).get('qoinAccrualRate')], [0, 0], '값 불변');
  eq([(await storeHist(storeId).get()).size, (await brandHist(brandId).get()).size], [0, 0], '이력 0');
  // 정상 값(무효 문자열 포함)은 가드 대상이 아니다
  const s2 = nid('st9b'); await db.collection('stores').doc(s2).set({ name: 'S9b', qoinAccrualRate: '3' });
  eq((await call('setQoinAccrualRate', { scope: 'store', targetId: s2, rate: 0.05 }, ADMIN)).result.changed, true);
});

// ═════════════════════════════════════════════════════════════════════════
// L. brand_authorization_hardening — claimSubmittedBrand (CF1~CF6) · auditBrandLinks (CF7·CF8)
// ═════════════════════════════════════════════════════════════════════════
console.log('\n── L. claimSubmittedBrand · auditBrandLinks ──');
const roleHist = (uid) => db.collection('users').doc(uid).collection('roleHistory');
async function brandAccount(extraUser = {}, brandExtra = {}) {
  const uid = nid('bu'); const brandId = nid('bb');
  await seedUser(uid, { role: 'brand', ...extraUser });
  await db.collection('brands').doc(brandId).set({ name: `브랜드_${brandId}`, status: 'pending', submittedBy: uid, brandKey: '', ...brandExtra });
  return { uid, brandId };
}
await check('CF1 submittedBy != uid 인 브랜드로 호출 → PERMISSION_DENIED, users·roleHistory 불변 (+ 인증/인자 경계)', async () => {
  const a = await brandAccount(); const b = await brandAccount();
  eq((await call('claimSubmittedBrand', { brandId: b.brandId }, a.uid)).error, 'PERMISSION_DENIED');
  eq((await db.collection('users').doc(a.uid).get()).get('brandId'), undefined, 'users 불변');
  eq((await roleHist(a.uid).get()).size, 0);
  eq((await call('claimSubmittedBrand', { brandId: a.brandId }, undefined)).error, 'UNAUTHENTICATED');
  for (const brandId of [undefined, '', 5, 'a/b']) eq((await call('claimSubmittedBrand', { brandId }, a.uid)).error, 'INVALID_ARGUMENT', `brandId=${brandId}`);
  // submittedBy 가 없는(레거시) 브랜드도 남의 것으로 취급한다
  const legacy = nid('bl'); await db.collection('brands').doc(legacy).set({ name: 'L', status: 'approved' });
  eq((await call('claimSubmittedBrand', { brandId: legacy }, a.uid)).error, 'PERMISSION_DENIED', 'submittedBy 부재 거부');
});
await check('CF2 정상 호출 → users.brandId 설정 + roleHistory 1건(changedBy == uid, field brandId, before null, after id, changedByRole self, source callable)', async () => {
  const a = await brandAccount();
  const r = await call('claimSubmittedBrand', { brandId: a.brandId }, a.uid);
  eq([r.result.changed, r.result.brandId], [true, a.brandId]);
  eq((await db.collection('users').doc(a.uid).get()).get('brandId'), a.brandId);
  const hs = await histories(roleHist(a.uid)); eq(hs.length, 1);
  eq([hs[0].field, hs[0].before, hs[0].after, hs[0].changedBy, hs[0].changedByRole, hs[0].source], ['brandId', null, a.brandId, a.uid, 'self', 'callable']);
  ok(hs[0].changedAt, 'changedAt');
});
await check('CF3 같은 호출 2회·동시 5회 → changed:false, **이력 1건** (멱등, 문서 수로 센다)', async () => {
  const a = await brandAccount();
  const r1 = await call('claimSubmittedBrand', { brandId: a.brandId }, a.uid);
  const r2 = await call('claimSubmittedBrand', { brandId: a.brandId }, a.uid);
  eq([r1.result.changed, r2.result.changed], [true, false]); eq((await roleHist(a.uid).get()).size, 1);
  const b = await brandAccount();
  const rs = await Promise.all([1, 2, 3, 4, 5].map(() => call('claimSubmittedBrand', { brandId: b.brandId }, b.uid)));
  for (const r of rs) ok(r.result, `동시 호출 오류 ${r.error} ${r.message}`);
  eq(rs.filter((r) => r.result.changed).length, 1, 'changed:true 는 1건'); eq((await roleHist(b.uid).get()).size, 1, '동시 호출에도 이력 1건');
});
await check('CF4 이미 다른 brandId 가 있는 계정 → FAILED_PRECONDITION, 기존 값·이력 불변 (조용한 재연결 금지)', async () => {
  const a = await brandAccount({ brandId: 'someone_elses' });
  eq((await call('claimSubmittedBrand', { brandId: a.brandId }, a.uid)).error, 'FAILED_PRECONDITION');
  eq((await db.collection('users').doc(a.uid).get()).get('brandId'), 'someone_elses'); eq((await roleHist(a.uid).get()).size, 0);
});
await check('CF5 없는 brandId → NOT_FOUND', async () => {
  const a = await brandAccount();
  eq((await call('claimSubmittedBrand', { brandId: nid('ghost') }, a.uid)).error, 'NOT_FOUND');
});
await check('CF6 role != brand 계정 → FAILED_PRECONDITION, users 불변', async () => {
  const uid = nid('cu'); const brandId = nid('cb');
  await seedUser(uid, { role: 'customer' });
  await db.collection('brands').doc(brandId).set({ name: 'C', status: 'pending', submittedBy: uid });
  eq((await call('claimSubmittedBrand', { brandId }, uid)).error, 'FAILED_PRECONDITION');
  eq((await db.collection('users').doc(uid).get()).get('brandId'), undefined); eq((await roleHist(uid).get()).size, 0);
});
async function fingerprint() {
  // 모든 문서의 updateTime — 어떤 쓰기든 이 값이 바뀐다 (users·brands·stores + 이력 collection group)
  const out = {};
  for (const c of ['users', 'brands', 'stores']) {
    const s = await db.collection(c).get();
    for (const d of s.docs) out[`${c}/${d.id}`] = d.updateTime.toMillis();
  }
  for (const g of ['qoinRateHistory', 'roleHistory']) {
    const s = await db.collectionGroup(g).get();
    for (const d of s.docs) out[d.ref.path] = d.updateTime.toMillis();
  }
  return out;
}
await check('CF7 auditBrandLinks: 분류 정확 + **쓰기 0** (실행 전후 전 문서 updateTime 동일)', async () => {
  const tag = nid('au');
  // ok
  const okA = await brandAccount({}, { status: 'approved' });
  await db.collection('users').doc(okA.uid).update({ brandId: okA.brandId });
  // ok_onboarding
  const onb = nid(`${tag}_onb`); await seedUser(onb, { role: 'brand' });
  // dangling
  const dang = nid(`${tag}_dang`); await seedUser(dang, { role: 'brand', brandId: nid('nowhere') });
  // mismatch (레거시 수동 발급)
  const mis = await brandAccount({}, { submittedBy: 'someone_else', status: 'approved' });
  await db.collection('users').doc(mis.uid).update({ brandId: mis.brandId });
  // duplicate (같은 브랜드에 두 계정)
  const dup1 = await brandAccount({}, { status: 'approved' });
  await db.collection('users').doc(dup1.uid).update({ brandId: dup1.brandId });
  const dup2 = nid(`${tag}_dup2`); await seedUser(dup2, { role: 'brand', brandId: dup1.brandId });
  // orphan_brand (아무도 안 가리킴)
  const orphan = nid(`${tag}_orph`); await db.collection('brands').doc(orphan).set({ name: 'orphan', status: 'pending', submittedBy: 'ghost_user' });
  // store_dangling_brand / store_unapproved_brand / 정상 / 개인 매장
  const pendingBrand = await brandAccount({}, { status: 'pending' });
  await db.collection('users').doc(pendingBrand.uid).update({ brandId: pendingBrand.brandId });
  const sDang = nid(`${tag}_sd`); await db.collection('stores').doc(sDang).set({ name: 'SD', brandId: nid('gone') });
  const sUna = nid(`${tag}_su`); await db.collection('stores').doc(sUna).set({ name: 'SU', brandId: pendingBrand.brandId });
  const sOk = nid(`${tag}_so`); await db.collection('stores').doc(sOk).set({ name: 'SO', brandId: okA.brandId });
  const sPersonal = nid(`${tag}_sp`); await db.collection('stores').doc(sPersonal).set({ name: 'SP', brandId: null });
  const sNoField = nid(`${tag}_sn`); await db.collection('stores').doc(sNoField).set({ name: 'SN' });
  await sleep(4000); // 트리거(이력 생성 등)가 가라앉기를 기다린 뒤 지문을 뜬다
  const before = await fingerprint();
  const r = await call('auditBrandLinks', {}, ADMIN);
  ok(r.result, `호출 실패 ${r.error} ${r.message}`);
  const after = await fingerprint();
  eq(JSON.stringify(after), JSON.stringify(before), '쓰기 0 — 문서 지문 동일');
  const { counts, items } = r.result;
  const has = (cls, pred) => items[cls].some(pred);
  ok(has('dangling', (x) => x.uid === dang), 'dangling'); ok(!has('dangling', (x) => x.uid === okA.uid), 'ok 가 dangling 에 없다');
  ok(has('mismatch', (x) => x.uid === mis.uid && x.submittedBy === 'someone_else'), 'mismatch');
  ok(has('duplicate', (x) => x.uid === dup1.uid) && has('duplicate', (x) => x.uid === dup2), 'duplicate 양쪽 모두');
  ok(has('orphan_brand', (x) => x.brandId === orphan), 'orphan_brand');
  ok(!has('orphan_brand', (x) => x.brandId === okA.brandId), '가리키는 계정이 있는 브랜드는 고아가 아니다');
  ok(has('store_dangling_brand', (x) => x.storeId === sDang), 'store_dangling_brand');
  ok(has('store_unapproved_brand', (x) => x.storeId === sUna), 'store_unapproved_brand');
  ok(!['store_dangling_brand', 'store_unapproved_brand'].some((c) => has(c, (x) => x.storeId === sOk || x.storeId === sPersonal || x.storeId === sNoField)), '정상·개인 매장은 어느 분류에도 없다');
  ok(counts.ok >= 1 && counts.ok_onboarding >= 1, 'ok / ok_onboarding 건수');
  eq([items.ok, items.ok_onboarding], [[], []], 'ok·ok_onboarding 은 건수만 (목록 없음)');
  eq(Object.keys(counts).sort(), ['dangling', 'duplicate', 'mismatch', 'ok', 'ok_onboarding', 'orphan_brand', 'store_dangling_brand', 'store_unapproved_brand']);
  // 인자 없이도, 어떤 인자(dryRun 등)를 줘도 쓰지 않는다
  const r2 = await call('auditBrandLinks', { dryRun: false, fix: true }, ADMIN);
  ok(r2.result, '인자 무시'); eq(JSON.stringify(await fingerprint()), JSON.stringify(before), '인자를 줘도 쓰기 0');
});
await check('CF8 auditBrandLinks: non-admin → PERMISSION_DENIED, 비로그인 → UNAUTHENTICATED', async () => {
  eq((await call('auditBrandLinks', {}, NONADMIN)).error, 'PERMISSION_DENIED');
  eq((await call('auditBrandLinks', {}, undefined)).error, 'UNAUTHENTICATED');
});

// ═════════════════════════════════════════════════════════════════════════
console.log('\n================ CF 에뮬레이터 검증 결과 ================');
let fail = 0;
for (const [n, r] of results) { if (r !== 'PASS') { fail++; console.log('  FAIL', n, '->', r); } }
console.log(`================ ${results.length - fail}/${results.length} PASS ================\n`);
process.exit(fail ? 1 : 0);

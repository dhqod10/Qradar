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

/** ready → completed 로 수정(트리거는 onDocumentUpdated). 적립 문서(earn_*)가 생기면 반환, 없으면 null. */
async function completeOrder({ orderId, uid, storeId, brandId, total = 10000, expectLedger = true }) {
  await db.collection('orders').doc(orderId).set({
    userId: uid, storeId, storeName: '테스트매장', brandId: brandId ?? null, totalPrice: total, status: 'ready',
  });
  await sleep(250);
  await db.collection('orders').doc(orderId).update({ status: 'completed' });
  if (expectLedger) return until(async () => {
    const s = await ledger(uid, `earn_${orderId}`); return s.exists ? s : null; });
  await sleep(3500);
  const s = await ledger(uid, `earn_${orderId}`);
  return s.exists ? s : null;
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
  if (body.error) return { error: body.error.status, message: body.error.message };
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
for (const row of table.resolve) {
  await check(`CH-${row.id} resolve store=${row.store} brand=${row.brand} global=${row.global}`, async () => {
    const uid = nid('u'); await seedUser(uid);
    const storeId = nid('st'); const hasBrand = row.brand !== 'absent';
    const brandId = hasBrand ? nid('br') : null;
    await setGlobal(row.global === 'absent' ? {} : { accrualRate: decode(row.global) });
    const storeDoc = { name: 'S', ownerId: 'x', status: 'approved' };
    const sv = decode(row.store); if (sv !== undefined) storeDoc.qoinAccrualRate = sv;
    await db.collection('stores').doc(storeId).set(storeDoc);
    if (hasBrand) await db.collection('brands').doc(brandId).set({ name: 'B', status: 'approved', qoinAccrualRate: decode(row.brand) });
    const orderId = nid('o');
    const exp = row.expect;
    const led = await completeOrder({ orderId, uid, storeId, brandId, total: 10000, expectLedger: !!(exp.rate && exp.rate > 0) });
    if (exp.invalid || exp.rate === 0) { ok(led === null, '적립되면 안 됨'); return; }
    ok(led, '적립 문서 없음');
    eq(led.get('accrualRate'), exp.rate, 'accrualRate');
    eq(led.get('accrualRateSource'), exp.source, 'accrualRateSource');
    eq(led.get('amount'), Math.floor(10000 * exp.rate), 'amount');
  });
}

// ═════════════════════════════════════════════════════════════════════════
// B. 회수 / kill switch / 엣지
// ═════════════════════════════════════════════════════════════════════════
console.log('\n── B. 회수 · kill switch · 엣지 ──');
await check('CH11 매장 0% 로 바꾼 뒤 환불 → 회수는 정상 동작 (돈이 새지 않는다) + CH18 source 상속', async () => {
  const uid = nid('u'); await seedUser(uid);
  const storeId = nid('st'); await setGlobal({ accrualRate: 0.03 });
  await db.collection('stores').doc(storeId).set({ name: 'S', qoinAccrualRate: 0.05 });
  const orderId = nid('o');
  const earn = await completeOrder({ orderId, uid, storeId });
  ok(earn, 'earn 없음'); eq(earn.get('amount'), 500, 'earn amount'); eq(earn.get('accrualRateSource'), 'store');
  await db.collection('stores').doc(storeId).update({ qoinAccrualRate: 0 }); // 이후 적립 중단
  const cb = await refundOrder(orderId, uid);
  ok(cb, '회수 문서 없음 — 0% 가 회수까지 막았다');
  eq(cb.get('amount'), -500, 'clawback amount'); eq(cb.get('accrualRateSource'), 'store', 'clawback source 상속');
  eq((await db.collection('users').doc(uid).get()).get('qoinBalance'), 0, '잔액');
  // 같은 매장의 새 주문은 적립되지 않는다
  const o2 = nid('o'); const none = await completeOrder({ orderId: o2, uid, storeId, expectLedger: false });
  ok(none === null, '0% 매장에서 적립됨');
});
await check('CH11b 브랜드 0% 후 환불 → 회수 정상', async () => {
  const uid = nid('u'); await seedUser(uid);
  const storeId = nid('st'); const brandId = nid('br'); await setGlobal({ accrualRate: 0.03 });
  await db.collection('stores').doc(storeId).set({ name: 'S', brandId });
  await db.collection('brands').doc(brandId).set({ name: 'B', qoinAccrualRate: 0.1 });
  const orderId = nid('o');
  const earn = await completeOrder({ orderId, uid, storeId, brandId });
  ok(earn && earn.get('amount') === 1000 && earn.get('accrualRateSource') === 'brand', 'earn');
  await db.collection('brands').doc(brandId).update({ qoinAccrualRate: 0 });
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
  const led = await completeOrder({ orderId: nid('o'), uid, storeId: '', expectLedger: false });
  ok(led === null, '적립됨');
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
  const led = await completeOrder({ orderId: nid('o'), uid, storeId, brandId });
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
  await check('CH16 earn(브랜드 소속): config1 + store1 + brand1 + 가드1 + users1 = 5 read, 계층 읽기는 1 라운드트립', async () => {
    const uid = nid('u'); await seedUser(uid); await setGlobal({ accrualRate: 0.03 });
    const storeId = nid('st'); const brandId = nid('br');
    await db.collection('stores').doc(storeId).set({ name: 'S', brandId });
    await db.collection('brands').doc(brandId).set({ name: 'B', qoinAccrualRate: 0.05 });
    const c = await measure('earn (브랜드 소속)', nid('o'), 'ready', 'completed', { userId: uid, storeId, storeName: 'S', brandId, totalPrice: 10000 });
    eq(c.docs, 5, 'earn 문서 read'); eq(c.queries, 0, '쿼리');
  });
  await check('CH16 earn(개인 매장): config1 + store1 + 가드1 + users1 = 4 read', async () => {
    const uid = nid('u'); await seedUser(uid);
    const storeId = nid('st'); await db.collection('stores').doc(storeId).set({ name: 'S' });
    const c = await measure('earn (개인 매장)', nid('o'), 'ready', 'completed', { userId: uid, storeId, storeName: 'S', totalPrice: 10000 });
    eq(c.docs, 4, 'earn(개인) 문서 read');
  });
  await check('CH16 clawback: config1 + earn1 + 가드1 + users1 = 4 read (계층 read 0, 1차와 동일)', async () => {
    const uid = nid('u'); await seedUser(uid);
    const storeId = nid('st'); await db.collection('stores').doc(storeId).set({ name: 'S' });
    const orderId = nid('o');
    await measure('earn 선행', orderId, 'ready', 'completed', { userId: uid, storeId, storeName: 'S', totalPrice: 10000 });
    const c = await measure('clawback', orderId, 'completed', 'refunded', { userId: uid, storeId, storeName: 'S', totalPrice: 10000 });
    eq(c.docs, 4, 'clawback 문서 read');
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
  for (const rate of [0.5, 0.0005, -1, '3', 1, 0.0305, null]) {
    const r = await call('setQoinAccrualRate', { scope: 'store', targetId: storeId, rate }, ADMIN);
    eq(r.error, 'INVALID_ARGUMENT', `rate=${JSON.stringify(rate)}`);
  }
  eq((await call('setQoinAccrualRate', { scope: 'store', targetId: storeId }, ADMIN)).error, 'INVALID_ARGUMENT', 'rate/clear 둘 다 없음');
  eq((await call('setQoinAccrualRate', { scope: 'store', targetId: storeId, rate: 0.05, clear: true }, ADMIN)).error, 'INVALID_ARGUMENT', '둘 다 있음');
  eq((await call('setQoinAccrualRate', { scope: 'global', rate: 0 }, ADMIN)).error, 'INVALID_ARGUMENT', '전역 0');
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
  // 0 (적립 안 함) / clear
  r = await call('setQoinAccrualRate', { scope: 'store', targetId: storeId, rate: 0 }, ADMIN);
  eq(r.result.after, 0); eq((await db.collection('stores').doc(storeId).get()).get('qoinAccrualRate'), 0);
  r = await call('setQoinAccrualRate', { scope: 'store', targetId: storeId, clear: true }, ADMIN);
  eq(r.result.before, 0); eq(r.result.after, null);
  eq((await db.collection('stores').doc(storeId).get()).get('qoinAccrualRate'), undefined, '필드 삭제(상속)');
  hs = await histories(storeHist(storeId));
  ok(hs.some((h) => h.op === 'clear' && h.before === 0 && h.after === null), 'clear 이력');
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
    const x = (await histories(globalHist())).filter((h) => h.field === 'enabled' && h.source === 'direct'); return x.length ? x : null; });
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
async function seedBrandStores(brandId, n, overrides /* {index: rate} */) {
  const col = db.collection('stores');
  let batch = db.batch(); let c = 0;
  for (let i = 0; i < n; i++) {
    const d = { name: `${brandId}-${i}`, brandId, status: 'approved' };
    if (overrides[i] !== undefined) d.qoinAccrualRate = overrides[i];
    batch.set(col.doc(`${brandId}_s${String(i).padStart(4, '0')}`), d);
    if (++c % 400 === 0) { await batch.commit(); batch = db.batch(); }
  }
  await batch.commit();
}
await check('CH22 일괄 preserve: 브랜드 값만 1 write, 개별 설정 보존, 이력 1건(completed, 수치 정확)', async () => {
  const brandId = nid('brp'); await db.collection('brands').doc(brandId).set({ name: 'P브랜드', status: 'approved' });
  await seedBrandStores(brandId, 10, { 2: 0.1, 5: 0, 7: 0.02 });
  const r = await call('applyBrandQoinRate', { brandId, rate: 0.05, mode: 'preserve', reason: '일괄' }, ADMIN);
  eq([r.result.status, r.result.affectedCount, r.result.clearedCount, r.result.preservedCount, r.result.totalCount], ['completed', 7, 0, 3, 3]);
  eq((await db.collection('brands').doc(brandId).get()).get('qoinAccrualRate'), 0.05);
  const snaps = await db.collection('stores').where('brandId', '==', brandId).get();
  const withOv = snaps.docs.filter((d) => d.get('qoinAccrualRate') !== undefined).map((d) => d.get('qoinAccrualRate')).sort();
  eq(withOv, [0, 0.02, 0.1], '개별 설정 보존');
  const hs = await histories(brandHist(brandId)); eq(hs.length, 1, '이력 1건');
  const h = hs[0];
  eq([h.op, h.bulkMode, h.status, h.affectedCount, h.clearedCount, h.preservedCount, h.before, h.after, h.changedBy, h.reason, h.source, h.targetName],
     ['bulkApply', 'preserve', 'completed', 7, 0, 3, null, 0.05, ADMIN, '일괄', 'bulk', 'P브랜드']);
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
  const ov = {}; for (let i = 0; i < 600; i += 3) ov[i] = i % 2 === 0 ? 0.1 : 0; // 200곳
  await seedBrandStores(brandId, 600, ov);
  const r = await call('applyBrandQoinRate', { brandId, rate: 0.06, mode: 'overwrite' }, ADMIN);
  eq([r.result.status, r.result.affectedCount, r.result.clearedCount, r.result.totalCount], ['completed', 600, 200, 200]);
  const snaps = await db.collection('stores').where('brandId', '==', brandId).get();
  eq(snaps.size, 600); eq(snaps.docs.filter((d) => d.get('qoinAccrualRate') !== undefined).length, 0, '개별 설정 전부 초기화');
  eq((await db.collection('brands').doc(brandId).get()).get('qoinAccrualRate'), 0.06);
  const hs = await histories(brandHist(brandId)); eq(hs.length, 1, '이력 1건');
  eq([hs[0].before, hs[0].after, hs[0].status, hs[0].processedCount, hs[0].bulkMode], [0.02, 0.06, 'completed', 200, 'overwrite']);
});
await check('CH24 중단 후 resumeHistoryId 재개: 멱등, 중복 이력 없음, completed 마감', async () => {
  const brandId = nid('brr'); await db.collection('brands').doc(brandId).set({ name: 'R', status: 'approved', qoinAccrualRate: 0.06 });
  await seedBrandStores(brandId, 20, { 1: 0.1, 4: 0.1, 8: 0, 9: 0.1 });
  // 중단 상황 모사: 브랜드 값은 이미 쓰였고, 이력은 partial(processed 2/4), 일부 매장만 지워진 상태
  await db.collection('stores').doc(`${brandId}_s0001`).update({ qoinAccrualRate: FieldValue.delete() });
  await db.collection('stores').doc(`${brandId}_s0004`).update({ qoinAccrualRate: FieldValue.delete() });
  const hRef = brandHist(brandId).doc();
  await hRef.set({ scope: 'brand', targetId: brandId, targetName: 'R', field: 'accrualRate', before: 0.02, after: 0.06,
    changedBy: ADMIN, changedByRole: 'admin', changedAt: FieldValue.serverTimestamp(), reason: null, source: 'bulk', op: 'bulkApply',
    bulkMode: 'overwrite', totalCount: 4, affectedCount: 0, clearedCount: 0, preservedCount: 0, processedCount: 2, status: 'partial',
    lastProgressAt: FieldValue.serverTimestamp() });
  const r = await call('applyBrandQoinRate', { brandId, mode: 'overwrite', resumeHistoryId: hRef.id }, ADMIN);
  eq([r.result.status, r.result.clearedCount, r.result.processedCount], ['completed', 4, 4]);
  const snaps = await db.collection('stores').where('brandId', '==', brandId).get();
  eq(snaps.docs.filter((d) => d.get('qoinAccrualRate') !== undefined).length, 0);
  eq((await brandHist(brandId).get()).size, 1, '이력은 여전히 1건');
  eq((await hRef.get()).get('status'), 'completed');
  eq((await db.collection('brands').doc(brandId).get()).get('qoinAccrualRate'), 0.06, '브랜드 값 불변');
  // 완료된 이력 재개 → failed-precondition, 방금 갱신된 in_progress 재개 → failed-precondition
  eq((await call('applyBrandQoinRate', { brandId, mode: 'overwrite', resumeHistoryId: hRef.id }, ADMIN)).error, 'FAILED_PRECONDITION');
  await hRef.update({ status: 'in_progress', lastProgressAt: FieldValue.serverTimestamp() });
  eq((await call('applyBrandQoinRate', { brandId, mode: 'overwrite', resumeHistoryId: hRef.id }, ADMIN)).error, 'FAILED_PRECONDITION', '진행 중 이력은 재개 불가');
  eq((await call('applyBrandQoinRate', { brandId, mode: 'overwrite', resumeHistoryId: 'nope' }, ADMIN)).error, 'NOT_FOUND');
  // 동시 실행 방지
  eq((await call('applyBrandQoinRate', { brandId, rate: 0.01, mode: 'overwrite' }, ADMIN)).error, 'FAILED_PRECONDITION', '진행 중 일괄 적용이 있으면 새 시작 거부');
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
console.log('\n================ CF 에뮬레이터 검증 결과 ================');
let fail = 0;
for (const [n, r] of results) { if (r !== 'PASS') { fail++; console.log('  FAIL', n, '->', r); } }
console.log(`================ ${results.length - fail}/${results.length} PASS ================\n`);
process.exit(fail ? 1 : 0);

import { initializeTestEnvironment, assertFails, assertSucceeds }
  from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, increment } from 'firebase/firestore';
import fs from 'fs';

const CUSTOMER = 'dUFcFv71FzVA4feodWnxv3k0MKF3';
const OWNER    = '8gnNH8NAJNhu8sxomEkX38CMapL2';

const env = await initializeTestEnvironment({
  projectId: 'order-app-5957e',
  firestore: { host: '127.0.0.1', port: 8137, rules: fs.readFileSync('firestore.rules', 'utf8') },
});

// 시드: 규칙 우회로 두 사용자 doc 생성
await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'users', CUSTOMER), { uid: CUSTOMER, role: 'customer', displayName: 'dhqod13' });
  await setDoc(doc(db, 'users', OWNER),    { uid: OWNER,    role: 'owner',    displayName: 'owner'   });
});

const asCustomer = env.authenticatedContext(CUSTOMER).firestore();
const results = [];
const run = async (name, expect, fn) => {
  try { await (expect === 'allow' ? assertSucceeds(fn()) : assertFails(fn())); results.push([name, expect, 'PASS']); }
  catch (e) { results.push([name, expect, 'FAIL: ' + (e.message || e).slice(0, 110)]); }
};

// ── 핵심: 타인 uid 의 notificationSettings 변경 ──────────────────────────
await run('타인 doc notificationSettings update', 'deny', () =>
  updateDoc(doc(asCustomer, 'users', OWNER), { 'notificationSettings.newOrder': false }));

// ── 본인 doc 의 notificationSettings 변경 ───────────────────────────────
await run('본인 doc notificationSettings update', 'allow', () =>
  updateDoc(doc(asCustomer, 'users', CUSTOMER), { 'notificationSettings.orderProgress': true }));

await run('본인 doc notificationSettings 2키 동시', 'allow', () =>
  updateDoc(doc(asCustomer, 'users', CUSTOMER), {
    'notificationSettings.orderProgress': false, 'notificationSettings.pickupComplete': true }));

// ── 회귀: 화이트리스트 밖 필드 ──────────────────────────────────────────
await run('본인 doc uid 변경 (immutable)', 'deny', () =>
  updateDoc(doc(asCustomer, 'users', CUSTOMER), { uid: 'hacked' }));

await run('본인 doc 임의 필드 추가', 'deny', () =>
  updateDoc(doc(asCustomer, 'users', CUSTOMER), { isAdmin: true }));

await run('타인 doc read', 'deny', () =>
  getDoc(doc(asCustomer, 'users', OWNER)));

await run('본인 doc read', 'allow', () =>
  getDoc(doc(asCustomer, 'users', CUSTOMER)));

// ── 회귀: fcmToken (T11 경로) ──────────────────────────────────────────
await run('본인 doc fcmToken update', 'allow', () =>
  updateDoc(doc(asCustomer, 'users', CUSTOMER), { fcmToken: 'tok123' }));

// ── sub-phase 4: laterCount ────────────────────────────────────────────
await run('본인 doc laterCount increment', 'allow', () =>
  updateDoc(doc(asCustomer, 'users', CUSTOMER), { notificationPermissionLaterCount: increment(1) }));

await run('본인 doc prompted=true update', 'allow', () =>
  updateDoc(doc(asCustomer, 'users', CUSTOMER), { notificationPermissionPrompted: true }));

await run('타인 doc laterCount increment', 'deny', () =>
  updateDoc(doc(asCustomer, 'users', OWNER), { notificationPermissionLaterCount: increment(1) }));

await run('본인 doc laterCount + role 무단 변경 동반', 'deny', () =>
  updateDoc(doc(asCustomer, 'users', CUSTOMER), {
    notificationPermissionLaterCount: increment(1), role: 'admin' }));

console.log('\n================ Rules 검증 결과 ================');
let fail = 0;
for (const [n, e, r] of results) {
  if (!r.startsWith('PASS')) fail++;
  console.log(`${r.startsWith('PASS') ? '  PASS' : '  FAIL'}  [${e.padEnd(5)}] ${n}${r.startsWith('PASS') ? '' : '  → ' + r}`);
}
console.log(`================ ${results.length - fail}/${results.length} PASS ================\n`);
await env.cleanup();
process.exit(fail ? 1 : 0);

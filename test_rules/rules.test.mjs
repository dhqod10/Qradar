import { initializeTestEnvironment, assertFails, assertSucceeds }
  from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, increment, collection, query, where, orderBy, limit, getDocs, Timestamp, serverTimestamp, deleteDoc, deleteField } from 'firebase/firestore';
import fs from 'fs';

const CUSTOMER = 'dUFcFv71FzVA4feodWnxv3k0MKF3';
const OWNER    = '8gnNH8NAJNhu8sxomEkX38CMapL2';
const OTHER    = 'otherOwnerUid000000000000000000';

// owner_sales 시드용
const S_A = 'store_a_approved';   // OWNER 소유, 승인됨
const S_B = 'store_b_other';      // 타인 소유
const S_P = 'store_p_pending';    // OWNER 소유, 승인 대기
const DAY_START = new Date('2026-10-21T00:00:00+09:00');
const DAY_END   = new Date('2026-10-22T00:00:00+09:00');

const env = await initializeTestEnvironment({
  projectId: 'order-app-5957e',
  firestore: { host: '127.0.0.1', port: 8137, rules: fs.readFileSync('firestore.rules', 'utf8') },
});

// 시드: 규칙 우회로 두 사용자 doc 생성
await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'users', CUSTOMER), { uid: CUSTOMER, role: 'customer', displayName: 'dhqod13' });
  await setDoc(doc(db, 'users', OWNER),    { uid: OWNER,    role: 'owner',    displayName: 'owner'   });

  // owner_sales: stores 3개 + orders 2개
  await setDoc(doc(db, 'stores', S_A), { ownerId: OWNER, name: 'A', status: 'approved' });
  await setDoc(doc(db, 'stores', S_B), { ownerId: OTHER, name: 'B', status: 'approved' });
  await setDoc(doc(db, 'stores', S_P), { ownerId: OWNER, name: 'P', status: 'pending'  });
  await setDoc(doc(db, 'orders', 'o_a1'), {
    storeId: S_A, userId: CUSTOMER, status: 'completed', totalPrice: 10000,
    createdAt: Timestamp.fromDate(new Date('2026-10-21T10:00:00+09:00')),
  });
  // store_reviews: 평가 자격 검증용 주문
  await setDoc(doc(db, 'orders', 'o_done'),  { storeId: S_A, userId: CUSTOMER, status: 'completed', totalPrice: 4500 });
  await setDoc(doc(db, 'orders', 'o_paid'),  { storeId: S_A, userId: CUSTOMER, status: 'paid',      totalPrice: 4500 });
  await setDoc(doc(db, 'orders', 'o_other'), { storeId: S_A, userId: OTHER,    status: 'completed', totalPrice: 4500 });
  await setDoc(doc(db, 'orders', 'o_b1'), {
    storeId: S_B, userId: CUSTOMER, status: 'completed', totalPrice: 20000,
    createdAt: Timestamp.fromDate(new Date('2026-10-21T11:00:00+09:00')),
  });
});

/// 앱과 동일한 형태의 기간 쿼리 (storeId == + createdAt 범위 + orderBy + limit)
const periodQuery = (db, storeId) => query(
  collection(db, 'orders'),
  where('storeId', '==', storeId),
  where('createdAt', '>=', Timestamp.fromDate(DAY_START)),
  where('createdAt', '<', Timestamp.fromDate(DAY_END)),
  orderBy('createdAt', 'desc'),
  limit(1000),
);

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

// ── owner_sales: 기간 쿼리 권한 (R13~R18) ─────────────────────────────
const asOwner = env.authenticatedContext(OWNER).firestore();
const asAnon  = env.unauthenticatedContext().firestore();

await run('R13 점주가 자기 매장(승인됨) 기간 쿼리', 'allow', () =>
  getDocs(periodQuery(asOwner, S_A)));

await run('R14 점주가 타 매장 기간 쿼리', 'deny', () =>
  getDocs(periodQuery(asOwner, S_B)));

await run('R15 storeId 조건 없이 createdAt 범위만 쿼리', 'deny', () =>
  getDocs(query(collection(asOwner, 'orders'),
    where('createdAt', '>=', Timestamp.fromDate(DAY_START)),
    where('createdAt', '<', Timestamp.fromDate(DAY_END)),
    orderBy('createdAt', 'desc'), limit(1000))));

await run('R16 고객이 타인 매장 기간 쿼리', 'deny', () =>
  getDocs(periodQuery(asCustomer, S_A)));

await run('R17 점주가 pending 매장 기간 쿼리', 'allow', () =>
  getDocs(periodQuery(asOwner, S_P)));

await run('R18 비로그인 기간 쿼리', 'deny', () =>
  getDocs(periodQuery(asAnon, S_A)));


// ── store_reviews: reviews Rules (RV1~RV20) ──────────────────────────
const RID = `${S_A}_${CUSTOMER}`;
const reviewBody = (o = {}) => ({
  storeId: S_A, userId: CUSTOMER, orderId: 'o_done',
  grade: 'S', score: 4, createdAt: serverTimestamp(), ...o,
});
const rv = (db, id) => doc(db, 'reviews', id);

await run('RV2 grade/score 불일치 (S 인데 score 1)', 'deny', () =>
  setDoc(rv(asCustomer, RID), reviewBody({ score: 1 })));
await run('RV2b score=4 인데 grade=C', 'deny', () =>
  setDoc(rv(asCustomer, RID), reviewBody({ grade: 'C' })));
await run('RV3 문서 ID 가 {storeId}_{uid} 가 아님', 'deny', () =>
  setDoc(rv(asCustomer, 'auto_generated_id'), reviewBody()));
await run('RV4 orderId 가 paid (completed 아님)', 'deny', () =>
  setDoc(rv(asCustomer, RID), reviewBody({ orderId: 'o_paid' })));
await run('RV5 타인 주문', 'deny', () =>
  setDoc(rv(asCustomer, RID), reviewBody({ orderId: 'o_other' })));
await run('RV6 storeId=S_B 인데 orderId 는 S_A 주문', 'deny', () =>
  setDoc(rv(asCustomer, `${S_B}_${CUSTOMER}`), reviewBody({ storeId: S_B })));
await run('RV7 comment 301자', 'deny', () =>
  setDoc(rv(asCustomer, RID), reviewBody({ comment: 'a'.repeat(301) })));
await run('RV8 createdAt 클라이언트 고정 Timestamp', 'deny', () =>
  setDoc(rv(asCustomer, RID), reviewBody({ createdAt: Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')) })));
await run('RV9 허용 외 필드(adminNote)', 'deny', () =>
  setDoc(rv(asCustomer, RID), reviewBody({ adminNote: 'x' })));
await run('RV9b userId 가 타인', 'deny', () =>
  setDoc(rv(asCustomer, RID), reviewBody({ userId: OTHER })));
await run('RV1b comment 300자 경계', 'allow', () =>
  setDoc(rv(asCustomer, `${S_A}_${CUSTOMER}`), reviewBody({ comment: 'a'.repeat(300) })));
// 이후 update 시나리오용: 위 문서가 생성된 상태
await run('RV10 본인 update (grade/score/updatedAt)', 'allow', () =>
  updateDoc(rv(asCustomer, RID), { grade: 'B', score: 2, updatedAt: serverTimestamp() }));
await run('RV10b 본인 update 코멘트 제거 (deleteField 대체: comment 빈 문자열)', 'allow', () =>
  updateDoc(rv(asCustomer, RID), { comment: '', updatedAt: serverTimestamp() }));
await run('RV10f 본인 update 코멘트 필드 삭제 (deleteField)', 'allow', () =>
  updateDoc(rv(asCustomer, RID), { comment: deleteField(), updatedAt: serverTimestamp() }));
await run('RV10c update 시 updatedAt 누락(클라이언트 값)', 'deny', () =>
  updateDoc(rv(asCustomer, RID), { grade: 'A', score: 3, updatedAt: Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')) }));
await run('RV10d update 시 grade/score 불일치', 'deny', () =>
  updateDoc(rv(asCustomer, RID), { grade: 'A', score: 1, updatedAt: serverTimestamp() }));
await run('RV10e update 시 orderId 를 paid 주문으로', 'deny', () =>
  updateDoc(rv(asCustomer, RID), { orderId: 'o_paid', updatedAt: serverTimestamp() }));
await run('RV11 storeId 변경 시도', 'deny', () =>
  updateDoc(rv(asCustomer, RID), { storeId: S_B, updatedAt: serverTimestamp() }));
await run('RV12 createdAt 변경 시도', 'deny', () =>
  updateDoc(rv(asCustomer, RID), { createdAt: serverTimestamp(), updatedAt: serverTimestamp() }));
await run('RV13 OWNER 가 CUSTOMER 리뷰 update', 'deny', () =>
  updateDoc(rv(asOwner, RID), { grade: 'C', score: 1, updatedAt: serverTimestamp() }));
await run('RV14 OWNER 가 CUSTOMER 리뷰 delete', 'deny', () =>
  deleteDoc(rv(asOwner, RID)));
await run('RV16 OWNER 가 stores.averageScore 직접 update', 'deny', () =>
  updateDoc(doc(asOwner, 'stores', S_A), { averageScore: 4.0 }));
await run('RV16b OWNER 가 stores.reviewCount 직접 update', 'deny', () =>
  updateDoc(doc(asOwner, 'stores', S_A), { reviewCount: 999 }));
await run('RV17 CUSTOMER 가 stores.reviewCount 직접 update', 'deny', () =>
  updateDoc(doc(asCustomer, 'stores', S_A), { reviewCount: 999 }));
await run('RV17b CUSTOMER 가 stores.averageScore 직접 update', 'deny', () =>
  updateDoc(doc(asCustomer, 'stores', S_A), { averageScore: 4.0 }));
await run('RV18 비로그인 read', 'deny', () =>
  getDoc(rv(asAnon, RID)));
await run('RV19 로그인 사용자가 타인 리뷰 read', 'allow', () =>
  getDoc(rv(asOwner, RID)));
await run('RV20 매장 리뷰 목록 쿼리 (storeId + createdAt desc + limit 50)', 'allow', () =>
  getDocs(query(collection(asCustomer, 'reviews'),
    where('storeId', '==', S_A), orderBy('createdAt', 'desc'), limit(50))));
await run('RV15 CUSTOMER 가 본인 리뷰 delete', 'allow', () =>
  deleteDoc(rv(asCustomer, RID)));
await run('RV1 CUSTOMER 정상 create (completed 주문, S, serverTimestamp)', 'allow', () =>
  setDoc(rv(asCustomer, RID), reviewBody()));

// ══ Qoin (docs/tasks/qoin/spec.md §13.1) ══════════════════════════════════
const ADMIN = 'adminUid00000000000000000000000';
await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'users', ADMIN), { uid: ADMIN, role: 'admin', displayName: 'admin' });
  await updateDoc(doc(db, 'users', CUSTOMER), { qoinBalance: 500 });
  await setDoc(doc(db, 'users', CUSTOMER, 'qoinTransactions', 'earn_o1'), {
    txId: 'earn_o1', type: 'earn', amount: 500, balanceAfter: 500, orderId: 'o1',
    storeId: S_A, storeName: 'A', orderTotalPrice: 10000, accrualRate: 0.05,
    createdAt: Timestamp.fromDate(new Date('2026-10-21T10:00:00+09:00')),
  });
  await setDoc(doc(db, 'config', 'qoin'), { accrualRate: 0.03, enabled: true });
});
const asAdmin = env.authenticatedContext(ADMIN).firestore();
const qtx = (db, id = 'earn_o1') => doc(db, 'users', CUSTOMER, 'qoinTransactions', id);

await run('QR1 CUSTOMER 본인 qoinTransactions 목록 read', 'allow', () =>
  getDocs(collection(asCustomer, 'users', CUSTOMER, 'qoinTransactions')));
await run('QR2 OWNER(타인) 가 CUSTOMER 내역 read', 'deny', () =>
  getDocs(collection(asOwner, 'users', CUSTOMER, 'qoinTransactions')));
await run('QR3 비로그인 내역 read', 'deny', () =>
  getDocs(collection(asAnon, 'users', CUSTOMER, 'qoinTransactions')));
await run('QR4 CUSTOMER 가 본인 거래 문서 create', 'deny', () =>
  setDoc(qtx(asCustomer, 'earn_forge'), { txId: 'earn_forge', type: 'earn', amount: 999999, balanceAfter: 999999, orderId: 'x', createdAt: serverTimestamp() }));
await run('QR5 CUSTOMER 가 본인 거래 문서 update(amount)', 'deny', () =>
  updateDoc(qtx(asCustomer), { amount: 999999 }));
await run('QR6 CUSTOMER 가 본인 거래 문서 delete', 'deny', () =>
  deleteDoc(qtx(asCustomer)));
await run('QR7 admin 이 거래 문서 delete (orderLogs 와 다름)', 'deny', () =>
  deleteDoc(qtx(asAdmin)));
await run('QR7b admin 이 거래 문서 update', 'deny', () =>
  updateDoc(qtx(asAdmin), { amount: 1 }));
await run('QR7c admin 이 거래 문서 create', 'deny', () =>
  setDoc(qtx(asAdmin, 'earn_forge2'), { txId: 'earn_forge2', amount: 1 }));
await run('QR8 admin 이 CUSTOMER 거래 문서 read', 'allow', () =>
  getDoc(qtx(asAdmin)));
await run('QR9 CUSTOMER 가 본인 qoinBalance 직접 update', 'deny', () =>
  updateDoc(doc(asCustomer, 'users', CUSTOMER), { qoinBalance: 999999 }));
await run('QR10 CUSTOMER 가 qoinBalance + displayName 동시 update', 'deny', () =>
  updateDoc(doc(asCustomer, 'users', CUSTOMER), { qoinBalance: 999999, displayName: 'x' }));
await run('QR10b CUSTOMER 가 qoinBalance increment', 'deny', () =>
  updateDoc(doc(asCustomer, 'users', CUSTOMER), { qoinBalance: increment(1000) }));
await run('QR11 OWNER 가 타인(CUSTOMER) qoinBalance update', 'deny', () =>
  updateDoc(doc(asOwner, 'users', CUSTOMER), { qoinBalance: 999999 }));
await run('QR13 CUSTOMER 가 config/qoin read', 'allow', () =>
  getDoc(doc(asCustomer, 'config', 'qoin')));
await run('QR14 CUSTOMER 가 config/qoin write', 'deny', () =>
  updateDoc(doc(asCustomer, 'config', 'qoin'), { accrualRate: 1 }));
await run('QR14b CUSTOMER 가 config/qoin enabled write', 'deny', () =>
  updateDoc(doc(asCustomer, 'config', 'qoin'), { enabled: true }));
await run('QR15 OWNER 가 config/qoin write', 'deny', () =>
  updateDoc(doc(asOwner, 'config', 'qoin'), { accrualRate: 1 }));
await run('QR16 admin 이 config/qoin write', 'allow', () =>
  updateDoc(doc(asAdmin, 'config', 'qoin'), { accrualRate: 0.05, enabled: false }));
await run('QR16b admin 이 config 신규 문서 create', 'allow', () =>
  setDoc(doc(asAdmin, 'config', 'qoin_new'), { accrualRate: 0.03, enabled: false }));
await run('QR17 비로그인 config/qoin read', 'deny', () =>
  getDoc(doc(asAnon, 'config', 'qoin')));
await run('QR18 내역 쿼리 (createdAt desc limit 50)', 'allow', () =>
  getDocs(query(collection(asCustomer, 'users', CUSTOMER, 'qoinTransactions'),
    orderBy('createdAt', 'desc'), limit(50))));
await run('QR12 admin 이 qoinBalance update (§4.4 수용)', 'allow', () =>
  updateDoc(doc(asAdmin, 'users', CUSTOMER), { qoinBalance: 500 }));

// ── 회귀: users self-create 로 qoinBalance 를 심는 경로 (F1) ──────────────
// update 화이트리스트는 create 에 적용되지 않는다. 막지 않으면 신규 계정이
// 처음부터 잔액을 들고 시작하고, CF 는 그 값을 믿고 더한다.
const NEWBIE = 'newbieUid00000000000000000001';
const asNewbie = env.authenticatedContext(NEWBIE).firestore();

await run('F1 self-create 에 qoinBalance 포함', 'deny', () =>
  setDoc(doc(asNewbie, 'users', NEWBIE),
    { uid: NEWBIE, role: 'customer', qoinBalance: 999999 }));

await run('F1 self-create (qoinBalance 없음)', 'allow', () =>
  setDoc(doc(asNewbie, 'users', NEWBIE), { uid: NEWBIE, role: 'customer' }));

console.log('\n================ Rules 검증 결과 ================');
let fail = 0;
for (const [n, e, r] of results) {
  if (!r.startsWith('PASS')) fail++;
  console.log(`${r.startsWith('PASS') ? '  PASS' : '  FAIL'}  [${e.padEnd(5)}] ${n}${r.startsWith('PASS') ? '' : '  → ' + r}`);
}
console.log(`================ ${results.length - fail}/${results.length} PASS ================\n`);
await env.cleanup();
process.exit(fail ? 1 : 0);

import { initializeTestEnvironment, assertFails, assertSucceeds }
  from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, increment, collection, query, where, orderBy, limit, getDocs, collectionGroup, Timestamp, serverTimestamp, deleteDoc, deleteField } from 'firebase/firestore';
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
// 계층화(qoin_accrual_rate_hierarchy)로 의미 변경: 적립률 쓰기는 CF 전담, enabled 만 admin 직접 쓰기 유지.
await run('QR16 admin 이 config/qoin enabled write', 'allow', () =>
  updateDoc(doc(asAdmin, 'config', 'qoin'), { enabled: false }));
await run('QR16b admin 이 config 신규 문서 create (accrualRate 없음)', 'allow', () =>
  setDoc(doc(asAdmin, 'config', 'qoin_new'), { enabled: false }));
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


// ══ Qoin 적립률 계층화 (docs/tasks/qoin_accrual_rate_hierarchy/spec.md §9 쓰기 경로 12개 전수) ══
// 1차 F1 교훈: 보호가 update 에만 있고 create / admin 전권 분기에 없으면 구멍이다.
// 아래 RH 케이스는 spec §9 의 경로 번호(P1~P12)와 1:1 로 대응한다.
const BRAND_U = 'brandUid0000000000000000000001';
const BRAND_X = 'brandUid0000000000000000000002'; // 다른 브랜드 보유자
const B_A = 'brand_a';
const B_X = 'brand_x';
const S_BR = 'store_br_of_brand_a';   // OWNER 소유, brand_a 가맹점
const S_OVR = 'store_with_override';  // OWNER 소유, 이미 qoinAccrualRate 가 있는 매장
await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'users', BRAND_U), { uid: BRAND_U, role: 'brand', brandId: B_A, displayName: 'brandA' });
  await setDoc(doc(db, 'users', BRAND_X), { uid: BRAND_X, role: 'brand', brandId: B_X, displayName: 'brandX' });
  await setDoc(doc(db, 'brands', B_A), { name: 'A브랜드', status: 'approved', submittedBy: BRAND_U, brandKey: 'AAA' });
  await setDoc(doc(db, 'brands', B_X), { name: 'X브랜드', status: 'approved', submittedBy: BRAND_X, brandKey: 'XXX' });
  await setDoc(doc(db, 'stores', S_BR), { ownerId: OWNER, name: 'BR', status: 'approved', brandId: B_A });
  await setDoc(doc(db, 'stores', S_OVR), { ownerId: OWNER, name: 'OVR', status: 'approved', qoinAccrualRate: 0.1 });
  const h = { scope: 'x', field: 'accrualRate', before: 0.03, after: 0.05, changedBy: ADMIN, changedAt: Timestamp.now(), source: 'callable', op: 'set' };
  await setDoc(doc(db, 'config', 'qoin', 'qoinRateHistory', 'h1'), { ...h, scope: 'global' });
  await setDoc(doc(db, 'brands', B_A, 'qoinRateHistory', 'h1'), { ...h, scope: 'brand' });
  await setDoc(doc(db, 'stores', S_A, 'qoinRateHistory', 'h1'), { ...h, scope: 'store' });
  await setDoc(doc(db, 'stores', S_BR, 'qoinRateHistory', 'h1'), { ...h, scope: 'store' });
  await setDoc(doc(db, 'stores', S_B, 'qoinRateHistory', 'h1'), { ...h, scope: 'store' });
});
const asBrand  = env.authenticatedContext(BRAND_U).firestore();
const asBrandX = env.authenticatedContext(BRAND_X).firestore();

// P1/P5: stores update (customer·owner·brand·admin 전권)
await run('RH1 P1 owner 가 자기 매장 qoinAccrualRate update', 'deny', () =>
  updateDoc(doc(asOwner, 'stores', S_A), { qoinAccrualRate: 0.2 }));
await run('RH1b P1 owner 가 개별 설정 삭제(deleteField)', 'deny', () =>
  updateDoc(doc(asOwner, 'stores', S_OVR), { qoinAccrualRate: deleteField() }));
await run('RH1c P1 owner 가 qoinAccrualRate 를 정상 필드와 함께 update', 'deny', () =>
  updateDoc(doc(asOwner, 'stores', S_A), { name: 'A2', qoinAccrualRate: 0.2 }));
await run('RH1d P1 customer 가 stores qoinAccrualRate update', 'deny', () =>
  updateDoc(doc(asCustomer, 'stores', S_A), { qoinAccrualRate: 0.2 }));
await run('RH2 P1 brand 가 가맹점 qoinAccrualRate update', 'deny', () =>
  updateDoc(doc(asBrand, 'stores', S_BR), { qoinAccrualRate: 0.2 }));
await run('RH3 P5 admin 이 stores qoinAccrualRate update (전권 분기)', 'deny', () =>
  updateDoc(doc(asAdmin, 'stores', S_A), { qoinAccrualRate: 0.2 }));
await run('RH3b P5 admin 이 stores qoinAccrualRate 삭제(deleteField)', 'deny', () =>
  updateDoc(doc(asAdmin, 'stores', S_OVR), { qoinAccrualRate: deleteField() }));
await run('RH3c P5 admin 이 stores 에 setDoc(merge) 로 qoinAccrualRate', 'deny', () =>
  setDoc(doc(asAdmin, 'stores', S_A), { qoinAccrualRate: 0.2 }, { merge: true }));
// P2/P3: stores create
await run('RH4 P2 owner 가 stores create 에 qoinAccrualRate 포함', 'deny', () =>
  setDoc(doc(asOwner, 'stores', 'new_store_1'), { ownerId: OWNER, name: 'N', status: 'pending', qoinAccrualRate: 0.2 }));
await run('RH4b P2 owner 가 stores create (qoinAccrualRate 없음, 회귀)', 'allow', () =>
  setDoc(doc(asOwner, 'stores', 'new_store_2'), { ownerId: OWNER, name: 'N', status: 'pending' }));
await run('RH4c P3 brand 가 stores create (qoinAccrualRate 포함)', 'deny', () =>
  setDoc(doc(asBrand, 'stores', 'new_store_3'), { ownerId: OWNER, name: 'N', status: 'pending', brandId: B_A, qoinAccrualRate: 0.2 }));
await run('RH4d P3 admin 이 stores create (qoinAccrualRate 포함)', 'deny', () =>
  setDoc(doc(asAdmin, 'stores', 'new_store_4'), { ownerId: OWNER, name: 'N', status: 'pending', qoinAccrualRate: 0.2 }));
await run('RH5 admin 이 stores 의 다른 필드 update (회귀)', 'allow', () =>
  updateDoc(doc(asAdmin, 'stores', S_A), { notice: 'hi' }));
await run('RH5b owner 가 자기 매장 운영 필드 update (회귀)', 'allow', () =>
  updateDoc(doc(asOwner, 'stores', S_A), { notice: 'hello' }));
await run('RH5c owner 가 개별 설정이 있는 매장의 다른 필드 update (필드 보존, 회귀)', 'allow', () =>
  updateDoc(doc(asOwner, 'stores', S_OVR), { notice: 'x' }));
await run('RH5d brand 가 가맹점 운영 필드 update (회귀)', 'allow', () =>
  updateDoc(doc(asBrand, 'stores', S_BR), { notice: 'x' }));
// P4: brands
await run('RH6 P5 admin 이 brands qoinAccrualRate update (전권 분기)', 'deny', () =>
  updateDoc(doc(asAdmin, 'brands', B_A), { qoinAccrualRate: 0.2 }));
await run('RH6b P4 brand 가 자기 brands qoinAccrualRate update', 'deny', () =>
  updateDoc(doc(asBrand, 'brands', B_A), { qoinAccrualRate: 0.2 }));
await run('RH6c P4 brand 가 자기 brands 에 qoinAccrualRate 와 정상 필드 동시 update', 'deny', () =>
  updateDoc(doc(asBrand, 'brands', B_A), { description: 'd', qoinAccrualRate: 0.2 }));
await run('RH7 P4 admin 이 brands create 에 qoinAccrualRate 포함', 'deny', () =>
  setDoc(doc(asAdmin, 'brands', 'new_brand_1'), { name: 'N', status: 'approved', qoinAccrualRate: 0.2 }));
await run('RH7b P4 brand 가 brands create(pending) 에 qoinAccrualRate 포함', 'deny', () =>
  setDoc(doc(asBrand, 'brands', 'new_brand_2'), { name: 'N', status: 'pending', submittedBy: BRAND_U, brandKey: '', qoinAccrualRate: 0.2 }));
await run('RH7c admin 이 brands create (qoinAccrualRate 없음, 회귀)', 'allow', () =>
  setDoc(doc(asAdmin, 'brands', 'new_brand_3'), { name: 'N', status: 'approved' }));
await run('RH7d brand 가 brands create(pending, qoinAccrualRate 없음, 회귀)', 'allow', () =>
  setDoc(doc(asBrand, 'brands', 'new_brand_4'), { name: 'N', status: 'pending', submittedBy: BRAND_U, brandKey: '' }));
await run('RH8 admin 이 brands 의 다른 필드 update (회귀)', 'allow', () =>
  updateDoc(doc(asAdmin, 'brands', B_A), { description: 'd' }));
await run('RH8b brand 가 자기 brands 운영 필드 update (회귀)', 'allow', () =>
  updateDoc(doc(asBrand, 'brands', B_A), { description: 'd2' }));
// P6/P7: config
await run('RH9 P6 admin 이 config/qoin.accrualRate update', 'deny', () =>
  updateDoc(doc(asAdmin, 'config', 'qoin'), { accrualRate: 0.2 }));
await run('RH9b P6 admin 이 config/qoin.accrualRate 삭제(deleteField)', 'deny', () =>
  updateDoc(doc(asAdmin, 'config', 'qoin'), { accrualRate: deleteField() }));
await run('RH9c P6 admin 이 config/qoin 을 setDoc 으로 교체(accrualRate 변경)', 'deny', () =>
  setDoc(doc(asAdmin, 'config', 'qoin'), { accrualRate: 0.2, enabled: true }));
await run('RH9d P6 admin 이 enabled 와 accrualRate 동시 update', 'deny', () =>
  updateDoc(doc(asAdmin, 'config', 'qoin'), { enabled: true, accrualRate: 0.2 }));
await run('RH10 admin 이 config/qoin.enabled update', 'allow', () =>
  updateDoc(doc(asAdmin, 'config', 'qoin'), { enabled: true }));
await run('RH11 P7 admin 이 config 문서를 accrualRate 포함해 create', 'deny', () =>
  setDoc(doc(asAdmin, 'config', 'qoin_create_probe'), { accrualRate: 0.2, enabled: true }));
await run('RH11b admin 이 config 문서를 accrualRate 없이 create (회귀)', 'allow', () =>
  setDoc(doc(asAdmin, 'config', 'qoin_create_probe2'), { enabled: false }));
await run('RH11c P6 admin 이 config/qoin delete (삭제 = accrualRate 소멸)', 'deny', () =>
  deleteDoc(doc(asAdmin, 'config', 'qoin')));
await run('RH12 customer 의 config write', 'deny', () =>
  updateDoc(doc(asCustomer, 'config', 'qoin'), { enabled: false }));
await run('RH12b 비로그인 config write', 'deny', () =>
  updateDoc(doc(asAnon, 'config', 'qoin'), { enabled: false }));
await run('RH12c owner 의 config enabled write', 'deny', () =>
  updateDoc(doc(asOwner, 'config', 'qoin'), { enabled: false }));
// P12: qoinRateHistory 직접 쓰기 (전 역할 × 전 범위 × create/update/delete)
const histPaths = [
  ['global', (db) => doc(db, 'config', 'qoin', 'qoinRateHistory', 'h1'), (db) => doc(db, 'config', 'qoin', 'qoinRateHistory', 'forge')],
  ['brand',  (db) => doc(db, 'brands', B_A, 'qoinRateHistory', 'h1'),   (db) => doc(db, 'brands', B_A, 'qoinRateHistory', 'forge')],
  ['store',  (db) => doc(db, 'stores', S_A, 'qoinRateHistory', 'h1'),   (db) => doc(db, 'stores', S_A, 'qoinRateHistory', 'forge')],
];
const actors = [['customer', asCustomer], ['owner', asOwner], ['brand', asBrand], ['admin', asAdmin]];
for (const [scope, existing, fresh] of histPaths) {
  for (const [role, db] of actors) {
    await run(`RH13 P12 ${role} 가 ${scope} 이력 create`, 'deny', () =>
      setDoc(fresh(db), { scope, field: 'accrualRate', before: 0.03, after: 0.2, changedAt: serverTimestamp() }));
    await run(`RH14 P12 ${role} 가 ${scope} 이력 update`, 'deny', () =>
      updateDoc(existing(db), { after: 0.2 }));
    await run(`RH15 P12 ${role} 가 ${scope} 이력 delete`, 'deny', () =>
      deleteDoc(existing(db)));
  }
}
// 이력 read (H6)
await run('RH17 점주가 자기 매장 이력 read', 'allow', () =>
  getDocs(query(collection(asOwner, 'stores', S_A, 'qoinRateHistory'), orderBy('changedAt', 'desc'), limit(50))));
await run('RH18 점주가 남의 매장 이력 read', 'deny', () =>
  getDocs(collection(asOwner, 'stores', S_B, 'qoinRateHistory')));
await run('RH19 brand 가 자기 산하 매장 이력 read', 'allow', () =>
  getDocs(collection(asBrand, 'stores', S_BR, 'qoinRateHistory')));
await run('RH19b brand 가 자기 브랜드 이력 read', 'allow', () =>
  getDocs(collection(asBrand, 'brands', B_A, 'qoinRateHistory')));
await run('RH20 brand 가 남의 브랜드 이력 read', 'deny', () =>
  getDocs(collection(asBrandX, 'brands', B_A, 'qoinRateHistory')));
await run('RH20b brand 가 남의 브랜드 산하 매장 이력 read', 'deny', () =>
  getDocs(collection(asBrandX, 'stores', S_BR, 'qoinRateHistory')));
await run('RH20c brand 가 개인 매장 이력 read', 'deny', () =>
  getDocs(collection(asBrand, 'stores', S_A, 'qoinRateHistory')));
await run('RH20d owner 가 브랜드 이력 read', 'deny', () =>
  getDocs(collection(asOwner, 'brands', B_A, 'qoinRateHistory')));
await run('RH20e owner 가 전역 이력 read', 'deny', () =>
  getDocs(collection(asOwner, 'config', 'qoin', 'qoinRateHistory')));
await run('RH21 admin 이 전역 이력 read', 'allow', () =>
  getDocs(collection(asAdmin, 'config', 'qoin', 'qoinRateHistory')));
await run('RH21b admin 이 브랜드 이력 read', 'allow', () =>
  getDocs(collection(asAdmin, 'brands', B_A, 'qoinRateHistory')));
await run('RH21c admin 이 매장 이력 read', 'allow', () =>
  getDocs(collection(asAdmin, 'stores', S_A, 'qoinRateHistory')));
await run('RH22 customer 가 임의 이력 read', 'deny', () =>
  getDocs(collection(asCustomer, 'stores', S_A, 'qoinRateHistory')));
await run('RH22b 비로그인 이력 read', 'deny', () =>
  getDocs(collection(asAnon, 'stores', S_A, 'qoinRateHistory')));
await run('RH23 admin 의 collectionGroup(qoinRateHistory) 조회', 'allow', () =>
  getDocs(query(collectionGroup(asAdmin, 'qoinRateHistory'), orderBy('changedAt', 'desc'), limit(50))));
await run('RH24 owner 의 collectionGroup 조회', 'deny', () =>
  getDocs(query(collectionGroup(asOwner, 'qoinRateHistory'), orderBy('changedAt', 'desc'), limit(50))));
await run('RH24b brand 의 collectionGroup 조회', 'deny', () =>
  getDocs(query(collectionGroup(asBrand, 'qoinRateHistory'), orderBy('changedAt', 'desc'), limit(50))));
await run('RH24c customer 의 collectionGroup 조회', 'deny', () =>
  getDocs(query(collectionGroup(asCustomer, 'qoinRateHistory'), orderBy('changedAt', 'desc'), limit(50))));

console.log('\n================ Rules 검증 결과 ================');
let fail = 0;
for (const [n, e, r] of results) {
  if (!r.startsWith('PASS')) fail++;
  console.log(`${r.startsWith('PASS') ? '  PASS' : '  FAIL'}  [${e.padEnd(5)}] ${n}${r.startsWith('PASS') ? '' : '  → ' + r}`);
}
console.log(`================ ${results.length - fail}/${results.length} PASS ================\n`);
await env.cleanup();
process.exit(fail ? 1 : 0);

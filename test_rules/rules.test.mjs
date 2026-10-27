import { initializeTestEnvironment, assertFails, assertSucceeds }
  from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, increment, collection, query, where, orderBy, limit, getDocs, collectionGroup, Timestamp, serverTimestamp, deleteDoc, deleteField, writeBatch } from 'firebase/firestore';
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
  firestore: { host: '127.0.0.1', port: 8137, rules: fs.readFileSync(process.env.RULES_FILE || 'firestore.rules', 'utf8') },
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
await run('QR16 admin 이 config/qoin enabled write (F3: enabledChangedBy = 본인 uid)', 'allow', () =>
  updateDoc(doc(asAdmin, 'config', 'qoin'), { enabled: false, enabledChangedBy: ADMIN, enabledChangedAt: serverTimestamp() }));
await run('QR16b admin 이 config 신규 문서 create (accrualRate 없음, enabledChangedBy 포함)', 'allow', () =>
  setDoc(doc(asAdmin, 'config', 'qoin_new'), { enabled: false, enabledChangedBy: ADMIN, enabledChangedAt: serverTimestamp() }));
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
await run('RH10 admin 이 config/qoin.enabled update (enabledChangedBy = 본인)', 'allow', () =>
  updateDoc(doc(asAdmin, 'config', 'qoin'), { enabled: true, enabledChangedBy: ADMIN, enabledChangedAt: serverTimestamp() }));
await run('RH11 P7 admin 이 config 문서를 accrualRate 포함해 create', 'deny', () =>
  setDoc(doc(asAdmin, 'config', 'qoin_create_probe'), { accrualRate: 0.2, enabled: true }));
await run('RH11b admin 이 config 문서를 accrualRate 없이 create (회귀, enabledChangedBy + enabledChangedAt 포함 — create 도 update 와 같은 강제, 3차 H-1)', 'allow', () =>
  setDoc(doc(asAdmin, 'config', 'qoin_create_probe2'), { enabled: false, enabledChangedBy: ADMIN, enabledChangedAt: serverTimestamp() }));
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


// ══ Qoin 적립 스위치 · 잠금 포인터 · enabledChangedBy · 이슈 (spec §20.5.4 / §20.5.6 #14~17, §19.3, Q2, Q3, N8) ══
// 보호 필드 집합: qoinAccrualRate / qoinAccrualEnabled / qoinBulkHistoryId / qoinBulkStatus / qoinBulkAt
const S_F4A = 'store_f4_a'; const S_F4B = 'store_f4_b'; const S_F4C = 'store_f4_c'; const S_F4D = 'store_f4_d';
await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  const seed = { ownerId: OWNER, name: 'F4', status: 'approved', qoinAccrualRate: 0.1, qoinAccrualEnabled: false };
  for (const id of [S_F4A, S_F4B, S_F4C, S_F4D]) await setDoc(doc(db, 'stores', id), seed);
  await setDoc(doc(db, 'brands', 'brand_ptr'), { name: 'PTR', status: 'approved', qoinBulkHistoryId: 'h9', qoinBulkStatus: 'partial', qoinBulkAt: Timestamp.now() });
  await setDoc(doc(db, 'config', 'qoin_f3'), { enabled: true, accrualRate: 0.03 });
  await setDoc(doc(db, 'qoinSettlementIssues', 'o_issue'), { orderId: 'o_issue', reason: 'invalid_rate', scope: 'store', resolved: false });
});
const SWITCH_FIELDS = [
  ['qoinAccrualEnabled', false], ['qoinBulkHistoryId', 'h1'], ['qoinBulkStatus', 'in_progress'], ['qoinBulkAt', Timestamp.now()],
];
for (const [field, val] of SWITCH_FIELDS) {
  await run(`SW1 P14 owner 가 자기 매장 ${field} update`, 'deny', () =>
    updateDoc(doc(asOwner, 'stores', S_A), { [field]: val }));
  await run(`SW1b P14 owner 가 ${field} 를 정상 필드와 함께 update`, 'deny', () =>
    updateDoc(doc(asOwner, 'stores', S_A), { name: 'A3', [field]: val }));
  await run(`SW1c P14 customer 가 stores ${field} update`, 'deny', () =>
    updateDoc(doc(asCustomer, 'stores', S_A), { [field]: val }));
  await run(`SW2 P14 brand 가 가맹점 ${field} update`, 'deny', () =>
    updateDoc(doc(asBrand, 'stores', S_BR), { [field]: val }));
  await run(`SW3 P17 admin 이 stores ${field} update (전권 분기)`, 'deny', () =>
    updateDoc(doc(asAdmin, 'stores', S_A), { [field]: val }));
  await run(`SW3b P17 admin 이 stores ${field} setDoc(merge)`, 'deny', () =>
    setDoc(doc(asAdmin, 'stores', S_A), { [field]: val }, { merge: true }));
  await run(`SW4 P15 owner 가 stores create 에 ${field} 포함`, 'deny', () =>
    setDoc(doc(asOwner, 'stores', `sw_new_o_${field}`), { ownerId: OWNER, name: 'N', status: 'pending', [field]: val }));
  await run(`SW4b P15 brand 가 stores create 에 ${field} 포함`, 'deny', () =>
    setDoc(doc(asBrand, 'stores', `sw_new_b_${field}`), { ownerId: OWNER, name: 'N', status: 'pending', brandId: B_A, [field]: val }));
  await run(`SW4c P17 admin 이 stores create 에 ${field} 포함`, 'deny', () =>
    setDoc(doc(asAdmin, 'stores', `sw_new_a_${field}`), { ownerId: OWNER, name: 'N', status: 'pending', [field]: val }));
  await run(`SW5 P16 brand 가 자기 brands ${field} update`, 'deny', () =>
    updateDoc(doc(asBrand, 'brands', B_A), { [field]: val }));
  await run(`SW5b P16 brand 가 brands ${field} 를 정상 필드와 함께 update`, 'deny', () =>
    updateDoc(doc(asBrand, 'brands', B_A), { description: 'd', [field]: val }));
  await run(`SW6 P17 admin 이 brands ${field} update (전권 분기)`, 'deny', () =>
    updateDoc(doc(asAdmin, 'brands', B_A), { [field]: val }));
  await run(`SW6b P17 admin 이 brands ${field} setDoc(merge)`, 'deny', () =>
    setDoc(doc(asAdmin, 'brands', B_A), { [field]: val }, { merge: true }));
  await run(`SW7 P16 admin 이 brands create 에 ${field} 포함`, 'deny', () =>
    setDoc(doc(asAdmin, 'brands', `sw_nb_a_${field}`), { name: 'N', status: 'approved', [field]: val }));
  await run(`SW7b P16 brand 가 brands create(pending) 에 ${field} 포함`, 'deny', () =>
    setDoc(doc(asBrand, 'brands', `sw_nb_b_${field}`), { name: 'N', status: 'pending', submittedBy: BRAND_U, brandKey: '', [field]: val }));
}
await run('SW8 P17 admin 이 stores 스위치 삭제(deleteField)', 'deny', () =>
  updateDoc(doc(asAdmin, 'stores', S_F4D), { qoinAccrualEnabled: deleteField() }));
await run('SW8b P17 owner 가 stores 스위치 삭제(deleteField)', 'deny', () =>
  updateDoc(doc(asOwner, 'stores', S_F4D), { qoinAccrualEnabled: deleteField() }));
await run('SW8c P17 admin 이 brands 포인터 삭제(deleteField)', 'deny', () =>
  updateDoc(doc(asAdmin, 'brands', 'brand_ptr'), { qoinBulkStatus: deleteField() }));
// 회귀: 보호 필드를 건드리지 않는 정상 쓰기는 막히지 않는다
await run('SW9 회귀: 스위치가 이미 있는 매장의 다른 필드 update (owner)', 'allow', () =>
  updateDoc(doc(asOwner, 'stores', S_F4D), { phone: '010-0000-0000' }));
await run('SW9b 회귀: 스위치가 이미 있는 매장의 다른 필드 update (admin)', 'allow', () =>
  updateDoc(doc(asAdmin, 'stores', S_F4D), { phone: '010-1111-1111' }));

// F3: enabledChangedBy 강제
await run('F3a admin 이 enabled 를 enabledChangedBy 없이 update', 'deny', () =>
  updateDoc(doc(asAdmin, 'config', 'qoin_f3'), { enabled: false }));
await run('F3a2 admin 이 enabled 를 enabledChangedBy = 본인과 함께 update (같은 문서, 회귀)', 'allow', () =>
  updateDoc(doc(asAdmin, 'config', 'qoin_f3'), { enabled: false, enabledChangedBy: ADMIN, enabledChangedAt: serverTimestamp() }));
await run('F3b admin 이 enabledChangedBy 를 타 uid 로 사칭해 update', 'deny', () =>
  updateDoc(doc(asAdmin, 'config', 'qoin'), { enabled: false, enabledChangedBy: OWNER, enabledChangedAt: serverTimestamp() }));
await run('F3c admin 이 enabledChangedBy = 본인 uid 로 update', 'allow', () =>
  updateDoc(doc(asAdmin, 'config', 'qoin'), { enabled: false, enabledChangedBy: ADMIN, enabledChangedAt: serverTimestamp() }));
await run('F3d admin 이 enabled 없이 enabledChangedBy 만 타 uid 로 update', 'deny', () =>
  updateDoc(doc(asAdmin, 'config', 'qoin'), { enabledChangedBy: OWNER }));
await run('F3e admin 이 config create 에 enabled 포함 + enabledChangedBy 사칭', 'deny', () =>
  setDoc(doc(asAdmin, 'config', 'qoin_forge_by'), { enabled: false, enabledChangedBy: OWNER }));
await run('F3f admin 이 enabledChangedBy 와 accrualRate 동시 update (accrualRate 차단 유지)', 'deny', () =>
  updateDoc(doc(asAdmin, 'config', 'qoin'), { enabled: true, enabledChangedBy: ADMIN, accrualRate: 0.2 }));

// Q2: qoinSettlementIssues — 읽기 admin, 쓰기 전면 차단
await run('IS1 admin 이 qoinSettlementIssues read', 'allow', () =>
  getDoc(doc(asAdmin, 'qoinSettlementIssues', 'o_issue')));
await run('IS2 owner 가 qoinSettlementIssues read', 'deny', () =>
  getDoc(doc(asOwner, 'qoinSettlementIssues', 'o_issue')));
await run('IS2b customer 가 qoinSettlementIssues read', 'deny', () =>
  getDoc(doc(asCustomer, 'qoinSettlementIssues', 'o_issue')));
await run('IS2c brand 가 qoinSettlementIssues read', 'deny', () =>
  getDoc(doc(asBrand, 'qoinSettlementIssues', 'o_issue')));
for (const [role, db] of actors) {
  await run(`IS3 ${role} 가 qoinSettlementIssues create`, 'deny', () =>
    setDoc(doc(db, 'qoinSettlementIssues', 'o_forge'), { orderId: 'o_forge', reason: 'invalid_rate' }));
  await run(`IS4 ${role} 가 qoinSettlementIssues update`, 'deny', () =>
    updateDoc(doc(db, 'qoinSettlementIssues', 'o_issue'), { resolved: true }));
  await run(`IS5 ${role} 가 qoinSettlementIssues delete`, 'deny', () =>
    deleteDoc(doc(db, 'qoinSettlementIssues', 'o_issue')));
}

// Q3 ⓐ / F4: 점주 delete → 같은 ID 재생성 (수용된 경로 #13) — 현재 동작을 명시적으로 고정한다
await run('F4a 점주가 개별 적립률·스위치가 있는 자기 매장 delete (수용)', 'allow', () =>
  deleteDoc(doc(asOwner, 'stores', S_F4A)));
await run('F4b 같은 ID 로 status:pending 재생성 (수용 — 재승인 필요)', 'allow', () =>
  setDoc(doc(asOwner, 'stores', S_F4A), { ownerId: OWNER, name: 'F4re', status: 'pending' }));
await run('F4c-pre 점주가 매장 delete (ⓒ 준비)', 'allow', () =>
  deleteDoc(doc(asOwner, 'stores', S_F4B)));
await run('F4c 같은 ID 로 qoinAccrualRate 포함 재생성', 'deny', () =>
  setDoc(doc(asOwner, 'stores', S_F4B), { ownerId: OWNER, name: 'F4re', status: 'pending', qoinAccrualRate: 0.1 }));
await run('F4c-pre2 점주가 매장 delete (ⓒ 스위치 준비)', 'allow', () =>
  deleteDoc(doc(asOwner, 'stores', S_F4C)));
await run('F4c2 같은 ID 로 qoinAccrualEnabled 포함 재생성', 'deny', () =>
  setDoc(doc(asOwner, 'stores', S_F4C), { ownerId: OWNER, name: 'F4re', status: 'pending', qoinAccrualEnabled: false }));
await run('F4c3 같은 ID 로 두 필드 모두 포함 재생성', 'deny', () =>
  setDoc(doc(asOwner, 'stores', S_F4C), { ownerId: OWNER, name: 'F4re', status: 'pending', qoinAccrualRate: 0.1, qoinAccrualEnabled: false }));

// N8: 점주는 자기 매장이 소속된 브랜드의 이력을 읽을 수 없다 (링크를 숨기는 근거 — Rules 를 완화하지 않는다)
await run('N8 owner 가 자기 매장(S_BR)이 소속된 브랜드(B_A)의 qoinRateHistory read', 'deny', () =>
  getDocs(collection(asOwner, 'brands', B_A, 'qoinRateHistory')));
await run('N8b owner 가 브랜드 이력 문서 단건 get', 'deny', () =>
  getDoc(doc(asOwner, 'brands', B_A, 'qoinRateHistory', 'h1')));
await run('N8c 회귀: owner 가 자기 매장(S_BR)의 이력은 read', 'allow', () =>
  getDocs(collection(asOwner, 'stores', S_BR, 'qoinRateHistory')));


// ══════════════════════════════════════════════════════════════════════════
// enabledChangedAt == request.time (spec §21.9-1) — 비상 정지의 행위자 기록은 생략할 수 없다
// ══════════════════════════════════════════════════════════════════════════
const seed = (fn) => env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
const ecReset = (enabled = true) => seed((db) => setDoc(doc(db, 'config', 'qoin'), { accrualRate: 0.03, enabled }));
await run('EC1 admin 이 enabledChangedBy 만 쓰고 enabledChangedAt 생략 (enabled 변경)', 'deny', async () => {
  await ecReset(true);
  return updateDoc(doc(asAdmin, 'config', 'qoin'), { enabled: false, enabledChangedBy: ADMIN });
});
await run('EC2 admin 이 enabled 만 단독으로 update (같은 admin 이 이전에 토글한 경우 포함 — 행위자 지우기)', 'deny', async () => {
  await ecReset(true);
  return updateDoc(doc(asAdmin, 'config', 'qoin'), { enabled: false });
});
await run('EC3 admin 이 enabledChangedAt 에 클라이언트 시각(Timestamp.now) — request.time 이 아님', 'deny', async () => {
  await ecReset(true);
  return updateDoc(doc(asAdmin, 'config', 'qoin'), { enabled: false, enabledChangedBy: ADMIN, enabledChangedAt: Timestamp.fromDate(new Date('2020-01-01')) });
});
await run('EC4 admin 이 enabledChangedAt 에 null', 'deny', async () => {
  await ecReset(true);
  return updateDoc(doc(asAdmin, 'config', 'qoin'), { enabled: false, enabledChangedBy: ADMIN, enabledChangedAt: null });
});
await run('EC5 admin 이 serverTimestamp 와 함께 enabled 변경 (새 앱의 정상 경로)', 'allow', async () => {
  await ecReset(true);
  return updateDoc(doc(asAdmin, 'config', 'qoin'), { enabled: false, enabledChangedBy: ADMIN, enabledChangedAt: serverTimestamp() });
});
await run('EC6 admin 이 다시 켜기 — 같은 형태 (비상 정지 해제도 동일)', 'allow', async () => {
  await ecReset(false);
  return updateDoc(doc(asAdmin, 'config', 'qoin'), { enabled: true, enabledChangedBy: ADMIN, enabledChangedAt: serverTimestamp() });
});
await run('EC7 enabled 를 건드리지 않는 update(예: 다른 설정 필드)는 enabledChangedAt 불요 — 회귀', 'allow', () =>
  updateDoc(doc(asAdmin, 'config', 'qoin'), { note: 'x' }));

await run('EC8 admin 이 config create 에 enabled + enabledChangedBy 만 (enabledChangedAt 생략) — create 에도 같은 강제 (H-1)', 'deny', () =>
  setDoc(doc(asAdmin, 'config', 'ec8_a'), { enabled: false, enabledChangedBy: ADMIN }));
await run('EC8b admin 이 config create 에 enabledChangedAt 을 클라이언트 시각으로', 'deny', () =>
  setDoc(doc(asAdmin, 'config', 'ec8_b'), { enabled: false, enabledChangedBy: ADMIN, enabledChangedAt: Timestamp.fromDate(new Date('2020-01-01')) }));
await run('EC8c admin 이 config create 에 enabled + serverTimestamp (정상)', 'allow', () =>
  setDoc(doc(asAdmin, 'config', 'ec8_c'), { enabled: false, enabledChangedBy: ADMIN, enabledChangedAt: serverTimestamp() }));
await run('EC8d enabled 없는 config create 는 불요 (회귀)', 'allow', () =>
  setDoc(doc(asAdmin, 'config', 'ec8_d'), { note: 'x' }));

// ══════════════════════════════════════════════════════════════════════════
// RM — 역할 변조 스위트 (brand_authorization_hardening §5)
//   불변식: "프로필을 바꿔서 얻을 수 있는 권한은 없다."
//   작성 규칙: 케이스마다 users/{uid} 를 **그 안에서** 쓰고 보호 대상을 때린다 (고정 시드 재사용 금지).
//   DENY 케이스는 Admin SDK(withSecurityRulesDisabled)로 변조 상태를 강제 주입한 뒤 하위 권한을 다시 때린다 —
//   "Rules 가 막으니 그 다음은 볼 필요 없다" 는 가정이 RH20 의 사각이었다.
// ══════════════════════════════════════════════════════════════════════════
const rmTag = Date.now().toString(36);
let rmN = 0;
const rmId = (p) => `${p}_${rmTag}_${++rmN}`;
/** 이 케이스 안에서 users/{uid} 를 쓴다 (Admin SDK). */
async function rmUser(fields = {}) {
  const uid = rmId('rmu');
  await seed((db) => setDoc(doc(db, 'users', uid), { uid, role: 'customer', ...fields }));
  return { uid, db: env.authenticatedContext(uid).firestore() };
}
/** 변조 상태를 강제 주입 (Rules 가 막아서 도달할 수 없는 상태를 가정해 하위 권한을 다시 때리기 위함). */
const rmForce = (uid, fields) => seed((db) => setDoc(doc(db, 'users', uid), fields, { merge: true }));
const rmBrand = async (status = 'approved', extra = {}) => {
  const id = rmId('rmb');
  await seed((db) => setDoc(doc(db, 'brands', id), { name: id, status, submittedBy: 'someone', brandKey: status === 'approved' ? 'KEY' : '', ...extra }));
  return id;
};
const rmStore = async (fields = {}, id = rmId('rms')) => {
  await seed((db) => setDoc(doc(db, 'stores', id), { ownerId: OTHER, name: id, status: 'approved', ...fields }));
  return id;
};
const menuBody = { name: 'm', price: 1000 };

await run('RM01 customer 가 users/{self} 에 {role:brand} (D3 — 전이 자체는 열려 있다)', 'allow', async () => {
  const u = await rmUser();
  return updateDoc(doc(u.db, 'users', u.uid), { role: 'brand' });
});
await run('RM01b owner 가 {role:brand}', 'allow', async () => {
  const u = await rmUser({ role: 'owner' });
  return updateDoc(doc(u.db, 'users', u.uid), { role: 'brand' });
});
for (const role of ['customer', 'owner', 'brand']) {
  await run(`RM02 ${role} 가 users/{self} 에 {brandId:'bX'} (D1 — 화이트리스트에서 제거)`, 'deny', async () => {
    const u = await rmUser({ role });
    return updateDoc(doc(u.db, 'users', u.uid), { brandId: 'bX' });
  });
}
await run('RM02b brand 계정(brandId 없음)이 {brandId:<실제 존재하는 approved 브랜드>} (존재하는 값이어도 DENY)', 'deny', async () => {
  const u = await rmUser({ role: 'brand' }); const b = await rmBrand();
  return updateDoc(doc(u.db, 'users', u.uid), { brandId: b });
});
await run('RM02c brand 계정(brandId 없음)이 {brandId:<자기가 submittedBy 인 브랜드>} 를 직접 (CF 만 쓸 수 있다)', 'deny', async () => {
  const u = await rmUser({ role: 'brand' });
  const b = rmId('rmb'); await seed((db) => setDoc(doc(db, 'brands', b), { name: 'mine', status: 'pending', submittedBy: u.uid, brandKey: '' }));
  return updateDoc(doc(u.db, 'users', u.uid), { brandId: b });
});
await run('RM02-inj 강제 주입 후 하위 권한: users.brandId=bX 가 주입됐다면 그 브랜드 menuItems 쓰기가 열린다 — 쓰기 차단(RM02)이 유일한 방어선임을 고정 (문서화)', 'allow', async () => {
  const b = await rmBrand();
  const u = await rmUser({ role: 'brand' });
  await rmForce(u.uid, { brandId: b }); // RM02 가 막는 상태를 Admin SDK 로 강제
  return setDoc(doc(u.db, 'brands', b, 'menuItems', rmId('m')), menuBody);
});
for (const from of ['customer', 'owner']) {
  await run(`RM03 ${from} 가 {role:brand, brandId:'bX'} 를 한 번에`, 'deny', async () => {
    const u = await rmUser({ role: from });
    return updateDoc(doc(u.db, 'users', u.uid), { role: 'brand', brandId: 'bX' });
  });
}
await run('RM03-inj 강제 주입({role:brand}만) 후: 같은 계정이 brands/bX/menuItems 쓰기는 DENY', 'deny', async () => {
  const b = await rmBrand(); const u = await rmUser({ role: 'customer' });
  await rmForce(u.uid, { role: 'brand' });
  return setDoc(doc(u.db, 'brands', b, 'menuItems', rmId('m')), menuBody);
});
await run('RM04 brandId 가 이미 있는 brand 계정이 다른 값으로 변경', 'deny', async () => {
  const a = await rmBrand(); const b = await rmBrand(); const u = await rmUser({ role: 'brand', brandId: a });
  return updateDoc(doc(u.db, 'users', u.uid), { brandId: b });
});
await run('RM04b brandId 가 이미 있는 brand 계정이 brandId 를 삭제(deleteField)', 'deny', async () => {
  const a = await rmBrand(); const u = await rmUser({ role: 'brand', brandId: a });
  return updateDoc(doc(u.db, 'users', u.uid), { brandId: deleteField() });
});
await run('RM04c 회귀: brand 계정이 brandId 와 무관한 프로필 필드(displayName)는 수정 가능', 'allow', async () => {
  const a = await rmBrand(); const u = await rmUser({ role: 'brand', brandId: a });
  return updateDoc(doc(u.db, 'users', u.uid), { displayName: 'x' });
});
await run('RM05 RM01 성공 직후(brandId 없음) brands/bX/menuItems create', 'deny', async () => {
  const b = await rmBrand(); const u = await rmUser();
  await updateDoc(doc(u.db, 'users', u.uid), { role: 'brand' }); // RM01 — 실제로 전이
  return setDoc(doc(u.db, 'brands', b, 'menuItems', rmId('m')), menuBody);
});
await run('RM05b RM01 직후 brands/bX 의 subCategories·optionGroups create', 'deny', async () => {
  const b = await rmBrand(); const u = await rmUser();
  await updateDoc(doc(u.db, 'users', u.uid), { role: 'brand' });
  return Promise.all([
    setDoc(doc(u.db, 'brands', b, 'subCategories', rmId('s')), { name: 's' }),
    setDoc(doc(u.db, 'brands', b, 'optionGroups', rmId('o')), { name: 'o' }),
  ]);
});
await run('RM05c RM01 직후 brands/bX 문서 자체 update(isBrandSelfUpdate)', 'deny', async () => {
  const b = await rmBrand(); const u = await rmUser();
  await updateDoc(doc(u.db, 'users', u.uid), { role: 'brand' });
  return updateDoc(doc(u.db, 'brands', b), { description: 'hijack' });
});
await run('RM06 RM01 직후 brands/bX/qoinRateHistory read', 'deny', async () => {
  const b = await rmBrand(); const u = await rmUser();
  await seed((db) => setDoc(doc(db, 'brands', b, 'qoinRateHistory', 'h1'), { scope: 'brand', field: 'accrualRate', changedBy: ADMIN, source: 'callable' }));
  await updateDoc(doc(u.db, 'users', u.uid), { role: 'brand' });
  return getDocs(collection(u.db, 'brands', b, 'qoinRateHistory'));
});
await run('RM07 RM01 직후(brandId 없음) **brandId 필드가 없는 매장**의 menuOverrides create — D2 의 회귀 핀 (D2 없이는 ALLOW)', 'deny', async () => {
  const s = await rmStore({}); const u = await rmUser();
  await updateDoc(doc(u.db, 'users', u.uid), { role: 'brand' });
  return setDoc(doc(u.db, 'stores', s, 'menuOverrides', rmId('mo')), { price: 1 });
});
for (const [label, fn] of [
  ['menuItems create', (u, st) => setDoc(doc(u.db, 'stores', st, 'menuItems', rmId('m')), menuBody)],
  ['subCategories create', (u, st) => setDoc(doc(u.db, 'stores', st, 'subCategories', rmId('c')), { name: 'c' })],
  ['optionGroups create', (u, st) => setDoc(doc(u.db, 'stores', st, 'optionGroups', rmId('o')), { name: 'o' })],
  ['qoinRateHistory read', (u, st) => getDocs(collection(u.db, 'stores', st, 'qoinRateHistory'))],
]) {
  await run(`RM07b brandId 필드 없는 매장 × brandId 없는 brand 계정(강제 주입) — ${label}`, 'deny', async () => {
    const st = await rmStore({}); const u = await rmUser();
    await rmForce(u.uid, { role: 'brand' });
    await seed((db) => setDoc(doc(db, 'stores', st, 'qoinRateHistory', 'h1'), { scope: 'store', field: 'accrualRate', changedBy: ADMIN, source: 'callable' }));
    return fn(u, st);
  });
}
await run('RM08 같은 상태, brandId:null 매장의 menuOverrides create (D2 전에도 DENY — 양쪽 고정)', 'deny', async () => {
  const s = await rmStore({ brandId: null }); const u = await rmUser();
  await updateDoc(doc(u.db, 'users', u.uid), { role: 'brand' });
  return setDoc(doc(u.db, 'stores', s, 'menuOverrides', rmId('mo')), { price: 1 });
});
await run('RM09 같은 상태, brandId:\'\' 매장의 menuItems create (D2)', 'deny', async () => {
  const s = await rmStore({ brandId: '' }); const u = await rmUser();
  await updateDoc(doc(u.db, 'users', u.uid), { role: 'brand' });
  return setDoc(doc(u.db, 'stores', s, 'menuItems', rmId('m')), menuBody);
});
await run('RM09b brandId 가 문자열이 아닌 값(숫자 0)인 매장 — brand 계정(brandId 없음)', 'deny', async () => {
  const s = await rmStore({ brandId: 0 }); const u = await rmUser();
  await rmForce(u.uid, { role: 'brand' });
  return setDoc(doc(u.db, 'stores', s, 'menuItems', rmId('m')), menuBody);
});
await run('RM09c brandId:\'\' 인 brand 계정(users.brandId == \'\')도 brandId \'\' 매장에 못 쓴다', 'deny', async () => {
  const s = await rmStore({ brandId: '' }); const u = await rmUser();
  await rmForce(u.uid, { role: 'brand', brandId: '' });
  return setDoc(doc(u.db, 'stores', s, 'menuItems', rmId('m')), menuBody);
});
await run('RM10 같은 상태, 그 매장 문서 자체 update(isStoreOwnerBrandUpdate 경로)', 'deny', async () => {
  const s = await rmStore({}); const u = await rmUser();
  await updateDoc(doc(u.db, 'users', u.uid), { role: 'brand' });
  return updateDoc(doc(u.db, 'stores', s), { status: 'pending' });
});
await run('RM10b brandId:\'\' 매장 문서 update (brand 계정 brandId 없음)', 'deny', async () => {
  const s = await rmStore({ brandId: '' }); const u = await rmUser();
  await rmForce(u.uid, { role: 'brand' });
  return updateDoc(doc(u.db, 'stores', s), { notice: 'x' });
});
await run('RM11 brand 계정(브랜드 A)이 브랜드 B 의 menuItems create', 'deny', async () => {
  const a = await rmBrand(); const b = await rmBrand(); const u = await rmUser({ role: 'brand', brandId: a });
  return setDoc(doc(u.db, 'brands', b, 'menuItems', rmId('m')), menuBody);
});
await run('RM12 brand 계정이 다른 브랜드 산하 매장의 menuOverrides create', 'deny', async () => {
  const a = await rmBrand(); const b = await rmBrand(); const s = await rmStore({ brandId: b });
  const u = await rmUser({ role: 'brand', brandId: a });
  return setDoc(doc(u.db, 'stores', s, 'menuOverrides', rmId('mo')), { price: 1 });
});
await run('RM13 brand 계정이 자기 브랜드 menuItems create (정상 흐름 고정)', 'allow', async () => {
  const a = await rmBrand(); const u = await rmUser({ role: 'brand', brandId: a });
  return setDoc(doc(u.db, 'brands', a, 'menuItems', rmId('m')), menuBody);
});
await run('RM14 brand 계정이 자기 산하 매장 menuOverrides create (정상 흐름 고정)', 'allow', async () => {
  const a = await rmBrand(); const s = await rmStore({ brandId: a });
  const u = await rmUser({ role: 'brand', brandId: a });
  return setDoc(doc(u.db, 'stores', s, 'menuOverrides', rmId('mo')), { price: 1 });
});
// D2 는 엄격화 전용 — 정상 흐름 12개 호출 지점이 전부 그대로 참이어야 한다 (하나라도 거짓이면 버그)
const holderSites = [
  ['brands/{b}/menuItems create', (u, a) => setDoc(doc(u.db, 'brands', a.b, 'menuItems', rmId('m')), menuBody)],
  ['brands/{b}/subCategories create', (u, a) => setDoc(doc(u.db, 'brands', a.b, 'subCategories', rmId('c')), { name: 'c' })],
  ['brands/{b}/optionGroups create', (u, a) => setDoc(doc(u.db, 'brands', a.b, 'optionGroups', rmId('o')), { name: 'o' })],
  ['brands/{b}/qoinRateHistory read', (u, a) => getDocs(collection(u.db, 'brands', a.b, 'qoinRateHistory'))],
  ['brands/{b} 운영 필드 update (isBrandSelfUpdate)', (u, a) => updateDoc(doc(u.db, 'brands', a.b), { description: 'd' })],
  ['stores/{s} 운영 필드 update (isStoreOwnerBrandUpdate)', (u, a) => updateDoc(doc(u.db, 'stores', a.s), { notice: 'n' })],
  ['stores/{s}/qoinRateHistory read', (u, a) => getDocs(collection(u.db, 'stores', a.s, 'qoinRateHistory'))],
  ['stores/{s}/subCategories create', (u, a) => setDoc(doc(u.db, 'stores', a.s, 'subCategories', rmId('c')), { name: 'c' })],
  ['stores/{s}/menuItems create', (u, a) => setDoc(doc(u.db, 'stores', a.s, 'menuItems', rmId('m')), menuBody)],
  ['stores/{s}/menuOverrides create', (u, a) => setDoc(doc(u.db, 'stores', a.s, 'menuOverrides', rmId('mo')), { price: 1 })],
  ['stores/{s}/optionGroups create', (u, a) => setDoc(doc(u.db, 'stores', a.s, 'optionGroups', rmId('o')), { name: 'o' })],
];
for (const [label, fn] of holderSites) {
  await run(`RM-D2 정상 브랜드 보유자 × ${label} (엄격화 전용 — 참 유지)`, 'allow', async () => {
    const b = await rmBrand('approved'); const s = await rmStore({ brandId: b });
    await seed(async (db) => {
      await setDoc(doc(db, 'brands', b, 'qoinRateHistory', 'h1'), { scope: 'brand', field: 'accrualRate', changedBy: ADMIN, source: 'callable' });
      await setDoc(doc(db, 'stores', s, 'qoinRateHistory', 'h1'), { scope: 'store', field: 'accrualRate', changedBy: ADMIN, source: 'callable' });
      await setDoc(doc(db, 'brands', b), { submittedBy: 'x' }, { merge: true });
    });
    const u = await rmUser({ role: 'brand', brandId: b });
    return fn(u, { b, s });
  });
}
// F-S1: brands.submittedBy 는 claimSubmittedBrand 의 신뢰 뿌리 — 본인 uid 로의 설정만 허용
await run('RM-S1 보유자가 자기 브랜드 submittedBy 를 임의의 다른 uid 로 양도', 'deny', async () => {
  const b = await rmBrand('approved'); const h = await rmUser({ role: 'brand', brandId: b });
  const victim = await rmUser({ role: 'brand' });
  return updateDoc(doc(h.db, 'brands', b), { submittedBy: victim.uid });
});
await run('RM-S1b 보유자가 submittedBy 를 양도하면서 다른 정상 필드와 함께(status pending 회귀 포함)', 'deny', async () => {
  const b = await rmBrand('approved'); const h = await rmUser({ role: 'brand', brandId: b });
  return updateDoc(doc(h.db, 'brands', b), { name: 'x', status: 'pending', submittedBy: 'someone_else', submittedAt: serverTimestamp() });
});
await run('RM-S1c 보유자가 재제출하며 submittedBy 를 자기 uid 로 설정 (정상 흐름)', 'allow', async () => {
  const b = await rmBrand('approved'); const h = await rmUser({ role: 'brand', brandId: b });
  return updateDoc(doc(h.db, 'brands', b), { name: 'x', status: 'pending', submittedBy: h.uid, submittedAt: serverTimestamp() });
});
await run('RM-S1d submittedBy 를 건드리지 않는 수정은 그대로 (회귀)', 'allow', async () => {
  const b = await rmBrand('approved'); const h = await rmUser({ role: 'brand', brandId: b });
  return updateDoc(doc(h.db, 'brands', b), { description: 'd' });
});
await run('RM-S1e admin 은 submittedBy 를 교정할 수 있다 (D4 교정 경로는 admin 전권)', 'allow', async () => {
  const b = await rmBrand('approved');
  return updateDoc(doc(asAdmin, 'brands', b), { submittedBy: 'any_uid_by_admin' });
});
await run('RM15 admin 이 users/{타인}.brandId 교정 (D4 의 교정 경로)', 'allow', async () => {
  const a = await rmBrand(); const u = await rmUser({ role: 'brand', brandId: 'wrong' });
  return updateDoc(doc(asAdmin, 'users', u.uid), { brandId: a });
});
await run('RM16 점주가 stores create 에 brandId:<존재하지 않는 id> (D5)', 'deny', async () => {
  const u = await rmUser({ role: 'owner' });
  return setDoc(doc(u.db, 'stores', rmId('rms')), { ownerId: u.uid, name: 'n', status: 'pending', brandId: rmId('ghost') });
});
await run('RM17 점주가 stores create 에 brandId:<pending 브랜드> (D5)', 'deny', async () => {
  const b = await rmBrand('pending'); const u = await rmUser({ role: 'owner' });
  return setDoc(doc(u.db, 'stores', rmId('rms')), { ownerId: u.uid, name: 'n', status: 'pending', brandId: b });
});
await run('RM17b 점주가 stores create 에 brandId:<rejected 브랜드> (D5)', 'deny', async () => {
  const b = await rmBrand('rejected'); const u = await rmUser({ role: 'owner' });
  return setDoc(doc(u.db, 'stores', rmId('rms')), { ownerId: u.uid, name: 'n', status: 'pending', brandId: b });
});
await run('RM17c 점주가 stores create 에 brandId 가 문자열이 아님(숫자)', 'deny', async () => {
  const u = await rmUser({ role: 'owner' });
  return setDoc(doc(u.db, 'stores', rmId('rms')), { ownerId: u.uid, name: 'n', status: 'pending', brandId: 7 });
});
await run('RM18 점주가 stores create 에 brandId:<approved 브랜드, 남의 것> — ALLOW 가 의도 (승인 게이트가 통제한다. Rules 로 가맹을 증명할 수 없다 — brandKey 가 공개)', 'allow', async () => {
  const b = await rmBrand('approved'); const u = await rmUser({ role: 'owner' });
  return setDoc(doc(u.db, 'stores', rmId('rms')), { ownerId: u.uid, name: 'n', status: 'pending', brandId: b });
});
await run('RM19 점주가 stores create 에 brandId:null (개인 매장)', 'allow', async () => {
  const u = await rmUser({ role: 'owner' });
  return setDoc(doc(u.db, 'stores', rmId('rms')), { ownerId: u.uid, name: 'n', status: 'pending', brandId: null });
});
await run('RM19b 점주가 stores create 에 brandId 필드 없음', 'allow', async () => {
  const u = await rmUser({ role: 'owner' });
  return setDoc(doc(u.db, 'stores', rmId('rms')), { ownerId: u.uid, name: 'n', status: 'pending' });
});
await run('RM20 brand 역할 계정이 stores create (create 는 isOwner())', 'deny', async () => {
  const b = await rmBrand('approved'); const u = await rmUser({ role: 'brand', brandId: b });
  return setDoc(doc(u.db, 'stores', rmId('rms')), { ownerId: u.uid, name: 'n', status: 'pending', brandId: b });
});
// 점주→브랜드 전환 흐름의 Rules 구간 (spec D1-2 의 1·3·5·8 단계) — CF(claim) 는 Admin SDK 라 Rules 밖
await run('FLOW 점주→브랜드 전환 ① role 전이 → ② 브랜드 문서 create(submittedBy=uid,pending,brandKey 빈값) → ③ (CF 가 brandId 쓴 상태) 브랜드 핵심 필드 수정 → pending 회귀', 'allow', async () => {
  const u = await rmUser({ role: 'owner' });
  await updateDoc(doc(u.db, 'users', u.uid), { role: 'brand' });                                   // 1
  const b = rmId('rmb');
  await setDoc(doc(u.db, 'brands', b), { name: 'n', status: 'pending', submittedBy: u.uid, brandKey: '' }); // 3 (batch 에서 users 쓰기 제거 후)
  await rmForce(u.uid, { brandId: b });                                                             // 4 claimSubmittedBrand 가 Admin SDK 로 쓴 결과
  await updateDoc(doc(u.db, 'brands', b), { name: 'n2', status: 'pending' });                       // 8
});
await run('FLOW-2 전환 ③ 직후(CF 전) 브랜드 문서 update 는 아직 DENY — 고아가 아니라 "연결 전" 상태임을 고정', 'deny', async () => {
  const u = await rmUser({ role: 'owner' });
  await updateDoc(doc(u.db, 'users', u.uid), { role: 'brand' });
  const b = rmId('rmb');
  await setDoc(doc(u.db, 'brands', b), { name: 'n', status: 'pending', submittedBy: u.uid, brandKey: '' });
  return updateDoc(doc(u.db, 'brands', b), { name: 'n2' });
});
await run('FLOW-3 batch 호환성: 브랜드 create 와 users.brandId 쓰기를 한 batch 로 보내는 구 방식은 신 Rules 에서 전체 거부 (③→④ 순서가 필수인 이유)', 'deny', async () => {
  const u = await rmUser({ role: 'brand' });
  const b = rmId('rmb');
  const batch = writeBatch(u.db);
  batch.set(doc(u.db, 'brands', b), { name: 'n', status: 'pending', submittedBy: u.uid, brandKey: '' });
  batch.set(doc(u.db, 'users', u.uid), { brandId: b }, { merge: true });
  return batch.commit();
});
// users/{uid}/roleHistory — CF 전담
await run('RHIST1 본인이 roleHistory read', 'allow', async () => {
  const u = await rmUser();
  await seed((db) => setDoc(doc(db, 'users', u.uid, 'roleHistory', 'h1'), { field: 'brandId', before: null, after: 'b', changedBy: u.uid }));
  return getDocs(collection(u.db, 'users', u.uid, 'roleHistory'));
});
await run('RHIST2 타인이 roleHistory read', 'deny', async () => {
  const u = await rmUser(); const v = await rmUser();
  await seed((db) => setDoc(doc(db, 'users', u.uid, 'roleHistory', 'h1'), { field: 'brandId', before: null, after: 'b', changedBy: u.uid }));
  return getDocs(collection(v.db, 'users', u.uid, 'roleHistory'));
});
await run('RHIST3 admin 이 roleHistory read', 'allow', async () => {
  const u = await rmUser();
  await seed((db) => setDoc(doc(db, 'users', u.uid, 'roleHistory', 'h1'), { field: 'brandId', before: null, after: 'b', changedBy: u.uid }));
  return getDocs(collection(asAdmin, 'users', u.uid, 'roleHistory'));
});
for (const [label, mk] of [
  ['본인 create', (u) => setDoc(doc(u.db, 'users', u.uid, 'roleHistory', 'forge'), { field: 'brandId', after: 'x', changedBy: u.uid })],
  ['본인 update', (u) => updateDoc(doc(u.db, 'users', u.uid, 'roleHistory', 'h1'), { after: 'x' })],
  ['본인 delete', (u) => deleteDoc(doc(u.db, 'users', u.uid, 'roleHistory', 'h1'))],
  ['admin create', (u) => setDoc(doc(asAdmin, 'users', u.uid, 'roleHistory', 'forge'), { field: 'brandId', after: 'x' })],
  ['admin delete', (u) => deleteDoc(doc(asAdmin, 'users', u.uid, 'roleHistory', 'h1'))],
]) {
  await run(`RHIST4 roleHistory ${label} (CF 전담)`, 'deny', async () => {
    const u = await rmUser();
    await seed((db) => setDoc(doc(db, 'users', u.uid, 'roleHistory', 'h1'), { field: 'brandId', before: null, after: 'b', changedBy: u.uid }));
    return mk(u);
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// payment_server_authority — Rules-A (spec §6.5, §6.7, §18.5)
// 결제 게이트(canSellNow)가 stores.approvedAt 을 권한 판정 입력으로 쓴다 → create 경로도 막혀야 한다.
// onlyChangedFields 는 update 전용 장치이고 create 에는 아무 보호도 주지 않는다 (같은 패턴 네 번째).
// ═══════════════════════════════════════════════════════════════════════════
const PSA_STORE = { ownerId: OWNER, name: 'N', status: 'pending' };
await run('PSA-A1 owner 매장 create 에 approvedAt 포함', 'deny', () =>
  setDoc(doc(asOwner, 'stores', 'psa_a1'), { ...PSA_STORE, approvedAt: Timestamp.now() }));
await run('PSA-A2 owner 매장 create 에 approvedBy 포함', 'deny', () =>
  setDoc(doc(asOwner, 'stores', 'psa_a2'), { ...PSA_STORE, approvedBy: ADMIN }));
await run('PSA-A3 owner 매장 create 에 rejectedReason 포함', 'deny', () =>
  setDoc(doc(asOwner, 'stores', 'psa_a3'), { ...PSA_STORE, rejectedReason: 'x' }));
await run('PSA-A4 owner 매장 create 에 세 필드를 명시적 null (부재와 동등)', 'allow', () =>
  setDoc(doc(asOwner, 'stores', 'psa_a4'), { ...PSA_STORE, approvedAt: null, approvedBy: null, rejectedReason: null }));
// 회귀: 현재 앱의 create payload(toFirestoreForCreate) 와 같은 키 집합 — 매장 등록이 막히면 안 된다.
await run('PSA-A5 owner 매장 create 정상 payload (회귀 — 앱과 동일 키 집합)', 'allow', () =>
  setDoc(doc(asOwner, 'stores', 'psa_a5'), {
    ownerId: OWNER, name: '신규 매장', description: '', phone: '010', address: '서울', location: { lat: 1, lng: 2 },
    imageUrl: '', imageUrls: [], menuCategories: ['coffee'], isOpen: false, status: 'pending',
    businessRegistrationNumber: '123-45-67890', createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    submittedBy: OWNER, submittedAt: serverTimestamp(),
  }));
await run('PSA-A5b owner 가맹 매장 create 정상 payload (brandId, 회귀)', 'allow', () =>
  setDoc(doc(asOwner, 'stores', 'psa_a5b'), { ...PSA_STORE, brandId: B_A, submittedBy: OWNER, submittedAt: serverTimestamp() }));
await run('PSA-A6 owner update 로 approvedAt 에 값 설정 (기존 보호 회귀)', 'deny', () =>
  updateDoc(doc(asOwner, 'stores', S_P), { approvedAt: Timestamp.now() }));
await run('PSA-A7 owner update 로 approvedAt: null (T3 재제출 회귀)', 'allow', () =>
  updateDoc(doc(asOwner, 'stores', S_P), { approvedAt: null }));
await run('PSA-A8 brand create 에 approvedAt 포함', 'deny', () =>
  setDoc(doc(asBrand, 'brands', 'psa_b1'), { name: 'N', status: 'pending', submittedBy: BRAND_U, brandKey: '', approvedAt: Timestamp.now() }));
await run('PSA-A8b brand create 에 approvedBy 포함', 'deny', () =>
  setDoc(doc(asBrand, 'brands', 'psa_b2'), { name: 'N', status: 'pending', submittedBy: BRAND_U, brandKey: '', approvedBy: ADMIN }));
await run('PSA-A8c brand create 정상 payload (회귀)', 'allow', () =>
  setDoc(doc(asBrand, 'brands', 'psa_b3'), { name: 'N', status: 'pending', submittedBy: BRAND_U, brandKey: '', companyName: 'C' }));
await run('PSA-A8d admin brand create (승인 메타 허용 — 해당 없음, 회귀)', 'allow', () =>
  setDoc(doc(asAdmin, 'brands', 'psa_b4'), { name: 'N', status: 'approved', approvedBy: ADMIN, approvedAt: Timestamp.now() }));

console.log('\n================ Rules 검증 결과 ================');
let fail = 0;
for (const [n, e, r] of results) {
  if (!r.startsWith('PASS')) fail++;
  console.log(`${r.startsWith('PASS') ? '  PASS' : '  FAIL'}  [${e.padEnd(5)}] ${n}${r.startsWith('PASS') ? '' : '  → ' + r}`);
}
console.log(`================ ${results.length - fail}/${results.length} PASS ================\n`);
await env.cleanup();
process.exit(fail ? 1 : 0);

// 점주/고객 -> 브랜드 전환 전 구간 통합 검증 (brand_authorization_hardening D1-2 의 9단계).
//
// Rules(클라이언트 SDK, 실제 Rules 적용)와 Cloud Function(claimSubmittedBrand, Functions 에뮬레이터)을 **같은 에뮬레이터 세션**에서
// 이어서 호출한다. Rules 하네스(rules.test.mjs)는 CF 를 부르지 않고, CF 테스트(functions/test/emulator.test.mjs)는 Admin SDK 라
// Rules 를 우회한다 — 두 조각이 이어지는 지점(batch 제거 -> callable -> isBrandHolder)을 이 파일이 처음부터 끝까지 한 번 돈다.
//
// 실행: cd test_rules && npm run test:flow   (functions 빌드 + firestore,functions 에뮬레이터)
import { initializeTestEnvironment, assertFails, assertSucceeds }
  from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, collection, query, where, getDocs, writeBatch, serverTimestamp, deleteField }
  from 'firebase/firestore';
import fs from 'fs';

const PROJECT = 'order-app-5957e';
const FN = `http://127.0.0.1:5137/${PROJECT}/asia-northeast3`;

const env = await initializeTestEnvironment({
  projectId: PROJECT,
  firestore: { host: '127.0.0.1', port: 8137, rules: fs.readFileSync('firestore.rules', 'utf8') },
});

const results = [];
const step = async (name, fn) => {
  try { await fn(); results.push([name, 'PASS']); console.log('  PASS', name); }
  catch (e) { results.push([name, 'FAIL: ' + (e.message || e)]); console.log('  FAIL', name, '->', e.message || e); }
};
const eq = (a, b, m = '') => {
  if (JSON.stringify(a) !== JSON.stringify(b)) throw new Error(`${m} expected ${JSON.stringify(b)} got ${JSON.stringify(a)}`);
};
const jwt = (uid) => {
  const b = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  return `${b({ alg: 'none', typ: 'JWT' })}.${b({ user_id: uid, sub: uid, aud: PROJECT, iss: `https://securetoken.google.com/${PROJECT}`, firebase: { sign_in_provider: 'custom' } })}.`;
};
const call = async (name, data, uid) => {
  const headers = { 'Content-Type': 'application/json' };
  if (uid) headers.Authorization = `Bearer ${jwt(uid)}`;
  const res = await fetch(`${FN}/${name}`, { method: 'POST', headers, body: JSON.stringify({ data }) });
  const body = await res.json();
  return body.error ? { error: body.error.status, message: body.error.message } : { result: body.result };
};
// 함수 에뮬레이터가 뜰 때까지 기다린다.
for (let i = 0; i < 60; i++) {
  try { const r = await call('claimSubmittedBrand', {}, undefined); if (r.error) break; } catch { /* retry */ }
  await new Promise((r) => setTimeout(r, 500));
}

const seed = (fn) => env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
const tag = Date.now().toString(36);
const ADMIN = `flow_admin_${tag}`;
await seed((db) => setDoc(doc(db, 'users', ADMIN), { uid: ADMIN, role: 'admin' }));
const asAdmin = env.authenticatedContext(ADMIN).firestore();

/** from: 'owner' | 'customer' — 전환 흐름을 처음부터 끝까지. */
async function runFlow(from) {
  const uid = `flow_${from}_${tag}`;
  const brandId = `flow_brand_${from}_${tag}`;
  const me = env.authenticatedContext(uid).firestore();
  await seed(async (db) => {
    await setDoc(doc(db, 'users', uid), { uid, role: from, displayName: from });
    if (from === 'owner') await setDoc(doc(db, 'stores', `flow_store_${tag}`), { ownerId: uid, name: '내 매장', status: 'approved', brandId: null });
  });

  await step(`[${from}] 1. 브랜드로 전환: users.role 만 바꾼다 (D3 — 전이는 열려 있다)`, () =>
    assertSucceeds(updateDoc(doc(me, 'users', uid), { role: 'brand' })));

  await step(`[${from}] 2. 전환 직후 brandId 없음 = 아직 아무 브랜드의 보유자가 아니다 (권한 0)`, async () => {
    eq((await getDoc(doc(me, 'users', uid))).get('brandId'), undefined);
    await assertFails(setDoc(doc(me, 'brands', 'someone_elses', 'menuItems', 'm'), { name: 'x' }));
  });

  await step(`[${from}] 3a. 구 방식(브랜드 문서 + users.brandId 한 batch)은 신 Rules 에서 전체 거부된다 — ③→④ 순서가 필수인 이유`, async () => {
    const b = writeBatch(me);
    b.set(doc(me, 'brands', `${brandId}_oldstyle`), { name: 'n', status: 'pending', submittedBy: uid, brandKey: '' });
    b.set(doc(me, 'users', uid), { brandId: `${brandId}_oldstyle` }, { merge: true });
    await assertFails(b.commit());
    eq((await getDoc(doc(me, 'brands', `${brandId}_oldstyle`))).exists(), false, '고아 브랜드 문서가 생기지 않았다');
  });

  await step(`[${from}] 3b. 신 방식: 브랜드 문서 1건만 쓴다 (users 쓰기 없음) — brands create 규칙 그대로 통과`, () =>
    assertSucceeds(setDoc(doc(me, 'brands', brandId), {
      name: '내 브랜드', status: 'pending', submittedBy: uid, brandKey: '', companyName: '(주)내', createdAt: serverTimestamp() }, { merge: true })));

  await step(`[${from}] 4-복구. 연결 전에 앱이 끊겨도 brands where submittedBy == uid 로 내 브랜드를 찾을 수 있다 (게이트의 조회)`, async () => {
    const snap = await assertSucceeds(getDocs(query(collection(me, 'brands'), where('submittedBy', '==', uid))));
    eq(snap.docs.map((d) => d.id), [brandId]);
    // 이 시점에도 users.brandId 는 비어 있다 -> 브랜드 문서 update 는 아직 거부 (연결 전)
    await assertFails(updateDoc(doc(me, 'brands', brandId), { name: '연결 전 수정' }));
  });

  await step(`[${from}] 4. claimSubmittedBrand: 서버가 submittedBy 를 검증하고 users.brandId + roleHistory 를 쓴다`, async () => {
    const r = await call('claimSubmittedBrand', { brandId }, uid);
    eq(r.result, { changed: true, brandId });
    eq((await getDoc(doc(me, 'users', uid))).get('brandId'), brandId);
    const h = await getDocs(collection(me, 'users', uid, 'roleHistory'));
    eq(h.size, 1);
    eq([h.docs[0].get('field'), h.docs[0].get('after'), h.docs[0].get('changedBy')], ['brandId', brandId, uid]);
    // 재호출은 멱등
    eq((await call('claimSubmittedBrand', { brandId }, uid)).result.changed, false);
    eq((await getDocs(collection(me, 'users', uid, 'roleHistory'))).size, 1);
  });

  await step(`[${from}] 5. BrandScaffold 가 brandId 를 인식한 뒤: 내 브랜드 권한 정상 (isBrandHolder)`, async () => {
    await assertSucceeds(getDocs(collection(me, 'brands', brandId, 'qoinRateHistory')));
    await assertSucceeds(setDoc(doc(me, 'brands', brandId, 'menuItems', 'm1'), { name: '아메리카노', price: 4000 }));
    await assertSucceeds(setDoc(doc(me, 'brands', brandId, 'subCategories', 's1'), { name: '커피' }));
    await assertSucceeds(setDoc(doc(me, 'brands', brandId, 'optionGroups', 'o1'), { name: '샷' }));
  });

  await step(`[${from}] 5b. 남의 브랜드는 여전히 안 된다`, () =>
    assertFails(setDoc(doc(me, 'brands', 'someone_elses', 'menuItems', 'm'), { name: 'x' })));

  await step(`[${from}] 6. admin 승인: status approved + brandKey 발급 (admin 전권)`, () =>
    assertSucceeds(updateDoc(doc(asAdmin, 'brands', brandId), {
      status: 'approved', brandKey: `BR-FLOW${from}`, approvedBy: ADMIN, approvedAt: serverTimestamp() })));

  await step(`[${from}] 7. 점주가 brandKey 로 얻은 brandId 로 매장 등록 (D5: 존재하는 approved 브랜드)`, async () => {
    const owner = `flow_owner2_${tag}_${from}`;
    await seed((db) => setDoc(doc(db, 'users', owner), { uid: owner, role: 'owner' }));
    const o = env.authenticatedContext(owner).firestore();
    await assertSucceeds(setDoc(doc(o, 'stores', `flow_affiliate_${tag}_${from}`), {
      ownerId: owner, name: '가맹점', status: 'pending', brandId }));
  });

  await step(`[${from}] 8. 브랜드 핵심 필드 수정 -> status pending 회귀 (isBrandSelfUpdate)`, () =>
    assertSucceeds(updateDoc(doc(me, 'brands', brandId), {
      name: '내 브랜드 2', status: 'pending', submittedBy: uid, submittedAt: serverTimestamp(), updatedAt: serverTimestamp() })));

  await step(`[${from}] 9. 반려 후 재제출 (같은 경로)`, async () => {
    await assertSucceeds(updateDoc(doc(asAdmin, 'brands', brandId), { status: 'rejected', rejectedReason: '서류 보완', approvedBy: ADMIN }));
    await assertSucceeds(updateDoc(doc(me, 'brands', brandId), {
      name: '내 브랜드 3', status: 'pending', rejectedReason: null, submittedBy: uid, submittedAt: serverTimestamp() }));
  });

  await step(`[${from}] 10. 점주 시절 매장은 영향 없음 / 자기 brandId 를 임의로 바꿀 수 없다 (D1)`, async () => {
    if (from === 'owner') {
      eq((await getDoc(doc(me, 'stores', `flow_store_${tag}`))).get('name'), '내 매장');
    }
    await assertFails(updateDoc(doc(me, 'users', uid), { brandId: 'someone_elses' }));
    await assertFails(updateDoc(doc(me, 'users', uid), { brandId: deleteField() }));
  });
}

console.log('\n── 점주 -> 브랜드 ──');
await runFlow('owner');
console.log('\n── 고객 -> 브랜드 ──');
await runFlow('customer');

console.log('\n── 연결 실패 후 복구 (4 가 실패한 사용자) ──');
await step('다른 사람의 브랜드를 claim 하면 permission-denied, users 불변 (게이트의 "내 브랜드 아님" 분기)', async () => {
  const a = `flow_a_${tag}`; const b = `flow_b_${tag}`;
  await seed(async (db) => {
    await setDoc(doc(db, 'users', a), { uid: a, role: 'brand' });
    await setDoc(doc(db, 'users', b), { uid: b, role: 'brand' });
    await setDoc(doc(db, 'brands', `flow_bb_${tag}`), { name: 'B', status: 'pending', submittedBy: b });
  });
  const r = await call('claimSubmittedBrand', { brandId: `flow_bb_${tag}` }, a);
  eq(r.error, 'PERMISSION_DENIED');
  const me = env.authenticatedContext(a).firestore();
  eq((await getDoc(doc(me, 'users', a))).get('brandId'), undefined);
});

console.log('\n================ 전환 전 구간 통합 검증 결과 ================');
let fail = 0;
for (const [n, r] of results) { if (r !== 'PASS') { fail++; console.log('  FAIL', n, '->', r); } }
console.log(`================ ${results.length - fail}/${results.length} PASS ================\n`);
await env.cleanup();
process.exit(fail ? 1 : 0);

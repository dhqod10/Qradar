/* ============================================================================
   데이터 접근 계층 — Firebase SDK 는 이 파일에서만 import 한다.
   화면 코드(console.js)는 SDK 를 직접 부르지 않는다 (spec §9.2 "데이터 접근 함수와 렌더 함수 분리").

   [Clean Architecture 와의 관계]
   CLAUDE.md 절대규칙 1·2 ("presentation → domain ← data", "Firebase 직접 사용은 data 레이어에서만")
   는 Flutter 앱(lib/)의 레이어 규칙이다. landing/ 은 Flutter 앱이 아니라 빌드 단계 없는 정적 사이트이므로
   그 레이어 체계 밖이다 → 규칙 2 위반이 아니다 (spec §9.2). 그래도 같은 정신으로 이 파일에 SDK 접근을 가두었다.

   [권위]
   이 콘솔은 클라이언트일 뿐이다. 무엇이 허용되는지는 Firestore Rules 와 Cloud Functions 가 결정한다.
   아래 코드의 사전 확인(pending 재확인, 연결 브랜드 확인)은 실수와 덮어쓰기를 줄이는 편의이며 보안 장치가 아니다.

   [SDK 버전] 정확한 버전을 URL 에 고정한다. 올릴 때는 4개 import 를 함께 바꾼다.
   ========================================================================== */

import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js';
import {
  getAuth, onAuthStateChanged, signInWithEmailAndPassword, signInWithPopup, GoogleAuthProvider, signOut,
} from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js';
import {
  getFirestore, collection, collectionGroup, doc, query, where, orderBy, limit,
  getDocFromServer, getDocsFromServer, getCountFromServer, runTransaction, serverTimestamp,
} from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js';
import { getFunctions, httpsCallable } from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-functions.js';

import { firebaseWebConfig, FUNCTIONS_REGION } from './firebase-config.js';
import { AdminError, parseGlobalRate } from './console-format.js';
import {
  assertPayload, brandApprovePayload, brandRejectPayload, storeApprovePayload, storeRejectPayload,
} from './console-payloads.js';

let app; let auth; let db; let functions;

/** 목록 상한. 넘으면 호출자에게 truncated 로 알린다. */
export const LIST_LIMIT = 500;
const READ_TIMEOUT_MS = 15000;
const WRITE_TIMEOUT_MS = 20000;
const KEY_TIMEOUT_MS = 30000;

export function initFirebase() {
  app = initializeApp(firebaseWebConfig);
  auth = getAuth(app);
  db = getFirestore(app); // 기본 = 메모리 캐시(오프라인 영속성 없음). 읽기는 전부 *FromServer 로 서버에서 가져온다.
  functions = getFunctions(app, FUNCTIONS_REGION); // 리전 명시 필수
}

function withTimeout(promise, ms) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new AdminError('timeout')), ms);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

/* ── 인증 ──────────────────────────────────────────────────────────────────── */

export const onAuthChanged = (cb) => onAuthStateChanged(auth, cb);
export const signInEmail = (email, password) => signInWithEmailAndPassword(auth, email, password);
export const signInGoogle = () => signInWithPopup(auth, new GoogleAuthProvider());
export const signOutNow = () => signOut(auth);
export const currentUid = () => auth?.currentUser?.uid ?? null;

/**
 * users/{uid} 를 서버에서 1회 읽어 role 을 판정한다. 읽기 실패·타임아웃은 throw (호출자가 닫힘으로 처리).
 * 이 결과는 "셸을 열지" 정하는 UX 판단일 뿐이다. 이후 모든 요청은 Rules 가 다시 판정한다.
 * @returns {Promise<{admin:boolean}>}
 */
export async function readUserRole(uid) {
  const snap = await withTimeout(getDocFromServer(doc(db, 'users', uid)), READ_TIMEOUT_MS);
  if (!snap.exists()) return { admin: false };
  const data = snap.data();
  if (data === null || typeof data !== 'object') throw new AdminError('parse');
  return { admin: data.role === 'admin' };
}

/* ── 읽기 공통 ─────────────────────────────────────────────────────────────── */

const rows = (snap) => snap.docs.map((d) => ({ id: d.id, ...d.data(), _ref: d.ref }));

async function getList(q) {
  const snap = await withTimeout(getDocsFromServer(q), READ_TIMEOUT_MS);
  return { rows: rows(snap), truncated: snap.size >= LIST_LIMIT };
}

async function getOne(ref) {
  const snap = await withTimeout(getDocFromServer(ref), READ_TIMEOUT_MS);
  if (!snap.exists()) return null;
  return { id: snap.id, ...snap.data() };
}

const bySubmittedAsc = (a, b) =>
  (a.submittedAt?.toMillis?.() ?? 0) - (b.submittedAt?.toMillis?.() ?? 0);

/* ── 건수 (읽기 실패를 0 으로 바꾸지 않는다: 숫자가 아니면 parse 오류) ──────────── */

async function countOf(q) {
  const snap = await withTimeout(getCountFromServer(q), READ_TIMEOUT_MS);
  const n = snap.data().count;
  if (typeof n !== 'number' || !Number.isFinite(n) || n < 0) throw new AdminError('parse');
  return n;
}

// 큐 조회와 같은 필터를 쓴다 (건수와 목록이 같은 대상을 센다).
const brandsPending = () => query(collection(db, 'brands'), where('status', '==', 'pending'));
const storesPending = () => query(collection(db, 'stores'), where('status', '==', 'pending'));
const menusPending = () =>
  query(collectionGroup(db, 'menuItems'), where('scope', '==', 'brand'), where('status', '==', 'pending'));
const overridesPending = () =>
  query(collectionGroup(db, 'menuOverrides'), where('status', '==', 'pending'));

export const countPending = Object.freeze({
  brands: () => countOf(brandsPending()),
  stores: () => countOf(storesPending()),
  menus: () => countOf(menusPending()),
  overrides: () => countOf(overridesPending()),
});

/* ── 브랜드 ────────────────────────────────────────────────────────────────── */

export async function listPendingBrands() {
  const r = await getList(query(
    collection(db, 'brands'), where('status', '==', 'pending'),
    orderBy('submittedAt', 'desc'), limit(LIST_LIMIT)));
  r.rows.sort(bySubmittedAsc); // 오래된 것 먼저 (design A2)
  return r;
}

export const getBrand = (id) => getOne(doc(db, 'brands', id));
/** brands/{id}/private/profile — 문서 없음은 null (= 사업자 정보 미제출), 읽기 실패는 throw. brandKey 는 화면에 쓰지 않는다. */
export const getBrandPrivate = (id) => getOne(doc(db, 'brands', id, 'private', 'profile'));

/** 전체 브랜드 id→{name,status} 맵. 매장 큐/목록의 "연결 브랜드" 해석용. 실패는 throw. */
export async function loadBrandMap() {
  const snap = await withTimeout(getDocsFromServer(collection(db, 'brands')), READ_TIMEOUT_MS);
  const map = new Map();
  snap.docs.forEach((d) => map.set(d.id, { name: d.data().name ?? '', status: d.data().status ?? null }));
  return map;
}

/* ── 매장 ──────────────────────────────────────────────────────────────────── */

export async function listPendingStores() {
  const r = await getList(query(
    collection(db, 'stores'), where('status', '==', 'pending'),
    orderBy('submittedAt', 'desc'), limit(LIST_LIMIT)));
  r.rows.sort(bySubmittedAsc);
  return r;
}

export const getStore = (id) => getOne(doc(db, 'stores', id));

/**
 * 전체 매장 전량 로드 (클라이언트 페이징). 건수가 늘면 서버 페이징이 필요하다 (한계 — implementation.md).
 * orderBy 를 쓰지 않는다: createdAt 이 없는 옛 문서가 orderBy 로 조용히 빠지는 것을 막는다. 정렬은 클라이언트에서.
 * 페이징 인자를 받는 형태로 분리해 두었다 (DV-7): 지금은 offset/limit 을 무시하고 전량을 돌려준다.
 */
export async function listAllStores(_page = { offset: 0, limit: Infinity }) {
  const snap = await withTimeout(getDocsFromServer(query(collection(db, 'stores'), limit(2000))), READ_TIMEOUT_MS);
  const list = rows(snap);
  list.sort((a, b) => (b.createdAt?.toMillis?.() ?? 0) - (a.createdAt?.toMillis?.() ?? 0));
  return { rows: list, total: list.length, truncated: snap.size >= 2000 };
}

/* ── 마스터 메뉴 / 매장 커스텀 (읽기 전용) ───────────────────────────────────── */

const failWithIndexHint = (label, e) => {
  // 색인 생성 URL 이 message 에 들어 있다. 화면에는 노출하지 않고 콘솔에만 남긴다 (design A6).
  console.error(`[admin] ${label} 조회 실패 (컬렉션 그룹 쿼리: Firestore 색인이 필요할 수 있어요)`, e);
  throw e;
};

export async function listPendingMenus() {
  try {
    const r = await getList(query(
      collectionGroup(db, 'menuItems'), where('scope', '==', 'brand'), where('status', '==', 'pending'),
      orderBy('submittedAt', 'desc'), limit(LIST_LIMIT)));
    // 경로 brands/{brandId}/menuItems/{id} 에서 brandId 를 얻는다.
    r.rows = r.rows.map((x) => ({ ...x, brandId: x.brandId || x._ref.parent.parent?.id || '' }));
    r.rows.sort(bySubmittedAsc);
    return r;
  } catch (e) { return failWithIndexHint('마스터 메뉴 승인 큐', e); }
}

export async function listPendingOverrides() {
  try {
    const r = await getList(query(
      collectionGroup(db, 'menuOverrides'), where('status', '==', 'pending'),
      orderBy('submittedAt', 'desc'), limit(LIST_LIMIT)));
    // 경로 stores/{storeId}/menuOverrides/{masterMenuItemId}
    r.rows = r.rows.map((x) => ({ ...x, storeId: x._ref.parent.parent?.id || '', masterMenuItemId: x.id }));
    r.rows.sort(bySubmittedAsc);
    return r;
  } catch (e) { return failWithIndexHint('매장 커스텀 승인 큐', e); }
}

export const getMasterMenu = (brandId, menuId) => getOne(doc(db, 'brands', brandId, 'menuItems', menuId));

/* ── Qoin (읽기 전용) ──────────────────────────────────────────────────────── */

/** @returns {Promise<null | {rate:{kind,value}, enabled:boolean|null, enabledChangedBy, enabledChangedAt}>} null = 문서 없음 */
export async function getQoinConfig() {
  const data = await getOne(doc(db, 'config', 'qoin'));
  if (data === null) return null;
  return {
    rate: parseGlobalRate(data.accrualRate, Object.prototype.hasOwnProperty.call(data, 'accrualRate')),
    enabled: typeof data.enabled === 'boolean' ? data.enabled : null,
    enabledChangedBy: typeof data.enabledChangedBy === 'string' ? data.enabledChangedBy : null,
    enabledChangedAt: data.enabledChangedAt ?? null,
  };
}

export async function listQoinHistory(n = 20) {
  const snap = await withTimeout(getDocsFromServer(query(
    collection(db, 'config', 'qoin', 'qoinRateHistory'), orderBy('changedAt', 'desc'), limit(n))), READ_TIMEOUT_MS);
  return rows(snap);
}

/* ============================================================================
   쓰기 — 승인/반려 2쌍(브랜드·매장)이 이 콘솔의 쓰기 전부다.
   - 전부 update 다. 문서를 새로 만드는 호출은 이 파일에 없다.
   - users 문서는 읽기만 한다. 역할 변경 코드는 없다.
   - 낙관적 갱신 없음: 이 함수들이 resolve 한 뒤에도 화면은 서버에서 다시 읽어 그린다.
   ========================================================================== */

/**
 * 트랜잭션으로 "읽기 → pending 확인 → update" 를 원자적으로 한다 (다른 admin/앱이 먼저 처리한 건의 덮어쓰기 방지).
 * 트랜잭션은 오프라인에서 큐에 쌓이지 않고 실패한다. 응답이 늦으면 timeout (반영 여부 불명 — 호출자가 단정하지 않는다).
 */
async function guardedUpdate(ref, action, build) {
  const uid = currentUid();
  if (!uid) throw Object.assign(new Error('unauthenticated'), { code: 'unauthenticated' });
  await withTimeout(runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists()) throw new AdminError('not-found');
    const current = snap.data().status;
    if (current !== 'pending') throw new AdminError('already-processed', { current });
    tx.update(ref, assertPayload(action, build(uid)));
  }), WRITE_TIMEOUT_MS);
}

/** 단계 정보를 에러에 붙여 던진다 (모달이 "어느 단계에서 실패했는지" 문구를 고르기 위함). */
async function stage(name, fn) {
  try { return await fn(); } catch (e) {
    if (e && typeof e === 'object') e.stage = name;
    throw e;
  }
}

async function assertPendingNow(ref) {
  const snap = await withTimeout(getDocFromServer(ref), READ_TIMEOUT_MS);
  if (!snap.exists()) throw new AdminError('not-found');
  const current = snap.data().status;
  if (current !== 'pending') throw new AdminError('already-processed', { current });
}

/**
 * 브랜드 승인 — 앱 approveBrand 와 같은 2단계 (D1).
 *   ① issueBrandKey CF (멱등) 성공  →  ② brands/{id} status 쓰기.
 * ① 이 실패하면 brands/{id} 를 건드리지 않는다 (문서 불변). 키 없는 approved 브랜드는 앱 큐에서 영구히 빠지므로 금지.
 * @param {(step:'precheck'|'issueKey'|'record')=>void} onStep
 */
export async function approveBrand(brandId, onStep = () => {}) {
  const ref = doc(db, 'brands', brandId);
  onStep('precheck');
  await stage('precheck', () => assertPendingNow(ref));
  onStep('issueKey');
  await stage('issueKey', async () => {
    const call = httpsCallable(functions, 'issueBrandKey', { timeout: KEY_TIMEOUT_MS });
    const res = await call({ brandId });
    const key = res?.data?.brandKey;
    // 키 없는 성공 응답을 성공으로 취급하지 않는다 (앱 issueBrandKey 와 동일).
    if (typeof key !== 'string' || key.length === 0) throw new AdminError('parse');
  });
  onStep('record');
  await stage('record', () => guardedUpdate(ref, 'brandApprove', (uid) => brandApprovePayload(uid, serverTimestamp)));
}

export async function rejectBrand(brandId, reason) {
  await stage('record', () => guardedUpdate(doc(db, 'brands', brandId), 'brandReject',
    (uid) => brandRejectPayload(uid, reason, serverTimestamp)));
}

/**
 * 매장 승인. 앱은 연결 브랜드가 개인 매장/승인됨일 때만 승인 버튼을 켠다 (StoreBrandLink.approveEnabled, fail-closed).
 * 같은 기준을 쓰기 직전에 서버 값으로 다시 확인한다. 확인 자체가 실패하면 쓰지 않는다.
 */
export async function approveStore(storeId, brandId) {
  const ref = doc(db, 'stores', storeId);
  if (brandId) {
    await stage('precheck', async () => {
      const b = await getOne(doc(db, 'brands', brandId));
      if (b === null || b.status !== 'approved') throw new AdminError('brand-not-approved');
    });
  }
  await stage('record', () => guardedUpdate(ref, 'storeApprove', (uid) => storeApprovePayload(uid, serverTimestamp)));
}

export async function rejectStore(storeId, reason) {
  await stage('record', () => guardedUpdate(doc(db, 'stores', storeId), 'storeReject',
    (uid) => storeRejectPayload(uid, reason, serverTimestamp)));
}

/** "상태 확인하기": 문서를 서버에서 다시 읽어 현재 status 만 돌려준다. */
export async function readCurrentStatus(kind, id) {
  const snap = await withTimeout(getDocFromServer(doc(db, kind === 'brand' ? 'brands' : 'stores', id)), READ_TIMEOUT_MS);
  if (!snap.exists()) throw new AdminError('not-found');
  return snap.data().status ?? null;
}

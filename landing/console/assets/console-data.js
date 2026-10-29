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

   [SDK 버전] 정확한 버전(10.14.1)을 URL 에 고정한다 — 범위 표기(`@10`, `^10`) 금지. 올릴 때는 5개 import 를 함께 바꾼다.

   [역할별 콘솔 — 쓰기 원칙]
   - 모든 쓰기는 console-payloads.js 의 assertPayload 를 통과해야 전송된다 (개발 중 실수 차단. 보안이 아니다 — 권위는 Rules).
   - users 문서는 읽기만 한다. 역할(role) 변경 코드는 없다. approvedAt/approvedBy 를 쓰는 곳은 admin 승인·반려와
     owner.storeCoreResubmit(서버 재읽기로 rejected 를 확인한 트랜잭션 안) 둘뿐이다.
   - 낙관적 갱신 없음: 이 파일의 쓰기 함수가 resolve 한 뒤에도 화면은 서버에서 다시 읽어 그린다.
   - 존재하지 않는 문서에 updateDoc 하면 not-found 가 아니라 permission-denied 가 온다 (Rules 의 resource.data 평가 오류).
     그래서 upsert 는 'updateDoc → not-found → create' 가 아니라 **트랜잭션(읽기 → update | create)** 으로 한다 (spec W-O8 보정).
   ========================================================================== */

import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js';
import {
  getAuth, onAuthStateChanged, signInWithEmailAndPassword, signInWithPopup, GoogleAuthProvider, signOut,
} from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js';
import {
  getFirestore, collection, collectionGroup, doc, query, where, orderBy, limit, startAfter,
  getDocFromServer, getDocsFromServer, getCountFromServer, runTransaction, serverTimestamp,
  deleteField, Timestamp, updateDoc, setDoc, deleteDoc, writeBatch,
} from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js';
import { getFunctions, httpsCallable } from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-functions.js';
import { getStorage, ref as storageRef, uploadBytes, getDownloadURL } from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-storage.js';

import { firebaseWebConfig, FUNCTIONS_REGION } from './firebase-config.js';
import {
  AdminError, parseGlobalRate, classifyRoleDoc, storeSellClass, checkImageFile, SALES_LIMIT, optionItemKey,
} from './console-format.js';
import {
  assertPayload, brandApprovePayload, brandRejectPayload, storeApprovePayload, storeRejectPayload,
  brandOperationPayload, brandCorePayload, privateProfilePayload, menuCreatePayload, menuCorePayload,
  personalMenuUpdatePayload, menuOperationPayload, MASTER_OPS_KEYS, STORE_MENU_OPS_KEYS,
  overrideSubmitUpdatePayload, overrideSubmitCreatePayload, storeOperationPayload, storeCorePayload,
  overrideSoldOutPayload, overrideOptionDisablePayload, overrideCreatePayload, subCategoryPayload,
  optionGroupPayload, activeTogglePayload,
} from './console-payloads.js';

let app; let auth; let db; let functions; let storage;

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
  storage = getStorage(app);
}

/** SDK 센티널 주입 — console-payloads.js 는 SDK 를 모른다. */
const sdk = { ts: () => serverTimestamp(), del: () => deleteField(), toTs: (d) => Timestamp.fromDate(d) };

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
 * users/{uid} 를 서버에서 1회 읽어 역할을 판정한다 (DV-3).
 * 읽기 **실패**·타임아웃은 throw (호출자가 fail-closed 로 닫는다). 문서/필드 **부재**는 'customer' (Rules userRole() 과 동일).
 * 이 결과는 "어느 셸을 열지" 정하는 UX 판단일 뿐이다. 이후 모든 요청은 Rules 가 다시 판정한다.
 * @returns {Promise<{kind:'ok', exists:boolean, role:string, brandId:string} | {kind:'unknown', exists:true, raw:any, brandId:string}>}
 */
export async function readUserRole(uid) {
  const snap = await withTimeout(getDocFromServer(doc(db, 'users', uid)), READ_TIMEOUT_MS);
  return classifyRoleDoc(snap.exists(), snap.data());
}

/** users/{uid} 원문 (customer 프로필용). 문서 부재는 {exists:false, data:{}} — 오류가 아니다. 읽기 실패는 throw. */
export async function readUserProfile(uid) {
  const snap = await withTimeout(getDocFromServer(doc(db, 'users', uid)), READ_TIMEOUT_MS);
  const data = snap.exists() ? snap.data() : {};
  if (data === null || typeof data !== 'object') throw new AdminError('parse');
  return { exists: snap.exists(), data };
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
    tx.update(ref, assertPayload(action, build(uid), { uid }));
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
  await stage('record', () => guardedUpdate(ref, 'admin.brandApprove', (uid) => brandApprovePayload(uid, serverTimestamp)));
}

export async function rejectBrand(brandId, reason) {
  await stage('record', () => guardedUpdate(doc(db, 'brands', brandId), 'admin.brandReject',
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
  await stage('record', () => guardedUpdate(ref, 'admin.storeApprove', (uid) => storeApprovePayload(uid, serverTimestamp)));
}

export async function rejectStore(storeId, reason) {
  await stage('record', () => guardedUpdate(doc(db, 'stores', storeId), 'admin.storeReject',
    (uid) => storeRejectPayload(uid, reason, serverTimestamp)));
}

/** "상태 확인하기": 문서를 서버에서 다시 읽어 현재 status 만 돌려준다. */
export async function readCurrentStatus(kind, id) {
  const snap = await withTimeout(getDocFromServer(doc(db, kind === 'brand' ? 'brands' : 'stores', id)), READ_TIMEOUT_MS);
  if (!snap.exists()) throw new AdminError('not-found');
  return snap.data().status ?? null;
}

/* ============================================================================
   공통 헬퍼 (역할별 콘솔)
   ========================================================================== */

const uidOrThrow = () => {
  const uid = currentUid();
  if (!uid) throw Object.assign(new Error('unauthenticated'), { code: 'unauthenticated' });
  return uid;
};

/** payload 검사 → updateDoc. 문서가 있어야 하는 쓰기 전용. */
async function sendUpdate(ref, action, payload, ctx = {}) {
  assertPayload(action, payload, { uid: uidOrThrow(), ...ctx });
  await withTimeout(updateDoc(ref, payload), WRITE_TIMEOUT_MS);
}

/**
 * upsert = 트랜잭션(읽기 → 있으면 update / 없으면 create). stale read 로 create 분기를 타서 update 로 판정되는 레이스(ⓕ)를 막고,
 * 존재하지 않는 문서에 updateDoc 하면 permission-denied 가 오는 Rules 동작을 피한다.
 * @param {(snap)=>({action:string, payload:object, ctx?:object}|null)} onExists  null 이면 아무것도 쓰지 않는다
 * @param {()=>({action:string, payload:object, ctx?:object})} onMissing
 */
async function upsertTx(ref, onExists, onMissing) {
  const uid = uidOrThrow();
  await withTimeout(runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists()) {
      const w = onExists(snap);
      if (w) tx.update(ref, assertPayload(w.action, w.payload, { uid, ...(w.ctx || {}) }));
    } else {
      const w = onMissing();
      tx.set(ref, assertPayload(w.action, w.payload, { uid, ...(w.ctx || {}) }));
    }
  }), WRITE_TIMEOUT_MS);
}

/** 이미지 업로드 (5MB 상한을 모든 업로드에 건다 — 앱의 매장 이미지 검증 누락 ⓙ 를 복제하지 않는다). */
export async function uploadImage(pathPrefix, file) {
  const chk = checkImageFile(file);
  if (!chk.ok) throw new AdminError('validation', { message: chk.error });
  const safe = String(file.name || 'image').replace(/[\\/]/g, '_');
  const r = storageRef(storage, `${pathPrefix}/${Date.now()}_${safe}`);
  await withTimeout(uploadBytes(r, file, { contentType: file.type || 'image/jpeg' }), WRITE_TIMEOUT_MS * 3);
  return withTimeout(getDownloadURL(r), READ_TIMEOUT_MS);
}
export const storagePaths = Object.freeze({
  storeImage: (ownerId) => `store_images/${ownerId}`,
  brandLogo: (brandId) => `brand_images/${brandId}`,
  masterMenu: (brandId, menuId) => `menu_images/brand/${brandId}/${menuId || `new_${Date.now()}`}`,
  storeMenu: (storeId, menuId) => `menu_images/store/${storeId}/${menuId || `new_${Date.now()}`}`,
});

/** 서버에서 새 문서 ID 만 만든다 (네트워크 호출 없음). */
export const newDocId = (...path) => doc(collection(db, ...path)).id;

/* ── 공용 조회 ─────────────────────────────────────────────────────────────── */
export async function listMainCategories() {
  const snap = await withTimeout(getDocsFromServer(collection(db, 'mainCategories')), READ_TIMEOUT_MS);
  return rows(snap).map((c) => ({ id: c.id, label: c.label || c.id, displayOrder: c.displayOrder ?? 0, active: c.active !== false }))
    .sort((a, b) => a.displayOrder - b.displayOrder);
}
/** 최상위 optionGroups (scope: master) — 관리자가 관리한다. */
export async function listMasterOptionGroups() {
  const snap = await withTimeout(getDocsFromServer(collection(db, 'optionGroups')), READ_TIMEOUT_MS);
  return rows(snap).map((g) => ({ ...g, scope: 'master' })).sort((a, b) => (a.displayOrder ?? 0) - (b.displayOrder ?? 0));
}

/* ============================================================================
   customer — 읽기 전용 (Q6)
   ========================================================================== */

/** users/{uid}/orderLogs — paidAt 최신순. cursor 는 이전 호출이 돌려준 마지막 행의 _snap. */
export async function listOrderLogs(uid, cursor = null, n = 25) {
  const parts = [orderBy('paidAt', 'desc')];
  if (cursor) parts.push(startAfter(cursor));
  parts.push(limit(n));
  const snap = await withTimeout(getDocsFromServer(query(collection(db, 'users', uid, 'orderLogs'), ...parts)), READ_TIMEOUT_MS);
  return { rows: snap.docs.map((d) => ({ id: d.id, ...d.data(), _snap: d })), hasMore: snap.size >= n };
}

/** users/{uid}/qoinTransactions — append-only 원장 (CF 전담). createdAt 최신순. */
export async function listQoinTransactions(uid, cursor = null, n = 25) {
  const parts = [orderBy('createdAt', 'desc')];
  if (cursor) parts.push(startAfter(cursor));
  parts.push(limit(n));
  const snap = await withTimeout(getDocsFromServer(query(collection(db, 'users', uid, 'qoinTransactions'), ...parts)), READ_TIMEOUT_MS);
  return { rows: snap.docs.map((d) => ({ id: d.id, ...d.data(), _snap: d })), hasMore: snap.size >= n };
}

/* ============================================================================
   owner
   ========================================================================== */

/** stores where ownerId == uid (MVP: 점주 1매장 가정 — 2건 이상이면 호출자가 알린다). orderBy 없음 → 인덱스 불필요. */
export async function listMyStores(uid) {
  const snap = await withTimeout(getDocsFromServer(query(collection(db, 'stores'), where('ownerId', '==', uid), limit(5))), READ_TIMEOUT_MS);
  return rows(snap);
}

/**
 * 기간 내 주문. **where storeId== 를 반드시 포함**한다 (빼면 Rules 가 쿼리 전체를 거부한다 — rules-aware query).
 * 서버 강제 읽기: 캐시를 쓰면 0원이 정상 수치처럼 보인다 (앱 코드가 경고한 지점).
 * 인덱스: orders (storeId ASC, createdAt DESC) 존재.
 */
export async function listStoreOrdersInPeriod(storeId, period) {
  const q = query(
    collection(db, 'orders'),
    where('storeId', '==', storeId),
    where('createdAt', '>=', Timestamp.fromDate(period.start)),
    where('createdAt', '<', Timestamp.fromDate(period.endExclusive)),
    orderBy('createdAt', 'desc'),
    limit(SALES_LIMIT),
  );
  const snap = await withTimeout(getDocsFromServer(q), READ_TIMEOUT_MS);
  const list = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  return { rows: list, truncated: list.length >= SALES_LIMIT };
}

/** reviews where storeId == X (인덱스 storeId,createdAt 존재). 점주는 읽기만 한다 — 답글·신고 없음. */
export async function listStoreReviews(storeId, n = 200) {
  const snap = await withTimeout(getDocsFromServer(query(collection(db, 'reviews'), where('storeId', '==', storeId), orderBy('createdAt', 'desc'), limit(n))), READ_TIMEOUT_MS);
  return { rows: rows(snap), truncated: snap.size >= n };
}

export async function listQoinHistoryOf(parentPath, n = 20) {
  const snap = await withTimeout(getDocsFromServer(query(collection(db, ...parentPath, 'qoinRateHistory'), orderBy('changedAt', 'desc'), limit(n))), READ_TIMEOUT_MS);
  return rows(snap);
}

export async function listSubCollection(parentPath, name, orderField = 'displayOrder') {
  const snap = await withTimeout(getDocsFromServer(query(collection(db, ...parentPath, name), orderBy(orderField))), READ_TIMEOUT_MS);
  return rows(snap);
}
/** orderBy 에서 빠지는 문서(필드 없는 옛 문서)가 없도록 정렬 없이 전부 읽고 클라이언트에서 정렬한다. */
export async function listAll(parentPath, name) {
  const snap = await withTimeout(getDocsFromServer(collection(db, ...parentPath, name)), READ_TIMEOUT_MS);
  return rows(snap).sort((a, b) => (a.displayOrder ?? 0) - (b.displayOrder ?? 0));
}
export const getStoreFresh = (id) => getOne(doc(db, 'stores', id));

/** 매장 운영 정보 (폼 ①) — 바뀐 필드만. status·승인 메타를 건드리지 않는다. */
export async function saveStoreOperation(storeId, changes, fallbackImageUrl = '') {
  await sendUpdate(doc(db, 'stores', storeId), 'owner.storeOperation', storeOperationPayload(changes, sdk, fallbackImageUrl));
}

/**
 * 매장 핵심 정보 (폼 ②) — 🔴 서버 상태를 트랜잭션 안에서 다시 읽어 payload 를 정한다 (DV-5).
 *   · 서버 status === 'rejected' 일 때만 재제출 payload(승인 메타 null 클리어)를 만든다.
 *   · 그 외에는 approvedBy/approvedAt/rejectedAt/rejectedReason 키가 payload 에 없다 → canSellNow 가 흔들리지 않는다.
 *   · 화면(모달)이 보여 준 3갈래(expectedClass)와 서버 값이 다르면 쓰지 않고 'state-changed' 로 돌려보낸다.
 * @returns {Promise<'A'|'B'|'C'>} 쓴 시점의 서버 기준 분류
 */
export async function submitStoreCore(storeId, changes, expectedClass) {
  const uid = uidOrThrow();
  const ref = doc(db, 'stores', storeId);
  let cls = 'X';
  await withTimeout(runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists()) throw new AdminError('not-found');
    const cur = snap.data();
    if (cur.brandId) throw new AdminError('validation', { message: '브랜드 가맹 매장의 핵심 정보는 브랜드 본사가 관리해요.' }); // 앱과 동일 (design U2)
    cls = storeSellClass(cur);
    if (cls === 'X') throw new AdminError('state-changed', { current: cls });
    if (expectedClass && cls !== expectedClass) throw new AdminError('state-changed', { current: cls });
    const resubmit = cur.status === 'rejected';
    const full = resubmit
      ? { name: 'name' in changes ? changes.name : cur.name, businessRegistrationNumber: 'businessRegistrationNumber' in changes ? changes.businessRegistrationNumber : (cur.businessRegistrationNumber ?? null) }
      : changes;
    const { action, payload } = storeCorePayload(full, uid, sdk, { resubmit });
    tx.update(ref, assertPayload(action, payload, { uid }));
  }), WRITE_TIMEOUT_MS);
  return cls;
}

/* ── owner / brand 공통: 메뉴 (개인 매장 · 점포 한정 · 마스터) ───────────────── */
export const listStoreMenus = (storeId) => listSubCollection(['stores', storeId], 'menuItems');
export const listStoreOverrides = (storeId) => listAll(['stores', storeId], 'menuOverrides');
export const listMasterMenus = (brandId) => listSubCollection(['brands', brandId], 'menuItems');

/** 개인 매장 메뉴 등록 — approved 로 즉시 반영 (승인 큐 미경유). */
export async function createPersonalMenu(storeId, form) {
  const uid = uidOrThrow();
  const id = newDocId('stores', storeId, 'menuItems');
  const payload = menuCreatePayload(form, { scope: 'store', status: 'approved', uid }, sdk);
  assertPayload('owner.personalMenuCreate', payload, { uid });
  await withTimeout(setDoc(doc(db, 'stores', storeId, 'menuItems', id), payload), WRITE_TIMEOUT_MS);
  return id;
}
export async function updatePersonalMenu(storeId, menuId, changed) {
  await sendUpdate(doc(db, 'stores', storeId, 'menuItems', menuId), 'owner.personalMenuUpdate', personalMenuUpdatePayload(changed, sdk));
}
/** 노출/품절 토글 — 운영 8키 경로 (핵심 전체 update 가 아니다: createdAt 리셋·description 미삭제 ⓒⓓⓔ 방지). */
export async function updateStoreMenuOperation(storeId, menuId, changed, role) {
  const action = role === 'brand' ? 'brand.storeOnlyMenuOperation' : 'owner.personalMenuOperation';
  await sendUpdate(doc(db, 'stores', storeId, 'menuItems', menuId), action, menuOperationPayload(changed, sdk, STORE_MENU_OPS_KEYS));
}
export async function deleteStoreMenu(storeId, menuId) {
  await withTimeout(deleteDoc(doc(db, 'stores', storeId, 'menuItems', menuId)), WRITE_TIMEOUT_MS);
}

/** 점포 한정 메뉴(브랜드 매장) 등록 — pending 제출. */
export async function createStoreOnlyMenu(storeId, brandId, form) {
  const uid = uidOrThrow();
  const id = newDocId('stores', storeId, 'menuItems');
  const payload = menuCreatePayload(form, { scope: 'store', brandId, status: 'pending', uid }, sdk);
  assertPayload('brand.storeOnlyMenuCreate', payload, { uid, brandId });
  await withTimeout(setDoc(doc(db, 'stores', storeId, 'menuItems', id), payload), WRITE_TIMEOUT_MS);
  return id;
}
export async function submitStoreOnlyMenuCore(storeId, menuId, changed) {
  const uid = uidOrThrow();
  await sendUpdate(doc(db, 'stores', storeId, 'menuItems', menuId), 'brand.storeOnlyMenuCore', menuCorePayload(changed, uid, sdk));
}

/* ── owner: 브랜드 매장 — 품절 · 옵션 비활성만 (오버라이드 문서) ───────────────── */
function ownerOverrideCtx(store, masterId) {
  if (!store?.brandId) throw new AdminError('validation', { message: '브랜드 매장이 아니에요.' });
  return { masterMenuItemId: masterId, storeId: store.id, brandId: store.brandId };
}

/** 품절 토글 — 3키만. 문서가 없으면 트랜잭션 안에서 16키 create (masterMenuItemId 포함, Q2). */
export async function setOverrideSoldOut(store, masterId, soldOut) {
  const uid = uidOrThrow();
  const base = ownerOverrideCtx(store, masterId);
  await upsertTx(
    doc(db, 'stores', store.id, 'menuOverrides', masterId),
    () => ({ action: 'owner.overrideSoldOut', payload: overrideSoldOutPayload(soldOut, sdk) }),
    () => ({ action: 'owner.overrideCreate', payload: overrideCreatePayload({ ...base, soldOut: !!soldOut }, uid, sdk) }),
  );
}

/** 옵션 비활성 — 4키. disabledOptionItemIds 원소는 복합 id `{groupId}_{itemId}`. */
export async function setOverrideOptionDisable(store, masterId, groupIds, itemIds) {
  const uid = uidOrThrow();
  const base = ownerOverrideCtx(store, masterId);
  await upsertTx(
    doc(db, 'stores', store.id, 'menuOverrides', masterId),
    () => ({ action: 'owner.overrideOptionDisable', payload: overrideOptionDisablePayload(groupIds, itemIds, sdk) }),
    () => ({ action: 'owner.overrideCreate', payload: overrideCreatePayload({ ...base, disabledOptionGroupIds: [...groupIds], disabledOptionItemIds: [...itemIds] }, uid, sdk) }),
  );
}
export { optionItemKey };

/* ── 서브 카테고리 / 옵션 그룹 (owner=매장, brand=브랜드) ───────────────────── */
const subPath = (scope, ownerId) => [scope === 'brand' ? 'brands' : 'stores', ownerId, 'subCategories'];
const optPath = (scope, ownerId) => [scope === 'brand' ? 'brands' : 'stores', ownerId, 'optionGroups'];

/** 이름 중복(대소문자 무시, trim) — 저장 직전 서버에서 다시 읽어 비교한다. */
export async function hasDuplicateName(scope, kind, ownerId, name, excludeId = null) {
  const path = kind === 'sub' ? subPath(scope, ownerId) : optPath(scope, ownerId);
  const snap = await withTimeout(getDocsFromServer(collection(db, ...path)), READ_TIMEOUT_MS);
  const want = String(name).trim().toLowerCase();
  return snap.docs.some((d) => d.id !== excludeId && String(d.data().normalizedName ?? d.data().name ?? '').trim().toLowerCase() === want);
}

export async function saveSubCategory(scope, ownerId, form, existingId = null) {
  const uid = uidOrThrow();
  const role = scope === 'brand' ? 'brand' : 'owner';
  const ctx = { uid, brandId: ownerId };
  if (await hasDuplicateName(scope, 'sub', ownerId, form.name, existingId)) throw new AdminError('validation', { message: '이미 같은 이름의 분류가 있어요', field: 'name' });
  const c = { scope, brandId: ownerId, storeId: ownerId, isNew: !existingId };
  const payload = subCategoryPayload(form, c, sdk);
  assertPayload(`${role}.subCategory`, payload, ctx);
  if (existingId) {
    // 편집: createdAt 을 보내지 않는다. 같은 키 집합이므로 updateDoc.
    await withTimeout(updateDoc(doc(db, ...subPath(scope, ownerId), existingId), payload), WRITE_TIMEOUT_MS);
    return existingId;
  }
  const id = `${form.mainCategory}_${Date.now()}`; // 문서 ID 는 클라이언트 생성 (앱과 동일)
  await withTimeout(setDoc(doc(db, ...subPath(scope, ownerId), id), payload), WRITE_TIMEOUT_MS);
  return id;
}

export async function saveOptionGroup(scope, ownerId, form, existingId = null) {
  const uid = uidOrThrow();
  const role = scope === 'brand' ? 'brand' : 'owner';
  if (await hasDuplicateName(scope, 'opt', ownerId, form.name, existingId)) throw new AdminError('validation', { message: '이미 같은 이름의 옵션 그룹이 있어요', field: 'name' });
  const payload = optionGroupPayload(form, { isNew: !existingId }, sdk);
  assertPayload(`${role}.optionGroup`, payload, { uid });
  if (existingId) {
    await withTimeout(updateDoc(doc(db, ...optPath(scope, ownerId), existingId), payload), WRITE_TIMEOUT_MS);
    return existingId;
  }
  const id = newDocId(...optPath(scope, ownerId));
  await withTimeout(setDoc(doc(db, ...optPath(scope, ownerId), id), payload), WRITE_TIMEOUT_MS);
  return id;
}

export async function toggleActive(scope, kind, ownerId, id, active) {
  const role = scope === 'brand' ? 'brand' : 'owner';
  const path = kind === 'sub' ? subPath(scope, ownerId) : optPath(scope, ownerId);
  await sendUpdate(doc(db, ...path, id), `${role}.activeToggle`, activeTogglePayload(active, sdk));
}

export async function deleteSubOrOption(scope, kind, ownerId, id) {
  const path = kind === 'sub' ? subPath(scope, ownerId) : optPath(scope, ownerId);
  await withTimeout(deleteDoc(doc(db, ...path, id)), WRITE_TIMEOUT_MS);
}

/** 서브 카테고리 사용 수 — menuItems 컬렉션 그룹 subCategoryId 단일 필드 (fieldOverrides 에 COLLECTION_GROUP 인덱스 존재). 실패는 throw → 삭제 차단. */
export async function countSubCategoryUsage(subCategoryId) {
  return countOf(query(collectionGroup(db, 'menuItems'), where('subCategoryId', '==', subCategoryId)));
}

/* ============================================================================
   brand
   ========================================================================== */

/** brands where submittedBy == uid (미연결 복구용, 단일 필드). 앱과 같이 가장 이른 submittedAt 이 먼저. */
export async function listSubmittedBrands(uid) {
  const snap = await withTimeout(getDocsFromServer(query(collection(db, 'brands'), where('submittedBy', '==', uid))), READ_TIMEOUT_MS);
  return rows(snap).sort((a, b) => {
    const x = a.submittedAt?.toMillis?.() ?? null; const y = b.submittedAt?.toMillis?.() ?? null;
    if (x === null && y === null) return a.id < b.id ? -1 : 1;
    if (x === null) return 1;
    if (y === null) return -1;
    return x !== y ? x - y : (a.id < b.id ? -1 : 1);
  });
}

/** claimSubmittedBrand CF — 이 콘솔의 brand/owner 섹션 유일한 CF 호출. 에러의 details.reason 으로 분기한다. */
export async function claimSubmittedBrand(brandId) {
  const call = httpsCallable(functions, 'claimSubmittedBrand', { timeout: KEY_TIMEOUT_MS });
  await call({ brandId });
}

/** 산하 매장 (승인된 가맹점만 — R-B3). 인덱스 stores(brandId, status, createdAt DESC) 존재. */
export async function listBrandStores(brandId) {
  const snap = await withTimeout(getDocsFromServer(query(collection(db, 'stores'),
    where('brandId', '==', brandId), where('status', '==', 'approved'), orderBy('createdAt', 'desc'), limit(LIST_LIMIT))), READ_TIMEOUT_MS);
  return { rows: rows(snap), truncated: snap.size >= LIST_LIMIT };
}

/** 이 브랜드의 모든 매장 (상태 무관, 단일 필드) — 마스터 삭제 cascade 의 영향 범위 계산용. */
async function listAllBrandStoreIds(brandId) {
  const snap = await withTimeout(getDocsFromServer(query(collection(db, 'stores'), where('brandId', '==', brandId), limit(2000))), READ_TIMEOUT_MS);
  return snap.docs.map((d) => ({ id: d.id, name: d.data().name || '' }));
}

/** 브랜드 정보 수정 — 운영 폼: brands 문서 + (선택) private/profile 을 **한 배치**로 (DV-14). */
export async function saveBrandOperation(brandId, brandChanges, piiChanges) {
  const uid = uidOrThrow();
  const batch = writeBatch(db);
  let n = 0;
  if (brandChanges && Object.keys(brandChanges).length > 0) {
    const p = brandOperationPayload(brandChanges, sdk);
    assertPayload('brand.brandOperation', p, { uid });
    batch.update(doc(db, 'brands', brandId), p); n++;
  }
  if (piiChanges && Object.keys(piiChanges).length > 0) {
    const pRef = doc(db, 'brands', brandId, 'private', 'profile');
    const snap = await withTimeout(getDocFromServer(pRef), READ_TIMEOUT_MS);
    const p = privateProfilePayload(piiChanges, sdk);
    if (snap.exists()) { assertPayload('brand.privateProfileUpdate', p, { uid }); batch.update(pRef, p); }
    else { assertPayload('brand.privateProfileCreate', p, { uid }); batch.set(pRef, p); } // B3: 문서 부재 시에만 create
    n++;
  }
  if (n === 0) return;
  await withTimeout(batch.commit(), WRITE_TIMEOUT_MS);
}

/** 브랜드 핵심 정보 — name/description. status pending 회귀. 승인 메타·brandKey·createdAt 은 보내지 않는다. */
export async function submitBrandCore(brandId, changes) {
  const uid = uidOrThrow();
  await sendUpdate(doc(db, 'brands', brandId), 'brand.brandCore', brandCorePayload(changes, uid, sdk));
}

/** 마스터 메뉴 등록 (pending 제출). */
export async function createMasterMenu(brandId, form) {
  const uid = uidOrThrow();
  const id = newDocId('brands', brandId, 'menuItems');
  const payload = menuCreatePayload(form, { scope: 'brand', brandId, status: 'pending', uid }, sdk);
  assertPayload('brand.masterMenuCreate', payload, { uid, brandId });
  await withTimeout(setDoc(doc(db, 'brands', brandId, 'menuItems', id), payload), WRITE_TIMEOUT_MS);
  return id;
}
/** 마스터 메뉴 핵심 수정 — pending 회귀, approvedBy/approvedAt 보존(보내지 않는다). */
export async function submitMasterMenuCore(brandId, menuId, changed) {
  const uid = uidOrThrow();
  await sendUpdate(doc(db, 'brands', brandId, 'menuItems', menuId), 'brand.masterMenuCore', menuCorePayload(changed, uid, sdk));
}
/** 마스터 메뉴 운영 수정 — 5키 + disabledOption* (Q4). 노출 스위치도 이 경로. */
export async function updateMasterMenuOperation(brandId, menuId, changed) {
  await sendUpdate(doc(db, 'brands', brandId, 'menuItems', menuId), 'brand.masterMenuOperation', menuOperationPayload(changed, sdk, MASTER_OPS_KEYS));
}

/**
 * 마스터 메뉴 삭제 cascade (W-B8, 앱에는 신뢰할 구현이 없다 — spec ⓛ).
 * 오버라이드 문서 ID = masterMenuItemId 이므로, 인덱스가 필요한 컬렉션 그룹 쿼리 대신 **매장별 문서 ID 조회**로 대상을 찾는다.
 * (masterMenuItemId 필드가 없는 점주 생성 오버라이드 ⓑ 도 ID 로는 찾아진다.)
 * @returns {Promise<{refs:Array, stores:number}>}  refs = 지울 오버라이드 문서 참조
 */
export async function findMasterOverrides(brandId, menuId) {
  const stores = await listAllBrandStoreIds(brandId);
  const found = [];
  const queue = [...stores];
  const worker = async () => {
    while (queue.length) {
      const s = queue.shift();
      const r = doc(db, 'stores', s.id, 'menuOverrides', menuId);
      const snap = await withTimeout(getDocFromServer(r), READ_TIMEOUT_MS); // 하나라도 실패하면 throw → 호출자가 삭제를 막는다
      if (snap.exists()) found.push({ ref: r, storeId: s.id, storeName: s.name });
    }
  };
  await Promise.all(Array.from({ length: 6 }, worker));
  return { refs: found, stores: stores.length };
}

/** Rules 접근 예산(배치 20, 매장마다 get(stores/{id}) 1회) 안의 청크 크기 — 실측은 implementation.md. */
export const CASCADE_CHUNK = 8;

/** ① 오버라이드 청크 삭제 → ② 마스터 삭제. 중간에 멈춰도 마스터 문서가 남아 재시도가 이어서 한다. */
export async function deleteMasterMenuCascade(brandId, menuId, refs, onProgress = () => {}) {
  let done = 0;
  for (let i = 0; i < refs.length; i += CASCADE_CHUNK) {
    const batch = writeBatch(db);
    refs.slice(i, i + CASCADE_CHUNK).forEach((o) => batch.delete(o.ref));
    await stage('overrides', () => withTimeout(batch.commit(), WRITE_TIMEOUT_MS));
    done += Math.min(CASCADE_CHUNK, refs.length - i);
    onProgress(done, refs.length);
  }
  await stage('menu', () => withTimeout(deleteDoc(doc(db, 'brands', brandId, 'menuItems', menuId)), WRITE_TIMEOUT_MS));
}

/**
 * 가격 오버라이드 제출 (W-B9) — 트랜잭션(읽기 → update | create).
 * 🔴 승인 메타(approvedBy/approvedAt)는 어느 분기에서도 보내지 않는다. soldOut/disabledOption*(점주 설정)도 update 에서 보존.
 * @param {number|null} expectedPrice  모달이 보여 준 "재제출 중 적용가" 검증용 아님 — 그냥 값 전달
 */
export async function submitPriceOverride(storeId, brandId, masterId, { priceOverride, excluded }) {
  const uid = uidOrThrow();
  await upsertTx(
    doc(db, 'stores', storeId, 'menuOverrides', masterId),
    () => ({ action: 'brand.overrideSubmitUpdate', payload: overrideSubmitUpdatePayload({ priceOverride, excluded }, uid, sdk), ctx: { brandId } }),
    () => ({ action: 'brand.overrideSubmitCreate', payload: overrideSubmitCreatePayload({ masterMenuItemId: masterId, storeId, brandId, priceOverride, excluded }, uid, sdk), ctx: { brandId } }),
  );
}

/** U6: 재제출 직전 서버 상태 (현재 적용가 계산용). 읽기 실패는 throw → 모달을 열지 않는다. */
export async function readOverrideAndMaster(storeId, brandId, masterId) {
  const [ov, master] = await Promise.all([
    getOne(doc(db, 'stores', storeId, 'menuOverrides', masterId)),
    getOne(doc(db, 'brands', brandId, 'menuItems', masterId)),
  ]);
  return { override: ov, master };
}

/** 검토 현황용 — 매장 한 곳의 오버라이드·점포 한정 메뉴 (인덱스 없는 컬렉션 그룹 쿼리 대신 매장별 조회). */
export async function loadTrackingForStore(storeId) {
  const [ovs, menus] = await Promise.all([listAll(['stores', storeId], 'menuOverrides'), listAll(['stores', storeId], 'menuItems')]);
  return { overrides: ovs, storeMenus: menus };
}

/* ── 옵션 그룹 참조 해석 / 사용 수 ────────────────────────────────────────────── */

/**
 * optionGroupRefs [{scope:'master'|'brand'|'store', id}] → 그룹 문서 배열 (없으면 null 항목). 하나라도 읽기 실패하면 throw.
 * 경로: master → optionGroups/{id} · brand → brands/{brandId}/optionGroups/{id} · store → stores/{storeId}/optionGroups/{id}
 */
export async function fetchOptionGroups(refs, { brandId, storeId }) {
  const one = async (r) => {
    let ref;
    if (r.scope === 'master') ref = doc(db, 'optionGroups', r.id);
    else if (r.scope === 'brand' && brandId) ref = doc(db, 'brands', brandId, 'optionGroups', r.id);
    else if (r.scope === 'store' && storeId) ref = doc(db, 'stores', storeId, 'optionGroups', r.id);
    else return null;
    const g = await getOne(ref);
    return g ? { ...g, scope: r.scope } : null;
  };
  return Promise.all((refs || []).map(one));
}

/**
 * 옵션 그룹 사용 수 — 컬렉션 그룹 arrayContains 쿼리(복합 인덱스 보장 없음) 대신 메뉴를 읽어 센다.
 * 하나라도 읽기 실패하면 throw → 호출자가 "사용 여부를 확인하지 못해 삭제할 수 없어요" 로 삭제를 막는다.
 */
export async function countOptionGroupUsage(scope, ownerId, groupId) {
  const uses = (m) => (Array.isArray(m.optionGroupRefs) && m.optionGroupRefs.some((r) => r && r.id === groupId))
    || (Array.isArray(m.optionGroupRefIds) && m.optionGroupRefIds.includes(groupId));
  if (scope === 'store') return (await listAll(['stores', ownerId], 'menuItems')).filter(uses).length;
  const [master, stores] = await Promise.all([listAll(['brands', ownerId], 'menuItems'), listAllBrandStoreIds(ownerId)]);
  let n = master.filter(uses).length;
  const queue = [...stores];
  await Promise.all(Array.from({ length: 6 }, async () => {
    while (queue.length) {
      const s = queue.shift();
      n += (await listAll(['stores', s.id], 'menuItems')).filter(uses).length;
    }
  }));
  return n;
}

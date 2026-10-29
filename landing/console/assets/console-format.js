/* ============================================================================
   표시 형식 / 오류 분류 / 입력 검증 — Firebase SDK 를 import 하지 않는 순수 모듈.
   ========================================================================== */

export const esc = (v) =>
  String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

const pad = (n) => String(n).padStart(2, '0');

export function toDate(v) {
  if (!v) return null;
  if (v instanceof Date) return v;
  if (typeof v.toDate === 'function') {
    try { return v.toDate(); } catch (_) { return null; }
  }
  return null;
}

export function fmtDateTime(v) {
  const d = toDate(v);
  if (!d || Number.isNaN(d.getTime())) return '-';
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export function fmtShortDateTime(v) {
  const d = toDate(v);
  if (!d || Number.isNaN(d.getTime())) return '-';
  return `${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export function fmtClock(d = new Date()) {
  return `${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export function shortUid(uid) {
  if (typeof uid !== 'string' || uid.length === 0) return '-';
  return uid.length <= 10 ? uid : `${uid.slice(0, 4)}…${uid.slice(-2)}`;
}

export function fmtKrw(n) {
  if (typeof n !== 'number' || !Number.isFinite(n)) return '-';
  return `${n.toLocaleString('ko-KR')}원`;
}

/** http(s) URL 만 통과시킨다 (javascript: 등 차단). 아니면 ''. */
export function safeUrl(u) {
  if (typeof u !== 'string') return '';
  try {
    const p = new URL(u);
    return p.protocol === 'https:' || p.protocol === 'http:' ? p.href : '';
  } catch (_) {
    return '';
  }
}

/* ── Qoin 전역 적립률 (lib/core/utils/qoin_policy.dart 와 같은 경계: 0.1% ~ 20%, 전역은 0 도 무효) ── */
export const RATE_MIN = 0.001;
export const RATE_MAX = 0.2;

/** @returns {{kind:'absent'|'valid'|'invalid', value:number|null}} 숫자를 못 읽은 것을 0 으로 읽지 않는다. */
export function parseGlobalRate(raw, present) {
  if (!present || raw === undefined || raw === null) return { kind: 'absent', value: null };
  if (typeof raw !== 'number' || !Number.isFinite(raw)) return { kind: 'invalid', value: null };
  if (raw < RATE_MIN || raw > RATE_MAX) return { kind: 'invalid', value: null };
  return { kind: 'valid', value: raw };
}

export function fmtRatePct(rate) {
  if (typeof rate !== 'number' || !Number.isFinite(rate)) return '미설정';
  return `${(Math.round(rate * 1000) / 10).toFixed(1)} %`;
}

/** 'pending'|'approved'|'rejected' 외는 null. (stores 는 status 누락 시 approved 로 취급 — 앱 T1 과 동일, 호출자가 처리) */
export function normalizeStatus(raw) {
  return raw === 'pending' || raw === 'approved' || raw === 'rejected' ? raw : null;
}

export const STATUS_LABEL = Object.freeze({ pending: '대기', approved: '승인됨', rejected: '반려됨' });

/* ── 반려 사유 (D2: 상한 없음. 필수 + trim 후 1자 이상) ─────────────────────────── */
export function validateReason(input) {
  const value = typeof input === 'string' ? input.trim() : '';
  return { ok: value.length > 0, value };
}

/* ── 오류 분류 ─────────────────────────────────────────────────────────────── */
export class AdminError extends Error {
  constructor(code, extra = {}) {
    super(code);
    this.name = 'AdminError';
    this.code = code;
    Object.assign(this, extra);
  }
}

/**
 * SDK 별 코드(`functions/…`, `firestore/…`, `auth/…`)를 정규화해 분류한다.
 * 원문 메시지·스택은 화면에 쓰지 않는다 (호출자가 console 로만 남긴다).
 * @returns {{kind:string, code:string}}
 */
export function classifyError(e) {
  const raw = typeof e?.code === 'string' ? e.code : '';
  const code = raw.replace(/^(functions|firestore)\//, '');
  const msg = typeof e?.message === 'string' ? e.message : '';
  if (e?.name === 'AdminError') {
    if (code === 'parse') return { kind: 'parse', code };
    if (code === 'timeout') return { kind: 'timeout', code };
    if (code === 'already-processed') return { kind: 'already-processed', code };
    if (code === 'not-found') return { kind: 'not-found', code };
    if (code === 'brand-not-approved') return { kind: 'brand-not-approved', code };
    if (code === 'state-changed') return { kind: 'state-changed', code };
    if (code === 'in-use') return { kind: 'in-use', code };
    if (code === 'validation') return { kind: 'validation', code };
    return { kind: 'other', code };
  }
  if (code === 'unavailable' || (typeof navigator !== 'undefined' && navigator.onLine === false)) return { kind: 'offline', code };
  if (code === 'permission-denied') return { kind: 'permission', code };
  if (code === 'unauthenticated') return { kind: 'unauthenticated', code };
  if (code === 'not-found') return { kind: 'not-found', code };
  if (code === 'deadline-exceeded') return { kind: 'timeout', code };
  if (code === 'resource-exhausted') return { kind: 'rate-limited', code };
  if (code === 'failed-precondition') return { kind: /index/i.test(msg) ? 'index' : 'precondition', code, message: msg };
  if (code === 'invalid-argument') return { kind: 'invalid', code, message: msg };
  return { kind: 'other', code };
}

/** 영역 단위 읽기 오류 문구 (design §8 표). */
export function readErrorText(err) {
  switch (classifyError(err).kind) {
    case 'offline':
      return { title: '불러오지 못했어요', desc: '연결을 확인한 뒤 다시 시도해주세요.' };
    case 'permission':
      return { title: '권한이 없어 불러올 수 없어요', desc: '이 데이터를 볼 수 있는 권한이 없어요. 계정을 확인해주세요.' };
    case 'index':
      return { title: '불러오지 못했어요', desc: '목록을 불러오지 못했어요. 인덱스 설정이 필요할 수 있어요.', index: true };
    case 'parse':
      return { title: '불러오지 못했어요', desc: '데이터 형식이 예상과 달라요. 건수를 0 으로 표시하지 않았어요.' };
    default:
      return { title: '불러오지 못했어요', desc: '잠시 후 다시 시도해주세요.' };
  }
}

/**
 * 쓰기 오류 문구 (design §8 표, 모달 내 배너용).
 * @returns {{text:string, unknown:boolean, lock:boolean, expired:boolean}}
 *   unknown = 반영 여부를 모른다(성공·실패로 단정 금지) / lock = 확정 버튼 잠금 / expired = 세션 만료
 */
export function writeErrorText(err, ctx = {}) {
  const k = classifyError(err);
  const base = { unknown: false, lock: false, expired: false };
  switch (k.kind) {
    case 'permission':
      return { ...base, text: '저장되지 않았어요. 권한이 없어 거부되었어요. 항목은 아직 대기 중이에요.' };
    case 'unauthenticated':
      return { ...base, expired: true, text: '로그인이 만료되었어요.' };
    case 'offline':
      return { ...base, text: '저장되지 않았어요. 연결을 확인해주세요. 항목은 아직 대기 중이에요.' };
    case 'timeout':
      return { ...base, unknown: true, text: '응답을 확인하지 못했어요. 처리됐는지 확실하지 않아요. 목록을 새로 고쳐 상태를 확인해주세요.' };
    case 'not-found':
      return { ...base, lock: true, text: '대상을 찾을 수 없어요. 목록을 새로고침해주세요.' };
    case 'already-processed': {
      const cur = STATUS_LABEL[err?.current] || '처리됨';
      return { ...base, lock: true, text: `이미 처리된 건이에요 (현재: ${cur}). 목록을 새로 고쳐주세요.` };
    }
    case 'brand-not-approved':
      return { ...base, lock: true, text: '연결된 브랜드가 승인된 상태가 아니라서 승인할 수 없어요. 브랜드 상태를 먼저 확인해주세요.' };
    case 'precondition':
    case 'invalid':
      // 서버(CF)가 한국어 message 를 내려준다. 토큰 없는 failed-precondition 을 특정 가드로 해석하지 않는다.
      return { ...base, text: (k.message && k.message.length < 200 ? k.message : '저장되지 않았어요. 목록을 새로 고친 뒤 다시 시도해주세요.') };
    default:
      return { ...base, text: '저장되지 않았어요. 잠시 후 다시 시도해주세요.' };
  }
}

/** 로그인 오류 문구 (design A0-a). null = 표시하지 않음 (팝업 닫기 등). */
export function loginErrorText(e) {
  const code = typeof e?.code === 'string' ? e.code : '';
  switch (code) {
    case 'auth/popup-closed-by-user':
    case 'auth/cancelled-popup-request':
    case 'auth/user-cancelled':
      return null;
    case 'auth/unauthorized-domain':
      return '이 주소가 Firebase 인증 승인 도메인에 없어 로그인할 수 없어요. 운영 담당자가 Firebase Console 의 Authentication 승인 도메인에 추가해야 해요.';
    case 'auth/invalid-credential':
    case 'auth/wrong-password':
    case 'auth/user-not-found':
    case 'auth/invalid-email':
    case 'auth/missing-password':
      return '이메일 또는 비밀번호를 확인해주세요.';
    case 'auth/too-many-requests':
      return '잠시 후 다시 시도해주세요.';
    case 'auth/network-request-failed':
      return '연결을 확인해주세요.';
    default:
      return '로그인에 실패했어요. 다시 시도해주세요.';
  }
}

/* ============================================================================
   역할별 콘솔 확장 (web_role_console) — 전부 SDK 비의존 순수 함수 (node 로 검증 가능)
   ========================================================================== */

/* ── 역할 판정 (DV-3) ────────────────────────────────────────────────────────
   getDoc 이 **성공**했는지가 기준이다. 성공했다면 응답 내용(없음 포함)이 판정 근거이고,
   실패했다면 어떤 근거도 없으므로 호출자(readUserRole)가 throw 해 fail-closed 로 닫는다.
     문서 부재 / role 필드 부재  → 'customer'  (Rules userRole() firestore.rules:26-30 과 같은 해석)
     role ∈ 4종                  → 해당 역할
     그 외 (null · '' · 숫자 · 모르는 문자열 · 대소문자 불일치) → unknown (G3)
   role: null 은 Rules userDoc().get('role','customer') 가 null 을 돌려줘 어느 역할도 아니다.
   → 권한을 임의로 customer 로 올려 해석하지 않는다. */
export const KNOWN_ROLES = Object.freeze(['admin', 'brand', 'owner', 'customer']);
export const ROLE_LABEL = Object.freeze({ admin: '관리자', brand: '브랜드', owner: '점주', customer: 'Qrator' });
export const ROLE_SUBTITLE = Object.freeze({ admin: '관리자 콘솔', brand: '브랜드 콘솔', owner: '점주 콘솔', customer: '내 Qradar' });

/** @returns {{kind:'ok', exists:boolean, role:string, brandId:string} | {kind:'unknown', exists:true, raw:any, brandId:string}} */
export function classifyRoleDoc(exists, data) {
  if (!exists) return { kind: 'ok', exists: false, role: 'customer', brandId: '' };
  if (data === null || typeof data !== 'object' || Array.isArray(data)) throw new AdminError('parse');
  const brandId = typeof data.brandId === 'string' ? data.brandId : '';
  if (!Object.prototype.hasOwnProperty.call(data, 'role') || data.role === undefined) {
    return { kind: 'ok', exists: true, role: 'customer', brandId };
  }
  if (typeof data.role === 'string' && KNOWN_ROLES.includes(data.role)) {
    return { kind: 'ok', exists: true, role: data.role, brandId };
  }
  return { kind: 'unknown', exists: true, raw: data.role, brandId };
}

/** 두 판정 결과가 같은 화면을 요구하는가 (역할 + brandId — 브랜드 연결이 바뀌어도 재구성). */
export const sameRole = (a, b) => !!a && !!b && a.kind === b.kind && a.role === b.role && a.brandId === b.brandId;

/** G3 화면에 보여줄 원문 — 사람이 읽을 수 있게 40자로 자른다 (textContent 로만 삽입). */
export function rawRoleText(raw) {
  let s;
  try { s = typeof raw === 'string' ? JSON.stringify(raw) : String(raw === null ? 'null' : raw); } catch (_) { s = '(표시할 수 없음)'; }
  return s.length > 40 ? `${s.slice(0, 40)}…` : s;
}

/* ── 승인 상태 ────────────────────────────────────────────────────────────── */
/** stores 는 status 누락 시 approved 로 취급 (앱 StoreModel T1 legacy fallback). 모르는 문자열은 그대로 돌려줘 호출자가 걸러낸다. */
export const storeStatusOf = (s) => (s?.status === undefined || s?.status === null ? 'approved' : s.status);

/**
 * 매장 핵심 수정 확인 모달의 3갈래 (design §9-3). **서버에서 다시 읽은 문서**로만 호출한다.
 *   A: approved, 또는 pending + approvedAt != null  → 영업·주문 계속 (canSellNow = approved || (pending && approvedAt != null))
 *   B: pending + approvedAt == null                 → 첫 승인 대기. "계속된다" 금지
 *   C: rejected                                     → 재제출
 *   X: 알 수 없는 상태                              → 안내를 단정하지 않는다
 */
export function storeSellClass(s) {
  const st = storeStatusOf(s);
  if (st === 'approved') return 'A';
  if (st === 'pending') return s.approvedAt ? 'A' : 'B';
  if (st === 'rejected') return 'C';
  return 'X';
}

/** 승인 이력이 있는 대기 = "수정 대기" (마스터 메뉴·브랜드·매장 공통). */
export const isRevisionPending = (x) => x?.status === 'pending' && !!x?.approvedAt;

export function statusBadgeText(x) {
  const st = normalizeStatus(x?.status);
  if (!st) return '알 수 없음';
  if (st === 'pending' && x.approvedAt) return '수정 대기';
  return STATUS_LABEL[st];
}

/** 마스터 메뉴 / 오버라이드가 고객에게 적용된 가격 (functions/src/menuVisibility.ts applyOverrideForCustomer 와 같은 분기). */
export function overrideIsApproved(ov) {
  const raw = typeof ov?.status === 'string' ? ov.status : 'pending';
  return raw !== 'pending' && raw !== 'rejected';
}
/** @returns {{hidden:boolean, price:number}} hidden = 이 매장은 이 메뉴를 팔지 않는다 (excluded) */
export function appliedOverride(masterPrice, ov) {
  const base = Number.isFinite(masterPrice) ? Math.trunc(masterPrice) : 0;
  if (!ov) return { hidden: false, price: base };
  const approved = overrideIsApproved(ov);
  if (approved && ov.excluded === true) return { hidden: true, price: base };
  const po = typeof ov.priceOverride === 'number' && Number.isFinite(ov.priceOverride) ? Math.trunc(ov.priceOverride) : null;
  return { hidden: false, price: approved && po !== null ? po : base };
}

/* ── 상수 (앱 값 그대로 — 새로 정하지 않는다) ────────────────────────────── */
export const LIMITS = Object.freeze({
  brandName: 30, brandDescription: 60, companyName: 30, contactName: 30, menuName: 40, optionGroupName: 30,
  subCategoryName: 20, storeName: 30, storeDescription: 200, storeNotice: 200,
});
export const RE_BIZNO = /^\d{3}-\d{2}-\d{5}$/;
export const RE_CONTACT = /^\d{2,3}-\d{3,4}-\d{4}$/;
export const MENU_TAGS = Object.freeze([['recommended', '추천'], ['new', '신메뉴'], ['best', '인기']]);
export const IMAGE_MAX_BYTES = 5 * 1024 * 1024;
export const SALES_LIMIT = 1000;
export const SALES_MONTHS_BACK = 12;

export function checkImageFile(file) {
  if (!file) return { ok: false, error: '이미지를 선택해주세요' };
  if (typeof file.type === 'string' && file.type !== '' && !file.type.startsWith('image/')) return { ok: false, error: '이미지 파일만 올릴 수 있어요' };
  if (file.size > IMAGE_MAX_BYTES) return { ok: false, error: `이미지 용량이 5MB를 초과했습니다. (${(file.size / 1024 / 1024).toFixed(1)}MB)` };
  return { ok: true };
}

/** 정수 가격 입력 파싱. required 면 > 0 (basePrice), 아니면 빈 문자열 = null, 0 허용 (priceOverride). */
export function parsePriceInput(raw, { required }) {
  const s = String(raw ?? '').trim().replace(/,/g, '');
  if (s === '') return required ? { ok: false, error: '가격을 입력해주세요' } : { ok: true, value: null };
  if (!/^\d+$/.test(s)) return { ok: false, error: '숫자만 입력해주세요' };
  const n = Number(s);
  if (!Number.isSafeInteger(n)) return { ok: false, error: '숫자가 너무 커요' };
  if (required && n <= 0) return { ok: false, error: '가격은 0원보다 커야 해요' };
  return { ok: true, value: n };
}

export function parseIntInput(raw, fallback = 0) {
  const s = String(raw ?? '').trim();
  if (s === '') return { ok: true, value: fallback };
  if (!/^-?\d+$/.test(s)) return { ok: false, error: '숫자만 입력해주세요' };
  const n = Number(s);
  return Number.isSafeInteger(n) ? { ok: true, value: n } : { ok: false, error: '숫자가 너무 커요' };
}

/** 두 값(배열 포함)이 같은가 — 폼의 변경 감지용. */
export function sameValue(a, b) {
  if (Array.isArray(a) || Array.isArray(b)) {
    if (!Array.isArray(a) || !Array.isArray(b) || a.length !== b.length) return false;
    return a.every((x, i) => sameValue(x, b[i]));
  }
  if (a && b && typeof a === 'object' && typeof b === 'object') {
    const ka = Object.keys(a); const kb = Object.keys(b);
    return ka.length === kb.length && ka.every((k) => sameValue(a[k], b[k]));
  }
  return a === b;
}

/** before/after 객체에서 keys 중 값이 바뀐 것만 {key: after} 로 돌려준다. */
export function changedFields(before, after, keys) {
  const out = {};
  for (const k of keys) if (!sameValue(before?.[k] ?? null, after?.[k] ?? null)) out[k] = after[k];
  return out;
}

/** 옵션 항목 비활성 키 — 복합 id `{groupId}_{itemId}` (lib/core/utils/option_availability.dart). */
export const optionItemKey = (groupId, itemId) => `${groupId}_${itemId}`;

/* ── 시각 / 상대 시간 ─────────────────────────────────────────────────────── */
export function fmtRelative(v, now = new Date()) {
  const d = toDate(v);
  if (!d || Number.isNaN(d.getTime())) return '-';
  const sec = Math.floor((now.getTime() - d.getTime()) / 1000);
  if (sec < 60) return '방금 전';
  if (sec < 3600) return `${Math.floor(sec / 60)}분 전`;
  if (sec < 86400) return `${Math.floor(sec / 3600)}시간 전`;
  return `${Math.floor(sec / 86400)}일 전`;
}

/** 'YYYY-MM-DD' (로컬). Date 또는 Timestamp. */
export function fmtDateOnly(v) {
  const d = toDate(v);
  if (!d || Number.isNaN(d.getTime())) return '-';
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

/** <input type=date> 값 → 로컬 자정 Date (앱 DateTime(y,m,d)). 형식이 틀리면 null. */
export function parseDateInput(s) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(s || ''));
  if (!m) return null;
  const d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
  return Number.isNaN(d.getTime()) ? null : d;
}

export const fmtWon = (n) => (typeof n === 'number' && Number.isFinite(n) ? `₩ ${n.toLocaleString('ko-KR')}` : '-');
export const fmtQoin = (n) => (typeof n === 'number' && Number.isFinite(n) ? `${n.toLocaleString('ko-KR')} Q` : '-');
export const fmtQoinSigned = (n) => {
  if (typeof n !== 'number' || !Number.isFinite(n)) return '-';
  if (n > 0) return `+${n.toLocaleString('ko-KR')} Q`;
  if (n < 0) return `-${(-n).toLocaleString('ko-KR')} Q`;
  return '0 Q';
};

/* ── 매출 (lib/domain/entities/sales_period.dart · lib/core/utils/kst.dart · get_store_sales_use_case.dart 그대로) ───
   기준 시각은 createdAt(환불 시각 아님). 기간은 KST(UTC+9) 반열린 구간 [start, endExclusive).
   주 = 월요일 시작 / ISO 8601 목요일 소속 주차. 평균 객단가는 정수 나눗셈 버림. */
const KST_MS = 9 * 3600 * 1000;
const toWall = (d) => new Date(d.getTime() + KST_MS);                      // getUTC* 로 읽는다
const fromWall = (y, m = 1, day = 1) => new Date(Date.UTC(y, m - 1, day) - KST_MS); // 월/일 오버플로는 Date.UTC 가 정규화

export function salesPeriod(type, anchor = new Date()) {
  const w = toWall(anchor);
  const y = w.getUTCFullYear(); const mo = w.getUTCMonth() + 1; const d = w.getUTCDate();
  if (type === 'day') return { type, start: fromWall(y, mo, d), endExclusive: fromWall(y, mo, d + 1) };
  if (type === 'month') return { type, start: fromWall(y, mo, 1), endExclusive: fromWall(y, mo + 1, 1) };
  const wd = w.getUTCDay() === 0 ? 7 : w.getUTCDay(); // Dart weekday: 월=1 … 일=7
  const monday = d - (wd - 1);
  return { type: 'week', start: fromWall(y, mo, monday), endExclusive: fromWall(y, mo, monday + 7) };
}
export const prevPeriod = (p) => salesPeriod(p.type, new Date(p.start.getTime() - 1));
export const nextPeriod = (p) => salesPeriod(p.type, p.endExclusive);
export const canGoNext = (p, now = new Date()) => p.endExclusive.getTime() <= now.getTime();
export function canGoPrevious(p, now = new Date()) {
  const w = toWall(now);
  const oldest = fromWall(w.getUTCFullYear(), w.getUTCMonth() + 1 - SALES_MONTHS_BACK, 1);
  return p.start.getTime() > oldest.getTime();
}
const DOW = ['일', '월', '화', '수', '목', '금', '토'];
export function periodLabel(p) {
  const s = toWall(p.start);
  const e = toWall(new Date(p.endExclusive.getTime() - 86400000));
  const ds = (w) => `${w.getUTCFullYear()}-${pad(w.getUTCMonth() + 1)}-${pad(w.getUTCDate())}`;
  if (p.type === 'day') return `${ds(s)} (${DOW[s.getUTCDay()]})`;
  if (p.type === 'month') return `${s.getUTCFullYear()}년 ${s.getUTCMonth() + 1}월`;
  return `${ds(s)} (${DOW[s.getUTCDay()]}) ~ ${pad(e.getUTCMonth() + 1)}-${pad(e.getUTCDate())} (${DOW[e.getUTCDay()]})`;
}

export const ORDER_STATUS = Object.freeze({
  paid: { label: '진행 중', cls: 'pending', group: 'progress' },
  accepted: { label: '진행 중', cls: 'pending', group: 'progress' },
  making: { label: '진행 중', cls: 'pending', group: 'progress' },
  ready: { label: '진행 중', cls: 'pending', group: 'progress' },
  completed: { label: '완료', cls: 'approved', group: 'confirmed' },
  refunded: { label: '환불', cls: 'rejected', group: 'refunded' },
  cancelled: { label: '취소', cls: '', group: 'cancelled' },
});

/**
 * 앱 aggregateStoreSales 와 같은 집계. orders 는 {status, totalPrice, refundInfo?} 배열.
 * 앱 OrderStatus.fromCode 의 폴백(모르는 코드 → paid)을 그대로 따른다 — 합계가 앱과 같아야 한다.
 */
export function aggregateSales(orders) {
  const r = { confirmedSales: 0, confirmedCount: 0, inProgressSales: 0, inProgressCount: 0, refundedAmount: 0, refundedCount: 0, cancelledCount: 0 };
  for (const o of orders) {
    const total = Number.isFinite(o.totalPrice) ? Math.trunc(o.totalPrice) : 0;
    const st = ORDER_STATUS[o.status]?.group || 'progress';
    if (st === 'confirmed') { r.confirmedSales += total; r.confirmedCount++; }
    else if (st === 'progress') { r.inProgressSales += total; r.inProgressCount++; }
    else if (st === 'refunded') {
      const ri = o.refundInfo;
      r.refundedAmount += ri && typeof ri === 'object' ? (Number.isFinite(ri.amount) ? Math.trunc(ri.amount) : 0) : total;
      r.refundedCount++;
    } else r.cancelledCount++;
  }
  r.netSales = r.confirmedSales + r.inProgressSales;
  r.orderCount = r.confirmedCount + r.inProgressCount;
  r.averageOrderValue = r.orderCount === 0 ? 0 : Math.floor(r.netSales / r.orderCount);
  return r;
}

/** 주문/Log 의 "아메리카노 외 1건". items: [{menuItemName|name, quantity}] */
export function itemsSummary(items) {
  const list = Array.isArray(items) ? items.filter((i) => i && typeof i === 'object') : [];
  if (list.length === 0) return '-';
  const first = String(list[0].menuItemName || list[0].name || '(이름 없음)');
  return list.length === 1 ? first : `${first} 외 ${list.length - 1}건`;
}

/* ── 점수 / 등급 (lib/core/constants/grade_thresholds.dart · grade_calculator.dart) ───────
   점주 화면은 grade_min_reviews 설계(§점주 my_store_page "현행 유지")를 따른다: 리뷰 0건이면 '미평가', 아니면 등급 + 평균.
   임계값(3건) 게이팅은 고객 화면의 규칙이고 점주 화면은 자기 매장 수치를 그대로 본다 — 이 함수가 임계값을 새로 정하지 않는다. */
export const GRADE_THRESHOLDS = Object.freeze({ sMin: 3.5, aMin: 2.5, bMin: 1.5, minReviewsForGrade: 3 });
export function gradeFromAverage(avg) {
  if (avg >= GRADE_THRESHOLDS.sMin) return 'S';
  if (avg >= GRADE_THRESHOLDS.aMin) return 'A';
  if (avg >= GRADE_THRESHOLDS.bMin) return 'B';
  return 'C';
}
export function ownerScoreView(store) {
  const count = Number.isFinite(store?.reviewCount) ? store.reviewCount : 0;
  const avg = Number.isFinite(store?.averageScore) ? store.averageScore : 0;
  if (count === 0) return { grade: '미평가', average: '-', count, unrated: true };
  return { grade: `${gradeFromAverage(avg)}급`, average: avg.toFixed(1), count, unrated: false };
}

/* ── Qoin 적립률 해석 (lib/core/utils/qoin_rate_resolver.dart · qoin_policy.dart) — 읽기 전용 표시용 ─── */
export function parseRateCell(raw, present) {
  if (!present) return { kind: 'absent', value: null };
  if (typeof raw !== 'number' || !Number.isFinite(raw)) return { kind: 'invalid', value: null };
  if (raw < RATE_MIN || raw > RATE_MAX) return { kind: 'invalid', value: null };
  return { kind: 'valid', value: raw };
}
export function parseSwitchCell(raw, present) {
  if (!present) return 'enabled';
  if (typeof raw !== 'boolean') return 'invalid';
  return raw ? 'enabled' : 'disabled';
}
/** @returns {{rate:number|null, source:'store'|'brand'|'global'|null, disabledSource:string|null, invalid:string|null}} */
export function resolveEffectiveQoinRate({ store, brand, global, storeSwitch = 'enabled', brandSwitch = 'enabled', hasBrand = true }) {
  const ok = (rate, source) => ({ rate, source, disabledSource: null, invalid: null });
  if (storeSwitch === 'disabled') return { rate: null, source: null, disabledSource: 'store', invalid: null };
  if (hasBrand && brandSwitch === 'disabled') return { rate: null, source: null, disabledSource: 'brand', invalid: null };
  if (storeSwitch === 'invalid') return { rate: null, source: null, disabledSource: null, invalid: 'storeEnabled' };
  if (hasBrand && brandSwitch === 'invalid') return { rate: null, source: null, disabledSource: null, invalid: 'brandEnabled' };
  if (store.kind === 'invalid') return { rate: null, source: null, disabledSource: null, invalid: 'store' };
  if (store.kind === 'valid') return ok(store.value, 'store');
  if (hasBrand && brand.kind === 'invalid') return { rate: null, source: null, disabledSource: null, invalid: 'brand' };
  if (hasBrand && brand.kind === 'valid') return ok(brand.value, 'brand');
  if (global.kind === 'valid') return ok(global.value, 'global');
  return { rate: null, source: null, disabledSource: null, invalid: 'global' };
}
export const QOIN_SOURCE_LABEL = Object.freeze({ store: '매장 설정', brand: '브랜드 설정', global: '전역 기본값' });
export function qoinRateText(eff) {
  if (eff.rate !== null) return { text: fmtRatePct(eff.rate), sub: `기준: ${QOIN_SOURCE_LABEL[eff.source]}`, tone: 'ok' };
  if (eff.disabledSource) return { text: '적립 중단', sub: eff.disabledSource === 'store' ? '이 매장의 적립이 꺼져 있어요' : '브랜드의 적립이 꺼져 있어요', tone: 'off' };
  return { text: '확인 필요', sub: '설정값이 올바르지 않아요. 앱에서 확인해주세요.', tone: 'bad' };
}

/* ── 표시 이름 (customer) ─────────────────────────────────────────────────── */
export const PROVIDER_LABEL = Object.freeze({ email: '이메일', google: 'Google', kakao: 'Kakao', naver: 'Naver' });
export const providerText = (p) => (typeof p === 'string' && p !== '' ? (PROVIDER_LABEL[p] || p) : '-'); // 모르는 값은 원문 그대로
export function displayNameOf(u) {
  if (typeof u?.displayName === 'string' && u.displayName.trim() !== '') return u.displayName.trim();
  if (typeof u?.email === 'string' && u.email.includes('@')) return u.email.split('@')[0];
  return '-';
}
export const QOIN_TX_LABEL = Object.freeze({ earn: '적립', clawback: '회수' });
export const qoinTxText = (t) => (typeof t === 'string' ? (QOIN_TX_LABEL[t] || t) : '-'); // 모르는 값은 원문

/* ── 오류 문구 확장 ───────────────────────────────────────────────────────── */
/** callable 의 details.reason 토큰 (functions/src/claimSubmittedBrand.ts). 없으면 ''. */
export function callableReason(e) {
  const d = e?.details;
  if (d && typeof d === 'object' && typeof d.reason === 'string') return d.reason;
  return '';
}

/** 쓰기 오류 문구 — 큐 항목이 아닌 쓰기는 "대기 중" 대신 "변경 내용은 아직 반영되지 않았어요" (design §9-3). */
export function saveErrorText(err) {
  const k = classifyError(err);
  const base = { unknown: false, lock: false, expired: false };
  switch (k.kind) {
    case 'permission': return { ...base, permission: true, text: '저장되지 않았어요. 권한이 없어 거부되었어요. 변경 내용은 아직 반영되지 않았어요.' };
    case 'unauthenticated': return { ...base, expired: true, text: '로그인이 만료되었어요.' };
    case 'offline': return { ...base, text: '저장되지 않았어요. 연결을 확인해주세요. 변경 내용은 아직 반영되지 않았어요.' };
    case 'timeout': return { ...base, unknown: true, text: '응답을 확인하지 못했어요. 처리됐는지 확실하지 않아요.' };
    case 'not-found': return { ...base, text: '저장되지 않았어요. 대상을 찾을 수 없어요. 새로고침 후 다시 시도해주세요.' };
    case 'state-changed': return { ...base, stateChanged: true, text: '상태가 바뀌었어요. 안내를 확인하고 다시 눌러주세요.' };
    case 'in-use': return { ...base, lock: true, text: err?.message && err.message.length < 120 ? err.message : '사용 중이라 삭제할 수 없어요.' };
    default: return { ...base, text: '저장되지 않았어요. 잠시 후 다시 시도해주세요.' };
  }
}

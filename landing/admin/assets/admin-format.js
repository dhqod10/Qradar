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

/* ============================================================================
   Qradar 관리자 콘솔 — 화면 / 라우팅 / 인터랙션
   데이터 접근은 전부 console-data.js (Firebase SDK 는 그 파일에서만 import).
   표시 형식·오류 분류·입력 검증은 console-format.js, 승인/반려 payload 는 console-payloads.js.

   [읽기 전에 — 보안 모델 (spec §6)]
   이 콘솔은 클라이언트일 뿐이다. 권한의 최종 권위는 Firestore Security Rules 와 Cloud Functions 에 있다.
   이 파일의 화면 분기(로그인 전 셸을 만들지 않음, 버튼 비활성화, 사전 상태 확인)는
   사용자의 혼동과 실수를 줄이는 편의이며, 접근을 통제하지 않는다. DOM 에서 버튼을 강제로 눌러도
   거부 여부는 서버가 정한다. 그래서 이 콘솔은 어떤 응답이든 서버의 판정을 그대로 보여준다.
   - 역할(role) 부여/변경 기능은 없다. admin 승격은 Firestore Console 에서 users.role='admin' 수동 설정뿐이다.
   - 낙관적 UI 없음: 쓰기 성공 응답 전에 목록·건수·배지를 바꾸지 않고, 성공 후에도 서버에서 다시 조회해 그린다.
   - 건수 조회 실패를 0 으로 표시하지 않는다. 반영 여부를 모를 때는 성공/실패로 단정하지 않는다.

   [landing/ 과 Clean Architecture] landing/ 은 Flutter 앱(lib/)의 레이어 규칙 밖이다 (spec §9.2). console-data.js 주석 참고.
   ========================================================================== */

import { isFirebaseConfigured } from './firebase-config.js';
import {
  initFirebase, onAuthChanged, signInEmail, signInGoogle, signOutNow, currentUid, readUserRole,
  countPending, listPendingBrands, getBrand, getBrandPrivate, loadBrandMap,
  listPendingStores, getStore, listAllStores, listPendingMenus, listPendingOverrides, getMasterMenu,
  getQoinConfig, listQoinHistory, approveBrand, rejectBrand, approveStore, rejectStore, readCurrentStatus, LIST_LIMIT,
} from './console-data.js';
import {
  esc, fmtDateTime, fmtShortDateTime, fmtClock, shortUid, fmtKrw, safeUrl, fmtRatePct, normalizeStatus,
  STATUS_LABEL, validateReason, classifyError, readErrorText, writeErrorText, loginErrorText,
} from './console-format.js';

const root = document.getElementById('app');

/* ── 상태 ──────────────────────────────────────────────────────────────────── */
const S = {
  authGen: 0,
  shell: null,            // { uid, email } — admin 으로 확인된 뒤에만 존재
  viewGen: 0,
  counts: {},             // key → {state:'loading'|'ok'|'error', n?, err?}
  order: {},              // 큐 key → 마지막으로 불러온 id 배열 (이전/다음 건)
  modal: null,
  flash: null,            // 쓰기 성공 후 큐에서 띄울 토스트 문구
  loginNotice: null,      // 로그인 화면 상단 안내 (세션 만료 등)
  panelFail: null,        // 모달을 닫은 뒤 상세 화면에 남기는 마지막 실패
  checkTimer: null,
  autoOutTimer: null,     // 비admin 안내 화면의 자동 로그아웃 카운트다운
  busy: false,
};

const LOGO = `<svg class="qlogo" viewBox="0 0 100 100" aria-hidden="true">
  <path d="M 73.09 79.55 A 37.5 37.5 0 1 1 87.5 50 L 75 50 A 25 25 0 1 0 65.39 69.70 Z" fill="currentColor"/>
  <path d="M 69.09 60.61 L 97.73 89.24 L 80.75 89.24 L 52.12 60.61 Z" fill="currentColor"/>
</svg>`;

const $ = (sel, scope = document) => scope.querySelector(sel);
const skel = (w = '100%', h = 16) => `<span class="a-skel" style="width:${w};height:${h}px"></span>`;
const letter = (name) => esc((String(name || '').trim()[0] || '?').toUpperCase());

function toast(msg) {
  const r = $('#toast-region');
  const t = document.createElement('div');
  t.className = 'a-toast';
  t.textContent = msg;
  r.appendChild(t);
  setTimeout(() => t.remove(), 6000);
}

window.addEventListener('beforeunload', (e) => {
  if (S.busy) { e.preventDefault(); e.returnValue = ''; } // 처리 중 이탈 확인
});

/* ── 공용 조각 ─────────────────────────────────────────────────────────────── */
const banner = (kind, lead, text, extra = '') =>
  `<div class="a-banner ${kind}" role="${kind === 'error' ? 'alert' : 'status'}"><p>${lead ? `<span class="a-b-lead">${esc(lead)}</span>` : ''}${esc(text)}</p>${extra}</div>`;

const emptyBlock = (title, desc, extra = '') =>
  `<div class="a-empty"><strong>${esc(title)}</strong>${desc ? `<span>${esc(desc)}</span>` : ''}${extra}</div>`;

function errorBlock(err, retryAttr = 'data-retry') {
  const t = readErrorText(err);
  return `<div class="a-err" role="alert"><strong>${esc(t.title)}</strong><p>${esc(t.desc)}</p>
    <button type="button" class="a-btn" ${retryAttr}>다시 시도</button></div>`;
}

const statusBadge = (st) => {
  const s = normalizeStatus(st);
  return s ? `<span class="a-badge ${s}">${STATUS_LABEL[s]}</span>` : '<span class="a-badge">알 수 없음</span>';
};

const copyBtn = (v) => (v ? `<button type="button" class="a-link a-copy" data-copy="${esc(v)}">복사</button>` : '');
const uidCell = (uid) => (uid
  ? `<span class="a-num" title="${esc(uid)}">${esc(shortUid(uid))}</span>${copyBtn(uid)}`
  : '<span class="a-empty-v a-muted">-</span>');

function thumb(url, name, lg = false) {
  const u = safeUrl(url);
  const cls = `a-thumb${lg ? ' lg' : ''}`;
  if (!u) return `<span class="${cls}" aria-hidden="true">${letter(name)}</span>`;
  return `<img class="${cls}" src="${esc(u)}" alt="" loading="lazy" referrerpolicy="no-referrer" data-fb="${letter(name)}">`;
}

// 이미지 로드 실패 → 첫 글자 플레이스홀더 (에러 문구 없음)
root.addEventListener('error', (e) => {
  const t = e.target;
  if (t && t.tagName === 'IMG' && t.dataset.fb !== undefined) {
    const span = document.createElement('span');
    span.className = t.className;
    span.setAttribute('aria-hidden', 'true');
    span.textContent = t.dataset.fb;
    t.replaceWith(span);
  }
}, true);

// UID 복사 — clipboard 가 막힌 컨텍스트에서도 조용히 실패하지 않는다 (DV-13)
root.addEventListener('click', async (e) => {
  const b = e.target.closest('[data-copy]');
  if (!b) return;
  const before = b.textContent;
  try {
    await navigator.clipboard.writeText(b.dataset.copy);
    b.textContent = '복사됨';
  } catch (_) {
    b.textContent = '복사하지 못했어요';
  }
  setTimeout(() => { b.textContent = before; }, 1500);
});

/* ============================================================================
   A0. 인증 게이트 — admin 으로 확인되기 전에는 셸(사이드바·본문) DOM 을 만들지 않고 데이터 요청도 보내지 않는다.
   (혼동 방지 UX 이다. 보안 경계가 아니다 — 위 [보안 모델] 참고.)
   ========================================================================== */

function gate(inner) {
  clearTimeout(S.checkTimer);
  clearInterval(S.autoOutTimer); S.autoOutTimer = null;
  teardownShell();
  root.innerHTML = `<div class="a-gate"><div class="a-gate-wrap">${inner}</div></div>`;
}

const gateLogo = `<div class="a-logo">${LOGO}</div>`;

function renderConfigMissing() {
  gate(`<div class="a-gate-card" role="alert">${gateLogo}<h2>설정이 필요해요</h2>
    <p>Firebase 웹 앱 설정(apiKey, appId)이 비어 있어 로그인할 수 없어요.</p>
    <p class="a-cap">assets/firebase-config.js 에 Firebase Console 의 웹 앱 SDK 설정값을 채워주세요. 자세한 방법은 admin/README.md 를 참고하세요.</p></div>`);
}

function renderChecking(user) {
  gate(`<div class="a-gate-card" role="status" aria-live="polite">${gateLogo}<h2>권한을 확인하고 있어요…</h2>
    <div class="a-loadbar"></div><div id="slow"></div></div>`);
  S.checkTimer = setTimeout(() => {
    const el = $('#slow');
    if (!el) return;
    el.innerHTML = `<p class="a-cap" style="margin-top:14px">오래 걸리고 있어요</p>
      <button type="button" class="a-btn block" id="slow-out">로그아웃</button>`;
    $('#slow-out').onclick = () => signOutNow();
  }, 8000);
}

function renderLogin(notice) {
  gate(`<div class="a-gate-card">${gateLogo}<h1>Qradar 관리자 콘솔</h1>
    <p class="a-sub">관리자 계정으로 로그인하세요</p>
    ${notice ? banner('', '', notice) : ''}
    <form id="login-form" novalidate>
      <div class="a-field"><label class="a-label" for="lg-email">이메일</label>
        <input class="a-input" id="lg-email" type="email" autocomplete="username" inputmode="email">
        <div class="a-field-err" id="lg-email-err" hidden></div></div>
      <div class="a-field"><label class="a-label" for="lg-pw">비밀번호</label>
        <input class="a-input" id="lg-pw" type="password" autocomplete="current-password">
        <div class="a-field-err" id="lg-pw-err" hidden></div></div>
      <button type="submit" class="a-btn primary block lg" id="lg-submit">로그인</button>
      <div class="a-divider">또는</div>
      <button type="button" class="a-btn block lg" id="lg-google">Google 로 로그인</button>
    </form>
    <div id="lg-msg" style="margin-top:16px"></div></div>
    <p class="a-cap">Naver·Kakao 계정은 사용할 수 없어요</p>`);

  const form = $('#login-form');
  const submit = $('#lg-submit');
  const google = $('#lg-google');
  const setBusy = (b, which) => {
    submit.disabled = b; google.disabled = b;
    submit.innerHTML = b && which === 'email' ? '<span class="a-spin"></span>로그인 중…' : '로그인';
    google.innerHTML = b && which === 'google' ? '<span class="a-spin"></span>로그인 중…' : 'Google 로 로그인';
  };
  const showFail = (e) => {
    const text = loginErrorText(e);
    if (e) console.error('[admin] 로그인 실패', e?.code || e);
    $('#lg-msg').innerHTML = text ? banner('error', '', text) : '';
  };
  const fieldErr = (id, msg) => {
    const el = $(`#${id}-err`);
    el.hidden = !msg; el.textContent = msg || '';
    $(`#${id === 'lg-email' ? 'lg-email' : 'lg-pw'}`).setAttribute('aria-invalid', msg ? 'true' : 'false');
  };

  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const email = $('#lg-email').value.trim();
    const pw = $('#lg-pw').value;
    fieldErr('lg-email', email ? '' : '이메일을 입력해주세요');
    fieldErr('lg-pw', pw ? '' : '비밀번호를 입력해주세요');
    if (!email || !pw) return;
    $('#lg-msg').innerHTML = '';
    setBusy(true, 'email');
    try { await signInEmail(email, pw); } // 성공하면 onAuthChanged 가 화면을 바꾼다
    catch (e) { setBusy(false); showFail(e); }
  });
  google.addEventListener('click', async () => {
    $('#lg-msg').innerHTML = '';
    setBusy(true, 'google');
    try { await signInGoogle(); }
    catch (e) { setBusy(false); showFail(e); }
  });
}

/** 비admin 안내 화면을 몇 초 보여준 뒤 자동 로그아웃할지. */
const NOT_ADMIN_AUTO_OUT_SEC = 5;

/** 자동 로그아웃 뒤 로그인 화면에 남길 안내. */
const NOT_ADMIN_NOTICE = '이 계정으로는 콘솔을 사용할 수 없어요. 관리자 계정으로 로그인해주세요.';

/**
 * admin 이 아닌 계정으로 로그인한 경우.
 *
 * 여기서 로그아웃하는 것은 **공용 PC 에 세션이 방치되지 않게 하려는 것**이지
 * 접근을 막는 수단이 아니다 — 접근은 이미 Firestore Rules 가 막는다(이 화면이
 * 떴다는 것은 users/{uid}.role 이 admin 이 아니라는 뜻이고, 콘솔은 본문 DOM 도
 * 데이터 요청도 만들지 않았다).
 *
 * "비밀번호가 틀렸다" 류로 사유를 숨기지 않는다. 그 시점에 Firebase Auth 인증은
 * 이미 성공했고, 공개된 apiKey 로 Auth REST 를 직접 호출하면 같은 사실을 알 수
 * 있어 숨겨지지 않는다. 반대로 정상 사용자(아직 role 을 받지 못한 관리자, URL 을
 * 잘못 연 점주)는 비밀번호 재설정을 반복하게 되고, 그 계정은 실제 앱 계정이다.
 */
function renderNotAdmin(user) {
  const my = S.authGen;   // 이 화면을 띄운 시점의 인증 세대
  gate(`<div class="a-gate-card">${gateLogo}<h2>이 계정으로는 콘솔을<br>사용할 수 없어요</h2>
    <p>관리자 권한이 있는 계정이 필요해요. 현재 계정:</p>
    <p><strong>${esc(user.email || user.uid)}</strong></p>
    <p>권한이 필요하면 운영 담당자에게 문의해주세요.</p>
    <p class="a-cap" id="na-count">${NOT_ADMIN_AUTO_OUT_SEC}초 후 자동으로 로그아웃돼요.</p>
    <button type="button" class="a-btn block lg" id="na-out">지금 로그아웃</button></div>`);

  let left = NOT_ADMIN_AUTO_OUT_SEC;

  // 버튼으로 누르든 카운트다운이 끝나든 같은 경로를 탄다 (중복 signOut 없음).
  const leave = () => {
    clearInterval(S.autoOutTimer); S.autoOutTimer = null;
    if (my !== S.authGen) return;          // 그 사이 인증 상태가 바뀌었으면 아무것도 하지 않는다
    S.loginNotice = NOT_ADMIN_NOTICE;
    signOutNow();
  };

  S.autoOutTimer = setInterval(() => {
    if (my !== S.authGen) { clearInterval(S.autoOutTimer); S.autoOutTimer = null; return; }
    left -= 1;
    if (left <= 0) { leave(); return; }
    const el = $('#na-count');
    if (el) el.textContent = `${left}초 후 자동으로 로그아웃돼요.`;
  }, 1000);

  $('#na-out').onclick = leave;
}

function renderRoleFail(user, err, my) {
  const k = classifyError(err).kind;
  const reason = k === 'offline' ? '네트워크' : k === 'permission' ? '읽기 거부' : '알 수 없음';
  gate(`<div class="a-gate-card">${gateLogo}<h2>권한을 확인하지 못했어요</h2>
    ${banner('error', '', '계정 정보를 불러오지 못해 콘솔을 열 수 없어요.')}
    <p class="a-cap">사유: ${esc(reason)}</p>
    <div class="a-gate-actions"><button type="button" class="a-btn" id="rf-retry">다시 시도</button>
    <button type="button" class="a-btn" id="rf-out">로그아웃</button></div></div>`);
  $('#rf-out').onclick = () => signOutNow();
  $('#rf-retry').onclick = (ev) => {
    ev.target.disabled = true; ev.target.innerHTML = '<span class="a-spin"></span>확인 중…';
    checkRole(user, my);
  };
}

/** users/{uid} 를 읽어 admin 일 때만 셸을 연다. 읽기 실패/타임아웃/형식 이상은 전부 닫힘(fail-closed). */
async function checkRole(user, my) {
  try {
    const r = await readUserRole(user.uid);
    if (my !== S.authGen) return;
    if (r.admin) openShell(user); else renderNotAdmin(user);
  } catch (e) {
    console.error('[admin] users/{uid} 읽기 실패 — 닫힘 유지', e?.code || e);
    if (my !== S.authGen) return;
    renderRoleFail(user, e, my);
  }
}

function handleAuth(user) {
  const my = ++S.authGen;
  if (!user) {
    // 사용자가 직접 로그아웃했으면 loginNotice 가 ''(안내 없음). 아니면 셸 이용 중 세션이 끊긴 것이다.
    const n = S.loginNotice; S.loginNotice = null;
    renderLogin(n !== null ? n : (S.shell ? '세션이 만료되었어요. 다시 로그인해주세요.' : null));
    return;
  }
  renderChecking(user);
  checkRole(user, my);
}

/* ============================================================================
   셸
   ========================================================================== */

const NAV = [
  { group: '운영', items: [{ key: 'dashboard', href: '#/dashboard', label: '대시보드' }] },
  { group: '승인 큐', items: [
    { key: 'brands', href: '#/brands', label: '브랜드', count: 'brands' },
    { key: 'storesPending', href: '#/stores/pending', label: '매장', count: 'stores' },
    { key: 'menus', href: '#/menus', label: '마스터 메뉴', count: 'menus', ro: true },
    { key: 'overrides', href: '#/overrides', label: '매장 커스텀', count: 'overrides', ro: true },
  ] },
  { group: '조회', items: [
    { key: 'stores', href: '#/stores', label: '매장 목록' },
    { key: 'qoin', href: '#/qoin', label: 'Qoin 현황' },
  ] },
];

function shellHtml(email) {
  const nav = NAV.map((g) => `<div class="a-nav-group">${g.group}</div><ul class="a-nav">${g.items.map((i) =>
    `<li><a href="${i.href}" data-nav="${i.key}"><span class="a-nav-label">${i.label}</span>${i.ro ? '<span class="a-chip">읽기</span>' : ''}${i.count ? `<span class="a-count" data-badge="${i.count}" hidden></span>` : ''}</a></li>`).join('')}</ul>`).join('');
  return `<div class="a-shell">
    <a class="skip" href="#main" id="skip">본문으로 건너뛰기</a>
    <aside class="a-side"><div class="a-brandbox"><span class="brand">${LOGO}<span class="brand-word">Qradar</span></span><small>관리자 콘솔</small></div>
      <nav aria-label="주 메뉴">${nav}</nav>
      <div class="a-account"><div class="a-email" title="${esc(email)}">${esc(email)}</div><div class="a-role">관리자</div>
        <button type="button" class="a-btn sm block" id="logout">로그아웃</button></div></aside>
    <main class="a-main" id="main" tabindex="-1"><div class="a-main-inner" id="view"></div></main></div>`;
}

function openShell(user) {
  clearTimeout(S.checkTimer);
  S.shell = { uid: user.uid, email: user.email || '' };
  root.innerHTML = shellHtml(S.shell.email);
  $('#logout').onclick = () => { S.loginNotice = ''; signOutNow(); };
  $('#skip').onclick = (e) => { e.preventDefault(); $('#main').focus(); };
  window.addEventListener('hashchange', route);
  S.counts = { brands: { state: 'loading' }, stores: { state: 'loading' }, menus: { state: 'loading' }, overrides: { state: 'loading' } };
  renderBadges();
  loadAllCounts();
  if (!/^#\/(dashboard|brands|stores|menus|overrides|qoin)/.test(location.hash)) location.hash = '#/dashboard';
  else route();
}

function teardownShell() {
  if (!S.shell) return;
  S.shell = null; S.viewGen++; S.order = {}; S.flash = null; S.panelFail = null; S.busy = false;
  if (S.modal) S.modal.destroy();
  window.removeEventListener('hashchange', route);
}

/* ── 건수 (대시보드 카드 + 사이드바 배지). 실패는 '!' / 오류 카드로 — 0 으로 표시하지 않는다 ───── */
const COUNT_KEYS = ['brands', 'stores', 'menus', 'overrides'];

async function loadCount(key) {
  const sh = S.shell;
  S.counts[key] = { state: 'loading' }; renderBadges(); renderStats();
  try {
    const n = await countPending[key]();
    if (S.shell !== sh) return;
    S.counts[key] = { state: 'ok', n };
  } catch (e) {
    console.error(`[admin] 승인 대기 건수(${key}) 조회 실패`, e?.code || e);
    if (S.shell !== sh) return;
    S.counts[key] = { state: 'error', err: e };
  }
  renderBadges(); renderStats();
}
const loadAllCounts = () => Promise.all(COUNT_KEYS.map(loadCount));

function renderBadges() {
  document.querySelectorAll('[data-badge]').forEach((el) => {
    const c = S.counts[el.dataset.badge] || { state: 'loading' };
    el.removeAttribute('aria-label');
    if (c.state === 'loading') { el.textContent = '…'; el.hidden = false; }
    else if (c.state === 'error') { el.textContent = '!'; el.setAttribute('aria-label', '건수를 불러오지 못했어요'); el.hidden = false; }
    else if (c.n > 0) { el.textContent = String(c.n); el.hidden = false; }
    else el.hidden = true; // 0건은 그리지 않는다 (조회 성공일 때만)
  });
}

const STAT_META = {
  brands: { title: '브랜드', href: '#/brands' },
  stores: { title: '매장', href: '#/stores/pending' },
  menus: { title: '마스터 메뉴', href: '#/menus', ro: true },
  overrides: { title: '매장 커스텀', href: '#/overrides', ro: true },
};

function statHtml(key) {
  const m = STAT_META[key]; const c = S.counts[key] || { state: 'loading' };
  const head = `<div class="a-stat-title">${m.title}${m.ro ? '<span class="a-chip">읽기</span>' : ''}</div>`;
  let body;
  if (c.state === 'loading') body = `<div class="a-stat-num">${skel('64px', 34)}</div><div class="a-stat-sub">${skel('56px', 13)}</div>`;
  else if (c.state === 'error') {
    body = `<div class="a-stat-num off" aria-label="불러오지 못했어요">–</div>
      <div class="a-stat-sub err">불러오지 못했어요</div>
      <button type="button" class="a-btn sm" data-retry-count="${key}">다시 시도</button>`;
  } else {
    body = `<div class="a-stat-num">${c.n}</div><div class="a-stat-sub">${c.n === 0 ? '대기 없음' : '건 대기'}</div>`;
  }
  return `${head}${body}<div style="margin-top:10px"><a href="${m.href}">목록 보기 →</a></div>`;
}

function renderStats() {
  document.querySelectorAll('[data-stat]').forEach((el) => { el.innerHTML = statHtml(el.dataset.stat); });
  const allZero = COUNT_KEYS.every((k) => S.counts[k]?.state === 'ok' && S.counts[k].n === 0);
  const z = $('#dash-zero');
  if (z) z.innerHTML = allZero ? banner('', '', '지금 처리할 승인 대기가 없어요') : '';
}

root.addEventListener('click', (e) => {
  const b = e.target.closest('[data-retry-count]');
  if (b) loadCount(b.dataset.retryCount);
});

/* ============================================================================
   라우터
   ========================================================================== */

function route() {
  if (!S.shell) return;
  if (S.modal) { if (S.modal.busy) return; S.modal.close(); }
  const gen = ++S.viewGen;
  const alive = () => gen === S.viewGen && !!S.shell;
  const parts = decodeURIComponent(location.hash.replace(/^#\/?/, '')).split('/').filter(Boolean);
  const view = $('#view');
  if (!view) return;
  let key = 'dashboard';
  let fn;
  if (parts[0] === 'brands') { key = 'brands'; fn = parts[1] ? () => viewBrandDetail(parts[1], alive) : () => viewBrandQueue(alive); }
  else if (parts[0] === 'stores' && parts[1] === 'pending') { key = 'storesPending'; fn = parts[2] ? () => viewStoreDetail(parts[2], alive) : () => viewStoreQueue(alive); }
  else if (parts[0] === 'stores') { key = 'stores'; fn = () => viewStoreList(alive); }
  else if (parts[0] === 'menus') { key = 'menus'; fn = () => viewMenus(alive); }
  else if (parts[0] === 'overrides') { key = 'overrides'; fn = () => viewOverrides(alive); }
  else if (parts[0] === 'qoin') { key = 'qoin'; fn = () => viewQoin(alive); }
  else if (parts[0] === 'dashboard') { fn = () => viewDashboard(alive); }
  else { location.hash = '#/dashboard'; return; } // 알 수 없는 해시 → 대시보드

  document.querySelectorAll('[data-nav]').forEach((a) => {
    if (a.dataset.nav === key) a.setAttribute('aria-current', 'page'); else a.removeAttribute('aria-current');
  });
  window.scrollTo(0, 0);
  fn();
}

/* ── 페이지 헤드 + 목록 로더 ────────────────────────────────────────────────── */
function headHtml({ title, tag, desc, refresh = true }) {
  return `<div class="a-head"><h1>${esc(title)}${tag ? `<span class="a-chip">${esc(tag)}</span>` : ''}</h1>
    ${refresh ? `<div class="a-head-tools"><span class="a-cap" id="stamp"></span><button type="button" class="a-btn sm" id="refresh">새로고침</button></div>` : ''}</div>
    ${desc ? `<p class="a-desc">${esc(desc)}</p>` : '<div style="height:24px"></div>'}`;
}

const skelRows = (cols, n = 5) => `<div class="a-table-wrap" aria-busy="true"><span class="a-sr">불러오는 중</span><table class="a-table"><tbody>${
  Array.from({ length: n }, () => `<tr class="a-skel-row">${Array.from({ length: cols }, () => `<td>${skel('80%', 16)}</td>`).join('')}</tr>`).join('')}</tbody></table></div>`;

/**
 * 목록 로더. 최초 = 스켈레톤, 새로고침 = 기존 행 유지 + 상단 로딩바(깜빡임 없음).
 * 새로고침 실패 시 기존 행을 유지하고 '마지막 갱신' 시각을 갱신하지 않는다.
 */
function makeLoader({ alive, box, notice, cols, load, render, onData, onFail }) {
  let token = 0; let has = false;
  async function run(isRefresh = false) {
    const my = ++token;
    const refreshing = isRefresh && has;
    if (!refreshing) box.innerHTML = skelRows(cols);
    else { const w = $('.a-table-wrap', box); if (w && !$('.a-lbar', w)) w.insertAdjacentHTML('afterbegin', '<div class="a-lbar"></div>'); }
    if (notice) notice.innerHTML = '';
    try {
      const data = await load();
      if (!alive() || my !== token) return;
      has = true;
      box.innerHTML = render(data);
      if (onData) onData(data);
      const st = $('#stamp'); if (st) st.textContent = `마지막 갱신 ${fmtClock()}`;
    } catch (e) {
      console.error('[admin] 목록 조회 실패', e?.code || e);
      if (!alive() || my !== token) return;
      if (refreshing) {
        $('.a-lbar', box)?.remove();
        if (notice) notice.innerHTML = banner('error', '', '목록을 새로 고치지 못했어요. 아래는 마지막으로 불러온 내용이에요.');
      } else {
        box.innerHTML = errorBlock(e);
        $('[data-retry]', box).onclick = () => run(false);
        if (onFail) onFail(e);
      }
    }
  }
  return { run };
}

const flashOnce = () => { const f = S.flash; S.flash = null; return f; };

/* ============================================================================
   화면 조각: 표 / 브랜드 연결
   ========================================================================== */

const tableHtml = (heads, bodyRows) =>
  `<div class="a-table-wrap"><table class="a-table"><thead><tr>${heads.map((h) => `<th scope="col">${h}</th>`).join('')}</tr></thead><tbody>${bodyRows.join('')}</tbody></table></div>`;

const totalLine = (n, truncated) =>
  `<div class="a-total">총 ${n}건${truncated ? ` · 처음 ${LIST_LIMIT}건까지만 불러왔어요` : ''}</div>`;

/** 매장의 연결 브랜드 해석. map === null 이면 브랜드 목록 조회 자체가 실패한 것(lookupFailed). */
function brandLinkOf(brandId, map) {
  if (!brandId) return { kind: 'personal' };
  if (map === null) return { kind: 'lookupFailed' };
  const b = map.get(brandId);
  if (!b) return { kind: 'missing' };
  return { kind: b.status === 'approved' ? 'approved' : 'unapproved', name: b.name || '(이름 없음)', status: b.status };
}

function brandLinkCell(l) {
  switch (l.kind) {
    case 'personal': return '<span class="a-muted">개인 매장(브랜드 없음)</span>';
    case 'approved': return esc(l.name);
    case 'unapproved': return `<span class="a-warn-dot"><strong>${esc(l.name)}</strong> (${esc(STATUS_LABEL[normalizeStatus(l.status)] || '알 수 없음')})</span>`;
    case 'missing': return '<span class="a-warn-dot"><strong>존재하지 않는 브랜드</strong></span>';
    case 'lookupFailed': return '<span class="a-warn-dot"><strong>브랜드를 확인하지 못했어요</strong></span>';
    default: return skel('70px', 14);
  }
}

/* ============================================================================
   A1 대시보드
   ========================================================================== */

function qoinCardsHtml(cfg) {
  const r = cfg.rate;
  const rateText = r.kind === 'valid' ? fmtRatePct(r.value) : r.kind === 'absent' ? '미설정' : '유효하지 않은 값';
  const rateSub = r.kind === 'invalid' ? '설정값이 올바르지 않아요. 앱에서 확인해주세요.' : '전역 Qoin 적립률';
  const stateBadge = cfg.enabled === true ? '<span class="a-badge approved">적립 중</span>'
    : cfg.enabled === false ? '<span class="a-badge pending">비상 정지</span>' : '<span class="a-badge">확인 필요</span>';
  const stateSub = cfg.enabled === null ? '값을 읽지 못했어요 (앱은 비상 정지로 취급해요)' : 'Qoin 적립 상태';
  return `<div class="a-grid c3">
    <div class="a-card"><div class="a-cap a-qdot">전역 적립률</div><div class="a-qval a-num" style="margin-top:8px">${esc(rateText)}</div><div class="a-cap" style="margin-top:4px">${esc(rateSub)}</div></div>
    <div class="a-card"><div class="a-cap a-qdot">적립 상태</div><div style="margin-top:10px">${stateBadge}</div><div class="a-cap" style="margin-top:8px">${esc(stateSub)}</div></div>
    <div class="a-card"><div class="a-cap a-qdot">최근 상태 변경</div>
      <dl class="a-kv" style="grid-template-columns:56px 1fr;margin-top:8px;gap:6px 8px"><dt>처리자</dt><dd>${uidCell(cfg.enabledChangedBy)}</dd><dt>시각</dt><dd class="a-num">${esc(fmtDateTime(cfg.enabledChangedAt))}</dd></dl></div></div>`;
}

const qoinSkel = () => `<div class="a-grid c3" aria-busy="true">${[0, 1, 2].map(() => `<div class="a-card">${skel('60%', 14)}<div style="height:12px"></div>${skel('80%', 24)}</div>`).join('')}</div>`;

/** config/qoin 읽기. 문서 없음은 '설정 없음' 빈 상태(값을 임의로 채우지 않는다). */
async function loadQoinInto(box, alive, { warnBox, onOk } = {}) {
  box.innerHTML = qoinSkel();
  if (warnBox) warnBox.innerHTML = '';
  try {
    const cfg = await getQoinConfig();
    if (!alive()) return null;
    if (cfg === null) { box.innerHTML = emptyBlock('아직 Qoin 설정이 없어요', ''); return 'empty'; }
    box.innerHTML = qoinCardsHtml(cfg);
    if (warnBox && cfg.enabled === false) {
      warnBox.innerHTML = banner('warn', '주의', 'Qoin 적립이 비상 정지 중이에요.', warnBox.dataset.more ? '<div class="a-b-actions"><a href="#/qoin">자세히 보기 →</a></div>' : '');
    }
    if (onOk) onOk(cfg);
    return 'ok';
  } catch (e) {
    console.error('[admin] config/qoin 조회 실패', e?.code || e);
    if (!alive()) return null;
    box.innerHTML = errorBlock(e);
    $('[data-retry]', box).onclick = () => loadQoinInto(box, alive, { warnBox, onOk });
    return 'error';
  }
}

function viewDashboard(alive) {
  const v = $('#view');
  v.innerHTML = `${headHtml({ title: '대시보드', desc: '지금 처리할 승인 대기와 Qoin 현황을 한눈에 확인해요.' })}
    <div id="dash-warn" data-more="1"></div><div id="dash-zero"></div>
    <div class="a-section"><h2 class="a-h2">승인 대기</h2>
      <div class="a-grid c4">${COUNT_KEYS.map((k) => `<div class="a-card a-stat" data-stat="${k}"></div>`).join('')}</div></div>
    <div class="a-section"><div class="a-head" style="margin-bottom:0"><h2 class="a-h2">Qoin 현황</h2><a href="#/qoin">자세히 보기 →</a></div>
      <div id="dash-qoin"></div></div>`;
  renderStats();
  const stamp = () => { const st = $('#stamp'); if (st && alive()) st.textContent = `마지막 갱신 ${fmtClock()}`; };
  const refreshQoin = () => loadQoinInto($('#dash-qoin'), alive, { warnBox: $('#dash-warn'), onOk: stamp });
  $('#refresh').onclick = () => { loadAllCounts().then(() => { if (COUNT_KEYS.some((k) => S.counts[k].state === 'ok')) stamp(); }); refreshQoin(); };
  if (COUNT_KEYS.every((k) => S.counts[k].state !== 'loading') && COUNT_KEYS.some((k) => S.counts[k].state === 'ok')) stamp();
  refreshQoin();
}

/* ============================================================================
   A2 브랜드 승인 큐 / A3 상세
   ========================================================================== */

function viewBrandQueue(alive) {
  const flash = flashOnce();
  const v = $('#view');
  v.innerHTML = `${headHtml({ title: '브랜드 승인', desc: '승인을 기다리는 브랜드 제출 건이에요. 제출이 오래된 순으로 보여줘요.' })}<div id="notice"></div><div id="box"></div>`;
  const loader = makeLoader({
    alive, box: $('#box'), notice: $('#notice'), cols: 5, load: listPendingBrands,
    render: ({ rows, truncated }) => (rows.length === 0
      ? emptyBlock('검토 대기 중인 브랜드가 없어요', '새 제출이 들어오면 여기에 나타나요.')
      : tableHtml(['브랜드', '제출자 UID', '제출 시각', '상태', ''], rows.map((r) => `<tr class="a-hover">
          <td><div class="a-name">${thumb(r.logoUrl, r.name)}<a href="#/brands/${encodeURIComponent(r.id)}">${esc(r.name || '(이름 없음)')}</a></div></td>
          <td>${uidCell(r.submittedBy)}</td><td class="a-num">${esc(fmtDateTime(r.submittedAt))}</td>
          <td>${statusBadge(r.status)}</td><td><a href="#/brands/${encodeURIComponent(r.id)}">자세히 →</a></td></tr>`)) + totalLine(rows.length, truncated)),
    onData: (d) => { S.order.brands = d.rows.map((r) => r.id); },
    onFail: () => { if (flash) $('#notice').innerHTML = banner('warn', '', '처리는 저장되었지만 목록을 새로 고치지 못했어요. 새로고침을 눌러주세요.'); },
  });
  $('#refresh').onclick = () => { loader.run(true); loadAllCounts(); };
  loader.run(false).then(() => { if (flash && alive()) toast(flash); });
}

const navButtons = (orderKey, id, base) => {
  const list = S.order[orderKey]; const i = list ? list.indexOf(id) : -1;
  if (i < 0) return '<span></span>';
  const prev = i > 0 ? `<a class="a-btn sm" href="${base}/${encodeURIComponent(list[i - 1])}">← 이전 건</a>` : '';
  const next = i < list.length - 1 ? `<a class="a-btn sm" href="${base}/${encodeURIComponent(list[i + 1])}">다음 건 →</a>` : '';
  return `<span style="display:flex;gap:8px">${prev}${next}</span>`;
};

const detailSkeleton = (backHref, backLabel) => `<div class="a-crumbs"><a href="${backHref}">← ${backLabel}</a></div>
  <div aria-busy="true"><span class="a-sr">불러오는 중</span>${skel('40%', 30)}<div style="height:24px"></div>
  <div class="a-detail"><div class="a-detail-main"><div class="a-card">${skel('50%', 18)}<div style="height:16px"></div>${skel('90%', 14)}<div style="height:10px"></div>${skel('70%', 14)}<div style="height:10px"></div>${skel('80%', 14)}</div>
  <div class="a-card">${skel('40%', 18)}<div style="height:16px"></div>${skel('90%', 14)}<div style="height:10px"></div>${skel('60%', 14)}</div></div>
  <aside class="a-panel a-card">${skel('50%', 18)}</aside></div></div>`;

const kv = (rows) => `<dl class="a-kv">${rows.map(([k, val, raw]) => `<dt>${esc(k)}</dt><dd>${raw ? val : (val === '' || val == null || val === '-' ? '<span class="a-empty-v a-muted">-</span>' : esc(val))}</dd>`).join('')}</dl>`;

const panelFailHtml = (id) => {
  const f = S.panelFail;
  if (!f || f.id !== id) return '';
  const msg = f.unknown
    ? `마지막 시도의 처리 여부를 확인하지 못했어요(${f.time}). 새로고침으로 현재 상태를 확인해주세요.`
    : `마지막 시도는 저장되지 않았어요(${f.time}). 항목은 아직 대기 중이에요.`;
  return `<div class="a-banner error" role="alert"><button type="button" class="a-link a-b-x" id="pf-x" aria-label="닫기">닫기</button>
    <p><span class="a-b-lead">${f.unknown ? '확인 필요' : '실패'}</span>${esc(msg)}</p></div>`;
};

async function viewBrandDetail(id, alive) {
  const v = $('#view');
  const back = '<a href="#/brands">← 브랜드 승인 목록</a>';
  v.innerHTML = detailSkeleton('#/brands', '브랜드 승인 목록');
  const load = async () => {
    v.innerHTML = detailSkeleton('#/brands', '브랜드 승인 목록');
    let b;
    try { b = await getBrand(id); } catch (e) {
      console.error('[admin] 브랜드 조회 실패', e?.code || e);
      if (!alive()) return;
      v.innerHTML = `<div class="a-crumbs">${back}</div>${errorBlock(e)}`;
      $('[data-retry]', v).onclick = load; return;
    }
    if (!alive()) return;
    if (!b) { v.innerHTML = `<div class="a-crumbs">${back}</div>${emptyBlock('찾을 수 없는 브랜드예요', '이미 삭제되었거나 주소가 잘못됐을 수 있어요.', '<br><a class="a-link" href="#/brands">목록으로</a>')}`; return; }
    renderBrand(b);
  };

  function renderBrand(b) {
    const st = normalizeStatus(b.status);
    let bizFail = false;
    v.innerHTML = `<div class="a-crumbs">${back}${navButtons('brands', id, '#/brands')}</div>
      <div class="a-head"><h1>${esc(b.name || '(이름 없음)')} ${statusBadge(b.status)}</h1></div><div style="height:16px"></div>
      <div class="a-detail"><div class="a-detail-main">
        ${st === 'pending' && b.rejectedReason ? banner('warn', '', `이전에 반려된 이력: "${b.rejectedReason}"`) : ''}
        <div class="a-card"><h2>브랜드 정보</h2><div style="margin-bottom:16px">${thumb(b.logoUrl, b.name, true)}</div>
          ${kv([['브랜드 이름', b.name], ['소개', b.description], ['제출자 UID', uidCell(b.submittedBy), true], ['제출 시각', fmtDateTime(b.submittedAt)], ['이전 처리 시각', b.approvedAt ? fmtDateTime(b.approvedAt) : '-']])}</div>
        <div class="a-card" id="biz"><h2>사업자 정보</h2>${kv([['', skel('70%', 14), true], ['', skel('50%', 14), true], ['', skel('60%', 14), true]])}</div>
        ${st === 'rejected' ? `<div class="a-card"><h2>기존 반려 사유</h2><p style="margin:0;white-space:pre-wrap">${esc(b.rejectedReason || '-')}</p></div>` : ''}
      </div><aside class="a-panel a-card" id="panel"></aside></div>`;

    const panel = () => {
      const p = $('#panel'); if (!p) return;
      if (st === 'pending') {
        p.innerHTML = `<h2>결정</h2><div class="a-cap">이 제출 건을 승인하거나 반려해요.</div>
          <div id="decision-banner" style="margin-top:12px">${panelFailHtml(id)}</div>
          <div class="a-btns"><button type="button" class="a-btn primary block lg" id="btn-approve">승인</button>
          <button type="button" class="a-btn block lg" id="btn-reject">반려…</button></div>
          ${bizFail ? '<p class="a-warn-line">사업자 정보를 확인하지 못했어요</p>' : ''}
          <p class="a-note">승인하면 브랜드 키가 함께 발급돼요.<br>반려하면 사유가 제출자에게 전달돼요.</p>`;
        const common = { kind: 'brand', id, name: b.name, submittedAt: b.submittedAt };
        $('#btn-approve').onclick = (e) => openDecision({ ...common, action: 'approve', trigger: e.currentTarget });
        $('#btn-reject').onclick = (e) => openDecision({ ...common, action: 'reject', trigger: e.currentTarget });
        const x = $('#pf-x'); if (x) x.onclick = () => { S.panelFail = null; $('#decision-banner').innerHTML = ''; };
      } else if (st === 'approved') {
        p.innerHTML = `<h2>결정</h2>${banner('', '', '이미 승인된 브랜드예요.')}${kv([['처리 시각', fmtDateTime(b.approvedAt)], ['처리자', uidCell(b.approvedBy), true]])}`;
      } else if (st === 'rejected') {
        p.innerHTML = `<h2>결정</h2>${banner('', '', '반려된 브랜드예요. 제출자의 재제출을 기다려요.')}`;
      } else p.innerHTML = `<h2>결정</h2>${banner('warn', '', '상태를 알 수 없어서 처리할 수 없어요.')}`;
    };
    panel();

    const loadBiz = async () => {
      const box = $('#biz'); if (!box) return;
      box.innerHTML = `<h2>사업자 정보</h2>${kv([['', skel('70%', 14), true], ['', skel('50%', 14), true]])}`;
      try {
        const p = await getBrandPrivate(id);
        if (!alive()) return;
        bizFail = false;
        box.innerHTML = p === null
          ? `<h2>사업자 정보</h2>${banner('', '', '제출된 사업자 정보가 없어요')}`
          : `<h2>사업자 정보</h2>${kv([['회사명', b.companyName], ['사업자번호', p.businessRegistrationNumber], ['대표자', p.representativeName],
              ['담당자', [p.contactName, p.contactPhone].filter(Boolean).join(' / ')], ['본사 주소', p.headOfficeAddress]])}`;
      } catch (e) {
        console.error('[admin] 사업자 정보 조회 실패', e?.code || e);
        if (!alive()) return;
        bizFail = true;
        box.innerHTML = `<h2>사업자 정보</h2><div class="a-err" role="alert"><strong>사업자 정보를 불러오지 못했어요</strong><button type="button" class="a-btn" id="biz-retry">다시 시도</button></div>`;
        $('#biz-retry').onclick = async () => { await loadBiz(); panel(); };
      }
      panel();
    };
    loadBiz();
  }
  load();
}

/* ============================================================================
   A4 매장 승인 큐 / A5 상세
   ========================================================================== */

/** stores 는 status 누락 시 approved 로 취급한다 (앱 StoreModel T1 legacy fallback 과 동일). */
const storeStatus = (s) => (s.status === undefined || s.status === null ? 'approved' : s.status);

async function loadBrandMapSafe() {
  try { return await loadBrandMap(); } catch (e) { console.error('[admin] 브랜드 목록 조회 실패', e?.code || e); return null; }
}

function viewStoreQueue(alive) {
  const flash = flashOnce();
  const v = $('#view');
  v.innerHTML = `${headHtml({ title: '매장 승인', desc: '승인을 기다리는 매장 제출 건이에요. 제출이 오래된 순으로 보여줘요.' })}<div id="notice"></div><div id="box"></div>`;
  const loader = makeLoader({
    alive, box: $('#box'), notice: $('#notice'), cols: 6,
    load: async () => { const [lr, map] = await Promise.all([listPendingStores(), loadBrandMapSafe()]); return { ...lr, map }; },
    render: ({ rows, truncated, map }) => (rows.length === 0
      ? emptyBlock('검토 대기 중인 매장이 없어요', '새 제출이 들어오면 여기에 나타나요.')
      : tableHtml(['매장', '주소', '연결 브랜드', '제출 시각', '상태', ''], rows.map((r) => `<tr class="a-hover">
          <td><div class="a-name"><a href="#/stores/pending/${encodeURIComponent(r.id)}">${esc(r.name || '(이름 없음)')}</a></div></td>
          <td class="a-ell" title="${esc(r.address)}">${esc(r.address || '-')}</td>
          <td>${brandLinkCell(brandLinkOf(r.brandId, map))}</td>
          <td class="a-num">${esc(fmtShortDateTime(r.submittedAt))}</td><td>${statusBadge(r.status)}</td>
          <td><a href="#/stores/pending/${encodeURIComponent(r.id)}">자세히 →</a></td></tr>`)) + totalLine(rows.length, truncated)),
    onData: (d) => { S.order.stores = d.rows.map((r) => r.id); },
    onFail: () => { if (flash) $('#notice').innerHTML = banner('warn', '', '처리는 저장되었지만 목록을 새로 고치지 못했어요. 새로고침을 눌러주세요.'); },
  });
  $('#refresh').onclick = () => { loader.run(true); loadAllCounts(); };
  loader.run(false).then(() => { if (flash && alive()) toast(flash); });
}

const APPROVE_BLOCK_REASON = {
  checking: '브랜드를 확인하고 있어요',
  unapproved: '승인되지 않은 브랜드라 승인할 수 없어요',
  missing: '연결된 브랜드를 찾을 수 없어 승인할 수 없어요',
  lookupFailed: '브랜드를 확인하지 못해 승인할 수 없어요',
};

async function viewStoreDetail(id, alive) {
  const v = $('#view');
  const back = '<a href="#/stores/pending">← 매장 승인 목록</a>';
  const load = async () => {
    v.innerHTML = detailSkeleton('#/stores/pending', '매장 승인 목록');
    let s;
    try { s = await getStore(id); } catch (e) {
      console.error('[admin] 매장 조회 실패', e?.code || e);
      if (!alive()) return;
      v.innerHTML = `<div class="a-crumbs">${back}</div>${errorBlock(e)}`;
      $('[data-retry]', v).onclick = load; return;
    }
    if (!alive()) return;
    if (!s) { v.innerHTML = `<div class="a-crumbs">${back}</div>${emptyBlock('찾을 수 없는 매장이에요', '이미 삭제되었거나 주소가 잘못됐을 수 있어요.', '<br><a class="a-link" href="#/stores/pending">목록으로</a>')}`; return; }
    renderStore(s);
  };

  function renderStore(s) {
    const st = normalizeStatus(storeStatus(s));
    const reapproval = !!s.approvedAt; // 이전 승인 이력 (재심사). 읽기 정보일 뿐 버튼을 막지 않는다.
    let link = s.brandId ? { kind: 'checking' } : { kind: 'personal' };
    const hours = s.businessHours && typeof s.businessHours === 'object'
      ? `${s.businessHours.openTime || '-'} ~ ${s.businessHours.closeTime || '-'}${Array.isArray(s.businessHours.closedDays) && s.businessHours.closedDays.length ? ` (휴무 요일 ${s.businessHours.closedDays.join(', ')})` : ''}`
      : '-';
    const imgs = [...(Array.isArray(s.imageUrls) ? s.imageUrls : []), ...(s.imageUrl && !(s.imageUrls || []).includes(s.imageUrl) ? [s.imageUrl] : [])]
      .map(safeUrl).filter(Boolean);

    v.innerHTML = `<div class="a-crumbs">${back}${navButtons('stores', id, '#/stores/pending')}</div>
      <div class="a-head"><h1>${esc(s.name || '(이름 없음)')} ${statusBadge(storeStatus(s))}</h1></div><div style="height:16px"></div>
      <div class="a-detail"><div class="a-detail-main">
        ${reapproval && st === 'pending' ? banner('', '', '이전에 승인된 적이 있는 매장이에요(재심사 요청).') : ''}
        <div class="a-card"><h2>매장 정보</h2>
          ${imgs.length ? `<div class="a-imgs">${imgs.map((u) => `<a href="${esc(u)}" target="_blank" rel="noopener noreferrer"><img src="${esc(u)}" alt="" loading="lazy" referrerpolicy="no-referrer" data-fb="${letter(s.name)}"></a>`).join('')}</div>` : '<p class="a-cap">등록된 이미지가 없어요</p>'}
          ${kv([['매장 이름', s.name], ['주소', s.address], ['사업자등록번호', s.businessRegistrationNumber],
            ['카테고리', Array.isArray(s.menuCategories) ? s.menuCategories.join(', ') : ''], ['전화번호', s.phone], ['영업시간', hours]])}</div>
        <div class="a-card" id="blink"><h2>연결 브랜드</h2></div>
        <div class="a-card"><h2>제출 정보</h2>
          ${kv([['점주 UID', uidCell(s.ownerId), true], ['제출자 UID', uidCell(s.submittedBy), true], ['제출 시각', fmtDateTime(s.submittedAt)],
            ['처리 시각', st === 'rejected' ? (s.rejectedAt ? `${fmtDateTime(s.rejectedAt)} (반려)` : '-') : fmtDateTime(s.approvedAt)], ['처리자 UID', uidCell(s.approvedBy), true]])}</div>
        ${st === 'rejected' ? `<div class="a-card"><h2>기존 반려 사유</h2><p style="margin:0;white-space:pre-wrap">${esc(s.rejectedReason || '-')}</p></div>` : ''}
      </div><aside class="a-panel a-card" id="panel"></aside></div>`;

    const blink = () => {
      const box = $('#blink'); if (!box) return;
      let inner;
      if (link.kind === 'checking') inner = kv([['', skel('60%', 14), true]]);
      else if (link.kind === 'personal') inner = banner('', '', '브랜드 없이 등록된 매장이에요');
      else if (link.kind === 'approved') inner = `<p style="margin:0">${esc(link.name)} ${statusBadge('approved')} <a href="#/brands/${encodeURIComponent(s.brandId)}" style="margin-left:8px">브랜드 보기 →</a></p>`;
      else if (link.kind === 'unapproved') inner = `${banner('warn', '', '연결된 브랜드가 승인된 상태가 아니에요.')}<p style="margin:0">${esc(link.name)} ${statusBadge(link.status)} <a href="#/brands/${encodeURIComponent(s.brandId)}" style="margin-left:8px">브랜드 보기 →</a></p>`;
      else if (link.kind === 'missing') inner = banner('warn', '', '연결된 브랜드를 찾을 수 없어요.');
      else inner = `${banner('warn', '', '브랜드를 확인하지 못했어요.')}<button type="button" class="a-btn sm" id="blink-retry">다시 시도</button>`;
      box.innerHTML = `<h2>연결 브랜드</h2>${inner}`;
      const r = $('#blink-retry'); if (r) r.onclick = resolveLink;
    };
    const panel = () => {
      const p = $('#panel'); if (!p) return;
      if (st === 'pending') {
        // 앱과 동일: 개인 매장/승인된 브랜드일 때만 승인 버튼을 켠다. 반려는 항상 켠다. (편의 — 최종 판정은 서버)
        const approveOk = link.kind === 'personal' || link.kind === 'approved';
        p.innerHTML = `<h2>결정</h2><div class="a-cap">이 제출 건을 승인하거나 반려해요.</div>
          <div id="decision-banner" style="margin-top:12px">${panelFailHtml(id)}</div>
          <div class="a-btns"><button type="button" class="a-btn primary block lg" id="btn-approve" ${approveOk ? '' : 'disabled'}>승인</button>
          <button type="button" class="a-btn block lg" id="btn-reject">반려…</button></div>
          ${approveOk ? '' : `<p class="a-cap" style="margin:0 0 12px">${esc(APPROVE_BLOCK_REASON[link.kind] || '')}</p>`}
          <p class="a-note">반려는 이번 제출 건에 대한 결정이에요.${reapproval ? ' 이미 승인된 매장의 승인을 되돌리는 동작이 아니에요.' : ''}</p>`;
        const common = { kind: 'store', id, name: s.name, submittedAt: s.submittedAt, brandId: s.brandId || '', reapproval };
        $('#btn-approve').onclick = (e) => openDecision({ ...common, action: 'approve', trigger: e.currentTarget });
        $('#btn-reject').onclick = (e) => openDecision({ ...common, action: 'reject', trigger: e.currentTarget });
        const x = $('#pf-x'); if (x) x.onclick = () => { S.panelFail = null; $('#decision-banner').innerHTML = ''; };
      } else if (st === 'approved') {
        p.innerHTML = `<h2>결정</h2>${banner('', '', '이미 승인된 매장이에요.')}`;
      } else if (st === 'rejected') {
        p.innerHTML = `<h2>결정</h2>${banner('', '', '반려된 매장이에요. 점주의 재제출을 기다려요.')}`;
      } else p.innerHTML = `<h2>결정</h2>${banner('warn', '', '상태를 알 수 없어서 처리할 수 없어요.')}`;
    };
    async function resolveLink() {
      if (!s.brandId) { link = { kind: 'personal' }; blink(); panel(); return; }
      link = { kind: 'checking' }; blink(); panel();
      try {
        const b = await getBrand(s.brandId);
        if (!alive()) return;
        link = b === null ? { kind: 'missing' } : { kind: b.status === 'approved' ? 'approved' : 'unapproved', name: b.name || '(이름 없음)', status: b.status };
      } catch (e) {
        console.error('[admin] 연결 브랜드 조회 실패', e?.code || e);
        if (!alive()) return;
        link = { kind: 'lookupFailed' };
      }
      blink(); panel();
    }
    blink(); panel(); resolveLink();
  }
  load();
}

/* ============================================================================
   A6 마스터 메뉴 / A7 매장 커스텀 (읽기 전용 — 행에 링크·버튼 없음)
   열 구성은 실제 필드에 맞췄다 (lib/data/models/menu_item_model.dart, menu_override_model.dart).
   ========================================================================== */

/** id 배열을 상한(cap)까지만 조회해 id→값 맵으로. 실패/상한 초과 항목은 맵에 없다 (호출자가 '-' 처리). */
async function resolveMap(ids, fetcher, cap = 200) {
  const uniq = [...new Set(ids.filter(Boolean))].slice(0, cap);
  const out = new Map();
  await Promise.all(uniq.map(async (k) => {
    try { out.set(k, await fetcher(k)); } catch (e) { console.error('[admin] 이름 조회 실패', e?.code || e); }
  }));
  return out;
}

function viewReadOnlyQueue(alive, { title, listFn, cols, emptyTitle, render }) {
  const v = $('#view');
  v.innerHTML = `${headHtml({ title, tag: '읽기 전용' })}
    ${banner('', '', '이 목록은 조회만 할 수 있어요. 승인과 반려는 앱에서 처리해주세요.')}<div id="notice"></div><div id="box"></div>`;
  const loader = makeLoader({
    alive, box: $('#box'), notice: $('#notice'), cols, load: listFn,
    render: (d) => (d.rows.length === 0 ? emptyBlock(emptyTitle, '') : render(d)),
  });
  $('#refresh').onclick = () => { loader.run(true); loadAllCounts(); };
  loader.run(false);
}

function viewMenus(alive) {
  viewReadOnlyQueue(alive, {
    title: '마스터 메뉴 승인', cols: 5, emptyTitle: '검토 대기 중인 메뉴가 없어요',
    listFn: async () => { const [lr, map] = await Promise.all([listPendingMenus(), loadBrandMapSafe()]); return { ...lr, map }; },
    render: ({ rows, truncated, map }) => tableHtml(['메뉴', '브랜드', '가격', '제출 시각', '상태'], rows.map((r) => `<tr>
      <td><strong>${esc(r.name || '(이름 없음)')}</strong></td>
      <td>${esc(map && map.get(r.brandId)?.name ? map.get(r.brandId).name : shortUid(r.brandId))}</td>
      <td class="a-num">${esc(fmtKrw(r.basePrice))}</td><td class="a-num">${esc(fmtShortDateTime(r.submittedAt))}</td><td>${statusBadge(r.status)}</td></tr>`)) + totalLine(rows.length, truncated),
  });
}

function overrideKinds(r) {
  const k = [];
  if (typeof r.priceOverride === 'number') k.push('가격 변경');
  if (r.excluded === true) k.push('이 매장 제외');
  if (r.soldOut === true) k.push('품절');
  if ((r.disabledOptionGroupIds || []).length || (r.disabledOptionItemIds || []).length) k.push('옵션 비활성');
  return k.length ? k.join(', ') : '변경 내용 없음';
}

function viewOverrides(alive) {
  viewReadOnlyQueue(alive, {
    title: '매장 커스텀 승인', cols: 6, emptyTitle: '검토 대기 중인 매장 커스텀이 없어요',
    listFn: async () => {
      const lr = await listPendingOverrides();
      const [stores, menus] = await Promise.all([
        resolveMap(lr.rows.map((r) => r.storeId), async (sid) => (await getStore(sid))?.name ?? null),
        resolveMap(lr.rows.map((r) => `${r.brandId}/${r.masterMenuItemId}`), async (k) => { const [b, m] = k.split('/'); return b && m ? (await getMasterMenu(b, m))?.name ?? null : null; }),
      ]);
      return { ...lr, stores, menus };
    },
    render: ({ rows, truncated, stores, menus }) => tableHtml(['메뉴', '매장', '변경 유형', '변경 가격', '제출 시각', '상태'], rows.map((r) => `<tr>
      <td><strong>${esc(menus.get(`${r.brandId}/${r.masterMenuItemId}`) || '-')}</strong></td>
      <td>${esc(stores.get(r.storeId) || shortUid(r.storeId))}</td><td>${esc(overrideKinds(r))}</td>
      <td class="a-num">${esc(typeof r.priceOverride === 'number' ? fmtKrw(r.priceOverride) : '-')}</td>
      <td class="a-num">${esc(fmtShortDateTime(r.submittedAt))}</td><td>${statusBadge(r.status)}</td></tr>`)) + totalLine(rows.length, truncated),
  });
}

/* ============================================================================
   A8 매장 목록 (읽기 전용, 전량 로드 + 클라이언트 필터/페이징 25건)
   ========================================================================== */

function viewStoreList(alive) {
  const v = $('#view');
  const PAGE = 25;
  const f = { q: '', status: 'all', page: 0 };
  let data = null;
  v.innerHTML = `${headHtml({ title: '매장 목록', desc: '전체 매장을 조회해요.' })}<div id="notice"></div>
    <div class="a-toolbar" id="tools"></div><div id="box"></div>`;

  const FILTERS = [['all', '전체'], ['pending', '대기'], ['approved', '승인됨'], ['rejected', '반려됨']];
  const tools = (disabled) => {
    $('#tools').innerHTML = `<label class="a-sr" for="q">매장 이름·주소 검색</label>
      <input class="a-input" id="q" type="search" placeholder="매장 이름·주소 검색" value="${esc(f.q)}" ${disabled ? 'disabled' : ''}>
      <div class="a-chips" role="radiogroup" aria-label="상태 필터">${FILTERS.map(([k, l]) =>
        `<button type="button" class="a-fchip" role="radio" aria-checked="${f.status === k}" data-f="${k}" ${disabled ? 'disabled' : ''}>${l}</button>`).join('')}</div>`;
    if (disabled) return;
    let t;
    $('#q').addEventListener('input', (e) => { clearTimeout(t); t = setTimeout(() => { f.q = e.target.value; f.page = 0; draw(); }, 150); });
    document.querySelectorAll('[data-f]').forEach((b) => { b.onclick = () => { f.status = b.dataset.f; f.page = 0; tools(false); $('#q').value = f.q; draw(); }; });
  };

  function draw() {
    const box = $('#box'); if (!box || !data) return;
    const q = f.q.trim().toLowerCase();
    const all = data.rows;
    const hit = all.filter((s) => (f.status === 'all' || storeStatus(s) === f.status)
      && (!q || String(s.name || '').toLowerCase().includes(q) || String(s.address || '').toLowerCase().includes(q)));
    if (all.length === 0) { box.innerHTML = emptyBlock('등록된 매장이 없어요', ''); return; }
    if (hit.length === 0) {
      box.innerHTML = emptyBlock('조건에 맞는 매장이 없어요', '', '<br><button type="button" class="a-link" id="clear-f">필터 지우기</button>');
      $('#clear-f').onclick = () => { f.q = ''; f.status = 'all'; f.page = 0; tools(false); draw(); };
      return;
    }
    const pages = Math.ceil(hit.length / PAGE);
    f.page = Math.min(f.page, pages - 1);
    const slice = hit.slice(f.page * PAGE, f.page * PAGE + PAGE);
    box.innerHTML = tableHtml(['매장', '주소', '연결 브랜드', '상태', '승인 메타(처리자·시각)', ''], slice.map((s) => {
      const st = storeStatus(s);
      // 반려 매장에는 approvedAt 을 표시하지 않는다 (반려 시각은 rejectedAt — 승인 이력과 분리).
      const meta = st === 'approved' ? `${shortUid(s.approvedBy)} · ${fmtShortDateTime(s.approvedAt)}`
        : st === 'rejected' ? `반려 ${shortUid(s.approvedBy)} · ${fmtShortDateTime(s.rejectedAt)}` : '-';
      return `<tr><td><strong>${esc(s.name || '(이름 없음)')}</strong></td><td class="a-ell" title="${esc(s.address)}">${esc(s.address || '-')}</td>
        <td>${brandLinkCell(brandLinkOf(s.brandId, data.map))}</td><td>${statusBadge(st)}</td><td class="a-num">${esc(meta)}</td>
        <td>${st === 'pending' ? `<a href="#/stores/pending/${encodeURIComponent(s.id)}">승인 상세 →</a>` : ''}</td></tr>`;
    })) + `<div class="a-pager"><span>총 ${all.length}건${hit.length !== all.length ? ` (검색 결과 ${hit.length}건)` : ''}${data.truncated ? ' · 일부만 불러왔어요' : ''}</span>
      <span style="margin-left:auto;display:flex;gap:12px;align-items:center"><button type="button" class="a-btn sm" id="pg-prev" ${f.page === 0 ? 'disabled' : ''}>이전</button>
      <span class="a-num">${f.page + 1} / ${pages}</span><button type="button" class="a-btn sm" id="pg-next" ${f.page >= pages - 1 ? 'disabled' : ''}>다음</button></span></div>`;
    $('#pg-prev').onclick = () => { f.page--; draw(); };
    $('#pg-next').onclick = () => { f.page++; draw(); };
  }

  const loader = makeLoader({
    alive, box: $('#box'), notice: $('#notice'), cols: 6,
    load: async () => { const [lr, map] = await Promise.all([listAllStores(), loadBrandMapSafe()]); return { ...lr, map }; },
    render: (d) => { data = d; tools(false); return ''; },
    onData: () => draw(),
    onFail: () => { $('#tools').innerHTML = ''; },
  });
  tools(true);
  $('#refresh').onclick = () => { loader.run(true); loadAllCounts(); };
  loader.run(false);
}

/* ============================================================================
   A9 Qoin 현황 (읽기 전용 — 입력·토글·변경 버튼 없음)
   ========================================================================== */

const HIST_FIELD = { accrualRate: '적립률', globalEnabled: '비상 정지' };
function histVal(field, v) {
  if (field === 'accrualRate') return typeof v === 'number' ? fmtRatePct(v) : '미설정';
  if (field === 'globalEnabled') return v === true ? '적립 중' : v === false ? '비상 정지' : '-';
  return '-';
}

function viewQoin(alive) {
  const v = $('#view');
  v.innerHTML = `${headHtml({ title: 'Qoin 현황', tag: '읽기 전용' })}
    ${banner('', '', '이 화면은 조회만 할 수 있어요. 적립률 변경과 비상 정지는 앱에서 처리해주세요.')}
    <div id="q-warn"></div><div id="q-cards"></div>
    <div class="a-section" style="margin-top:32px"><h2 class="a-h2">전역 적립률 변경 이력 (최근 20건)</h2><div id="q-hist"></div></div>`;
  const stamp = () => { const st = $('#stamp'); if (st && alive()) st.textContent = `마지막 갱신 ${fmtClock()}`; };

  async function loadHist() {
    const box = $('#q-hist'); box.innerHTML = skelRows(5);
    try {
      const rows = await listQoinHistory(20);
      if (!alive()) return;
      box.innerHTML = rows.length === 0 ? emptyBlock('전역 적립률 변경 이력이 없어요', '')
        : tableHtml(['변경 시각', '항목', '변경 전 → 후', '처리자', '사유'], rows.map((r) => {
          const reason = typeof r.reason === 'string' ? r.reason : '';
          return `<tr><td class="a-num">${esc(fmtDateTime(r.changedAt))}</td><td>${esc(HIST_FIELD[r.field] || '(알 수 없는 항목)')}</td>
            <td class="a-num">${esc(histVal(r.field, r.before))} → ${esc(histVal(r.field, r.after))}</td><td>${uidCell(r.changedBy)}</td>
            <td class="a-ell" title="${esc(reason)}">${esc(reason.length > 200 ? `${reason.slice(0, 200)}…` : reason || '-')}</td></tr>`;
        }));
    } catch (e) {
      console.error('[admin] Qoin 이력 조회 실패', e?.code || e);
      if (!alive()) return;
      box.innerHTML = errorBlock(e);
      $('[data-retry]', box).onclick = loadHist;
    }
  }
  const loadCards = () => loadQoinInto($('#q-cards'), alive, { warnBox: $('#q-warn'), onOk: stamp });
  $('#refresh').onclick = () => { loadCards(); loadHist(); };
  loadCards(); loadHist();
}

/* ============================================================================
   승인 / 반려 모달 (A3, A5) — 확인 단계, 사유 입력, 실패 복귀
   - 확정 직전에 서버에서 상태를 다시 읽는다 (console-data.js 의 트랜잭션 / assertPendingNow).
   - 응답 전에는 화면 어느 곳도 '처리됨'으로 바꾸지 않는다. 성공 후 큐로 이동해 서버에서 다시 조회한다.
   - 반려 사유 상한 없음 (D2): 글자 수만 표시하고, 필수 + trim 후 1자 이상만 요구한다.
   ========================================================================== */

function openDecision(o) {
  if (S.modal) return;
  const isBrand = o.kind === 'brand';
  const isApprove = o.action === 'approve';
  const noun = isBrand ? '브랜드' : '매장';
  const queueHash = isBrand ? '#/brands' : '#/stores/pending';
  const st = { busy: false, locked: false, failed: null };

  const ov = document.createElement('div');
  ov.className = 'a-overlay';
  const idShort = o.id.length > 8 ? `${o.id.slice(0, 6)}…` : o.id;
  const stepsHtml = isBrand && isApprove
    ? '<ul class="a-steps" id="m-steps" hidden><li data-s="0"><span class="a-sdot"></span>브랜드 키 발급</li><li data-s="1"><span class="a-sdot"></span>승인 기록</li></ul>' : '';
  const bodyHtml = isApprove
    ? `<p class="a-ask">${isBrand ? '이 브랜드를' : '이 매장을'} 승인할까요?</p>${isBrand ? '<p class="a-ask-sub">승인하면 브랜드 키가 함께 발급돼요.</p>' : ''}${stepsHtml}`
    : `<label class="a-label" for="m-reason">반려 사유 (필수)</label>
       <textarea class="a-textarea" id="m-reason" aria-describedby="m-reason-err m-hint"></textarea>
       <div class="a-field-err" id="m-reason-err" hidden>반려 사유를 입력해주세요</div>
       <div class="a-count-line"><span id="m-hint">제출자에게 전달되는 내용이에요.</span><span class="a-num" id="m-count">0자</span></div>
       <p class="a-cap" style="margin-top:12px">반려는 이번 제출 건에 대한 결정이에요.${!isBrand && o.reapproval ? ' 이미 승인된 매장의 승인을 되돌리는 동작이 아니에요.' : ''}</p>`;
  ov.innerHTML = `<div class="a-modal" role="dialog" aria-modal="true" aria-labelledby="m-title">
    <h2 id="m-title">${isApprove ? `${noun} 승인` : '이 제출 건 반려'}</h2>
    <div class="a-target"><b>${esc(o.name || '(이름 없음)')}</b><small>제출 ${esc(fmtDateTime(o.submittedAt))} · ID ${esc(idShort)}</small></div>
    ${bodyHtml}<div id="m-msg" style="margin-top:14px"></div>
    <div class="a-modal-foot" id="m-foot"><button type="button" class="a-btn lg" id="m-cancel">취소</button>
      <button type="button" class="a-btn lg ${isApprove ? 'primary' : 'reject-confirm'}" id="m-ok" ${isApprove ? '' : 'aria-disabled="true"'}>${isApprove ? '승인 확정' : '반려 확정'}</button></div></div>`;
  document.body.appendChild(ov);

  const modal = $('.a-modal', ov);
  const okBtn = $('#m-ok', ov); const cancelBtn = $('#m-cancel', ov);
  const ta = $('#m-reason', ov);
  const label = isApprove ? '승인 확정' : '반려 확정';
  const q = (sel) => $(sel, ov);

  function setBusy(b, text) {
    modal.setAttribute('aria-busy', String(b));
    ov.querySelectorAll('button, textarea').forEach((el) => { el.disabled = b || (el.id === 'm-ok' && st.locked); });
    okBtn.innerHTML = b ? `<span class="a-spin"></span>${esc(text || '처리 중…')}` : label;
    if (ta) ta.disabled = b;
  }
  function syncOk() {
    if (isApprove) { okBtn.disabled = st.locked; return; }
    const ok = validateReason(ta.value).ok && !st.locked;
    okBtn.setAttribute('aria-disabled', String(!ok));
  }
  const showMsg = (html) => { q('#m-msg').innerHTML = html ? `<div id="m-msg-in" tabindex="-1">${html}</div>` : ''; if (html) q('#m-msg-in').focus(); };
  function reasonErr(show) {
    const e = q('#m-reason-err'); e.hidden = !show;
    ta.setAttribute('aria-invalid', String(show));
  }

  if (ta) {
    ta.addEventListener('input', () => {
      q('#m-count').textContent = `${[...ta.value].length}자`;
      if (validateReason(ta.value).ok) reasonErr(false);
      syncOk();
    });
    ta.addEventListener('blur', () => { if (!validateReason(ta.value).ok) reasonErr(true); });
    ta.addEventListener('keydown', (e) => { if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') { e.preventDefault(); confirm(); } });
  }

  function onStep(step) {
    const steps = q('#m-steps'); if (!steps) return;
    steps.hidden = false;
    const idx = step === 'record' ? 1 : 0;
    steps.querySelectorAll('li').forEach((li) => {
      const i = Number(li.dataset.s);
      li.className = i < idx ? 'done' : i === idx ? 'now' : '';
    });
    okBtn.innerHTML = `<span class="a-spin"></span>${idx === 0 ? '브랜드 키 발급 중…' : '승인 기록 중…'}`;
  }

  function addFootButton(id, text, handler) {
    const b = document.createElement('button');
    b.type = 'button'; b.className = 'a-btn lg'; b.id = id; b.textContent = text; b.onclick = handler;
    q('#m-foot').insertBefore(b, cancelBtn);
    return b;
  }
  const goQueue = () => { destroy(); if (location.hash === queueHash) route(); else location.hash = queueHash; };

  function fail(e) {
    console.error('[admin] 승인/반려 실패', e?.stage || '', e?.code || e?.name || e);
    const kind = classifyError(e).kind;
    let t = writeErrorText(e);
    if (isBrand && isApprove && e?.stage === 'issueKey' && ['other', 'timeout', 'precondition', 'invalid', 'rate-limited', 'parse'].includes(kind)) {
      t = { unknown: false, lock: false, expired: false, text: '브랜드 키 발급에 실패했어요. 승인은 저장되지 않았어요. 다시 시도해주세요.' };
    } else if (isBrand && isApprove && e?.stage === 'record' && !t.unknown && !t.lock && !t.expired) {
      t = { ...t, text: kind === 'other' ? '브랜드 키는 발급되었지만 승인 상태를 저장하지 못했어요. 다시 시도하면 이어서 처리돼요.' : `${t.text} (브랜드 키는 이미 발급되었어요.)` };
    }
    showMsg(banner('error', '실패', t.text + (t.expired ? ' 입력한 내용은 보존되지 않아요.' : '')));
    if (t.expired) {
      setTimeout(() => { S.loginNotice = '세션이 만료되었어요. 다시 로그인해주세요.'; destroy(); signOutNow(); }, 3000);
      return;
    }
    if (t.unknown) {
      st.locked = true; st.failed = { unknown: true };
      syncOk(); okBtn.disabled = true;
      const chk = addFootButton('m-check', '상태 확인하기', () => checkStatus(chk));
    } else if (t.lock) {
      st.locked = true; syncOk(); okBtn.disabled = true;
      addFootButton('m-list', '목록으로', goQueue);
    } else {
      st.failed = { unknown: false };
    }
  }

  async function checkStatus(btn) {
    btn.disabled = true; btn.textContent = '확인 중…';
    try {
      const cur = await readCurrentStatus(o.kind, o.id);
      if (cur === 'pending') {
        st.locked = false; st.failed = { unknown: false }; btn.remove(); okBtn.disabled = false; syncOk();
        showMsg(banner('', '', '아직 대기 중이에요. 확정을 다시 시도할 수 있어요.'));
      } else {
        st.failed = null; btn.remove();
        addFootButton('m-list', '목록으로', goQueue);
        showMsg(banner('', '', `현재 상태: ${STATUS_LABEL[normalizeStatus(cur)] || '알 수 없음'}. 목록을 새로 고쳐주세요.`));
      }
    } catch (e) {
      console.error('[admin] 상태 확인 실패', e?.code || e);
      btn.disabled = false; btn.textContent = '상태 확인하기';
      showMsg(banner('error', '실패', '상태를 확인하지 못했어요. 잠시 후 다시 시도해주세요.'));
    }
  }

  async function confirm() {
    if (st.busy || st.locked) return;
    let reason = '';
    if (!isApprove) {
      const r = validateReason(ta.value);
      if (!r.ok) { reasonErr(true); ta.focus(); return; }
      reason = r.value; // trim 한 값을 저장한다
    }
    st.busy = true; S.busy = true; st.failed = null;
    showMsg('');
    setBusy(true, isApprove ? (isBrand ? '확인 중…' : '승인 중…') : '반려 중…');
    try {
      if (isBrand) await (isApprove ? approveBrand(o.id, onStep) : rejectBrand(o.id, reason));
      else await (isApprove ? approveStore(o.id, o.brandId) : rejectStore(o.id, reason));
    } catch (e) {
      st.busy = false; S.busy = false;
      setBusy(false); syncOk();
      fail(e);
      return;
    }
    st.busy = false; S.busy = false;
    // 서버가 성공을 응답했다. 로컬에서 항목을 지우지 않고, 큐로 이동해 서버에서 다시 조회한다.
    S.flash = isApprove ? '승인했어요' : '반려했어요';
    S.panelFail = null;
    destroy();
    loadAllCounts();
    if (location.hash === queueHash) route(); else location.hash = queueHash;
  }

  function destroy() {
    if (!S.modal) return;
    S.modal = null;
    ov.remove();
    document.removeEventListener('keydown', onKey, true);
    if (o.trigger && document.contains(o.trigger)) o.trigger.focus();
  }
  function close() {
    if (st.busy) return;
    const failed = st.failed;
    destroy();
    if (failed) { // 실패 후 닫으면 상세 화면에 영구 배너를 남긴다 (사라지는 토스트로 보내지 않는다)
      S.panelFail = { id: o.id, time: fmtClock(), unknown: !!failed.unknown };
      route();
    }
  }
  function onKey(e) {
    if (e.key === 'Escape') { e.preventDefault(); if (!st.busy) close(); return; }
    if (e.key !== 'Tab') return;
    const items = [...modal.querySelectorAll('button:not([disabled]), textarea:not([disabled])')];
    if (items.length === 0) { e.preventDefault(); return; }
    const first = items[0]; const last = items[items.length - 1];
    if (e.shiftKey && (document.activeElement === first || !modal.contains(document.activeElement))) { e.preventDefault(); last.focus(); }
    else if (!e.shiftKey && (document.activeElement === last || !modal.contains(document.activeElement))) { e.preventDefault(); first.focus(); }
  }
  document.addEventListener('keydown', onKey, true);

  cancelBtn.onclick = close;
  okBtn.onclick = () => {
    if (!isApprove && okBtn.getAttribute('aria-disabled') === 'true') { reasonErr(true); ta.focus(); return; }
    confirm();
  };
  ov.addEventListener('mousedown', (e) => {
    if (e.target !== ov || st.busy) return;
    if (ta && ta.value.trim()) return; // 입력 손실 방지: 사유가 있으면 바깥 클릭으로 닫지 않는다
    close();
  });

  S.modal = { get busy() { return st.busy; }, close, destroy };
  (ta || cancelBtn).focus(); // 승인: 취소에 포커스(Enter 한 번에 확정되지 않게) / 반려: 사유 입력창
}

/* ============================================================================
   시작
   ========================================================================== */

function boot() {
  if (!isFirebaseConfigured) { renderConfigMissing(); return; }
  try {
    initFirebase();
  } catch (e) {
    console.error('[admin] Firebase 초기화 실패', e);
    renderConfigMissing();
    return;
  }
  renderChecking(); // Auth 복원이 끝날 때까지 로그인 폼을 먼저 깜빡이지 않는다
  onAuthChanged(handleAuth);
}

boot();

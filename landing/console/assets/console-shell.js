/* ============================================================================
   Qradar 콘솔 셸 — 로그인 · 역할 판정 게이트 · 역할별 셸 · 해시 라우터 · 역할 변경 복구.
   데이터 접근은 전부 console-data.js (Firebase SDK 는 그 파일에서만 import).
   역할별 화면은 section-{admin,brand,owner,customer}.js 이고, 판정된 역할의 섹션만 동적 import() 한다.

   [읽기 전에 — 보안 모델 (spec §4.2)]
   이 콘솔은 클라이언트일 뿐이다. 권한의 최종 권위는 Firestore Security Rules 와 Cloud Functions 에 있다.
   이 파일의 분기(역할 판정 전에는 셸을 만들지 않음, 역할별 네비, 다른 역할 해시를 기본 화면으로 되돌림)는
   사용자의 혼동과 실수를 줄이는 편의이며, 접근을 통제하지 않는다. 해시를 직접 고쳐도, DOM 을 고쳐도
   모든 read/write 는 서버가 다시 판정한다. 그래서 이 콘솔은 어떤 응답이든 서버의 판정을 그대로 보여준다.
   - 역할(role) 부여/변경 기능은 없다. admin 승격은 Firestore Console 에서 users.role='admin' 수동 설정뿐이다.
   - 낙관적 UI 없음: 쓰기 성공 응답 전에 목록·건수·배지를 바꾸지 않고, 성공 후에도 서버에서 다시 조회해 그린다.
   - 역할 변경은 폴링하지 않는다. 섹션의 읽기/쓰기가 permission-denied 일 때 users/{uid} 를 다시 읽어 확인한다 (C4).

   [landing/ 과 Clean Architecture] landing/ 은 Flutter 앱(lib/)의 레이어 규칙 밖이다 (spec §8.4). console-data.js 주석 참고.
   ========================================================================== */

import {
  isFirebaseConfigured,
} from './firebase-config.js';
import {
  initFirebase, onAuthChanged, signInEmail, signInGoogle, signOutNow, readUserRole,
} from './console-data.js';
import {
  esc, classifyError, loginErrorText, ROLE_LABEL, ROLE_SUBTITLE, sameRole, rawRoleText,
} from './console-format.js';
import {
  S, root, hooks, $, $$, LOGO, banner, confirmLeave, clearDirty,
} from './console-ui.js';

/* ── 섹션 로더: 판정된 역할의 코드만 내려받는다 ─────────────────────────────── */
const SECTION_LOADERS = {
  admin: () => import('./section-admin.js'),
  brand: () => import('./section-brand.js'),
  owner: () => import('./section-owner.js'),
  customer: () => import('./section-customer.js'),
};

hooks.signOut = () => { signOutNow(); };

/* ============================================================================
   게이트 — 역할 판정이 끝나기 전에는 셸(사이드바·본문) DOM 을 만들지 않고 데이터 요청도 보내지 않는다.
   ========================================================================== */

function gate(inner) {
  clearTimeout(S.checkTimer);
  clearInterval(S.autoOutTimer); S.autoOutTimer = null;
  teardownShell();
  S.roleNotice = null;
  root.innerHTML = `<div class="a-gate"><div class="a-gate-wrap">${inner}</div></div>`;
}

const gateLogo = `<div class="a-logo">${LOGO}</div>`;

function renderConfigMissing() {
  gate(`<div class="a-gate-card" role="alert">${gateLogo}<h2>설정이 필요해요</h2>
    <p>Firebase 웹 앱 설정(apiKey, appId)이 비어 있어 로그인할 수 없어요.</p>
    <p class="a-cap">assets/firebase-config.js 에 Firebase Console 의 웹 앱 SDK 설정값을 채워주세요. 자세한 방법은 console/README.md 를 참고하세요.</p></div>`);
}

function renderChecking() {
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
  gate(`<div class="a-gate-card">${gateLogo}<h1>Qradar 콘솔</h1>
    <p class="a-sub">계정으로 로그인하세요</p>
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
    <p class="a-cap">Naver·Kakao 로 가입한 계정은 아직 웹에서 로그인할 수 없어요</p>`);

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
    if (e) console.error('[console] 로그인 실패', e?.code || e);
    $('#lg-msg').innerHTML = text ? banner('error', '', text) : '';
  };
  const fieldErr = (id, msg) => {
    const el = $(`#${id}-err`);
    el.hidden = !msg; el.textContent = msg || '';
    $(`#${id}`).setAttribute('aria-invalid', msg ? 'true' : 'false');
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

/** 모르는 role 안내 화면을 몇 초 보여준 뒤 자동 로그아웃할지. */
const UNKNOWN_ROLE_AUTO_OUT_SEC = 5;
const UNKNOWN_ROLE_NOTICE = '이 계정의 권한을 확인할 수 없어 로그아웃했어요.';

/**
 * G3 — users/{uid}.role 이 있는데 admin/brand/owner/customer 어느 것도 아닌 값일 때. 5초 자동 로그아웃이 남은 **유일한** 지점이다.
 *
 * 여기서 로그아웃하는 것은 **공용 PC 에 세션이 방치되지 않게 하려는 것**이지 접근을 막는 수단이 아니다 —
 * 접근은 이미 Firestore Rules 가 막는다(이 화면이 떴다는 것은 콘솔이 어떤 섹션도 열지 않았고 데이터 요청도 만들지 않았다는 뜻).
 * 이전에는 admin 이 아닌 모든 계정이 이 경로를 탔다. 역할별 콘솔에서는 brand·owner·customer 가 정당한 사용자이므로
 * 문서/필드가 없는 경우(= customer)와 정상 role 은 자동 로그아웃하지 않는다.
 */
function renderUnknownRole(user, info) {
  const my = S.authGen;
  gate(`<div class="a-gate-card">${gateLogo}<h2>이 계정의 권한 정보를<br>확인할 수 없어요</h2>
    <p>계정 정보에 콘솔이 모르는 권한 값이 들어 있어요. 현재 계정:</p>
    <p><strong>${esc(user.email || user.uid)}</strong></p>
    <p class="a-cap">권한 값: <span id="ur-raw"></span></p>
    <p>운영 담당자에게 문의해주세요.</p>
    <p class="a-cap" id="na-count">${UNKNOWN_ROLE_AUTO_OUT_SEC}초 후 자동으로 로그아웃돼요.</p>
    <button type="button" class="a-btn block lg" id="na-out">지금 로그아웃</button></div>`);
  $('#ur-raw').textContent = rawRoleText(info.raw); // textContent 로만 삽입

  let left = UNKNOWN_ROLE_AUTO_OUT_SEC;
  const leave = () => {
    clearInterval(S.autoOutTimer); S.autoOutTimer = null;
    if (my !== S.authGen) return;          // 그 사이 인증 상태가 바뀌었으면 아무것도 하지 않는다
    S.loginNotice = UNKNOWN_ROLE_NOTICE;
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
    ${k === 'permission' ? '<p class="a-cap">계정 정보를 읽을 수 없는 상태예요. 계속되면 운영 담당자에게 문의해주세요.</p>' : ''}
    <div class="a-gate-actions"><button type="button" class="a-btn" id="rf-retry">다시 시도</button>
    <button type="button" class="a-btn" id="rf-out">로그아웃</button></div></div>`);
  $('#rf-out').onclick = () => signOutNow();
  $('#rf-retry').onclick = (ev) => {
    ev.target.disabled = true; ev.target.innerHTML = '<span class="a-spin"></span>확인 중…';
    checkRole(user, my);
  };
}

/**
 * users/{uid} 를 읽어 역할에 맞는 셸을 연다 (DV-3).
 *   읽기 실패·타임아웃·형식 이상 → fail-closed (G2)
 *   문서/필드 부재 → customer (정상 상태) / 모르는 role → G3
 */
async function checkRole(user, my) {
  let info;
  let mod;
  try {
    info = await readUserRole(user.uid);
    if (my !== S.authGen) return;
    if (info.kind === 'unknown') { renderUnknownRole(user, info); return; }
    mod = await SECTION_LOADERS[info.role]();
  } catch (e) {
    console.error('[console] 역할 판정/섹션 로드 실패 — 닫힘 유지', e?.code || e);
    if (my !== S.authGen) return;
    renderRoleFail(user, e, my);
    return;
  }
  if (my !== S.authGen) return;
  openShell({ uid: user.uid, email: user.email || '' }, info, mod);
}

function handleAuth(user) {
  const my = ++S.authGen;
  if (!user) {
    // 사용자가 직접 로그아웃했으면 loginNotice 가 ''(안내 없음). 아니면 셸 이용 중 세션이 끊긴 것이다.
    const n = S.loginNotice; S.loginNotice = null;
    renderLogin(n !== null ? n : (S.shell ? '세션이 만료되었어요. 다시 로그인해주세요.' : null));
    return;
  }
  renderChecking();
  checkRole(user, my);
}

/* ============================================================================
   셸
   ========================================================================== */

function shellHtml(email, role) {
  return `<div class="a-shell" data-role="${esc(role)}">
    <a class="skip" href="#main" id="skip">본문으로 건너뛰기</a>
    <aside class="a-side"><div class="a-brandbox"><span class="brand">${LOGO}<span class="brand-word">Qradar</span></span><small>${esc(ROLE_SUBTITLE[role])}</small></div>
      <div id="ctx"></div>
      <nav aria-label="주 메뉴" id="nav"></nav>
      <div class="a-account"><div class="a-email" title="${esc(email)}">${esc(email)}</div>
        <div class="a-role"><span class="a-chip a-role-chip" aria-label="현재 역할: ${esc(ROLE_LABEL[role])}">${esc(ROLE_LABEL[role])}</span></div>
        <button type="button" class="a-btn sm block" id="logout">로그아웃</button></div></aside>
    <main class="a-main" id="main" tabindex="-1"><div id="role-notice"></div><div class="a-main-inner" id="view"></div></main></div>`;
}

function openShell(user, info, mod) {
  clearTimeout(S.checkTimer);
  clearInterval(S.autoOutTimer); S.autoOutTimer = null;
  S.shell = { uid: user.uid, email: user.email, role: info.role, brandId: info.brandId, info };
  S.section = mod;
  S.viewGen++; S.dirty = null; S.busy = false;
  root.innerHTML = shellHtml(user.email, info.role);
  $('#logout').onclick = () => { S.loginNotice = ''; signOutNow(); };
  $('#skip').onclick = (e) => { e.preventDefault(); $('#main').focus(); };
  window.addEventListener('hashchange', onHashChange);
  document.title = `Qradar · ${ROLE_SUBTITLE[info.role]}`;
  showRoleNotice();
  S.section.start();                      // admin: 건수 로드 / owner: 매장 로드 — 각 섹션이 자기 일을 시작한다
  renderContext();
  renderNav();
  S.curHash = location.hash;
  if (!S.section.match(parseHash())) hooks.go(S.section.meta.defaultHash); else route();
}

function teardownShell() {
  if (!S.shell) return;
  try { S.section?.stop?.(); } catch (e) { console.error('[console] 섹션 정리 실패', e); }
  S.shell = null; S.section = null; S.viewGen++; S.order = {}; S.flash = null; S.panelFail = null; S.busy = false; S.dirty = null;
  if (S.modal) S.modal.destroy();
  window.removeEventListener('hashchange', onHashChange);
}

/* ── 네비 / 컨텍스트 ─────────────────────────────────────────────────────── */

export function renderNav() {
  const nav = $('#nav');
  if (!nav || !S.section) return;
  const groups = S.section.navGroups();
  nav.innerHTML = groups.map((g) => `<div class="a-nav-group">${esc(g.group)}${g.ro ? '<span class="a-chip">읽기</span>' : ''}</div><ul class="a-nav">${g.items.map((i) =>
    `<li><a href="${i.href}" data-nav="${i.key}"><span class="a-nav-label">${esc(i.label)}</span>${i.ro ? '<span class="a-chip">읽기</span>' : ''}${i.count ? `<span class="a-count" data-badge="${i.count}" hidden></span>` : ''}</a></li>`).join('')}</ul>`).join('');
  if (S.section.afterNav) S.section.afterNav();
  markCurrent();
}

function markCurrent() {
  $$('[data-nav]').forEach((a) => {
    if (a.dataset.nav === S.navKey) a.setAttribute('aria-current', 'page'); else a.removeAttribute('aria-current');
  });
}

export function renderContext() {
  const el = $('#ctx');
  if (!el || !S.section) return;
  el.innerHTML = S.section.contextHtml ? S.section.contextHtml() : '';
}

hooks.renderNav = renderNav;
hooks.renderContext = renderContext;

/* ── 라우터 ──────────────────────────────────────────────────────────────── */

const parseHash = () => decodeURIComponent(location.hash.replace(/^#\/?/, '').split('?')[0]).split('/').filter(Boolean); // ?query 는 라우트 매칭에서 제외 (복제 등 뷰가 직접 읽는다)

function route() {
  if (!S.shell || !S.section) return;
  if (S.modal) { if (S.modal.busy) return; S.modal.close(); }
  S.dirty = null; // 새 화면이 필요하면 스스로 등록한다
  const gen = ++S.viewGen;
  const alive = () => gen === S.viewGen && !!S.shell;
  // 역할 밖 해시 / 알 수 없는 해시 → 자기 역할 기본 화면으로 교체(replace, 히스토리 오염 방지).
  // ⚠️ 이것은 혼동 방지일 뿐이다. 어떤 해시를 열어도 데이터는 Rules 가 판정한다 (R-SEC1).
  const m = S.section.match(parseHash(), alive);
  if (!m) { hooks.go(S.section.meta.defaultHash); return; }
  const view = $('#view');
  if (!view) return;
  S.navKey = m.key;
  markCurrent();
  window.scrollTo(0, 0);
  m.run();
  setTimeout(() => { const h = $('#view h1'); if (h && alive()) h.focus({ preventScroll: true }); }, 0);
}

hooks.route = route;
hooks.go = (hash) => {
  history.replaceState(null, '', hash);
  S.curHash = location.hash;
  route();
};

/** N15 — 저장 안 한 변경이 있는 폼에서 이동하려 하면 되돌리고 확인한다. */
function onHashChange() {
  if (S.suppressHash) { S.suppressHash = false; return; }
  if (S.dirty && S.dirty() && !(S.modal && S.modal.busy)) {
    const target = location.hash;
    S.suppressHash = true;
    location.hash = S.curHash;
    confirmLeave(() => { clearDirty(); S.curHash = target; location.hash = target; });
    return;
  }
  S.curHash = location.hash;
  route();
}

/* ============================================================================
   역할 변경 복구 (C4 / G5) — 폴링 없음. permission-denied 가 계기다.
   - 단일 비행: 동시에 실패한 카드 N개가 읽기를 N번 하지 않는다.
   - 완료 후 3초 안의 재호출은 직전 결과를 재사용한다.
   - 비교 대상은 role 과 brandId (브랜드 연결만 바뀌어도 컨텍스트가 낡았다).
   ========================================================================== */
let rcInflight = null;
let rcLast = { at: 0, res: null };
const RECHECK_REUSE_MS = 3000;

hooks.recheckRole = (force = false) => {
  if (!S.shell) return Promise.resolve({ changed: false });
  if (rcInflight) return rcInflight;
  if (!force && rcLast.res && Date.now() - rcLast.at < RECHECK_REUSE_MS) return Promise.resolve(rcLast.res);
  const sh = S.shell;
  rcInflight = (async () => {
    let res;
    try {
      const info = await readUserRole(sh.uid);
      if (S.shell !== sh) return { changed: false };
      if (info.kind === 'unknown') { res = { changed: true }; renderUnknownRole({ uid: sh.uid, email: sh.email }, info); }
      else if (sameRole(sh.info, info)) res = { changed: false };
      else { res = { changed: true }; await rebuildShell(info, sh.role === info.role && !sh.brandId && !!info.brandId); }
    } catch (e) {
      console.error('[console] 역할 재확인 실패', e?.code || e);
      res = { changed: false, failed: true };
    }
    return res;
  })().then((r) => { rcLast = { at: Date.now(), res: r }; rcInflight = null; return r; });
  return rcInflight;
};

async function rebuildShell(info, quiet = false) {
  const prev = S.shell;
  const discarded = !!(S.dirty && S.dirty());
  const mod = await SECTION_LOADERS[info.role]();
  if (S.shell !== prev) return;
  try { S.section?.stop?.(); } catch (_) { /* 정리 실패는 재구성을 막지 않는다 */ }
  if (S.modal) S.modal.destroy();
  window.removeEventListener('hashchange', onHashChange);
  S.roleNotice = quiet ? null : { from: prev.role, to: info.role, discarded }; // 브랜드 연결 직후 재구성은 권한 변경이 아니다
  S.order = {}; S.flash = null; S.panelFail = null;
  openShell({ uid: prev.uid, email: prev.email }, info, mod);
}

function showRoleNotice() {
  const box = $('#role-notice');
  const n = S.roleNotice;
  if (!box) return;
  if (!n) { box.innerHTML = ''; return; }
  const change = n.from !== n.to ? ` (${ROLE_LABEL[n.from]} → ${ROLE_LABEL[n.to]})` : '';
  box.innerHTML = `<div class="a-banner" role="status"><button type="button" class="a-link a-b-x" id="rn-x" aria-label="닫기">닫기</button>
    <p>권한이 바뀌었어요. 화면을 다시 구성했어요.${esc(change)}</p>${n.discarded ? '<p class="a-cap">열려 있던 입력은 저장되지 않았어요.</p>' : ''}</div>`;
  $('#rn-x').onclick = () => { S.roleNotice = null; box.innerHTML = ''; };
}

/* ============================================================================
   시작
   ========================================================================== */

export function boot() {
  if (!isFirebaseConfigured) { renderConfigMissing(); return; }
  try {
    initFirebase();
  } catch (e) {
    console.error('[console] Firebase 초기화 실패', e);
    renderConfigMissing();
    return;
  }
  renderChecking(); // Auth 복원이 끝날 때까지 로그인 폼을 먼저 깜빡이지 않는다
  onAuthChanged(handleAuth);
}

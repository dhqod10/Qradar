/* ============================================================================
   admin 섹션 — 승인 큐 · 대시보드 · 매장 목록 · Qoin 현황. (web_admin_console 에서 이관 — 기능 변경 없음)
   화면 A1~A9 와 승인/반려 모달은 이전 console.js 의 코드를 그대로 옮겼다. 달라진 것은 셸/위젯을 console-ui.js 에서 가져오는 것과
   네비 구성(NAV)·라우트 매칭(match)이 섹션 인터페이스로 바뀐 것뿐이다.

   [보안] 이 섹션은 admin 으로 판정된 사용자에게만 import 된다. 그러나 그것은 보안 장치가 아니라 편의다 —
   다른 역할이 이 모듈을 직접 import 해 호출해도 모든 요청은 Rules / Cloud Functions 가 다시 판정한다.

   [섹션 인터페이스]  meta · navGroups() · contextHtml() · start() · stop() · afterNav() · match(parts, alive) → {key, run}
   ========================================================================== */

import {
  signOutNow, countPending, listPendingBrands, getBrand, getBrandPrivate, loadBrandMap, listPendingStores, getStore, listAllStores, listPendingMenus, listPendingOverrides, getMasterMenu, getQoinConfig, listQoinHistory, listQoinHistoryOf, setQoinAccrualRate, setQoinAccrualEnabled, applyBrandQoinRate, approveBrand, rejectBrand, approveStore, rejectStore, readCurrentStatus, runBackfillGeohash, runBackfillQoinAccrual, runBackfillSearchKeywords, findUsersByEmail, findUserByUid, setUserSuspension, adminDeleteUser, LIST_LIMIT,
} from './console-data.js';
import {
  esc, safeUrl, fmtDateTime, fmtShortDateTime, fmtClock, shortUid, fmtKrw, fmtRatePct, normalizeStatus, STATUS_LABEL, validateReason, classifyError, writeErrorText, RATE_MIN, RATE_MAX, parseRateCell, parseSwitchCell, resolveEffectiveQoinRate, qoinRateText, toDate,
} from './console-format.js';
import {
  S, root, hooks, $, skel, letter, banner, openDialog, emptyBlock, errorBlock, statusBadge, uidCell, thumb, kv, tableHtml, skelRows, headHtml, detailSkeleton, flashOnce, makeLoader, toast, field, setFieldError, targetBlock,
} from './console-ui.js';

export const meta = { role: 'admin', defaultHash: '#/dashboard' };

const NAV = [
  { group: '운영', items: [
    { key: 'dashboard', href: '#/dashboard', label: '대시보드' },
    { key: 'users', href: '#/users', label: '회원 관리' },
    { key: 'tools', href: '#/tools', label: '백필 도구' },
  ] },
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

export const navGroups = () => NAV;
export const contextHtml = () => '';
export const afterNav = () => renderBadges();

/** S.counts / loadAllCounts 는 admin 일 때만 시작한다 (다른 역할은 이 섹션을 import 하지 않는다). */
export function start() {
  S.counts = { brands: { state: 'loading' }, stores: { state: 'loading' }, menus: { state: 'loading' }, overrides: { state: 'loading' } };
  hooks.loadAllCounts = loadAllCounts;
  loadAllCounts();
}
export function stop() { S.counts = {}; hooks.loadAllCounts = () => Promise.resolve(); }

/** 레거시 호환상 admin 해시는 네임스페이스가 없다 (#/dashboard #/brands …). */
export function match(parts, alive) {
  const p0 = parts[0];
  if (p0 === 'brands') return { key: 'brands', run: () => (parts[1] ? viewBrandDetail(parts[1], alive) : viewBrandQueue(alive)) };
  if (p0 === 'stores' && parts[1] === 'pending') return { key: 'storesPending', run: () => (parts[2] ? viewStoreDetail(parts[2], alive) : viewStoreQueue(alive)) };
  if (p0 === 'stores') return { key: 'stores', run: () => viewStoreList(alive) };
  if (p0 === 'menus') return { key: 'menus', run: () => viewMenus(alive) };
  if (p0 === 'overrides') return { key: 'overrides', run: () => viewOverrides(alive) };
  if (p0 === 'qoin') return { key: 'qoin', run: () => viewQoin(alive) };
  if (p0 === 'dashboard') return { key: 'dashboard', run: () => viewDashboard(alive) };
  if (p0 === 'tools') return { key: 'tools', run: () => viewTools(alive) };
  if (p0 === 'users') return { key: 'users', run: () => viewUsers(alive) };
  return null;
}

const route = () => hooks.route();

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
   백필 도구 — 운영용 사후 보정 (store_list_pagination / qoin_accrual_backfill)
   항상 미리보기(dryRun) 먼저. "실제 실행" 은 미리보기 성공 후에만 켜지고 확인을 한 번 더 받는다.
   ========================================================================== */

const TOOLS = {
  geo: {
    h2: '매장 위치코드 백필',
    desc: '거리순 매장 목록에 쓰는 위치코드(position)를 기존 매장에 채워요. 여러 번 실행해도 안전해요(멱등).',
    confirm: '매장 위치코드를 실제로 기록할까요? 멱등이라 다시 눌러도 중복되지 않아요.',
    dry: () => runBackfillGeohash(true),
    commit: () => runBackfillGeohash(false),
  },
  search: {
    h2: '매장 검색 키워드 백필',
    desc: '검색에 쓰는 키워드(매장명·브랜드명·카테고리)를 기존 매장에 채워요. 여러 번 실행해도 안전해요(멱등).',
    confirm: '매장 검색 키워드를 실제로 기록할까요? 멱등이라 다시 눌러도 중복되지 않아요.',
    dry: () => runBackfillSearchKeywords(true),
    commit: () => runBackfillSearchKeywords(false),
  },
};

const toolPanel = (id) => {
  const t = TOOLS[id];
  return `<div class="a-section">
    <h2 class="a-h2">${esc(t.h2)}</h2>
    <p class="a-muted" style="margin:-8px 0 16px">${esc(t.desc)}</p>
    <div style="display:flex;gap:8px;flex-wrap:wrap">
      <button type="button" class="a-btn" id="${id}-dry">미리보기</button>
      <button type="button" class="a-btn primary" id="${id}-commit" disabled>실제 실행</button>
    </div>
    <div id="${id}-msg" style="margin-top:12px"></div>
    <pre id="${id}-out" style="display:none;white-space:pre-wrap;word-break:break-word;max-height:360px;overflow:auto;margin-top:12px;padding:12px;border:1px solid var(--border);border-radius:8px;font-size:12px;line-height:1.55;font-family:ui-monospace,SFMono-Regular,Menlo,monospace"></pre>
  </div>`;
};

/* ── Qoin 적립 소급 — 폼 → 미리보기(dryRun) → 2차 확인 → 실제 실행 (qoin_accrual_backfill_admin_ui) ──
   쓰기는 전부 callable 이 한다 (UI 는 Firestore 에 직접 쓰지 않는다). 입력은 서버 스키마 1:1. */

const QOIN_SKIP_LABEL = {
  already_earned: '이미 적립됨', already_applied: '이미 반영됨', no_completedAt: '완료 시각 없음',
  rate_unrecoverable: '당시 요율 복원 불가', disabled_period: '적립 꺼져 있던 기간', invalid_total: '결제 금액 비정상',
  store_unresolvable: '매장 확인 불가', order_not_found: '주문 없음', not_completed: '완료되지 않은 주문',
  no_user: '고객 정보 없음', self_dealing: '자기적립 제외', zero_amount: '적립액 0', failed: '처리 실패',
};
const QOIN_OUTCOME_LABEL = { credited: '적립', would_credit: '적립 예정', already_applied: '이미 반영', skipped: '건너뜀', failed: '실패' };
const QOIN_SOURCES = [
  ['issues', '누락 이슈 전체'], ['orderIds', '주문 ID 지정'], ['storeRange', '매장 + 기간'], ['range', '기간 전체'],
];
const QOIN_MAX_RANGE_MS = 31 * 24 * 60 * 60 * 1000;

function qoinPanelHtml() {
  const inp = 'class="a-input"';
  return `<div class="a-section" id="qn-root">
    <h2 class="a-h2">Qoin 적립 소급</h2>
    <p class="a-muted" style="margin:-8px 0 16px">적립이 누락된 완료 주문에 당시 요율로 Qoin 을 사후 적립해요. 고객 잔액이 실제로 바뀌니 미리보기를 꼭 먼저 확인하세요. 이미 적립된 주문은 건너뛰어요(멱등).</p>
    <div class="a-field"><label class="a-label" for="qn-source">대상</label>
      <select id="qn-source" ${inp}>${QOIN_SOURCES.map(([v, l]) => `<option value="${v}">${esc(l)}</option>`).join('')}</select></div>
    <div id="qn-g-orderIds" hidden><div class="a-field"><label class="a-label" for="qn-orderIds">주문 ID 목록 (줄바꿈 또는 쉼표 구분, 최대 500개)</label>
      <textarea class="a-textarea" id="qn-orderIds" rows="4"></textarea></div></div>
    <div id="qn-g-storeId" hidden><div class="a-field"><label class="a-label" for="qn-storeId">매장 ID</label>
      <input ${inp} id="qn-storeId" type="text" autocomplete="off"></div></div>
    <div id="qn-g-range" hidden style="display:none;gap:12px;flex-wrap:wrap">
      <div class="a-field"><label class="a-label" for="qn-from">시작 일시</label><input ${inp} id="qn-from" type="datetime-local"></div>
      <div class="a-field"><label class="a-label" for="qn-to">종료 일시 (시작 후 31일 이내)</label><input ${inp} id="qn-to" type="datetime-local"></div>
    </div>
    <div class="a-field"><label class="a-label" for="qn-limit">건수 상한 (1~500)</label>
      <input ${inp} id="qn-limit" type="number" min="1" max="500" step="1" value="200"></div>
    <div class="a-field"><label style="display:flex;gap:8px;align-items:center"><input id="qn-cdp" type="checkbox"> 적립이 꺼져 있던 기간의 주문도 소급</label></div>
    <details id="qn-adv" style="margin:8px 0 12px"><summary class="a-muted" style="cursor:pointer">고급: 강제 요율</summary>
      <div class="a-field" style="margin-top:8px"><label class="a-label" for="qn-rate">강제 요율 % (0.1~20, 0.1% 단위)</label>
        <input ${inp} id="qn-rate" type="text" inputmode="decimal" autocomplete="off" placeholder="비워두면 당시 요율로 복원"></div>
      <div id="qn-rate-warn"></div></details>
    <div class="a-field"><label class="a-label" for="qn-reason">사유 (실제 실행 시 필수, 200자 이내)</label>
      <input ${inp} id="qn-reason" type="text" maxlength="200" autocomplete="off"></div>
    <div id="qn-err" class="a-field-err" hidden></div>
    <div style="display:flex;gap:8px;flex-wrap:wrap">
      <button type="button" class="a-btn" id="qn-dry">미리보기</button>
      <button type="button" class="a-btn primary" id="qn-commit" disabled>실제 실행</button>
    </div>
    <div id="qn-msg" style="margin-top:12px"></div>
    <div id="qn-sum" style="margin-top:12px"></div>
    <details id="qn-rawwrap" style="display:none;margin-top:12px"><summary class="a-muted" style="cursor:pointer">전체 응답 JSON</summary>
      <pre id="qn-out" style="white-space:pre-wrap;word-break:break-word;max-height:360px;overflow:auto;margin-top:8px;padding:12px;border:1px solid var(--border);border-radius:8px;font-size:12px;line-height:1.55;font-family:ui-monospace,SFMono-Regular,Menlo,monospace"></pre></details>
  </div>`;
}

function wireQoin(alive) {
  const el = (id) => $(`#qn-${id}`);
  const dryBtn = el('dry'); const commitBtn = el('commit');
  const msg = el('msg'); const sum = el('sum'); const errBox = el('err');
  let previewSig = null;   // 미리보기에 성공한 입력 서명 (reason 제외 — reason 은 실행 시점에 받는다)
  let previewEligible = 0;
  let busy = false;

  /** 폼 → { params, error }. params 는 서버 스키마 키만. reason 은 별도(선택). */
  const readForm = () => {
    const source = el('source').value;
    const p = { source };
    const lim = el('limit').value.trim();
    const limN = Number(lim);
    if (lim === '' || !Number.isInteger(limN) || limN < 1 || limN > 500) return { error: '건수 상한은 1~500 사이 정수여야 해요.' };
    p.limit = limN;
    if (source === 'orderIds') {
      const ids = [...new Set(el('orderIds').value.split(/[\n,]+/).map((x) => x.trim()).filter(Boolean))];
      if (ids.length === 0) return { error: '주문 ID 를 한 개 이상 입력하세요.' };
      if (ids.length > 500) return { error: '주문 ID 는 최대 500개까지예요.' };
      if (ids.some((x) => x.includes('/'))) return { error: '주문 ID 에 "/" 를 넣을 수 없어요.' };
      p.orderIds = ids;
    }
    if (source === 'storeRange') {
      const sid = el('storeId').value.trim();
      if (!sid || sid.includes('/')) return { error: '매장 ID 를 입력하세요 ("/" 불가).' };
      p.storeId = sid;
    }
    if (source === 'storeRange' || source === 'range') {
      const f = Date.parse(el('from').value); const t = Date.parse(el('to').value);
      if (!Number.isFinite(f) || !Number.isFinite(t)) return { error: '시작/종료 일시를 모두 입력하세요.' };
      if (t <= f) return { error: '종료 일시는 시작 일시 이후여야 해요.' };
      if (t - f > QOIN_MAX_RANGE_MS) return { error: '기간은 31일을 넘을 수 없어요.' };
      p.from = f; p.to = t;
    }
    if (el('cdp').checked) p.creditDisabledPeriod = true;
    const rateRaw = el('rate').value.trim().replace(/%$/, '').trim();
    if (rateRaw !== '') {
      const pct = Number(rateRaw);
      const tenths = pct * 10;
      if (!Number.isFinite(pct) || Math.abs(tenths - Math.round(tenths)) > 1e-6 || Math.round(tenths) < 1 || Math.round(tenths) > 200) {
        return { error: '강제 요율은 0.1%~20% 사이, 0.1% 단위여야 해요.' };
      }
      p.overrideRate = Math.round(tenths) / 1000;
    }
    return { params: p };
  };

  const reasonVal = () => el('reason').value.trim();
  const sigNow = () => { const r = readForm(); return r.params ? JSON.stringify(r.params) : null; };

  const refresh = () => {
    const showSrc = el('source').value;
    el('g-orderIds').hidden = showSrc !== 'orderIds';
    el('g-storeId').hidden = showSrc !== 'storeRange';
    el('g-range').style.display = (showSrc === 'storeRange' || showSrc === 'range') ? 'flex' : 'none';
    el('rate-warn').innerHTML = el('rate').value.trim() === '' ? ''
      : banner('warn', '주의', '강제 요율은 "당시 요율"이 아니라 입력한 값으로 적립되고, 원장에 강제 지정(admin_override)으로 영구 기록돼요.');
    const r = readForm();
    errBox.hidden = !r.error || previewSig === null && !dirtyShown; errBox.textContent = r.error || '';
    const same = previewSig !== null && r.params && JSON.stringify(r.params) === previewSig;
    if (previewSig !== null && !same && !busy) {
      msg.innerHTML = banner('warn', '', '입력이 바뀌었어요. 다시 미리보기 하세요.');
    }
    const reasonOk = reasonVal().length > 0;
    commitBtn.disabled = busy || !(same && previewEligible > 0 && reasonOk);
    commitBtn.title = same && previewEligible > 0 && !reasonOk ? '사유를 입력하면 실행할 수 있어요.' : '';
  };
  let dirtyShown = false;

  const setBusy = (btn, on, idle) => {
    busy = on;
    btn.innerHTML = on ? '<span class="a-spin"></span> 실행 중…' : idle;
    dryBtn.disabled = on;
    if (on) commitBtn.disabled = true;
  };

  const skipRows = (counts) => {
    const ent = Object.entries(counts || {});
    if (ent.length === 0) return '<span class="a-muted">없음</span>';
    return ent.map(([k, n]) => `${esc(QOIN_SKIP_LABEL[k] || k)} ${n}건`).join(' · ');
  };
  const sampleTable = (results) => {
    const rows = (results || []).slice(0, 50);
    if (rows.length === 0) return '';
    const body = rows.map((r) => `<tr><td>${esc(r.orderId)}</td><td>${esc(QOIN_OUTCOME_LABEL[r.outcome] || r.outcome || '-')}${r.skipReason ? ` (${esc(QOIN_SKIP_LABEL[r.skipReason] || r.skipReason)})` : ''}</td><td>${r.rate != null ? esc(fmtRatePct(r.rate)) : '-'}</td><td>${r.amount != null ? esc(`${r.amount} Q`) : '-'}</td><td>${esc(r.reconstruction?.method ?? '-')}</td></tr>`);
    return `<div class="a-muted" style="margin:12px 0 6px">샘플 ${rows.length}${(results || []).length > rows.length ? ` / ${(results || []).length}` : ''}건</div>${tableHtml(['주문 ID', '결과', '요율', '금액', '요율 복원'], body)}`;
  };
  const renderSummary = (d, isDry) => {
    const n = isDry ? (d.wouldCredit ?? d.eligible ?? 0) : (d.credited ?? d.eligible ?? 0);
    let html = '';
    if (isDry && n === 0) html += emptyBlock('소급할 대상이 없어요', '조건에 맞는 적립 대상이 없습니다.');
    html += kv([
      [isDry ? '소급 대상' : '적립 완료', `${n}건`],
      [isDry ? '소급 예정 Qoin 합계' : '적립된 Qoin 합계', `${d.totalQoin ?? 0} Q`],
      ['스캔', `${d.scanned ?? 0}건`],
      ['건너뜀 사유', skipRows(d.skippedCounts), true],
    ]);
    if (d.truncated) html += banner('warn', '일부만 조회됨', '대상이 한 번에 다 담기지 않았어요 — 범위를 좁히거나 실행 후 다시 미리보기 하세요.');
    html += sampleTable(d.results);
    sum.innerHTML = html;
    el('out').textContent = JSON.stringify(d, null, 2);
    el('rawwrap').style.display = 'block';
  };

  const showErr = (e, target) => {
    const t = writeErrorText(e).text;
    const isTimeout = /timeout|deadline|시간/i.test(`${e?.code || ''} ${e?.message || ''} ${t}`);
    const hint = isTimeout ? ' 반영 여부를 확인하지 못했어요 — 같은 입력으로 다시 미리보기 하면 이미 적립된 건은 건너뛰어요(멱등).' : '';
    return banner('error', '실패', `${t}${hint}`);
  };

  const doPreview = async () => {
    const r = readForm();
    dirtyShown = true;
    if (r.error) { refresh(); return; }
    const params = { ...r.params, dryRun: true };
    if (reasonVal()) params.reason = reasonVal();
    msg.innerHTML = ''; sum.innerHTML = ''; previewSig = null; previewEligible = 0;
    setBusy(dryBtn, true, '미리보기');
    try {
      const d = await runBackfillQoinAccrual(params);
      if (!alive()) return;
      previewSig = JSON.stringify(r.params);
      previewEligible = d?.wouldCredit ?? d?.eligible ?? 0;
      renderSummary(d || {}, true);
      msg.innerHTML = banner('', '미리보기', previewEligible > 0
        ? '아래가 실행 시 반영될 내용이에요. 사유를 입력하고 "실제 실행"을 눌러주세요.' : '실행할 대상이 없어요.');
    } catch (e) {
      if (!alive()) return;
      msg.innerHTML = showErr(e);
    } finally {
      if (alive()) { setBusy(dryBtn, false, '미리보기'); refresh(); }
    }
  };

  const doCommit = () => {
    const r = readForm();
    const reason = reasonVal();
    if (!r.params || JSON.stringify(r.params) !== previewSig || !reason || previewEligible <= 0) { refresh(); return; }
    const p = r.params;
    const srcLabel = QOIN_SOURCES.find(([v]) => v === p.source)?.[1] || p.source;
    const fmtT = (ms) => fmtDateTime(new Date(ms));
    const rows = [
      ['대상', srcLabel],
      ...(p.orderIds ? [['주문', `${p.orderIds.length}건`]] : []),
      ...(p.storeId ? [['매장 ID', p.storeId]] : []),
      ...(p.from ? [['기간', `${fmtT(p.from)} ~ ${fmtT(p.to)}`]] : []),
      ['건수 상한', `${p.limit}건`],
      ['꺼진 기간 포함', p.creditDisabledPeriod ? '예' : '아니오'],
      ['강제 요율', p.overrideRate != null ? `${(p.overrideRate * 100).toFixed(1)}%` : '없음 (당시 요율 복원)'],
      ['미리보기 대상', `${previewEligible}건`],
      ['사유', reason],
    ];
    const params = { ...p, dryRun: false, reason };
    openDialog({
      title: 'Qoin 을 실제로 적립할까요?',
      bodyHtml: `${banner('warn', '되돌릴 수 없어요', '고객 잔액이 실제로 바뀌어요. 아래 범위가 맞는지 확인하세요.')}${kv(rows)}`,
      confirmLabel: '실제 적립', confirmClass: 'primary', busyLabel: '적립 중…',
      onConfirm: async () => {
        const d = await runBackfillQoinAccrual(params);
        if (alive()) {
          previewSig = null; previewEligible = 0;
          renderSummary(d || {}, false);
          let m = banner('success', '완료', `${d?.credited ?? 0}건 적립했어요.`);
          if (d?.historyId) m += banner('', '이력', `실행 이력이 기록됐어요 (ID: ${d.historyId}).`);
          if (d?.historyWarning) m += banner('warn', '이력 기록 실패', '적립은 완료됐지만 실행 이력 기록에 실패했어요 — 운영 기록을 수동으로 확인하세요.');
          msg.innerHTML = m;
          toast('소급 적립을 실행했어요.');
          refresh();
        }
      },
      onError: (e, api) => { api.showMsg(showErr(e)); },
    });
  };

  const root = el('root');
  root.addEventListener('input', () => { dirtyShown = true; refresh(); });
  root.addEventListener('change', () => { dirtyShown = true; refresh(); });
  dryBtn.onclick = doPreview;
  commitBtn.onclick = doCommit;
  refresh();
}

function viewTools(alive) {
  const v = $('#view');
  v.innerHTML = `${headHtml({ title: '백필 도구', desc: '누락된 데이터를 사후 보정하는 운영 도구예요. 항상 미리보기로 대상을 확인한 뒤 실행하세요.', refresh: false })}
    ${toolPanel('geo')}
    ${qoinPanelHtml()}
    ${toolPanel('search')}`;
  wireTool('geo', alive);
  wireQoin(alive);
  wireTool('search', alive);
}

function wireTool(id, alive) {
  const t = TOOLS[id];
  const dryBtn = $(`#${id}-dry`);
  const commitBtn = $(`#${id}-commit`);
  const msg = $(`#${id}-msg`);
  const out = $(`#${id}-out`);
  let previewed = false;

  const show = (data) => {
    out.style.display = 'block';
    out.textContent = typeof data === 'string' ? data : JSON.stringify(data, null, 2);
  };
  const setBusy = (btn, busy, labelIdle) => {
    btn.disabled = busy;
    btn.innerHTML = busy ? '<span class="a-spin"></span> 실행 중…' : labelIdle;
  };

  const run = async (isDry) => {
    const btn = isDry ? dryBtn : commitBtn;
    msg.innerHTML = '';
    setBusy(btn, true);
    (isDry ? commitBtn : dryBtn).disabled = true;
    try {
      const data = await (isDry ? t.dry() : t.commit());
      if (!alive()) return;
      show(data);
      if (isDry) {
        previewed = true;
        msg.innerHTML = banner('', '미리보기', '아래가 실행 시 반영될 내용이에요. 확인했으면 "실제 실행"을 눌러주세요.');
      } else {
        previewed = false;
        msg.innerHTML = banner('success', '완료', '실제 실행이 끝났어요. 결과는 아래와 같아요.');
        toast('백필을 실행했어요.');
      }
    } catch (e) {
      if (!alive()) return;
      msg.innerHTML = banner('error', '실패', writeErrorText(e).text);
    } finally {
      if (alive()) {
        setBusy(dryBtn, false, '미리보기');
        setBusy(commitBtn, false, '실제 실행');
        commitBtn.disabled = !previewed;
      }
    }
  };

  dryBtn.onclick = () => run(true);
  commitBtn.onclick = () => { if (window.confirm(t.confirm)) run(false); };
}

/* ============================================================================
   회원 관리 — 조회 + 정지/해제(전 역할) + 강제 탈퇴(customer, admin_user_moderation)
   조회는 admin Firestore 직접 쿼리. 정지/해제·강제탈퇴는 서버가 권한·집행·멱등 재판정.
   ========================================================================== */

function viewUsers(alive) {
  const v = $('#view');
  v.innerHTML = `${headHtml({ title: '회원 관리', desc: '이메일 또는 UID 로 회원을 조회해 정지/해제(전 역할)하거나 강제 탈퇴(고객)해요.', refresh: false })}
    <div class="a-section">
      <div style="display:flex;gap:8px;flex-wrap:wrap;align-items:center">
        <input id="u-q" type="text" placeholder="이메일 또는 UID" autocomplete="off"
          style="flex:1;min-width:220px;min-height:44px;padding:0 14px;border:1px solid var(--border);border-radius:10px;font-size:15px;background:var(--surface);color:var(--text-body)">
        <button type="button" class="a-btn primary" id="u-search">조회</button>
      </div>
      <div id="u-msg" style="margin-top:12px"></div>
      <div id="u-result" style="margin-top:4px"></div>
    </div>`;

  const input = $('#u-q');
  const msg = $('#u-msg');
  const result = $('#u-result');

  const search = async () => {
    const raw = (input.value || '').trim();
    msg.innerHTML = '';
    result.innerHTML = '';
    if (!raw) { msg.innerHTML = banner('', '', '이메일 또는 UID 를 입력해주세요.'); return; }
    const btn = $('#u-search');
    btn.disabled = true; btn.innerHTML = '<span class="a-spin"></span> 조회 중…';
    try {
      const rows = raw.includes('@') ? await findUsersByEmail(raw) : [await findUserByUid(raw)].filter(Boolean);
      if (!alive()) return;
      if (rows.length === 0) {
        result.innerHTML = emptyBlock('일치하는 회원이 없어요', '이메일 완전일치/UID 로만 조회돼요. (탈퇴·익명화된 계정은 이메일로 안 잡혀요)');
      } else {
        result.innerHTML = rows.map((u) => userCardHtml(u)).join('');
        rows.forEach((u) => wireUserCard(u, alive));
      }
    } catch (e) {
      if (!alive()) return;
      msg.innerHTML = banner('error', '조회 실패', writeErrorText(e).text);
    } finally {
      if (alive()) { btn.disabled = false; btn.textContent = '조회'; }
    }
  };

  $('#u-search').onclick = search;
  input.onkeydown = (e) => { if (e.key === 'Enter') search(); };
}

const roleLabelKo = (r) => ({ customer: '고객', owner: '점주', brand: '브랜드', admin: '관리자' }[r] || (r || '알 수 없음'));

function userCardHtml(u) {
  const id = `u-${u.uid}`;
  const suspended = u.suspended === true;
  const deleted = u.deleted === true;
  const isCustomer = u.role === 'customer';
  const isAdmin = u.role === 'admin';
  const statusPill = deleted
    ? '<span class="a-badge">탈퇴함</span>'
    : (suspended ? '<span class="a-badge rejected">정지됨</span>' : '<span class="a-badge approved">정상</span>');
  const qoin = typeof u.qoinBalance === 'number' ? `${u.qoinBalance.toLocaleString('ko-KR')} Q` : '-';

  // 정지/해제: admin·탈퇴 계정 제외
  const modBlock = (isAdmin || deleted) ? `<p class="a-muted" style="margin:8px 0 0">${isAdmin ? '관리자 계정은 정지할 수 없어요.' : '이미 탈퇴한 계정이에요.'}</p>` : `
    <div style="margin-top:12px">
      <input id="${id}-reason" type="text" placeholder="사유 (선택, 내부 기록용)" autocomplete="off"
        style="width:100%;min-height:40px;padding:0 12px;border:1px solid var(--border);border-radius:8px;font-size:14px;background:var(--surface);color:var(--text-body);margin-bottom:8px">
      <button type="button" class="a-btn ${suspended ? '' : 'primary'}" id="${id}-mod">${suspended ? '정지 해제' : '계정 정지'}</button>
    </div>`;

  // 강제 탈퇴: customer 만
  const delBlock = deleted ? '' : (isCustomer ? `
    <div style="margin-top:16px;padding-top:12px;border-top:1px solid var(--border)">
      <div class="a-muted" style="margin-bottom:8px">강제 탈퇴 — 되돌릴 수 없어요. 미리보기로 확인 후 실행하세요.</div>
      <div style="display:flex;gap:8px;flex-wrap:wrap">
        <button type="button" class="a-btn" id="${id}-del-dry">탈퇴 미리보기</button>
        <button type="button" class="a-btn" style="border-color:var(--error);color:var(--error)" id="${id}-del-go" disabled>강제 탈퇴 실행</button>
      </div>
      <div id="${id}-del-msg" style="margin-top:10px"></div>
    </div>` : `<p class="a-muted" style="margin-top:16px;padding-top:12px;border-top:1px solid var(--border)">강제 탈퇴는 고객 계정만 가능해요. (점주·브랜드는 소유 매장 정리가 필요해 Phase 2)</p>`);

  return `<div class="a-card" style="padding:18px;margin-bottom:14px">
    <div class="a-head" style="margin-bottom:8px"><h2 class="a-h2" style="margin:0">${esc(u.displayName || '(이름 없음)')}</h2>${statusPill}</div>
    ${kv([
      ['이메일', u.email || '-'],
      ['역할', roleLabelKo(u.role)],
      ['UID', `<span style="font-family:ui-monospace,Menlo,monospace;font-size:12px">${esc(u.uid)}</span>`, true],
      ['보유 Qoin', qoin],
    ])}
    <div id="${id}-msg" style="margin-top:10px"></div>
    ${modBlock}
    ${delBlock}
  </div>`;
}

function wireUserCard(u, alive) {
  const id = `u-${u.uid}`;
  const cardMsg = $(`#${id}-msg`);
  const reasonOf = () => { const el = $(`#${id}-reason`); return el ? (el.value || '').trim() : ''; };

  // 정지 / 해제
  const modBtn = $(`#${id}-mod`);
  if (modBtn) {
    const suspended = u.suspended === true;
    modBtn.onclick = async () => {
      const action = suspended ? 'unsuspend' : 'suspend';
      const ok = window.confirm(suspended
        ? `${u.email || u.uid} 의 정지를 해제할까요?`
        : `${u.email || u.uid} 를 정지할까요? 로그인·결제가 즉시 차단되고, 점주면 매장 판매도 중단돼요.`);
      if (!ok) return;
      modBtn.disabled = true; modBtn.innerHTML = '<span class="a-spin"></span> 처리 중…';
      try {
        await setUserSuspension(u.uid, action, reasonOf());
        if (!alive()) return;
        cardMsg.innerHTML = banner('success', '완료', suspended ? '정지를 해제했어요.' : '계정을 정지했어요.');
        toast(suspended ? '정지 해제됨' : '정지됨');
        modBtn.disabled = true; modBtn.textContent = suspended ? '해제됨' : '정지됨';
      } catch (e) {
        if (!alive()) return;
        cardMsg.innerHTML = banner('error', '실패', writeErrorText(e).text);
        modBtn.disabled = false; modBtn.textContent = suspended ? '정지 해제' : '계정 정지';
      }
    };
  }

  // 강제 탈퇴 (customer)
  const dry = $(`#${id}-del-dry`);
  const go = $(`#${id}-del-go`);
  const delMsg = $(`#${id}-del-msg`);
  if (dry && go) {
    let canDelete = false;
    dry.onclick = async () => {
      delMsg.innerHTML = '';
      dry.disabled = true; dry.innerHTML = '<span class="a-spin"></span> 확인 중…';
      try {
        const d = await adminDeleteUser(u.uid, reasonOf(), true);
        if (!alive()) return;
        const inflight = d?.inFlightOrders ?? 0;
        const qForfeit = d?.qoinToForfeit ?? 0;
        canDelete = d?.canDelete === true;
        delMsg.innerHTML = banner(canDelete ? '' : 'warn', '미리보기',
          `진행 중 주문 ${inflight}건 · 소멸 예정 Qoin ${(qForfeit || 0).toLocaleString('ko-KR')}Q · ${canDelete ? '탈퇴 가능' : '탈퇴 불가(진행 중 주문 완료 후)'}`);
        go.disabled = !canDelete;
      } catch (e) {
        if (!alive()) return;
        delMsg.innerHTML = banner('error', '실패', writeErrorText(e).text);
      } finally {
        if (alive()) { dry.disabled = false; dry.textContent = '탈퇴 미리보기'; }
      }
    };
    go.onclick = async () => {
      if (!canDelete) return;
      if (!window.confirm(`${u.email || u.uid} 를 정말 강제 탈퇴할까요? 되돌릴 수 없어요.`)) return;
      go.disabled = true; go.innerHTML = '<span class="a-spin"></span> 실행 중…'; dry.disabled = true;
      try {
        await adminDeleteUser(u.uid, reasonOf(), false);
        if (!alive()) return;
        delMsg.innerHTML = banner('success', '완료', '강제 탈퇴를 실행했어요. (익명화 + 계정 삭제)');
        toast('강제 탈퇴됨');
        go.textContent = '탈퇴 완료';
      } catch (e) {
        if (!alive()) return;
        delMsg.innerHTML = banner('error', '실패', writeErrorText(e).text);
        go.disabled = false; go.textContent = '강제 탈퇴 실행'; dry.disabled = false;
      }
    };
  }
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
        ${st === 'approved' ? '<div id="qoin-policy"></div>' : ''}
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
    if (st === 'approved') mountQoinPolicy($('#qoin-policy'), { scope: 'brand', id, alive });
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
        ${st === 'approved' ? '<div id="qoin-policy"></div>' : ''}
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
    if (st === 'approved') mountQoinPolicy($('#qoin-policy'), { scope: 'store', id, alive });
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
        <td>${st === 'pending' ? `<a href="#/stores/pending/${encodeURIComponent(s.id)}">승인 상세 →</a>` : st === 'approved' ? `<a href="#/stores/pending/${encodeURIComponent(s.id)}">Qoin 설정 →</a>` : ''}</td></tr>`;
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
   Qoin 적립 정책 편집 (qoin_policy_admin_ui) — 전역 / 브랜드 / 매장
   - 모든 쓰기는 callable(setQoinAccrualRate · setQoinAccrualEnabled · applyBrandQoinRate) 경유. Firestore 직접 쓰기 없음.
     값과 qoinRateHistory 는 서버가 같은 트랜잭션에 쓴다.
   - 입력은 % (0.1% 격자) → 소수로 변환. 서버가 같은 경계로 재검증한다.
   - spend(사용) 정책·비상 정지(config/qoin.enabled) 조작은 이 화면에 없다 (게이트 OFF / D0-2 A).
   ========================================================================== */

const QP_BULK_STALE_MS = 5 * 60 * 1000;
const QP_REASON_MAX = 200;
const hasOwn = (o, k) => !!o && Object.prototype.hasOwnProperty.call(o, k);

/** 사용자가 입력한 % 문자열 → 소수 요율. @returns {{ok:true, rate:number}|{ok:false, msg:string}} */
function parsePctInput(raw) {
  const s = String(raw ?? '').trim().replace(/%$/, '').trim();
  if (s === '' || !/^\d+(\.\d+)?$/.test(s)) return { ok: false, msg: '숫자로 입력해주세요 (예: 3 또는 2.5)' };
  const pct = Number(s);
  const tenths = pct * 10;
  if (Math.abs(tenths - Math.round(tenths)) > 1e-9) return { ok: false, msg: '0.1% 단위로 입력해주세요' };
  const rate = Math.round(tenths) / 1000;
  if (rate < RATE_MIN || rate > RATE_MAX) return { ok: false, msg: `${fmtRatePct(RATE_MIN)} ~ ${fmtRatePct(RATE_MAX)} 사이여야 해요 (0% 는 적립 스위치로 꺼주세요)` };
  return { ok: true, rate };
}

/** 서버 오류 문구 — 영어 서버 메시지를 그대로 노출하지 않는다. */
function qpErrText(e) {
  const t = writeErrorText(e);
  const k = classifyError(e);
  if ((k.kind === 'precondition' || k.kind === 'invalid') && !/[가-힣]/.test(k.message || '')) {
    return '요청을 처리할 수 없어요. 새로고침 후 상태를 확인하고 다시 시도해주세요.';
  }
  return t.text;
}

const qpReasonField = () => field({ id: 'qp-reason', label: '변경 사유', required: true, multiline: true, rows: 3, max: QP_REASON_MAX, help: '이력에 남아요 (최대 200자).' });
const qpRateText = (cell, fallback = '상위 설정 따름') => (cell.kind === 'valid' ? fmtRatePct(cell.value) : cell.kind === 'invalid' ? '확인 필요 (값 이상)' : fallback);

/**
 * 적립률 변경 모달 (1단계 입력 → 2단계 확인). o: { scope, targetId, title, targetName, current:{kind,value}, absentText, allowClear, trigger, onDone }
 */
function openQoinRateDialog(o) {
  const ask = { clear: false, pct: '', reason: '' };
  let step = 1; let parsed = null;
  const curText = qpRateText(o.current, o.absentText);
  const form = () => `${targetBlock(o.targetName, esc(o.title))}
    <p class="a-ask-sub" style="margin:0 0 12px">현재: <b>${esc(curText)}</b></p>
    ${field({ id: 'qp-pct', label: '새 적립률 (%)', required: true, ph: '예: 3.0', attrs: 'inputmode="decimal" autocomplete="off"', help: `${fmtRatePct(RATE_MIN)} ~ ${fmtRatePct(RATE_MAX)}, 0.1% 단위` })}
    ${o.allowClear ? `<label class="a-sw-row" style="display:flex;gap:8px;align-items:center;margin:0 0 12px"><input type="checkbox" id="qp-clear"> <span>개별 값 삭제 — 상위 설정을 따라요</span></label>` : ''}
    ${qpReasonField()}`;
  const restore = (api) => {
    api.setBody(form());
    const pct = api.q('#qp-pct'); const cl = api.q('#qp-clear'); const rs = api.q('#qp-reason');
    pct.value = ask.pct; rs.value = ask.reason;
    const sync = () => { if (cl) { pct.disabled = cl.checked; } };
    if (cl) { cl.checked = ask.clear; cl.onchange = sync; sync(); }
  };
  const toConfirm = (api) => {
    const cl = api.q('#qp-clear'); const clear = !!cl && cl.checked;
    const pctRaw = api.q('#qp-pct').value; const reasonRaw = api.q('#qp-reason').value;
    ask.clear = clear; ask.pct = pctRaw; ask.reason = reasonRaw;
    let bad = false;
    if (!clear) {
      const p = parsePctInput(pctRaw);
      if (!p.ok) { setFieldError('qp-pct', p.msg); bad = true; } else { setFieldError('qp-pct', ''); parsed = p.rate; }
    } else { setFieldError('qp-pct', ''); parsed = null; }
    const r = validateReason(reasonRaw);
    if (!r.ok) { setFieldError('qp-reason', '변경 사유를 입력해주세요'); bad = true; }
    else if ([...r.value].length > QP_REASON_MAX) { setFieldError('qp-reason', `${QP_REASON_MAX}자 이내로 입력해주세요`); bad = true; }
    else setFieldError('qp-reason', '');
    if (bad) return false;
    ask.reason = r.value;
    const after = clear ? o.inheritText || '상위 설정 따름' : fmtRatePct(parsed);
    api.setBody(`${targetBlock(o.targetName, esc(o.title))}
      <p class="a-ask">${esc(o.title)}을(를) <b>${esc(curText)}</b> → <b>${esc(after)}</b> (으)로 바꿀까요?</p>
      ${banner('warn', '확인', '이후 적립부터 새 요율이 적용돼요. 이미 적립된 Qoin 은 바뀌지 않아요.')}
      <p class="a-cap" style="margin-top:12px">사유: ${esc(r.value)}</p>`);
    api.showMsg('');
    api.setLabel('변경 확정');
    const back = api.addFootButton('qp-back', '이전', () => { step = 1; restore(api); api.setLabel('다음'); back.remove(); });
    step = 2;
    return false;
  };
  openDialog({
    title: o.title, confirmLabel: '다음', busyLabel: '변경 중…', trigger: o.trigger, focus: '#qp-pct',
    bodyHtml: form(),
    dirty: () => true,
    onOpen: (api) => restore(api),
    onConfirm: async (api) => {
      if (step === 1) return toConfirm(api);
      const res = await setQoinAccrualRate(o.scope, o.targetId, ask.clear ? { clear: true, reason: ask.reason } : { rate: parsed, reason: ask.reason });
      toast(res && res.changed === false ? '이미 같은 값이라 변경 없이 끝났어요.' : '적립률을 변경했어요.');
      if (o.onDone) o.onDone();
      return undefined;
    },
    onError: (e, api) => { api.showMsg(banner('error', '실패', qpErrText(e))); },
  });
}

/** 적립 스위치 변경 모달. o: { scope, targetId, targetName, enabledNow:boolean, trigger, onDone } */
function openQoinSwitchDialog(o) {
  const next = !o.enabledNow;
  const body = `${targetBlock(o.targetName, '적립 스위치')}
    <p class="a-ask">${next ? '적립을 다시 켤까요?' : '적립을 끌까요?'}</p>
    ${next
    ? banner('', '안내', '켜면 이후 주문부터 다시 Qoin 이 적립돼요.')
    : banner('warn', '주의', `이후 주문부터 적립이 멈춰요${o.scope === 'brand' ? ' (산하 모든 매장)' : ''}. 이미 적립된 Qoin 의 회수는 그대로 동작해요.`)}
    <div style="height:12px"></div>${qpReasonField()}`;
  openDialog({
    title: next ? '적립 켜기' : '적립 끄기', confirmLabel: next ? '켜기 확정' : '끄기 확정', confirmClass: next ? 'primary' : 'reject-confirm', busyLabel: '변경 중…',
    trigger: o.trigger, focus: '#qp-reason', bodyHtml: body, dirty: () => true,
    onConfirm: async (api) => {
      const r = validateReason(api.q('#qp-reason').value);
      if (!r.ok) { setFieldError('qp-reason', '변경 사유를 입력해주세요'); return false; }
      if ([...r.value].length > QP_REASON_MAX) { setFieldError('qp-reason', `${QP_REASON_MAX}자 이내로 입력해주세요`); return false; }
      const res = await setQoinAccrualEnabled(o.scope, o.targetId, next, r.value);
      toast(res && res.changed === false ? '이미 같은 상태라 변경 없이 끝났어요.' : next ? '적립을 켰어요.' : '적립을 껐어요.');
      if (o.onDone) o.onDone();
      return undefined;
    },
    onError: (e, api) => { api.showMsg(banner('error', '실패', qpErrText(e))); },
  });
}

/** 브랜드 일괄 적용 모달 (입력 → 영향 고지/확인). o: { brandId, brand, current, trigger, onDone } */
function openBrandBulkDialog(o) {
  const ask = { clear: false, pct: '', mode: 'preserve', reason: '' };
  let step = 1; let parsed = null;
  const curText = qpRateText(o.current, '전역 기본값 따름');
  const brandOff = o.brand.qoinAccrualEnabled === false;
  const form = () => `${targetBlock(o.brand.name, '브랜드 일괄 적용')}
    <p class="a-ask-sub" style="margin:0 0 12px">현재 브랜드 적립률: <b>${esc(curText)}</b></p>
    ${field({ id: 'qp-pct', label: '브랜드 적립률 (%)', required: true, ph: '예: 3.0', attrs: 'inputmode="decimal" autocomplete="off"', help: `${fmtRatePct(RATE_MIN)} ~ ${fmtRatePct(RATE_MAX)}, 0.1% 단위` })}
    <label class="a-sw-row" style="display:flex;gap:8px;align-items:center;margin:0 0 12px"><input type="checkbox" id="qp-clear"> <span>브랜드 값 삭제 — 전역 기본값을 따라요</span></label>
    <div class="a-field"><span class="a-label">산하 매장의 개별 적립률</span>
      <label style="display:flex;gap:8px;align-items:flex-start;margin:6px 0"><input type="radio" name="qp-mode" value="preserve"> <span><b>유지</b> — 개별 값이 있는 매장은 그 값을 계속 써요</span></label>
      <label style="display:flex;gap:8px;align-items:flex-start;margin:6px 0"><input type="radio" name="qp-mode" value="overwrite"> <span><b>덮어쓰기</b> — 개별 값을 삭제해 모든 매장이 브랜드 값을 따라요</span></label></div>
    ${qpReasonField()}`;
  const restore = (api) => {
    api.setBody(form());
    const pct = api.q('#qp-pct'); const cl = api.q('#qp-clear'); const rs = api.q('#qp-reason');
    pct.value = ask.pct; rs.value = ask.reason; cl.checked = ask.clear;
    api.el.querySelectorAll('input[name="qp-mode"]').forEach((r) => { r.checked = r.value === ask.mode; });
    const sync = () => { pct.disabled = cl.checked; };
    cl.onchange = sync; sync();
  };
  const toConfirm = (api) => {
    const clear = api.q('#qp-clear').checked;
    ask.clear = clear; ask.pct = api.q('#qp-pct').value; ask.reason = api.q('#qp-reason').value;
    ask.mode = api.el.querySelector('input[name="qp-mode"]:checked')?.value || 'preserve';
    let bad = false;
    if (!clear) {
      const p = parsePctInput(ask.pct);
      if (!p.ok) { setFieldError('qp-pct', p.msg); bad = true; } else { setFieldError('qp-pct', ''); parsed = p.rate; }
    } else { setFieldError('qp-pct', ''); parsed = null; }
    const r = validateReason(ask.reason);
    if (!r.ok) { setFieldError('qp-reason', '변경 사유를 입력해주세요'); bad = true; }
    else if ([...r.value].length > QP_REASON_MAX) { setFieldError('qp-reason', `${QP_REASON_MAX}자 이내로 입력해주세요`); bad = true; }
    else setFieldError('qp-reason', '');
    if (bad) return false;
    ask.reason = r.value;
    const after = clear ? '전역 기본값 따름' : fmtRatePct(parsed);
    api.setBody(`${targetBlock(o.brand.name, '브랜드 일괄 적용')}
      <p class="a-ask">브랜드 적립률을 <b>${esc(curText)}</b> → <b>${esc(after)}</b> (으)로 바꾸고, 산하 매장은 <b>${ask.mode === 'overwrite' ? '개별 값을 삭제' : '개별 값을 유지'}</b>할까요?</p>
      <div id="qp-impact">${banner('', '영향 범위', '산하 매장 수를 확인하는 중이에요…')}</div>
      ${ask.mode === 'overwrite' ? banner('warn', '되돌릴 수 없어요', '삭제된 매장별 개별 적립률은 복구되지 않아요 (이력에는 남아요).') : ''}
      ${brandOff ? banner('warn', '브랜드 적립 중단 중', '이 브랜드의 적립 스위치가 꺼져 있어 산하 전체 적립이 멈춰 있어요. 이 작업은 스위치를 바꾸지 않아요.') : ''}
      <p class="a-cap" style="margin-top:12px">사유: ${esc(r.value)}</p>`);
    api.showMsg('');
    api.setLabel('일괄 적용 확정');
    const back = api.addFootButton('qp-back', '이전', () => { step = 1; restore(api); api.setLabel('다음'); back.remove(); });
    step = 2;
    listAllStores().then(({ rows }) => {
      const mine = rows.filter((s) => s.brandId === o.brandId);
      const ind = mine.filter((s) => hasOwn(s, 'qoinAccrualRate')).length;
      const el = api.q('#qp-impact'); if (!el) return;
      el.innerHTML = banner('', '영향 범위', `산하 매장 ${mine.length}개 중 개별 적립률이 있는 매장 ${ind}개${ask.mode === 'overwrite' ? ' — 이 값이 삭제돼요' : ' — 그대로 유지돼요'}.`);
    }).catch(() => { const el = api.q('#qp-impact'); if (el) el.innerHTML = banner('warn', '영향 범위', '산하 매장 수를 확인하지 못했어요. 그래도 적용할 수 있어요.'); });
    return false;
  };
  openDialog({
    title: '브랜드 적립률 일괄 적용', confirmLabel: '다음', busyLabel: '적용 중… (매장이 많으면 오래 걸려요)', trigger: o.trigger, focus: '#qp-pct', wide: true,
    bodyHtml: form(), dirty: () => true,
    onOpen: (api) => restore(api),
    onConfirm: async (api) => {
      if (step === 1) return toConfirm(api);
      try {
        const res = await applyBrandQoinRate(o.brandId, { ...(ask.clear ? { clear: true } : { rate: parsed }), mode: ask.mode, reason: ask.reason });
        toast(res?.status === 'partial' ? '일괄 적용이 중간에 멈췄어요. 재개해주세요.'
          : res && res.changed === false ? '변경 사항이 없어요.' : `일괄 적용을 완료했어요${typeof res?.clearedCount === 'number' && ask.mode === 'overwrite' ? ` (매장 개별 값 ${res.clearedCount}개 삭제)` : ''}.`);
      } finally { if (o.onDone) o.onDone(); }
      return undefined;
    },
    onError: (e, api) => { api.showMsg(banner('error', '실패', `${qpErrText(e)} 브랜드 화면에서 일괄 적용 상태를 확인해주세요.`)); },
  });
}

/** 중단된 일괄 적용 재개 확인. */
function openBulkResumeDialog(o) {
  openDialog({
    title: '일괄 적용 재개', confirmLabel: '재개', busyLabel: '재개 중…', trigger: o.trigger,
    bodyHtml: `${targetBlock(o.name, '중단된 일괄 적용')}<p class="a-ask">남은 매장의 개별 적립률 삭제를 이어서 진행할까요?</p>
      ${banner('', '안내', '이미 처리된 매장은 건너뛰어요 (여러 번 눌러도 안전해요).')}`,
    onConfirm: async () => {
      try {
        const res = await applyBrandQoinRate(o.brandId, { mode: 'overwrite', resumeHistoryId: o.historyId, reason: '일괄 적용 재개' });
        toast(res?.status === 'partial' ? '아직 일부가 남았어요. 다시 재개해주세요.' : '일괄 적용을 마쳤어요.');
      } finally { if (o.onDone) o.onDone(); }
      return undefined;
    },
    onError: (e, api) => { api.showMsg(banner('error', '실패', qpErrText(e))); },
  });
}

const QP_HIST_FIELD = { accrualRate: '적립률', accrualEnabled: '적립 스위치', globalEnabled: '비상 정지' };
function qpHistVal(field, v) {
  if (field === 'accrualEnabled') return v === true ? '켜짐' : v === false ? '꺼짐' : '켜짐(기본)';
  if (field === 'accrualRate') return typeof v === 'number' ? fmtRatePct(v) : '상위 설정 따름';
  return histVal(field, v);
}
function qpHistTable(rows) {
  if (rows.length === 0) return emptyBlock('변경 이력이 없어요', '');
  return tableHtml(['변경 시각', '항목', '변경 전 → 후', '처리자', '사유'], rows.map((r) => {
    const reason = typeof r.reason === 'string' ? r.reason : '';
    const bulk = r.op === 'bulkApply' ? ` (일괄${r.bulkMode === 'overwrite' ? '·덮어쓰기' : r.bulkMode === 'preserve' ? '·유지' : ''}${typeof r.affected === 'number' ? ` ${r.affected}개` : ''})` : '';
    return `<tr><td class="a-num">${esc(fmtDateTime(r.changedAt))}</td><td>${esc((QP_HIST_FIELD[r.field] || '(알 수 없는 항목)') + bulk)}</td>
      <td class="a-num">${esc(qpHistVal(r.field, r.before))} → ${esc(qpHistVal(r.field, r.after))}</td><td>${uidCell(r.changedBy)}</td>
      <td class="a-ell" title="${esc(reason)}">${esc(reason.length > 200 ? `${reason.slice(0, 200)}…` : reason || '-')}</td></tr>`;
  }));
}

/** 일괄 적용 포인터 상태 → 'locked'(진행 중) | 'resume'(중단/방치) | null */
function bulkPointerState(b) {
  const st = b?.qoinBulkStatus;
  if (st === 'partial') return 'resume';
  if (st !== 'in_progress') return null;
  const at = toDate(b.qoinBulkAt);
  if (!at || Date.now() - at.getTime() > QP_BULK_STALE_MS) return 'resume';
  return 'locked';
}

/**
 * 브랜드 / 매장 상세에 붙이는 Qoin 적립 정책 카드. box 안을 스스로 읽고(fresh) 그린다. 쓰기 성공 후 스스로 다시 그린다.
 * scope: 'brand' | 'store'
 */
function mountQoinPolicy(box, { scope, id, alive }) {
  const isBrand = scope === 'brand';
  const parentPath = [isBrand ? 'brands' : 'stores', id];
  async function render() {
    box.innerHTML = `<div class="a-card" aria-busy="true"><h2>Qoin 적립 설정</h2>${skel('60%', 16)}<div style="height:10px"></div>${skel('40%', 16)}</div>`;
    let doc; let brand = null; let cfg = null; let hist = null; let histErr = null; let parentFail = false;
    try {
      doc = await (isBrand ? getBrand(id) : getStore(id));
      if (doc && !isBrand && doc.brandId) { try { brand = await getBrand(doc.brandId); } catch (e) { parentFail = true; console.error('[admin] 소속 브랜드 조회 실패', e?.code || e); } }
      try { cfg = await getQoinConfig(); } catch (e) { console.error('[admin] config/qoin 조회 실패', e?.code || e); }
      try { hist = await listQoinHistoryOf(parentPath, 20); } catch (e) { histErr = e; console.error('[admin] Qoin 이력 조회 실패', e?.code || e); }
    } catch (e) {
      console.error('[admin] Qoin 설정 조회 실패', e?.code || e);
      if (!alive()) return;
      box.innerHTML = `<div class="a-card"><h2>Qoin 적립 설정</h2>${errorBlock(e)}</div>`;
      $('[data-retry]', box).onclick = render; return;
    }
    if (!alive()) return;
    if (!doc) { box.innerHTML = ''; return; }

    const rateCell = parseRateCell(doc.qoinAccrualRate, hasOwn(doc, 'qoinAccrualRate'));
    const swState = parseSwitchCell(doc.qoinAccrualEnabled, hasOwn(doc, 'qoinAccrualEnabled'));
    const globalCell = cfg ? cfg.rate : { kind: 'absent', value: null };
    const bulkState = isBrand ? bulkPointerState(doc) : bulkPointerState(brand);
    const locked = bulkState === 'locked';
    const parentUnknown = !isBrand && !!doc.brandId && parentFail;
    const writeBlocked = locked || parentUnknown;

    let effRow;
    if (isBrand) {
      const eff = resolveEffectiveQoinRate({ store: { kind: 'absent' }, brand: rateCell, global: globalCell, brandSwitch: swState });
      const t = qoinRateText(eff);
      effRow = ['실제 적용', `${t.text} · ${t.sub}`];
    } else if (parentUnknown) {
      effRow = ['실제 적용', '소속 브랜드를 확인하지 못해 계산하지 않았어요'];
    } else {
      const brandCell = brand ? parseRateCell(brand.qoinAccrualRate, hasOwn(brand, 'qoinAccrualRate')) : { kind: 'absent', value: null };
      const brandSw = brand ? parseSwitchCell(brand.qoinAccrualEnabled, hasOwn(brand, 'qoinAccrualEnabled')) : 'enabled';
      const eff = resolveEffectiveQoinRate({ store: rateCell, brand: brandCell, global: globalCell, storeSwitch: swState, brandSwitch: brandSw, hasBrand: !!doc.brandId });
      const t = qoinRateText(eff);
      effRow = ['실제 적용', `${t.text} · ${t.sub}`];
    }
    const absentText = isBrand ? `전역 기본값 따름${globalCell.kind === 'valid' ? ` (${fmtRatePct(globalCell.value)})` : ''}`
      : `상위(브랜드/전역) 설정 따름`;
    const swText = swState === 'enabled' ? '적립 중' : swState === 'disabled' ? '적립 중단' : '확인 필요 (값 이상)';
    const swOn = swState !== 'disabled';

    let bulkBanner = '';
    if (isBrand && bulkState === 'locked') bulkBanner = banner('warn', '진행 중', '일괄 적용이 진행 중이에요. 끝날 때까지 이 브랜드의 설정은 바꿀 수 없어요.');
    else if (isBrand && bulkState === 'resume') bulkBanner = banner('warn', '일괄 적용이 중단됐어요', '일부 매장의 개별 적립률이 아직 남아 있을 수 있어요. 재개하거나, 값을 바꾸면 이 안내가 닫혀요.',
      `<div class="a-b-actions"><button type="button" class="a-btn sm" id="qp-resume">이어서 재개…</button></div>`);
    else if (!isBrand && bulkState === 'locked') bulkBanner = banner('warn', '진행 중', '소속 브랜드의 일괄 적용이 진행 중이에요. 끝날 때까지 이 매장의 설정은 바꿀 수 없어요.');
    else if (parentUnknown) bulkBanner = banner('warn', '확인 필요', '소속 브랜드 상태를 확인하지 못해 변경을 잠갔어요. 새로고침 후 다시 시도해주세요.');

    const dis = writeBlocked ? 'disabled' : '';
    box.innerHTML = `<div class="a-card"><h2>Qoin 적립 설정</h2>
      ${bulkBanner}
      ${kv([[isBrand ? '브랜드 적립률' : '매장 적립률', qpRateText(rateCell, absentText)], ['적립 스위치', swText], effRow])}
      <div class="a-btns" style="margin-top:14px;display:flex;gap:8px;flex-wrap:wrap">
        <button type="button" class="a-btn" id="qp-rate" ${dis}>적립률 변경…</button>
        <button type="button" class="a-btn" id="qp-sw" ${dis}>${swOn ? '적립 끄기…' : '적립 켜기…'}</button>
        ${isBrand ? `<button type="button" class="a-btn" id="qp-bulk" ${dis}>산하 매장 일괄 적용…</button>` : ''}</div>
      <p class="a-note">${isBrand ? '브랜드 값은 개별 값이 없는 모든 매장에 적용돼요.' : '개별 값을 삭제하면 브랜드(없으면 전역) 설정을 따라요.'} 변경은 이력에 남아요.</p>
      <h3 class="a-h2" style="margin-top:20px">변경 이력 (최근 20건)</h3>
      <div id="qp-hist">${histErr ? errorBlock(histErr) : qpHistTable(hist || [])}</div></div>`;
    const hr = $('[data-retry]', $('#qp-hist', box) || box); if (histErr && hr) hr.onclick = render;

    const done = () => { if (alive()) render(); };
    const targetName = doc.name || '(이름 없음)';
    $('#qp-rate', box).onclick = (e) => openQoinRateDialog({
      scope, targetId: id, title: isBrand ? '브랜드 적립률' : '매장 적립률', targetName, current: rateCell, absentText,
      allowClear: true, inheritText: isBrand ? '전역 기본값 따름' : '상위 설정 따름', trigger: e.currentTarget, onDone: done,
    });
    $('#qp-sw', box).onclick = (e) => openQoinSwitchDialog({ scope, targetId: id, targetName, enabledNow: swOn, trigger: e.currentTarget, onDone: done });
    if (isBrand) {
      $('#qp-bulk', box).onclick = (e) => openBrandBulkDialog({ brandId: id, brand: doc, current: rateCell, trigger: e.currentTarget, onDone: done });
      const rs = $('#qp-resume', box);
      if (rs) rs.onclick = (e) => openBulkResumeDialog({ brandId: id, name: targetName, historyId: doc.qoinBulkHistoryId, trigger: e.currentTarget, onDone: done });
    }
  }
  render();
}

/* ============================================================================
   A9 Qoin 현황 (전역 적립률 편집 가능 · 비상 정지는 조회 전용)
   ========================================================================== */

const HIST_FIELD = { accrualRate: '적립률', accrualEnabled: '적립 스위치', globalEnabled: '비상 정지' };
function histVal(field, v) {
  if (field === 'accrualRate') return typeof v === 'number' ? fmtRatePct(v) : '미설정';
  if (field === 'globalEnabled') return v === true ? '적립 중' : v === false ? '비상 정지' : '-';
  return '-';
}

function viewQoin(alive) {
  const v = $('#view');
  v.innerHTML = `${headHtml({ title: 'Qoin 현황' })}
    ${banner('', '', '전역 적립률은 여기서 바꿀 수 있어요. 브랜드·매장별 적립률과 적립 스위치는 각 상세 화면에서 바꿔요. 비상 정지는 조회만 가능해요.')}
    <div id="q-warn"></div><div id="q-cards"></div>
    <div class="a-btns" style="margin-top:16px"><button type="button" class="a-btn" id="q-edit" disabled>전역 적립률 변경…</button></div>
    <div class="a-section" style="margin-top:32px"><h2 class="a-h2">브랜드별 적립 설정</h2><div id="q-brands"></div></div>
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
  let lastCfg = null;
  const editBtn = $('#q-edit');
  const loadCards = () => {
    editBtn.disabled = true; lastCfg = null;
    return loadQoinInto($('#q-cards'), alive, { warnBox: $('#q-warn'), onOk: (cfg) => { lastCfg = cfg; stamp(); } })
      .then((r) => { if (alive() && (r === 'ok' || r === 'empty')) editBtn.disabled = false; });
  };
  async function loadBrands() {
    const box = $('#q-brands'); box.innerHTML = skelRows(3);
    try {
      const map = await loadBrandMap();
      if (!alive()) return;
      const rows = [...map.entries()].filter(([, b]) => b.status === 'approved').sort((a, b) => String(a[1].name).localeCompare(String(b[1].name), 'ko'));
      box.innerHTML = rows.length === 0 ? emptyBlock('승인된 브랜드가 없어요', '')
        : tableHtml(['브랜드', ''], rows.map(([bid, b]) => `<tr><td><strong>${esc(b.name || '(이름 없음)')}</strong></td><td><a href="#/brands/${encodeURIComponent(bid)}">Qoin 설정 →</a></td></tr>`));
    } catch (e) {
      console.error('[admin] 브랜드 목록 조회 실패', e?.code || e);
      if (!alive()) return;
      box.innerHTML = errorBlock(e);
      $('[data-retry]', box).onclick = loadBrands;
    }
  }
  editBtn.onclick = (e) => {
    const cell = lastCfg ? lastCfg.rate : { kind: 'absent', value: null };
    openQoinRateDialog({
      scope: 'global', targetId: null, title: '전역 적립률', targetName: '전역 기본 적립률', current: cell, absentText: '미설정',
      allowClear: false, trigger: e.currentTarget, onDone: () => { if (alive()) { loadCards(); loadHist(); } },
    });
  };
  $('#refresh').onclick = () => { loadCards(); loadHist(); loadBrands(); };
  loadCards(); loadHist(); loadBrands();
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

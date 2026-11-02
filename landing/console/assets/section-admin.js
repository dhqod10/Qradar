/* ============================================================================
   admin 섹션 — 승인 큐 · 대시보드 · 매장 목록 · Qoin 현황. (web_admin_console 에서 이관 — 기능 변경 없음)
   화면 A1~A9 와 승인/반려 모달은 이전 console.js 의 코드를 그대로 옮겼다. 달라진 것은 셸/위젯을 console-ui.js 에서 가져오는 것과
   네비 구성(NAV)·라우트 매칭(match)이 섹션 인터페이스로 바뀐 것뿐이다.

   [보안] 이 섹션은 admin 으로 판정된 사용자에게만 import 된다. 그러나 그것은 보안 장치가 아니라 편의다 —
   다른 역할이 이 모듈을 직접 import 해 호출해도 모든 요청은 Rules / Cloud Functions 가 다시 판정한다.

   [섹션 인터페이스]  meta · navGroups() · contextHtml() · start() · stop() · afterNav() · match(parts, alive) → {key, run}
   ========================================================================== */

import {
  signOutNow, countPending, listPendingBrands, getBrand, getBrandPrivate, loadBrandMap, listPendingStores, getStore, listAllStores, listPendingMenus, listPendingOverrides, getMasterMenu, getQoinConfig, listQoinHistory, approveBrand, rejectBrand, approveStore, rejectStore, readCurrentStatus, runBackfillGeohash, runBackfillQoinAccrual, LIST_LIMIT,
} from './console-data.js';
import {
  esc, safeUrl, fmtDateTime, fmtShortDateTime, fmtClock, shortUid, fmtKrw, fmtRatePct, normalizeStatus, STATUS_LABEL, validateReason, classifyError, writeErrorText,
} from './console-format.js';
import {
  S, root, hooks, $, skel, letter, banner, emptyBlock, errorBlock, statusBadge, uidCell, thumb, kv, tableHtml, skelRows, headHtml, detailSkeleton, flashOnce, makeLoader, toast,
} from './console-ui.js';

export const meta = { role: 'admin', defaultHash: '#/dashboard' };

const NAV = [
  { group: '운영', items: [
    { key: 'dashboard', href: '#/dashboard', label: '대시보드' },
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
  qoin: {
    h2: 'Qoin 적립 소급',
    desc: '적립이 누락된 주문(미해결 이슈)에 당시 요율로 Qoin 을 사후 적립해요. 고객 잔액이 실제로 바뀌니 미리보기를 꼭 먼저 확인하세요.',
    confirm: '미리보기에서 확인한 대상에게 Qoin 을 실제로 적립할까요? 고객 잔액이 바뀌고 되돌릴 수 없어요.',
    dry: () => runBackfillQoinAccrual(true),
    commit: () => runBackfillQoinAccrual(false),
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

function viewTools(alive) {
  const v = $('#view');
  v.innerHTML = `${headHtml({ title: '백필 도구', desc: '누락된 데이터를 사후 보정하는 운영 도구예요. 항상 미리보기로 대상을 확인한 뒤 실행하세요.', refresh: false })}
    ${toolPanel('geo')}
    ${toolPanel('qoin')}`;
  wireTool('geo', alive);
  wireTool('qoin', alive);
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

/* ============================================================================
   brand 섹션 — 브랜드 정보(운영/핵심 2폼) · 검토 현황 · 마스터 메뉴 · 서브 카테고리 · 옵션 그룹 · 산하 매장(읽기) · 가격 오버라이드 · 점포 한정 메뉴.

   ▸ brand 가 자기 제출물을 승인하는 UI 는 없다 (승인 경계는 admin 몫). Rules 가 이제 이것도 막는다
     (firestore.rules:73-90 noSelfApproveOnCreate/Update — brand_self_approve_guard).
   ▸ 브랜드 경로 payload 에는 approvedBy / approvedAt 키를 아예 넣지 않는다 (변경분만 담은 좁은 payload).
     값을 똑같이 다시 보내도 diff 에 안 잡히지만, Timestamp 왕복에서 1비트라도 달라지면 "null 만 허용" 에 걸려 update 전체가 거부된다.
   ▸ brand 는 stores/{id} 본문을 쓰지 않는다 (산하 매장 화면은 읽기 전용, 서브컬렉션만 관리).
   ▸ 브랜드 신규 등록 폼은 없다. 미연결 계정은 GT1 게이트 + claimSubmittedBrand 버튼만 제공한다.

   [보안] 화면 숨김·탭 미노출은 편의다. 모든 읽기/쓰기는 Rules 가 다시 판정한다
   (isBrandHolder: users.role=='brand' && users.brandId==brandId, firestore.rules:57-63).
   ========================================================================== */

import {
  getBrand, getBrandPrivate, getStoreFresh, getMasterMenu, listSubmittedBrands, claimSubmittedBrand, getQoinConfig, listQoinHistoryOf, listBrandStores, listMasterMenus, listMainCategories, listMasterOptionGroups, listAll, listStoreMenus, listStoreOverrides, saveBrandOperation, submitBrandCore, createMasterMenu, submitMasterMenuCore, updateMasterMenuOperation, findMasterOverrides, deleteMasterMenuCascade, submitPriceOverride, readOverrideAndMaster, createStoreOnlyMenu, submitStoreOnlyMenuCore, updateStoreMenuOperation, deleteStoreMenu, fetchOptionGroups, loadTrackingForStore, uploadImage, storagePaths,
} from './console-data.js';
import {
  esc, fmtDateTime, fmtClock, fmtRelative, fmtWon, fmtRatePct, LIMITS, RE_BIZNO, RE_CONTACT, normalizeStatus, STATUS_LABEL, parsePriceInput, appliedOverride, isRevisionPending, callableReason, saveErrorText, parseRateCell, parseSwitchCell, resolveEffectiveQoinRate, qoinRateText, checkImageFile,
} from './console-format.js';
import {
  S, hooks, $, $$, skel, banner, emptyBlock, errorBlock, thumb, kv, tableHtml, skelRows, headHtml, makeLoader, openDialog, field, setFieldError, switchHtml, wireSwitch, saveBarHtml, setSaveBar, registerDirty, changeListHtml, targetBlock, chipGroup, onReadFail, toast, flashOnce, docBadge, tabBar, formBanner, copyBtn, detailSkeleton,
} from './console-ui.js';
import {
  menuForm, catalogView,
} from './console-forms.js';

export const meta = { role: 'brand', defaultHash: '#/b/info' };

/* ── 브랜드 컨텍스트 ──────────────────────────────────────────────────────── */
const B = { state: 'loading', brand: null, err: null, flight: null, gen: 0 };
const brandId = () => S.shell.brandId;
const linked = () => !!S.shell && !!S.shell.brandId;

function ensureBrand(force = false) {
  if (!linked()) return Promise.resolve(B);
  if (!force && B.state !== 'loading' && B.state !== 'error') return Promise.resolve(B);
  if (B.flight) return B.flight;
  B.state = 'loading'; B.err = null;
  const gen = B.gen;
  B.flight = (async () => {
    try {
      const b = await getBrand(brandId());
      if (gen !== B.gen) return B;
      B.brand = b; B.state = b ? 'ready' : 'empty';
    } catch (e) {
      console.error('[brand] 브랜드 조회 실패', e?.code || e);
      if (gen !== B.gen) return B;
      B.state = 'error'; B.err = e; onReadFail(e);
    }
    B.flight = null;
    hooks.renderContext();
    return B;
  })();
  return B.flight;
}
const invalidateBrand = () => { B.state = 'loading'; B.brand = null; return ensureBrand(true); };

export function start() { B.gen++; B.state = 'loading'; B.brand = null; B.err = null; B.flight = null; if (linked()) ensureBrand(true); }
export function stop() { B.gen++; B.flight = null; }

export function navGroups() {
  if (!linked()) return [{ group: '시작하기', items: [{ key: 'info', href: '#/b/info', label: '브랜드 연결' }] }];
  return [
    { group: '브랜드', items: [{ key: 'info', href: '#/b/info', label: '브랜드 정보' }, { key: 'tracking', href: '#/b/tracking', label: '검토 현황' }] },
    { group: '메뉴', items: [{ key: 'menus', href: '#/b/menus', label: '마스터 메뉴' }, { key: 'subcats', href: '#/b/subcats', label: '서브 카테고리' }, { key: 'options', href: '#/b/options', label: '옵션 그룹' }] },
    { group: '가맹점', items: [{ key: 'stores', href: '#/b/stores', label: '산하 매장', ro: true }] },
  ];
}

export function contextHtml() {
  if (!linked()) return '';
  if (B.state === 'loading') return `<div class="a-ctx">${skel('120px', 16)}</div>`;
  if (B.state !== 'ready') return '';
  return `<div class="a-ctx"><div class="a-ctx-name" title="${esc(B.brand.name)}">${esc(B.brand.name || '(이름 없음)')}</div>${docBadge(B.brand)}</div>`;
}

export function match(parts, alive) {
  if (parts[0] !== 'b') return null;
  const [, a, b, c, d, e] = parts;
  if (!linked()) return { key: 'info', run: () => viewGate(alive) }; // 연결 전에는 어떤 b 경로든 게이트 하나로 (B10)
  if (a === 'info' && !b) return { key: 'info', run: () => viewInfo(alive) };
  if (a === 'info' && b === 'ops') return { key: 'info', run: () => viewInfoOps(alive) };
  if (a === 'info' && b === 'core') return { key: 'info', run: () => viewInfoCore(alive) };
  if (a === 'tracking') return { key: 'tracking', run: () => viewTracking(alive) };
  if (a === 'menus' && !b) return { key: 'menus', run: () => viewMenus(alive) };
  if (a === 'menus' && b === 'new') return { key: 'menus', run: () => viewMasterForm(alive, 'create', null) };
  if (a === 'menus' && b && !c) return { key: 'menus', run: () => viewMasterDetail(alive, b) };
  if (a === 'menus' && b && c === 'core') return { key: 'menus', run: () => viewMasterForm(alive, 'core', b) };
  if (a === 'menus' && b && c === 'ops') return { key: 'menus', run: () => viewMasterForm(alive, 'ops', b) };
  if (a === 'subcats') return { key: 'subcats', run: () => viewCatalog(alive, 'sub') };
  if (a === 'options') return { key: 'options', run: () => viewCatalog(alive, 'opt') };
  if (a === 'stores' && !b) return { key: 'stores', run: () => viewStores(alive) };
  if (a === 'stores' && b && (!c || c === 'price')) return { key: 'stores', run: () => viewStoreDetail(alive, b, 'price') };
  if (a === 'stores' && b && c === 'menus' && !d) return { key: 'stores', run: () => viewStoreDetail(alive, b, 'menus') };
  if (a === 'stores' && b && c === 'menus' && d === 'new') return { key: 'stores', run: () => viewStoreMenuForm(alive, b, 'create', null) };
  if (a === 'stores' && b && c === 'menus' && d && (e === 'core' || e === 'ops')) return { key: 'stores', run: () => viewStoreMenuForm(alive, b, e, d) };
  return null;
}

/* ── 공통 ────────────────────────────────────────────────────────────────── */
/** GT2 — 브랜드 승인 상태 배너 (쓰기를 막지 않는 사실 안내). 노출 영향은 단정하지 않는다 (design §0-5). */
function brandBanner(b) {
  const st = normalizeStatus(b?.status);
  if (st === 'pending' && !b.approvedAt) return banner('warn', '', '심사 중 — 고객에게 노출되지 않아요');
  if (st === 'pending') return banner('', '', '수정한 내용을 검토하고 있어요');
  if (st === 'rejected') return banner('warn', '브랜드 검토가 반려되었어요', b.rejectedReason ? String(b.rejectedReason) : '사유가 기록되지 않았어요', '<div class="a-b-actions"><a class="a-btn sm" href="#/b/info/core">브랜드 정보 수정으로 이동</a></div>');
  return '';
}

async function withBrand(alive, box, render, { withBanner = true } = {}) {
  box.innerHTML = `<div class="a-card" aria-busy="true"><span class="a-sr">불러오는 중</span>${skel('50%', 18)}<div style="height:14px"></div>${skel('90%', 14)}<div style="height:8px"></div>${skel('70%', 14)}</div>`;
  const r = await ensureBrand();
  if (!alive()) return;
  if (r.state === 'error') {
    box.innerHTML = errorBlock(r.err, 'data-retry', { title: '브랜드 정보를 불러오지 못했어요', desc: '잠시 후 다시 시도해주세요.' });
    $('[data-retry]', box).onclick = async () => { await invalidateBrand(); if (alive()) withBrand(alive, box, render, { withBanner }); };
    onReadFail(r.err, box);
    return;
  }
  if (r.state === 'empty') { box.innerHTML = emptyBlock('연결된 브랜드를 찾지 못했어요', '관리자에게 문의해 주세요. 브랜드를 다시 등록하지 않아도 돼요'); return; }
  box.innerHTML = `${withBanner ? brandBanner(r.brand) : ''}<div id="brand-body"></div>`;
  render(r.brand, $('#brand-body', box));
}

/* ============================================================================
   GT1 — brand 인데 users.brandId 가 비어 있음 (B10). 등록 폼은 없다.
   ========================================================================== */
const CLAIM_TEXT = {
  already_linked: { t: '이 계정은 이미 다른 브랜드에 연결돼 있어요', d: '관리자에게 문의해 주세요. 직접 바꿀 수는 없어요', btn: '새로고침' },
  not_brand_account: { t: '브랜드 계정이 아니에요', d: '계정 역할이 바뀐 것 같아요. 앱을 다시 열어 보고, 계속 그러면 관리자에게 문의해 주세요', btn: null },
  not_submitter: { t: '이 브랜드는 내 계정으로 등록한 브랜드가 아니에요', d: '관리자에게 문의해 주세요', btn: null }, // 재시도해도 같다 — 재시도 버튼 없음
  brand_not_found: { t: '등록한 브랜드를 찾을 수 없어요', d: '브랜드가 삭제됐을 수 있어요. 다시 확인해 볼까요?', btn: '다시 확인' },
};

function viewGate(alive) {
  const v = $('#view');
  v.innerHTML = `${headHtml({ title: '브랜드 연결', refresh: false })}<div id="gt"></div>`;
  const box = $('#gt');
  let failure = null;
  const draw = async () => {
    box.innerHTML = `<div class="a-gate-card a-in-main" role="status"><h2>브랜드 정보를 확인하고 있어요</h2><div class="a-loadbar"></div></div>`;
    let list;
    try { list = await listSubmittedBrands(S.shell.uid); } catch (e) {
      console.error('[brand] 제출 브랜드 조회 실패', e?.code || e);
      if (!alive()) return;
      // 조회가 실패하면 연결 버튼을 그리지 않는다 (모르는 채로 연결 시도 금지)
      box.innerHTML = `<div class="a-gate-card a-in-main" role="alert"><h2>브랜드 정보를 확인하지 못했어요</h2><p class="a-cap">이미 등록한 브랜드가 있을 수 있어서, 확인되기 전에는 연결할 수 없어요</p><button type="button" class="a-btn" id="gt-retry">다시 시도</button></div>`;
      $('#gt-retry').onclick = draw; onReadFail(e); return;
    }
    if (!alive()) return;
    if (list.length === 0) {
      box.innerHTML = `<div class="a-gate-card a-in-main"><h2>등록한 브랜드를 찾을 수 없어요</h2><p>브랜드 등록은 앱에서 먼저 완료해주세요. 웹에서는 등록할 수 없어요.</p><button type="button" class="a-btn" id="gt-retry">다시 확인</button></div>`;
      $('#gt-retry').onclick = draw; return;
    }
    const first = list[0];
    const f = failure && CLAIM_TEXT[failure];
    box.innerHTML = `<div class="a-gate-card a-in-main"><h2>브랜드 연결을 마치지 못했어요</h2>
      <p>등록한 브랜드 「<strong id="gt-name"></strong>」 가 있어요.</p>
      <p class="a-cap">아직 이 계정에 연결되지 않았어요. 연결하면 브랜드를 관리할 수 있어요. 등록한 브랜드는 그대로 있어요. 다시 등록하지 않아도 돼요.</p>
      ${list.length >= 2 ? `<p class="a-cap">등록한 브랜드가 ${list.length}개 있어요. 가장 먼저 등록한 「${esc(first.name || '')}」 으로 연결을 시도해요. 같은 계정으로 등록된 브랜드가 더 있어서 관리자가 확인할 거예요.</p>` : ''}
      <div id="gt-msg">${f ? banner('error', f.t, f.d) : ''}</div>
      ${f && f.btn === null ? '' : `<button type="button" class="a-btn primary block lg" id="gt-claim">${f && f.btn ? esc(f.btn) : '브랜드 연결'}</button>`}</div>`;
    $('#gt-name').textContent = first.name || '(이름 없음)';
    const claim = $('#gt-claim');
    if (!claim) return;
    claim.onclick = async () => {
      if (failure === 'brand_not_found') { failure = null; draw(); return; }
      if (failure === 'already_linked') { await hooks.recheckRole(true); failure = null; if (alive() && !linked()) draw(); return; }
      claim.disabled = true; claim.innerHTML = '<span class="a-spin"></span>연결하고 있어요…'; S.busy = true;
      try {
        await claimSubmittedBrand(first.id);
        S.busy = false;
        // 응답만 믿고 재구성하지 않는다 — users/{uid} 를 서버에서 다시 읽어 brandId 가 확인되면 셸을 재구성한다.
        S.flash = `브랜드 「${first.name || ''}」 에 연결했어요`;
        const res = await hooks.recheckRole(true);
        if (!res.changed && alive()) {
          S.flash = null;
          $('#gt-msg').innerHTML = banner('warn', '', '연결 결과를 확인하지 못했어요. 새로고침 후 다시 확인해주세요.');
          claim.disabled = false; claim.textContent = '다시 확인';
        }
      } catch (e) {
        S.busy = false;
        const reason = callableReason(e);
        console.error('[brand] 브랜드 연결 실패', reason || e?.code || e);
        if (!alive()) return;
        failure = CLAIM_TEXT[reason] ? reason : null;
        if (reason === 'not_brand_account') hooks.recheckRole(true);
        if (failure) { draw(); return; }
        $('#gt-msg').innerHTML = banner('error', '브랜드 연결을 마치지 못했어요', '잠시 후 다시 시도해주세요');
        claim.disabled = false; claim.textContent = '다시 시도';
      }
    };
  };
  draw();
}

/* ============================================================================
   BR1 브랜드 정보
   ========================================================================== */
function viewInfo(alive) {
  const v = $('#view');
  const flash = flashOnce();
  v.innerHTML = `${headHtml({ title: '브랜드 정보' })}<div id="notice"></div><div id="br-box"></div>`;
  if (flash) toast(flash);
  $('#refresh').onclick = async () => { await invalidateBrand(); if (alive()) viewInfo(alive); };
  withBrand(alive, $('#br-box'), (b, body) => {
    const stamp = $('#stamp'); if (stamp) stamp.textContent = `마지막 갱신 ${fmtClock()}`;
    body.innerHTML = `<div class="a-detail"><div class="a-detail-main">
        <div class="a-card"><h2>${esc(b.name || '(이름 없음)')} ${docBadge(b)}</h2><div style="margin-bottom:16px">${thumb(b.logoUrl, b.name, true)}</div>
          ${kv([['브랜드 이름', b.name], ['소개', b.description], ['제출 시각', fmtDateTime(b.submittedAt)], ['처리 시각', b.approvedAt ? fmtDateTime(b.approvedAt) : '-'], ...(normalizeStatus(b.status) === 'rejected' ? [['반려 사유', b.rejectedReason || '사유가 기록되지 않았어요']] : [])])}</div>
        <div class="a-card" id="br-priv"></div><div class="a-card" id="br-key"></div><div class="a-card" id="br-qoin"></div>
      </div><aside class="a-panel a-card"><h2>정보 수정</h2>
        <a class="a-btn primary block lg" href="#/b/info/ops">운영 정보 수정</a><p class="a-note" style="border:0;padding:4px 0 12px">로고·회사명·사업자·담당자 정보. 저장하면 바로 반영돼요.</p>
        <a class="a-btn block lg" href="#/b/info/core">핵심 정보 수정…<span class="a-chip">재승인 필요</span></a>
        <p class="a-note" style="border:0;padding:8px 0 0">브랜드 이름·소개를 바꾸면 관리자 재승인 대상이 돼요.</p></aside></div>`;
    loadPrivate(b, alive);
    loadQoin(b, alive);
  });
}

async function loadPrivate(b, alive) {
  const priv = $('#br-priv'); const key = $('#br-key');
  const run = async () => {
    priv.innerHTML = `<h2>사업자 · 담당자 정보</h2>${kv([['', skel('70%', 14), true], ['', skel('50%', 14), true], ['', skel('60%', 14), true]])}`;
    key.innerHTML = `<h2>브랜드 키</h2>${skel('40%', 16)}`;
    try {
      const p = await getBrandPrivate(b.id);
      if (!alive()) return;
      const g = (k) => (p && typeof p[k] === 'string' ? p[k] : '');
      priv.innerHTML = `<h2>사업자 · 담당자 정보</h2>${kv([['회사명', b.companyName], ['사업자등록번호', g('businessRegistrationNumber')], ['대표자', g('representativeName')], ['담당자', g('contactName')], ['담당자 연락처', g('contactPhone')], ['본사 주소', g('headOfficeAddress')]])}`;
      const k = g('brandKey');
      key.innerHTML = `<h2>브랜드 키</h2>${k ? `<div class="a-qval a-num" style="font-size:18px">${esc(k)} ${copyBtn(k)}</div><p class="a-cap">가맹 매장이 등록할 때 이 키를 입력해요.</p>` : '<div class="a-cap">아직 발급되지 않았어요</div>'}`;
    } catch (e) {
      console.error('[brand] private/profile 조회 실패', e?.code || e);
      if (!alive()) return;
      const err = `<div class="a-err" role="alert"><strong>사업자 정보를 불러오지 못했어요</strong><button type="button" class="a-btn" data-retry>다시 시도</button></div>`;
      priv.innerHTML = `<h2>사업자 · 담당자 정보</h2>${err}`; key.innerHTML = '<h2>브랜드 키</h2><div class="a-cap">불러오지 못했어요</div>';
      $('[data-retry]', priv).onclick = run; onReadFail(e, priv);
    }
  };
  run();
}

async function loadQoin(b, alive) {
  const box = $('#br-qoin');
  const run = async () => {
    box.innerHTML = `<h2>Qoin 적립률 <span class="a-chip">읽기</span></h2>${skel('40%', 20)}`;
    try {
      const [cfg, hist] = await Promise.all([getQoinConfig(), listQoinHistoryOf(['brands', b.id], 20)]);
      if (!alive()) return;
      const has = (k) => Object.prototype.hasOwnProperty.call(b, k);
      const eff = resolveEffectiveQoinRate({ store: { kind: 'absent', value: null }, brand: parseRateCell(b.qoinAccrualRate, has('qoinAccrualRate')), brandSwitch: parseSwitchCell(b.qoinAccrualEnabled, has('qoinAccrualEnabled')), global: cfg ? cfg.rate : { kind: 'absent', value: null }, hasBrand: true });
      const t = qoinRateText(eff);
      const FIELD = { accrualRate: '적립률', accrualEnabled: '적립 스위치', globalEnabled: '비상 정지', enabled: '비상 정지' };
      const val = (f, x) => (f === 'accrualRate' ? (typeof x === 'number' ? fmtRatePct(x) : '미설정') : (x === true ? '켜짐' : x === false ? '꺼짐' : '-'));
      box.innerHTML = `<h2>Qoin 적립률 <span class="a-chip">읽기</span></h2><div class="a-qval a-num">${esc(t.text)}</div><div class="a-cap">${esc(t.sub)}</div>
        <div style="margin-top:16px">${hist.length === 0 ? '<div class="a-cap">적립률 변경 이력이 없어요</div>' : tableHtml(['변경 시각', '항목', '변경 전 → 후', '사유'], hist.map((r) => `<tr><td class="a-num">${esc(fmtDateTime(r.changedAt))}</td><td>${esc(FIELD[r.field] || '(알 수 없는 항목)')}</td>
          <td class="a-num">${esc(val(r.field, r.before))} → ${esc(val(r.field, r.after))}</td><td class="a-ell" title="${esc(r.reason || '')}">${esc(r.reason || '-')}</td></tr>`))}</div>`;
    } catch (e) {
      console.error('[brand] 적립률 조회 실패', e?.code || e);
      if (!alive()) return;
      box.innerHTML = `<h2>Qoin 적립률 <span class="a-chip">읽기</span></h2><div class="a-err" role="alert"><strong>적립률을 불러오지 못했어요</strong><button type="button" class="a-btn" data-retry>다시 시도</button></div>`;
      $('[data-retry]', box).onclick = run; onReadFail(e, box);
    }
  };
  run();
}

/* ============================================================================
   BR2 브랜드 운영 정보 수정 — 폼 ① (즉시 반영)  : brands 문서 + private/profile 을 한 배치로 (DV-14)
   ========================================================================== */
function viewInfoOps(alive) {
  const v = $('#view');
  v.innerHTML = `<div class="a-crumbs"><a href="#/b/info">← 브랜드 정보</a></div><div class="a-head"><h1 tabindex="-1">브랜드 운영 정보 수정<span class="a-chip a-chip-strong">저장 즉시 반영</span></h1></div><div style="height:16px"></div><div id="br-box"></div>`;
  withBrand(alive, $('#br-box'), async (b, body) => {
    body.innerHTML = '<div id="of"></div>';
    let priv = null;
    try { priv = await getBrandPrivate(b.id); } catch (e) { console.error('[brand] private/profile 조회 실패', e?.code || e); $('#of').innerHTML = errorBlock(e, 'data-retry', { title: '사업자 정보를 불러오지 못했어요', desc: '잠시 후 다시 시도해주세요.' }); $('[data-retry]', $('#of')).onclick = () => viewInfoOps(alive); onReadFail(e, $('#of')); return; }
    if (!alive()) return;
    const g = (k) => (priv && typeof priv[k] === 'string' ? priv[k] : '');
    const init = { companyName: b.companyName || '', businessRegistrationNumber: g('businessRegistrationNumber'), representativeName: g('representativeName'), contactName: g('contactName'), contactPhone: g('contactPhone'), headOfficeAddress: g('headOfficeAddress') };
    let st = { ...init, file: null }; let saving = false; let prev = null;
    const PII = ['businessRegistrationNumber', 'representativeName', 'contactName', 'contactPhone', 'headOfficeAddress'];
    const changes = () => {
      const brandC = {}; const piiC = {};
      if (st.companyName.trim() !== init.companyName.trim()) brandC.companyName = st.companyName.trim();
      if (st.file) brandC.logoUrl = '(새 이미지)';
      for (const k of PII) if (st[k].trim() !== init[k].trim()) piiC[k] = st[k].trim();
      return { brandC, piiC };
    };
    const count = () => { const c = changes(); return Object.keys(c.brandC).length + Object.keys(c.piiC).length; };
    const refresh = () => { setSaveBar(count()); registerDirty(() => !saving && count() > 0); };
    const F = (id, label, key, extra = {}) => field({ id, label, value: st[key], ...extra });
    $('#of').innerHTML = `<div id="form-banner"></div>${banner('', '', '아래 정보는 저장 즉시 반영돼요.')}
      <div class="a-card"><h2>로고 · 회사</h2><div class="a-field"><span class="a-label">로고</span><div class="a-imgpick"><div id="bo-prev">${thumb(b.logoUrl, b.name, true)}</div>
        <div><input type="file" id="bo-file" accept="image/*" class="a-sr"><label for="bo-file" class="a-btn sm" id="bo-filebtn" role="button" tabindex="0">이미지 선택</label><div class="a-help">최대 5MB</div></div></div><div class="a-field-err" id="bo-img-err" hidden></div></div>
        ${F('bo-company', '회사명', 'companyName', { max: LIMITS.companyName, counter: true })}</div>
      <div class="a-card"><h2>사업자 · 담당자</h2>
        ${F('bo-biz', '사업자등록번호', 'businessRegistrationNumber', { ph: '000-00-00000' })}${F('bo-rep', '대표자', 'representativeName')}
        ${F('bo-cname', '담당자 이름', 'contactName', { max: LIMITS.contactName, counter: true })}${F('bo-cphone', '담당자 연락처', 'contactPhone', { ph: '010-0000-0000' })}${F('bo-addr', '본사 주소', 'headOfficeAddress')}</div>
      ${saveBarHtml({ targetName: b.name || '', saveLabel: '저장' })}`;
    const bind = (id, key) => { $(`#${id}`).addEventListener('input', (e) => { st[key] = e.target.value; const c = $(`#${id}-cnt`); if (c) c.textContent = `${[...e.target.value].length} / ${e.target.maxLength}`; refresh(); }); };
    bind('bo-company', 'companyName'); bind('bo-biz', 'businessRegistrationNumber'); bind('bo-rep', 'representativeName'); bind('bo-cname', 'contactName'); bind('bo-cphone', 'contactPhone'); bind('bo-addr', 'headOfficeAddress');
    $('#bo-file').onchange = (e) => {
      const f = e.target.files[0]; const er = $('#bo-img-err'); if (!f) return;
      const chk = checkImageFile(f); if (!chk.ok) { er.hidden = false; er.textContent = chk.error; e.target.value = ''; return; }
      er.hidden = true; if (prev) URL.revokeObjectURL(prev); prev = URL.createObjectURL(f); st.file = f; $('#bo-prev').innerHTML = `<img class="a-thumb lg" src="${esc(prev)}" alt="">`; refresh();
    };
    $('#bo-filebtn').onkeydown = (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); $('#bo-file').click(); } };
    $('#sb-reset').onclick = () => viewInfoOps(alive);
    $('#sb-save').onclick = async () => {
      const { brandC, piiC } = changes(); let bad = false;
      const chk = (id, msg, cond) => { setFieldError(id, cond ? msg : ''); if (cond) bad = true; };
      chk('bo-biz', '000-00-00000 형식으로 입력해주세요', 'businessRegistrationNumber' in piiC && (piiC.businessRegistrationNumber === '' || !RE_BIZNO.test(piiC.businessRegistrationNumber)));
      chk('bo-cphone', '010-0000-0000 형식으로 입력해주세요', 'contactPhone' in piiC && (piiC.contactPhone === '' || !RE_CONTACT.test(piiC.contactPhone)));
      chk('bo-cname', '담당자 이름을 입력해주세요', 'contactName' in piiC && piiC.contactName === '');
      chk('bo-company', '회사명을 입력해주세요', 'companyName' in brandC && brandC.companyName === '');
      if (bad || count() === 0 || saving) return;
      saving = true; S.busy = true; formBanner(''); const btn = $('#sb-save'); const label = btn.textContent;
      $$('input, button', $('#of')).forEach((el) => { el.disabled = true; }); btn.innerHTML = '<span class="a-spin"></span>저장 중…';
      try {
        if (st.file) brandC.logoUrl = await uploadImage(storagePaths.brandLogo(b.id), st.file);
        await saveBrandOperation(b.id, brandC, piiC);
      } catch (e) {
        console.error('[brand] 운영 정보 저장 실패', e?.code || e?.name || e);
        const t = e?.name === 'AdminError' && e.code === 'validation' ? { text: e.message } : saveErrorText(e);
        formBanner(banner('error', '실패', t.text)); if (t.permission) hooks.recheckRole();
        saving = false; S.busy = false; $$('input, button', $('#of')).forEach((el) => { el.disabled = false; }); btn.textContent = label; refresh(); return;
      }
      saving = false; S.busy = false; registerDirty(() => false);
      S.flash = '즉시 반영되었습니다'; await invalidateBrand(); if (alive()) hooks.go('#/b/info');
    };
    refresh();
  });
}

/* ============================================================================
   BR3 브랜드 핵심 정보 수정 — 폼 ② (status 'pending' 회귀, 확인 모달, 노출 영향 단정 금지)
   ========================================================================== */
function viewInfoCore(alive) {
  const v = $('#view');
  v.innerHTML = `<div class="a-crumbs"><a href="#/b/info">← 브랜드 정보</a></div><div class="a-head"><h1 tabindex="-1">브랜드 핵심 정보 수정<span class="a-chip a-chip-strong">재승인 필요</span></h1></div><div style="height:16px"></div><div id="br-box"></div>`;
  withBrand(alive, $('#br-box'), (b, body) => {
    const init = { name: b.name || '', description: b.description || '' };
    let st = { ...init }; let saving = false;
    const changes = () => { const c = {}; if (st.name.trim() !== init.name.trim()) c.name = st.name.trim(); if (st.description.trim() !== init.description.trim()) c.description = st.description.trim(); return c; };
    const rejected = normalizeStatus(b.status) === 'rejected';
    body.innerHTML = `<div id="form-banner"></div>${banner(rejected ? 'warn' : '', '', rejected ? '검토가 반려되었어요. 수정한 뒤 다시 제출해주세요.' : '아래 정보는 관리자 검토 후 반영돼요.')}
      <div class="a-card"><h2>핵심 정보</h2>${field({ id: 'bc-name', label: '브랜드 이름', required: true, value: st.name, max: LIMITS.brandName, counter: true })}
      ${field({ id: 'bc-desc', label: '소개', value: st.description, multiline: true, rows: 3, max: LIMITS.brandDescription, counter: true })}</div>
      ${saveBarHtml({ targetName: b.name || '', saveLabel: '검토 요청 보내기…' })}`;
    const refresh = () => { setSaveBar(Object.keys(changes()).length); registerDirty(() => !saving && Object.keys(changes()).length > 0); };
    $('#bc-name').oninput = (e) => { st.name = e.target.value; $('#bc-name-cnt').textContent = `${[...e.target.value].length} / ${LIMITS.brandName}`; refresh(); };
    $('#bc-desc').oninput = (e) => { st.description = e.target.value; $('#bc-desc-cnt').textContent = `${[...e.target.value].length} / ${LIMITS.brandDescription}`; refresh(); };
    $('#sb-reset').onclick = () => { st = { ...init }; $('#bc-name').value = st.name; $('#bc-desc').value = st.description; refresh(); };
    $('#sb-save').onclick = () => {
      const c = changes();
      if (!st.name.trim()) { setFieldError('bc-name', '브랜드 이름을 입력해주세요'); $('#bc-name').focus(); return; } setFieldError('bc-name', '');
      if (Object.keys(c).length === 0) return;
      let fresh = b;
      openDialog({
        title: '핵심 정보 변경 검토 요청', confirmLabel: '검토 요청 보내기', busyLabel: '보내는 중…', bodyHtml: '',
        onOpen: async (api) => {
          api.setBody('<div class="a-cap" role="status"><span class="a-spin"></span> 상태 확인 중…</div>'); api.setConfirmEnabled(false);
          try {
            fresh = await getBrand(b.id); if (!fresh) throw Object.assign(new Error('nf'), { code: 'not-found' });
            const rej = normalizeStatus(fresh.status) === 'rejected';
            const rows = [...('name' in c ? [['브랜드 이름', fresh.name || '', c.name]] : []), ...('description' in c ? [['소개', fresh.description || '', c.description]] : [])];
            api.setBody(`${targetBlock(fresh.name, `현재 상태: ${esc(STATUS_LABEL[normalizeStatus(fresh.status)] || '알 수 없음')}`)}<div class="a-sub-h">바꾸는 내용</div>${changeListHtml(rows)}
              ${banner('', '', rej ? '수정한 내용으로 다시 검토해요.' : '브랜드 이름 · 소개를 바꾸면 관리자 재승인 대상이 돼요. 승인 상태가 「대기」 로 바뀌어요.')}`); // 고객 노출 영향은 단정하지 않는다
            api.setConfirmEnabled(true);
          } catch (e) { api.setBody(''); api.showMsg(banner('error', '', '브랜드 상태를 확인하지 못했어요')); onReadFail(e); }
        },
        onConfirm: async () => { await submitBrandCore(b.id, c); registerDirty(() => false); S.flash = '검토 요청을 보냈어요'; await invalidateBrand(); hooks.go('#/b/info'); },
        onError: (e, api) => { const t = saveErrorText(e); api.showMsg(banner('error', '실패', t.text)); if (t.permission) hooks.recheckRole(); },
      });
    };
    refresh();
  });
}

/* ============================================================================
   BR4 검토 현황 (읽기) — 마스터 메뉴 · 가격 오버라이드 · 점포 한정 메뉴 중 대기·반려
   인덱스 없는 컬렉션 그룹 쿼리 대신 산하 매장별 서브컬렉션을 N회 조회한다. 부분 실패를 전체 성공처럼 보이지 않는다.
   ========================================================================== */
function viewTracking(alive) {
  const v = $('#view');
  v.innerHTML = `${headHtml({ title: '검토 현황', tag: '읽기' })}<div id="tr-banner"></div><div id="tr-tools"></div><div id="tr-prog" class="a-cap"></div><div id="tr-box"></div>`;
  withBrand(alive, $('#tr-box'), async (b, body) => {
    body.innerHTML = '';
    let f = 'all'; let rows = []; let failed = []; let storesList = []; let masters = []; let running = false;
    const kindLabel = { master: '마스터 메뉴', override: '가격 오버라이드', storeMenu: '점포 한정 메뉴' };
    const draw = (partial) => {
      $('#tr-tools').innerHTML = chipGroup('상태', [['all', '전체'], ['pending', '대기'], ['rejected', '반려']], f);
      $$('[data-f]', $('#tr-tools')).forEach((x) => { x.onclick = () => { f = x.dataset.f; draw(partial); }; });
      const hit = rows.filter((r) => f === 'all' || normalizeStatus(r.doc.status) === f).sort((a, c) => (c.doc.submittedAt?.toMillis?.() ?? 0) - (a.doc.submittedAt?.toMillis?.() ?? 0));
      $('#tr-banner').innerHTML = failed.length ? banner('warn', '', `일부 매장의 항목을 불러오지 못했어요 (${failed.length}곳). 아래 목록은 전부가 아닐 수 있어요.`, '<div class="a-b-actions"><button type="button" class="a-btn sm" id="tr-retry">실패한 곳만 다시 시도</button></div>') : '';
      const rb = $('#tr-retry'); if (rb) rb.onclick = () => run(failed.map((x) => x.id));
      const box = $('#tr-box');
      if (hit.length === 0) {
        box.innerHTML = partial ? skelRows(5, 4) : (rows.length === 0 && failed.length === 0 ? emptyBlock('제출한 항목이 없어요', '매장 또는 가격 재정의를 제출하면 여기에서 검토 상태를 확인할 수 있어요.')
          : emptyBlock('조건에 맞는 항목이 없어요', '', '<br><button type="button" class="a-link" id="tr-clear">필터 지우기</button>'));
        const c = $('#tr-clear'); if (c) c.onclick = () => { f = 'all'; draw(false); };
        return;
      }
      box.innerHTML = tableHtml(['구분', '대상', '상태', '제출', ''], hit.map((r) => `<tr><td>${kindLabel[r.kind]}</td><td>${esc(r.label)}${normalizeStatus(r.doc.status) === 'rejected' ? `<details class="a-why"><summary>반려 사유</summary>${esc(r.doc.rejectedReason || '사유가 기록되지 않았어요')}</details>` : ''}</td>
        <td>${docBadge(r.doc)}</td><td title="${esc(fmtDateTime(r.doc.submittedAt))}">${esc(fmtRelative(r.doc.submittedAt))}</td><td><a href="${r.href}">열기 →</a></td></tr>`)) + `<div class="a-total">총 ${hit.length}건${partial ? ' · 확인 중' : ''}</div>`;
    };
    const run = async (onlyIds = null) => {
      if (running) return; running = true;
      const st = $('#refresh'); if (st) st.disabled = true;
      try {
        if (!onlyIds) {
          rows = []; failed = []; draw(true);
          const [ml, sl] = await Promise.all([listMasterMenus(b.id), listBrandStores(b.id)]);
          if (!alive()) return;
          masters = ml; storesList = sl.rows;
          ml.filter((m) => m.status !== 'approved').forEach((m) => rows.push({ kind: 'master', doc: m, label: m.name || '(이름 없음)', href: `#/b/menus/${encodeURIComponent(m.id)}` }));
        } else rows = rows.filter((r) => !onlyIds.includes(r.storeId));
        const targets = onlyIds ? storesList.filter((s) => onlyIds.includes(s.id)) : storesList;
        failed = onlyIds ? failed.filter((x) => !onlyIds.includes(x.id)) : [];
        const mName = new Map(masters.map((m) => [m.id, m.name]));
        let done = 0; const queue = [...targets];
        $('#tr-prog').textContent = targets.length ? `산하 매장 0 / ${targets.length}곳 확인 중…` : '';
        await Promise.all(Array.from({ length: 4 }, async () => {
          while (queue.length) {
            const s = queue.shift();
            try {
              const t = await loadTrackingForStore(s.id);
              t.overrides.filter((o) => o.updatedBy === 'brand' && o.status !== 'approved').forEach((o) => rows.push({ kind: 'override', storeId: s.id, doc: o, label: `${mName.get(o.id) || o.id} · ${s.name || ''}${typeof o.priceOverride === 'number' ? ` · ${fmtWon(o.priceOverride)}` : ''}`, href: `#/b/stores/${encodeURIComponent(s.id)}/price` }));
              t.storeMenus.filter((m) => m.scope === 'store' && m.brandId === b.id && m.status !== 'approved').forEach((m) => rows.push({ kind: 'storeMenu', storeId: s.id, doc: m, label: `${m.name || '(이름 없음)'} · ${s.name || ''}`, href: `#/b/stores/${encodeURIComponent(s.id)}/menus` }));
            } catch (e) { console.error('[brand] 매장별 조회 실패', s.id, e?.code || e); failed.push({ id: s.id, name: s.name }); onReadFail(e); }
            done++; if (alive()) { $('#tr-prog').textContent = `산하 매장 ${done} / ${targets.length}곳 확인 중…`; draw(true); }
          }
        }));
        if (!alive()) return;
        $('#tr-prog').textContent = '';
        const stamp = $('#stamp'); if (stamp && failed.length === 0) stamp.textContent = `마지막 갱신 ${fmtClock()}`;
        draw(false);
      } catch (e) {
        console.error('[brand] 검토 현황 조회 실패', e?.code || e);
        if (!alive()) return;
        $('#tr-prog').textContent = '';
        $('#tr-box').innerHTML = errorBlock(e, 'data-retry', { title: '불러오지 못했어요', desc: '잠시 후 다시 시도해주세요.' }); $('[data-retry]', $('#tr-box')).onclick = () => run(); onReadFail(e, $('#tr-box'));
      } finally { running = false; if (st) st.disabled = false; }
    };
    $('#refresh').onclick = () => run();
    run();
  }, { withBanner: false });
}

/* ============================================================================
   BR5/BR6 마스터 메뉴
   ========================================================================== */
async function brandCatalog() {
  const [mainCategories, subCategories, brandGroups, master] = await Promise.all([
    listMainCategories(), listAll(['brands', brandId()], 'subCategories'), listAll(['brands', brandId()], 'optionGroups'), listMasterOptionGroups(),
  ]);
  return { mainCategories, subCategories, optionGroups: [...master.map((g) => ({ ...g, scope: 'master' })), ...brandGroups.map((g) => ({ ...g, scope: 'brand' }))] };
}
const menuStatusText = (m) => (isRevisionPending(m) ? '수정 대기' : STATUS_LABEL[normalizeStatus(m.status)] || '알 수 없음');

function viewMenus(alive) {
  const v = $('#view');
  v.innerHTML = `${headHtml({ title: '마스터 메뉴' })}<div id="br-box"></div>`;
  withBrand(alive, $('#br-box'), (b, body) => {
    let f = 'all'; let rows = [];
    body.innerHTML = '<div class="a-toolbar" id="mn-tools"></div><div id="notice"></div><div id="mn-box"></div>';
    const tools = () => {
      $('#mn-tools').innerHTML = `${chipGroup('상태', [['all', '전체'], ['approved', '승인됨'], ['pending', '대기'], ['rejected', '반려됨']], f)}<span style="margin-left:auto"></span><a class="a-btn primary" href="#/b/menus/new">메뉴 등록</a>`;
      $$('[data-f]', $('#mn-tools')).forEach((x) => { x.onclick = () => { f = x.dataset.f; tools(); draw(); }; });
    };
    const draw = () => {
      const hit = rows.filter((m) => f === 'all' || normalizeStatus(m.status) === f);
      const box = $('#mn-box');
      if (rows.length === 0) { box.innerHTML = emptyBlock('등록한 마스터 메뉴가 없어요', '첫 메뉴를 등록하면 승인 후 가맹 매장에 쓸 수 있어요', '<br><a class="a-btn primary" href="#/b/menus/new">메뉴 등록</a>'); return; }
      if (hit.length === 0) { box.innerHTML = emptyBlock('조건에 맞는 메뉴가 없어요', '', '<br><button type="button" class="a-link" id="mn-clear">필터 지우기</button>'); $('#mn-clear').onclick = () => { f = 'all'; tools(); draw(); }; return; }
      box.innerHTML = tableHtml(['메뉴', '카테고리', '가격', '상태', '노출', '순서', ''], hit.map((m) => `<tr>
        <td><div class="a-name">${thumb(m.imageUrl, m.name)}<a href="#/b/menus/${encodeURIComponent(m.id)}">${esc(m.name || '(이름 없음)')}</a></div></td><td>${esc(m.mainCategory || '-')}</td>
        <td class="a-num">${esc(typeof m.basePrice === 'number' ? m.basePrice.toLocaleString('ko-KR') + '원' : '-')}</td><td>${docBadge(m)}</td>
        <td class="a-sw-row">${switchHtml(`v-${m.id}`, m.visible !== false, `${m.name} 노출`, `data-id="${esc(m.id)}"`)}</td><td class="a-num">${esc(m.displayOrder ?? 0)}</td>
        <td class="a-actions"><a href="#/b/menus/${encodeURIComponent(m.id)}/core">편집</a> <a href="#/b/menus/new?clone=${encodeURIComponent(m.id)}">복제</a> <button type="button" class="a-link" data-del="${esc(m.id)}">삭제…</button></td></tr>`))
        + `<div class="a-total">총 ${hit.length}개</div>`;
      // 노출 스위치 = 운영 5키 경로 (즉시 반영). 응답 전에는 상태가 바뀌지 않는다.
      $$('.a-switch', box).forEach((sw) => wireSwitch(sw, async (next) => { await updateMasterMenuOperation(b.id, sw.dataset.id, { visible: next }); const m = rows.find((x) => x.id === sw.dataset.id); if (m) m.visible = next; }));
      $$('[data-del]', box).forEach((x) => { x.onclick = () => deleteMasterDialog(b, rows.find((m) => m.id === x.dataset.del), x, load); });
    };
    const load = async () => {
      $('#mn-box').innerHTML = skelRows(7, 8);
      try { rows = await listMasterMenus(b.id); if (!alive()) return; tools(); draw(); const st = $('#stamp'); if (st) st.textContent = `마지막 갱신 ${fmtClock()}`; }
      catch (e) { console.error('[brand] 마스터 메뉴 조회 실패', e?.code || e); if (!alive()) return; $('#mn-box').innerHTML = errorBlock(e, 'data-retry', { title: '메뉴를 불러오지 못했어요', desc: '잠시 후 다시 시도해주세요.' }); $('[data-retry]', $('#mn-box')).onclick = load; onReadFail(e, $('#mn-box')); }
    };
    $('#refresh').onclick = load; tools(); load();
  });
}

/** 삭제 cascade 모달 — 영향 범위를 먼저 조회(모른 채 삭제하지 않는다), 오버라이드가 있으면 이름 입력, 오버라이드 선삭제 → 메뉴 삭제. */
function deleteMasterDialog(b, m, trigger, reload, after = null) {
  let found = null;
  const body = () => `${targetBlock(`${m.name || '(이름 없음)'} · 마스터 메뉴`)}<p class="a-ask">삭제된 메뉴는 복구할 수 없어요.</p>
    <div id="dm-state" class="a-cap" role="status"><span class="a-spin"></span> 영향을 확인하고 있어요</div><div id="dm-name"></div>
    <ul class="a-steps" id="dm-steps" hidden><li data-s="0"><span class="a-sdot"></span>가격 오버라이드 삭제 <span id="dm-prog"></span></li><li data-s="1"><span class="a-sdot"></span>메뉴 삭제</li></ul>`;
  const probe = async (api) => {
    api.setConfirmEnabled(false);
    api.q('#dm-state').innerHTML = '<span class="a-spin"></span> 영향을 확인하고 있어요'; api.q('#dm-name').innerHTML = '';
    try {
      found = await findMasterOverrides(b.id, m.id);
      if (!document.contains(api.el)) return;
      if (found.refs.length === 0) { api.q('#dm-state').textContent = '이 메뉴를 쓰는 매장 가격 오버라이드는 없어요.'; api.setConfirmEnabled(true); return; }
      api.q('#dm-state').innerHTML = `이 메뉴를 쓰는 매장 가격 오버라이드 ${found.refs.length}개도 함께 삭제돼요.`;
      api.q('#dm-name').innerHTML = field({ id: 'dm-in', label: `메뉴 이름을 입력하면 삭제할 수 있어요`, value: '', ph: m.name || '' });
      api.q('#dm-in').addEventListener('input', (e) => api.setConfirmEnabled(e.target.value.trim() === (m.name || '').trim()));
    } catch (e) {
      console.error('[brand] 영향 범위 조회 실패', e?.code || e);
      if (!document.contains(api.el)) return;
      api.q('#dm-state').innerHTML = '영향 범위를 확인하지 못해 삭제할 수 없어요.';
      const bt = api.addFootButton('dm-recheck', '다시 확인', () => { bt.remove(); probe(api); }); onReadFail(e);
    }
  };
  openDialog({
    title: '메뉴를 삭제할까요?', trigger, bodyHtml: body(), confirmLabel: '삭제', confirmClass: 'reject-confirm', busyLabel: '삭제 중…',
    onOpen: (api) => { probe(api); },
    onConfirm: async (api) => {
      const fresh = await findMasterOverrides(b.id, m.id); // 재시도 시 남은 것만 다시 찾는다
      api.q('#dm-steps').hidden = false;
      const mark = (i) => $$('#dm-steps li', api.el).forEach((li) => { const n = Number(li.dataset.s); li.className = n < i ? 'done' : n === i ? 'now' : ''; });
      mark(0);
      await deleteMasterMenuCascade(b.id, m.id, fresh.refs, (d, t) => { api.q('#dm-prog').textContent = `${d} / ${t}`; });
      mark(2);
      S.flash = '삭제됐어요';
      if (after) after(); else await reload();
      toast('삭제됐어요');
    },
    onError: (e, api) => {
      if (e?.stage === 'overrides') api.showMsg(banner('error', '실패', '일부 가격 오버라이드만 삭제하고 멈췄어요. 메뉴는 아직 남아 있어요. 다시 시도하면 이어서 삭제돼요.'));
      else if (e?.stage === 'menu') api.showMsg(banner('error', '실패', '가격 오버라이드는 삭제했지만 메뉴 삭제에 실패했어요. 다시 시도해주세요.'));
      else { const t = saveErrorText(e); api.showMsg(banner('error', '실패', t.text)); if (t.permission) hooks.recheckRole(); }
    },
  });
}

function viewMasterDetail(alive, id) {
  const v = $('#view');
  v.innerHTML = detailSkeleton('#/b/menus', '마스터 메뉴 목록');
  withBrand(alive, v, async (b, body) => {
    let m;
    try { m = await getMasterMenu(b.id, id); } catch (e) {
      if (!alive()) return;
      body.innerHTML = `<div class="a-crumbs"><a href="#/b/menus">← 마스터 메뉴 목록</a></div>${errorBlock(e)}`; $('[data-retry]', body).onclick = () => viewMasterDetail(alive, id); onReadFail(e, body); return;
    }
    if (!alive()) return;
    if (!m) { body.innerHTML = `<div class="a-crumbs"><a href="#/b/menus">← 마스터 메뉴 목록</a></div>${emptyBlock('찾을 수 없는 메뉴예요', '', '<br><a class="a-link" href="#/b/menus">목록으로</a>')}`; return; }
    body.innerHTML = `<div class="a-crumbs"><a href="#/b/menus">← 마스터 메뉴 목록</a></div><div class="a-head"><h1 tabindex="-1">${esc(m.name || '(이름 없음)')} ${docBadge(m)}</h1></div><div style="height:16px"></div>
      <div class="a-detail"><div class="a-detail-main"><div class="a-card"><h2>메뉴 정보</h2><div style="margin-bottom:16px">${thumb(m.imageUrl, m.name, true)}</div>
        ${kv([['이름', m.name], ['가격', typeof m.basePrice === 'number' ? m.basePrice.toLocaleString('ko-KR') + '원' : '-'], ['카테고리', m.mainCategory], ['설명', m.description], ['태그', (m.tags || []).join(', ')], ['노출', m.visible === false ? '꺼짐' : '켜짐'], ['순서', String(m.displayOrder ?? 0)], ['옵션 그룹', `${(m.optionGroupRefs || []).length}개`], ['비활성 옵션', `${(m.disabledOptionGroupIds || []).length + (m.disabledOptionItemIds || []).length}개`]])}</div>
        <div class="a-card"><h2>검토 정보</h2>${kv([['상태', menuStatusText(m)], ['제출 시각', fmtDateTime(m.submittedAt)], ['승인 시각', m.approvedAt ? fmtDateTime(m.approvedAt) : '-'], ...(normalizeStatus(m.status) === 'rejected' ? [['반려 사유', m.rejectedReason || '사유가 기록되지 않았어요']] : [])])}</div></div>
      <aside class="a-panel a-card"><h2>작업</h2><a class="a-btn primary block lg" href="#/b/menus/${encodeURIComponent(m.id)}/ops">운영 정보 수정</a><p class="a-note" style="border:0;padding:4px 0 12px">노출·태그·순서·사진·옵션 비활성. 저장하면 바로 반영돼요.</p>
        <a class="a-btn block lg" href="#/b/menus/${encodeURIComponent(m.id)}/core">핵심 정보 수정…<span class="a-chip">재승인 필요</span></a><p class="a-note" style="border:0;padding:8px 0">이름·가격·설명·카테고리를 바꾸면 관리자 재승인 대상이 돼요.</p>
        <div class="a-btns"><a class="a-btn" href="#/b/menus/new?clone=${encodeURIComponent(m.id)}">복제</a><button type="button" class="a-btn" id="md-del">삭제…</button></div></aside></div>`;
    $('#md-del').onclick = (e) => deleteMasterDialog(b, m, e.currentTarget, null, () => hooks.go('#/b/menus'));
  }, { withBanner: false });
}

/* BR7/BR8/BR9 — 등록(복제 포함) · 핵심 수정 · 운영 수정 */
function viewMasterForm(alive, mode, id) {
  const v = $('#view');
  const params = new URLSearchParams(location.hash.split('?')[1] || '');
  const cloneId = mode === 'create' ? params.get('clone') : null;
  const title = mode === 'create' ? (cloneId ? '메뉴 복제' : '메뉴 등록') : mode === 'core' ? '메뉴 핵심 정보 수정' : '메뉴 운영 정보 수정';
  const chip = mode === 'ops' ? '저장 즉시 반영' : '재승인 필요';
  v.innerHTML = `<div class="a-crumbs"><a href="${id ? `#/b/menus/${encodeURIComponent(id)}` : '#/b/menus'}">← ${id ? '메뉴 상세' : '마스터 메뉴 목록'}</a></div>
    <div class="a-head"><h1 tabindex="-1">${title}<span class="a-chip a-chip-strong">${mode === 'create' ? (cloneId ? '복제' : '검토 요청') : chip}</span></h1></div><div style="height:16px"></div><div id="br-box"></div>`;
  withBrand(alive, $('#br-box'), async (b, body) => {
    body.innerHTML = '<div id="mf-box"></div>';
    try {
      const [catalog, src] = await Promise.all([brandCatalog(), id || cloneId ? getMasterMenu(b.id, id || cloneId) : Promise.resolve(null)]);
      if (!alive()) return;
      if ((id || cloneId) && !src) { $('#mf-box').innerHTML = emptyBlock('찾을 수 없는 메뉴예요', '', '<br><a class="a-link" href="#/b/menus">목록으로</a>'); return; }
      if (mode !== 'create' && normalizeStatus(src.status) === null) { /* 알 수 없는 status — 폼은 열되 배너로 알린다 */ }
      const initial = cloneId ? { ...src, name: `${src.name} 복사`, status: undefined } : src;
      menuForm({
        box: $('#mf-box'), alive, initial, isCreate: mode === 'create', alwaysSavable: mode === 'create', targetName: initial?.name || '새 메뉴', catalog,
        sections: mode === 'create' ? { image: true, core: true, ops: true, requireImage: true } : mode === 'core' ? { core: true } : { ops: true, image: true, disabled: true },
        saveLabel: mode === 'create' ? '저장 (검토 요청)' : mode === 'core' ? '검토 요청 보내기…' : '저장',
        loadDisableGroups: () => fetchOptionGroups(src?.optionGroupRefs || [], { brandId: b.id }),
        onSubmit: (c) => {
          if (mode === 'core') return coreConfirm(b, id, c);
          return c.runSave(async () => {
            const imageUrl = await c.uploadIfNeeded(storagePaths.masterMenu(b.id, mode === 'create' ? null : id));
            if (mode === 'create') await createMasterMenu(b.id, { ...c.values(), imageUrl });
            else { const ch = { ...c.changes() }; if ('imageUrl' in ch) ch.imageUrl = imageUrl; await updateMasterMenuOperation(b.id, id, ch); }
          }).then((ok) => { if (ok) { registerDirty(() => false); S.flash = mode === 'create' ? '검토 요청을 보냈어요' : '즉시 반영되었습니다'; hooks.go(id ? `#/b/menus/${encodeURIComponent(id)}` : '#/b/menus'); } });
        },
      });
    } catch (e) {
      console.error('[brand] 메뉴 폼 로드 실패', e?.code || e);
      if (!alive()) return;
      $('#mf-box').innerHTML = errorBlock(e, 'data-retry', { title: '불러오지 못했어요', desc: '잠시 후 다시 시도해주세요.' }); $('[data-retry]', $('#mf-box')).onclick = () => viewMasterForm(alive, mode, id); onReadFail(e, $('#mf-box'));
    }
  });
}

/** BR8 확인 모달 — U5 확정 문구: 마스터 메뉴는 매장과 달리 "목록에서 사라진다" (결제 게이트는 master.status 를 보지 않아 담긴 주문은 결제될 수 있다). */
function coreConfirm(b, id, ctrl) {
  const changes = ctrl.changes(); const init = ctrl.initial;
  const labels = { name: '이름', description: '설명', mainCategory: '카테고리', subCategoryId: '서브 카테고리', basePrice: '가격', optionGroupRefs: '옵션 그룹' };
  const show = (k, val) => (k === 'basePrice' ? (val === '' || val == null ? '' : `${Number(val).toLocaleString('ko-KR')}원`) : k === 'optionGroupRefs' ? `${val.length}개` : String(val ?? ''));
  const rows = Object.keys(changes).filter((k) => labels[k]).map((k) => [labels[k], show(k, k === 'optionGroupRefs' ? init.optionGroupRefs : init[k]), show(k, changes[k])]);
  let fresh = null;
  openDialog({
    title: '핵심 정보 변경 검토 요청', confirmLabel: '검토 요청 보내기', busyLabel: '보내는 중…', bodyHtml: '',
    onOpen: async (api) => {
      api.setBody('<div class="a-cap" role="status"><span class="a-spin"></span> 상태 확인 중…</div>'); api.setConfirmEnabled(false);
      try {
        fresh = await getMasterMenu(b.id, id); if (!fresh) throw Object.assign(new Error('nf'), { code: 'not-found' });
        const listed = fresh.status === 'approved' || isRevisionPending(fresh); // 지금 고객 목록에 있거나(approved) 이미 수정 검토 중
        api.setBody(`${targetBlock(fresh.name, `현재 상태: ${esc(menuStatusText(fresh))}`)}<div class="a-sub-h">바꾸는 내용</div>${changeListHtml(rows)}
          ${banner('warn', '', fresh.status === 'approved' ? '수정하면 관리자 승인 전까지 고객 메뉴 목록에 보이지 않습니다. 이미 장바구니에 담긴 주문은 결제될 수 있습니다.'
            : listed ? '이미 수정 검토 중이에요. 수정한 내용으로 다시 검토해요. 승인 전까지 고객 메뉴 목록에 보이지 않습니다.' : '수정한 내용으로 다시 검토해요.')}
          <p class="a-cap">승인 상태가 「수정 대기」 로 바뀌어요.</p>`);
        api.setConfirmEnabled(true);
      } catch (e) { api.setBody(''); api.showMsg(banner('error', '', '메뉴 상태를 확인하지 못했어요')); onReadFail(e); }
    },
    onConfirm: async () => { const ch = { ...changes }; delete ch.imageUrl; await submitMasterMenuCore(b.id, id, ch); registerDirty(() => false); S.flash = '검토 요청을 보냈어요'; hooks.go(`#/b/menus/${encodeURIComponent(id)}`); },
    onError: (e, api) => { const t = saveErrorText(e); api.showMsg(banner('error', '실패', t.text)); if (t.permission) hooks.recheckRole(); },
  });
}

/* BR10/BR11 */
function viewCatalog(alive, kind) {
  const v = $('#view');
  v.innerHTML = `${headHtml({ title: kind === 'sub' ? '서브 카테고리' : '옵션 그룹', refresh: false })}<div id="br-box"></div>`;
  withBrand(alive, $('#br-box'), async (b, body) => {
    body.innerHTML = '<div id="cat-box"></div>';
    try { const cats = kind === 'sub' ? await listMainCategories() : []; if (!alive()) return; catalogView({ kind, scope: 'brand', ownerId: b.id, alive, box: $('#cat-box'), mainCategories: cats }); }
    catch (e) { $('#cat-box').innerHTML = errorBlock(e); $('[data-retry]', $('#cat-box')).onclick = () => viewCatalog(alive, kind); onReadFail(e, $('#cat-box')); }
  });
}

/* ============================================================================
   BR12 산하 매장 (읽기 전용)
   ========================================================================== */
function viewStores(alive) {
  const v = $('#view');
  v.innerHTML = `${headHtml({ title: '산하 매장', tag: '읽기' })}${banner('', '', '산하 매장 정보는 점주가 관리해요. 여기서는 조회와 가격 · 점포 한정 메뉴 제출만 할 수 있어요.')}<div id="notice"></div><div id="br-box"></div>
    <p class="a-cap">승인된 가맹점만 보여요. 승인을 기다리는 가맹점은 관리자 승인 후 나타나요.</p>`;
  withBrand(alive, $('#br-box'), (b, body) => {
    body.innerHTML = '<div id="st-box"></div>';
    const loader = makeLoader({
      alive, box: $('#st-box'), cols: 5,
      load: async () => { const [r, cfg] = await Promise.all([listBrandStores(b.id), getQoinConfig().catch(() => null)]); return { ...r, cfg }; },
      render: ({ rows, cfg }) => (rows.length === 0 ? emptyBlock('승인된 가맹점이 없어요', '가맹점이 승인되면 여기에 나타나요')
        : tableHtml(['매장', '주소', '상태', 'Qoin 적립률', ''], rows.map((s) => {
          const has = (o, k) => Object.prototype.hasOwnProperty.call(o, k);
          const eff = resolveEffectiveQoinRate({ store: parseRateCell(s.qoinAccrualRate, has(s, 'qoinAccrualRate')), storeSwitch: parseSwitchCell(s.qoinAccrualEnabled, has(s, 'qoinAccrualEnabled')),
            brand: parseRateCell(b.qoinAccrualRate, has(b, 'qoinAccrualRate')), brandSwitch: parseSwitchCell(b.qoinAccrualEnabled, has(b, 'qoinAccrualEnabled')), global: cfg ? cfg.rate : { kind: 'absent', value: null }, hasBrand: true });
          return `<tr><td><strong>${esc(`${b.name || ''} ${s.name || ''}`.trim())}</strong></td><td class="a-ell" title="${esc(s.address || '')}">${esc(s.address || '-')}</td><td>${docBadge(s)}</td><td class="a-num">${esc(qoinRateText(eff).text)}</td>
            <td><a href="#/b/stores/${encodeURIComponent(s.id)}/price">가격·메뉴 관리 →</a></td></tr>`;
        })) + `<div class="a-total">총 ${rows.length}곳</div>`),
    });
    $('#refresh').onclick = () => loader.run(true);
    loader.run(false);
  });
}

/* ============================================================================
   BR13 산하 매장 상세 — 탭 ① 가격 오버라이드 · 탭 ② 점포 한정 메뉴
   ========================================================================== */
function viewStoreDetail(alive, sid, tab) {
  const v = $('#view');
  v.innerHTML = detailSkeleton('#/b/stores', '산하 매장 목록');
  withBrand(alive, v, async (b, body) => {
    let s;
    try { s = await getStoreFresh(sid); } catch (e) {
      if (!alive()) return;
      body.innerHTML = `<div class="a-crumbs"><a href="#/b/stores">← 산하 매장 목록</a></div>${errorBlock(e)}`; $('[data-retry]', body).onclick = () => viewStoreDetail(alive, sid, tab); onReadFail(e, body); return;
    }
    if (!alive()) return;
    if (!s || s.brandId !== b.id) { body.innerHTML = `<div class="a-crumbs"><a href="#/b/stores">← 산하 매장 목록</a></div>${emptyBlock('찾을 수 없는 매장이에요', '', '<br><a class="a-link" href="#/b/stores">목록으로</a>')}`; return; }
    const sname = `${b.name || ''} ${s.name || ''}`.trim();
    body.innerHTML = `<div class="a-crumbs"><a href="#/b/stores">← 산하 매장 목록</a></div>
      <div class="a-head"><h1 tabindex="-1">${esc(sname)} ${docBadge(s)}<span class="a-chip">매장 정보는 읽기 전용</span></h1></div>
      ${tabBar([{ key: 'price', href: `#/b/stores/${encodeURIComponent(sid)}/price`, label: '가격 오버라이드' }, { key: 'menus', href: `#/b/stores/${encodeURIComponent(sid)}/menus`, label: '점포 한정 메뉴' }], tab)}
      <div id="tab-box" style="margin-top:16px"></div>`;
    if (tab === 'price') priceTab(alive, b, s, sname); else storeMenusTab(alive, b, s, sname);
  }, { withBanner: false });
}

function priceTab(alive, b, s, sname) {
  const box = $('#tab-box');
  box.innerHTML = `${banner('', '', '이 매장에서만 쓸 가격을 제출하면 관리자 검토 후 고객에게 반영돼요.')}<div id="po-box"></div>`;
  const load = async () => {
    $('#po-box').innerHTML = skelRows(5, 6);
    try {
      // 두 조회가 모두 끝나야 행을 그린다 — 가격을 모른 채 "마스터 가격 사용" 으로 보이면 안 된다.
      const [masters, ovs] = await Promise.all([listMasterMenus(b.id), listStoreOverrides(s.id)]);
      if (!alive()) return;
      const ovMap = new Map(ovs.map((o) => [o.id, o]));
      const ms = masters.filter((m) => m.status === 'approved'); // 승인된 마스터 메뉴만 (앱 동일)
      if (ms.length === 0) { $('#po-box').innerHTML = emptyBlock('마스터 메뉴가 없어요', '마스터 메뉴를 먼저 등록하고 승인을 받아주세요.'); return; }
      $('#po-box').innerHTML = tableHtml(['메뉴', '마스터 가격', '이 매장 가격', '제외', '상태', ''], ms.map((m) => {
        const o = ovMap.get(m.id) || null;
        return `<tr data-mid="${esc(m.id)}"><td><strong>${esc(m.name || '(이름 없음)')}</strong>${o && normalizeStatus(o.status) === 'rejected' ? `<div class="a-cap">반려 사유: ${esc(o.rejectedReason || '사유가 기록되지 않았어요')}</div>` : ''}</td>
          <td class="a-num">마스터 가격: ${esc(fmtWon(m.basePrice))}</td>
          <td><label class="a-sr" for="po-p-${esc(m.id)}">${esc(m.name)} 이 매장 가격</label><input class="a-input a-num" id="po-p-${esc(m.id)}" data-p value="${o && typeof o.priceOverride === 'number' ? o.priceOverride : ''}" inputmode="numeric" placeholder="마스터 가격 사용"></td>
          <td><label class="a-check"><input type="checkbox" data-x ${o && o.excluded === true ? 'checked' : ''}> 이 매장에서 제외</label></td>
          <td>${o ? docBadge(o) : '<span class="a-badge">미설정</span>'}</td><td><button type="button" class="a-btn sm" data-submit="${esc(m.id)}">검토 요청…</button></td></tr>`;
      }));
      const stamp = $('#stamp'); void stamp;
      $$('[data-submit]', $('#po-box')).forEach((bt) => { bt.onclick = () => submitRow(ms.find((m) => m.id === bt.dataset.submit), ovMap.get(bt.dataset.submit) || null, bt); });
    } catch (e) {
      console.error('[brand] 오버라이드 조회 실패', e?.code || e);
      if (!alive()) return;
      $('#po-box').innerHTML = errorBlock(e, 'data-retry', { title: '불러오지 못했어요', desc: '잠시 후 다시 시도해주세요.' }); $('[data-retry]', $('#po-box')).onclick = load; onReadFail(e, $('#po-box'));
    }
  };
  const submitRow = (m, o0, btn) => {
    const tr = $$('tr[data-mid]', $('#po-box')).find((x) => x.dataset.mid === m.id);
    const pin = $('[data-p]', tr).value; const excluded = $('[data-x]', tr).checked;
    const p = parsePriceInput(pin, { required: false });
    if (!p.ok) { toast(`${m.name}: ${p.error}`); $('[data-p]', tr).focus(); return; }
    let cur = null; let master = null;
    openDialog({
      title: '가격 오버라이드 검토 요청', trigger: btn, confirmLabel: '검토 요청 보내기', busyLabel: '제출 중…', bodyHtml: '',
      onOpen: async (api) => {
        api.setBody('<div class="a-cap" role="status"><span class="a-spin"></span> 현재 상태 확인 중…</div>'); api.setConfirmEnabled(false);
        try {
          const r = await readOverrideAndMaster(s.id, b.id, m.id); cur = r.override; master = r.master;
          if (!master) throw Object.assign(new Error('nf'), { code: 'not-found' });
          const before = appliedOverride(master.basePrice, cur);
          const after = appliedOverride(master.basePrice, { status: 'pending' }); // 재제출 즉시 pending → 마스터 기준가 (U6)
          const rows = [['가격', cur && typeof cur.priceOverride === 'number' ? fmtWon(cur.priceOverride) : '마스터 가격 사용', p.value === null ? '마스터 가격 사용' : fmtWon(p.value)]];
          if ((cur?.excluded === true) !== excluded) rows.push(['이 매장에서 제외', cur?.excluded === true ? '제외' : '판매', excluded ? '제외' : '판매']);
          const effective = overrideIsApprovedWithEffect(cur);
          let u6 = banner('', '', '제출하면 관리자 검토 후 고객에게 반영돼요. 승인 전에는 이 항목이 「대기」 로 표시돼요.');
          if (effective) {
            const worse = !before.hidden && after.price > before.price; // 고객이 더 비싸게 산다
            u6 = `${banner(worse || before.hidden ? 'warn' : '', '', '재제출하면 관리자 승인 전까지 기준 가격으로 판매됩니다. 지금 적용 중인 가격은 유지되지 않습니다.')}
              <div class="a-u6"><div><span class="a-cap">현재 적용가</span><strong class="a-num">${before.hidden ? '판매 안 함 (제외)' : esc(fmtWon(before.price))}</strong></div><span aria-hidden="true">→</span>
              <div><span class="a-cap">재제출 중 적용가</span><strong class="a-num">${esc(fmtWon(after.price))}</strong></div></div>
              ${worse ? banner('warn', '주의', '가격이 올라가요. 그 사이 고객은 더 비싸게 사게 돼요.') : ''}
              ${before.hidden ? banner('warn', '', '재제출하면 관리자 승인 전까지 이 메뉴가 고객에게 다시 보입니다.') : ''}`;
          }
          api.setBody(`${targetBlock(`${sname} · ${master.name}`)}<div class="a-sub-h">바꾸는 내용</div>${changeListHtml(rows)}${u6}`);
          api.setConfirmEnabled(true);
        } catch (e) { api.setBody(''); api.showMsg(banner('error', '', '현재 상태를 확인하지 못해 제출할 수 없어요')); onReadFail(e); }
      },
      onConfirm: async () => { await submitPriceOverride(s.id, b.id, m.id, { priceOverride: p.value, excluded }); toast('검토 요청을 보냈어요'); await load(); },
      onError: (e, api) => { const t = saveErrorText(e); api.showMsg(banner('error', '실패', t.text)); if (t.permission) hooks.recheckRole(); },
    });
    void o0;
  };
  const stampEl = $('#refresh'); if (stampEl) stampEl.onclick = load;
  load();
}
/** 승인 상태라 지금 고객에게 효력이 있는 오버라이드인가 (가격이 있거나 제외). */
function overrideIsApprovedWithEffect(o) {
  if (!o) return false;
  const approved = typeof o.status === 'string' ? (o.status !== 'pending' && o.status !== 'rejected') : false;
  return approved && (typeof o.priceOverride === 'number' || o.excluded === true);
}

function storeMenusTab(alive, b, s, sname) {
  const box = $('#tab-box');
  box.innerHTML = `${banner('', '', '이 매장에서만 파는 메뉴예요. 제출하면 관리자 검토 후 고객에게 반영돼요.')}<div class="a-toolbar"><span style="margin-left:auto"></span><a class="a-btn primary" href="#/b/stores/${encodeURIComponent(s.id)}/menus/new">메뉴 추가</a></div><div id="sm-box"></div>`;
  const load = async () => {
    $('#sm-box').innerHTML = skelRows(6, 5);
    try {
      const rows = (await listStoreMenus(s.id)).filter((m) => m.scope === 'store');
      if (!alive()) return;
      $('#sm-box').innerHTML = rows.length === 0 ? emptyBlock('등록한 점포 한정 메뉴가 없어요', '', `<br><a class="a-btn primary" href="#/b/stores/${encodeURIComponent(s.id)}/menus/new">메뉴 추가</a>`)
        : tableHtml(['메뉴', '가격', '상태', '노출', ''], rows.map((m) => `<tr><td><div class="a-name">${thumb(m.imageUrl, m.name)}<strong>${esc(m.name || '(이름 없음)')}</strong></div></td><td class="a-num">${esc(typeof m.basePrice === 'number' ? m.basePrice.toLocaleString('ko-KR') + '원' : '-')}</td><td>${docBadge(m)}</td><td>${m.visible === false ? '꺼짐' : '켜짐'}</td>
          <td class="a-actions"><a href="#/b/stores/${encodeURIComponent(s.id)}/menus/${encodeURIComponent(m.id)}/core">핵심 수정</a> <a href="#/b/stores/${encodeURIComponent(s.id)}/menus/${encodeURIComponent(m.id)}/ops">운영 수정</a> <button type="button" class="a-link" data-del="${esc(m.id)}">삭제…</button></td></tr>`));
      $$('[data-del]', $('#sm-box')).forEach((x) => { x.onclick = () => { const m = rows.find((r) => r.id === x.dataset.del); openDialog({ title: '메뉴를 삭제할까요?', trigger: x, confirmLabel: '삭제', confirmClass: 'reject-confirm', bodyHtml: `${targetBlock(`${m.name} · ${sname}`)}<p class="a-ask">삭제된 메뉴는 복구할 수 없어요.</p>`, onConfirm: async () => { await deleteStoreMenu(s.id, m.id); await load(); }, onError: (e, api) => api.showMsg(banner('error', '실패', '삭제에 실패했어요')) }); }; });
    } catch (e) { console.error('[brand] 점포 한정 메뉴 조회 실패', e?.code || e); if (!alive()) return; $('#sm-box').innerHTML = errorBlock(e); $('[data-retry]', $('#sm-box')).onclick = load; onReadFail(e, $('#sm-box')); }
  };
  load();
}

/* BR14 점포 한정 메뉴 폼 */
function viewStoreMenuForm(alive, sid, mode, mid) {
  const v = $('#view');
  const back = `#/b/stores/${encodeURIComponent(sid)}/menus`;
  v.innerHTML = `<div class="a-crumbs"><a href="${back}">← 점포 한정 메뉴</a></div><div class="a-head"><h1 tabindex="-1">${mode === 'create' ? '점포 한정 메뉴 등록' : mode === 'core' ? '점포 한정 메뉴 핵심 수정' : '점포 한정 메뉴 운영 수정'}<span class="a-chip a-chip-strong">${mode === 'ops' ? '저장 즉시 반영' : '재승인 필요'}</span></h1></div><div style="height:16px"></div><div id="br-box"></div>`;
  withBrand(alive, $('#br-box'), async (b, body) => {
    body.innerHTML = '<div id="mf-box"></div>';
    try {
      const s = await getStoreFresh(sid);
      if (!alive()) return;
      if (!s || s.brandId !== b.id) { $('#mf-box').innerHTML = emptyBlock('찾을 수 없는 매장이에요', '', `<br><a class="a-link" href="#/b/stores">목록으로</a>`); return; }
      const sname = `${b.name || ''} ${s.name || ''}`.trim();
      const [catalog, menus] = await Promise.all([brandCatalog(), mid ? listStoreMenus(sid) : Promise.resolve([])]);
      if (!alive()) return;
      const src = mid ? menus.find((m) => m.id === mid) : null;
      if (mid && !src) { $('#mf-box').innerHTML = emptyBlock('찾을 수 없는 메뉴예요', '', `<br><a class="a-link" href="${back}">목록으로</a>`); return; }
      menuForm({
        box: $('#mf-box'), alive, initial: src, isCreate: mode === 'create', alwaysSavable: mode === 'create', targetName: `${src?.name || '새 메뉴'} · ${sname}`, catalog,
        sections: mode === 'create' ? { image: true, core: true, ops: true, requireImage: true } : mode === 'core' ? { core: true } : { ops: true, soldOut: true, image: true, disabled: true },
        saveLabel: mode === 'create' ? '저장 (검토 요청)' : mode === 'core' ? '검토 요청 보내기…' : '저장',
        loadDisableGroups: () => fetchOptionGroups(src?.optionGroupRefs || [], { brandId: b.id, storeId: sid }),
        onSubmit: (c) => {
          const run = () => c.runSave(async () => {
            if (mode === 'core') { const ch = { ...c.changes() }; delete ch.imageUrl; await submitStoreOnlyMenuCore(sid, mid, ch); return; }
            const imageUrl = await c.uploadIfNeeded(storagePaths.storeMenu(sid, mode === 'create' ? null : mid));
            if (mode === 'create') await createStoreOnlyMenu(sid, b.id, { ...c.values(), imageUrl });
            else { const ch = { ...c.changes() }; if ('imageUrl' in ch) ch.imageUrl = imageUrl; await updateStoreMenuOperation(sid, mid, ch, 'brand'); }
          }).then((ok) => { if (ok) { registerDirty(() => false); S.flash = mode === 'ops' ? '즉시 반영되었습니다' : '검토 요청을 보냈어요'; hooks.go(back); } });
          if (mode !== 'core') return run();
          openDialog({ title: '핵심 정보 변경 검토 요청', confirmLabel: '검토 요청 보내기', busyLabel: '보내는 중…',
            bodyHtml: `${targetBlock(`${src.name} · ${sname}`)}${banner('', '', '이름 · 가격 등을 바꾸면 관리자 재승인 대상이 돼요. 승인 상태가 「수정 대기」 로 바뀌어요.')}`,
            onConfirm: async () => { const ch = { ...c.changes() }; delete ch.imageUrl; await submitStoreOnlyMenuCore(sid, mid, ch); registerDirty(() => false); S.flash = '검토 요청을 보냈어요'; hooks.go(back); },
            onError: (e, api) => { const t = saveErrorText(e); api.showMsg(banner('error', '실패', t.text)); if (t.permission) hooks.recheckRole(); } });
          return undefined;
        },
      });
    } catch (e) { console.error('[brand] 점포 한정 메뉴 폼 로드 실패', e?.code || e); if (!alive()) return; $('#mf-box').innerHTML = errorBlock(e); $('[data-retry]', $('#mf-box')).onclick = () => viewStoreMenuForm(alive, sid, mode, mid); onReadFail(e, $('#mf-box')); }
  });
}

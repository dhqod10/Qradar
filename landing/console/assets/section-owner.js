/* ============================================================================
   owner 섹션 — 내 매장 · 매장 정보 수정(운영/핵심 2폼) · 매출 · 받은 평가 · 메뉴 관리 · 서브 카테고리 · 옵션 그룹.

   ▸ 주문 접수/제조/완료/환불 거절 화면은 만들지 않는다 (spec N1 — 카운터 업무는 손에 들린 앱이 맞다).
   ▸ 매장 정보 수정은 라우트·DOM·payload 빌더가 모두 별개인 두 폼이다 (Q3, DV-6).
       #/o/store/ops   운영 정보  → 즉시 반영, status 회귀 없음, 확인 모달 없음
       #/o/store/core  핵심 정보  → status 'pending' 회귀, 확인 모달(서버 재읽기 3갈래)
   ▸ 🔴 approvedAt 을 건드리는 UI 는 없다. 재제출 payload 는 console-data.js submitStoreCore 의 트랜잭션 안에서
       서버 status === 'rejected' 로 확인된 경우에만 만들어진다 (DV-5).

   [보안] 화면 숨김·탭 미노출·해시 정규화는 편의다. 이 섹션의 모든 읽기/쓰기는 Rules 가 다시 판정한다
   (stores read :328 · update :363-366, orders read :235-238, menuOverrides :515-531).
   ========================================================================== */

import {
  listMyStores, getStoreFresh, getBrand, getQoinConfig, listStoreOrdersInPeriod, listStoreReviews, listMainCategories, listMasterOptionGroups, listAll, listStoreMenus, listStoreOverrides, listMasterMenus, saveStoreOperation, countInflightOrders, submitStoreCore, createPersonalMenu, updatePersonalMenu, updateStoreMenuOperation, deleteStoreMenu, setOverrideSoldOut, setOverrideOptionDisable, fetchOptionGroups, uploadImage, storagePaths,
} from './console-data.js';
import {
  esc, fmtShortDateTime, fmtClock, fmtWon, fmtDateOnly, parseDateInput, safeUrl, LIMITS, RE_BIZNO, storeStatusOf, storeSellClass, normalizeStatus, STATUS_LABEL, ownerScoreView, parseRateCell, parseSwitchCell, resolveEffectiveQoinRate, qoinRateText, aggregateSales, salesPeriod, prevPeriod, nextPeriod, canGoNext, canGoPrevious, periodLabel, ORDER_STATUS, itemsSummary, checkImageFile, sameValue, appliedOverride, saveErrorText, classifyError,
} from './console-format.js';
import {
  S, hooks, $, $$, skel, banner, emptyBlock, errorBlock, thumb, kv, tableHtml, skelRows, headHtml, makeLoader, openDialog, field, setFieldError, switchHtml, wireSwitch, saveBarHtml, setSaveBar, registerDirty, changeListHtml, targetBlock, chipGroup, onReadFail, toast, flashOnce, formBanner,
} from './console-ui.js';
import {
  menuForm, catalogView, optionDisableDialog,
} from './console-forms.js';

export const meta = { role: 'owner', defaultHash: '#/o/store' };

/* ── 매장 컨텍스트 (섹션 전체가 공유) ────────────────────────────────────────── */
const O = { state: 'loading', store: null, err: null, multi: false, brand: null, flight: null, gen: 0 };

/** 매장 로드(단일 비행). 결과: state = 'ready' | 'empty' | 'error'. */
function ensureStore(force = false) {
  if (!force && O.state !== 'loading' && O.state !== 'error') return Promise.resolve(O);
  if (O.flight) return O.flight;
  O.state = 'loading'; O.err = null;
  const gen = O.gen;
  O.flight = (async () => {
    try {
      const list = await listMyStores(S.shell.uid);
      if (gen !== O.gen) return O;
      O.multi = list.length > 1;
      O.store = list[0] || null;
      O.state = O.store ? 'ready' : 'empty';
    } catch (e) {
      console.error('[owner] 매장 조회 실패', e?.code || e);
      if (gen !== O.gen) return O;
      O.state = 'error'; O.err = e; onReadFail(e);
    }
    O.flight = null;
    hooks.renderContext(); hooks.renderNav();
    return O;
  })();
  return O.flight;
}
const invalidateStore = () => { O.state = 'loading'; O.store = null; return ensureStore(true); };

export function start() { O.gen++; O.state = 'loading'; O.store = null; O.err = null; O.flight = null; O.multi = false; ensureStore(true); }
export function stop() { O.gen++; O.flight = null; }

const isPersonal = () => !!O.store && !O.store.brandId;
const isFranchise = () => !!O.store && !!O.store.brandId;

export function navGroups() {
  const base = [{ group: '매장', items: [{ key: 'store', href: '#/o/store', label: '내 매장' }] }];
  if (O.state === 'empty' || O.state === 'error') return base;
  const menus = [{ key: 'menus', href: '#/o/menus', label: '메뉴 관리' }];
  if (O.state === 'ready' && isPersonal()) { // 개인 매장 전용 2항목은 유형이 확정된 뒤에만 (마지막이라 위쪽이 밀리지 않는다)
    menus.push({ key: 'subcats', href: '#/o/subcats', label: '서브 카테고리' }, { key: 'options', href: '#/o/options', label: '옵션 그룹' });
  }
  return [...base,
    { group: '운영', items: [{ key: 'sales', href: '#/o/sales', label: '매출' }, { key: 'reviews', href: '#/o/reviews', label: '받은 평가' }] },
    { group: '메뉴', items: menus }];
}

export function contextHtml() {
  if (O.state === 'loading') return `<div class="a-ctx">${skel('120px', 16)}</div>`;
  if (O.state !== 'ready') return '';
  return `<div class="a-ctx"><div class="a-ctx-name" title="${esc(O.store.name)}">${esc(O.store.name || '(이름 없음)')}</div>${storeBadge(O.store)}</div>`;
}

export function match(parts, alive) {
  if (parts[0] !== 'o') return null;
  const [, a, b] = parts;
  if (a === 'store' && !b) return { key: 'store', run: () => viewStore(alive) };
  if (a === 'store' && b === 'ops') return { key: 'store', run: () => viewOps(alive) };
  if (a === 'store' && b === 'core') return { key: 'store', run: () => viewCore(alive) };
  if (a === 'sales') return { key: 'sales', run: () => viewSales(alive) };
  if (a === 'reviews') return { key: 'reviews', run: () => viewReviews(alive) };
  if (a === 'menus' && !b) return { key: 'menus', run: () => viewMenus(alive) };
  if (a === 'menus' && b === 'new') return { key: 'menus', run: () => viewMenuForm(alive, null) };
  if (a === 'menus' && b) return { key: 'menus', run: () => viewMenuForm(alive, b) };
  if (a === 'subcats') return { key: 'subcats', run: () => viewCatalog(alive, 'sub') };
  if (a === 'options') return { key: 'options', run: () => viewCatalog(alive, 'opt') };
  return null;
}

/* ── 공통 조각 ───────────────────────────────────────────────────────────── */
const storeBadge = (s) => {
  const st = storeStatusOf(s);
  const n = normalizeStatus(st);
  if (!n) return '<span class="a-badge">알 수 없음</span>';
  return `<span class="a-badge ${n}">${n === 'pending' && s.approvedAt ? '수정 대기' : STATUS_LABEL[n]}</span>`;
};

/** GT4 — 매장 상태 배너 (앱 SalesStoreStatusBanner 문구). 판매 가능 여부를 단정하지 않는다. */
function statusBannerHtml(s) {
  const st = storeStatusOf(s);
  if (st === 'pending' && !s.approvedAt) return banner('', '매장 승인을 기다리고 있어요', '승인 완료 후 주문이 접수됩니다');
  if (st === 'pending') return banner('', '수정한 내용을 검토하고 있어요', '검토 중에도 기존 주문 매출은 그대로 확인할 수 있어요');
  if (st === 'rejected') return banner('warn', '매장 검토가 반려되었어요', '내 매장에서 사유를 확인하고 다시 제출해 주세요', '<div class="a-b-actions"><a class="a-btn sm" href="#/o/store">내 매장으로</a></div>');
  return '';
}

/**
 * 매장 로드 게이트: 로딩 스켈레톤 / 오류 / GT3(매장 없음) 를 처리하고 준비되면 render(store) 를 부른다.
 * @param {boolean} [withBanner=true] 상태 배너를 헤드 아래에 둔다
 */
async function withStore(alive, box, render, { withBanner = true } = {}) {
  box.innerHTML = `<div class="a-card" aria-busy="true"><span class="a-sr">불러오는 중</span>${skel('50%', 18)}<div style="height:14px"></div>${skel('90%', 14)}<div style="height:8px"></div>${skel('70%', 14)}</div>`;
  const r = await ensureStore();
  if (!alive()) return;
  if (r.state === 'error') {
    box.innerHTML = errorBlock(r.err, 'data-retry', { title: '매장 정보를 불러오지 못했어요', desc: '잠시 후 다시 시도해주세요.' });
    $('[data-retry]', box).onclick = async () => { await invalidateStore(); if (alive()) withStore(alive, box, render, { withBanner }); };
    onReadFail(r.err, box);
    return;
  }
  if (r.state === 'empty') {
    box.innerHTML = `<div class="a-gate-card a-in-main"><h2>등록된 매장이 없어요</h2><p>매장을 등록하면 매출이 집계됩니다.</p>
      <p class="a-cap">매장 등록은 앱에서 해주세요. 웹에서는 등록할 수 없어요.</p><button type="button" class="a-btn" id="gt3-retry">다시 확인</button></div>`;
    $('#gt3-retry').onclick = async () => { await invalidateStore(); if (alive()) withStore(alive, box, render, { withBanner }); };
    return;
  }
  const multi = r.multi ? banner('', '', '매장이 여러 개예요. 콘솔은 첫 번째 매장만 보여줘요.') : '';
  box.innerHTML = `${multi}${withBanner ? statusBannerHtml(r.store) : ''}<div id="owner-body"></div>`;
  render(r.store, $('#owner-body', box));
}

const catLabelMap = (cats) => new Map(cats.map((c) => [c.id, c.label]));

/* ============================================================================
   OW1 내 매장
   ========================================================================== */
function viewStore(alive) {
  const v = $('#view');
  const flash = flashOnce();
  v.innerHTML = `${headHtml({ title: '내 매장' })}<div id="notice"></div><div id="ow-box"></div>`;
  const stamp = () => { const st = $('#stamp'); if (st && alive()) st.textContent = `마지막 갱신 ${fmtClock()}`; };
  $('#refresh').onclick = async () => { await invalidateStore(); if (alive()) viewStore(alive); };
  if (flash) toast(flash);
  withStore(alive, $('#ow-box'), (s, body) => {
    stamp();
    const franchise = !!s.brandId;
    const st = storeStatusOf(s);
    const score = ownerScoreView(s);
    const panel = franchise
      ? `${banner('', '', '매장 핵심 정보는 브랜드 본사가 관리해요.')}${st === 'rejected' ? `<p class="a-cap">재제출은 브랜드 본사에서 진행됩니다.</p>` : ''}
         <a class="a-btn primary block lg" href="#/o/store/ops">운영 정보 수정</a><p class="a-note">전화번호·영업시간·휴무·소개·사진. 저장하면 바로 반영돼요.</p>`
      : `${st === 'rejected' ? `${banner('warn', '검토가 반려되었어요', s.rejectedReason ? String(s.rejectedReason) : '사유가 기록되지 않았어요')}
           <a class="a-btn primary block lg" href="#/o/store/core">재제출하기…</a><a class="a-btn block lg" href="#/o/store/ops" style="margin-top:8px">운영 정보 수정</a>`
        : `${st === 'pending' && s.approvedAt ? banner('', '', '수정한 내용을 검토하고 있어요') : st === 'pending' ? banner('', '', '검토 요청이 접수되었어요. 검토 완료까지 잠시 기다려주세요.') : ''}
           <a class="a-btn primary block lg" href="#/o/store/ops">운영 정보 수정</a><p class="a-note" style="border:0;padding:4px 0 12px">전화번호·영업시간·휴무·소개·사진. 저장하면 바로 반영돼요.</p>
           <a class="a-btn block lg" href="#/o/store/core">핵심 정보 수정…<span class="a-chip">재승인 필요</span></a>
           <p class="a-note" style="border:0;padding:8px 0 0">상호명·주소·사업자등록번호를 바꾸면 관리자 재승인 대상이 돼요.</p>`}`;
    body.innerHTML = `<div class="a-detail"><div class="a-detail-main">
        <div class="a-card"><h2>매장 정보</h2><div id="ow-imgs"></div><div id="ow-info"></div></div>
        <div class="a-card"><h2>지표 <span class="a-chip">읽기</span></h2>
          ${kv([['등급', score.grade], ['평균 점수', score.average], ['리뷰 수', `${score.count}개`]])}
          <div style="margin-top:12px"><a href="#/o/reviews">받은 평가 보기 →</a></div>
          <div id="ow-qoin" style="margin-top:16px"></div></div>
        <p class="a-cap">${!franchise && st === 'approved' ? '매장 운영을 그만두려면 관리자에게 문의해 주세요.' : '매장을 삭제하거나 잘못 등록한 매장을 정리하려면 관리자에게 문의해 주세요.'}</p>
      </div><aside class="a-panel a-card"><h2>정보 수정</h2>${panel}</aside></div>`;
    const urls = (s.imageUrls && s.imageUrls.length ? s.imageUrls : (s.imageUrl ? [s.imageUrl] : [])).filter((u) => safeUrl(u));
    $('#ow-imgs').innerHTML = urls.length ? `<div class="a-imgs">${urls.map((u) => `<a href="${esc(safeUrl(u))}" target="_blank" rel="noopener noreferrer"><img src="${esc(safeUrl(u))}" alt="" referrerpolicy="no-referrer" loading="lazy"></a>`).join('')}</div>` : '';
    const hours = s.businessHours && s.businessHours.openTime ? `매일 ${s.businessHours.openTime} ~ ${s.businessHours.closeTime}` : '-';
    const closed = Array.isArray(s.closedDates) ? s.closedDates.map((d) => fmtDateOnly(d)).filter((x) => x !== '-') : [];
    $('#ow-info').innerHTML = kv([['매장 이름', s.name], ['주소', s.address], ['전화번호', s.phone || '전화번호 미입력'], ['영업시간', hours],
      ['임시 휴무', s.temporaryClosed === true ? '켜짐' : '꺼짐'], ['휴무 날짜', closed.length ? closed.join(', ') : '-'], ['소개', s.description], ['매장 안내', s.notice], ['메뉴 카테고리 노출', '불러오는 중…']]);
    if (franchise) {
      getBrand(s.brandId).then((b) => {
        if (!alive() || !b?.name) return; // 브랜드 이름 조회 실패/없음 → 매장 이름만 (가짜 이름 금지)
        const dd = $('#ow-info dd'); if (dd) dd.textContent = `${b.name} ${s.name}`;
      }).catch((e) => { console.error('[owner] 브랜드 이름 조회 실패', e?.code || e); });
    }
    // 카테고리 노출 요약 (독립 로드, 실패해도 나머지에 영향 없음)
    listMainCategories().then((cats) => {
      if (!alive()) return;
      const m = catLabelMap(cats); const ex = new Set(s.excludedMainCategories || []);
      const on = cats.filter((c) => c.active && !ex.has(c.id)).map((c) => c.label); const off = cats.filter((c) => c.active && ex.has(c.id)).map((c) => c.label);
      const dds = $$('#ow-info dd'); const last = dds[dds.length - 1];
      if (last) last.textContent = `${on.length ? `노출: ${on.join(', ')}` : '노출 중인 카테고리가 없어요'}${off.length ? ` / 숨김: ${off.join(', ')}` : ''}`;
      void m;
    }).catch(() => { const dds = $$('#ow-info dd'); const last = dds[dds.length - 1]; if (last) last.textContent = '불러오지 못했어요'; });
    loadQoinCard(s, alive);
  });
}

/** 적립률 (읽기 전용): 매장 → 브랜드 → 전역 3단 해석. 실패는 카드 안에서만. */
async function loadQoinCard(s, alive) {
  const box = $('#ow-qoin');
  if (!box) return;
  box.innerHTML = skel('50%', 16);
  try {
    const [cfg, brand] = await Promise.all([getQoinConfig(), s.brandId ? getBrand(s.brandId) : Promise.resolve(null)]);
    if (!alive()) return;
    const has = (o, k) => !!o && Object.prototype.hasOwnProperty.call(o, k);
    const eff = resolveEffectiveQoinRate({
      store: parseRateCell(s.qoinAccrualRate, has(s, 'qoinAccrualRate')), storeSwitch: parseSwitchCell(s.qoinAccrualEnabled, has(s, 'qoinAccrualEnabled')),
      brand: parseRateCell(brand?.qoinAccrualRate, has(brand, 'qoinAccrualRate')), brandSwitch: parseSwitchCell(brand?.qoinAccrualEnabled, has(brand, 'qoinAccrualEnabled')),
      global: cfg ? cfg.rate : { kind: 'absent', value: null }, hasBrand: !!s.brandId,
    });
    const t = qoinRateText(eff);
    box.innerHTML = `<div class="a-cap a-qdot">Qoin 적립률 <span class="a-chip">읽기</span></div><div class="a-qval a-num">${esc(t.text)}</div><div class="a-cap">${esc(t.sub)}</div>`;
  } catch (e) {
    console.error('[owner] 적립률 조회 실패', e?.code || e);
    if (alive()) { box.innerHTML = '<div class="a-cap">Qoin 적립률을 불러오지 못했어요</div>'; onReadFail(e); }
  }
}

/* ============================================================================
   OW2 운영 정보 수정 — 폼 ① (즉시 반영, status·승인 메타 무변경)
   payload: 바뀐 필드만 + updatedAt (DV-12). 핵심 입력칸이 이 폼에는 하나도 없다.
   ========================================================================== */
function viewOps(alive) {
  const v = $('#view');
  v.innerHTML = `<div class="a-crumbs"><a href="#/o/store">← 내 매장</a></div>
    <div class="a-head"><h1 tabindex="-1">운영 정보 수정<span class="a-chip a-chip-strong">저장 즉시 반영</span></h1></div><div style="height:16px"></div><div id="ow-box"></div>`;
  withStore(alive, $('#ow-box'), async (s, body) => {
    body.innerHTML = '<div id="ops-form"></div>';
    const franchise = !!s.brandId;
    let cats = null; let catsErr = false;
    const loadCats = async () => { try { cats = (await listMainCategories()).filter((c) => c.active); catsErr = false; } catch (e) { catsErr = true; onReadFail(e); } };
    await loadCats();
    if (!alive()) return;
    const hours0 = s.businessHours && s.businessHours.openTime ? { openTime: s.businessHours.openTime, closeTime: s.businessHours.closeTime, closedDays: s.businessHours.closedDays || [] } : null;
    const init = {
      phone: s.phone || '', description: s.description || '', notice: s.notice || '', open: hours0?.openTime || '', close: hours0?.closeTime || '',
      temporaryClosed: s.temporaryClosed === true, closedDates: (s.closedDates || []).map((d) => fmtDateOnly(d)).filter((x) => x !== '-'),
      excluded: [...(s.excludedMainCategories || [])], imageUrls: [...(s.imageUrls || (s.imageUrl ? [s.imageUrl] : []))],
    };
    let st = JSON.parse(JSON.stringify(init)); st.files = []; // files: [{file, url}]
    let saving = false;
    let inflightUnverified = false;   // 진행중 주문을 확인하지 못한 채 휴업을 켰는가 (저장 후 안내용)
    const activeIds = () => (cats || []).map((c) => c.id);
    const dormant = () => init.excluded.filter((c) => !activeIds().includes(c)); // 휴면 코드는 화면에 없어도 저장 시 보존
    const resolveExcluded = () => [...dormant(), ...activeIds().filter((id) => st.excluded.includes(id))];

    const changes = () => {
      const c = {};
      if (st.phone.trim() !== init.phone.trim()) c.phone = st.phone.trim();
      if (st.description.trim() !== init.description.trim()) c.description = st.description.trim();
      if (st.notice.trim() !== init.notice.trim()) c.notice = st.notice.trim();
      if (st.open !== init.open || st.close !== init.close) c.businessHours = st.open && st.close ? { openTime: st.open, closeTime: st.close, closedDays: hours0?.closedDays || [] } : null;
      if (st.temporaryClosed !== init.temporaryClosed) c.temporaryClosed = st.temporaryClosed;
      if (!sameValue([...st.closedDates].sort(), [...init.closedDates].sort())) c.closedDates = st.closedDates.map(parseDateInput).filter(Boolean);
      // 카테고리 섹션이 실패한 채로는 excludedMainCategories 를 보내지 않는다 (DV-12)
      if (!catsErr && cats && !sameValue([...resolveExcluded()].sort(), [...init.excluded].sort())) c.excludedMainCategories = resolveExcluded();
      if (st.files.length || !sameValue(st.imageUrls, init.imageUrls)) c.imageUrls = ['(변경)'];
      return c;
    };
    const count = () => Object.keys(changes()).length;
    const refresh = () => { setSaveBar(count()); registerDirty(() => !saving && count() > 0); };

    const render = () => {
      const imgs = [...st.imageUrls.map((u) => ({ u, own: true })), ...st.files.map((f) => ({ u: f.url, own: false }))];
      $('#ops-form').innerHTML = `<div id="form-banner"></div>
        ${banner('', '', '아래 정보는 저장 즉시 반영돼요.')}${franchise ? banner('', '', '매장 핵심 정보는 브랜드 본사가 관리해요.') : ''}
        <div class="a-card"><h2>연락처 · 소개</h2>
          ${field({ id: 'op-phone', label: '전화번호', value: st.phone, ph: '010-0000-0000', attrs: 'inputmode="tel"' })}
          ${field({ id: 'op-desc', label: '소개', value: st.description, multiline: true, rows: 3, max: LIMITS.storeDescription, counter: true, ph: '매장 분위기나 대표 메뉴를 간단히 소개해주세요' })}
          ${field({ id: 'op-notice', label: '매장 안내', value: st.notice, multiline: true, rows: 3, max: LIMITS.storeNotice, counter: true, ph: '주차 안내, 포인트 적립 등 안내 사항을 입력해주세요' })}</div>
        <div class="a-card"><h2>영업</h2>
          <div class="a-field"><span class="a-label">영업시간</span><div class="a-row"><label class="a-sr" for="op-open">영업 시작</label><input class="a-input a-time" type="time" id="op-open" value="${esc(st.open)}"> <span>~</span>
            <label class="a-sr" for="op-close">영업 종료</label><input class="a-input a-time" type="time" id="op-close" value="${esc(st.close)}"> <button type="button" class="a-link" id="op-hclear">영업시간 지우기</button></div>
            <div class="a-help">매일 같은 시간으로 저장돼요.</div><div class="a-field-err" id="op-hours-err" hidden></div></div>
          <div class="a-field a-sw-row"><span class="a-label">임시 휴무</span>${switchHtml('op-temp', st.temporaryClosed, '임시 휴무')}
            <div class="a-help">켜면 <strong>휴업 중에는 주문이 들어오지 않아요.</strong> 매장이 휴업 상태로 표시돼요.</div></div>
            <!-- temporary_closed_gate C 반영 (2026-10-29, 앱 세션 커밋 2066f5c).
                 canSellNow / storeGateReason 이 temporaryClosed 를 보고, paymentGate 가 서버에서
                 STORE_TEMPORARILY_CLOSED(failed-precondition) 로 거절한다. 그래서 위 문구가 참이다.

                 배포 전 확인 2가지 — 둘 다 완료
                   ① C 의 functions 재배포: 완료 확인 2026-10-30.
                      verifyTossPayment updateTime 2026-10-29T11:44:05Z (= KST 20:44:05),
                      커밋 2066f5c(KST 20:00:28) 보다 43분 뒤. 34개 함수 전체가 한 묶음으로 배포됐다.
                      재확인: firebase functions:list --project order-app-5957e --debug 의 updateTime
                   ② 진행중 주문 가드: 완료 2026-10-30 — guardInflight 참조. -->
            <!-- 진행중 주문 가드는 doSave → guardInflight 에 구현돼 있다 (2026-10-30). -->
          <div class="a-field"><span class="a-label">휴무 날짜</span><div class="a-row"><label class="a-sr" for="op-date">휴무 날짜 선택</label><input class="a-input a-time" type="date" id="op-date"> <button type="button" class="a-btn sm" id="op-dadd">추가</button></div>
            <div class="a-field-err" id="op-date-err" hidden></div>
            <div class="a-datechips">${st.closedDates.length ? st.closedDates.map((d) => `<span class="a-datechip">${esc(d)} <button type="button" class="a-link" data-drm="${esc(d)}" aria-label="${esc(d)} 휴무 삭제">삭제</button></span>`).join('') : '<span class="a-cap">추가된 휴무 날짜가 없어요.</span>'}</div></div></div>
        <div class="a-card"><h2>카테고리 노출 설정</h2>
          ${catsErr ? `<div class="a-err" role="alert"><strong>카테고리를 불러오지 못했어요</strong><button type="button" class="a-btn" id="op-catretry">다시 시도</button></div>`
          : (cats && cats.length === 0 ? '<div class="a-cap">설정할 수 있는 카테고리가 없어요</div>' : `<p class="a-cap">끄면 이 매장의 메뉴 탭과 검색에서 해당 카테고리 메뉴가 모두 사라져요. 나중에 브랜드가 메뉴를 추가해도 다시 켜기 전까지 보이지 않아요.</p>
          <div class="a-catsw">${(cats || []).map((c) => `<div class="a-sw-row">${esc(c.label)} ${switchHtml(`op-cat-${c.id}`, !st.excluded.includes(c.id), c.label, `data-cat="${esc(c.id)}"`)}</div>`).join('')}</div>`)}</div>
        <div class="a-card"><h2>사진</h2><div class="a-imggrid">${imgs.map((im, i) => `<div class="a-gimg">${i === 0 ? '<span class="a-chip">대표</span>' : ''}<img src="${esc(im.u)}" alt="" referrerpolicy="no-referrer"><button type="button" class="a-link" data-irm="${i}">제거</button></div>`).join('')}
          ${imgs.length < 5 ? '<div class="a-gadd"><input type="file" id="op-file" accept="image/*" class="a-sr"><label for="op-file" class="a-btn sm" id="op-filebtn" role="button" tabindex="0">+ 추가</label></div>' : ''}</div>
          <div class="a-help">최대 5MB, 첫 번째 사진이 대표예요${imgs.length === 0 ? '. 등록된 사진이 없어요' : ''}</div><div class="a-field-err" id="op-img-err" hidden></div></div>
        ${saveBarHtml({ targetName: s.name || '', saveLabel: '저장' })}`;
      wire(); refresh();
    };

    const wire = () => {
      const bindText = (id, key) => { const el = $(`#${id}`); el.addEventListener('input', () => { st[key] = el.value; const c = $(`#${id}-cnt`); if (c) c.textContent = `${[...el.value].length} / ${el.maxLength}`; refresh(); }); };
      bindText('op-phone', 'phone'); bindText('op-desc', 'description'); bindText('op-notice', 'notice');
      $('#op-open').oninput = (e) => { st.open = e.target.value; refresh(); };
      $('#op-close').oninput = (e) => { st.close = e.target.value; refresh(); };
      $('#op-hclear').onclick = () => { st.open = ''; st.close = ''; $('#op-open').value = ''; $('#op-close').value = ''; refresh(); };
      const t = $('#op-temp'); t.onclick = () => { st.temporaryClosed = t.getAttribute('aria-checked') !== 'true'; t.setAttribute('aria-checked', String(st.temporaryClosed)); t.querySelector('.a-sw-text').textContent = st.temporaryClosed ? '켜짐' : '꺼짐'; refresh(); };
      $('#op-dadd').onclick = () => {
        const val = $('#op-date').value; const err = $('#op-date-err');
        const d = parseDateInput(val);
        if (!d) { err.hidden = false; err.textContent = '날짜를 선택해주세요'; return; }
        if (st.closedDates.includes(val)) { err.hidden = false; err.textContent = '이미 추가된 날짜예요'; return; }
        err.hidden = true; st.closedDates = [...st.closedDates, val].sort(); render();
      };
      $$('[data-drm]').forEach((b) => { b.onclick = () => { st.closedDates = st.closedDates.filter((x) => x !== b.dataset.drm); render(); }; });
      $$('[data-cat]').forEach((sw) => { sw.onclick = () => {
        const on = sw.getAttribute('aria-checked') !== 'true';
        sw.setAttribute('aria-checked', String(on)); sw.querySelector('.a-sw-text').textContent = on ? '켜짐' : '꺼짐';
        st.excluded = on ? st.excluded.filter((x) => x !== sw.dataset.cat) : [...new Set([...st.excluded, sw.dataset.cat])]; refresh();
      }; });
      const cr = $('#op-catretry'); if (cr) cr.onclick = async () => { await loadCats(); if (alive()) render(); };
      const file = $('#op-file');
      if (file) {
        file.onchange = () => {
          const f = file.files[0]; const e = $('#op-img-err'); if (!f) return;
          const chk = checkImageFile(f);
          if (!chk.ok) { e.hidden = false; e.textContent = chk.error; file.value = ''; return; }
          e.hidden = true; st.files.push({ file: f, url: URL.createObjectURL(f) }); render();
        };
        $('#op-filebtn').onkeydown = (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); file.click(); } };
      }
      $$('[data-irm]').forEach((b) => { b.onclick = () => {
        const i = Number(b.dataset.irm);
        if (i < st.imageUrls.length) st.imageUrls.splice(i, 1); else { const f = st.files.splice(i - st.imageUrls.length, 1)[0]; if (f) URL.revokeObjectURL(f.url); }
        render();
      }; });
      $('#sb-reset').onclick = () => { st = JSON.parse(JSON.stringify(init)); st.files = []; render(); };
      $('#sb-save').onclick = () => doSave();
    };

    /**
     * 진행중 주문 가드. 통과하면 true, 막으면 false(스위치를 끄고 안내를 남긴다).
     * 조회 자체가 실패하면 **막지 않는다** — 읽기 실패로 휴업을 못 하게 하면
     * 정작 닫아야 할 때 못 닫는다. 대신 확인하지 못했다고 알린다.
     */
    const guardInflight = async () => {
      const btn = $('#sb-save'); const label = btn.textContent;
      btn.disabled = true; btn.innerHTML = '<span class="a-spin"></span>주문 확인 중…';
      let res = null; let failed = false;
      try { res = await countInflightOrders(s.id); } catch (e) {
        console.error('[owner] 진행중 주문 조회 실패', e?.code || e); failed = true;
      }
      if (!alive()) return false;
      btn.disabled = false; btn.textContent = label; refresh();

      if (failed) {
        // fail-open — 읽기 실패가 휴업을 막지는 않는다. 다만 확인하지 못했다는 사실은 저장 뒤에 알린다.
        // 여기서 formBanner 를 쓰면 바로 뒤 write() 의 formBanner('') 가 지워버려 점주가 보지 못한다.
        inflightUnverified = true;
        return true;
      }
      inflightUnverified = false;
      if (res.count === 0) { formBanner(''); return true; }

      // 되돌린다 — 저장하지 않으므로 화면도 끈 상태로 되돌려야 한다.
      st.temporaryClosed = false;
      const n = res.capped ? `${res.count}건 이상` : `${res.count}건`;
      openDialog({
        title: '아직 처리 중인 주문이 있어요',
        bodyHtml: `<p class="a-ask">접수·제조·수령 대기 중인 주문이 <strong>${esc(n)}</strong> 있어요.<br>`
          + '휴업을 켜면 <strong>새 주문만</strong> 막히고 이 주문들은 그대로 남아요.<br>'
          + '먼저 처리한 뒤에 휴업해주세요.</p>',
        noConfirm: true,          // 알림이지 선택이 아니다 — 버튼 하나만 둔다
        cancelLabel: '알겠어요',
      });
      render();
      return false;
    };

    const doSave = async () => {
      if (saving || count() === 0) return;
      const hours = (st.open && !st.close) || (!st.open && st.close);
      const he = $('#op-hours-err');
      if (hours) { he.hidden = false; he.textContent = '영업 시작과 종료를 모두 입력해주세요'; $('#op-open').focus(); return; }
      he.hidden = true;
      const c = changes();

      // 임시 휴업을 켜는 전환이면, 아직 끝나지 않은 주문이 있는지 먼저 본다.
      // 휴업은 신규 주문만 막는다 — 이미 받은 주문은 남으므로, 모르고 닫으면 그 손님이 못 받는다.
      // 앱(temporary_closed_gate)도 같은 확인을 한다. 권위가 아니라 사전 확인이다.
      if ('temporaryClosed' in c && st.temporaryClosed === true) {
        const ok = await guardInflight();
        if (!ok) return;
      }

      const allOff = !catsErr && cats && cats.length > 0 && cats.every((x) => st.excluded.includes(x.id));
      const wasAllOff = cats && cats.length > 0 && cats.every((x) => init.excluded.includes(x.id));
      if ('excludedMainCategories' in c && allOff && !wasAllOff) {
        openDialog({ title: '메뉴가 모두 숨겨져요', bodyHtml: '<p class="a-ask">모든 카테고리를 끄면 손님은 이 매장에서 메뉴를 볼 수 없어요. 그래도 저장할까요?</p>', cancelLabel: '돌아가기', confirmLabel: '저장', confirmClass: 'reject-confirm', onConfirm: async () => { await write(c); } });
        return;
      }
      await write(c);
    };

    const write = async (c) => {
      saving = true; formBanner(''); S.busy = true;
      const btn = $('#sb-save'); const label = btn.textContent;
      $$('input, textarea, button', $('#ops-form')).forEach((el) => { el.disabled = true; }); btn.innerHTML = '<span class="a-spin"></span>저장 중…';
      try {
        if ('imageUrls' in c) { // 새 파일 업로드 → 모두 성공해야 Firestore 쓰기 (일부 실패 시 쓰지 않는다)
          const urls = [...st.imageUrls]; let failed = 0;
          for (const f of st.files) {
            try { urls.push(await uploadImage(storagePaths.storeImage(s.ownerId || S.shell.uid), f.file)); } catch (e) { failed++; console.error('[owner] 사진 업로드 실패', e?.code || e); }
          }
          if (failed) throw Object.assign(new Error('upload'), { name: 'AdminError', code: 'validation', message: `사진 ${failed}장을 올리지 못했어요. 다시 시도해주세요.` });
          c.imageUrls = urls;
        }
        await saveStoreOperation(s.id, c, s.imageUrl || '');
      } catch (e) {
        console.error('[owner] 운영 정보 저장 실패', e?.code || e?.name || e);
        const t = e?.name === 'AdminError' && e.code === 'validation' ? { text: e.message } : saveErrorText(e);
        formBanner(banner('error', '실패', `${t.text}`));
        if (t.permission) hooks.recheckRole();
        saving = false; S.busy = false;
        $$('input, textarea, button', $('#ops-form')).forEach((el) => { el.disabled = false; }); const b2 = $('#sb-save'); if (b2) { b2.textContent = label; refresh(); }
        return;
      }
      saving = false; S.busy = false; registerDirty(() => false);
      S.flash = inflightUnverified
        ? '저장했어요. 진행중 주문이 있는지는 확인하지 못했으니 주문 내역을 확인해주세요'
        : '즉시 반영되었습니다';
      await invalidateStore();
      if (alive()) hooks.go('#/o/store');
    };
    render();
  });
}

/* ============================================================================
   OW3 핵심 정보 수정 / 재제출 — 폼 ② (status 'pending' 회귀, 개인 매장 전용)
   주소·위치는 읽기 전용이다 (좌표 변환에 웹에서 쓸 수 있는 키가 없다 — design U1).
   메뉴 카테고리(menuCategories)는 앱도 deprecated(Phase B)라 수정하지 않고 기존 값을 보존한다.
   ========================================================================== */
function viewCore(alive) {
  const v = $('#view');
  v.innerHTML = `<div class="a-crumbs"><a href="#/o/store">← 내 매장</a></div>
    <div class="a-head"><h1 tabindex="-1">핵심 정보 수정<span class="a-chip a-chip-strong">재승인 필요</span></h1></div><div style="height:16px"></div><div id="ow-box"></div>`;
  withStore(alive, $('#ow-box'), (s, body) => {
    if (s.brandId) { hooks.go('#/o/store'); return; } // 브랜드 가맹 매장은 핵심 폼이 없다 (앱과 동일)
    const cls = storeSellClass(s);
    const resub = storeStatusOf(s) === 'rejected';
    const init = { name: s.name || '', biz: s.businessRegistrationNumber || '' };
    let st = { ...init }; let saving = false;
    const notice = resub ? banner('warn', '검토가 반려되었어요', `${s.rejectedReason ? String(s.rejectedReason) : '사유가 기록되지 않았어요'} — 수정한 뒤 다시 제출해주세요`)
      : cls === 'B' ? banner('', '', '검토 요청이 접수되었어요. 수정하면 새 내용으로 검토해요.')
        : (storeStatusOf(s) === 'pending' ? banner('', '', '수정한 내용을 검토하고 있어요. 다시 수정하면 새 내용으로 검토해요.') : banner('', '', '아래 정보는 관리자 검토 후 반영돼요.'));
    const changes = () => { const c = {}; if (st.name.trim() !== init.name.trim()) c.name = st.name.trim(); if (st.biz.trim() !== init.biz.trim()) c.businessRegistrationNumber = st.biz.trim(); return c; };
    const label = resub ? '재제출하기…' : '검토 요청 보내기…';
    body.innerHTML = `<div id="form-banner"></div>${notice}<div class="a-card"><h2>핵심 정보</h2>
      ${field({ id: 'co-name', label: '매장명', required: true, value: st.name, max: LIMITS.storeName, counter: true })}
      <div class="a-field"><span class="a-label">주소</span><div class="a-readonly">${esc(s.address || '-')}</div><div class="a-help">주소와 위치(지도 좌표)는 앱에서 변경해요.</div></div>
      ${field({ id: 'co-biz', label: '사업자등록번호', value: st.biz, ph: '000-00-00000', attrs: 'inputmode="numeric"' })}</div>
      ${saveBarHtml({ targetName: s.name || '', saveLabel: label })}`;
    const refresh = () => { setSaveBar(Object.keys(changes()).length); registerDirty(() => !saving && Object.keys(changes()).length > 0); };
    $('#co-name').oninput = (e) => { st.name = e.target.value; $('#co-name-cnt').textContent = `${[...e.target.value].length} / ${LIMITS.storeName}`; refresh(); };
    $('#co-biz').oninput = (e) => { st.biz = e.target.value; refresh(); };
    $('#sb-reset').onclick = () => { st = { ...init }; $('#co-name').value = st.name; $('#co-biz').value = st.biz; refresh(); };
    $('#sb-save').onclick = () => {
      const c = changes(); let bad = false;
      if (!st.name.trim()) { setFieldError('co-name', '매장명을 입력해주세요'); bad = true; } else setFieldError('co-name', '');
      if ('businessRegistrationNumber' in c && c.businessRegistrationNumber !== '' && !RE_BIZNO.test(c.businessRegistrationNumber)) { setFieldError('co-biz', '000-00-00000 형식으로 입력해주세요'); bad = true; } else setFieldError('co-biz', '');
      if (bad || Object.keys(c).length === 0) { if (bad) (!st.name.trim() ? $('#co-name') : $('#co-biz')).focus(); return; }
      openCoreConfirm(s, c, init);
    };
    refresh();
  });
}

/** 확인 모달 — 먼저 서버에서 매장 문서를 다시 읽고, 읽은 상태로 3갈래 문구를 고른다 (낡은 화면 상태로 고르지 않는다). */
function openCoreConfirm(s0, changes, init) {
  let cls = 'X'; let fresh = null; let note = '';
  const rows = () => [
    ...('name' in changes ? [['매장명', fresh.name || '', changes.name]] : []),
    ...('businessRegistrationNumber' in changes ? [['사업자등록번호', fresh.businessRegistrationNumber || '', changes.businessRegistrationNumber]] : []),
  ];
  const guide = () => cls === 'A' ? banner('', '', '상호명 · 주소 · 사업자등록번호를 바꾸면 관리자 재승인 대상이 됩니다. 영업과 주문은 그대로 계속됩니다.')
    : cls === 'B' ? banner('', '', '아직 첫 승인을 기다리는 매장이에요. 수정한 내용으로 다시 검토해요. 승인되기 전에는 주문을 받을 수 없어요.')
      : cls === 'C' ? banner('', '', '재제출하면 관리자가 다시 검토해요. 승인되기 전에는 주문을 받을 수 없어요.')
        : banner('warn', '', '매장 상태를 알 수 없어서 안내를 드릴 수 없어요. 새로고침 후 다시 시도해주세요.');
  const draw = (api) => {
    api.setBody(`${targetBlock(fresh.name, `현재 상태: ${storeBadge(fresh)}`)}
      <div class="a-sub-h">바꾸는 내용</div>${changeListHtml(rows())}${note ? banner('', '', note) : ''}${guide()}`);
    api.setLabel(cls === 'C' ? '재제출하기' : '검토 요청 보내기');
    api.q('#dlg-title').textContent = cls === 'C' ? '매장 재제출' : '핵심 정보 변경 검토 요청';
    api.setConfirmEnabled(cls !== 'X');
  };
  const readFresh = async (api) => {
    api.setBody('<div class="a-cap" role="status"><span class="a-spin"></span> 상태 확인 중…</div>'); api.setConfirmEnabled(false);
    try {
      fresh = await getStoreFresh(s0.id);
      if (!fresh) throw Object.assign(new Error('nf'), { code: 'not-found' });
      fresh = { ...fresh, id: s0.id };
      cls = storeSellClass(fresh);
      if (fresh.brandId) throw Object.assign(new Error('brand'), { name: 'AdminError', code: 'validation', message: '브랜드 가맹 매장의 핵심 정보는 브랜드 본사가 관리해요.' });
      draw(api);
    } catch (e) {
      console.error('[owner] 매장 상태 재확인 실패', e?.code || e);
      api.setBody('');
      api.showMsg(banner('error', '', e?.code === 'validation' ? e.message : '매장 상태를 확인하지 못했어요'));
      if (e?.code !== 'validation') { const b = api.addFootButton('dlg-recheck', '다시 확인', () => { b.remove(); api.showMsg(''); readFresh(api); }); }
      onReadFail(e);
    }
  };
  openDialog({
    title: '핵심 정보 변경 검토 요청', bodyHtml: '', confirmLabel: '검토 요청 보내기', busyLabel: '보내는 중…',
    onOpen: (api) => { readFresh(api); },
    onConfirm: async (api) => {
      try {
        const done = await submitStoreCore(s0.id, changes, cls);
        S.flash = done === 'C' ? '재제출이 완료되었어요' : done === 'A' ? '검토 요청을 보냈어요. 검토 동안 매장은 계속 노출됩니다' : '검토 요청을 보냈어요';
      } catch (e) {
        if (classifyError(e).kind === 'state-changed') { // 모달을 연 뒤 상태가 바뀌었다 — 쓰지 않고 새 안내로 교체, 자동 진행 금지
          note = '매장 상태가 바뀌었어요. 안내를 확인하고 다시 눌러주세요.';
          await readFresh(api);
          return false;
        }
        throw e;
      }
      registerDirty(() => false);
      await invalidateStore();
      hooks.go('#/o/store');
    },
    onError: (e, api) => {
      const t = e?.name === 'AdminError' && e.code === 'validation' ? { text: e.message } : saveErrorText(e);
      api.showMsg(banner('error', '실패', t.text));
      if (t.permission) hooks.recheckRole();
    },
  });
}

/* ============================================================================
   OW4 매출 (읽기 전용) — 집계 정의는 앱 aggregateStoreSales 그대로
   ========================================================================== */
function viewSales(alive) {
  const v = $('#view');
  v.innerHTML = `${headHtml({ title: '매출', tag: '읽기' })}<div id="ow-box"></div>`;
  withStore(alive, $('#ow-box'), (s, body) => {
    let type = 'day'; let period = salesPeriod(type); let token = 0;
    body.innerHTML = `<p class="a-cap" style="margin:0 0 12px">주문 접수와 처리는 앱에서 해요. 이 화면은 조회 전용이에요.</p>
      <div class="a-toolbar"><div class="a-chips" role="radiogroup" aria-label="기간 단위">${[['day', '일'], ['week', '주'], ['month', '월']].map(([k, l]) => `<button type="button" class="a-fchip" role="radio" aria-checked="${k === type}" data-t="${k}">${l}</button>`).join('')}</div>
        <button type="button" class="a-btn sm" id="sp-prev">‹ 이전</button><strong class="a-num" id="sp-label"></strong><button type="button" class="a-btn sm" id="sp-next">다음 ›</button></div>
      <p class="a-cap">한국 시간(KST) 기준이에요. 주는 월요일에 시작해요.</p><div id="sales-notice"></div><div id="sales-box"></div>`;
    const ctrls = () => {
      $('#sp-label').textContent = periodLabel(period);
      const n = $('#sp-next'); n.disabled = !canGoNext(period); n.title = n.disabled ? '현재 기간이 마지막이에요' : '';
      const p = $('#sp-prev'); p.disabled = !canGoPrevious(period); p.title = p.disabled ? '최대 12개월 전까지 조회할 수 있어요' : '';
      $$('[data-t]').forEach((b) => b.setAttribute('aria-checked', String(b.dataset.t === type)));
    };
    const load = async () => {
      const my = ++token; ctrls();
      $('#sales-notice').innerHTML = '';
      $('#sales-box').innerHTML = `<div class="a-grid c3" aria-busy="true">${[0, 1, 2].map(() => `<div class="a-card">${skel('60%', 14)}<div style="height:10px"></div>${skel('80%', 28)}</div>`).join('')}</div>${skelRows(4, 6)}`;
      try {
        const r = await listStoreOrdersInPeriod(s.id, period); // 서버 강제 읽기 + where storeId==
        if (!alive() || my !== token) return;
        const a = aggregateSales(r.rows);
        const st = $('#stamp'); if (st) st.textContent = `마지막 조회 ${fmtClock()}`;
        $('#sales-notice').innerHTML = r.truncated ? banner('', '', '주문이 많아 최근 1,000건만 집계했어요') : '';
        const card = (t, val, sub) => `<div class="a-card a-stat"><div class="a-stat-title">${esc(t)}</div><div class="a-stat-num">${esc(val)}</div><div class="a-stat-sub">${esc(sub)}</div></div>`;
        const mini = (t, val) => `<div class="a-card"><div class="a-cap">${esc(t)}</div><div class="a-qval a-num" style="font-size:16px">${esc(val)}</div></div>`;
        $('#sales-box').innerHTML = `<div class="a-grid c3">${card('총 매출', fmtWon(a.netSales), '진행 중 포함')}${card('주문 건수', `${a.orderCount}건`, '')}${card('평균 객단가', fmtWon(a.averageOrderValue), '')}</div>
          <div class="a-grid c3" style="margin-top:16px">${mini('진행 중 포함', `${a.inProgressCount}건 · ${fmtWon(a.inProgressSales)}`)}${mini('환불 제외', `${a.refundedCount}건 · −${fmtWon(a.refundedAmount)}`)}${mini('취소 제외', `${a.cancelledCount}건`)}</div>
          <p class="a-cap">환불은 주문한 날의 매출에서 차감돼요</p>
          <div class="a-head" style="margin:24px 0 8px"><h2 class="a-h2" style="margin:0">주문 내역</h2><span class="a-cap">환불·취소 포함 ${r.rows.length}건</span></div>
          ${r.rows.length === 0 ? emptyBlock('이 기간에 주문이 없어요', '주문이 들어오면 매출에 반영됩니다')
            : tableHtml(['주문 시각', '주문 내용', '상태', '금액'], r.rows.map((o) => {
              const m = ORDER_STATUS[o.status];
              return `<tr><td class="a-num">${esc(fmtShortDateTime(o.createdAt))}</td><td class="a-ell" title="${esc(itemsSummary(o.items))}">${esc(itemsSummary(o.items))}</td>
                <td><span class="a-badge ${m ? m.cls : ''}">${esc(m ? m.label : String(o.status ?? '-'))}</span></td><td class="a-num">${esc(fmtWon(o.totalPrice))}</td></tr>`;
            }))}`;
      } catch (e) {
        console.error('[owner] 매출 조회 실패', e?.code || e);
        if (!alive() || my !== token) return;
        const k = classifyError(e).kind;
        $('#sales-box').innerHTML = errorBlock(e, 'data-retry', { title: '불러오는 데 실패했어요', desc: k === 'permission' ? '매출을 조회할 권한이 없어요' : k === 'offline' ? '네트워크 상태를 확인하고 다시 시도해 주세요' : '잠시 후 다시 시도해주세요.' }); // 0원/0건으로 채우지 않는다
        $('[data-retry]', $('#sales-box')).onclick = load; onReadFail(e, $('#sales-box'));
      }
    };
    $$('[data-t]').forEach((b) => { b.onclick = () => { type = b.dataset.t; period = salesPeriod(type); load(); }; });
    $('#sp-prev').onclick = () => { period = prevPeriod(period); load(); };
    $('#sp-next').onclick = () => { period = nextPeriod(period); load(); };
    $('#refresh').onclick = load;
    load();
  });
}

/* ============================================================================
   OW5 받은 평가 (읽기 전용) — 답글·신고 없음
   열: reviews 의 실제 필드(createdAt · grade · comment). score 는 내부 점수라 노출하지 않는다 (grade_thresholds.dart).
   ========================================================================== */
function viewReviews(alive) {
  const v = $('#view');
  v.innerHTML = `${headHtml({ title: '받은 평가', tag: '읽기' })}<div id="ow-box"></div>`;
  withStore(alive, $('#ow-box'), (s, body) => {
    const sc = ownerScoreView(s);
    body.innerHTML = `<p class="a-cap" style="margin:0 0 12px">평균 점수 ${esc(sc.average)} · 리뷰 ${esc(sc.count)}개 · ${esc(sc.grade)}</p><div id="rv-box"></div>`;
    const loader = makeLoader({
      alive, box: $('#rv-box'), cols: 3, load: () => listStoreReviews(s.id),
      render: ({ rows, truncated }) => (rows.length === 0 ? emptyBlock('아직 받은 평가가 없어요', '손님이 평가를 남기면 여기에 나타나요')
        : tableHtml(['작성일', '등급', '내용'], rows.map((r) => `<tr><td class="a-num">${esc(fmtDateOnly(r.createdAt))}</td><td>${esc(typeof r.grade === 'string' ? `${r.grade}급` : '-')}</td>
          <td class="a-clamp" title="${esc(r.comment || '')}">${esc(r.comment || '-')}</td></tr>`)) + (truncated ? '<div class="a-total">최근 200건까지만 불러왔어요</div>' : '')),
    });
    $('#refresh').onclick = () => loader.run(true);
    loader.run(false);
  });
}

/* ============================================================================
   OW6/OW7/OW8 메뉴 관리
   ========================================================================== */
async function loadMenuCatalog(s) {
  const [mainCategories, subCategories, store, master] = await Promise.all([
    listMainCategories(), listAll(['stores', s.id], 'subCategories'), listAll(['stores', s.id], 'optionGroups'), listMasterOptionGroups(),
  ]);
  return {
    mainCategories, subCategories,
    optionGroups: [...master.map((g) => ({ ...g, scope: 'master' })), ...store.map((g) => ({ ...g, scope: 'store' }))],
  };
}

function viewMenus(alive) {
  const v = $('#view');
  v.innerHTML = `${headHtml({ title: '메뉴 관리' })}<div id="ow-box"></div>`;
  withStore(alive, $('#ow-box'), (s, body) => {
    if (s.brandId) return franchiseMenus(alive, s, body);
    if (storeStatusOf(s) !== 'approved') {
      body.innerHTML = `<div class="a-gate-card a-in-main"><h2>매장 승인 후 메뉴를 관리할 수 있어요</h2><p class="a-cap">승인 상태는 위 안내를 확인해주세요.</p></div>`;
      return;
    }
    personalMenus(alive, s, body);
  });
}

function personalMenus(alive, s, body) {
  let f = 'all'; let rows = [];
  body.innerHTML = `<div class="a-toolbar" id="mn-tools"></div><div id="notice"></div><div id="mn-box"></div>`;
  const tools = () => {
    $('#mn-tools').innerHTML = `${chipGroup('필터', [['all', '전체'], ['on', '노출'], ['off', '숨김'], ['sold', '품절']], f)}<span style="margin-left:auto"></span><a class="a-btn primary" href="#/o/menus/new">메뉴 추가</a>`;
    $$('[data-f]', $('#mn-tools')).forEach((b) => { b.onclick = () => { f = b.dataset.f; tools(); draw(); }; });
  };
  const draw = () => {
    const hit = rows.filter((m) => f === 'all' || (f === 'on' && m.visible !== false) || (f === 'off' && m.visible === false) || (f === 'sold' && m.soldOut === true));
    const box = $('#mn-box');
    if (rows.length === 0) { box.innerHTML = emptyBlock('아직 등록된 메뉴가 없어요', '첫 메뉴를 등록해보세요', '<br><a class="a-btn primary" href="#/o/menus/new">첫 메뉴 등록하기</a>'); return; }
    if (hit.length === 0) { box.innerHTML = emptyBlock('조건에 맞는 메뉴가 없어요', '', '<br><button type="button" class="a-link" id="mn-clear">필터 지우기</button>'); $('#mn-clear').onclick = () => { f = 'all'; tools(); draw(); }; return; }
    box.innerHTML = tableHtml(['메뉴', '카테고리', '가격', '노출', '품절', '순서', ''], hit.map((m) => `<tr>
      <td><div class="a-name">${thumb(m.imageUrl, m.name)}<strong>${esc(m.name || '(이름 없음)')}</strong></div></td><td>${esc(m.mainCategory || '-')}</td><td class="a-num">${esc(typeof m.basePrice === 'number' ? m.basePrice.toLocaleString('ko-KR') + '원' : '-')}</td>
      <td class="a-sw-row">${switchHtml(`v-${m.id}`, m.visible !== false, `${m.name} 노출`, `data-k="visible" data-id="${esc(m.id)}"`)}</td>
      <td class="a-sw-row">${switchHtml(`s-${m.id}`, m.soldOut === true, `${m.name} 품절`, `data-k="soldOut" data-id="${esc(m.id)}"`)}</td>
      <td class="a-num">${esc(m.displayOrder ?? 0)}</td>
      <td class="a-actions"><a href="#/o/menus/${encodeURIComponent(m.id)}">편집</a> <a href="#/o/menus/new?clone=${encodeURIComponent(m.id)}">복제</a> <button type="button" class="a-link" data-del="${esc(m.id)}">삭제…</button></td></tr>`))
      + `<div class="a-total">총 ${hit.length}개</div>`;
    // 노출/품절 토글은 운영 8키 경로 (W-O3). 응답 전에는 스위치 상태가 바뀌지 않는다.
    $$('.a-switch', box).forEach((sw) => wireSwitch(sw, async (next) => { await updateStoreMenuOperation(s.id, sw.dataset.id, { [sw.dataset.k]: next }, 'owner'); const m = rows.find((x) => x.id === sw.dataset.id); if (m) m[sw.dataset.k] = next; }));
    $$('[data-del]', box).forEach((b) => { b.onclick = () => deleteMenuDialog(rows.find((x) => x.id === b.dataset.del), b); });
  };
  const deleteMenuDialog = (m, trigger) => openDialog({
    title: '메뉴를 삭제할까요?', trigger, confirmLabel: '삭제', confirmClass: 'reject-confirm',
    bodyHtml: `${targetBlock(m.name)}<p class="a-ask">삭제된 메뉴는 복구할 수 없어요.</p>`,
    onConfirm: async () => { await deleteStoreMenu(s.id, m.id); await load(); },
    onError: (e, api) => api.showMsg(banner('error', '실패', '삭제에 실패했어요')),
  });
  const load = async () => {
    $('#mn-box').innerHTML = skelRows(7, 6);
    try { rows = await listStoreMenus(s.id); if (!alive()) return; tools(); draw(); const st = $('#stamp'); if (st) st.textContent = `마지막 갱신 ${fmtClock()}`; }
    catch (e) { console.error('[owner] 메뉴 조회 실패', e?.code || e); if (!alive()) return; $('#mn-box').innerHTML = errorBlock(e, 'data-retry', { title: '메뉴를 불러오지 못했어요', desc: '잠시 후 다시 시도해주세요.' }); $('[data-retry]', $('#mn-box')).onclick = load; onReadFail(e, $('#mn-box')); }
  };
  $('#refresh').onclick = load; tools(); load();
}

/* OW8 — 브랜드 가맹 매장: 품절 · 옵션 비활성만 (점주는 메뉴를 추가·수정·삭제하지 않는다) */
function franchiseMenus(alive, s, body) {
  body.innerHTML = `${banner('', '', '점주는 품절과 옵션 비활성화만 가능해요. 메뉴 추가/수정은 브랜드 본사에서 관리합니다.')}<div id="fm-tools"></div><div id="notice"></div><div id="fm-box"></div>`;
  let f = 'all'; let items = [];
  const load = async () => {
    $('#fm-box').innerHTML = skelRows(5, 6);
    try {
      const [masters, ovs, storeOnly] = await Promise.all([listMasterMenus(s.brandId), listStoreOverrides(s.id), listStoreMenus(s.id)]);
      if (!alive()) return;
      const ovMap = new Map(ovs.map((o) => [o.id, o]));
      items = [
        ...masters.filter((m) => m.status === 'approved').map((m) => ({ kind: 'master', m, ov: ovMap.get(m.id) || null })),
        ...storeOnly.map((m) => ({ kind: 'store', m, ov: null })),
      ];
      draw();
      const st = $('#stamp'); if (st) st.textContent = `마지막 갱신 ${fmtClock()}`;
    } catch (e) { console.error('[owner] 가맹 메뉴 조회 실패', e?.code || e); if (!alive()) return; $('#fm-box').innerHTML = errorBlock(e, 'data-retry', { title: '메뉴를 불러오지 못했어요', desc: '잠시 후 다시 시도해주세요.' }); $('[data-retry]', $('#fm-box')).onclick = load; onReadFail(e, $('#fm-box')); }
  };
  const draw = () => {
    $('#fm-tools').innerHTML = chipGroup('구분', [['all', '전체'], ['master', '마스터'], ['store', '매장 한정']], f);
    $$('[data-f]', $('#fm-tools')).forEach((b) => { b.onclick = () => { f = b.dataset.f; draw(); }; });
    const hit = items.filter((i) => f === 'all' || i.kind === f);
    const box = $('#fm-box');
    if (hit.length === 0) { box.innerHTML = emptyBlock('아직 등록된 메뉴가 없어요', '브랜드 본사에서 마스터 메뉴를 추가하면 여기에 표시돼요.'); return; }
    box.innerHTML = tableHtml(['메뉴', '구분', '가격', '품절', '옵션'], hit.map((i) => {
      const sold = i.kind === 'master' ? (i.ov ? i.ov.soldOut === true : i.m.soldOut === true) : i.m.soldOut === true;
      const price = i.kind === 'master' ? appliedOverride(i.m.basePrice, i.ov).price : i.m.basePrice;
      return `<tr><td><div class="a-name">${thumb(i.m.imageUrl, i.m.name)}<strong>${esc(i.m.name || '(이름 없음)')}</strong></div></td><td>${i.kind === 'master' ? '마스터' : '매장 한정'}</td>
        <td class="a-num">${esc(typeof price === 'number' ? price.toLocaleString('ko-KR') + '원' : '-')}</td>
        <td class="a-sw-row">${switchHtml(`s-${i.m.id}`, sold, `${i.m.name} 품절`, `data-id="${esc(i.m.id)}" data-kind="${i.kind}"`)}</td>
        <td><button type="button" class="a-link" data-opt="${esc(i.m.id)}" data-kind="${i.kind}">옵션 관리 →</button></td></tr>`;
    }));
    // 품절 토글은 soldOut 3키만 (옵션 비활성 설정을 지우지 않는다 — 앱 결함 ⓐ)
    $$('.a-switch', box).forEach((sw) => wireSwitch(sw, async (next) => {
      const it = items.find((x) => x.m.id === sw.dataset.id && x.kind === sw.dataset.kind);
      if (it.kind === 'master') { await setOverrideSoldOut(S_STORE(s), it.m.id, next); it.ov = { ...(it.ov || {}), soldOut: next }; }
      else { await updateStoreMenuOperation(s.id, it.m.id, { soldOut: next }, 'owner'); it.m.soldOut = next; }
    }));
    $$('[data-opt]', box).forEach((b) => { b.onclick = () => optionDialog(items.find((x) => x.m.id === b.dataset.opt && x.kind === b.dataset.kind), b); });
  };
  const optionDialog = async (it, trigger) => {
    trigger.disabled = true; const before = trigger.textContent; trigger.textContent = '불러오는 중…';
    try {
      const groups = await fetchOptionGroups(it.m.optionGroupRefs || [], { brandId: s.brandId, storeId: s.id });
      if (!alive()) return;
      const src = it.kind === 'master' ? (it.ov || {}) : it.m;
      optionDisableDialog({
        title: '옵션 관리', subtitle: it.m.name, groups, trigger,
        disabledGroupIds: Array.isArray(src.disabledOptionGroupIds) ? src.disabledOptionGroupIds : [], disabledItemIds: Array.isArray(src.disabledOptionItemIds) ? src.disabledOptionItemIds : [],
        onApply: async (g, i) => {
          if (it.kind === 'master') { await setOverrideOptionDisable(S_STORE(s), it.m.id, g, i); it.ov = { ...(it.ov || {}), disabledOptionGroupIds: g, disabledOptionItemIds: i }; }
          else { await updateStoreMenuOperation(s.id, it.m.id, { disabledOptionGroupIds: g, disabledOptionItemIds: i }, 'owner'); it.m.disabledOptionGroupIds = g; it.m.disabledOptionItemIds = i; }
        },
      });
    } catch (e) { console.error('[owner] 옵션 그룹 조회 실패', e?.code || e); $('#notice').innerHTML = banner('error', '', '옵션 그룹을 불러오지 못했어요. 잠시 후 다시 시도해주세요.'); onReadFail(e); }
    finally { trigger.disabled = false; trigger.textContent = before; }
  };
  $('#refresh').onclick = load; load();
}
const S_STORE = (s) => ({ id: s.id, brandId: s.brandId });

/* OW7 메뉴 등록/수정(개인 매장) — approved 로 즉시 반영되는 단일 폼 */
function viewMenuForm(alive, id) {
  const v = $('#view');
  const params = new URLSearchParams(location.hash.split('?')[1] || '');
  const cloneId = id === null ? params.get('clone') : null;
  const isCreate = id === null;
  v.innerHTML = `<div class="a-crumbs"><a href="#/o/menus">← 메뉴 관리</a></div>
    <div class="a-head"><h1 tabindex="-1">${isCreate ? (cloneId ? '메뉴 복제' : '메뉴 등록') : '메뉴 수정'}<span class="a-chip a-chip-strong">저장 즉시 반영</span></h1></div><div style="height:16px"></div><div id="ow-box"></div>`;
  withStore(alive, $('#ow-box'), async (s, body) => {
    if (s.brandId || storeStatusOf(s) !== 'approved') { hooks.go('#/o/menus'); return; }
    body.innerHTML = '<div id="mf-box"></div>';
    try {
      const [catalog, menus] = await Promise.all([loadMenuCatalog(s), id || cloneId ? listStoreMenus(s.id) : Promise.resolve([])]);
      if (!alive()) return;
      const src = (id || cloneId) ? menus.find((m) => m.id === (id || cloneId)) : null;
      if ((id || cloneId) && !src) { $('#mf-box').innerHTML = emptyBlock('찾을 수 없는 메뉴예요', '', '<br><a class="a-link" href="#/o/menus">목록으로</a>'); return; }
      const initial = cloneId ? { ...src, name: `${src.name} 복사` } : src;
      const ctrl = menuForm({
        box: $('#mf-box'), alive, initial, isCreate, alwaysSavable: isCreate, targetName: initial?.name || '새 메뉴',
        sections: { image: true, core: true, ops: true, soldOut: true, requireImage: isCreate }, catalog, saveLabel: '저장',
        onSubmit: async (c) => {
          const ok = await c.runSave(async () => {
            const prefix = storagePaths.storeMenu(s.id, isCreate ? null : id);
            const imageUrl = await c.uploadIfNeeded(prefix);
            if (isCreate) await createPersonalMenu(s.id, { ...c.values(), imageUrl });
            else {
              const ch = { ...c.changes() }; if ('imageUrl' in ch) ch.imageUrl = imageUrl;
              await updatePersonalMenu(s.id, id, ch);
            }
          });
          if (ok) { registerDirty(() => false); S.flash = '즉시 반영되었습니다'; hooks.go('#/o/menus'); }
        },
      });
      void ctrl;
    } catch (e) {
      console.error('[owner] 메뉴 폼 로드 실패', e?.code || e);
      if (!alive()) return;
      $('#mf-box').innerHTML = errorBlock(e, 'data-retry', { title: '불러오지 못했어요', desc: '잠시 후 다시 시도해주세요.' });
      $('[data-retry]', $('#mf-box')).onclick = () => viewMenuForm(alive, id); onReadFail(e, $('#mf-box'));
    }
  });
}

/* OW9/OW10 서브 카테고리 · 옵션 그룹 (개인 매장만, 앱과 동일) */
function viewCatalog(alive, kind) {
  const v = $('#view');
  v.innerHTML = `${headHtml({ title: kind === 'sub' ? '서브 카테고리' : '옵션 그룹', refresh: false })}<div id="ow-box"></div>`;
  withStore(alive, $('#ow-box'), async (s, body) => {
    if (s.brandId) { hooks.go('#/o/store'); return; }
    body.innerHTML = '<div id="cat-box"></div>';
    try {
      const cats = kind === 'sub' ? await listMainCategories() : [];
      if (!alive()) return;
      catalogView({ kind, scope: 'store', ownerId: s.id, alive, box: $('#cat-box'), mainCategories: cats });
    } catch (e) { $('#cat-box').innerHTML = errorBlock(e); $('[data-retry]', $('#cat-box')).onclick = () => viewCatalog(alive, kind); onReadFail(e, $('#cat-box')); }
  });
}

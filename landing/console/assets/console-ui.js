/* ============================================================================
   공용 UI 조각 — 상태(S), 위젯, 목록 로더, 대화상자, 폼 빌더.
   console-shell.js(셸·라우터)와 section-*.js(역할별 화면)가 함께 쓴다. Firebase SDK 는 import 하지 않는다.

   [보안 모델 — 이 파일의 모든 분기에 해당]
   이 콘솔은 클라이언트일 뿐이다. 권한의 최종 권위는 Firestore Security Rules 와 Cloud Functions 에 있다.
   화면 분기(셸을 만들지 않음, 버튼 비활성화, 사전 상태 확인, 해시 정규화)는 사용자의 혼동과 실수를 줄이는 편의이며,
   접근을 통제하지 않는다. DOM 을 고쳐 버튼을 눌러도 거부 여부는 서버가 정한다.
   ========================================================================== */

import {
  esc, fmtClock, shortUid, safeUrl, normalizeStatus, STATUS_LABEL, classifyError, readErrorText, saveErrorText,
  statusBadgeText, fmtDateTime,
} from './console-format.js';

export const root = document.getElementById('app');

/* ── 상태 ──────────────────────────────────────────────────────────────────── */
export const S = {
  authGen: 0,
  shell: null,            // { uid, email, role, brandId, info } — 역할 판정이 끝난 뒤에만 존재
  section: null,          // 현재 역할의 섹션 모듈
  viewGen: 0,
  counts: {},             // admin 승인 대기 건수 key → {state, n?, err?}
  order: {},              // admin 큐 key → 마지막으로 불러온 id 배열
  modal: null,
  flash: null,            // 쓰기 성공 후 목록에서 띄울 토스트 문구
  loginNotice: null,      // 로그인 화면 상단 안내
  panelFail: null,        // 모달을 닫은 뒤 상세 화면에 남기는 마지막 실패
  checkTimer: null,
  autoOutTimer: null,     // 모르는 role 안내 화면의 자동 로그아웃 카운트다운
  busy: false,            // 쓰기 in-flight (beforeunload 확인)
  dirty: null,            // () => boolean — 저장 안 한 변경이 있는 폼이 등록한다 (N15)
  curHash: '',
  suppressHash: false,
};

/** 셸이 채우는 연결 고리. 섹션은 셸을 직접 import 하지 않는다 (순환 방지). */
export const hooks = {
  route: () => {},
  go: (_hash) => {},          // 해시를 replace 로 바꾸고 다시 그린다
  recheckRole: (_force) => Promise.resolve({ changed: false }),
  renderNav: () => {},
  renderContext: () => {},
  loadAllCounts: () => Promise.resolve(),
  signOut: () => {},
};

export const LOGO = `<svg class="qlogo" viewBox="0 0 100 100" aria-hidden="true">
  <path d="M 73.09 79.55 A 37.5 37.5 0 1 1 87.5 50 L 75 50 A 25 25 0 1 0 65.39 69.70 Z" fill="currentColor"/>
  <path d="M 69.09 60.61 L 97.73 89.24 L 80.75 89.24 L 52.12 60.61 Z" fill="currentColor"/>
</svg>`;

export const $ = (sel, scope = document) => scope.querySelector(sel);
export const $$ = (sel, scope = document) => [...scope.querySelectorAll(sel)];
export const skel = (w = '100%', h = 16) => `<span class="a-skel" style="width:${w};height:${h}px"></span>`;
export const letter = (name) => esc((String(name || '').trim()[0] || '?').toUpperCase());

export function toast(msg) {
  const r = $('#toast-region');
  if (!r) return;
  const t = document.createElement('div');
  t.className = 'a-toast';
  t.textContent = msg;
  r.appendChild(t);
  setTimeout(() => t.remove(), 6000);
}

window.addEventListener('beforeunload', (e) => {
  // 쓰기 중이거나 저장 안 한 변경이 있으면 이탈을 확인한다.
  if (S.busy || (S.dirty && S.dirty())) { e.preventDefault(); e.returnValue = ''; }
});

/* ── 공용 조각 ─────────────────────────────────────────────────────────────── */
export const banner = (kind, lead, text, extra = '') =>
  `<div class="a-banner ${kind}" role="${kind === 'error' ? 'alert' : 'status'}"><p>${lead ? `<span class="a-b-lead">${esc(lead)}</span>` : ''}${esc(text)}</p>${extra}</div>`;

export const emptyBlock = (title, desc, extra = '') =>
  `<div class="a-empty"><strong>${esc(title)}</strong>${desc ? `<span>${esc(desc)}</span>` : ''}${extra}</div>`;

export function errorBlock(err, retryAttr = 'data-retry', override = null) {
  const t = override || readErrorText(err);
  return `<div class="a-err" role="alert"><strong>${esc(t.title)}</strong><p>${esc(t.desc)}</p>
    <button type="button" class="a-btn" ${retryAttr}>다시 시도</button></div>`;
}

export const statusBadge = (st) => {
  const s = normalizeStatus(st);
  return s ? `<span class="a-badge ${s}">${STATUS_LABEL[s]}</span>` : '<span class="a-badge">알 수 없음</span>';
};
/** 승인 이력이 있는 대기는 "수정 대기" (색이 아니라 글자로 구분). */
export const docBadge = (x) => {
  const s = normalizeStatus(x?.status);
  return `<span class="a-badge ${s || ''}">${esc(statusBadgeText(x))}</span>`;
};

export const copyBtn = (v) => (v ? `<button type="button" class="a-link a-copy" data-copy="${esc(v)}">복사</button>` : '');
export const uidCell = (uid) => (uid
  ? `<span class="a-num" title="${esc(uid)}">${esc(shortUid(uid))}</span>${copyBtn(uid)}`
  : '<span class="a-empty-v a-muted">-</span>');

export function thumb(url, name, lg = false) {
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

// UID / 브랜드 키 복사 — clipboard 가 막힌 컨텍스트에서도 조용히 실패하지 않는다 (DV-24)
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

export const kv = (rows) => `<dl class="a-kv">${rows.map(([k, val, raw]) => `<dt>${esc(k)}</dt><dd>${raw ? val : (val === '' || val == null || val === '-' ? '<span class="a-empty-v a-muted">-</span>' : esc(val))}</dd>`).join('')}</dl>`;

export const tableHtml = (heads, bodyRows) =>
  `<div class="a-table-wrap"><table class="a-table"><thead><tr>${heads.map((h) => `<th scope="col">${h}</th>`).join('')}</tr></thead><tbody>${bodyRows.join('')}</tbody></table></div>`;

export const skelRows = (cols, n = 5) => `<div class="a-table-wrap" aria-busy="true"><span class="a-sr">불러오는 중</span><table class="a-table"><tbody>${
  Array.from({ length: n }, () => `<tr class="a-skel-row">${Array.from({ length: cols }, () => `<td>${skel('80%', 16)}</td>`).join('')}</tr>`).join('')}</tbody></table></div>`;

export function headHtml({ title, tag, desc, refresh = true }) {
  return `<div class="a-head"><h1 tabindex="-1">${esc(title)}${tag ? `<span class="a-chip">${esc(tag)}</span>` : ''}</h1>
    ${refresh ? `<div class="a-head-tools"><span class="a-cap" id="stamp"></span><button type="button" class="a-btn sm" id="refresh">새로고침</button></div>` : ''}</div>
    ${desc ? `<p class="a-desc">${esc(desc)}</p>` : '<div style="height:24px"></div>'}`;
}

export const detailSkeleton = (backHref, backLabel) => `<div class="a-crumbs"><a href="${backHref}">← ${backLabel}</a></div>
  <div aria-busy="true"><span class="a-sr">불러오는 중</span>${skel('40%', 30)}<div style="height:24px"></div>
  <div class="a-detail"><div class="a-detail-main"><div class="a-card">${skel('50%', 18)}<div style="height:16px"></div>${skel('90%', 14)}<div style="height:10px"></div>${skel('70%', 14)}<div style="height:10px"></div>${skel('80%', 14)}</div>
  <div class="a-card">${skel('40%', 18)}<div style="height:16px"></div>${skel('90%', 14)}<div style="height:10px"></div>${skel('60%', 14)}</div></div>
  <aside class="a-panel a-card">${skel('50%', 18)}</aside></div></div>`;

export const flashOnce = () => { const f = S.flash; S.flash = null; return f; };

/* ── 읽기 실패 처리 (C4) ──────────────────────────────────────────────────────
   permission-denied 는 "역할이 바뀌었을 수 있다" 는 신호다. users/{uid} 를 다시 읽어 확인한다 (폴링 없음).
   재확인 자체가 실패하면 blockEl 안의 설명을 "권한을 다시 확인하지 못했어요" 로 바꾼다. */
export function onReadFail(err, blockEl = null) {
  if (classifyError(err).kind !== 'permission') return;
  hooks.recheckRole().then((res) => {
    if (res && res.failed && blockEl && document.contains(blockEl)) {
      const p = blockEl.querySelector('.a-err p');
      if (p) p.textContent = '권한을 다시 확인하지 못했어요. 연결을 확인한 뒤 다시 시도해주세요.';
    }
  });
}

/**
 * 목록 로더. 최초 = 스켈레톤, 새로고침 = 기존 행 유지 + 상단 로딩바(깜빡임 없음).
 * 새로고침 실패 시 기존 행을 유지하고 '마지막 갱신' 시각을 갱신하지 않는다.
 */
export function makeLoader({ alive, box, notice, cols, load, render, onData, onFail }) {
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
      console.error('[console] 목록 조회 실패', e?.code || e);
      if (!alive() || my !== token) return;
      if (refreshing) {
        $('.a-lbar', box)?.remove();
        if (notice) notice.innerHTML = banner('error', '', '목록을 새로 고치지 못했어요. 아래는 마지막으로 불러온 내용이에요.');
      } else {
        box.innerHTML = errorBlock(e);
        $('[data-retry]', box).onclick = () => run(false);
        onReadFail(e, box);
        if (onFail) onFail(e);
      }
    }
  }
  return { run };
}

/**
 * 영역 하나(카드·폼·상세)를 불러오는 단순 로더. render(data) 가 HTML 을 돌려주고 after(data) 로 이벤트를 단다.
 * 실패는 영역 안 오류 블록 + 다시 시도. 권한 거부는 역할 재확인 (C4).
 */
export async function loadInto(box, alive, load, render, after, skelHtml = null) {
  box.innerHTML = skelHtml ?? `<div class="a-card" aria-busy="true"><span class="a-sr">불러오는 중</span>${skel('50%', 18)}<div style="height:14px"></div>${skel('90%', 14)}<div style="height:8px"></div>${skel('70%', 14)}</div>`;
  try {
    const data = await load();
    if (!alive()) return null;
    box.innerHTML = render(data);
    if (after) after(data);
    return data;
  } catch (e) {
    console.error('[console] 영역 조회 실패', e?.code || e);
    if (!alive()) return null;
    box.innerHTML = errorBlock(e);
    $('[data-retry]', box).onclick = () => loadInto(box, alive, load, render, after, skelHtml);
    onReadFail(e, box);
    return null;
  }
}

/* ============================================================================
   대화상자 (변경 확인 · 삭제 · 편집 · 이동 확인)
   - 응답 전에는 어느 화면도 '처리됨'으로 바꾸지 않는다. 실패 시 모달을 닫지 않고 입력을 보존한다.
   - Esc / 오버레이 클릭 / 취소: busy 중에는 무시. 포커스 트랩.
   ========================================================================== */

/**
 * @param {object} o
 * @param {string} o.title
 * @param {string} o.bodyHtml
 * @param {string} [o.confirmLabel]   확정 버튼 라벨
 * @param {string} [o.confirmClass]   'primary' | 'reject-confirm' | ''
 * @param {string} [o.cancelLabel]
 * @param {boolean} [o.wide]          640px (옵션 그룹 편집 등)
 * @param {boolean} [o.noConfirm]     확정 버튼 없음 (안내 전용)
 * @param {string} [o.focus]          초기 포커스 셀렉터 (기본: 취소 버튼 — Enter 한 번에 확정되지 않게)
 * @param {(api)=>void} [o.onOpen]
 * @param {(api)=>Promise<any>} [o.onConfirm]   resolve → 닫힘 (false 를 돌려주면 열어 둠) / reject → onError
 * @param {(e, api)=>void} [o.onError]
 * @param {()=>boolean} [o.dirty]     true 면 오버레이 클릭으로 닫지 않는다 (입력 손실 방지)
 */
export function openDialog(o) {
  if (S.modal) return null;
  const st = { busy: false, locked: false };
  const ov = document.createElement('div');
  ov.className = 'a-overlay';
  let label = o.confirmLabel || '확인';
  ov.innerHTML = `<div class="a-modal${o.wide ? ' wide' : ''}" role="dialog" aria-modal="true" aria-labelledby="dlg-title">
    <h2 id="dlg-title">${esc(o.title)}</h2>
    <div id="dlg-body">${o.bodyHtml || ''}</div><div id="dlg-msg" style="margin-top:14px"></div>
    <div class="a-modal-foot" id="dlg-foot"><button type="button" class="a-btn lg" id="dlg-cancel">${esc(o.cancelLabel || '취소')}</button>
      ${o.noConfirm ? '' : `<button type="button" class="a-btn lg ${o.confirmClass ?? 'primary'}" id="dlg-ok">${esc(label)}</button>`}</div></div>`;
  document.body.appendChild(ov);
  const modal = $('.a-modal', ov);
  const okBtn = $('#dlg-ok', ov); const cancelBtn = $('#dlg-cancel', ov);
  const q = (sel) => $(sel, ov);

  const api = {
    el: ov, q, label,
    get busy() { return st.busy; },
    showMsg(html) { q('#dlg-msg').innerHTML = html ? `<div id="dlg-msg-in" tabindex="-1">${html}</div>` : ''; if (html) q('#dlg-msg-in').focus(); },
    setBody(html) { q('#dlg-body').innerHTML = html; },
    setConfirmEnabled(on) { if (okBtn) okBtn.disabled = !on || st.locked; },
    lock() { st.locked = true; if (okBtn) okBtn.disabled = true; },
    setBusy(b, text) {
      st.busy = b; S.busy = b;
      modal.setAttribute('aria-busy', String(b));
      ov.querySelectorAll('button, textarea, input, select').forEach((el) => { el.disabled = b; });
      if (okBtn) okBtn.innerHTML = b ? `<span class="a-spin"></span>${esc(text || '처리 중…')}` : esc(label);
      if (!b && okBtn) okBtn.disabled = st.locked;
    },
    addFootButton(id, text, handler) {
      const b = document.createElement('button');
      b.type = 'button'; b.className = 'a-btn lg'; b.id = id; b.textContent = text; b.onclick = handler;
      q('#dlg-foot').insertBefore(b, cancelBtn);
      return b;
    },
    setLabel(t) { label = t; if (okBtn) okBtn.textContent = t; },
    close() { if (!st.busy) destroy(); },
  };

  function destroy() {
    if (S.modal?.api !== api) return;
    S.modal = null; S.busy = false;
    ov.remove();
    document.removeEventListener('keydown', onKey, true);
    if (o.trigger && document.contains(o.trigger)) o.trigger.focus();
  }
  api.destroy = destroy;

  function onKey(e) {
    if (e.key === 'Escape') { e.preventDefault(); if (!st.busy) destroy(); return; }
    if (e.key !== 'Tab') return;
    const items = [...modal.querySelectorAll('button:not([disabled]), textarea:not([disabled]), input:not([disabled]), select:not([disabled])')];
    if (items.length === 0) { e.preventDefault(); return; }
    const first = items[0]; const last = items[items.length - 1];
    if (e.shiftKey && (document.activeElement === first || !modal.contains(document.activeElement))) { e.preventDefault(); last.focus(); }
    else if (!e.shiftKey && (document.activeElement === last || !modal.contains(document.activeElement))) { e.preventDefault(); first.focus(); }
  }
  document.addEventListener('keydown', onKey, true);

  cancelBtn.onclick = () => { if (!st.busy) { destroy(); if (o.onCancel) o.onCancel(); } };
  ov.addEventListener('mousedown', (e) => {
    if (e.target !== ov || st.busy) return;
    if (o.dirty && o.dirty()) return;
    destroy();
  });

  if (okBtn && o.onConfirm) {
    okBtn.onclick = async () => {
      if (st.busy || st.locked) return;
      api.showMsg('');
      api.setBusy(true, o.busyLabel);
      try {
        const keep = await o.onConfirm(api);
        api.setBusy(false);
        if (keep !== false) destroy();
      } catch (e) {
        api.setBusy(false);
        console.error('[console] 대화상자 쓰기 실패', e?.stage || '', e?.code || e?.name || e);
        if (o.onError) o.onError(e, api); else defaultSaveError(e, api, o);
      }
    };
  }

  S.modal = { api, get busy() { return st.busy; }, close: () => api.close(), destroy };
  if (o.onOpen) o.onOpen(api);
  (o.focus ? q(o.focus) : cancelBtn)?.focus();
  return api;
}

/** 쓰기 실패 기본 표시 — 성공으로 보이지 않게, 입력은 보존, 불확실한 결과는 단정하지 않는다. */
export function defaultSaveError(e, api, o = {}) {
  const t = saveErrorText(e);
  api.showMsg(banner('error', '실패', t.text));
  if (t.permission) hooks.recheckRole();  // 역할이 바뀌어서 거부됐을 수 있다 — 거부를 성공으로 표시하지 않고 재확인
  if (t.expired) { setTimeout(() => { S.loginNotice = '세션이 만료되었어요. 다시 로그인해주세요.'; api.destroy(); hooks.signOut(); }, 3000); return; }
  if (t.unknown) {
    api.lock();
    if (o.checkStatus) {
      const b = api.addFootButton('dlg-check', '상태 확인하기', async () => {
        b.disabled = true; b.textContent = '확인 중…';
        try { await o.checkStatus(api); } catch (_) { b.disabled = false; b.textContent = '상태 확인하기'; api.showMsg(banner('error', '실패', '상태를 확인하지 못했어요. 잠시 후 다시 시도해주세요.')); }
      });
    }
  }
}

/** N15 — 저장하지 않은 변경 확인. 나가기를 누르면 onLeave. */
export function confirmLeave(onLeave) {
  if (S.modal) return;
  openDialog({
    title: '저장하지 않은 변경이 있어요',
    bodyHtml: '<p class="a-ask">이 페이지를 나가면 입력한 내용이 사라져요.</p>',
    cancelLabel: '계속 편집', confirmLabel: '나가기', confirmClass: '',
    onConfirm: async () => { onLeave(); },
  });
}

/* ============================================================================
   폼 빌더 — 입력은 textContent/value 로만 다룬다 (esc 후 innerHTML)
   ========================================================================== */

export const switchHtml = (id, on, label, extra = '') =>
  `<button type="button" class="a-switch" role="switch" id="${id}" aria-checked="${on ? 'true' : 'false'}" ${extra}>
    <span class="a-sw-track" aria-hidden="true"><span class="a-sw-knob"></span></span><span class="a-sw-text">${on ? '켜짐' : '꺼짐'}</span>
    ${label ? `<span class="a-sr">${esc(label)}</span>` : ''}</button>`;

export function field({ id, label, required, help, value = '', type = 'text', max, ph = '', multiline = false, rows = 3, attrs = '', counter = false }) {
  const lab = `${esc(label)}${required ? ' (필수)' : ''}`;
  const input = multiline
    ? `<textarea class="a-textarea" id="${id}" rows="${rows}" ${max ? `maxlength="${max}"` : ''} placeholder="${esc(ph)}" aria-describedby="${id}-help ${id}-err" ${attrs}>${esc(value)}</textarea>`
    : `<input class="a-input" id="${id}" type="${type}" ${max ? `maxlength="${max}"` : ''} value="${esc(value)}" placeholder="${esc(ph)}" aria-describedby="${id}-help ${id}-err" ${attrs}>`;
  return `<div class="a-field"><label class="a-label" for="${id}">${lab}${counter && max ? `<span class="a-counter a-num" id="${id}-cnt">${[...String(value)].length} / ${max}</span>` : ''}</label>
    ${input}${help ? `<div class="a-help" id="${id}-help">${esc(help)}</div>` : `<div id="${id}-help"></div>`}<div class="a-field-err" id="${id}-err" hidden></div></div>`;
}

export function setFieldError(id, msg) {
  const el = $(`#${id}-err`); const input = $(`#${id}`);
  if (el) { el.hidden = !msg; el.textContent = msg || ''; }
  if (input) input.setAttribute('aria-invalid', msg ? 'true' : 'false');
}

/** 스위치 클릭 배선. onToggle(next) 는 Promise — 성공 응답 후에만 상태를 바꾼다 (낙관적 UI 금지). */
export function wireSwitch(el, onToggle) {
  el.addEventListener('click', async () => {
    if (el.disabled || el.dataset.busy === '1') return;
    const next = el.getAttribute('aria-checked') !== 'true';
    el.dataset.busy = '1'; el.disabled = true; el.classList.add('busy');
    const row = el.closest('tr, .a-sw-row');
    row?.querySelector('.a-sw-err')?.remove();
    try {
      await onToggle(next);
      el.setAttribute('aria-checked', String(next));
      el.querySelector('.a-sw-text').textContent = next ? '켜짐' : '꺼짐';
    } catch (e) {
      console.error('[console] 스위치 쓰기 실패', e?.code || e);
      const t = saveErrorText(e);
      el.insertAdjacentHTML('afterend', `<div class="a-sw-err" role="alert">${esc(t.unknown ? '처리 여부를 확인하지 못했어요. 새로고침으로 확인해주세요' : '변경에 실패했어요. 다시 시도해주세요')}</div>`);
      if (t.permission) hooks.recheckRole();
    } finally {
      delete el.dataset.busy; el.disabled = false; el.classList.remove('busy');
    }
  });
}

/** 변경 요약 리스트 (N6): rows = [[라벨, 이전, 이후]] */
export function changeListHtml(rows) {
  const v = (x) => (x === '' || x == null ? '(없음)' : String(x));
  return `<ul class="a-changes">${rows.map(([k, a, b]) => `<li><span class="a-ch-k">${esc(k)}</span><span class="a-ch-a" title="${esc(v(a))}">${esc(v(a))}</span><span aria-hidden="true">→</span><span class="a-ch-b" title="${esc(v(b))}">${esc(v(b))}</span></li>`).join('')}</ul>`;
}

/** 대상 블록 (모달 상단) */
export const targetBlock = (name, sub = '') => `<div class="a-target"><b>${esc(name || '(이름 없음)')}</b>${sub ? `<small>${sub}</small>` : ''}</div>`;

/** 고정 저장 바 (N5). 변경 개수·대상 이름·버튼. */
export function saveBarHtml({ targetName, saveLabel }) {
  return `<div class="a-savebar" role="group" aria-label="저장">
    <div class="a-sb-left"><span id="sb-dirty" class="a-sb-dirty">변경 사항이 없어요</span><span class="a-sb-target" title="${esc(targetName)}">${esc(targetName)}</span></div>
    <div class="a-sb-right"><button type="button" class="a-btn" id="sb-reset">입력 되돌리기</button>
    <button type="button" class="a-btn primary" id="sb-save" disabled>${esc(saveLabel)}</button></div></div>`;
}
export function setSaveBar(count) {
  const d = $('#sb-dirty'); const b = $('#sb-save');
  if (d) { d.textContent = count > 0 ? `변경 ${count}개` : '변경 사항이 없어요'; d.classList.toggle('on', count > 0); }
  if (b) b.disabled = count === 0;
}

/** 폼 위 영구 오류 배너 (닫기 가능). */
export function formBanner(html) {
  const box = $('#form-banner');
  if (box) { box.innerHTML = html; if (html) box.querySelector('[role="alert"]')?.setAttribute('tabindex', '-1'); }
}

/** 탭 바 (N2) — 링크 목록 + aria-current. */
export const tabBar = (tabs, activeKey) => `<nav class="a-tabs" aria-label="탭">${tabs.map((t) =>
  `<a href="${t.href}" ${t.key === activeKey ? 'aria-current="page"' : ''}>${esc(t.label)}</a>`).join('')}</nav>`;

/** 필터 칩 (라디오 그룹) */
export const chipGroup = (label, items, active) =>
  `<div class="a-chips" role="radiogroup" aria-label="${esc(label)}">${items.map(([k, l]) =>
    `<button type="button" class="a-fchip" role="radio" aria-checked="${active === k}" data-f="${k}">${esc(l)}</button>`).join('')}</div>`;

/** 폼 변경 감지 도우미: 초기 스냅샷과 현재 값을 비교하는 dirty 등록. */
export function registerDirty(fn) { S.dirty = fn; }
export function clearDirty() { S.dirty = null; }

/** 날짜 시각 셀 */
export const timeCell = (v) => `<span class="a-num">${esc(fmtDateTime(v))}</span>`;

/* ============================================================================
   역할 공통 폼·카탈로그 위젯 — 메뉴 폼, 옵션 비활성 대화상자, 서브 카테고리/옵션 그룹 목록·편집.
   owner(개인 매장 메뉴 · 매장 분류) 와 brand(마스터 메뉴 · 점포 한정 메뉴 · 브랜드 분류)가 같은 모양을 쓴다.
   Firebase SDK 는 import 하지 않는다 (console-data.js 함수만 호출).

   [원칙]
   - 한 폼은 한 종류의 결과만 낸다 (design §2-1): 폼마다 `sections` 로 어떤 입력이 있는지 정해지고,
     입력이 없는 영역의 키는 payload 에 섞일 수 없다 (payload 빌더도 같은 키 집합만 받는다).
   - 낙관적 UI 없음. 실패해도 입력은 보존한다. 변경 감지는 서버에서 읽은 초기값과 비교한다.
   ========================================================================== */

import {
  saveSubCategory, saveOptionGroup, toggleActive, deleteSubOrOption, countSubCategoryUsage, countOptionGroupUsage, listAll, uploadImage,
} from './console-data.js';
import {
  esc, LIMITS, MENU_TAGS, parsePriceInput, parseIntInput, sameValue, checkImageFile, saveErrorText, optionItemKey,
} from './console-format.js';
import {
  S, hooks, $, $$, banner, emptyBlock, tableHtml, skelRows, errorBlock, openDialog, field, setFieldError, switchHtml, wireSwitch, saveBarHtml, setSaveBar, registerDirty, thumb, onReadFail, targetBlock,
} from './console-ui.js';

const clone = (x) => JSON.parse(JSON.stringify(x));
const refKey = (r) => `${r.scope}:${r.id}`;

/* ============================================================================
   옵션 비활성 대화상자 — 그룹 단위 / 항목 단위. 체크 = 고객에게 보임.
   disabledOptionItemIds 원소는 복합 id `{groupId}_{itemId}`, disabledOptionGroupIds 는 groupId 단독 (option_availability.dart).
   화면에 없는 기존 id(삭제된 그룹의 흔적 등)는 건드리지 않고 보존한다.
   ========================================================================== */
export function optionDisableDialog({ title, subtitle, groups, disabledGroupIds, disabledItemIds, applyLabel, onApply, trigger }) {
  const list = groups.filter(Boolean);
  const body = list.length === 0
    ? '<p class="a-cap">옵션 그룹이 없어요</p>'
    : `<p class="a-ask-sub">끄면 고객에게 노출되지 않습니다</p>${list.map((g) => `<fieldset class="a-optgrp" data-g="${esc(g.id)}">
        <legend><label class="a-check"><input type="checkbox" data-gcheck="${esc(g.id)}" ${disabledGroupIds.includes(g.id) ? '' : 'checked'}> <b>${esc(g.name || '(이름 없음)')}</b></label>
          ${g.active === false ? '<span class="a-chip">비활성 그룹</span>' : ''}</legend>
        <div class="a-optitems">${(g.items || []).length === 0 ? '<span class="a-cap">항목이 없어요</span>' : (g.items || []).map((it) => `
          <label class="a-check"><input type="checkbox" data-icheck="${esc(optionItemKey(g.id, it.id))}" ${disabledItemIds.includes(optionItemKey(g.id, it.id)) ? '' : 'checked'}> ${esc(it.label || '(이름 없음)')}
            ${it.priceDelta ? `<span class="a-cap a-num">${it.priceDelta > 0 ? '+' : ''}${esc(it.priceDelta.toLocaleString('ko-KR'))}원</span>` : ''}</label>`).join('')}</div></fieldset>`).join('')}`;
  const calc = (api) => {
    const shownG = new Set(list.map((g) => g.id));
    const shownI = new Set(list.flatMap((g) => (g.items || []).map((it) => optionItemKey(g.id, it.id))));
    const keepG = disabledGroupIds.filter((id) => !shownG.has(id));
    const keepI = disabledItemIds.filter((id) => !shownI.has(id));
    const offG = $$('[data-gcheck]', api.el).filter((c) => !c.checked).map((c) => c.dataset.gcheck);
    const offI = $$('[data-icheck]', api.el).filter((c) => !c.checked).map((c) => c.dataset.icheck);
    return { groupIds: [...keepG, ...offG], itemIds: [...keepI, ...offI] };
  };
  return openDialog({
    title, wide: true, trigger,
    bodyHtml: `${subtitle ? targetBlock(subtitle) : ''}${body}`,
    confirmLabel: applyLabel || '저장', noConfirm: list.length === 0,
    onConfirm: async (api) => { const r = calc(api); await onApply(r.groupIds, r.itemIds); },
  });
}

/* ============================================================================
   이미지 선택 (N7, 단일) — 선택 즉시 업로드하지 않는다. 저장 시점에 업로드 → Firestore 쓰기 (고아 파일 감소).
   ========================================================================== */
function imageFieldHtml(url, name) {
  return `<div class="a-field"><span class="a-label">메뉴 이미지</span>
    <div class="a-imgpick"><div id="mf-imgprev">${thumb(url, name, true)}</div>
      <div><input type="file" id="mf-file" accept="image/*" class="a-sr"><label for="mf-file" class="a-btn sm" id="mf-file-btn" tabindex="0" role="button">이미지 선택</label>
        <div class="a-help">최대 5MB</div></div></div><div class="a-field-err" id="mf-img-err" hidden></div></div>`;
}

/* ============================================================================
   메뉴 폼
   ========================================================================== */
/**
 * @param {object} o
 * @param {HTMLElement} o.box
 * @param {()=>boolean} o.alive
 * @param {object|null} o.initial          서버에서 읽은 메뉴 문서 (없으면 신규)
 * @param {boolean} o.isCreate
 * @param {{image?:boolean, core?:boolean, ops?:boolean, soldOut?:boolean, disabled?:boolean, requireImage?:boolean}} o.sections
 * @param {{mainCategories:Array, subCategories:Array, optionGroups:Array}} o.catalog
 * @param {string} o.targetName
 * @param {string} o.saveLabel
 * @param {(ctrl)=>void} o.onSubmit        검증을 통과하고 변경이 있을 때 호출된다
 * @param {()=>Promise<Array>} [o.loadDisableGroups]   옵션 비활성 대화상자에 보여줄 그룹 목록 로더
 */
export function menuForm(o) {
  const sec = o.sections;
  const it = o.initial || {};
  const norm = (m) => ({
    name: m.name ?? '', description: m.description ?? '', mainCategory: m.mainCategory ?? '', subCategoryId: m.subCategoryId ?? '',
    basePrice: m.basePrice === undefined || m.basePrice === null ? '' : String(m.basePrice),
    optionGroupRefs: Array.isArray(m.optionGroupRefs) ? m.optionGroupRefs.filter((r) => r && r.id).map((r) => ({ scope: r.scope || 'master', id: r.id })) : [],
    imageUrl: m.imageUrl ?? '', tags: Array.isArray(m.tags) ? [...m.tags] : [],
    visible: m.visible !== false, soldOut: m.soldOut === true,
    displayOrder: m.displayOrder === undefined ? '0' : String(m.displayOrder),
    disabledOptionGroupIds: Array.isArray(m.disabledOptionGroupIds) ? [...m.disabledOptionGroupIds] : [],
    disabledOptionItemIds: Array.isArray(m.disabledOptionItemIds) ? [...m.disabledOptionItemIds] : [],
  });
  const init = norm(it);
  let st = clone(init); st.imageFile = null; let imgPrev = null;
  let saving = false;
  const cat = o.catalog;

  const sortedRefs = (a) => a.map(refKey).sort();
  const sortedStr = (a) => [...a].sort();

  function changes() {
    const c = {};
    if (sec.core) {
      if (st.name.trim() !== init.name.trim()) c.name = st.name.trim();
      if (st.description.trim() !== init.description.trim()) c.description = st.description.trim();
      if (st.mainCategory !== init.mainCategory) c.mainCategory = st.mainCategory;
      if (st.subCategoryId !== init.subCategoryId) c.subCategoryId = st.subCategoryId;
      const p = parsePriceInput(st.basePrice, { required: true });
      if (st.basePrice.trim() !== init.basePrice.trim() && p.ok) c.basePrice = p.value;
      if (!sameValue(sortedRefs(st.optionGroupRefs), sortedRefs(init.optionGroupRefs))) c.optionGroupRefs = st.optionGroupRefs.map((r) => ({ ...r }));
    }
    if (sec.ops) {
      if (st.visible !== init.visible) c.visible = st.visible;
      if (!sameValue(sortedStr(st.tags), sortedStr(init.tags))) c.tags = [...st.tags];
      const d = parseIntInput(st.displayOrder, 0);
      if (st.displayOrder.trim() !== init.displayOrder.trim() && d.ok) c.displayOrder = d.value;
    }
    if (sec.image && st.imageFile) c.imageUrl = '(새 이미지)'; // 업로드 후 실제 URL 로 바뀐다 — 변경 개수 계산용 표식
    if (sec.soldOut && st.soldOut !== init.soldOut) c.soldOut = st.soldOut;
    if (sec.disabled) {
      if (!sameValue(sortedStr(st.disabledOptionGroupIds), sortedStr(init.disabledOptionGroupIds))) c.disabledOptionGroupIds = [...st.disabledOptionGroupIds];
      if (!sameValue(sortedStr(st.disabledOptionItemIds), sortedStr(init.disabledOptionItemIds))) c.disabledOptionItemIds = [...st.disabledOptionItemIds];
    }
    return c;
  }
  const count = () => { const n = Object.keys(changes()).length; return o.alwaysSavable ? Math.max(1, n) : n; };

  function validate() {
    const errs = {};
    if (sec.core) {
      if (!st.name.trim()) errs.name = '메뉴 이름을 입력해주세요';
      else if ([...st.name.trim()].length > LIMITS.menuName) errs.name = `이름은 ${LIMITS.menuName}자까지 입력할 수 있어요`;
      const p = parsePriceInput(st.basePrice, { required: true });
      if (!p.ok) errs.price = p.error;
      if (!st.mainCategory) errs.cat = '카테고리를 선택해주세요';
    }
    if (sec.ops) { const d = parseIntInput(st.displayOrder, 0); if (!d.ok) errs.order = d.error; }
    if (sec.requireImage && !st.imageFile && !st.imageUrl) errs.img = '이미지를 선택해주세요';
    return errs;
  }

  function showErrors(errs) {
    setFieldError('mf-name', errs.name); setFieldError('mf-price', errs.price); setFieldError('mf-order', errs.order);
    const ce = $('#mf-cat-err'); if (ce) { ce.hidden = !errs.cat; ce.textContent = errs.cat || ''; }
    const ie = $('#mf-img-err'); if (ie) { ie.hidden = !errs.img; ie.textContent = errs.img || ''; }
  }

  function refresh() {
    setSaveBar(count());
    const n = count();
    registerDirty(() => !saving && Object.keys(changes()).length > 0);
  }

  const catChips = () => cat.mainCategories.filter((c) => c.active || c.id === st.mainCategory)
    .map((c) => `<button type="button" class="a-fchip" role="radio" aria-checked="${st.mainCategory === c.id}" data-cat="${esc(c.id)}">${esc(c.label)}${c.active ? '' : ' (비활성)'}</button>`).join('');
  const subChips = () => {
    const subs = cat.subCategories.filter((s) => s.mainCategory === st.mainCategory && (s.active !== false || s.id === st.subCategoryId));
    if (!st.mainCategory || subs.length === 0) return '';
    return `<div class="a-field"><span class="a-label">서브 카테고리</span><div class="a-chips" role="radiogroup" aria-label="서브 카테고리">
      <button type="button" class="a-fchip" role="radio" aria-checked="${st.subCategoryId === ''}" data-sub="">없음</button>
      ${subs.map((s) => `<button type="button" class="a-fchip" role="radio" aria-checked="${st.subCategoryId === s.id}" data-sub="${esc(s.id)}">${esc(s.name)}</button>`).join('')}</div></div>`;
  };
  const optList = () => {
    const groups = cat.optionGroups.filter((g) => g.active !== false || st.optionGroupRefs.some((r) => r.id === g.id));
    if (groups.length === 0) return `<div class="a-cap">옵션 그룹이 없어요. 옵션 그룹 관리 화면에서 추가해보세요.</div>`;
    return groups.map((g) => `<label class="a-check"><input type="checkbox" data-og="${esc(refKey(g))}" ${st.optionGroupRefs.some((r) => r.scope === g.scope && r.id === g.id) ? 'checked' : ''}> ${esc(g.name || '(이름 없음)')}
      <span class="a-chip">${g.scope === 'master' ? '공통' : g.scope === 'brand' ? '브랜드' : '매장'}</span>${g.active === false ? '<span class="a-chip">비활성</span>' : ''}</label>`).join('');
  };

  function render() {
    const parts = [];
    if (sec.image) parts.push(`<div class="a-card">${imageFieldHtml(st.imageFile ? imgPrev : st.imageUrl, st.name || o.targetName)}</div>`);
    if (sec.core) {
      parts.push(`<div class="a-card"><h2>기본 정보</h2>
        ${field({ id: 'mf-name', label: '메뉴 이름', required: true, value: st.name, max: LIMITS.menuName, counter: true })}
        ${field({ id: 'mf-desc', label: '메뉴 설명', value: st.description, multiline: true, rows: 3, ph: '메뉴 설명을 입력해주세요 (선택)' })}
        ${field({ id: 'mf-price', label: '기본 가격', required: true, value: st.basePrice, attrs: 'inputmode="numeric"', help: '원 단위 정수' })}
        <div class="a-field"><span class="a-label">카테고리 (필수)</span><div class="a-chips" role="radiogroup" aria-label="카테고리" id="mf-cat">${catChips()}</div><div class="a-field-err" id="mf-cat-err" hidden></div></div>
        <div id="mf-sub">${subChips()}</div>
        <div class="a-field"><span class="a-label">옵션 그룹</span><div class="a-checklist" id="mf-og">${optList()}</div></div></div>`);
    }
    if (sec.ops || sec.soldOut || sec.disabled) {
      parts.push(`<div class="a-card"><h2>${sec.core ? '노출 설정' : '운영 설정'}</h2>
        ${sec.ops ? `<div class="a-field a-sw-row"><span class="a-label">노출</span>${switchHtml('mf-visible', st.visible, '노출')}<div class="a-help">끄면 손님에게 숨김 처리돼요</div></div>` : ''}
        ${sec.soldOut ? `<div class="a-field a-sw-row"><span class="a-label">품절</span>${switchHtml('mf-sold', st.soldOut, '품절')}</div>` : ''}
        ${sec.ops ? `<div class="a-field"><span class="a-label">태그</span><div class="a-chips" role="group" aria-label="태그" id="mf-tags">${MENU_TAGS.map(([k, l]) =>
          `<button type="button" class="a-fchip" role="checkbox" aria-checked="${st.tags.includes(k)}" data-tag="${k}">${esc(l)}</button>`).join('')}</div></div>
          ${field({ id: 'mf-order', label: '노출 순서', value: st.displayOrder, attrs: 'inputmode="numeric"', help: '숫자가 낮을수록 앞에 노출됩니다' })}` : ''}
        ${sec.disabled ? `<div class="a-field"><span class="a-label">옵션 비활성</span><button type="button" class="a-btn sm" id="mf-disable">옵션 비활성 설정…</button>
          <span class="a-cap" id="mf-disable-n"></span></div>` : ''}</div>`);
    }
    o.box.innerHTML = `<div id="form-banner"></div>${parts.join('')}${saveBarHtml({ targetName: o.targetName, saveLabel: o.saveLabel })}`;
    wire();
    updateDisableCount();
    refresh();
  }

  function updateDisableCount() {
    const el = $('#mf-disable-n'); if (!el) return;
    const n = st.disabledOptionGroupIds.length + st.disabledOptionItemIds.length;
    el.textContent = n > 0 ? `${n}개 비활성` : '비활성 없음';
  }

  function wire() {
    const bind = (id, key, after) => {
      const el = $(id); if (!el) return;
      el.addEventListener('input', () => { st[key] = el.value; if (after) after(el); refresh(); });
    };
    bind('#mf-name', 'name', (el) => { const c = $('#mf-name-cnt'); if (c) c.textContent = `${[...el.value].length} / ${LIMITS.menuName}`; });
    bind('#mf-desc', 'description'); bind('#mf-price', 'basePrice'); bind('#mf-order', 'displayOrder');
    ['mf-name', 'mf-price', 'mf-order'].forEach((id) => { const el = $(`#${id}`); if (el) el.addEventListener('blur', () => showErrors(validate())); });
    $$('[data-cat]').forEach((b) => { b.onclick = () => {
      if (st.mainCategory !== b.dataset.cat) { st.mainCategory = b.dataset.cat; st.subCategoryId = ''; }
      $('#mf-cat').innerHTML = catChips(); $('#mf-sub').innerHTML = subChips(); rewireChips(); refresh();
    }; });
    rewireChips();
    $$('[data-og]').forEach((c) => { c.onchange = () => {
      const [scope, ...rest] = c.dataset.og.split(':'); const id = rest.join(':');
      if (c.checked) { if (!st.optionGroupRefs.some((r) => r.scope === scope && r.id === id)) st.optionGroupRefs.push({ scope, id }); }
      else st.optionGroupRefs = st.optionGroupRefs.filter((r) => !(r.scope === scope && r.id === id));
      refresh();
    }; });
    $$('[data-tag]').forEach((b) => { b.onclick = () => {
      const on = b.getAttribute('aria-checked') !== 'true';
      b.setAttribute('aria-checked', String(on));
      st.tags = on ? [...new Set([...st.tags, b.dataset.tag])] : st.tags.filter((t) => t !== b.dataset.tag); refresh();
    }; });
    // 폼 안 스위치는 저장 버튼으로 묶여 제출되는 입력이다 — 즉시 쓰기가 아니다 (낙관적 UI 대상 아님)
    ['mf-visible:visible', 'mf-sold:soldOut'].forEach((p) => {
      const [id, key] = p.split(':'); const el = $(`#${id}`); if (!el) return;
      el.onclick = () => {
        st[key] = el.getAttribute('aria-checked') !== 'true';
        el.setAttribute('aria-checked', String(st[key])); el.querySelector('.a-sw-text').textContent = st[key] ? '켜짐' : '꺼짐'; refresh();
      };
    });
    const file = $('#mf-file');
    if (file) {
      file.onchange = () => {
        const f = file.files && file.files[0];
        const chk = f ? checkImageFile(f) : { ok: true };
        const ie = $('#mf-img-err');
        if (f && !chk.ok) { ie.hidden = false; ie.textContent = chk.error; file.value = ''; return; }
        if (ie) { ie.hidden = true; ie.textContent = ''; }
        if (!f) return;
        if (imgPrev) URL.revokeObjectURL(imgPrev);
        st.imageFile = f; imgPrev = URL.createObjectURL(f);
        $('#mf-imgprev').innerHTML = `<img class="a-thumb lg" src="${esc(imgPrev)}" alt="">`;
        refresh();
      };
      const btn = $('#mf-file-btn');
      if (btn) btn.onkeydown = (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); file.click(); } };
    }
    const dis = $('#mf-disable');
    if (dis) dis.onclick = async () => {
      dis.disabled = true; dis.textContent = '불러오는 중…';
      try {
        const groups = await o.loadDisableGroups();
        if (!o.alive()) return;
        optionDisableDialog({
          title: '옵션 비활성 설정', subtitle: o.targetName, groups, disabledGroupIds: st.disabledOptionGroupIds, disabledItemIds: st.disabledOptionItemIds,
          applyLabel: '적용 (저장 전까지 반영되지 않아요)', trigger: dis,
          onApply: async (g, i) => { st.disabledOptionGroupIds = g; st.disabledOptionItemIds = i; updateDisableCount(); refresh(); },
        });
      } catch (e) {
        console.error('[console] 옵션 그룹 조회 실패', e?.code || e);
        formBannerSet(banner('error', '', '옵션 그룹을 불러오지 못했어요. 잠시 후 다시 시도해주세요.'));
        onReadFail(e);
      } finally { dis.disabled = false; dis.textContent = '옵션 비활성 설정…'; }
    };
    $('#sb-save').onclick = () => {
      const errs = validate(); showErrors(errs);
      if (Object.keys(errs).length) {
        const first = ['mf-name', 'mf-price', 'mf-order'].find((id) => errs[{ 'mf-name': 'name', 'mf-price': 'price', 'mf-order': 'order' }[id]]);
        (first ? $(`#${first}`) : (errs.cat ? $('#mf-cat button') : $('#mf-file-btn')))?.focus();
        return;
      }
      if (count() === 0 || saving) return;
      o.onSubmit(ctrl);
    };
    $('#sb-reset').onclick = () => { st = clone(init); st.imageFile = null; if (imgPrev) { URL.revokeObjectURL(imgPrev); imgPrev = null; } render(); };
  }
  function rewireChips() {
    $$('[data-sub]').forEach((b) => { b.onclick = () => {
      st.subCategoryId = b.dataset.sub; $('#mf-sub').innerHTML = subChips(); rewireChips(); refresh();
    }; });
  }
  const formBannerSet = (html) => { const b = $('#form-banner'); if (b) b.innerHTML = html; };

  const ctrl = {
    changes, count, validate,
    /** 폼 값을 타입에 맞게 돌려준다 (신규 등록용 — 전체 값). */
    values() {
      const price = parsePriceInput(st.basePrice, { required: true });
      const order = parseIntInput(st.displayOrder, 0);
      return {
        name: st.name.trim(), description: st.description.trim(), mainCategory: st.mainCategory, subCategoryId: st.subCategoryId,
        basePrice: price.ok ? price.value : 0, optionGroupRefs: st.optionGroupRefs.map((r) => ({ ...r })), imageUrl: st.imageUrl,
        tags: [...st.tags], visible: st.visible, soldOut: st.soldOut, displayOrder: order.ok ? order.value : 0,
        disabledOptionGroupIds: [...st.disabledOptionGroupIds], disabledOptionItemIds: [...st.disabledOptionItemIds],
      };
    },
    imageFile: () => st.imageFile,
    initial: init,
    setBanner: formBannerSet,
    /** 이미지가 있으면 업로드해 URL 을 돌려준다. 실패하면 throw (Firestore 쓰기를 하지 않는다). */
    async uploadIfNeeded(pathPrefix) {
      if (!st.imageFile) return st.imageUrl;
      return uploadImage(pathPrefix, st.imageFile);
    },
    /** 저장 중 UI + 실패 시 입력 보존 배너. fn 이 성공하면 true. */
    async runSave(fn) {
      if (saving) return false;
      saving = true; formBannerSet('');
      const btn = $('#sb-save'); const label = btn.textContent;
      $$('input, textarea, button', o.box).forEach((el) => { el.disabled = true; }); btn.innerHTML = '<span class="a-spin"></span>저장 중…';
      S.busy = true;
      try { await fn(); return true; } catch (e) {
        console.error('[console] 메뉴 저장 실패', e?.stage || '', e?.code || e?.name || e);
        const t = e?.name === 'AdminError' && e.code === 'validation' ? { text: e.message, permission: false } : saveErrorText(e);
        formBannerSet(banner('error', '실패', t.text));
        if (t.permission) hooks.recheckRole();
        $('#form-banner [role="alert"]')?.setAttribute('tabindex', '-1');
        return false;
      } finally {
        S.busy = false; saving = false;
        $$('input, textarea, button', o.box).forEach((el) => { el.disabled = false; });
        const b2 = $('#sb-save'); if (b2) { b2.textContent = label; setSaveBar(count()); }
      }
    },
  };
  render();
  return ctrl;
}

/* ============================================================================
   서브 카테고리 / 옵션 그룹 — 목록 + 편집 모달 (OW9·OW10·BR10·BR11 공통)
   ========================================================================== */
const SEL_LABEL = { single: '단일', multi: '복수' };

export function catalogView({ kind, scope, ownerId, alive, box, mainCategories, notice }) {
  const isSub = kind === 'sub';
  const noun = isSub ? '서브 카테고리' : '옵션 그룹';
  const dupMsg = isSub ? '이미 같은 이름의 분류가 있어요' : '이미 같은 이름의 옵션 그룹이 있어요';
  let rows = [];
  const catLabel = (id) => mainCategories.find((c) => c.id === id)?.label || id || '-';

  async function load() {
    box.innerHTML = skelRows(6, 5);
    try {
      rows = await listAll([scope === 'brand' ? 'brands' : 'stores', ownerId], isSub ? 'subCategories' : 'optionGroups');
      if (!alive()) return;
      draw();
      const st = $('#stamp'); if (st) st.textContent = '';
    } catch (e) {
      console.error('[console] 목록 조회 실패', e?.code || e);
      if (!alive()) return;
      box.innerHTML = errorBlock(e);
      $('[data-retry]', box).onclick = load;
      onReadFail(e, box);
    }
  }

  function draw() {
    const addBtn = `<div class="a-toolbar"><button type="button" class="a-btn primary" id="cat-add">${noun} 추가</button></div>`;
    if (rows.length === 0) {
      box.innerHTML = `${addBtn}${emptyBlock(isSub ? '서브 카테고리가 없어요' : '옵션 그룹이 없어요', '')}`;
    } else {
      const heads = isSub ? ['이름', '메인 카테고리', '순서', '활성', ''] : ['이름', '선택 방식', '필수', '항목 수', '순서', '활성', ''];
      box.innerHTML = `${addBtn}${tableHtml(heads, rows.map((r) => `<tr>
        <td><strong>${esc(r.name || '(이름 없음)')}</strong></td>
        ${isSub ? `<td>${esc(catLabel(r.mainCategory))}</td>` : `<td>${esc(SEL_LABEL[r.selectionType] || r.selectionType || '-')}</td><td>${r.required ? '필수' : '선택'}</td><td class="a-num">${(r.items || []).length}</td>`}
        <td class="a-num">${esc(r.displayOrder ?? 0)}</td>
        <td class="a-sw-row">${switchHtml(`sw-${r.id}`, r.active !== false, `${r.name} 활성`, `data-id="${esc(r.id)}"`)}</td>
        <td class="a-actions"><button type="button" class="a-link" data-edit="${esc(r.id)}">편집</button> <button type="button" class="a-link" data-del="${esc(r.id)}">삭제…</button></td></tr>`))}`;
    }
    $('#cat-add').onclick = (e) => editDialog(null, e.currentTarget);
    $$('[data-edit]', box).forEach((b) => { b.onclick = () => editDialog(rows.find((x) => x.id === b.dataset.edit), b); });
    $$('[data-del]', box).forEach((b) => { b.onclick = () => deleteDialog(rows.find((x) => x.id === b.dataset.del), b); });
    $$('.a-switch', box).forEach((sw) => wireSwitch(sw, async (next) => { await toggleActive(scope, kind, ownerId, sw.dataset.id, next); }));
  }

  /* 편집 모달 */
  function editDialog(row, trigger) {
    const isNew = !row;
    let items = isSub ? [] : (row?.items || []).map((i) => ({ id: i.id, label: i.label || '', priceDelta: i.priceDelta || 0 }));
    let sel = row?.selectionType === 'multi' ? 'multi' : 'single';
    let required = row?.required === true; let active = row ? row.active !== false : true; let mainCat = row?.mainCategory || '';
    const cats = mainCategories.filter((c) => c.active || c.id === mainCat);
    const itemRows = () => items.map((it, i) => `<div class="a-itemrow"><input class="a-input" data-ilabel="${i}" value="${esc(it.label)}" placeholder="항목 이름" aria-label="항목 이름"><input class="a-input a-num" data-iprice="${i}" value="${esc(it.priceDelta)}" inputmode="numeric" aria-label="추가 금액"><button type="button" class="a-link" data-irm="${i}">삭제</button></div>`).join('');
    const body = `${field({ id: 'cg-name', label: `${noun} 이름`, required: true, value: row?.name || '', max: isSub ? LIMITS.subCategoryName : LIMITS.optionGroupName, counter: true })}
      ${isSub ? `<div class="a-field"><span class="a-label">메인 카테고리 (필수)</span><div class="a-chips" role="radiogroup" id="cg-cat">${cats.map((c) => `<button type="button" class="a-fchip" role="radio" aria-checked="${mainCat === c.id}" data-cat="${esc(c.id)}">${esc(c.label)}</button>`).join('')}</div><div class="a-field-err" id="cg-cat-err" hidden></div></div>`
        : `<div class="a-field"><span class="a-label">선택 방식</span><div class="a-chips" role="radiogroup" id="cg-sel">
            <button type="button" class="a-fchip" role="radio" aria-checked="${sel === 'single'}" data-sel="single">단일 선택</button>
            <button type="button" class="a-fchip" role="radio" aria-checked="${sel === 'multi'}" data-sel="multi">복수 선택</button></div></div>
          <div class="a-field"><label class="a-check"><input type="checkbox" id="cg-req" ${required ? 'checked' : ''}> 고객이 반드시 선택해야 주문 가능해요</label></div>
          <div class="a-field"><span class="a-label">항목 (이름 · 추가 금액)</span><div id="cg-items">${itemRows()}</div><button type="button" class="a-btn sm" id="cg-iadd">항목 추가</button><div class="a-field-err" id="cg-items-err" hidden></div></div>`}
      ${field({ id: 'cg-order', label: '표시 순서', value: String(row?.displayOrder ?? 0), attrs: 'inputmode="numeric"', help: '숫자가 낮을수록 앞에 표시돼요' })}
      <div class="a-field a-sw-row"><span class="a-label">활성</span>${switchHtml('cg-active', active, '활성')}</div>`;
    const getName = (api) => api.q('#cg-name').value;
    const errs = (api) => {
      const e = {};
      const name = getName(api).trim();
      if (!name) e.name = '이름을 입력해주세요';
      if (isSub && !mainCat) e.cat = '메인 카테고리를 선택해주세요';
      const o = parseIntInput(api.q('#cg-order').value, 0); if (!o.ok) e.order = o.error;
      if (!isSub) {
        if (items.length === 0 || items.some((i) => !i.label.trim())) e.items = '항목을 1개 이상 입력하고 이름을 비워두지 마세요';
        else if (new Set(items.map((i) => i.label.trim().toLowerCase())).size !== items.length) e.items = '같은 이름의 항목이 있어요. 확인 후 다시 저장해주세요';
        else if (items.some((i) => !Number.isSafeInteger(i.priceDelta))) e.items = '추가 금액은 정수로 입력해주세요';
      }
      return e;
    };
    const dlg = openDialog({
      title: isNew ? `${noun} 추가` : `${noun} 편집`, wide: !isSub, trigger, bodyHtml: body, confirmLabel: '저장',
      dirty: () => true,
      onOpen: (api) => {
        const nameEl = api.q('#cg-name');
        nameEl.addEventListener('input', () => { api.q('#cg-name-cnt').textContent = `${[...nameEl.value].length} / ${isSub ? LIMITS.subCategoryName : LIMITS.optionGroupName}`; });
        api.q('#cg-active').onclick = () => { active = !active; const b = api.q('#cg-active'); b.setAttribute('aria-checked', String(active)); b.querySelector('.a-sw-text').textContent = active ? '켜짐' : '꺼짐'; };
        if (isSub) {
          $$('[data-cat]', api.el).forEach((b) => { b.onclick = () => { mainCat = b.dataset.cat; $$('[data-cat]', api.el).forEach((x) => x.setAttribute('aria-checked', String(x.dataset.cat === mainCat))); }; });
        } else {
          $$('[data-sel]', api.el).forEach((b) => { b.onclick = () => { sel = b.dataset.sel; $$('[data-sel]', api.el).forEach((x) => x.setAttribute('aria-checked', String(x.dataset.sel === sel))); }; });
          api.q('#cg-req').onchange = (e) => { required = e.target.checked; };
          const bindItems = () => {
            api.q('#cg-items').innerHTML = itemRows();
            $$('[data-ilabel]', api.el).forEach((el) => { el.oninput = () => { items[Number(el.dataset.ilabel)].label = el.value; }; });
            $$('[data-iprice]', api.el).forEach((el) => { el.oninput = () => { const v = el.value.trim(); items[Number(el.dataset.iprice)].priceDelta = v === '' || v === '-' ? 0 : Number(v); if (!/^-?\d*$/.test(v)) items[Number(el.dataset.iprice)].priceDelta = NaN; }; });
            $$('[data-irm]', api.el).forEach((b) => { b.onclick = () => { items.splice(Number(b.dataset.irm), 1); bindItems(); }; });
          };
          bindItems();
          api.q('#cg-iadd').onclick = () => { items.push({ id: `new_${Date.now()}_${items.length}`, label: '', priceDelta: 0 }); bindItems(); api.q('#cg-items').querySelector('.a-itemrow:last-child input')?.focus(); };
        }
      },
      onConfirm: async (api) => {
        const e = errs(api);
        setFieldError('cg-name', e.name); setFieldError('cg-order', e.order);
        const ce = api.q('#cg-cat-err'); if (ce) { ce.hidden = !e.cat; ce.textContent = e.cat || ''; }
        const ie = api.q('#cg-items-err'); if (ie) { ie.hidden = !e.items; ie.textContent = e.items || ''; }
        if (Object.keys(e).length) return false;
        const form = { name: getName(api).trim(), displayOrder: parseIntInput(api.q('#cg-order').value, 0).value, active, mainCategory: mainCat, selectionType: sel, required, items };
        try {
          if (isSub) await saveSubCategory(scope, ownerId, form, row?.id || null);
          else await saveOptionGroup(scope, ownerId, form, row?.id || null);
        } catch (err) {
          if (err?.name === 'AdminError' && err.field === 'name') { setFieldError('cg-name', err.message || dupMsg); return false; } // 중복 이름은 필드 아래 인라인
          throw err;
        }
        await load();
        return true;
      },
    });
    void dlg;
  }

  /* 삭제 모달 — 사용 중이면 확정 버튼을 열지 않는다 */
  function deleteDialog(row, trigger) {
    let usage = null;
    openDialog({
      title: `${noun}를 삭제할까요?`, trigger, confirmLabel: '삭제', confirmClass: 'reject-confirm',
      bodyHtml: `${targetBlock(row.name)}<p class="a-ask">삭제된 ${noun}는 복구할 수 없어요.</p><div id="del-state" class="a-cap" role="status">사용 여부를 확인하고 있어요</div>`,
      onOpen: async (api) => {
        api.setConfirmEnabled(false);
        try {
          usage = isSub ? await countSubCategoryUsage(row.id) : await countOptionGroupUsage(scope, ownerId, row.id);
          if (typeof usage !== 'number' || !Number.isFinite(usage)) throw new Error('parse');
          if (!document.contains(api.el)) return;
          if (usage > 0) {
            api.q('#del-state').outerHTML = `<div class="a-banner warn" role="status"><p>${esc(usage)}개 메뉴에서 사용 중이라 삭제할 수 없어요</p></div>`;
            api.q('#dlg-ok').hidden = true;
          } else { api.q('#del-state').textContent = '사용 중인 메뉴가 없어요'; api.setConfirmEnabled(true); }
        } catch (e) {
          console.error('[console] 사용 수 조회 실패', e?.code || e);
          if (document.contains(api.el)) api.q('#del-state').outerHTML = '<div class="a-banner error" role="alert"><p>사용 여부를 확인하지 못해 삭제할 수 없어요</p></div>';
          onReadFail(e);
        }
      },
      onConfirm: async () => { await deleteSubOrOption(scope, kind, ownerId, row.id); await load(); },
    });
  }

  load();
  return { reload: load };
}

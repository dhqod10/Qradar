/* ============================================================================
   customer 섹션 — 아직 비어 있는 정식 섹션. 읽기 전용 3화면(프로필 · 주문 내역(Log) · Qoin) + 준비 중 자리.
   (Q6: 쓰기 없음. 이름 변경 등 쓰기 컨트롤을 두지 않는다.)

   ▸ "앱을 쓰세요" 로 돌려보내는 안내벽이 아니다. 고객이 오래 머물 공간의 첫 입주 3화면이다.
   ▸ 자동 로그아웃을 걸지 않는다 (spec §10.1). 공용 PC 방치는 명시 로그아웃 버튼 + Auth 기본 세션 만료로 다룬다.
   ▸ 확장 지점(DV-20): 뷰는 테이블 주도로 등록한다. 리뷰·게시글·QnA 는 아래 COMING 배열에서 카드 1장을 지우고,
     VIEWS 에 한 줄 추가하고, 뷰 함수를 하나 만드는 것으로 끝난다. 셸·네비·에러 분류·payload 가드는 다시 만지지 않는다.

   [보안] 숨김·탭 미노출은 편의다. 이 섹션의 모든 읽기는 users/{uid} 하위 본인 데이터이고 Rules 가 본인만 허용한다
   (firestore.rules:130 users read, :193 orderLogs read, :204 qoinTransactions read).
   ========================================================================== */

import {
  readUserProfile, listOrderLogs, listQoinTransactions,
} from './console-data.js';
import {
  esc, fmtDateTime, fmtClock, fmtKrw, fmtQoin, fmtQoinSigned, itemsSummary, providerText, displayNameOf, qoinTxText,
} from './console-format.js';
import {
  S, $, banner, emptyBlock, errorBlock, tableHtml, skelRows, headHtml, thumb, onReadFail, loadInto, kv,
} from './console-ui.js';

export const meta = { role: 'customer', defaultHash: '#/u/profile' };

/** 뷰 등록 표 — 해시 → 뷰 함수 + 네비 라벨. 새 기능은 여기에 한 줄 추가한다. */
const VIEWS = [
  { key: 'profile', hash: '#/u/profile', label: '프로필', run: (alive) => viewProfile(alive) },
  { key: 'log', hash: '#/u/log', label: '주문 내역 (Log)', run: (alive) => viewLog(alive) },
  { key: 'qoin', hash: '#/u/qoin', label: 'Qoin', run: (alive) => viewQoin(alive) },
];

/** 준비 중 카드 데이터 (CU1). 문구는 "~을 준비하고 있어요" 까지 — 날짜·순서·기능 약속 금지. */
const COMING = [
  { title: '리뷰', desc: '내가 남긴 평가를 이곳에서 모아 볼 수 있게 준비하고 있어요.' },
  { title: '게시글', desc: '다른 Qrator 와 이야기를 나누는 공간을 준비하고 있어요.' },
  { title: 'QnA', desc: '궁금한 점을 묻고 답을 확인하는 공간을 준비하고 있어요.' },
];

export const navGroups = () => [{ group: '내 정보', ro: true, items: VIEWS.map((v) => ({ key: v.key, href: v.hash, label: v.label })) }];
export const contextHtml = () => '';
export function start() {}
export function stop() {}

export function match(parts, alive) {
  if (parts[0] !== 'u') return null;
  const v = VIEWS.find((x) => x.key === parts[1]);
  return v ? { key: v.key, run: () => v.run(alive) } : null;
}

/* ── CU1 프로필 ──────────────────────────────────────────────────────────── */
function viewProfile(alive) {
  const v = $('#view');
  v.innerHTML = `${headHtml({ title: '프로필' })}<div id="cu-body"></div>
    <section class="a-section" aria-labelledby="soon-h"><h2 class="a-h2" id="soon-h">곧 이곳에서 만나요</h2>
      <p class="a-cap" style="margin:-8px 0 16px">Qrator 의 활동이 쌓일 자리예요. 지금은 준비하고 있어요.</p>
      <ul class="a-grid c3 a-soon">${COMING.map((c) => `<li class="a-soon-card"><div class="a-soon-head"><h3>${esc(c.title)}</h3><span class="a-chip">준비 중</span></div><p>${esc(c.desc)}</p></li>`).join('')}</ul></section>`;
  const load = () => loadInto($('#cu-body'), alive, () => readUserProfile(S.shell.uid), (d) => {
    const u = d.data;
    const name = displayNameOf({ displayName: u.displayName, email: u.email || S.shell.email });
    const hasBalance = d.exists && typeof u.qoinBalance === 'number' && Number.isFinite(u.qoinBalance);
    return `<div class="a-detail"><div class="a-detail-main"><div class="a-card"><h2>Qrator 프로필</h2>
        <div class="a-profile-head">${thumb(u.photoUrl, name, true)}<div class="a-profile-name">${esc(name)}</div></div>
        ${kv([['이메일', u.email || S.shell.email || '-'], ['가입 수단', providerText(u.provider)]])}
        ${d.exists ? '' : '<p class="a-cap" style="margin:12px 0 0">아직 프로필 정보가 없어요. 앱에서 프로필이 만들어지면 여기에 나타나요.</p>'}</div></div>
      <aside class="a-panel a-card"><h2 class="a-qdot">Qoin</h2>
        ${hasBalance ? `<div class="a-stat-num" style="font-size:34px;font-weight:800;line-height:1.2;margin:8px 0 2px">${esc(fmtQoin(u.qoinBalance))}</div><div class="a-cap">보유 Qoin (읽기 전용)</div>
          <div style="margin-top:12px"><a href="#/u/qoin">거래 내역 보기 →</a></div>` : '<div class="a-cap">Qoin 정보가 아직 없어요</div>'}</aside></div>`;
  });
  const stamp = (d) => { if (d && alive()) { const st = $('#stamp'); if (st) st.textContent = `마지막 갱신 ${fmtClock()}`; } };
  $('#refresh').onclick = () => load().then(stamp);
  load().then(stamp);
}

/* ── CU2 주문 내역 (Log) ─────────────────────────────────────────────────── */
/**
 * 열 구성은 users/{uid}/orderLogs 의 실제 필드로 확정했다 (lib/data/models/order_log_model.dart):
 *   paidAt · storeName · items[{menuItemName, quantity, lineTotal}] · total · paymentMethod.
 * Log 문서에는 status 필드가 없다 → 상태 열을 만들지 않는다 (DV-15: 없는 열은 뺀다).
 */
function viewLog(alive) {
  const v = $('#view');
  v.innerHTML = `${headHtml({ title: '주문 내역 (Log)', desc: '지금까지 Qradar 에 남긴 주문 기록이에요.' })}<div id="notice"></div><div id="box"></div><div id="more"></div>`;
  let all = []; let cursor = null; let hasMore = false;

  const draw = () => {
    $('#box').innerHTML = all.length === 0
      ? emptyBlock('아직 남긴 Log 가 없어요', '주문을 하면 Qradar 가 Log 로 남겨요')
      : tableHtml(['주문 일시', '매장', '주문 내용', '금액', '결제 수단'], all.map((r) => `<tr>
          <td class="a-num">${esc(fmtDateTime(r.paidAt))}</td><td>${esc(r.storeName || '-')}</td>
          <td class="a-ell" title="${esc(itemsSummary(r.items))}">${esc(itemsSummary(r.items))}</td>
          <td class="a-num">${esc(typeof r.total === 'number' ? fmtKrw(r.total) : '-')}</td><td>${esc(r.paymentMethod || '-')}</td></tr>`));
    $('#more').innerHTML = all.length === 0 ? '' : `<div class="a-pager"><span>${all.length}건 표시</span>${hasMore ? '<button type="button" class="a-btn sm" id="more-btn" style="margin-left:auto">더 보기</button>' : ''}</div>`;
    const mb = $('#more-btn');
    if (mb) mb.onclick = () => fetchMore(mb);
  };

  async function fetchMore(btn) {
    btn.disabled = true; btn.innerHTML = '<span class="a-spin"></span>불러오는 중…';
    try {
      const r = await listOrderLogs(S.shell.uid, cursor);
      if (!alive()) return;
      all = all.concat(r.rows); cursor = r.rows.length ? r.rows[r.rows.length - 1]._snap : cursor; hasMore = r.hasMore;
      draw();
    } catch (e) {
      console.error('[console] Log 더 보기 실패', e?.code || e);
      if (!alive()) return;
      btn.disabled = false; btn.textContent = '더 보기';
      $('#notice').innerHTML = banner('error', '', '더 불러오지 못했어요. 표는 그대로 유지돼요. 잠시 후 다시 시도해주세요.');
      onReadFail(e);
    }
  }

  const first = async () => {
    $('#box').innerHTML = skelRows(5, 8); $('#more').innerHTML = ''; $('#notice').innerHTML = '';
    try {
      const r = await listOrderLogs(S.shell.uid);
      if (!alive()) return;
      all = r.rows; cursor = r.rows.length ? r.rows[r.rows.length - 1]._snap : null; hasMore = r.hasMore;
      draw();
      const st = $('#stamp'); if (st) st.textContent = `마지막 갱신 ${fmtClock()}`;
    } catch (e) {
      console.error('[console] Log 조회 실패', e?.code || e);
      if (!alive()) return;
      $('#box').innerHTML = errorBlock(e);
      $('[data-retry]', $('#box')).onclick = first;
      onReadFail(e, $('#box'));
    }
  };
  $('#refresh').onclick = first;
  first();
}

/* ── CU3 Qoin ────────────────────────────────────────────────────────────── */
/**
 * 거래 원장은 append-only 로 서버만 쓴다(CF 전담, firestore.rules:205-207) — 편집·삭제 컨트롤이 없다.
 * 열: createdAt · type(모르는 값은 원문) · amount · balanceAfter · storeName (lib/data/models/qoin_transaction_model.dart).
 * 보유 카드와 거래 표는 서로 독립이다 (한쪽이 실패해도 다른 쪽을 가리지 않는다).
 */
function viewQoin(alive) {
  const v = $('#view');
  v.innerHTML = `${headHtml({ title: 'Qoin' })}<div id="q-bal"></div>
    <div class="a-section" style="margin-top:32px"><h2 class="a-h2">거래 내역</h2><div id="notice"></div><div id="box"></div><div id="more"></div></div>`;
  let all = []; let cursor = null; let hasMore = false;

  const loadBal = () => loadInto($('#q-bal'), alive, () => readUserProfile(S.shell.uid), (d) => {
    const b = d.data.qoinBalance;
    return `<div class="a-card" style="max-width:360px"><div class="a-cap a-qdot">보유 Qoin</div>${typeof b === 'number' && Number.isFinite(b)
      ? `<div class="a-qval a-num" style="font-size:34px;margin-top:8px">${esc(fmtQoin(b))}</div>` : '<div class="a-cap" style="margin-top:8px">Qoin 정보가 아직 없어요</div>'}</div>`;
  });

  const draw = () => {
    $('#box').innerHTML = all.length === 0
      ? emptyBlock('아직 Qoin 거래가 없어요', '주문이 완료되면 Qoin 이 적립돼요')
      : tableHtml(['일시', '구분', 'Qoin', '잔액', '매장'], all.map((r) => `<tr>
          <td class="a-num">${esc(fmtDateTime(r.createdAt))}</td><td>${esc(qoinTxText(r.type))}</td>
          <td class="a-num">${esc(fmtQoinSigned(r.amount))}</td><td class="a-num">${esc(fmtQoin(r.balanceAfter))}</td><td>${esc(r.storeName || '-')}</td></tr>`));
    $('#more').innerHTML = all.length === 0 ? '' : `<div class="a-pager"><span>${all.length}건 표시</span>${hasMore ? '<button type="button" class="a-btn sm" id="more-btn" style="margin-left:auto">더 보기</button>' : ''}</div>`;
    const mb = $('#more-btn');
    if (mb) mb.onclick = () => fetchMore(mb);
  };
  async function fetchMore(btn) {
    btn.disabled = true; btn.innerHTML = '<span class="a-spin"></span>불러오는 중…';
    try {
      const r = await listQoinTransactions(S.shell.uid, cursor);
      if (!alive()) return;
      all = all.concat(r.rows); cursor = r.rows.length ? r.rows[r.rows.length - 1]._snap : cursor; hasMore = r.hasMore;
      draw();
    } catch (e) {
      console.error('[console] Qoin 거래 더 보기 실패', e?.code || e);
      if (!alive()) return;
      btn.disabled = false; btn.textContent = '더 보기';
      $('#notice').innerHTML = banner('error', '', '더 불러오지 못했어요. 표는 그대로 유지돼요. 잠시 후 다시 시도해주세요.');
      onReadFail(e);
    }
  }
  const first = async () => {
    $('#box').innerHTML = skelRows(5, 6); $('#more').innerHTML = ''; $('#notice').innerHTML = '';
    try {
      const r = await listQoinTransactions(S.shell.uid);
      if (!alive()) return;
      all = r.rows; cursor = r.rows.length ? r.rows[r.rows.length - 1]._snap : null; hasMore = r.hasMore;
      draw();
    } catch (e) {
      console.error('[console] Qoin 거래 조회 실패', e?.code || e);
      if (!alive()) return;
      $('#box').innerHTML = errorBlock(e);
      $('[data-retry]', $('#box')).onclick = first;
      onReadFail(e, $('#box'));
    }
  };
  $('#refresh').onclick = () => { loadBal(); first().then(() => { const st = $('#stamp'); if (st && alive()) st.textContent = `마지막 갱신 ${fmtClock()}`; }); };
  loadBal(); first().then(() => { const st = $('#stamp'); if (st && alive()) st.textContent = `마지막 갱신 ${fmtClock()}`; });
}


/* ============================================================================
   Qradar 랜딩 — 사업자 정보 단일 진실원
   ----------------------------------------------------------------------------
   ★★ 아래 BIZ 객체의 값만 서류(사업자등록증 / 통신판매업 신고증) 그대로 채우면
      index / terms / privacy / refund 4개 페이지의 모든 표기가 한 번에 바뀝니다.
      토스페이먼츠 심사는 "홈페이지 하단 상호명·주소·대표자명"이 사업자등록증과
      한 글자라도 다르면 반려되므로, 띄어쓰기까지 서류와 동일하게 입력하세요.
   ========================================================================== */

const BIZ = {
  // ── 사업자등록증 기재사항 (서류와 100% 일치) ──────────────────────────────
  company:      '티엠아이',
  ceo:          '김현우',
  bizNo:        '283-22-00820',            // 사업자등록번호
  mailOrderNo:  '제2026-서울성북-1340호',   // 통신판매업 신고번호
  address:      '서울특별시 성북구 정릉로38바길 22 (02816)', // 사업장 주소 (우편번호 포함)

  // ── 고객 응대 ────────────────────────────────────────────────────────────
  tel:          '010-9535-5886',
  email:        'tmibourne@gmail.com',
  hours:        '평일 10:00 ~ 18:00 (주말·공휴일 휴무, 점심 12:00 ~ 13:00)',

  // ── 개인정보 ─────────────────────────────────────────────────────────────
  privacyOfficer:      '김현우',
  privacyOfficerTitle: '대표',
  privacyEmail:        'tmibourne@gmail.com',

  // ── 고정값 (변경 불필요) ─────────────────────────────────────────────────
  hosting:      'Google Cloud Platform (Firebase Hosting)',
  pg:           '토스페이먼츠 주식회사',
  termsDate:    '2026년 10월 28일',   // 약관 시행일
  privacyDate:  '2026년 10월 28일',   // 개인정보처리방침 시행일
};

/* ── 사업자정보확인 링크 (국세청 통신판매사업자 조회) ───────────────────── */
const MAIL_ORDER_LOOKUP = 'https://www.ftc.go.kr/bizCommPop.do?wrkr_no=' +
  BIZ.bizNo.replace(/[^0-9]/g, '');

/* ── 공통 헤더 ───────────────────────────────────────────────────────────── */
const Q_LOGO_SVG = `
<svg class="qlogo" viewBox="0 0 100 100" aria-hidden="true">
  <path d="M 73.09 79.55 A 37.5 37.5 0 1 1 87.5 50 L 75 50 A 25 25 0 1 0 65.39 69.70 Z" fill="currentColor"/>
  <path d="M 69.09 60.61 L 97.73 89.24 L 80.75 89.24 L 52.12 60.61 Z" fill="currentColor"/>
</svg>`;

function renderHeader() {
  const here = location.pathname.split('/').pop() || 'index.html';
  const nav = [
    ['index.html#service',  '서비스 소개'],
    ['index.html#howto',    '이용 방법'],
    ['index.html#menu',     '메뉴 · 가격'],
    ['refund.html',         '취소 · 환불'],
    ['index.html#support',  '고객센터'],
  ];
  return `
<a class="skip" href="#main">본문으로 바로가기</a>
<header class="site-head">
  <div class="wrap head-inner">
    <a class="brand" href="index.html" aria-label="Qradar 홈">
      ${Q_LOGO_SVG}<span class="brand-word">radar</span>
    </a>
    <nav aria-label="주요 메뉴">
      <ul>${nav.map(([href, label]) => {
        const on = here === href.split('#')[0] && !href.includes('#') ? ' class="on"' : '';
        return `<li><a href="${href}"${on}>${label}</a></li>`;
      }).join('')}</ul>
    </nav>
  </div>
</header>`;
}

/* ── 사업자 정보 보정 ─────────────────────────────────────────────────────
   푸터와 본문의 사업자 정보는 각 HTML 에 **정적으로 박혀 있다** (PG 심사 요건:
   JS 가 꺼져 있거나 크롤러로 열어도 하단 표기가 보여야 한다).
   아래 함수들은 BIZ 를 단일 진실원으로 유지하기 위한 보정이다 — BIZ 값을 고치면
   정적 텍스트가 무엇이든 런타임에 BIZ 값으로 덮어쓴다.
   ⚠️ BIZ 를 고쳤으면 각 HTML 의 정적 값도 함께 고칠 것 (JS off 대비).
   ---------------------------------------------------------------------- */
function fillBiz() {
  document.querySelectorAll('[data-biz]').forEach((el) => {
    const key = el.getAttribute('data-biz');
    if (key in BIZ) el.textContent = BIZ[key];
  });
}

/* 링크 href 보정: data-biz-href="tel|email|lookup" */
function fillBizHref() {
  const href = {
    tel:    () => 'tel:' + BIZ.tel.replace(/[^0-9+]/g, ''),
    email:  () => 'mailto:' + BIZ.email,
    lookup: () => MAIL_ORDER_LOOKUP,
  };
  document.querySelectorAll('[data-biz-href]').forEach((el) => {
    const key = el.getAttribute('data-biz-href');
    if (key in href) el.setAttribute('href', href[key]());
  });
}

/* 저작권 연도 보정: <span data-biz-year>2026</span> */
function fillBizYear() {
  document.querySelectorAll('[data-biz-year]').forEach((el) => {
    el.textContent = String(new Date().getFullYear());
  });
}

document.addEventListener('DOMContentLoaded', () => {
  const head = document.getElementById('site-header');
  if (head) head.innerHTML = renderHeader();
  fillBiz();
  fillBizHref();
  fillBizYear();
});

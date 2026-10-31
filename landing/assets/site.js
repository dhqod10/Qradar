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

/* ── 공통 푸터 (토스 심사 필수 표기 전부) ────────────────────────────────── */
function renderFooter() {
  return `
<footer class="site-foot">
  <div class="wrap">
    <nav class="foot-links" aria-label="약관 및 정책">
      <a href="terms.html">이용약관</a>
      <a href="privacy.html"><strong>개인정보처리방침</strong></a>
      <a href="refund.html">취소 · 환불 정책</a>
      <a href="index.html#support">고객센터</a>
    </nav>

    <dl class="biz">
      <div><dt>상호명</dt><dd>${BIZ.company}</dd></div>
      <div><dt>대표자명</dt><dd>${BIZ.ceo}</dd></div>
      <div><dt>사업자등록번호</dt><dd>${BIZ.bizNo}</dd></div>
      <div><dt>통신판매업 신고번호</dt><dd>${BIZ.mailOrderNo}
        <a class="lookup" href="${MAIL_ORDER_LOOKUP}" target="_blank" rel="noopener noreferrer">사업자정보 확인</a></dd></div>
      <div class="wide"><dt>사업장 주소</dt><dd>${BIZ.address}</dd></div>
      <div><dt>고객센터</dt><dd><a href="tel:${BIZ.tel.replace(/[^0-9+]/g, '')}">${BIZ.tel}</a></dd></div>
      <div><dt>이메일</dt><dd><a href="mailto:${BIZ.email}">${BIZ.email}</a></dd></div>
      <div class="wide"><dt>운영시간</dt><dd>${BIZ.hours}</dd></div>
      <div><dt>개인정보보호책임자</dt><dd>${BIZ.privacyOfficer} (${BIZ.privacyOfficerTitle})</dd></div>
      <div><dt>호스팅서비스 제공자</dt><dd>${BIZ.hosting}</dd></div>
    </dl>

    <p class="foot-note">
      ${BIZ.company}는 통신판매중개자가 아닌 통신판매업자로서, Qradar 앱을 통해 주문·결제된
      상품의 제공 및 환불에 대한 책임을 부담합니다. 결제 대행은 ${BIZ.pg}를 통해 이루어집니다.
    </p>
    <p class="copy">© ${new Date().getFullYear()} ${BIZ.company}. All rights reserved.</p>
  </div>
</footer>`;
}

/* ── 본문 내 사업자 정보 치환: <span data-biz="company"></span> ──────────── */
function fillBiz() {
  document.querySelectorAll('[data-biz]').forEach((el) => {
    const key = el.getAttribute('data-biz');
    if (key in BIZ) el.textContent = BIZ[key];
  });
}

document.addEventListener('DOMContentLoaded', () => {
  const head = document.getElementById('site-header');
  const foot = document.getElementById('site-footer');
  if (head) head.innerHTML = renderHeader();
  if (foot) foot.innerHTML = renderFooter();
  fillBiz();
});

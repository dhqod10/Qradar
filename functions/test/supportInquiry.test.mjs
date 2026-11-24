import test from 'node:test';
import assert from 'node:assert/strict';
import {
  runCreateSupportInquiry, parseCreateInput, attachmentsBelongTo, nextLimitState,
} from '../lib/createSupportInquiry.js';
import { runModerateSupportInquiry } from '../lib/moderateSupportInquiry.js';

const url = (path) => `https://firebasestorage.googleapis.com/v0/b/bkt/o/${encodeURIComponent(path)}?alt=media&token=t`;
const base = { inquiryId: 'inq1', category: 'order', title: ' 제목 ', body: '내용' };

function createPorts({ inquiry = null, user = { role: 'customer' }, order = null, limit = null } = {}) {
  const st = { docs: new Map(), limit, commits: 0 };
  return {
    st,
    projectBucket() { return 'bkt'; },
    async readInquiry() { return inquiry; },
    async readUser() { return user; },
    async readOrder() { return order; },
    async commit({ uid, nowMs, doc }) {
      const next = nextLimitState(st.limit, nowMs);
      if (!next) return 'rate_limited';
      st.limit = next; st.commits++; st.doc = doc; return 'created';
    },
  };
}
const run = (p, data, nowMs = 1_000_000) => runCreateSupportInquiry(p, { uid: 'u1', data, nowMs });
const token = (tok) => (e) => e.details?.reason === tok || String(e.message).includes(`[${tok}]`);

test('create: 정상 — trim, status open, authorRole 박제', async () => {
  const p = createPorts();
  const r = await run(p, base);
  assert.deepEqual(r, { inquiryId: 'inq1', created: true });
  assert.equal(p.st.doc.title, '제목');
  assert.equal(p.st.doc.status, 'open');
  assert.equal(p.st.doc.authorDeleted, false);
});
test('create: 같은 inquiryId + 내 문서 → 멱등 성공, 카운터 안 센다', async () => {
  const p = createPorts({ inquiry: { userId: 'u1' } });
  assert.deepEqual(await run(p, base), { inquiryId: 'inq1', created: false });
  assert.equal(p.st.commits, 0);
});
test('create: 남의 inquiryId → already-exists', async () => {
  await assert.rejects(run(createPorts({ inquiry: { userId: 'other' } }), base), (e) => e.code === 'already-exists');
});
test('create: 입력 검증 경계 (제목 60/61, 본문 2000/2001, 공백만, 잘못된 category, / 포함 id)', async () => {
  const ok = (o) => parseCreateInput({ ...base, ...o });
  ok({ title: 'a'.repeat(60) }); ok({ body: 'a'.repeat(2000) });
  for (const o of [{ title: 'a'.repeat(61) }, { body: 'a'.repeat(2001) }, { title: '   ' }, { body: '' }, { category: 'x' }, { inquiryId: 'a/b' }, { inquiryId: '' }, { imageUrls: ['a', 'b', 'c', 'd'] }, { imageUrls: [1] }, { orderId: 'a/b' }]) {
    assert.throws(() => ok(o), token('SUPPORT_INVALID_INPUT'), JSON.stringify(o).slice(0, 40));
  }
});
test('create: deleted 계정 거부 / suspended 는 허용(Q7)', async () => {
  await assert.rejects(run(createPorts({ user: { deleted: true } }), base), token('SUPPORT_ACCOUNT_DELETED'));
  const r = await run(createPorts({ user: { role: 'customer', suspended: true } }), base);
  assert.equal(r.created, true);
});
test('create: 첨부 — 자기 경로 3장 허용, 남의 uid·남의 inquiryId·외부 URL·.. 거부', async () => {
  const mine = (n) => url(`support_inquiries/u1/inq1/${n}.jpg`);
  const r = await run(createPorts(), { ...base, imageUrls: [mine(1), mine(2), mine(3)] });
  assert.equal(r.created, true);
  for (const bad of [url('support_inquiries/other/inq1/a.jpg'), url('support_inquiries/u1/inq9/a.jpg'), url('store_images/a.jpg'), 'https://evil.example/o/a.jpg', url('support_inquiries/u1/inq1/../x.jpg')]) {
    await assert.rejects(run(createPorts(), { ...base, imageUrls: [mine(1), bad] }), token('SUPPORT_INVALID_ATTACHMENT'));
  }
  assert.equal(attachmentsBelongTo([], 'u1', 'inq1', 'bkt'), true);
  assert.equal(attachmentsBelongTo([], 'u1', 'inq1', null), true);
});
test('create: 첨부 — 경로만 같고 bucket 이 다른 URL 거부 (D2), bucket 미확인이면 fail-closed', async () => {
  const path = 'support_inquiries/u1/inq1/a.jpg';
  const mine = `https://firebasestorage.googleapis.com/v0/b/bkt/o/${encodeURIComponent(path)}?alt=media&token=t`;
  const evil = `https://firebasestorage.googleapis.com/v0/b/evil-bucket/o/${encodeURIComponent(path)}?alt=media&token=t`;
  await assert.rejects(run(createPorts(), { ...base, imageUrls: [mine, evil] }), token('SUPPORT_INVALID_ATTACHMENT'));
  assert.equal(attachmentsBelongTo([mine], 'u1', 'inq1', 'bkt'), true);
  assert.equal(attachmentsBelongTo([evil], 'u1', 'inq1', 'bkt'), false);
  assert.equal(attachmentsBelongTo([mine], 'u1', 'inq1', null), false);
  const p = createPorts(); p.projectBucket = () => null;
  await assert.rejects(run(p, { ...base, imageUrls: [mine] }), token('SUPPORT_INVALID_ATTACHMENT'));
});
test('create: 주문 — 남의 주문/없는 주문 같은 응답, 본인 주문은 스냅샷 박제', async () => {
  await assert.rejects(run(createPorts({ order: null }), { ...base, orderId: 'o1' }), token('SUPPORT_ORDER_NOT_FOUND'));
  await assert.rejects(run(createPorts({ order: { userId: 'other' } }), { ...base, orderId: 'o1' }), token('SUPPORT_ORDER_NOT_FOUND'));
  const p = createPorts({ order: { userId: 'u1', storeId: 's1', storeName: '카페', pickupNumber: 7, totalPrice: 4500, status: 'completed' } });
  await run(p, { ...base, orderId: 'o1' });
  assert.deepEqual({ ...p.st.doc.orderSnapshot, createdAt: undefined }, { storeId: 's1', storeName: '카페', pickupNumber: 7, totalPrice: 4500, status: 'completed', createdAt: undefined });
});
test('create: rate limit — 분당 2번째 거부, 1분 후 허용, 일 6번째 거부', async () => {
  const p = createPorts();
  const T = 10_000_000;
  await run(p, base, T);
  await assert.rejects(run(p, { ...base, inquiryId: 'inq2' }, T + 30_000), token('SUPPORT_RATE_LIMITED'));
  await run(p, { ...base, inquiryId: 'inq3' }, T + 60_000);      // 정확히 60s → 새 분 창
  await run(p, { ...base, inquiryId: 'inq4' }, T + 120_000);
  await run(p, { ...base, inquiryId: 'inq5' }, T + 180_000);
  await run(p, { ...base, inquiryId: 'inq6' }, T + 240_000);      // 일 5건째
  await assert.rejects(run(p, { ...base, inquiryId: 'inq7' }, T + 300_000), token('SUPPORT_RATE_LIMITED'));
  await run(p, { ...base, inquiryId: 'inq8' }, T + 24 * 3600_000 + 1); // 24h 경과 → 허용
});
test('create: 형식 오류는 rate limit 을 소모하지 않는다', async () => {
  const p = createPorts();
  await assert.rejects(run(p, { ...base, title: '' }));
  assert.equal(p.st.limit, null);
});

// ── moderate ──
function modPorts(doc) {
  const st = { doc: doc && { ...doc } };
  return {
    st,
    async update(id, decide) {
      if (!st.doc) return null;
      const { patch, result } = decide(st.doc);
      if (patch) Object.assign(st.doc, patch);
      return result;
    },
  };
}
const mod = (p, data) => runModerateSupportInquiry(p, { adminUid: 'adm', data });
test('moderate: open → answered, answeredBy 기록, 재답변 거부(append-only)', async () => {
  const p = modPorts({ status: 'open' });
  assert.deepEqual(await mod(p, { inquiryId: 'i', action: 'answer', body: ' 답변 ' }), { changed: true, status: 'answered' });
  assert.equal(p.st.doc.answer.body, '답변');
  assert.equal(p.st.doc.answer.answeredBy, 'adm');
  await assert.rejects(mod(p, { inquiryId: 'i', action: 'answer', body: '또' }), token('SUPPORT_ALREADY_ANSWERED'));
  assert.equal(p.st.doc.answer.body, '답변');
});
test('moderate: withdrawn/closed 는 답변 불가 [NOT_OPEN]', async () => {
  for (const status of ['withdrawn', 'closed']) {
    await assert.rejects(mod(modPorts({ status }), { inquiryId: 'i', action: 'answer', body: 'x' }), token('SUPPORT_NOT_OPEN'));
  }
});
test('moderate: close — 사유 필수, open|answered 허용, closed 재호출 no-op, withdrawn 거부', async () => {
  await assert.rejects(mod(modPorts({ status: 'open' }), { inquiryId: 'i', action: 'close' }), token('SUPPORT_INVALID_INPUT'));
  await assert.rejects(mod(modPorts({ status: 'open' }), { inquiryId: 'i', action: 'close', closedReason: 'account_deleted' }), token('SUPPORT_INVALID_INPUT'));
  const p = modPorts({ status: 'answered', answer: { body: 'a' } });
  assert.deepEqual(await mod(p, { inquiryId: 'i', action: 'close', closedReason: 'spam' }), { changed: true, status: 'closed' });
  assert.equal(p.st.doc.closedBy, 'adm');
  assert.deepEqual(await mod(p, { inquiryId: 'i', action: 'close', closedReason: 'spam' }), { changed: false, status: 'closed' });
  await assert.rejects(mod(modPorts({ status: 'withdrawn' }), { inquiryId: 'i', action: 'close', closedReason: 'spam' }), token('SUPPORT_NOT_OPEN'));
});
test('moderate: 입력 검증 (본문 2000/2001, 빈 본문, 문서 없음)', async () => {
  await mod(modPorts({ status: 'open' }), { inquiryId: 'i', action: 'answer', body: 'a'.repeat(2000) });
  await assert.rejects(mod(modPorts({ status: 'open' }), { inquiryId: 'i', action: 'answer', body: 'a'.repeat(2001) }));
  await assert.rejects(mod(modPorts({ status: 'open' }), { inquiryId: 'i', action: 'answer', body: '  ' }));
  await assert.rejects(mod(modPorts(null), { inquiryId: 'i', action: 'answer', body: 'x' }), (e) => e.code === 'not-found');
});

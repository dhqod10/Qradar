// payment_server_authority — 교차 골든 (Dart 와 같은 fixture 3종). `npm test` (functions/ 에서). 환경 불필요.
//  Dart 쪽: test/core/payment_authority_contract_test.dart
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { canSellNow, storeGateReason, evaluateStoreOpenState, isStoreOpenNow, parseWeeklyHours } from '../lib/storeSellability.js';
import { applyOverrideForCustomer, classifyCartMenu } from '../lib/menuVisibility.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const load = (n) => JSON.parse(fs.readFileSync(path.join(here, '../../test_fixtures', n), 'utf8'));

const visibility = load('menu_visibility_contract.json');
const sellability = load('store_sellability_contract.json');
const gate = load('checkout_menu_gate_contract.json');

test('골든 fixture 가 비어 있지 않다', () => {
  assert.ok(visibility.cases.length >= 8);
  assert.ok(sellability.cases.length >= 8);
  assert.ok(sellability.openStateCases.length >= 20);
  assert.ok(sellability.parseCases.length >= 8);
  assert.ok(gate.cases.length >= 8);
});

for (const c of visibility.cases) {
  test(`menu_visibility: ${c.name}`, () => {
    const r = applyOverrideForCustomer({ master: c.master, override: c.override });
    assert.deepEqual(r, c.expect);
  });
}

for (const c of sellability.cases) {
  test(`store_sellability: ${c.name}`, () => {
    const input = { rawStatus: c.rawStatus, hasApprovedAt: c.hasApprovedAt, temporaryClosed: c.temporaryClosed, scheduleClosedNow: c.scheduleClosedNow };
    assert.equal(storeGateReason(input), c.expectReason);
    assert.equal(canSellNow(input), c.expect);
  });
}

for (const c of sellability.openStateCases) {
  test(`store_open_state: ${c.name}`, () => {
    const args = {
      weeklyHours: c.weeklyHours,
      closedDateKeys: new Set(c.closedDateKeys),
      nowWeekday: c.now.weekday,
      nowMinuteOfDay: c.now.minuteOfDay,
      nowDateKey: c.now.dateKey,
    };
    const r = evaluateStoreOpenState(args);
    assert.deepEqual(
      { kind: r.kind, isOpen: r.isOpen, nextOpenAt: r.nextOpenAt, closeAt: r.closeAt, todayRange: r.todayRange },
      c.expect
    );
    assert.equal(isStoreOpenNow(args), c.expect.isOpen);
  });
}

for (const c of sellability.parseCases) {
  test(`business_hours_parse: ${c.name}`, () => {
    assert.deepEqual(parseWeeklyHours(c.raw), c.expect);
  });
}

const verdictOf = (r) => (r.reason === null ? 'OK' : r.reason);
for (const c of gate.cases) {
  test(`checkout_menu_gate: ${c.name}`, () => {
    const r = classifyCartMenu({ hasBrand: c.hasBrand, storeMenu: c.storeMenu, master: c.master, override: c.override });
    assert.equal(verdictOf(r), c.expect);
  });
}

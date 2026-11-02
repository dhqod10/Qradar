// qoinRateReconstruct.ts 순수 로직 단위 테스트 (point-in-time 재구성). 환경 불필요.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { reconstructRate } from '../lib/qoinRateReconstruct.js';

const h = (field, ms, before, beforeState, after) => ({ field, changedAtMs: ms, before, beforeState, beforeRaw: null, after });
const layer = (history = [], currentRate, currentSwitch) => ({ history, currentRate, currentSwitch });
const T = 1000;

test('전역 요율이 완료 후 바뀌어도 완료 시점 값', () => {
  const g = layer([h('accrualRate', 500, null, 'absent', 0.03), h('accrualRate', 2000, 0.03, 'value', 0.05)], 0.05);
  const r = reconstructRate({ anchorMs: T, store: layer(), brand: null, global: g, ignoreSwitch: false });
  assert.equal(r.status, 'ok'); assert.equal(r.rate, 0.03); assert.equal(r.source, 'global');
});

test('anchor 이전 항목 없고 이후 최초 항목의 before 사용', () => {
  const g = layer([h('accrualRate', 2000, 0.03, 'value', 0.05)], 0.05);
  const r = reconstructRate({ anchorMs: T, store: null, brand: null, global: g, ignoreSwitch: false });
  assert.equal(r.status, 'ok'); assert.equal(r.rate, 0.03);
});

test('매장 clear 후 상속 / 매장 값 우선', () => {
  const g = layer([h('accrualRate', 100, null, 'absent', 0.02)], 0.02);
  const s = layer([h('accrualRate', 200, null, 'absent', 0.1), h('accrualRate', 300, 0.1, 'value', null)], undefined);
  assert.equal(reconstructRate({ anchorMs: 250, store: s, brand: null, global: g, ignoreSwitch: false }).source, 'store');
  const r = reconstructRate({ anchorMs: T, store: s, brand: null, global: g, ignoreSwitch: false });
  assert.equal(r.source, 'global'); assert.equal(r.rate, 0.02);
});

test('이력 없음 + 현재값 존재 = 복원 불가 (fail-closed)', () => {
  const g = layer([h('accrualRate', 100, null, 'absent', 0.02)], 0.02);
  const r = reconstructRate({ anchorMs: T, store: layer([], 0.07), brand: null, global: g, ignoreSwitch: false });
  assert.equal(r.status, 'unrecoverable');
});

test('전역 이력 없음 = 복원 불가', () => {
  const r = reconstructRate({ anchorMs: T, store: null, brand: null, global: layer([], 0.03), ignoreSwitch: false });
  assert.equal(r.status, 'unrecoverable');
  const r2 = reconstructRate({ anchorMs: T, store: null, brand: null, global: layer([], undefined), ignoreSwitch: false });
  assert.equal(r2.status, 'unrecoverable');
});

test('스위치 off 기간: 기본 disabled, ignoreSwitch 면 그 시점 rate', () => {
  const g = layer([h('accrualRate', 100, null, 'absent', 0.02)], 0.02);
  const s = layer([h('accrualEnabled', 200, null, 'absent', false)], undefined, false);
  assert.equal(reconstructRate({ anchorMs: T, store: s, brand: null, global: g, ignoreSwitch: false }).status, 'disabled');
  const r = reconstructRate({ anchorMs: T, store: s, brand: null, global: g, ignoreSwitch: true });
  assert.equal(r.status, 'ok'); assert.equal(r.rate, 0.02);
});

test('당시 값이 무효(invalid before)면 복원 불가', () => {
  const e = { field: 'accrualRate', changedAtMs: 2000, before: null, beforeState: 'invalid', beforeRaw: '"3"', after: 0.03 };
  const g = layer([e], 0.03);
  assert.equal(reconstructRate({ anchorMs: T, store: null, brand: null, global: g, ignoreSwitch: false }).status, 'unrecoverable');
});

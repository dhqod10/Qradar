// store_category_optout Phase B — availableMainCategories 순수 계산 + 트리거 게이트 + 소스 가드.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  computeAvailableMainCategories as compute, sameCodeSet, masterMenuRelevance,
} from '../lib/availableCategories.js';
import { storeDocNeedsRecompute, effectiveActive } from '../lib/onAvailableCategoriesWritten.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const src = (n) => fs.readFileSync(path.join(here, '../src', n), 'utf8');
const active = new Set(['coffee', 'dessert', 'nonCoffee']);
const base = { storeOwnMenus: [], brandMasterMenus: null, storeOverrides: new Map(), activeCodes: active, excludedByStore: [] };
const master = (id, mainCategory, extra = {}) => ({ id, data: { mainCategory, basePrice: 1000, ...extra } });

test('개인 매장: visible 메뉴의 카테고리, 정렬·중복 제거', () => {
  const r = compute({ ...base, storeOwnMenus: [{ mainCategory: 'dessert' }, { mainCategory: 'coffee' }, { mainCategory: 'coffee' }] });
  assert.deepEqual(r, ['coffee', 'dessert']);
});
test('개인 매장: visible=false 메뉴는 제외, mainCategory 부재 = coffee', () => {
  const r = compute({ ...base, storeOwnMenus: [{ mainCategory: 'dessert', visible: false }, {}] });
  assert.deepEqual(r, ['coffee']);
});
test('soldOut 은 카테고리에 영향 없다', () => {
  assert.deepEqual(compute({ ...base, storeOwnMenus: [{ mainCategory: 'dessert', soldOut: true }] }), ['dessert']);
});
test('∩active: 비활성 카테고리는 빠진다', () => {
  assert.deepEqual(compute({ ...base, storeOwnMenus: [{ mainCategory: 'tea' }, { mainCategory: 'coffee' }] }), ['coffee']);
});
test('−excluded: 점주 opt-out 은 빠진다 (sticky)', () => {
  const r = compute({ ...base, storeOwnMenus: [{ mainCategory: 'dessert' }, { mainCategory: 'coffee' }], excludedByStore: ['dessert'] });
  assert.deepEqual(r, ['coffee']);
});
test('가맹: 마스터 카테고리가 들어온다 (override 없음)', () => {
  assert.deepEqual(compute({ ...base, brandMasterMenus: [master('m1', 'coffee'), master('m2', 'dessert')] }), ['coffee', 'dessert']);
});
test('가맹: 승인된 override.excluded 면 그 마스터는 빠진다', () => {
  const r = compute({
    ...base, brandMasterMenus: [master('m1', 'coffee'), master('m2', 'dessert')],
    storeOverrides: new Map([['m2', { excluded: true, status: 'approved' }]]),
  });
  assert.deepEqual(r, ['coffee']);
});
test('가맹: 미승인(pending/부재) override.excluded 는 효력 없음 (menuVisibility 계약)', () => {
  const r = compute({
    ...base, brandMasterMenus: [master('m2', 'dessert')],
    storeOverrides: new Map([['m2', { excluded: true, status: 'pending' }], ['x', {}]]),
  });
  assert.deepEqual(r, ['dessert']);
  const r2 = compute({ ...base, brandMasterMenus: [master('m2', 'dessert')], storeOverrides: new Map([['m2', { excluded: true }]]) });
  assert.deepEqual(r2, ['dessert']);
});
test('가맹: override.soldOut 는 카테고리에 영향 없음', () => {
  const r = compute({ ...base, brandMasterMenus: [master('m2', 'dessert')], storeOverrides: new Map([['m2', { soldOut: true, status: 'approved' }]]) });
  assert.deepEqual(r, ['dessert']);
});
test('가맹: 마스터 pending/rejected/visible=false 는 제외', () => {
  const r = compute({
    ...base, brandMasterMenus: [master('a', 'coffee', { status: 'pending' }), master('b', 'dessert', { status: 'rejected' }), master('c', 'nonCoffee', { visible: false })],
  });
  assert.deepEqual(r, []);
});
test('가맹: store-scope 메뉴는 approved && visible 만 합류', () => {
  const r = compute({
    ...base, brandMasterMenus: [master('a', 'coffee')],
    storeOwnMenus: [{ mainCategory: 'dessert' }, { mainCategory: 'nonCoffee', status: 'pending' }],
  });
  assert.deepEqual(r, ['coffee', 'dessert']);
});
test('가맹 + excluded 조합', () => {
  const r = compute({ ...base, brandMasterMenus: [master('a', 'coffee'), master('b', 'dessert')], excludedByStore: ['coffee'] });
  assert.deepEqual(r, ['dessert']);
});

test('sameCodeSet: 순서 무관 동일 / 부재·타입 다름은 다름', () => {
  assert.equal(sameCodeSet(['b', 'a'], ['a', 'b']), true);
  assert.equal(sameCodeSet([], []), true);
  assert.equal(sameCodeSet(undefined, []), false);
  assert.equal(sameCodeSet(['a'], ['a', 'b']), false);
});

test('diff 게이트: 가격·이름 편집은 fan-out 안 함, 카테고리·생성·삭제·visible·승인 변화는 함', () => {
  const m = { mainCategory: 'coffee', basePrice: 1000, name: 'A' };
  assert.equal(masterMenuRelevance(m), masterMenuRelevance({ ...m, basePrice: 2000, name: 'B', soldOut: true }));
  assert.notEqual(masterMenuRelevance(m), masterMenuRelevance({ ...m, mainCategory: 'dessert' }));
  assert.notEqual(masterMenuRelevance(null), masterMenuRelevance(m));
  assert.notEqual(masterMenuRelevance(m), masterMenuRelevance(undefined));
  assert.notEqual(masterMenuRelevance(m), masterMenuRelevance({ ...m, visible: false }));
  assert.notEqual(masterMenuRelevance(m), masterMenuRelevance({ ...m, status: 'pending' }));
});

test('루프 가드: availableMainCategories 만 바뀐 store write 는 재계산하지 않는다', () => {
  const b = { excludedMainCategories: ['x'], brandId: 'b1', availableMainCategories: [] };
  assert.equal(storeDocNeedsRecompute(b, { ...b, availableMainCategories: ['coffee'] }), false);
  assert.equal(storeDocNeedsRecompute(b, { ...b, name: 'n', averageScore: 4 }), false);
  assert.equal(storeDocNeedsRecompute(b, { ...b, excludedMainCategories: ['x', 'y'] }), true);
  assert.equal(storeDocNeedsRecompute(b, { ...b, excludedMainCategories: ['x'].slice() }), false);
  assert.equal(storeDocNeedsRecompute(b, { ...b, brandId: 'b2' }), true);
  assert.equal(storeDocNeedsRecompute(undefined, b), true);
  assert.equal(storeDocNeedsRecompute(b, undefined), false);
});

test('active 플립 게이트: 실제 플립/생성/삭제만 true', () => {
  assert.equal(effectiveActive({ active: true }), effectiveActive({ active: true, label: 'x' }));
  assert.equal(effectiveActive({}), true);
  assert.notEqual(effectiveActive({ active: true }), effectiveActive({ active: false }));
  assert.notEqual(effectiveActive(undefined), effectiveActive({ active: true }));
});

test('소스 가드: 판정은 menuVisibility 재사용 (override status/soldOut 재포팅 금지), 쓰기는 1필드', () => {
  const a = src('availableCategories.ts');
  assert.match(a, /from "\.\/menuVisibility"/);
  assert.doesNotMatch(a, /\.soldOut|\.excluded\b/);
  const r = src('recomputeAvailableCategories.ts');
  assert.match(r, /\{ \[FIELD\]: p\.after \}/);
  assert.match(src('index.ts'), /backfillAvailableMainCategories/);
});

test('백필: admin 전용 + dryRun 기본 + migrationHistory 1건 affected/total', () => {
  const b = src('backfillAvailableMainCategories.ts');
  assert.match(b, /requireAdmin/);
  assert.match(b, /\.dryRun !== false/);
  assert.match(b, /migrationHistory/);
  assert.match(b, /affected: changed\.length/);
  assert.match(b, /total: snap\.size/);
});

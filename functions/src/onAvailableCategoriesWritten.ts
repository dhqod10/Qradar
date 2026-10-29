/**
 * store_category_optout Phase B — `stores/{s}.availableMainCategories` 파생 트리거 5개 (spec §12.1.3).
 *
 * 모두 같은 코어(`recomputeAvailableCategories.ts`)를 쓴다. freshness 는 soft(§12.0) — 소비처는 홈 카테고리 필터뿐이고
 * 매장 탭/메뉴 검색은 Phase A 에서 클라이언트가 즉시 반영한다. 그래서 실패는 `console.error` 후 swallow (재시도 폭주 방지),
 * 누락은 다음 소스 변경 또는 `backfillAvailableMainCategories` 가 치유한다.
 *
 *   ① onBrandMasterMenuWritten   brands/{b}/menuItems/{id}        관련성 diff 게이트 통과 시 산하 매장 fan-out
 *   ② onStoreMenuOverrideWritten stores/{s}/menuOverrides/{id}    매장 1건
 *   ③ onStoreOptoutWritten       stores/{s}                       excluded/brandId 변경(또는 생성)시만 매장 1건 — 루프 가드
 *   ③' onStoreOwnMenuWritten     stores/{s}/menuItems/{id}        매장 1건
 *   ④ onMainCategoryActiveWritten mainCategories/{id}             active 실제 플립시만 전 매장
 */

import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { masterMenuRelevance } from "./availableCategories";
import { RawDoc } from "./menuVisibility";
import { recomputeAllStores, recomputeBrandStores, recomputeStore } from "./recomputeAvailableCategories";

const REGION = "asia-northeast3";

async function guarded(tag: string, fn: () => Promise<unknown>): Promise<void> {
  try {
    await fn();
  } catch (err) {
    console.error(`[${tag}] failed. swallow (soft freshness; backfill heals).`, err);
  }
}

export const onStoreOwnMenuWritten = onDocumentWritten(
  { document: "stores/{storeId}/menuItems/{menuItemId}", region: REGION, timeoutSeconds: 120 },
  async (event) => {
    await guarded("onStoreOwnMenuWritten", () => recomputeStore(event.params.storeId));
  }
);

export const onStoreMenuOverrideWritten = onDocumentWritten(
  { document: "stores/{storeId}/menuOverrides/{masterMenuItemId}", region: REGION, timeoutSeconds: 120 },
  async (event) => {
    await guarded("onStoreMenuOverrideWritten", () => recomputeStore(event.params.storeId));
  }
);

/** 매장 문서 쓰기에서 재계산이 필요한가 — 소스 필드(excluded/brandId) 변경 또는 생성. 자신의 파생 쓰기는 false (루프 가드). */
export function storeDocNeedsRecompute(before: RawDoc | undefined, after: RawDoc | undefined): boolean {
  if (after == null) return false; // 삭제
  if (before == null) return true; // 생성 — 시드
  const key = (d: RawDoc) =>
    JSON.stringify([
      [...(Array.isArray(d.excludedMainCategories) ? d.excludedMainCategories : [])].sort(),
      typeof d.brandId === "string" ? d.brandId : null,
    ]);
  return key(before) !== key(after);
}

export const onStoreOptoutWritten = onDocumentWritten(
  { document: "stores/{storeId}", region: REGION, timeoutSeconds: 120 },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!storeDocNeedsRecompute(before, after)) return;
    await guarded("onStoreOptoutWritten", () => recomputeStore(event.params.storeId, after));
  }
);

export const onBrandMasterMenuWritten = onDocumentWritten(
  { document: "brands/{brandId}/menuItems/{menuItemId}", region: REGION, timeoutSeconds: 540 },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    // diff 게이트: 카테고리 집합에 영향 없는 편집(가격·이름 등)은 fan-out 하지 않는다.
    if (masterMenuRelevance(before) === masterMenuRelevance(after)) return;
    await guarded("onBrandMasterMenuWritten", async () => {
      const r = await recomputeBrandStores(event.params.brandId);
      console.info("[onBrandMasterMenuWritten] fan-out.", { brandId: event.params.brandId, ...r });
    });
  }
);

/** mainCategory 의 실효 active (문서 없음 = false, active 부재 = true). */
export function effectiveActive(d: RawDoc | undefined): boolean {
  return d != null && d.active !== false;
}

export const onMainCategoryActiveWritten = onDocumentWritten(
  { document: "mainCategories/{categoryId}", region: REGION, timeoutSeconds: 540 },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (effectiveActive(before) === effectiveActive(after)) return;
    await guarded("onMainCategoryActiveWritten", async () => {
      const r = await recomputeAllStores();
      console.info("[onMainCategoryActiveWritten] fan-out all.", { categoryId: event.params.categoryId, ...r });
    });
  }
);

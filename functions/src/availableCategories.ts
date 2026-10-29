/**
 * availableMainCategories 순수 계산 (store_category_optout Phase B, spec §12.1.2). 읽기 0 — 단위 테스트 대상.
 *
 *   availableMainCategories(store)
 *     = { visibleMenu.mainCategory } ∩ activeCodes − store.excludedMainCategories
 *
 * "visible menu" 판정은 Dart `MenuItemRepositoryImpl.watchByStore` 머지 시맨틱을 그대로 미러한다:
 *   - 개인 매장(brandId 없음): stores/{s}/menuItems 중 visible 인 것.
 *   - 가맹 매장(brandMasterMenus != null): 마스터(approved && visible) 에 override 를 적용(`applyOverrideForCustomer` —
 *     **menuVisibility.ts 재사용, 재포팅 금지**)해 null(excluded) 이 아닌 것 ∪ store-scope 메뉴(approved && visible).
 *   - soldOut 은 카테고리 노출에 영향 없다 (품절이어도 메뉴는 매장 탭에 보인다).
 *
 * 이 필드는 홈 카테고리 필터 노출용 파생값이다. 결제·권한 판정 입력이 아니다.
 */

import { applyOverrideForCustomer, RawDoc } from "./menuVisibility";

export interface BrandMasterMenu {
  id: string;
  data: RawDoc;
}

export interface ComputeAvailableArgs {
  /** stores/{s}/menuItems 문서 data 들. */
  storeOwnMenus: RawDoc[];
  /** brands/{b}/menuItems. null = 개인(비가맹) 매장. */
  brandMasterMenus: BrandMasterMenu[] | null;
  /** stores/{s}/menuOverrides — key = masterMenuItemId (= 문서 id). */
  storeOverrides: ReadonlyMap<string, RawDoc>;
  /** mainCategories 중 active 인 id 집합. */
  activeCodes: ReadonlySet<string>;
  /** store.excludedMainCategories. */
  excludedByStore: readonly string[];
}

/** Dart `MenuItemModel.fromFirestore`: mainCategory 부재 = 'coffee'. */
export function menuMainCategory(d: RawDoc): string {
  return typeof d.mainCategory === "string" ? d.mainCategory : "coffee";
}

/** 메뉴(마스터·store-scope) 승인 여부 — status 부재/알 수 없는 값 = approved (Dart `EntityApprovalStatus.fromString`). */
export function menuIsApproved(d: RawDoc): boolean {
  return d.status !== "pending" && d.status !== "rejected";
}

/** 고객 노출(visible) — 부재 = true. */
export function menuIsVisible(d: RawDoc): boolean {
  return typeof d.visible === "boolean" ? d.visible : true;
}

/** 정렬·중복 제거된 결과 (저장값 비교가 결정적이도록). */
export function computeAvailableMainCategories(args: ComputeAvailableArgs): string[] {
  const { storeOwnMenus, brandMasterMenus, storeOverrides, activeCodes, excludedByStore } = args;
  const found = new Set<string>();

  if (brandMasterMenus == null) {
    for (const m of storeOwnMenus) {
      if (menuIsVisible(m)) found.add(menuMainCategory(m));
    }
  } else {
    for (const { id, data } of brandMasterMenus) {
      if (!menuIsApproved(data) || !menuIsVisible(data)) continue;
      const merged = applyOverrideForCustomer({ master: data, override: storeOverrides.get(id) ?? null });
      if (merged == null) continue; // 이 매장은 이 메뉴를 팔지 않는다 (override excluded)
      found.add(menuMainCategory(data));
    }
    for (const m of storeOwnMenus) {
      if (menuIsApproved(m) && menuIsVisible(m)) found.add(menuMainCategory(m));
    }
  }

  const optedOut = new Set(excludedByStore);
  return [...found].filter((c) => activeCodes.has(c) && !optedOut.has(c)).sort();
}

/** 두 코드 목록이 같은가 (순서 무관). stored 가 배열이 아니면(부재) 다르다. */
export function sameCodeSet(stored: unknown, next: readonly string[]): boolean {
  if (!Array.isArray(stored)) return false;
  const a = [...new Set(stored.filter((x): x is string => typeof x === "string"))].sort();
  const b = [...new Set(next)].sort();
  return a.length === b.length && a.every((v, i) => v === b[i]);
}

/** 브랜드 마스터 메뉴가 카테고리 집합에 영향을 주는 상태의 지문 (diff 게이트). 문서 없음 = null. */
export function masterMenuRelevance(d: RawDoc | null | undefined): string | null {
  if (d == null) return null;
  return `${menuMainCategory(d)}|${menuIsVisible(d)}|${menuIsApproved(d)}`;
}

/**
 * 메뉴 판매 가능 판정 — Dart `lib/core/utils/store_menu_visibility.dart applyOverrideForCustomer` 의 **TS 포팅**
 * (복제가 아니다). payment_server_authority spec §7. 이 파일이 CF 쪽 유일한 구현이다 (grep 가드: `soldOut` /
 * override `status` 비교는 이 파일 1곳에만 나온다).
 *
 * **비자명한 분기**: 핵심 필드(`excluded` / `priceOverride`)는 `override.status == approved` 일 때만,
 * 운영 필드(`soldOut` / `disabledOption*`)는 status 무관 즉시 적용. 갈라지면 "고객이 본 화면과 결제 결과가 다르다".
 *
 * 교차 골든: `test_fixtures/menu_visibility_contract.json` · `test_fixtures/checkout_menu_gate_contract.json`
 * (Dart `test/core/payment_authority_contract_test.dart` 와 같은 파일을 읽는다).
 *
 * 값 해석은 Dart 모델 경로를 그대로 따른다 (골든이 고정):
 *  - override.status 키 부재 = 'pending' (MenuOverrideModel 기본값), 알 수 없는 문자열 = 'approved'
 *    (EntityApprovalStatus.fromString 의 legacy 폴백 — **의도적으로 Dart 와 동일**. 서버가 혼자 엄격해지면 고객이 본 화면과 갈라진다.)
 *  - override.excluded / soldOut 키 부재 = false, 마스터·점포 메뉴 soldOut 부재 = false, visible 부재 = true.
 */

export type RawDoc = Record<string, unknown>;

/** 옵션 그룹 출처 (Dart `OptionScope`). 모르는 값은 `master` (Dart `OptionScope.fromString` 폴백과 같다). */
export type OptionScope = "master" | "brand" | "store";

/** 메뉴 → 옵션 그룹 참조 (Dart `OptionGroupRef`). */
export interface OptionGroupRef {
  scope: OptionScope;
  id: string;
}

/**
 * 적용 결과 — 단가(basePrice)와 옵션 그룹 참조까지 포함한다 (payment_price_authority: 금액 재계산이 이 반환값만 소비한다.
 * `optionGroupRefs` 는 이미 읽은 문서에 있으므로 추가 읽기 0).
 */
export interface MergedMenu {
  basePrice: number;
  soldOut: boolean;
  disabledOptionGroupIds: string[];
  disabledOptionItemIds: string[];
  optionGroupRefs: OptionGroupRef[];
}

function asBool(v: unknown, dflt: boolean): boolean {
  return typeof v === "boolean" ? v : dflt;
}

function asStringList(v: unknown): string[] {
  return Array.isArray(v) ? v.filter((x): x is string => typeof x === "string") : [];
}

/**
 * `optionGroupRefs` 해석 — Dart `MenuItemModel.fromFirestore` 경로를 그대로 따른다 (골든이 고정):
 * 객체가 아닌 요소는 건너뛰고, scope 부재/모르는 값 = master, id 부재 = ''.
 */
function asOptionGroupRefs(v: unknown): OptionGroupRef[] {
  if (!Array.isArray(v)) return [];
  const out: OptionGroupRef[] = [];
  for (const e of v) {
    if (typeof e !== "object" || e === null || Array.isArray(e)) continue;
    const m = e as RawDoc;
    const scope = m.scope === "brand" || m.scope === "store" ? m.scope : "master";
    out.push({ scope, id: typeof m.id === "string" ? m.id : "" });
  }
  return out;
}

function asPrice(v: unknown): number {
  return typeof v === "number" && Number.isFinite(v) ? Math.trunc(v) : 0;
}

/**
 * override.status 해석 — Dart `MenuOverrideModel`(부재='pending') → `EntityApprovalStatus.fromString`.
 * **승인 분기의 유일한 구현이다** — 감사 도구(`auditOrderPriceIntegrity`)도 이 함수를 가져다 쓴다 (복제 금지, payment_price_authority 가드 5).
 */
export function overrideIsApproved(override: RawDoc): boolean {
  const raw = typeof override.status === "string" ? override.status : "pending";
  return raw !== "pending" && raw !== "rejected";
}

/**
 * 마스터 메뉴 1건에 이 매장의 override 를 고객 기준으로 적용한다.
 * 반환 `null` = 이 매장은 이 메뉴를 팔지 않는다 (`excluded`). `override` 가 null 이면 마스터 그대로.
 */
export function applyOverrideForCustomer(args: {
  master: RawDoc;
  override: RawDoc | null;
}): MergedMenu | null {
  const { master, override } = args;
  if (override == null) {
    return {
      basePrice: asPrice(master.basePrice),
      soldOut: asBool(master.soldOut, false),
      disabledOptionGroupIds: asStringList(master.disabledOptionGroupIds),
      disabledOptionItemIds: asStringList(master.disabledOptionItemIds),
      optionGroupRefs: asOptionGroupRefs(master.optionGroupRefs),
    };
  }
  const approved = overrideIsApproved(override);
  if (approved && asBool(override.excluded, false)) return null;
  const priceOverride =
    typeof override.priceOverride === "number" && Number.isFinite(override.priceOverride)
      ? Math.trunc(override.priceOverride)
      : null;
  return {
    basePrice: approved && priceOverride !== null ? priceOverride : asPrice(master.basePrice),
    soldOut: asBool(override.soldOut, false),
    disabledOptionGroupIds: asStringList(override.disabledOptionGroupIds),
    disabledOptionItemIds: asStringList(override.disabledOptionItemIds),
    // override 는 옵션 그룹 참조를 바꾸지 않는다 — 마스터 것이다.
    optionGroupRefs: asOptionGroupRefs(master.optionGroupRefs),
  };
}

export type CartMenuReason = "MENU_SOLD_OUT" | "MENU_EXCLUDED" | "MENU_NOT_FOUND";

export interface CartMenuVerdict {
  /** null = 판매 가능. */
  reason: CartMenuReason | null;
  /** 어느 문서에서 해석했는가 (문서 존재로 역추론한 결과). NOT_FOUND 면 null. */
  source: "store" | "master" | null;
  /** 판매 가능/품절일 때의 단가 포함 병합 결과. EXCLUDED·NOT_FOUND 면 null. */
  merged: MergedMenu | null;
}

/**
 * menuItemId 하나를 **문서 존재로 역추론**해 분류한다 (spec §7.2 ③). 클라이언트가 선언한 scope/brandId 는 쓰지 않는다.
 *  - storeMenu : stores/{s}/menuItems/{id}   - override : stores/{s}/menuOverrides/{id}
 *  - master    : brands/{b}/menuItems/{id}  — 매장에 brandId 가 있을 때만 읽는다 (hasBrand)
 * Dart `classifyCheckoutMenu` 와 같은 규칙.
 */
export function classifyCartMenu(args: {
  hasBrand: boolean;
  storeMenu: RawDoc | null;
  master: RawDoc | null;
  override: RawDoc | null;
}): CartMenuVerdict {
  const { hasBrand, storeMenu, master, override } = args;
  if (storeMenu != null) {
    const merged: MergedMenu = {
      basePrice: asPrice(storeMenu.basePrice),
      soldOut: asBool(storeMenu.soldOut, false),
      disabledOptionGroupIds: asStringList(storeMenu.disabledOptionGroupIds),
      disabledOptionItemIds: asStringList(storeMenu.disabledOptionItemIds),
      optionGroupRefs: asOptionGroupRefs(storeMenu.optionGroupRefs),
    };
    if (!asBool(storeMenu.visible, true)) return { reason: "MENU_EXCLUDED", source: "store", merged: null };
    if (merged.soldOut) return { reason: "MENU_SOLD_OUT", source: "store", merged };
    return { reason: null, source: "store", merged };
  }
  if (hasBrand && master != null) {
    const merged = applyOverrideForCustomer({ master, override });
    if (merged == null) return { reason: "MENU_EXCLUDED", source: "master", merged: null };
    if (merged.soldOut) return { reason: "MENU_SOLD_OUT", source: "master", merged };
    return { reason: null, source: "master", merged };
  }
  return { reason: "MENU_NOT_FOUND", source: null, merged: null };
}

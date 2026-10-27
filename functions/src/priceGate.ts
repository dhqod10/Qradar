/**
 * 결제 금액 게이트 (2-c) — `verifyTossPayment` 의 Toss confirm **직전**에서 카트 금액을 Firestore 문서에서 다시 계산한다.
 * payment_price_authority spec §4~§8.
 *
 * **이 파일은 새 판정 함수를 만들지 않는다.** 가격의 권위(승인된 `priceOverride` 만 적용)는 `menuVisibility.ts` 가 이미 결정한
 * `MergedMenu.basePrice` 로 들어오고, 옵션은 `optionPricing.ts`, 산술은 `cartPricing.ts` 다. 여기서는 그 셋을 이어 붙이고
 * §4-3 의 판정식(c1~c6)을 클라이언트 선언값과 대조할 뿐이다.
 *
 * 클라이언트가 선언한 `lineTotal` / `unitPriceWithOptions` / `subtotal` / `totalPrice` / `priceDelta` 는 **권위가 아니다.**
 * 서버는 menuItemId · quantity · selectedOptions.{groupId,itemId} 만 읽고 나머지는 문서에서 다시 만든다.
 *
 * Firestore 에 직접 의존하지 않는다 (`GateReader` 주입) — confirm 이 호출되지 않음을 단위 테스트로 단언하기 위해서다.
 */

import { computeCartAmount, CartLinePricing } from "./cartPricing";
import { classifyCartMenu, MergedMenu, OptionGroupRef, RawDoc } from "./menuVisibility";
import { OptionGroupDoc, OptionIssue, optionRefKey, parseOptionGroup, validateSelection } from "./optionPricing";
import { GateMode, GateReader, GateReason, isLookupSafeId, MAX_CART_ITEMS, resolveGateMode, TOKEN_ID_RE } from "./paymentGate";

/** 중복 제거 후 (scope, groupId) 쌍 수 상한 (spec §6-2). 메뉴당 옵션 그룹 수는 점주·브랜드가 정하므로 읽기 비용의 뚜껑이다. */
export const MAX_OPTION_GROUP_DOCS = 200;

/** 라인 수량 상한 — 앱 `QuantityStepper` 의 1~99 와 같다. 음수·0·소수·거대 수량은 금액을 깎는 입력이므로 거절한다. */
export const MAX_LINE_QUANTITY = 99;

/** `PAYMENT_PRICE_MODE` 값. `resolveGateMode` 와 **같은 폴백**(없거나 모르는 값·대소문자·공백 = off) — operations.md §6.1. */
export type PriceMode = GateMode;
export const resolvePriceMode = (raw: unknown): PriceMode => resolveGateMode(raw);

export interface PriceChecks {
  c1: boolean;
  c2: boolean;
  c3: boolean;
  c4: boolean;
  c5: boolean;
  c6: boolean;
}

export interface PriceGateDetail {
  clientAmount: number | null;
  /** 서버 계산액. 계산할 수 없었으면 null. */
  serverExpected: number | null;
  /** clientAmount − serverExpected (부호 있음 — 방향이 시점 차이와 조작을 가른다). 계산할 수 없었으면 null. */
  delta: number | null;
  checks: PriceChecks;
  lines: Array<{
    menuItemId: string | null;
    clientLineTotal: number | null;
    serverLineTotal: number | null;
    quantity: number | null;
    /** 이 라인을 계산할 수 없었던 이유 (메뉴 해석 불가 / 수량 / 선택 형식). */
    unusable?: "menuUnresolved" | "badMenuItemId" | "badQuantity" | "badSelection";
  }>;
  optionIssues: Array<OptionIssue & { menuItemId: string }>;
  /** READ_FAILED 일 때만: 왜 계산하지 못했는가. */
  failure?: "storeUnreadable" | "menuUnreadable" | "optionGroupsUnreadable" | "optionGroupCapExceeded";
}

export type PriceGateResult =
  | {
      ok: true;
      /** 서버가 문서에서 다시 만든 금액. enforce 일 때 주문 문서가 이 값으로 쓰인다 (R8). */
      pricing: { lines: CartLinePricing[]; subtotal: number; expected: number };
    }
  | { ok: false; reason: GateReason; menuItemIds: string[]; detail: PriceGateDetail };

// ── 메뉴 해석 (게이트가 꺼져 있을 때만 쓴다) ─────────────────────────────────────────

export interface ResolvedMenus {
  menus: Map<string, MergedMenu>;
  storeBrandId: string | null;
}

/**
 * `PAYMENT_GATE_MODE=off` (또는 게이트가 shadow 로 위반을 만났을 때) 금액 게이트가 메뉴를 **직접** 읽는다 (spec §8 ⓐ).
 * 게이트 판정(품절·판매중단 거절)은 하지 않는다 — 가격이 필요할 뿐이다. 판정은 `classifyCartMenu` 한 곳이다.
 * `null` = 매장·메뉴를 읽을 수 없었다 (호출자가 READ_FAILED 로 처리).
 */
export async function resolveMenusForPricing(
  reader: GateReader,
  cart: { storeId: unknown; items: unknown[] }
): Promise<ResolvedMenus | null> {
  if (!isLookupSafeId(cart.storeId)) return null;
  try {
    const store = await reader.getStore(cart.storeId);
    if (store == null) return null;
    const brandId = typeof store.brandId === "string" && store.brandId.length > 0 ? store.brandId : null;
    const ids: string[] = [];
    for (const it of cart.items) {
      const id = (it as RawDoc | null)?.menuItemId;
      if (isLookupSafeId(id) && !ids.includes(id)) ids.push(id);
    }
    const docs = await reader.getMenuDocs(cart.storeId, brandId, ids);
    const menus = new Map<string, MergedMenu>();
    for (const id of ids) {
      const v = classifyCartMenu({
        hasBrand: brandId !== null,
        storeMenu: docs.storeMenus.get(id) ?? null,
        master: docs.masters.get(id) ?? null,
        override: docs.overrides.get(id) ?? null,
      });
      if (v.merged !== null) menus.set(id, v.merged);
    }
    return { menus, storeBrandId: brandId };
  } catch (e) {
    console.error("[priceGate] menu read failed", e);
    return null;
  }
}

// ── 평가 ─────────────────────────────────────────────────────────────────────

interface ParsedLine {
  menuItemId: string | null;
  quantity: number | null;
  selected: Array<{ groupId: string; itemId: string }> | null;
  clientUnit: unknown;
  clientTotal: unknown;
  unusable?: "badMenuItemId" | "badQuantity" | "badSelection";
}

function parseLine(raw: unknown): ParsedLine {
  const it = (typeof raw === "object" && raw !== null ? raw : {}) as RawDoc;
  const out: ParsedLine = {
    menuItemId: null,
    quantity: null,
    selected: [],
    clientUnit: it.unitPriceWithOptions,
    clientTotal: it.lineTotal,
  };
  if (isLookupSafeId(it.menuItemId)) out.menuItemId = it.menuItemId;
  else out.unusable = "badMenuItemId";
  if (typeof it.quantity === "number" && Number.isInteger(it.quantity) && it.quantity >= 1 && it.quantity <= MAX_LINE_QUANTITY) {
    out.quantity = it.quantity;
  } else {
    out.unusable ??= "badQuantity";
  }
  const sel = it.selectedOptions;
  if (sel === undefined || sel === null) {
    out.selected = [];
  } else if (Array.isArray(sel)) {
    const picked: Array<{ groupId: string; itemId: string }> = [];
    for (const o of sel) {
      const m = (typeof o === "object" && o !== null ? o : {}) as RawDoc;
      if (typeof m.groupId === "string" && typeof m.itemId === "string") picked.push({ groupId: m.groupId, itemId: m.itemId });
      else out.unusable ??= "badSelection";
    }
    out.selected = picked;
  } else {
    out.selected = null;
    out.unusable ??= "badSelection";
  }
  return out;
}

const isInt = (v: unknown): v is number => typeof v === "number" && Number.isSafeInteger(v);

function emptyChecks(): PriceChecks {
  return { c1: false, c2: false, c3: false, c4: false, c5: false, c6: false };
}

function readFailed(detail: Partial<PriceGateDetail> & { failure: NonNullable<PriceGateDetail["failure"]> }): PriceGateResult {
  return {
    ok: false,
    reason: "READ_FAILED",
    menuItemIds: [],
    detail: {
      clientAmount: null,
      serverExpected: null,
      delta: null,
      checks: emptyChecks(),
      lines: [],
      optionIssues: [],
      ...detail,
    },
  };
}

/** 메뉴·매장을 읽을 수 없어 금액을 계산하지 못했다 — 거절(enforce) + 기록. 통과시키면 게이트가 무력화된다 (spec §7-1). */
export function storeUnreadableResult(amount: unknown): PriceGateResult {
  return readFailed({ failure: "storeUnreadable", clientAmount: isInt(amount) ? amount : null });
}

/**
 * §4-3 판정식. `menus` 는 게이트가 이미 읽은 `ResolvedMenu` 들이거나 [resolveMenusForPricing] 의 결과다 (추가 읽기 0).
 * 옵션 그룹만 `getAll` 1회로 더 읽는다 (R3).
 */
export async function evaluatePriceAuthority(
  reader: GateReader,
  args: {
    storeId: string;
    storeBrandId: string | null;
    menus: ReadonlyMap<string, MergedMenu>;
    amount: number;
    cart: { subtotal: unknown; totalPrice: unknown; items: unknown[] };
  }
): Promise<PriceGateResult> {
  const { cart } = args;
  const clientAmount = isInt(args.amount) ? args.amount : null;
  if (!Array.isArray(cart.items) || cart.items.length > MAX_CART_ITEMS) {
    return readFailed({ failure: "menuUnreadable", clientAmount });
  }
  const parsed = cart.items.map(parseLine);

  // 필요한 옵션 그룹 = 카트 메뉴들의 **모든** ref (required / single 제약은 선택하지 않은 그룹까지 봐야 한다).
  const refByKey = new Map<string, OptionGroupRef>();
  for (const p of parsed) {
    const m = p.menuItemId === null ? undefined : args.menus.get(p.menuItemId);
    if (m === undefined) continue;
    for (const r of m.optionGroupRefs) refByKey.set(optionRefKey(r.scope, r.id), r);
  }
  if (refByKey.size > MAX_OPTION_GROUP_DOCS) {
    return readFailed({ failure: "optionGroupCapExceeded", clientAmount });
  }

  const groups = new Map<string, OptionGroupDoc | null>();
  if (refByKey.size > 0) {
    let raw: Map<string, RawDoc | null>;
    try {
      raw = await reader.getOptionGroups(args.storeId, args.storeBrandId, [...refByKey.values()]);
    } catch (e) {
      console.error("[priceGate] option group read failed", e);
      return readFailed({ failure: "optionGroupsUnreadable", clientAmount });
    }
    for (const [key, ref] of refByKey) {
      const doc = raw.get(key) ?? null;
      groups.set(key, doc === null ? null : parseOptionGroup(ref.id, doc));
    }
  }

  // 라인별 옵션 검증 + 가격 입력.
  const optionIssues: Array<OptionIssue & { menuItemId: string }> = [];
  const pricingInput: Array<{ basePrice: number; priceDeltas: number[]; quantity: number }> = [];
  const unusable: Array<PriceGateDetail["lines"][number]["unusable"]> = [];
  parsed.forEach((p, i) => {
    const merged = p.menuItemId === null ? undefined : args.menus.get(p.menuItemId);
    let reason: PriceGateDetail["lines"][number]["unusable"] = p.unusable;
    if (reason === undefined && merged === undefined) reason = "menuUnresolved";
    if (reason !== undefined || merged === undefined || p.quantity === null || p.selected === null) {
      unusable[i] = reason ?? "badSelection";
      pricingInput.push({ basePrice: 0, priceDeltas: [], quantity: 0 });
      return;
    }
    const check = validateSelection({
      refs: merged.optionGroupRefs,
      groupsByRefKey: groups,
      disabledGroupIds: new Set(merged.disabledOptionGroupIds),
      disabledItemIds: new Set(merged.disabledOptionItemIds),
      selected: p.selected,
    });
    for (const issue of check.issues) optionIssues.push({ ...issue, menuItemId: p.menuItemId as string });
    pricingInput.push({ basePrice: merged.basePrice, priceDeltas: check.priceDeltas, quantity: p.quantity });
  });

  const anyUnusable = unusable.some((u) => u !== undefined);
  const amount = computeCartAmount(pricingInput);
  const serverExpected = anyUnusable ? null : amount.expected;

  // §4-3 판정식. ①②③ 은 클라 값끼리의 비교(권위 아님, 기준선과 같은 불변식), ④⑤⑥ 이 권위다.
  const clientLineTotals = parsed.map((p) => p.clientTotal);
  const clientSum = clientLineTotals.every(isInt) ? (clientLineTotals as number[]).reduce((a, b) => a + b, 0) : null;
  const lineOk5 = parsed.map((p, i) => unusable[i] === undefined && p.clientTotal === amount.lines[i].lineTotal);
  const lineOk6 = parsed.map((p, i) => unusable[i] === undefined && p.clientUnit === amount.lines[i].unitPrice);
  const checks: PriceChecks = {
    c1: clientAmount !== null && clientAmount === cart.totalPrice,
    c2: cart.totalPrice === cart.subtotal,
    c3: clientSum !== null && cart.subtotal === clientSum,
    c4: serverExpected !== null && clientAmount === serverExpected,
    c5: lineOk5.every(Boolean),
    c6: lineOk6.every(Boolean),
  };

  const detail: PriceGateDetail = {
    clientAmount,
    serverExpected,
    delta: clientAmount !== null && serverExpected !== null ? clientAmount - serverExpected : null,
    checks,
    lines: parsed.map((p, i) => ({
      menuItemId: p.menuItemId,
      clientLineTotal: isInt(p.clientTotal) ? p.clientTotal : null,
      serverLineTotal: unusable[i] === undefined ? amount.lines[i].lineTotal : null,
      quantity: p.quantity,
      ...(unusable[i] !== undefined ? { unusable: unusable[i] } : {}),
    })),
    optionIssues,
  };

  const tokenIds = (ids: Iterable<string | null>): string[] => {
    const out: string[] = [];
    for (const id of ids) if (id !== null && TOKEN_ID_RE.test(id) && !out.includes(id)) out.push(id);
    return out;
  };

  // 사유 우선순위: OPTION_UNAVAILABLE > PRICE_MISMATCH (옵션이 고객이 고칠 수 있는 쪽이고, 옵션이 깨지면 금액도 깨진다).
  if (optionIssues.length > 0) {
    return { ok: false, reason: "OPTION_UNAVAILABLE", menuItemIds: tokenIds(optionIssues.map((x) => x.menuItemId)), detail };
  }
  const allOk = Object.values(checks).every(Boolean) && !anyUnusable;
  if (!allOk) {
    const bad = parsed.filter((_, i) => !lineOk5[i] || !lineOk6[i]).map((p) => p.menuItemId);
    return { ok: false, reason: "PRICE_MISMATCH", menuItemIds: tokenIds(bad), detail };
  }
  return { ok: true, pricing: { lines: amount.lines, subtotal: amount.subtotal, expected: amount.expected } };
}

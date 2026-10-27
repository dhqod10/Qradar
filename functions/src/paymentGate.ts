/**
 * 결제 게이트 (G1 매장 판매 가능 + G2 메뉴 품절·판매중단) — `verifyTossPayment` 의 Toss confirm **직전**에서 호출된다.
 * payment_server_authority spec §6~§9, §15.1.
 *
 * **서버가 결제를 거절할 수 있게 되면서 처음 생기는 실패**다. 막을 것을 못 막으면 구멍이고, 막지 말아야 할 것을 막으면
 * 매출이 멈춘다 (spec §8). fail 방향은 spec §8.1 표를 그대로 따른다:
 *   - 데이터 위반(품절·미승인 등)  → 거절
 *   - 데이터 부재(문서·status 없음) → 거절 (M1 백필이 선행돼야 한다 — spec §17 ③)
 *   - 읽기 실패                    → 거절 + 기록 + `READ_FAILED` (게이트를 무력화하지 않는다)
 *
 * 이 파일은 Firestore 에 직접 의존하지 않는다 (`GateReader` 주입) — confirm 이 호출되지 않음을 단위 테스트로 단언하기 위해서다.
 * 판정 함수는 `canSellNow`(storeSellability.ts) · `classifyCartMenu`(menuVisibility.ts) 두 개뿐이며 여기서 재구현하지 않는다.
 */

import { canSellNow } from "./storeSellability";
import { classifyCartMenu, CartMenuReason, MergedMenu, RawDoc } from "./menuVisibility";

/**
 * 거절 사유 8종 (고객 화면이 아는 목록 — design §3.1). `PRICE_MISMATCH` / `OPTION_UNAVAILABLE` 은 금액 게이트
 * (`priceGate.ts`, payment_price_authority §9-1)가 쓰며 토큰 문법은 메뉴 사유와 같다.
 */
export type GateReason =
  | "STORE_NOT_SELLABLE"
  | "STORE_NOT_FOUND"
  | "MENU_SOLD_OUT"
  | "MENU_EXCLUDED"
  | "MENU_NOT_FOUND"
  | "PRICE_MISMATCH"
  | "OPTION_UNAVAILABLE"
  | "READ_FAILED";

/**
 * 게이트 모드 (spec §17.0) — `PAYMENT_GATE_MODE` 파라미터 값.
 *   off     : 평가하지 않는다. stores·메뉴 읽기도 하지 않는다 (비용 0). 게이트 도입 전과 동일.
 *   shadow  : 판정하고 `paymentGateRejections` 에 `detail.shadow:true` 로 기록하되 거절하지 않는다.
 *   enforce : 판정 + 기록 + 거절.
 */
export type GateMode = "off" | "shadow" | "enforce";

/**
 * 원시 값 → 모드. **없거나 모르는 값이면 `off`** (명시적 결정, spec §17.0).
 * 게이트는 돈을 멈추는 장치다 — 설정 오타로 매출이 멈추는 것보다 구멍이 하루 더 열려 있는 편이 낫다.
 * (Qoin 적립이 fail-closed 인 것과 반대이고, 반대인 것이 맞다: fail 방향은 "그 실패가 누구에게서 무엇을 빼앗는가"로 정한다.)
 * 정확히 일치만 인정한다 — 대소문자·공백을 너그럽게 받지 않는다 (`Enforce` 는 `off`). 그 대가는 런북 ⑥-c 의 거절 1건 실측이 받는다.
 */
export function resolveGateMode(raw: unknown): GateMode {
  return raw === "shadow" || raw === "enforce" ? raw : "off";
}

/** spec §15 사유 ↔ HttpsError code. */
export const GATE_HTTPS_CODE: Record<GateReason, "failed-precondition" | "not-found" | "unavailable"> = {
  STORE_NOT_SELLABLE: "failed-precondition",
  STORE_NOT_FOUND: "not-found",
  MENU_SOLD_OUT: "failed-precondition",
  MENU_EXCLUDED: "failed-precondition",
  MENU_NOT_FOUND: "not-found",
  PRICE_MISMATCH: "failed-precondition",
  OPTION_UNAVAILABLE: "failed-precondition",
  READ_FAILED: "unavailable",
};

/** 사람용 문장 (디버깅·구 앱용). 신 앱 화면은 이 문자열을 그리지 않는다 — 코드 안 상수만 그린다 (spec §15.1). */
const GATE_TEXT: Record<GateReason, string> = {
  STORE_NOT_SELLABLE: "지금은 이 매장이 주문을 받을 수 없어요. 잠시 후 다시 시도해주세요",
  STORE_NOT_FOUND: "매장 정보를 찾을 수 없어요. 카트를 비우고 다시 담아주세요",
  MENU_SOLD_OUT: "품절된 메뉴가 있어요. 카트에서 빼고 다시 시도해주세요",
  MENU_EXCLUDED: "이 매장에서 더 이상 판매하지 않는 메뉴가 있어요",
  MENU_NOT_FOUND: "메뉴 정보가 변경됐어요. 카트를 비우고 다시 담아주세요",
  PRICE_MISMATCH: "메뉴 가격이 바뀌었어요. 최신 가격으로 다시 담아주세요",
  OPTION_UNAVAILABLE: "선택한 옵션이 바뀌었어요. 카트에서 옵션을 다시 골라주세요",
  READ_FAILED: "일시적인 오류예요. 잠시 후 다시 시도해주세요",
};

/** 토큰에 menuItemId 를 싣는 사유 (메뉴 사유 3종 + 금액 사유 2종 — payment_price_authority R11). */
const MENU_REASONS: ReadonlySet<GateReason> = new Set([
  "MENU_SOLD_OUT",
  "MENU_EXCLUDED",
  "MENU_NOT_FOUND",
  "PRICE_MISMATCH",
  "OPTION_UNAVAILABLE",
]);

/** 토큰의 id 문법 (spec §15.1): Firestore 문서 ID — `,` `:` `[` `]` 가 들어가지 않는다. */
export const TOKEN_ID_RE = /^[A-Za-z0-9_-]{1,64}$/;

/** 카트 품목 수 상한 (spec §15.1) — 토큰 절단을 구조적으로 막고 G2 읽기 비용(품목당 최대 3문서)의 뚜껑이 된다. */
export const MAX_CART_ITEMS = 50;

/**
 * 거절 토큰을 message 맨 끝에 붙인다 (spec §15.1):
 *   메뉴 사유 3종 `[MENU_SOLD_OUT:id1,id2]` · 그 외 3종 `[STORE_NOT_SELLABLE]` ...
 * 토큰에는 문법을 통과한 id 만 싣는다 (서버는 id 만 보내고 이름은 보내지 않는다).
 */
export function buildRejectionMessage(reason: GateReason, menuItemIds: readonly string[] = []): string {
  const ids = MENU_REASONS.has(reason) ? menuItemIds.filter((i) => TOKEN_ID_RE.test(i)) : [];
  const token = ids.length > 0 ? `[${reason}:${ids.join(",")}]` : `[${reason}]`;
  return `${GATE_TEXT[reason]} ${token}`;
}

// ── 읽기 포트 ────────────────────────────────────────────────────────────────

export interface MenuDocs {
  /** menuItemId → stores/{s}/menuItems/{id} (없으면 키 없음/null) */
  storeMenus: Map<string, RawDoc | null>;
  /** menuItemId → stores/{s}/menuOverrides/{id} */
  overrides: Map<string, RawDoc | null>;
  /** menuItemId → brands/{b}/menuItems/{id} (brandId 가 없으면 비어 있다) */
  masters: Map<string, RawDoc | null>;
}

export interface GateReader {
  /** stores/{storeId}. 문서가 없으면 null. 읽기 실패는 예외. */
  getStore(storeId: string): Promise<RawDoc | null>;
  /** §7.2 ② — getAll 1회로 묶는다. brandId 가 null 이면 마스터는 읽지 않는다. */
  getMenuDocs(storeId: string, brandId: string | null, menuItemIds: string[]): Promise<MenuDocs>;
  /**
   * 금액 게이트용 옵션 그룹 문서 (payment_price_authority R3). getAll 1 round-trip.
   * 반환 키는 `optionRefKey(scope, id)`; 문서가 없으면 null. brand scope 는 `brandId` 가 null 이면 읽지 않고 null.
   * 읽기 실패는 예외.
   */
  getOptionGroups(
    storeId: string,
    brandId: string | null,
    refs: ReadonlyArray<{ scope: "master" | "brand" | "store"; id: string }>
  ): Promise<Map<string, RawDoc | null>>;
}

// ── 평가 ─────────────────────────────────────────────────────────────────────

export interface GateCartItem {
  menuItemId: string;
  menuItemName?: string;
}

export interface ResolvedMenu {
  menuItemId: string;
  source: "store" | "master";
  /** 단가 포함 병합 결과 — N1(서버 가격 재계산)이 이 반환값만 소비하면 되게 한다 (spec Q6). 읽기 추가 0. */
  merged: MergedMenu;
}

export interface GateDetail {
  rawStatus: string | null;
  hasApprovedAt: boolean;
  violatedMenuItemIds: string[];
  violatedMenuNames: string[];
}

export type GateResult =
  | { ok: true; resolved: ResolvedMenu[]; storeBrandId: string | null }
  | {
      ok: false;
      reason: GateReason;
      /** 토큰에 실릴 menuItemId (메뉴 사유일 때). */
      menuItemIds: string[];
      detail: GateDetail;
    };

/** Firestore 경로 조립에 안전한 id 인가 ('/' 가 들어가면 다른 경로를 읽게 된다). */
export function isLookupSafeId(id: unknown): id is string {
  return typeof id === "string" && id.length > 0 && id.length <= 256 && !id.includes("/") && id !== "." && id !== "..";
}

function emptyDetail(over: Partial<GateDetail> = {}): GateDetail {
  return { rawStatus: null, hasApprovedAt: false, violatedMenuItemIds: [], violatedMenuNames: [], ...over };
}

/** 메뉴 사유 우선순위 — 토큰은 사유 1개만 싣는다. 고객이 가장 자주 마주치고 이름을 지목할 수 있는 순. */
const MENU_PRECEDENCE: CartMenuReason[] = ["MENU_SOLD_OUT", "MENU_EXCLUDED", "MENU_NOT_FOUND"];

export async function evaluatePaymentGate(
  reader: GateReader,
  cart: { storeId: string; items: GateCartItem[] }
): Promise<GateResult> {
  // ── G1: 매장 ────────────────────────────────────────────────────────────
  if (!isLookupSafeId(cart.storeId)) {
    return { ok: false, reason: "STORE_NOT_FOUND", menuItemIds: [], detail: emptyDetail() };
  }
  let store: RawDoc | null;
  try {
    store = await reader.getStore(cart.storeId);
  } catch (e) {
    console.error("[paymentGate] store read failed", e);
    return { ok: false, reason: "READ_FAILED", menuItemIds: [], detail: emptyDetail() };
  }
  if (store == null) {
    return { ok: false, reason: "STORE_NOT_FOUND", menuItemIds: [], detail: emptyDetail() };
  }
  const rawStatus = typeof store.status === "string" ? store.status : null;
  const hasApprovedAt = store.approvedAt != null;
  if (!canSellNow({ rawStatus, hasApprovedAt })) {
    return { ok: false, reason: "STORE_NOT_SELLABLE", menuItemIds: [], detail: emptyDetail({ rawStatus, hasApprovedAt }) };
  }
  const brandId = typeof store.brandId === "string" && store.brandId.length > 0 ? store.brandId : null;

  // ── G2: 메뉴 ────────────────────────────────────────────────────────────
  // 메뉴 종류 단위로 중복 제거한다 (같은 메뉴가 옵션이 달라 여러 줄이어도 1번 읽고 id 도 1번만 싣는다).
  const nameById = new Map<string, string>();
  const unsafeIds: string[] = [];
  for (const it of cart.items) {
    if (!isLookupSafeId(it?.menuItemId)) {
      unsafeIds.push(String(it?.menuItemId ?? ""));
      continue;
    }
    if (!nameById.has(it.menuItemId)) nameById.set(it.menuItemId, String(it.menuItemName ?? "").slice(0, 60));
  }
  const ids = [...nameById.keys()];

  let docs: MenuDocs;
  try {
    docs = await reader.getMenuDocs(cart.storeId, brandId, ids);
  } catch (e) {
    console.error("[paymentGate] menu read failed", e);
    return { ok: false, reason: "READ_FAILED", menuItemIds: [], detail: emptyDetail({ rawStatus, hasApprovedAt }) };
  }

  const byReason = new Map<CartMenuReason, string[]>();
  const resolved: ResolvedMenu[] = [];
  for (const id of ids) {
    const v = classifyCartMenu({
      hasBrand: brandId !== null,
      storeMenu: docs.storeMenus.get(id) ?? null,
      master: docs.masters.get(id) ?? null,
      override: docs.overrides.get(id) ?? null,
    });
    if (v.reason === null) {
      resolved.push({ menuItemId: id, source: v.source as "store" | "master", merged: v.merged as MergedMenu });
    } else {
      const list = byReason.get(v.reason) ?? [];
      list.push(id);
      byReason.set(v.reason, list);
    }
  }
  // 조회 불가능한 id(경로 오염 가능) 는 존재할 수 없는 메뉴다. 토큰 문법을 통과하지 못하므로 토큰에는 싣지 않는다.
  if (unsafeIds.length > 0 && !byReason.has("MENU_NOT_FOUND")) byReason.set("MENU_NOT_FOUND", []);

  const violatedIds = [...byReason.values()].flat();
  if (byReason.size > 0 || unsafeIds.length > 0) {
    const reason = MENU_PRECEDENCE.find((r) => byReason.has(r)) as CartMenuReason;
    return {
      ok: false,
      reason,
      menuItemIds: byReason.get(reason) ?? [],
      detail: {
        rawStatus,
        hasApprovedAt,
        violatedMenuItemIds: violatedIds,
        violatedMenuNames: violatedIds.map((i) => nameById.get(i) ?? ""),
      },
    };
  }
  return { ok: true, resolved, storeBrandId: brandId };
}

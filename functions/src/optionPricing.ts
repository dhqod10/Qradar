/**
 * 옵션 선택 가능 판정 — Dart `lib/core/utils/option_availability.dart` 의 **TS 포팅** (복제가 아니다).
 * payment_price_authority spec §4-1 사실 5, R4, R6. Firestore 비의존.
 *
 * 규칙 (Dart 와 같다, `test_fixtures/option_availability_contract.json` 이 고정):
 *  1. `active == false` 그룹은 선택할 수 없다.  2. 점주가 끈 그룹(`disabledOptionGroupIds`)은 선택할 수 없다.
 *  3. 항목은 composite `{groupId}_{itemId}` 가 `disabledOptionItemIds` 에 있으면 선택할 수 없다.
 *
 * 문서 값 해석은 Dart 모델 경로를 따른다: active 부재 = true, selectionType 모르는 값 = single, required 부재 = false,
 * priceDelta = `(num)?.toInt()` 즉 0 쪽 버림·부재 = 0, items 의 객체가 아닌 요소는 건너뛴다.
 * 이 파일이 TS 쪽 유일한 구현이다 (grep 가드: composite 조립 1곳, `optionGroupId`/`optionId` 0건).
 */

import { OptionGroupRef, OptionScope, RawDoc } from "./menuVisibility";

export type OptionIssueKind =
  | "missing"
  | "disabled"
  | "inactive"
  | "notInRefs"
  | "requiredEmpty"
  | "multiInSingle"
  | "duplicate";

export interface OptionIssue {
  groupId: string;
  /** 그룹 단위 위반(requiredEmpty / multiInSingle)이면 키 자체가 없다. */
  itemId?: string;
  kind: OptionIssueKind;
}

export interface OptionItemDoc {
  id: string;
  priceDelta: number;
}

export interface OptionGroupDoc {
  id: string;
  active: boolean;
  selectionType: "single" | "multi";
  required: boolean;
  items: OptionItemDoc[];
}

export interface OptionSelectionCheck {
  issues: OptionIssue[];
  /** 위반 없이 해석된 선택 항목의 가격 증감. 합산은 `cartPricing.ts computeLinePrice` 에서만 한다. */
  priceDeltas: number[];
}

/** (scope, id) → 읽기 결과 map 의 키. */
export function optionRefKey(scope: OptionScope, id: string): string {
  return `${scope}:${id}`;
}

/** 항목 비활성 composite 키 `{groupId}_{itemId}` — **TS 에서 이 조립은 이 함수 1곳뿐이다** (grep 가드). */
export function isOptionItemDisabled(groupId: string, itemId: string, disabledItemIds: ReadonlySet<string>): boolean {
  return disabledItemIds.has(`${groupId}_${itemId}`);
}

/** Dart `(num?)?.toInt() ?? 0` — 0 쪽 버림. */
function asDelta(v: unknown): number {
  return typeof v === "number" && Number.isFinite(v) ? Math.trunc(v) : 0;
}

/** 그룹 문서 → 판정 입력. Dart `OptionGroupModel.fromData(...).toEntity()` 와 같은 해석이다. */
export function parseOptionGroup(id: string, doc: RawDoc): OptionGroupDoc {
  const rawItems = Array.isArray(doc.items) ? doc.items : [];
  const items: OptionItemDoc[] = [];
  for (const e of rawItems) {
    if (typeof e !== "object" || e === null || Array.isArray(e)) continue;
    const m = e as RawDoc;
    items.push({ id: typeof m.id === "string" ? m.id : "", priceDelta: asDelta(m.priceDelta) });
  }
  return {
    id,
    active: typeof doc.active === "boolean" ? doc.active : true,
    selectionType: doc.selectionType === "multi" ? "multi" : "single",
    required: typeof doc.required === "boolean" ? doc.required : false,
    items,
  };
}

type GroupState = "selectable" | "inactive" | "disabled";

function groupState(g: OptionGroupDoc, disabledGroupIds: ReadonlySet<string>): GroupState {
  if (!g.active) return "inactive";
  if (disabledGroupIds.has(g.id)) return "disabled";
  return "selectable";
}

/** 고객에게 보이는(=선택 가능한) 그룹·항목만 남긴다. 입력 순서 유지. */
export function resolveSelectableOptions(args: {
  groups: readonly OptionGroupDoc[];
  disabledGroupIds?: ReadonlySet<string>;
  disabledItemIds?: ReadonlySet<string>;
}): OptionGroupDoc[] {
  const disabledGroupIds = args.disabledGroupIds ?? new Set<string>();
  const disabledItemIds = args.disabledItemIds ?? new Set<string>();
  const out: OptionGroupDoc[] = [];
  for (const g of args.groups) {
    if (groupState(g, disabledGroupIds) !== "selectable") continue;
    if (disabledItemIds.size === 0) {
      out.push(g);
      continue;
    }
    out.push({ ...g, items: g.items.filter((i) => !isOptionItemDisabled(g.id, i.id, disabledItemIds)) });
  }
  return out;
}

/** 카트 라인 하나의 옵션 선택이 지금 유효한가 (spec R4). Dart `validateSelection` 과 이슈 순서까지 같다. */
export function validateSelection(args: {
  refs: readonly OptionGroupRef[];
  groupsByRefKey: ReadonlyMap<string, OptionGroupDoc | null>;
  disabledGroupIds?: ReadonlySet<string>;
  disabledItemIds?: ReadonlySet<string>;
  selected: ReadonlyArray<{ groupId: string; itemId: string }>;
}): OptionSelectionCheck {
  const disabledGroupIds = args.disabledGroupIds ?? new Set<string>();
  const disabledItemIds = args.disabledItemIds ?? new Set<string>();
  const refOf = (groupId: string): OptionGroupRef | undefined => args.refs.find((r) => r.id === groupId);
  const groupOf = (r: OptionGroupRef): OptionGroupDoc | null => args.groupsByRefKey.get(optionRefKey(r.scope, r.id)) ?? null;

  const issues: OptionIssue[] = [];
  const priceDeltas: number[] = [];
  const counts = new Map<string, number>();
  const seen = new Set<string>();

  for (const sel of args.selected) {
    const ref = refOf(sel.groupId);
    if (ref === undefined) {
      issues.push({ groupId: sel.groupId, itemId: sel.itemId, kind: "notInRefs" });
      continue;
    }
    const group = groupOf(ref);
    if (group === null) {
      issues.push({ groupId: sel.groupId, itemId: sel.itemId, kind: "missing" });
      continue;
    }
    const state = groupState(group, disabledGroupIds);
    if (state !== "selectable") {
      issues.push({ groupId: sel.groupId, itemId: sel.itemId, kind: state === "inactive" ? "inactive" : "disabled" });
      continue;
    }
    const item = group.items.find((i) => i.id === sel.itemId);
    if (item === undefined) {
      issues.push({ groupId: sel.groupId, itemId: sel.itemId, kind: "missing" });
      continue;
    }
    if (isOptionItemDisabled(group.id, item.id, disabledItemIds)) {
      issues.push({ groupId: sel.groupId, itemId: sel.itemId, kind: "disabled" });
      continue;
    }
    const dupKey = `${sel.groupId}\u0000${sel.itemId}`;
    if (seen.has(dupKey)) {
      issues.push({ groupId: sel.groupId, itemId: sel.itemId, kind: "duplicate" });
      continue;
    }
    seen.add(dupKey);
    counts.set(group.id, (counts.get(group.id) ?? 0) + 1);
    priceDeltas.push(item.priceDelta);
  }

  // 그룹 단위 제약: 선택 가능한 그룹만 본다 (끈 그룹의 required 는 요구할 수 없다).
  const checked = new Set<string>();
  for (const ref of args.refs) {
    if (checked.has(ref.id)) continue;
    checked.add(ref.id);
    const group = groupOf(ref);
    if (group === null) continue;
    if (groupState(group, disabledGroupIds) !== "selectable") continue;
    const n = counts.get(group.id) ?? 0;
    if (group.required && n === 0) issues.push({ groupId: group.id, kind: "requiredEmpty" });
    if (group.selectionType === "single" && n > 1) issues.push({ groupId: group.id, kind: "multiInSingle" });
  }

  return { issues, priceDeltas };
}

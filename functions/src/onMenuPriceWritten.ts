/**
 * onMenuPriceWritten — 가격 변경 이력 트리거 (payment_price_authority R16 / Q7 ⓐ, audit_trail §4-1).
 *
 * **쓰기 경로를 하나도 건드리지 않는다.** 가격을 쓰는 클라이언트(점주·브랜드·admin)는 그대로이고, 트리거가 사후에 `priceHistory` 에
 * 남긴다. Rules 로는 "이력을 같이 쓰라" 를 강제할 수 없고(클라이언트가 이력만 빼고 쓸 수 있다), 트리거는 클라이언트 직접 쓰기도
 * 포착하므로 트리거여야 한다. 이 task 가 가격을 **돈의 권위**로 승격시키므로 "그때 얼마였나" 를 답할 수 있어야 한다.
 *
 * 한 Firestore 트리거는 한 문서 경로만 가리키므로 같은 핵심(`recordPriceChange`)을 쓰는 진입점이 문서 종류별로 있다:
 *   onMenuPriceWritten            stores/{s}/menuItems/{id}        basePrice
 *   onBrandMenuPriceWritten       brands/{b}/menuItems/{id}        basePrice
 *   onMenuOverridePriceWritten    stores/{s}/menuOverrides/{id}    priceOverride + status (승인 여부가 효력을 정한다)
 *   onOptionGroupPriceWritten     stores/{s}/optionGroups/{id}     items[].priceDelta   (store scope — 승인 없이 즉시 효력, Q8)
 *   onBrandOptionGroupPriceWritten brands/{b}/optionGroups/{id}    items[].priceDelta
 *   onMasterOptionGroupPriceWritten optionGroups/{id}              items[].priceDelta   (legacy master)
 *
 * 변경이 가격 필드에 없으면(다른 필드만 바뀜) 기록하지 않는다. 생성·삭제도 기록한다(before/after 중 한쪽이 null).
 * 문서 ID 는 이벤트 ID — 트리거는 at-least-once 라 재전달이 와도 같은 문서에 덮어써 중복이 생기지 않는다.
 * 기록 실패는 로그만 남기고 삼킨다 (재시도 폭주 방지; 이력은 원 쓰기를 막지 않는다).
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { onDocumentWrittenWithAuthContext } from "firebase-functions/v2/firestore";

const REGION = "asia-northeast3";

export type PriceHistoryKind = "menuItem" | "menuOverride" | "optionGroup";
export type PriceHistoryScope = "store" | "brand" | "master";

type Doc = Record<string, unknown>;

export interface PriceSnapshot {
  [k: string]: unknown;
}

/** 문서 → 가격 필드만 뽑은 스냅샷. 문서가 없으면 null. 원시 값을 그대로 둔다(증거이므로 정규화하지 않는다). */
export function priceSnapshot(kind: PriceHistoryKind, doc: Doc | null | undefined): PriceSnapshot | null {
  if (doc == null) return null;
  switch (kind) {
    case "menuItem":
      return { basePrice: doc.basePrice ?? null };
    case "menuOverride":
      // status 를 함께 남긴다 — priceOverride 는 status == approved 일 때만 효력이 있다.
      return { priceOverride: doc.priceOverride ?? null, status: doc.status ?? null, approvedBy: doc.approvedBy ?? null };
    case "optionGroup": {
      const out: Record<string, unknown> = {};
      const items = Array.isArray(doc.items) ? doc.items : [];
      for (const it of items) {
        if (typeof it !== "object" || it === null) continue;
        const m = it as Doc;
        if (typeof m.id === "string") out[m.id] = m.priceDelta ?? null;
      }
      return { priceDeltas: out };
    }
  }
}

/** 두 스냅샷이 같은가 (키 순서 무관). */
function sameSnapshot(a: PriceSnapshot | null, b: PriceSnapshot | null): boolean {
  const norm = (v: unknown): unknown => {
    if (Array.isArray(v)) return v.map(norm);
    if (typeof v === "object" && v !== null) {
      return Object.fromEntries(Object.keys(v as Doc).sort().map((k) => [k, norm((v as Doc)[k])]));
    }
    return v;
  };
  return JSON.stringify(norm(a)) === JSON.stringify(norm(b));
}

export interface PriceChange {
  kind: PriceHistoryKind;
  before: PriceSnapshot | null;
  after: PriceSnapshot | null;
}

/** 가격 필드가 바뀌었으면 변경 1건, 아니면 null. 순수 함수 — 단위 테스트 대상. */
export function diffPriceChange(kind: PriceHistoryKind, before: Doc | null | undefined, after: Doc | null | undefined): PriceChange | null {
  const b = priceSnapshot(kind, before);
  const a = priceSnapshot(kind, after);
  if (sameSnapshot(b, a)) return null;
  return { kind, before: b, after: a };
}

export interface PriceHistoryTarget {
  scope: PriceHistoryScope;
  storeId: string | null;
  brandId: string | null;
  targetId: string;
}

/** 이력 문서 1건. `changedBy` 는 이벤트의 인증 주체(클라이언트 쓰기면 uid, Admin SDK/CF 쓰기면 null + authType). */
export function buildPriceHistoryDoc<TS>(
  change: PriceChange,
  target: PriceHistoryTarget,
  actor: { authType: string | null; authId: string | null },
  changedAt: TS
): Record<string, unknown> {
  return {
    kind: change.kind,
    scope: target.scope,
    storeId: target.storeId,
    brandId: target.brandId,
    targetId: target.targetId,
    before: change.before,
    after: change.after,
    changedBy: actor.authId,
    authType: actor.authType,
    changedAt,
  };
}

export async function recordPriceChange(
  db: admin.firestore.Firestore,
  args: {
    eventId: string;
    kind: PriceHistoryKind;
    target: PriceHistoryTarget;
    before: Doc | null | undefined;
    after: Doc | null | undefined;
    actor: { authType: string | null; authId: string | null };
  }
): Promise<boolean> {
  const change = diffPriceChange(args.kind, args.before, args.after);
  if (change === null) return false;
  try {
    await db
      .collection("priceHistory")
      .doc(args.eventId)
      .set(buildPriceHistoryDoc(change, args.target, args.actor, FieldValue.serverTimestamp()));
    return true;
  } catch (e) {
    console.error("[onMenuPriceWritten] history write failed", args.kind, args.target.targetId, e);
    return false;
  }
}

type PriceEvent = {
  id: string;
  authType?: string;
  authId?: string;
  params: Record<string, string>;
  data?: { before?: { exists: boolean; data(): Doc | undefined }; after?: { exists: boolean; data(): Doc | undefined } };
};

function handler(kind: PriceHistoryKind, targetOf: (p: Record<string, string>) => PriceHistoryTarget) {
  return async (event: PriceEvent) => {
    const before = event.data?.before?.exists ? event.data.before.data() : null;
    const after = event.data?.after?.exists ? event.data.after.data() : null;
    await recordPriceChange(admin.firestore(), {
      eventId: event.id,
      kind,
      target: targetOf(event.params),
      before,
      after,
      actor: { authType: event.authType ?? null, authId: event.authId ?? null },
    });
  };
}

const store = (p: Record<string, string>, id: string): PriceHistoryTarget => ({ scope: "store", storeId: p.storeId, brandId: null, targetId: id });
const brand = (p: Record<string, string>, id: string): PriceHistoryTarget => ({ scope: "brand", storeId: null, brandId: p.brandId, targetId: id });

export const onMenuPriceWritten = onDocumentWrittenWithAuthContext(
  { document: "stores/{storeId}/menuItems/{menuItemId}", region: REGION },
  handler("menuItem", (p) => store(p, p.menuItemId))
);
export const onBrandMenuPriceWritten = onDocumentWrittenWithAuthContext(
  { document: "brands/{brandId}/menuItems/{menuItemId}", region: REGION },
  handler("menuItem", (p) => brand(p, p.menuItemId))
);
export const onMenuOverridePriceWritten = onDocumentWrittenWithAuthContext(
  { document: "stores/{storeId}/menuOverrides/{masterMenuItemId}", region: REGION },
  handler("menuOverride", (p) => store(p, p.masterMenuItemId))
);
export const onOptionGroupPriceWritten = onDocumentWrittenWithAuthContext(
  { document: "stores/{storeId}/optionGroups/{groupId}", region: REGION },
  handler("optionGroup", (p) => store(p, p.groupId))
);
export const onBrandOptionGroupPriceWritten = onDocumentWrittenWithAuthContext(
  { document: "brands/{brandId}/optionGroups/{groupId}", region: REGION },
  handler("optionGroup", (p) => brand(p, p.groupId))
);
export const onMasterOptionGroupPriceWritten = onDocumentWrittenWithAuthContext(
  { document: "optionGroups/{groupId}", region: REGION },
  handler("optionGroup", (p) => ({ scope: "master", storeId: null, brandId: null, targetId: p.groupId }))
);

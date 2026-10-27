/**
 * 결제 게이트의 Firestore 어댑터 — `GateReader`(paymentGate.ts) 구현 + 거절 기록 (`paymentGateRejections`).
 * payment_server_authority spec §7.2 ②, §9-7.
 */

import * as admin from "firebase-admin";
import { GateDetail, GateReader, GateReason, MenuDocs } from "./paymentGate";
import { RawDoc } from "./menuVisibility";
import { optionRefKey } from "./optionPricing";

export function makeFirestoreGateReader(db: admin.firestore.Firestore): GateReader {
  return {
    async getStore(storeId) {
      const snap = await db.collection("stores").doc(storeId).get();
      return snap.exists ? (snap.data() as RawDoc) : null;
    },

    async getMenuDocs(storeId, brandId, menuItemIds): Promise<MenuDocs> {
      const out: MenuDocs = { storeMenus: new Map(), overrides: new Map(), masters: new Map() };
      if (menuItemIds.length === 0) return out;
      const store = db.collection("stores").doc(storeId);
      // 한 번의 getAll round-trip (spec §7.2 ②). 순서: [storeMenu × n][override × n][master × n(brandId 있을 때)]
      const refs: admin.firestore.DocumentReference[] = [];
      for (const id of menuItemIds) refs.push(store.collection("menuItems").doc(id));
      if (brandId !== null) {
        for (const id of menuItemIds) refs.push(store.collection("menuOverrides").doc(id));
        for (const id of menuItemIds) refs.push(db.collection("brands").doc(brandId).collection("menuItems").doc(id));
      }
      const snaps = await db.getAll(...refs);
      const n = menuItemIds.length;
      const data = (i: number): RawDoc | null => (snaps[i].exists ? (snaps[i].data() as RawDoc) : null);
      menuItemIds.forEach((id, k) => {
        out.storeMenus.set(id, data(k));
        if (brandId !== null) {
          out.overrides.set(id, data(n + k));
          out.masters.set(id, data(2 * n + k));
        }
      });
      return out;
    },

    /**
     * 옵션 그룹 문서 — 한 번의 getAll round-trip (payment_price_authority R3). 경로 조립에 안전하지 않은 id·brandId 없는
     * brand scope 는 읽지 않고 null(=문서 부재)로 돌려준다.
     */
    async getOptionGroups(storeId, brandId, refs) {
      const out = new Map<string, RawDoc | null>();
      const reads: Array<{ key: string; ref: admin.firestore.DocumentReference }> = [];
      for (const r of refs) {
        const key = optionRefKey(r.scope, r.id);
        if (out.has(key)) continue;
        out.set(key, null);
        if (r.id.length === 0 || r.id.length > 256 || r.id.includes("/") || r.id === "." || r.id === "..") continue;
        if (r.scope === "master") reads.push({ key, ref: db.collection("optionGroups").doc(r.id) });
        else if (r.scope === "store") reads.push({ key, ref: db.collection("stores").doc(storeId).collection("optionGroups").doc(r.id) });
        else if (brandId !== null) reads.push({ key, ref: db.collection("brands").doc(brandId).collection("optionGroups").doc(r.id) });
      }
      if (reads.length === 0) return out;
      const snaps = await db.getAll(...reads.map((x) => x.ref));
      snaps.forEach((snap, i) => {
        if (snap.exists) out.set(reads[i].key, snap.data() as RawDoc);
      });
      return out;
    },
  };
}

/**
 * 거절 1건을 영구 기록한다 (spec §9-7). Cloud Logging 만으로는 보존 기간 뒤에 오탐 분포를 영구히 못 본다.
 * **기록 실패는 거절 결과를 바꾸지 않는다** — 로그만 남기고 삼킨다 (기록 때문에 거절이 통과로 뒤집히거나 다른 오류로 바뀌면 안 된다).
 */
export async function recordGateRejection(
  db: admin.firestore.Firestore,
  rec: { uid: string; storeId: string; reason: GateReason; detail: GateDetail | object; amount: number; shadow?: boolean }
): Promise<void> {
  try {
    await db.collection("paymentGateRejections").add({
      uid: rec.uid,
      storeId: rec.storeId,
      reason: rec.reason,
      // shadow 모드의 기록은 detail.shadow:true — 거절이 아니라 '거절되었을 건'이다 (enforce 기록에는 이 키가 없다).
      detail: rec.shadow ? { ...rec.detail, shadow: true } : rec.detail,
      amount: rec.amount,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (e) {
    console.error("[paymentGate] rejection record failed", rec.reason, e);
  }
}

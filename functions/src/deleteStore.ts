/**
 * deleteStore — callable (admin 전용). 매장 하드 삭제의 **유일한 정상 경로** (payment_server_authority D1, spec §11).
 *
 * 입력 { storeId, reason?, dryRun } — dryRun:true 는 쓰기 0건, 영향 범위만 센다 (화면 숫자와 삭제가 센 숫자가 같은 코드에서 나온다).
 *
 * 실행 순서 (spec §11.2) — 이력 문서 `storeDeletionHistory/{deletionId}` 가 **재진입점**이다 (매장 문서는 ② 에서 사라진다):
 *   (가드) 진행 중 주문이 있으면 차단 — 이력도 남기지 않는다 (§11.4. 매장이 없으면 cancelTossPayment/processRefund 가 막혀 돈이 묶인다)
 *   ① 이력 phase:'started' (스냅샷 포함)  ② 매장 문서 삭제 → 점주 하위 쓰기가 즉시 봉쇄된다  ③ 서브컬렉션 재귀 삭제
 *   ④ Storage 이미지  ⑤ phase:'done'
 * 각 단계가 끝날 때마다 phase 를 기록하고, 재실행은 이력의 phase 이후 단계만 수행한다 → 이력 1건 (중복 기록 없음).
 * deletionId = `${storeId}_${createdAtMillis}` (createdAt 부재 = `${storeId}_0`) — 같은 ID 로 재생성된 매장의 삭제는 별도 이력.
 */
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { REGION, requireAdmin } from "./qoinAdmin";

export const IN_FLIGHT_STATUSES = ["paid", "accepted", "making", "ready"] as const;
export const SUBCOLLECTIONS = ["menuItems", "menuOverrides", "subCategories", "optionGroups", "qoinRateHistory"] as const;

export type DeletionPhase = "started" | "docDeleted" | "subDeleted" | "storageDeleted" | "done";
const PHASE_ORDER: DeletionPhase[] = ["started", "docDeleted", "subDeleted", "storageDeleted", "done"];
const atLeast = (p: DeletionPhase, q: DeletionPhase) => PHASE_ORDER.indexOf(p) >= PHASE_ORDER.indexOf(q);

export interface Affected {
  menuItems: number;
  menuOverrides: number;
  subCategories: number;
  optionGroups: number;
  qoinRateHistory: number;
  images: number;
  inFlightOrders: number;
}

type RawDoc = Record<string, unknown>;

export interface HistoryDoc {
  id: string;
  phase: DeletionPhase;
  storeId: string;
  imageUrls?: string[];
  affected?: Affected;
}

export interface DeletePorts {
  readStore(storeId: string): Promise<RawDoc | null>;
  /** storeId 의 가장 최근 이력 (deletionId 를 모를 때 — 매장 문서가 이미 사라진 재실행). */
  findLatestHistory(storeId: string): Promise<HistoryDoc | null>;
  readHistory(deletionId: string): Promise<HistoryDoc | null>;
  /** set(merge). */
  writeHistory(deletionId: string, patch: Record<string, unknown>): Promise<void>;
  countAffected(storeId: string, imageUrls: string[]): Promise<Affected>;
  deleteStoreDoc(storeId: string): Promise<void>;
  /** 서브컬렉션 재귀 삭제. 실제 지운 문서 수를 돌려준다 (이미 없으면 0 — 본질적으로 멱등). */
  deleteSubcollections(storeId: string): Promise<Partial<Affected>>;
  deleteImages(urls: string[]): Promise<void>;
}

export function storeImageUrls(store: RawDoc): string[] {
  const out = new Set<string>();
  if (typeof store.imageUrl === "string" && store.imageUrl) out.add(store.imageUrl);
  if (Array.isArray(store.imageUrls)) for (const u of store.imageUrls) if (typeof u === "string" && u) out.add(u);
  return [...out];
}

function createdAtMillis(store: RawDoc): number {
  const c = store.createdAt as { toMillis?: () => number } | undefined;
  return c && typeof c.toMillis === "function" ? c.toMillis() : 0;
}

export type DeleteResult =
  | { alreadyDeleted: true }
  | { dryRun: true; affected: Affected; blockedBy: { inFlightOrders: number } }
  | { dryRun?: false; deletionId: string; phase: "done"; affected: Affected };

export async function runDeleteStore(
  ports: DeletePorts,
  args: { storeId: string; reason: string | null; dryRun: boolean; adminUid: string }
): Promise<DeleteResult> {
  const { storeId, dryRun } = args;
  const store = await ports.readStore(storeId);

  // ── 어느 이력을 이어갈 것인가 ──────────────────────────────────────────────
  let deletionId: string;
  let history: HistoryDoc | null;
  if (store) {
    deletionId = `${storeId}_${createdAtMillis(store)}`;
    history = await ports.readHistory(deletionId);
    if (history && history.phase === "done") {
      // 같은 createdAt 으로 재생성된 매장 (legacy `_0` 등) — 완료된 이력을 덮어쓰지 않고 별도 이력으로.
      deletionId = `${deletionId}_r${Date.now()}`;
      history = null;
    }
  } else {
    history = await ports.findLatestHistory(storeId);
    if (!history) throw new HttpsError("not-found", "매장을 찾을 수 없습니다.");
    if (history.phase === "done") return { alreadyDeleted: true };
    deletionId = history.id;
  }

  const phase: DeletionPhase | null = history ? history.phase : null;
  const imageUrls = store ? storeImageUrls(store) : history?.imageUrls ?? [];

  // ── dryRun: 쓰기 0건 ───────────────────────────────────────────────────────
  if (dryRun) {
    const affected = await ports.countAffected(storeId, imageUrls);
    return { dryRun: true, affected, blockedBy: { inFlightOrders: affected.inFlightOrders } };
  }

  // ── 진행 중 주문 가드 (이력 쓰기보다 먼저 — 차단은 삭제 시도가 아니다) ─────────
  // 이미 매장 문서가 삭제된 재실행(phase ≥ docDeleted)에서는 건너뛴다: 매장이 없으면 새 주문이 생길 수 없다.
  let affected: Affected | null = null;
  if (!phase || phase === "started") {
    affected = await ports.countAffected(storeId, imageUrls);
    if (affected.inFlightOrders > 0) {
      throw new HttpsError(
        "failed-precondition",
        `진행 중인 주문이 ${affected.inFlightOrders}건 있어요 [STORE_HAS_INFLIGHT_ORDERS]`,
        { reason: "STORE_HAS_INFLIGHT_ORDERS", inFlightOrders: affected.inFlightOrders }
      );
    }
  }

  // ① 이력 (가장 먼저)
  if (!phase) {
    await ports.writeHistory(deletionId, {
      storeId,
      storeName: typeof store?.name === "string" ? store.name : "",
      ownerId: typeof store?.ownerId === "string" ? store.ownerId : null,
      brandId: typeof store?.brandId === "string" ? store.brandId : null,
      status: typeof store?.status === "string" ? store.status : null,
      deletedBy: args.adminUid,
      deletedAt: FieldValue.serverTimestamp(),
      reason: args.reason,
      snapshot: store,
      imageUrls,
      affected,
      phase: "started" as DeletionPhase,
    });
  }
  let cur: DeletionPhase = phase ?? "started";

  // ② 매장 문서 삭제 (쓰기 봉쇄)
  if (!atLeast(cur, "docDeleted")) {
    await ports.deleteStoreDoc(storeId);
    await ports.writeHistory(deletionId, { phase: "docDeleted" });
    cur = "docDeleted";
  }
  // ③ 서브컬렉션
  let deleted: Partial<Affected> | null = null;
  if (!atLeast(cur, "subDeleted")) {
    deleted = await ports.deleteSubcollections(storeId);
    await ports.writeHistory(deletionId, { phase: "subDeleted" });
    cur = "subDeleted";
  }
  // ④ Storage
  if (!atLeast(cur, "storageDeleted")) {
    await ports.deleteImages(imageUrls);
    await ports.writeHistory(deletionId, { phase: "storageDeleted" });
    cur = "storageDeleted";
  }
  // ⑤ 완료 + 실행 시점 affected 확정 (화면 숫자는 쓰지 않는다)
  const base = affected ?? history?.affected ?? (await ports.countAffected(storeId, imageUrls));
  // ③ 이 중단 후 재실행이면 남은 것만 센다 → 키별 max (먼저 센 값을 더 작은 값으로 덮어쓰지 않는다. 그 사이 새로 생긴 하위 문서는 반영된다).
  const finalAffected: Affected = { ...base, images: imageUrls.length, inFlightOrders: base.inFlightOrders };
  for (const k of SUBCOLLECTIONS) finalAffected[k] = Math.max(base[k], deleted?.[k] ?? 0);
  await ports.writeHistory(deletionId, { phase: "done", affected: finalAffected, completedAt: FieldValue.serverTimestamp() });
  return { deletionId, phase: "done", affected: finalAffected };
}

// ── Firestore / Storage 어댑터 ───────────────────────────────────────────────

/** `https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{encodedPath}?...` → {bucket, path}. 그 외 URL 은 null. */
export function parseStorageUrl(url: string): { bucket: string; path: string } | null {
  try {
    const u = new URL(url);
    if (u.hostname !== "firebasestorage.googleapis.com") return null;
    const m = u.pathname.match(/^\/v0\/b\/([^/]+)\/o\/(.+)$/);
    if (!m) return null;
    return { bucket: m[1], path: decodeURIComponent(m[2]) };
  } catch {
    return null;
  }
}

export function makeFirestoreDeletePorts(db: admin.firestore.Firestore): DeletePorts {
  const hist = db.collection("storeDeletionHistory");
  const countOf = async (q: admin.firestore.Query) => (await q.count().get()).data().count;
  return {
    async readStore(storeId) {
      const s = await db.collection("stores").doc(storeId).get();
      return s.exists ? (s.data() as RawDoc) : null;
    },
    async findLatestHistory(storeId) {
      // 단일 필드 등식 쿼리(인덱스 불요). 같은 storeId 의 이력이 여럿이면 deletedAt 이 가장 큰 것을 클라이언트에서 고른다.
      const snap = await hist.where("storeId", "==", storeId).get();
      if (snap.empty) return null;
      const ms = (d: admin.firestore.QueryDocumentSnapshot) => {
        const t = d.get("deletedAt") as { toMillis?: () => number } | undefined;
        return t && typeof t.toMillis === "function" ? t.toMillis() : 0;
      };
      const docs = [...snap.docs].sort((a, b) => ms(b) - ms(a));
      // 미완료 이력이 있으면 그것을 우선한다 (재진입점).
      const d = docs.find((x) => x.get("phase") !== "done") ?? docs[0];
      return { id: d.id, ...(d.data() as Omit<HistoryDoc, "id">) };
    },
    async readHistory(deletionId) {
      const s = await hist.doc(deletionId).get();
      return s.exists ? ({ id: s.id, ...(s.data() as Omit<HistoryDoc, "id">) }) : null;
    },
    async writeHistory(deletionId, patch) {
      await hist.doc(deletionId).set(patch, { merge: true });
    },
    async countAffected(storeId, imageUrls) {
      const store = db.collection("stores").doc(storeId);
      const [menuItems, menuOverrides, subCategories, optionGroups, qoinRateHistory, inFlightOrders] = await Promise.all([
        countOf(store.collection("menuItems")),
        countOf(store.collection("menuOverrides")),
        countOf(store.collection("subCategories")),
        countOf(store.collection("optionGroups")),
        countOf(store.collection("qoinRateHistory")),
        countOf(db.collection("orders").where("storeId", "==", storeId).where("status", "in", [...IN_FLIGHT_STATUSES])),
      ]);
      return { menuItems, menuOverrides, subCategories, optionGroups, qoinRateHistory, images: imageUrls.length, inFlightOrders };
    },
    async deleteStoreDoc(storeId) {
      await db.collection("stores").doc(storeId).delete();
    },
    async deleteSubcollections(storeId) {
      const store = db.collection("stores").doc(storeId);
      const out: Partial<Affected> = {};
      for (const name of SUBCOLLECTIONS) out[name] = await countOf(store.collection(name));
      // 하위 문서 전부(예상 밖 서브컬렉션 포함) 재귀 삭제. 문서가 이미 없어도 하위는 지워진다.
      await db.recursiveDelete(store);
      return out;
    },
    async deleteImages(urls) {
      for (const url of urls) {
        const p = parseStorageUrl(url);
        if (!p) continue; // 외부 URL 은 건드리지 않는다
        // 실패하면 예외 → phase 가 진행되지 않고, 재실행이 남은 것부터 지운다 (ignoreNotFound 로 이미 지운 것은 건너뛴다).
        await admin.storage().bucket(p.bucket).file(p.path).delete({ ignoreNotFound: true });
      }
    },
  };
}

export const deleteStore = onCall({ region: REGION, timeoutSeconds: 300 }, async (request) => {
  const db = admin.firestore();
  const adminUid = await requireAdmin(db, request);
  const d = (request.data ?? {}) as { storeId?: unknown; reason?: unknown; dryRun?: unknown };
  if (typeof d.storeId !== "string" || d.storeId.length === 0 || d.storeId.includes("/")) {
    throw new HttpsError("invalid-argument", "storeId required");
  }
  const dryRun = d.dryRun === true;
  let reason: string | null = null;
  if (!dryRun) {
    const r = typeof d.reason === "string" ? d.reason.trim() : "";
    if (r.length < 2 || r.length > 200) throw new HttpsError("invalid-argument", "reason must be 2-200 chars");
    reason = r;
  }
  const result = await runDeleteStore(makeFirestoreDeletePorts(db), { storeId: d.storeId, reason, dryRun, adminUid });
  console.info("[deleteStore]", dryRun ? "dryRun" : "run", { storeId: d.storeId, adminUid });
  return result;
});

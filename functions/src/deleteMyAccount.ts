/**
 * deleteMyAccount — callable (본인 uid). customer 회원 탈퇴 = **소프트 삭제 / 익명화** (account_deletion spec).
 *
 * 입력 { reason?, dryRun } — dryRun:true 는 쓰기 0건, `{inFlightOrders, qoinToForfeit, canDelete}` 만 돌려준다.
 *
 * 실행 순서 — 이력 문서 `accountDeletionHistory/{deletionId}` 가 **재진입점**이다 (deleteStore 와 같은 구조):
 *   (가드) 진행 중 주문(paid/accepted/making/ready)이 있으면 차단 — 이력도 남기지 않는다
 *   ① 이력 phase:'started' (users 스냅샷 포함 — 익명화로 사라질 PII 의 감사 박제)
 *   ② Qoin 소멸 (원장 1건 + 잔액 0, 한 트랜잭션)  ③ users 익명화 + deleted 플래그  ④ favorites 삭제
 *   ⑤ Firebase Auth 계정 삭제 (**마지막** — 삭제 후엔 request.auth 가 무효가 되므로 Firestore 작업을 먼저 끝낸다)
 *   ⑥ phase:'done'
 * 주문·orderLogs·Qoin 원장은 **보존**한다 (정산·감사·전자상거래법, PII 스냅샷 없음).
 */
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { CallableRequest, HttpsError, onCall } from "firebase-functions/v2/https";
import { REGION } from "./qoinAdmin";
import { IN_FLIGHT_STATUSES } from "./deleteStore";

export const ANONYMIZED_NAME = "(탈퇴한 사용자)";
export const INFLIGHT_TOKEN = "ACCOUNT_HAS_INFLIGHT_ORDERS";

export type AccountPhase =
  | "started"
  | "qoinForfeited"
  | "anonymized"
  | "favoritesDeleted"
  | "authDeleted"
  | "done";
const PHASE_ORDER: AccountPhase[] = ["started", "qoinForfeited", "anonymized", "favoritesDeleted", "authDeleted", "done"];
const atLeast = (p: AccountPhase, q: AccountPhase) => PHASE_ORDER.indexOf(p) >= PHASE_ORDER.indexOf(q);

type RawDoc = Record<string, unknown>;

export interface AccountHistoryDoc {
  id: string;
  phase: AccountPhase;
  forfeitedQoin?: number;
  affected?: { favoriteStores: number; favoriteMenuItems: number };
}

export interface AccountPorts {
  readUser(uid: string): Promise<RawDoc | null>;
  /** 미완료(phase != done) 이력 — 재진입점. 없으면 null. */
  findIncompleteHistory(uid: string): Promise<AccountHistoryDoc | null>;
  /** set(merge). */
  writeHistory(deletionId: string, patch: Record<string, unknown>): Promise<void>;
  countInFlightOrders(uid: string): Promise<number>;
  /** 잔액>0 이면 소멸 원장 1건 + 잔액 0 (한 트랜잭션, 이미 소멸 원장이 있으면 no-op). 소멸한 액을 돌려준다 (없으면 0). */
  forfeitQoin(uid: string, deletionId: string): Promise<number>;
  /** PII 제거 + displayName 치환 + deleted 플래그. 멱등 (같은 결과로 덮어씀). */
  anonymizeUser(uid: string, reason: string | null): Promise<void>;
  /** favoriteStores / favoriteMenuItems 서브컬렉션 삭제. 지운 건수 (이미 없으면 0). */
  deleteFavorites(uid: string): Promise<{ favoriteStores: number; favoriteMenuItems: number }>;
  /** Firebase Auth 계정 삭제. 이미 없으면 성공으로 본다. */
  deleteAuthUser(uid: string): Promise<void>;
}

export type DeleteAccountResult =
  | { alreadyDeleted: true }
  | { dryRun: true; inFlightOrders: number; qoinToForfeit: number; canDelete: boolean }
  | { dryRun?: false; deletionId: string; phase: "done"; forfeitedQoin: number };

function qoinOf(user: RawDoc | null): number {
  const b = user?.qoinBalance;
  return typeof b === "number" && Number.isFinite(b) && b > 0 ? Math.floor(b) : 0;
}

export async function runDeleteMyAccount(
  ports: AccountPorts,
  args: { uid: string; reason: string | null; dryRun: boolean }
): Promise<DeleteAccountResult> {
  const { uid, dryRun } = args;
  const user = await ports.readUser(uid);
  const history = await ports.findIncompleteHistory(uid);

  if (!history) {
    if (!user) throw new HttpsError("not-found", "사용자를 찾을 수 없습니다.");
    if (user.deleted === true) return { alreadyDeleted: true };
  }
  // customer 만 (Phase 1). 익명화 후에도 role 은 보존되므로 재진입에서도 같은 판정이다.
  if (user && user.role !== undefined && user.role !== "customer") {
    throw new HttpsError("permission-denied", "customer only");
  }

  const phase: AccountPhase | null = history ? history.phase : null;

  // ── dryRun: 쓰기 0건 ───────────────────────────────────────────────────────
  if (dryRun) {
    const inFlightOrders = await ports.countInFlightOrders(uid);
    return { dryRun: true, inFlightOrders, qoinToForfeit: qoinOf(user), canDelete: inFlightOrders === 0 };
  }

  // ── 진행 중 주문 가드 (이력 쓰기보다 먼저). 익명화 이후 재진입(phase ≥ qoinForfeited)에서는 이미 통과한 것이다 ──
  if (!phase || phase === "started") {
    const inFlight = await ports.countInFlightOrders(uid);
    if (inFlight > 0) {
      throw new HttpsError(
        "failed-precondition",
        `진행 중인 주문이 ${inFlight}건 있어요 [${INFLIGHT_TOKEN}]`,
        { reason: INFLIGHT_TOKEN, inFlightOrders: inFlight }
      );
    }
  }

  // ① 이력 (가장 먼저)
  let deletionId: string;
  if (history) {
    deletionId = history.id;
  } else {
    deletionId = `${uid}_${Date.now()}`;
    await ports.writeHistory(deletionId, {
      uid,
      provider: typeof user?.provider === "string" ? user.provider : null,
      snapshot: user,
      deletedBy: uid,
      deletedAt: FieldValue.serverTimestamp(),
      reason: args.reason ?? "",
      forfeitedQoin: qoinOf(user),
      phase: "started" as AccountPhase,
    });
  }
  let cur: AccountPhase = phase ?? "started";
  let forfeited = history?.forfeitedQoin ?? qoinOf(user);

  // ② Qoin 소멸
  if (!atLeast(cur, "qoinForfeited")) {
    forfeited = await ports.forfeitQoin(uid, deletionId);
    await ports.writeHistory(deletionId, { phase: "qoinForfeited", forfeitedQoin: forfeited });
    cur = "qoinForfeited";
  }
  // ③ users 익명화
  if (!atLeast(cur, "anonymized")) {
    await ports.anonymizeUser(uid, args.reason);
    await ports.writeHistory(deletionId, { phase: "anonymized" });
    cur = "anonymized";
  }
  // ④ favorites
  let affected = history?.affected;
  if (!atLeast(cur, "favoritesDeleted")) {
    affected = await ports.deleteFavorites(uid);
    await ports.writeHistory(deletionId, { phase: "favoritesDeleted", affected });
    cur = "favoritesDeleted";
  }
  // ⑤ Auth (마지막)
  if (!atLeast(cur, "authDeleted")) {
    await ports.deleteAuthUser(uid);
    await ports.writeHistory(deletionId, { phase: "authDeleted" });
    cur = "authDeleted";
  }
  // ⑥ 완료
  await ports.writeHistory(deletionId, { phase: "done", completedAt: FieldValue.serverTimestamp() });
  return { deletionId, phase: "done", forfeitedQoin: forfeited };
}

// ── Firestore / Auth 어댑터 ───────────────────────────────────────────────────

export function makeFirestoreAccountPorts(db: admin.firestore.Firestore): AccountPorts {
  const hist = db.collection("accountDeletionHistory");
  const userRef = (uid: string) => db.collection("users").doc(uid);
  const countOf = async (q: admin.firestore.Query) => (await q.count().get()).data().count;
  return {
    async readUser(uid) {
      const s = await userRef(uid).get();
      return s.exists ? (s.data() as RawDoc) : null;
    },
    async findIncompleteHistory(uid) {
      const snap = await hist.where("uid", "==", uid).get();
      const d = snap.docs.find((x) => x.get("phase") !== "done");
      return d ? { id: d.id, ...(d.data() as Omit<AccountHistoryDoc, "id">) } : null;
    },
    async writeHistory(deletionId, patch) {
      await hist.doc(deletionId).set(patch, { merge: true });
    },
    async countInFlightOrders(uid) {
      return countOf(db.collection("orders").where("userId", "==", uid).where("status", "in", [...IN_FLIGHT_STATUSES]));
    },
    async forfeitQoin(uid, deletionId) {
      const ref = userRef(uid);
      const txRef = ref.collection("qoinTransactions").doc(`forfeit_${deletionId}`);
      return db.runTransaction(async (t) => {
        const txSnap = await t.get(txRef);
        if (txSnap.exists) {
          const a = txSnap.get("amount");
          return typeof a === "number" ? -a : 0; // 이미 소멸됨 — 이중 처리 금지
        }
        const userSnap = await t.get(ref);
        const amount = qoinOf(userSnap.exists ? (userSnap.data() as RawDoc) : null);
        if (amount <= 0) return 0;
        t.set(txRef, {
          txId: `forfeit_${deletionId}`,
          type: "forfeit",
          reason: "accountDeletion",
          amount: -amount,
          balanceAfter: 0,
          createdAt: FieldValue.serverTimestamp(),
        });
        t.update(ref, { qoinBalance: 0 }); // 이 1필드만
        return amount;
      });
    },
    async anonymizeUser(uid, reason) {
      const patch: Record<string, unknown> = {
        displayName: ANONYMIZED_NAME,
        email: FieldValue.delete(),
        phone: FieldValue.delete(),
        photoUrl: FieldValue.delete(),
        fcmToken: FieldValue.delete(),
        fcmTokenUpdatedAt: FieldValue.delete(),
        deleted: true,
        deletedAt: FieldValue.serverTimestamp(),
      };
      if (reason) patch.deletionReason = reason;
      await userRef(uid).update(patch);
    },
    async deleteFavorites(uid) {
      const stores = userRef(uid).collection("favoriteStores");
      const items = userRef(uid).collection("favoriteMenuItems");
      const [favoriteStores, favoriteMenuItems] = await Promise.all([countOf(stores), countOf(items)]);
      await db.recursiveDelete(stores);
      await db.recursiveDelete(items);
      return { favoriteStores, favoriteMenuItems };
    },
    async deleteAuthUser(uid) {
      try {
        await admin.auth().deleteUser(uid);
      } catch (e) {
        if ((e as { code?: string }).code === "auth/user-not-found") return;
        throw e;
      }
    },
  };
}

/** 로그인 필수. 본인 uid 반환 (requireAdmin 대응). */
export function requireSelf(request: CallableRequest<unknown>): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "login required");
  return uid;
}

export const deleteMyAccount = onCall({ region: REGION, timeoutSeconds: 120 }, async (request) => {
  const uid = requireSelf(request);
  const d = (request.data ?? {}) as { reason?: unknown; dryRun?: unknown };
  const dryRun = d.dryRun === true;
  let reason: string | null = null;
  if (typeof d.reason === "string") {
    const r = d.reason.trim();
    if (r.length > 200) throw new HttpsError("invalid-argument", "reason too long");
    reason = r.length > 0 ? r : null;
  }
  const result = await runDeleteMyAccount(makeFirestoreAccountPorts(admin.firestore()), { uid, reason, dryRun });
  console.info("[deleteMyAccount]", dryRun ? "dryRun" : "run", { uid });
  return result;
});

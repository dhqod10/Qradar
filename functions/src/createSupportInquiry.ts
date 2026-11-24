/**
 * createSupportInquiry — callable (본인 uid). 고객센터 문의 **생성** (support_inquiry Q1: CF 전담).
 *
 * 입력 { inquiryId, category, title, body, imageUrls?, orderId?, appVersion?, platform? }
 * 응답 { inquiryId, created }  (같은 inquiryId 재호출은 멱등 성공 — created:false)
 *
 * 순서: ① 형식 검증  ② 멱등(이미 내 문서면 성공 반환 — rate limit 도 세지 않는다)  ③ 작성자 상태(deleted 거부, suspended 는 허용 — Q7)
 *   ④ 첨부 경로 검증  ⑤ 주문 소유 검증 + orderSnapshot 박제  ⑥ rate limit(분당 1 / 24h 5, **쓰기 직전**)  ⑦ 문서 create
 * rate limit 은 "형식 검증 이후, 쓰기 이전" 에 센다 (spec §createSupportInquiry-5). 카운터는 문서 생성과 **같은 트랜잭션**에서 커밋한다.
 *
 * 에러 토큰: [SUPPORT_RATE_LIMITED] [SUPPORT_INVALID_INPUT] [SUPPORT_INVALID_ATTACHMENT] [SUPPORT_ORDER_NOT_FOUND] [SUPPORT_ACCOUNT_DELETED]
 */
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { REGION } from "./qoinAdmin";
import { requireSelf } from "./deleteMyAccount";
import { parseStorageUrl } from "./deleteStore";

export const SUPPORT_RATE_LIMITED = "SUPPORT_RATE_LIMITED";
export const SUPPORT_INVALID_INPUT = "SUPPORT_INVALID_INPUT";
export const SUPPORT_INVALID_ATTACHMENT = "SUPPORT_INVALID_ATTACHMENT";
export const SUPPORT_ORDER_NOT_FOUND = "SUPPORT_ORDER_NOT_FOUND";
export const SUPPORT_ACCOUNT_DELETED = "SUPPORT_ACCOUNT_DELETED";

export const SUPPORT_CATEGORIES = ["order", "refund", "qoin", "account", "store", "bug", "etc"] as const;
export const MAX_TITLE = 60;
export const MAX_BODY = 2000;
export const MAX_IMAGES = 3;
/** Storage 경로 prefix — 앱 `supportInquiryImagesStoragePrefix` 와 같은 값. */
export const SUPPORT_IMAGES_PREFIX = "support_inquiries";
export const MINUTE_LIMIT = 1;
export const DAY_LIMIT = 5;
const MINUTE_MS = 60_000;
const DAY_MS = 24 * 60 * 60_000;

type RawDoc = Record<string, unknown>;

export interface CreateInput {
  inquiryId: string;
  category: string;
  title: string;
  body: string;
  imageUrls: string[];
  orderId: string | null;
  appVersion: string | null;
  platform: string | null;
}

export interface OrderSnapshot {
  storeId: string;
  storeName: string;
  pickupNumber: number | null;
  totalPrice: number;
  status: string;
  createdAt: unknown;
}

export interface CreatePorts {
  readInquiry(id: string): Promise<RawDoc | null>;
  readUser(uid: string): Promise<RawDoc | null>;
  readOrder(orderId: string): Promise<RawDoc | null>;
  /** 이 프로젝트의 기본 Storage bucket 이름 (런타임 설정). 알 수 없으면 null — 첨부가 있으면 fail-closed. */
  projectBucket(): string | null;
  /**
   * 한 트랜잭션: rate limit 카운터 판정·증가 + 문서 create. 한도 초과면 문서를 쓰지 않고 false.
   * (같은 id 가 그 사이 생겼으면 'exists' 로 멱등 처리)
   */
  commit(args: { uid: string; nowMs: number; inquiryId: string; doc: RawDoc }): Promise<"created" | "rate_limited" | "exists">;
}

function bad(msg: string): HttpsError {
  return new HttpsError("invalid-argument", `${msg} [${SUPPORT_INVALID_INPUT}]`, { reason: SUPPORT_INVALID_INPUT });
}

/** 입력 검증 (순수). 서버가 유일한 권위 — 클라 검증과 같은 상한. */
export function parseCreateInput(raw: unknown): CreateInput {
  const d = (raw ?? {}) as Record<string, unknown>;
  if (typeof d.inquiryId !== "string" || d.inquiryId.length === 0 || d.inquiryId.length > 128 || d.inquiryId.includes("/")) {
    throw bad("inquiryId invalid");
  }
  if (typeof d.category !== "string" || !(SUPPORT_CATEGORIES as readonly string[]).includes(d.category)) throw bad("category invalid");
  if (typeof d.title !== "string") throw bad("title invalid");
  const title = d.title.trim();
  if (title.length < 1 || title.length > MAX_TITLE) throw bad("title length");
  if (typeof d.body !== "string") throw bad("body invalid");
  const body = d.body.trim();
  if (body.length < 1 || body.length > MAX_BODY) throw bad("body length");
  let imageUrls: string[] = [];
  if (d.imageUrls !== undefined && d.imageUrls !== null) {
    if (!Array.isArray(d.imageUrls) || d.imageUrls.length > MAX_IMAGES) throw bad("imageUrls");
    if (!d.imageUrls.every((u) => typeof u === "string" && u.length > 0 && u.length <= 2048)) throw bad("imageUrls item");
    imageUrls = d.imageUrls as string[];
  }
  let orderId: string | null = null;
  if (d.orderId !== undefined && d.orderId !== null) {
    if (typeof d.orderId !== "string" || d.orderId.length === 0 || d.orderId.length > 128 || d.orderId.includes("/")) throw bad("orderId");
    orderId = d.orderId;
  }
  const meta = (v: unknown, max: number): string | null => (typeof v === "string" && v.length > 0 ? v.slice(0, max) : null);
  return {
    inquiryId: d.inquiryId,
    category: d.category,
    title,
    body,
    imageUrls,
    orderId,
    appVersion: meta(d.appVersion, 32),
    platform: meta(d.platform, 16),
  };
}

/**
 * 모든 첨부가 이 프로젝트 bucket 의 `support_inquiries/{uid}/{inquiryId}/` 아래인지.
 * 남의 경로·외부 URL·타 bucket URL·`..` 주입 차단 (관리자 콘솔이 첨부를 그대로 로드하므로 bucket 도 검증한다).
 */
export function attachmentsBelongTo(urls: string[], uid: string, inquiryId: string, bucket: string | null): boolean {
  if (urls.length > 0 && !bucket) return false;
  const prefix = `${SUPPORT_IMAGES_PREFIX}/${uid}/${inquiryId}/`;
  return urls.every((u) => {
    const p = parseStorageUrl(u);
    return p !== null && p.bucket === bucket && p.path.startsWith(prefix) && !p.path.includes("..");
  });
}

/** rate limit 카운터 갱신값 (순수). 초과면 null. */
export function nextLimitState(
  prev: RawDoc | null,
  nowMs: number
): { minuteWindowStartMs: number; minuteCount: number; dayWindowStartMs: number; dayCount: number } | null {
  const num = (v: unknown) => (typeof v === "number" && Number.isFinite(v) ? v : 0);
  const mStart = num(prev?.minuteWindowStartMs);
  const dStart = num(prev?.dayWindowStartMs);
  const inMin = prev !== null && nowMs - mStart < MINUTE_MS;
  const inDay = prev !== null && nowMs - dStart < DAY_MS;
  const minuteCount = (inMin ? num(prev?.minuteCount) : 0) + 1;
  const dayCount = (inDay ? num(prev?.dayCount) : 0) + 1;
  if (minuteCount > MINUTE_LIMIT || dayCount > DAY_LIMIT) return null;
  return {
    minuteWindowStartMs: inMin ? mStart : nowMs,
    minuteCount,
    dayWindowStartMs: inDay ? dStart : nowMs,
    dayCount,
  };
}

export async function runCreateSupportInquiry(
  ports: CreatePorts,
  args: { uid: string; data: unknown; nowMs: number }
): Promise<{ inquiryId: string; created: boolean }> {
  const { uid } = args;
  const input = parseCreateInput(args.data);

  // 멱등: 이미 있으면 내 것이면 성공, 남의 것이면 거부.
  const existing = await ports.readInquiry(input.inquiryId);
  if (existing) {
    if (existing.userId === uid) return { inquiryId: input.inquiryId, created: false };
    throw new HttpsError("already-exists", "inquiry exists");
  }

  const user = await ports.readUser(uid);
  if (user && user.deleted === true) {
    throw new HttpsError("permission-denied", `탈퇴한 계정이에요 [${SUPPORT_ACCOUNT_DELETED}]`, { reason: SUPPORT_ACCOUNT_DELETED });
  }

  if (!attachmentsBelongTo(input.imageUrls, uid, input.inquiryId, ports.projectBucket())) {
    throw new HttpsError("invalid-argument", `첨부 확인 필요 [${SUPPORT_INVALID_ATTACHMENT}]`, { reason: SUPPORT_INVALID_ATTACHMENT });
  }

  let orderSnapshot: OrderSnapshot | null = null;
  if (input.orderId) {
    const order = await ports.readOrder(input.orderId);
    // 존재하지 않음 / 비소유 를 같은 응답으로 (열거 오라클 방지)
    if (!order || order.userId !== uid) {
      throw new HttpsError("not-found", `주문 정보를 확인할 수 없어요 [${SUPPORT_ORDER_NOT_FOUND}]`, { reason: SUPPORT_ORDER_NOT_FOUND });
    }
    orderSnapshot = {
      storeId: typeof order.storeId === "string" ? order.storeId : "",
      storeName: typeof order.storeName === "string" ? order.storeName : "",
      pickupNumber: typeof order.pickupNumber === "number" ? order.pickupNumber : null,
      totalPrice: typeof order.totalPrice === "number" ? order.totalPrice : 0,
      status: typeof order.status === "string" ? order.status : "",
      createdAt: order.createdAt ?? null,
    };
  }

  const doc: RawDoc = {
    userId: uid,
    authorRole: typeof user?.role === "string" ? user.role : "customer",
    category: input.category,
    title: input.title,
    body: input.body,
    imageUrls: input.imageUrls,
    orderId: input.orderId,
    orderSnapshot,
    status: "open",
    answer: null,
    answerReadAt: null,
    authorDeleted: false,
    appVersion: input.appVersion,
    platform: input.platform,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
  const r = await ports.commit({ uid, nowMs: args.nowMs, inquiryId: input.inquiryId, doc });
  if (r === "rate_limited") {
    console.warn("[createSupportInquiry] rate limited", { uid });
    throw new HttpsError("resource-exhausted", `잠시 후 다시 시도해주세요 [${SUPPORT_RATE_LIMITED}]`, { reason: SUPPORT_RATE_LIMITED });
  }
  return { inquiryId: input.inquiryId, created: r === "created" };
}

export function makeFirestoreCreatePorts(db: admin.firestore.Firestore): CreatePorts {
  const get = async (col: string, id: string): Promise<RawDoc | null> => {
    const s = await db.collection(col).doc(id).get();
    return s.exists ? (s.data() as RawDoc) : null;
  };
  return {
    readInquiry: (id) => get("supportInquiries", id),
    readUser: (uid) => get("users", uid),
    readOrder: (id) => get("orders", id),
    projectBucket() {
      // 하드코딩 금지: Functions 런타임 설정(FIREBASE_CONFIG.storageBucket)의 기본 bucket. 못 얻으면 null → 첨부 거절.
      try {
        const name = admin.storage().bucket().name;
        return name && name.length > 0 ? name : null;
      } catch {
        return null;
      }
    },
    async commit({ uid, nowMs, inquiryId, doc }) {
      const limitRef = db.collection("supportInquiryLimits").doc(uid);
      const inqRef = db.collection("supportInquiries").doc(inquiryId);
      return db.runTransaction(async (t) => {
        const [limSnap, inqSnap] = await Promise.all([t.get(limitRef), t.get(inqRef)]);
        if (inqSnap.exists) return "exists" as const;
        const next = nextLimitState(limSnap.exists ? (limSnap.data() as RawDoc) : null, nowMs);
        if (!next) return "rate_limited" as const;
        t.set(limitRef, { ...next, updatedAt: FieldValue.serverTimestamp() });
        t.create(inqRef, doc);
        return "created" as const;
      });
    },
  };
}

export const createSupportInquiry = onCall({ region: REGION }, async (request) => {
  const uid = requireSelf(request);
  return runCreateSupportInquiry(makeFirestoreCreatePorts(admin.firestore()), { uid, data: request.data, nowMs: Date.now() });
});

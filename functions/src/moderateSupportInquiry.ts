/**
 * moderateSupportInquiry — callable (admin 전용). 고객센터 문의 **답변 / 종결** (support_inquiry).
 *
 * 입력 { inquiryId, action:'answer'|'close', body?, closedReason? }
 * 응답 { changed, status }
 *
 *  - answer: status=='open' 만. `answer` 맵을 **1회** 기록(append-only — 이미 있으면 절대 덮지 않는다). 같은 admin 의 재호출이 아니라
 *            이미 answered 면 [SUPPORT_ALREADY_ANSWERED], withdrawn|closed 면 [SUPPORT_NOT_OPEN].
 *  - close : open|answered → closed + closedReason 필수. 이미 closed 면 멱등 no-op 성공(changed:false).
 * 읽기-검증-쓰기는 트랜잭션 한 번으로 묶는다 (동시 답변 경합 방지).
 */
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { REGION, requireAdmin } from "./qoinAdmin";

export const SUPPORT_ALREADY_ANSWERED = "SUPPORT_ALREADY_ANSWERED";
export const SUPPORT_NOT_OPEN = "SUPPORT_NOT_OPEN";
export const SUPPORT_INVALID_INPUT_MOD = "SUPPORT_INVALID_INPUT";
export const CLOSE_REASONS = ["answered_done", "spam", "duplicate", "no_response_needed"] as const;
export const MAX_ANSWER = 2000;

type RawDoc = Record<string, unknown>;
export type ModerateAction = "answer" | "close";

export interface ModeratePorts {
  /** 트랜잭션 안에서 현재 문서를 읽고 `decide` 가 돌려준 patch 를 쓴다. 문서가 없으면 null 반환(쓰기 없음). */
  update(
    inquiryId: string,
    decide: (cur: RawDoc) => { patch: Record<string, unknown> | null; result: { changed: boolean; status: string } }
  ): Promise<{ changed: boolean; status: string } | null>;
}

function bad(msg: string): HttpsError {
  return new HttpsError("invalid-argument", `${msg} [${SUPPORT_INVALID_INPUT_MOD}]`, { reason: SUPPORT_INVALID_INPUT_MOD });
}

export async function runModerateSupportInquiry(
  ports: ModeratePorts,
  args: { adminUid: string; data: unknown }
): Promise<{ changed: boolean; status: string }> {
  const d = (args.data ?? {}) as Record<string, unknown>;
  if (typeof d.inquiryId !== "string" || d.inquiryId.length === 0 || d.inquiryId.includes("/")) throw bad("inquiryId invalid");
  if (d.action !== "answer" && d.action !== "close") throw bad("action invalid");
  const inquiryId = d.inquiryId;
  const adminUid = args.adminUid;

  let answerBody = "";
  let closedReason = "";
  if (d.action === "answer") {
    if (typeof d.body !== "string") throw bad("body required");
    answerBody = d.body.trim();
    if (answerBody.length < 1 || answerBody.length > MAX_ANSWER) throw bad("body length");
  } else {
    if (typeof d.closedReason !== "string" || !(CLOSE_REASONS as readonly string[]).includes(d.closedReason)) throw bad("closedReason invalid");
    closedReason = d.closedReason;
  }

  const out = await ports.update(inquiryId, (cur) => {
    const status = typeof cur.status === "string" ? cur.status : "";
    if (d.action === "answer") {
      if (status === "answered" || cur.answer) {
        throw new HttpsError("failed-precondition", `이미 답변이 등록된 문의예요 [${SUPPORT_ALREADY_ANSWERED}]`, { reason: SUPPORT_ALREADY_ANSWERED });
      }
      if (status !== "open") {
        throw new HttpsError("failed-precondition", `답변할 수 없는 상태예요 [${SUPPORT_NOT_OPEN}]`, { reason: SUPPORT_NOT_OPEN });
      }
      return {
        patch: {
          answer: { body: answerBody, answeredBy: adminUid, answeredAt: FieldValue.serverTimestamp() },
          status: "answered",
          updatedAt: FieldValue.serverTimestamp(),
        },
        result: { changed: true, status: "answered" },
      };
    }
    // close
    if (status === "closed") return { patch: null, result: { changed: false, status: "closed" } };
    if (status !== "open" && status !== "answered") {
      throw new HttpsError("failed-precondition", `종결할 수 없는 상태예요 [${SUPPORT_NOT_OPEN}]`, { reason: SUPPORT_NOT_OPEN });
    }
    return {
      patch: {
        status: "closed",
        closedAt: FieldValue.serverTimestamp(),
        closedBy: adminUid,
        closedReason,
        updatedAt: FieldValue.serverTimestamp(),
      },
      result: { changed: true, status: "closed" },
    };
  });
  if (!out) throw new HttpsError("not-found", "문의를 찾을 수 없습니다.");
  return out;
}

export function makeFirestoreModeratePorts(db: admin.firestore.Firestore): ModeratePorts {
  return {
    async update(inquiryId, decide) {
      const ref = db.collection("supportInquiries").doc(inquiryId);
      return db.runTransaction(async (t) => {
        const snap = await t.get(ref);
        if (!snap.exists) return null;
        const { patch, result } = decide(snap.data() as RawDoc);
        if (patch) t.update(ref, patch);
        return result;
      });
    },
  };
}

export const moderateSupportInquiry = onCall({ region: REGION }, async (request) => {
  const db = admin.firestore();
  const adminUid = await requireAdmin(db, request);
  return runModerateSupportInquiry(makeFirestoreModeratePorts(db), { adminUid, data: request.data });
});

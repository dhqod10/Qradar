/**
 * verifyTossPayment — Cloud Function (onCall, asia-northeast3)
 *
 * 흐름:
 *   1. 인증 확인 (auth null → unauthenticated)
 *   2. 입력값 검증
 *   2-b. 결제 게이트 (G1 매장 판매 가능 + G2 메뉴 품절·판매중단) — Toss confirm **전**. 거절하면 돈이 움직이지 않는다
 *        (payment_server_authority, `paymentGate.ts`). 멱등 가드 직후 ~ confirm 직전이 유일한 "confirm 전 서버 지점"이다.
 *   2-c. 금액 게이트 — 카트 금액을 Firestore 문서에서 다시 계산해 대조 (payment_price_authority, `priceGate.ts`). 2-b 가 읽은
 *        메뉴를 재사용한다 (추가 읽기 0, 옵션 그룹만 +1 round-trip).
 *   2-d. Qoin 사용 (qoin_spend) — `qoinToUse > 0` 일 때만. 금액 게이트가 **가격 모드와 무관하게** 서버 소계를 다시 만들고(enforce 강제),
 *        그 소계로 사용 한도를 판정해 **Toss confirm 전에** 잔액을 트랜잭션으로 차감한다 (`qoinSpendLedger.reserveSpend`).
 *        confirm 이후 어떤 단계가 실패해도 반전 원장으로 되돌린다 (catch 블록). `qoinToUse` 가 0/미전송이면 이 경로 전체가 없다 — 현행과 동일.
 *   3. Toss Server API POST /v1/payments/confirm 호출
 *   4. 응답 검증 (status === 'DONE' && totalAmount === amount && orderId 일치)
 *   5. 검증 실패 → Toss cancel + error throw
 *   6. 검증 성공 → Firestore batch:
 *      - orders/{orderId} set
 *      - users/{uid}/orderLogs/{logId} set
 *   7. 반환 { orderId, status: 'paid' }
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret, defineString } from "firebase-functions/params";
import { v4 as uuidv4 } from "uuid";
import { confirmPayment, cancelPayment } from "./tossClient";
import { applyServerPricing, buildOrderData, buildOrderLogData, CartSnapshot } from "./orderBuilder";
import { buildRejectionMessage, evaluatePaymentGate, GATE_HTTPS_CODE, GateReader, MAX_CART_ITEMS, resolveGateMode } from "./paymentGate";
import { evaluatePriceAuthority, resolveMenusForPricing, resolvePriceMode, storeUnreadableResult } from "./priceGate";
import { MergedMenu } from "./menuVisibility";
import { makeFirestoreGateReader, recordGateRejection } from "./paymentGateReader";
import { findSelfDealing, validBrandId } from "./selfDealing";
import { writeOrderSignal } from "./orderSignals";
import { parseQoinToUse, resolveSpendPolicy, SPEND_REJECT_TOKEN, SpendPolicy } from "./qoinSpend";
import { recordSpendIssue, reserveSpend, rollbackSpend, SpendConflictError, SpendRejectedError } from "./qoinSpendLedger";

const tossSecretKey = defineSecret("TOSS_SECRET_KEY");
/** Layer2 신호 해시 salt (prelaunch_security_bundle). 값은 `firebase functions:secrets:set SIGNAL_HASH_SALT` 로 주입 — 코드엔 선언만. */
const signalHashSalt = defineSecret("SIGNAL_HASH_SALT");

/**
 * 결제 게이트 모드 (payment_server_authority spec §17.0): off | shadow | enforce.
 * 값은 **배포 시점에** functions params 로 해석된다 — `functions/.env.<projectId>` (또는 `functions/.env`) 의
 * `PAYMENT_GATE_MODE=...` 한 줄. 값을 바꾸면 재배포해야 반영된다 (docs/tasks/payment_server_authority/implementation.md §8).
 * default 를 둬서 값이 없어도 배포가 대화형 프롬프트로 멈추지 않는다. 없거나 모르는 값은 `resolveGateMode` 가 `off` 로 떨어뜨린다.
 */
const paymentGateMode = defineString("PAYMENT_GATE_MODE", { default: "off" });

/**
 * 결제 금액 게이트 모드 (payment_price_authority spec §8, Q3): off | shadow | enforce. **`PAYMENT_GATE_MODE` 와 독립**이다.
 * 읽는 방식·폴백은 위와 같다 (`resolvePriceMode` = `resolveGateMode`). 운영 방법은 docs/operations.md §6 이 단일 진실원이다.
 */
const paymentPriceMode = defineString("PAYMENT_PRICE_MODE", { default: "off" });

// ── 입력 타입 ─────────────────────────────────────────────────────────────────
// OrderItem / CartSnapshot 은 orderBuilder.ts (주문 문서 구성의 단일 출처, T1).

interface VerifyPaymentInput {
  paymentKey: string;
  orderId: string;
  amount: number;
  idempotencyKey: string;
  cart: CartSnapshot;
  paymentMethod: string;
  /** 앱이 싣는 결제 클라이언트 수준 (lib/core/constants/app_client_level.dart). 구버전은 이 키가 없다. 거절 기록에만 쓴다 — 권위가 아니다. */
  clientLevel?: unknown;
  /**
   * Qoin 사용 요청액 (qoin_spend, 1 Qoin = 1원). **요청일 뿐 권위가 아니다** — 서버가 잔액·정책·서버 재계산 소계로 검증한다.
   * 미전송(구버전 앱)/null = 0 = 기존 결제 흐름. 안전 정수·0 이상이 아니면 invalid-argument.
   */
  qoinToUse?: unknown;
  /** Layer2 신호용 설치 식별자(Firebase Installations ID). 구버전은 없다. 판정에 쓰지 않는다 — 해시해 orderSignals 에만 저장. */
  deviceId?: unknown;
}

// ── 함수 ─────────────────────────────────────────────────────────────────────

/** 외부 의존 주입 — 거절 경로에서 Toss 를 호출하지 않음을 단위 테스트로 단언하기 위한 이음새 (R5). */
export interface VerifyDeps {
  db: admin.firestore.Firestore;
  secretKey: () => string;
  confirm: typeof confirmPayment;
  cancel: typeof cancelPayment;
  /** 테스트에서 Firestore 대신 주입. 기본은 db 기반 어댑터. */
  gateReader?: GateReader;
  /**
   * 게이트 모드 원시 값을 돌려주는 thunk (spec §17.0). **thunk 인 이유**: 요청마다 읽고, `off` 일 때는 게이트 코드를 아예 타지 않는다.
   * 생략하면 `off` — "설정이 없으면 평가하지 않는다" 와 같은 방향이다.
   */
  gateMode?: () => unknown;
  /** 금액 게이트 모드 원시 값 thunk (payment_price_authority §8). 생략하면 `off` — 옵션 그룹을 읽지 않는다. */
  priceMode?: () => unknown;
  /** Layer2 해시 salt thunk. 없거나 비어 있으면 신호 저장을 생략한다 (주문은 정상). */
  signalSalt?: () => string | undefined;
}

export const verifyTossPayment = onCall(
  {
    region: "asia-northeast3",
    secrets: [tossSecretKey, signalHashSalt],
  },
  (request) =>
    handleVerifyTossPayment(
      {
        db: admin.firestore(),
        secretKey: () => tossSecretKey.value(),
        confirm: confirmPayment,
        cancel: cancelPayment,
        gateMode: () => paymentGateMode.value(),
        priceMode: () => paymentPriceMode.value(),
        signalSalt: () => signalHashSalt.value(),
      },
      request
    )
);

export async function handleVerifyTossPayment(
  deps: VerifyDeps,
  request: { auth?: { uid: string } | null; data: unknown; rawRequest?: { ip?: unknown } | null }
) {
    console.log("[verifyTossPayment] START");
    // Qoin 예약(차감)이 성공했고 아직 주문 커밋 전이면 값이 있다 — 이후 실패 시 catch 가 반전 원장으로 되돌린다 (qoin_spend).
    let reservation: { uid: string; orderId: string; storeId: string; storeName: string; tossConfirmed: boolean; paymentKey: string } | null = null;
    const db = deps.db;
    try {
    // 1. 인증 확인
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }
    const uid = request.auth.uid;
    const data = request.data as VerifyPaymentInput;
    console.log("[verifyTossPayment] input:", JSON.stringify({
      uid,
      paymentKey: data.paymentKey?.substring(0, 20),
      orderId: data.orderId,
      amount: data.amount,
      qoinToUse: data.qoinToUse,
      idempotencyKey: data.idempotencyKey,
      paymentMethod: data.paymentMethod,
      cartKeys: data.cart ? Object.keys(data.cart) : null,
    }));

    // 2. 입력값 검증
    if (
      !data.paymentKey ||
      !data.orderId ||
      !data.amount ||
      !data.idempotencyKey ||
      !data.cart ||
      !data.paymentMethod
    ) {
      throw new HttpsError(
        "invalid-argument",
        "필수 입력값이 누락되었습니다. (paymentKey, orderId, amount, idempotencyKey, cart, paymentMethod)"
      );
    }
    // 품목 수 상한 (spec §15.1) — 토큰 절단을 구조적으로 막고 G2 읽기 비용(품목당 최대 3문서)의 뚜껑이 된다. 토큰 없음 → 앱은 갈래 C.
    if (!Array.isArray(data.cart.items) || data.cart.items.length > MAX_CART_ITEMS) {
      throw new HttpsError("invalid-argument", "cart.items 가 올바르지 않습니다.");
    }
    if (data.amount !== data.cart.totalPrice) {
      throw new HttpsError(
        "invalid-argument",
        `amount(${data.amount})와 cart.totalPrice(${data.cart.totalPrice})가 일치하지 않습니다.`
      );
    }

    // Qoin 사용 요청 파싱 (미전송 = 0, 구버전 앱). 음수·소수·비수는 금액을 깎는 입력이므로 거절한다.
    const qoinToUse = parseQoinToUse(data.qoinToUse);
    if (qoinToUse === null) {
      throw new HttpsError("invalid-argument", "qoinToUse 가 올바르지 않습니다.");
    }

    // 3-pre. 멱등성 가드: Toss confirm 호출 전에 동일 idempotencyKey 문서 존재 확인
    //   - 정상 처리된 주문(status='paid' 이상) → already-exists 에러 + 기존 orderId 반환
    //   - 비정상 상태(status 누락 / 알 수 없는 값) → internal 에러
    //   - 존재하지 않으면 기존 흐름 진행
    const idempotencyDocRef = db.collection("orders").doc(data.idempotencyKey);
    const idempotencyDocSnap = await idempotencyDocRef.get();
    if (idempotencyDocSnap.exists) {
      const existingData = idempotencyDocSnap.data();
      const existingStatus = existingData?.status as string | undefined;
      const terminalStatuses = ["paid", "accepted", "making", "ready", "completed", "cancelled", "refunded"];
      if (existingStatus && terminalStatuses.includes(existingStatus)) {
        console.log(
          "[verifyTossPayment] idempotency hit — already processed. orderId:",
          data.idempotencyKey,
          "status:",
          existingStatus
        );
        // 정상 처리된 주문: 동일 결과 반환 (새 doc 생성 없음)
        return { orderId: data.idempotencyKey, status: existingStatus };
      }
      // 비정상 상태 문서가 존재하는 경우 — 중복 write 금지
      console.error(
        "[verifyTossPayment] idempotency conflict — unexpected status:",
        existingStatus,
        "orderId:",
        data.idempotencyKey
      );
      throw new HttpsError(
        "internal",
        "동일 주문 키로 처리 중인 요청이 있습니다. 잠시 후 다시 시도해주세요."
      );
    }

    // 2-a. 자기거래 가드 (prelaunch_security_bundle Layer1-A) — Toss confirm 전. 거절하면 돈이 움직이지 않는다.
    //   잠정(사용자 검토 대기) D-1: 모드 스위치 없이 **상시 enforce** — ownerId 동일성 비교라 정상 손님 오탐이 구조적으로 없다.
    //   신뢰원은 stores/{id}.ownerId/.brandId 뿐 (cart 값 미사용). 매장 문서가 없으면 건너뛴다 (STORE_NOT_FOUND 는 2-b 의 몫 — 기존 동작 유지).
    //   store 는 Layer2 신호(storeOwnerId/storeBrandId 박제)에도 쓴다.
    let signalStore: { ownerId: string | null; brandId: string | null } | null = null;
    if (typeof data.cart.storeId === "string" && data.cart.storeId.length > 0) {
      let storeData: Record<string, unknown> | undefined;
      let matchedBy: "owner" | "brandHolder" | null;
      try {
        const storeSnap = await db.collection("stores").doc(data.cart.storeId).get();
        storeData = storeSnap.exists ? (storeSnap.data() as Record<string, unknown>) : undefined;
        matchedBy = storeData ? await findSelfDealing(db, uid, storeData) : null;
      } catch (e) {
        // 판정을 못 하면 통과시키지 않는다 (confirm 전이라 돈은 안 움직인다) — 일시 장애는 재시도 가능한 unavailable.
        console.error("[verifyTossPayment] self-dealing check read failed", e);
        throw new HttpsError("unavailable", buildRejectionMessage("READ_FAILED"));
      }
      if (storeData) {
        signalStore = {
          ownerId: typeof storeData.ownerId === "string" ? storeData.ownerId : null,
          brandId: validBrandId(storeData.brandId),
        };
      }
      if (matchedBy !== null) {
        await recordGateRejection(db, {
          uid,
          storeId: data.cart.storeId,
          reason: "SELF_DEALING",
          detail: { storeOwnerId: signalStore?.ownerId ?? null, matchedBy },
          amount: data.amount,
        });
        console.warn("[verifyTossPayment] SELF_DEALING REJECT", matchedBy);
        throw new HttpsError(GATE_HTTPS_CODE.SELF_DEALING, buildRejectionMessage("SELF_DEALING"), { reason: "SELF_DEALING" });
      }
    }

    // 2-b. 결제 게이트 (G1 + G2) — Toss confirm 전. 거절하면 confirm 을 호출하지 않는다 (R5).
    //   판정은 canSellNow / classifyCartMenu 두 함수뿐이다 (paymentGate.ts). 클라이언트가 선언한 scope/brandId 를 쓰지 않는다.
    //   모드 (spec §17.0): off = 평가·읽기 모두 하지 않는다(비용 0) / shadow = 판정·기록만, 거절 없음 / enforce = 판정·기록·거절.
    //   값이 없거나 모르면 off — 설정 오타로 매출이 멈추는 것보다 구멍이 하루 더 열려 있는 편이 낫다.
    const gateMode = resolveGateMode(deps.gateMode?.());
    const reader = deps.gateReader ?? makeFirestoreGateReader(db);
    // 2-b 가 읽어 해석한 메뉴 — 2-c 가 재사용한다 (추가 읽기 0). 게이트가 꺼졌거나 위반으로 끝났으면 null.
    let gateMenus: { menus: Map<string, MergedMenu>; storeBrandId: string | null } | null = null;
    if (gateMode !== "off") {
      const shadow = gateMode === "shadow";
      try {
        const gate = await evaluatePaymentGate(reader, data.cart);
        if (gate.ok) {
          gateMenus = {
            menus: new Map(gate.resolved.map((r) => [r.menuItemId, r.merged])),
            storeBrandId: gate.storeBrandId,
          };
        }
        if (!gate.ok) {
          await recordGateRejection(db, {
            uid,
            storeId: String(data.cart.storeId ?? ""),
            reason: gate.reason,
            detail: gate.detail,
            amount: data.amount,
            shadow,
          });
          console.warn(
            `[verifyTossPayment] GATE ${shadow ? "SHADOW (not rejected)" : "REJECT"}`,
            gate.reason,
            JSON.stringify(gate.detail)
          );
          if (!shadow) {
            throw new HttpsError(GATE_HTTPS_CODE[gate.reason], buildRejectionMessage(gate.reason, gate.menuItemIds), {
              reason: gate.reason,
              menuItemIds: gate.menuItemIds,
            });
          }
        }
      } catch (e) {
        // shadow 는 관측용이다 — 게이트 코드의 예상 밖 예외가 결제를 막아서는 안 된다. enforce 의 거절(HttpsError)은 그대로 던진다.
        if (!shadow || e instanceof HttpsError) throw e;
        console.error("[verifyTossPayment] shadow gate error (결제는 계속 진행)", e);
      }
    }

    // 2-d(전반). Qoin 사용 정책 — `qoinToUse > 0` 일 때만 읽는다 (0 이면 추가 read 0, 현행과 동일).
    //   정책이 꺼져 있으면(spendEnabled 부재 = 꺼짐, fail-closed) 금액 게이트까지 가지 않고 여기서 거절한다. confirm 전이라 돈은 안 움직인다.
    let spendPolicy: SpendPolicy | null = null;
    if (qoinToUse > 0) {
      try {
        const cfgSnap = await db.collection("config").doc("qoin").get();
        spendPolicy = resolveSpendPolicy(cfgSnap.exists ? (cfgSnap.data() as Record<string, unknown>) : undefined);
      } catch (e) {
        console.error("[verifyTossPayment] qoin policy read failed", e);
        throw new HttpsError("unavailable", buildRejectionMessage("READ_FAILED"));
      }
      if (!spendPolicy.spendEnabled) {
        await rejectSpend(db, uid, data, "DISABLED", { because: spendPolicy.disabledBecause, requested: qoinToUse });
      }
    }

    // 2-c. 금액 게이트 (payment_price_authority). 모드 off 면 메뉴도 옵션 그룹도 읽지 않는다 (비용 0).
    //   shadow = 판정·기록만 (주문 문서는 클라 값 그대로) / enforce = 판정·기록·거절 + 주문 문서의 금액 필드를 서버 값으로 쓴다.
    //   PAYMENT_GATE_MODE=off + 가격 모드 != off 조합: 2-b 가 메뉴를 읽지 않았으므로 여기서 직접 읽는다 — 조용히 통과시키지 않는다.
    let serverPricing: { lines: Array<{ unitPrice: number; lineTotal: number }>; subtotal: number; expected: number } | null = null;
    // Qoin 사용 주문은 가격 모드와 무관하게 enforce — 할인의 정당성은 서버가 다시 만든 소계에 의존한다 (qoin_spend spec §5.3).
    //   클라 소계를 믿으면 '소계 뻥튀기 → Qoin 으로 거의 전액 차감' 이 가능하다. 비-Qoin 주문은 기존대로 `PAYMENT_PRICE_MODE` 가 지배한다.
    const priceMode = qoinToUse > 0 ? "enforce" : resolvePriceMode(deps.priceMode?.());
    if (priceMode !== "off") {
      const shadow = priceMode === "shadow";
      try {
        const menus =
          gateMenus ?? (await resolveMenusForPricing(reader, { storeId: data.cart.storeId, items: data.cart.items }));
        const result =
          menus === null
            ? storeUnreadableResult(data.amount)
            : await evaluatePriceAuthority(reader, {
                storeId: data.cart.storeId,
                storeBrandId: menus.storeBrandId,
                menus: menus.menus,
                amount: data.amount,
                cart: data.cart,
                // 0 이면 키 자체를 넘기지 않는다 — 비-Qoin 호출은 현행과 동일한 인자 모양이다.
                ...(qoinToUse > 0 ? { discount: qoinToUse } : {}),
              });
        if (!result.ok) {
          await recordGateRejection(db, {
            uid,
            storeId: String(data.cart.storeId ?? ""),
            reason: result.reason,
            // clientLevel: null = 구버전(재가격 없음). ⑤-b 관측에서 구버전 비율을 재는 수단 (H-01). 판정에는 쓰지 않는다.
            detail: { ...result.detail, clientLevel: Number.isInteger(data.clientLevel) ? data.clientLevel : null },
            amount: data.amount,
            shadow,
          });
          console.warn(
            `[verifyTossPayment] PRICE ${shadow ? "SHADOW (not rejected)" : "REJECT"}`,
            result.reason,
            JSON.stringify(result.detail)
          );
          if (!shadow) {
            throw new HttpsError(GATE_HTTPS_CODE[result.reason], buildRejectionMessage(result.reason, result.menuItemIds), {
              reason: result.reason,
              menuItemIds: result.menuItemIds,
            });
          }
        } else if (!shadow) {
          serverPricing = result.pricing;
        }
      } catch (e) {
        // shadow 는 관측용이다 — 예상 밖 예외가 결제를 막아서는 안 된다. enforce 의 거절(HttpsError)은 그대로 던진다.
        if (!shadow || e instanceof HttpsError) throw e;
        console.error("[verifyTossPayment] shadow price gate error (결제는 계속 진행)", e);
      }
    }

    // 2-d(후반). Qoin 예약(차감) — Toss confirm **전**. 한 트랜잭션: 선존재 가드 → 잔액 read → 판정 → 원장 + 잔액.
    //   소계는 위 금액 게이트가 문서에서 다시 만든 값이다 (클라 값 아님). 실패하면 돈도 Qoin 도 안 움직인다.
    if (qoinToUse > 0) {
      if (serverPricing === null || spendPolicy === null) {
        // 도달 불가 방어: Q>0 은 enforce 로 강제돼 통과했다면 pricing 이 있다. 근거 없는 할인은 통과시키지 않는다.
        throw new HttpsError("internal", "Qoin 사용 검증에 필요한 금액을 계산하지 못했습니다.");
      }
      const serverSubtotal = serverPricing.subtotal;
      const serverFinal = serverPricing.expected; // = serverSubtotal − qoinToUse (priceGate 가 D 를 반영)
      if (data.amount !== serverFinal) {
        // 게이트 c4' 가 이미 보장한다 — 벨트와 멜빵. 어긋나면 PRICE_MISMATCH 와 같은 취급.
        await recordGateRejection(db, {
          uid,
          storeId: String(data.cart.storeId ?? ""),
          reason: "PRICE_MISMATCH",
          detail: { clientAmount: data.amount, serverExpected: serverFinal, qoinToUse, via: "qoinSpend" },
          amount: data.amount,
        });
        throw new HttpsError(GATE_HTTPS_CODE.PRICE_MISMATCH, buildRejectionMessage("PRICE_MISMATCH"), { reason: "PRICE_MISMATCH", menuItemIds: [] });
      }
      try {
        await reserveSpend(db, {
          uid,
          orderId: data.idempotencyKey,
          requested: qoinToUse,
          policy: spendPolicy,
          serverSubtotal,
          serverFinal,
          storeId: String(data.cart.storeId ?? ""),
          storeName: String(data.cart.storeName ?? ""),
          brandId: signalStore?.brandId ?? null,
        });
      } catch (e) {
        if (e instanceof SpendRejectedError) {
          await rejectSpend(db, uid, data, e.reason, e.detail);
        }
        if (e instanceof SpendConflictError) {
          // 같은 주문 키의 예약이 이미 있다 — 처리 중이거나 이전 시도의 잔재. 차감도 롤백도 하지 않는다 (남의 예약을 건드리지 않는다).
          throw new HttpsError("aborted", "동일 주문 키로 처리 중인 요청이 있습니다. 잠시 후 다시 시도해주세요.");
        }
        console.error("[verifyTossPayment] qoin reserve failed", e);
        throw new HttpsError("unavailable", buildRejectionMessage("READ_FAILED"));
      }
      reservation = {
        uid,
        orderId: data.idempotencyKey,
        storeId: String(data.cart.storeId ?? ""),
        storeName: String(data.cart.storeName ?? ""),
        tossConfirmed: false,
        paymentKey: data.paymentKey,
      };
    }

    // 3. Toss Server API confirm 호출 (또는 Mock 분기 — docs 공개 키 사용 시)
    const secretKey = deps.secretKey();
    const isMockMode = secretKey.startsWith("test_gsk_docs_");
    const tossResponse = isMockMode
      ? {
          paymentKey: data.paymentKey,
          orderId: data.idempotencyKey,
          status: "DONE",
          totalAmount: data.amount,
          approvedAt: new Date().toISOString(),
          method: data.paymentMethod,
        }
      : await deps.confirm(secretKey, {
          paymentKey: data.paymentKey,
          orderId: data.orderId,
          amount: data.amount,
        });
    if (isMockMode) {
      console.log("[verifyTossPayment] MOCK MODE — Toss confirm SKIP");
    }

    // 4. 응답 검증
    const isStatusDone = tossResponse.status === "DONE";
    const isAmountMatch = tossResponse.totalAmount === data.amount;
    const isOrderIdMatch = tossResponse.orderId === data.idempotencyKey;

    if (!isStatusDone || !isAmountMatch || !isOrderIdMatch) {
      // 5. 검증 실패 → Toss cancel 시도 후 에러 throw
      if (!isMockMode) {
        try {
          await deps.cancel(secretKey, {
            paymentKey: data.paymentKey,
            cancelReason: "서버 측 검증 실패로 인한 자동 취소",
          });
        } catch (cancelErr) {
          // cancel 실패는 로그만 기록, 원본 에러를 throw
          console.error("verifyTossPayment: cancel 실패", cancelErr);
        }
      }
      throw new HttpsError(
        "invalid-argument",
        `결제 검증 실패. status=${tossResponse.status}, ` +
          `amount=${tossResponse.totalAmount}(expected ${data.amount}), ` +
          `orderId=${tossResponse.orderId}(expected ${data.idempotencyKey})`
      );
    }

    if (reservation) reservation.tossConfirmed = true; // 이 시점부터 돈이 승인된 상태 — 이후 실패는 Toss cancel 도 필요하다

    // 6. Firestore batch write
    const now = admin.firestore.FieldValue.serverTimestamp();
    const logId = uuidv4();
    const orderId = data.idempotencyKey;

    // approvedAt 파싱 (Toss ISO 8601 문자열 → Timestamp)
    const approvedAt = admin.firestore.Timestamp.fromDate(
      new Date(tossResponse.approvedAt)
    );

    // paymentMethod 정규화 (easyPay 제공자 기반)
    const resolvedPaymentMethod = normalizePaymentMethod(
      data.paymentMethod,
      tossResponse.easyPay?.provider
    );

    // paymentInfo 맵 구성
    const paymentInfo: Record<string, unknown> = {
      method: resolvedPaymentMethod,
      channel: "toss",
      paymentKey: tossResponse.paymentKey,
      transactionId: tossResponse.transactionKey ?? null,
      receiptUrl: tossResponse.receipt?.url ?? null,
      approvedAt,
      amount: tossResponse.totalAmount,
      cardCompany: tossResponse.card?.company ?? null,
      cardNumberMasked: maskCardNumber(tossResponse.card?.number),
      easyPayProvider: tossResponse.easyPay?.provider ?? null,
    };

    // orders/{orderId} 문서 (멱등성 가드 통과 후 신규 write)
    const orderDoc = idempotencyDocRef; // 이미 step 3-pre 에서 참조 확보
    // R8: enforce 에서는 금액 필드를 서버가 문서에서 다시 만든 값으로 쓴다. shadow / off 는 클라 값 그대로 (관측만).
    //   Qoin 사용 주문은 검증된 사용액이 `discount`, 서버 최종청구액이 `totalPrice` 로 쓰인다 (적립은 이 totalPrice = 현금 결제액 기준, D-4).
    const cartForOrder =
      serverPricing === null ? data.cart : applyServerPricing(data.cart, serverPricing, qoinToUse > 0 ? qoinToUse : 0);
    const orderData = buildOrderData(cartForOrder, uid, paymentInfo, { approvedAt, now });

    // users/{uid}/orderLogs/{logId} 문서 (Phase 2 OrderLogEntity 스키마 준수)
    const logDoc = db
      .collection("users")
      .doc(uid)
      .collection("orderLogs")
      .doc(logId);
    const logData = buildOrderLogData(
      cartForOrder,
      { logId, orderId, paymentMethod: resolvedPaymentMethod, ...(qoinToUse > 0 ? { discount: qoinToUse } : {}) },
      { approvedAt, now }
    );

    const batch = db.batch();
    batch.set(orderDoc, orderData);
    batch.set(logDoc, logData);
    await batch.commit();
    reservation = null; // 주문이 커밋됐다 — Qoin 차감은 확정. 이후의 어떤 예외도 롤백하지 않는다.

    // Layer2 신호 (best-effort, D-6) — 주문 커밋 **후** 별도 write. 실패해도 주문 성공을 뒤집지 않는다 (writeOrderSignal 이 삼킨다).
    await writeOrderSignal(db, deps.signalSalt?.(), {
      orderId,
      userId: uid,
      storeId: String(data.cart.storeId ?? ""),
      storeOwnerId: signalStore?.ownerId ?? null,
      storeBrandId: signalStore?.brandId ?? null,
      deviceId: data.deviceId,
      card: tossResponse.card,
      ip: request.rawRequest?.ip,
    });

    // 7. 반환
    console.log("[verifyTossPayment] SUCCESS orderId:", orderId);
    return { orderId, status: "paid" };
    } catch (err) {
      console.error("[verifyTossPayment] FATAL:", err);
      if (err instanceof Error) {
        console.error("[verifyTossPayment] stack:", err.stack);
      }
      if (reservation) await undoQoinReservation(deps, reservation);
      throw err;
    }
}

// ── 헬퍼 ─────────────────────────────────────────────────────────────────────

/** Qoin 사용 거절: `paymentGateRejections` 에 기록하고 throw (Toss confirm 전 — 돈 안 움직임). 항상 throw 한다. */
async function rejectSpend(
  db: admin.firestore.Firestore,
  uid: string,
  data: VerifyPaymentInput,
  reason: keyof typeof SPEND_REJECT_TOKEN,
  detail: Record<string, unknown>
): Promise<never> {
  const token = SPEND_REJECT_TOKEN[reason];
  await recordGateRejection(db, {
    uid,
    storeId: String(data.cart.storeId ?? ""),
    reason: token,
    detail,
    amount: data.amount,
  });
  console.warn("[verifyTossPayment] QOIN REJECT", token, JSON.stringify(detail));
  throw new HttpsError(GATE_HTTPS_CODE[token], buildRejectionMessage(token), { reason: token });
}

/**
 * 예약된 Qoin 차감을 되돌린다 (주문 커밋 전 실패). Toss 가 이미 승인했으면 먼저 취소를 시도한다 — 둘 다 best-effort 이며
 * 서로를 막지 않는다. 롤백 자체가 실패하면 `qoinSettlementIssues` 에 남긴다 (고객 돈 — 로그에만 두지 않는다).
 */
async function undoQoinReservation(
  deps: VerifyDeps,
  r: { uid: string; orderId: string; storeId: string; storeName: string; tossConfirmed: boolean; paymentKey: string }
): Promise<void> {
  if (r.tossConfirmed) {
    try {
      const secretKey = deps.secretKey();
      if (!secretKey.startsWith("test_gsk_docs_")) {
        await deps.cancel(secretKey, { paymentKey: r.paymentKey, cancelReason: "주문 저장 실패로 인한 자동 취소" });
      }
    } catch (cancelErr) {
      console.error("[verifyTossPayment] 주문 저장 실패 후 Toss cancel 실패", r.orderId, cancelErr);
    }
  }
  try {
    const outcome = await rollbackSpend(deps.db, {
      uid: r.uid,
      orderId: r.orderId,
      reason: r.tossConfirmed ? "order_write_failed" : "payment_confirm_failed",
      storeId: r.storeId,
      storeName: r.storeName,
    });
    console.info("[verifyTossPayment] qoin rollback", outcome, r.orderId);
  } catch (rollbackErr) {
    console.error("[verifyTossPayment] qoin rollback FAILED", r.orderId, rollbackErr);
    await recordSpendIssue(deps.db, {
      orderId: r.orderId,
      userId: r.uid,
      storeId: r.storeId,
      reason: "spend_rollback_failed",
      values: { tossConfirmed: r.tossConfirmed },
    });
  }
}

/** Toss easyPay provider 기반으로 paymentMethod 정규화. */
function normalizePaymentMethod(
  requestedMethod: string,
  easyPayProvider?: string
): string {
  if (easyPayProvider) {
    const provider = easyPayProvider.toUpperCase();
    if (provider === "KAKAOPAY") return "kakaoPay";
    if (provider === "NAVERPAY") return "naverPay";
    if (provider === "TOSSPAY") return "tossPay";
    if (provider === "SAMSUNGPAY") return "samsungPay";
    if (provider === "APPLEPAY") return "applePay";
    if (provider === "PAYCO") return "payco";
  }
  // 카드 / 계좌이체 등
  return requestedMethod;
}

/** 카드 번호 마스킹. "1234567812345678" → "1234-****-****-5678". */
function maskCardNumber(number?: string): string | null {
  if (!number) return null;
  const digits = number.replace(/\D/g, "");
  if (digits.length < 8) return null;
  const first4 = digits.slice(0, 4);
  const last4 = digits.slice(-4);
  return `${first4}-****-****-${last4}`;
}

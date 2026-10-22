/**
 * migrateQoinZeroRates — **임시** callable (admin 전용). 운영에 남은 `qoinAccrualRate: 0` 을
 * `qoinAccrualEnabled: false` (적립 사용 안 함) 로 이전한다. (spec §20.4)
 *
 * TRANSITIONAL(spec §20.4.5): 마이그레이션 0건 확인 후 정리 커밋에서 이 파일과 `index.ts` export 를 삭제한다.
 *
 * 요청: { dryRun: boolean }
 * 응답: { dryRun, zeroStores:[{id,name}], zeroBrands:[...], invalidStores:[{id,name,raw}], invalidBrands:[...],
 *         migrated: number, skipped: number }
 *   - dryRun true  → 쓰기 0. 대상 목록·건수만.
 *   - dryRun false → 대상 1건당 한 트랜잭션: `qoinAccrualRate` 삭제 + `qoinAccrualEnabled: false` + 이력 1건
 *     (field 'accrualEnabled', source 'migration', changedBy = 실행 admin uid, migratedFromRate: 0).
 *     트랜잭션 안에서 문서를 다시 읽어 여전히 `qoinAccrualRate === 0` 일 때만 쓴다 (아니면 skipped).
 *     이미 이전된 문서는 `qoinAccrualRate` 가 없으므로 스캔에 잡히지 않는다 → 이력도 쓰지 않는다 (멱등).
 *   - 무효 값(비number / 범위 밖)은 **보고만** 한다. 의도를 추측할 수 없으므로 자동 변환 금지 (fail-closed).
 *
 * 스캔: `orderBy('qoinAccrualRate')` 는 그 필드가 있는 문서만 돌려준다 (단일 필드 자동 인덱스) — 전 매장을 읽지 않는다.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { classifyRate } from "./qoinRate";
import { describeRaw, historyCollection, REGION, requireAdmin, switchBeforeInfo } from "./qoinAdmin";

const LOG = "[migrateQoinZeroRates]";
const PAGE = 400;
const REASON = "적립률 0% → 적립 사용 안 함 이전 (Q1)";

type Kind = "store" | "brand";
interface Target {
  id: string;
  name: string;
}
interface InvalidTarget extends Target {
  raw: string;
}

async function scan(db: admin.firestore.Firestore, kind: Kind) {
  const zero: Target[] = [];
  const invalid: InvalidTarget[] = [];
  let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
  for (;;) {
    let q = db
      .collection(kind === "store" ? "stores" : "brands")
      .orderBy("qoinAccrualRate")
      .select("name", "qoinAccrualRate")
      .limit(PAGE);
    if (cursor) q = q.startAfter(cursor);
    const page = await q.get();
    if (page.empty) break;
    for (const d of page.docs) {
      const raw = d.get("qoinAccrualRate");
      const name = (d.get("name") as string | undefined) ?? "";
      const cell = classifyRate(raw);
      if (cell.kind === "legacyZero") zero.push({ id: d.id, name });
      else if (cell.kind === "invalid") invalid.push({ id: d.id, name, raw: describeRaw(raw) });
    }
    cursor = page.docs[page.docs.length - 1];
    if (page.size < PAGE) break;
  }
  return { zero, invalid };
}

/** 대상 1건: 트랜잭션 1개 = 문서 1개 + 이력 1개. 반환 true = 이전함, false = skip. */
async function migrateOne(db: admin.firestore.Firestore, kind: Kind, target: Target, uid: string): Promise<boolean> {
  const ref = db.collection(kind === "store" ? "stores" : "brands").doc(target.id);
  const historyRef = historyCollection(db, kind, target.id).doc();
  return db.runTransaction(async (t) => {
    const snap = await t.get(ref);
    if (!snap.exists || snap.get("qoinAccrualRate") !== 0) return false;
    const info = switchBeforeInfo(snap.get("qoinAccrualEnabled"));
    t.update(ref, { qoinAccrualRate: FieldValue.delete(), qoinAccrualEnabled: false });
    t.set(historyRef, {
      scope: kind,
      targetId: target.id,
      targetName: (snap.get("name") as string | undefined) ?? "",
      field: "accrualEnabled",
      before: info.before,
      beforeState: info.beforeState,
      beforeRaw: info.beforeRaw,
      after: false,
      op: "set",
      changedBy: uid,
      changedByRole: "admin",
      changedAt: FieldValue.serverTimestamp(),
      reason: REASON,
      source: "migration",
      migratedFromRate: 0,
    });
    return true;
  });
}

export const migrateQoinZeroRates = onCall({ region: REGION, timeoutSeconds: 300 }, async (request) => {
  const db = admin.firestore();
  const uid = await requireAdmin(db, request);

  const dryRun = (request.data as { dryRun?: unknown } | undefined)?.dryRun;
  if (typeof dryRun !== "boolean") throw new HttpsError("invalid-argument", "dryRun must be boolean");

  const stores = await scan(db, "store");
  const brands = await scan(db, "brand");

  let migrated = 0;
  let skipped = 0;
  if (!dryRun) {
    for (const t of stores.zero) (await migrateOne(db, "store", t, uid)) ? migrated++ : skipped++;
    for (const t of brands.zero) (await migrateOne(db, "brand", t, uid)) ? migrated++ : skipped++;
  }
  console.info(`${LOG} ${dryRun ? "dry-run" : "applied"}.`, {
    uid,
    zeroStores: stores.zero.length,
    zeroBrands: brands.zero.length,
    invalidStores: stores.invalid.length,
    invalidBrands: brands.invalid.length,
    migrated,
    skipped,
  });
  return {
    dryRun,
    zeroStores: stores.zero,
    zeroBrands: brands.zero,
    invalidStores: stores.invalid,
    invalidBrands: brands.invalid,
    migrated,
    skipped,
  };
});

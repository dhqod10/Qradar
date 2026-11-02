/**
 * backfillStoreGeohash — admin 전용 callable (store_list_pagination, spec §0 D3).
 *
 * 전 매장의 `position = { geohash, geopoint }` 를 `location(GeoPoint)` 에서 파생해 채운다.
 * 클라이언트 라이브러리(geoflutterfire_plus)와 같은 표준 geohash(정밀도 9)를 쓴다. 멱등 — 이미 같은 값이면 쓰지 않는다.
 * `location` 이 없거나 좌표가 유효하지 않은 매장은 건너뛰고 리포트한다 (자동 보정 금지).
 *
 * 입력 { dryRun?: boolean = true } — dryRun 은 쓰기 0. 실행(dryRun:false)은 400건 청크 배치 +
 * `migrationHistory/{autoId}` 1건 (audit_trail §4-5).
 */
import * as admin from "firebase-admin";
import { FieldValue, GeoPoint } from "firebase-admin/firestore";
import { onCall } from "firebase-functions/v2/https";
import { REGION, requireAdmin } from "./qoinAdmin";

const BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz";
const PRECISION = 9;

/** 표준 geohash 인코딩 (geoflutterfire_plus 와 동일 알고리즘/정밀도). */
export function encodeGeohash(lat: number, lng: number, precision = PRECISION): string {
  let latRange: [number, number] = [-90, 90];
  let lngRange: [number, number] = [-180, 180];
  let hash = "";
  let bits = 0;
  let ch = 0;
  let even = true;
  while (hash.length < precision) {
    const range = even ? lngRange : latRange;
    const val = even ? lng : lat;
    const mid = (range[0] + range[1]) / 2;
    if (val >= mid) {
      ch = (ch << 1) | 1;
      range[0] = mid;
    } else {
      ch = ch << 1;
      range[1] = mid;
    }
    even = !even;
    if (++bits === 5) {
      hash += BASE32[ch];
      bits = 0;
      ch = 0;
    }
  }
  return hash;
}

export const backfillStoreGeohash = onCall({ region: REGION, timeoutSeconds: 540 }, async (request) => {
  const db = admin.firestore();
  const adminUid = await requireAdmin(db, request);
  const dryRun = (request.data as { dryRun?: unknown } | undefined)?.dryRun !== false;

  const snap = await db.collection("stores").get();
  const changes: { id: string; geohash: string; loc: GeoPoint }[] = [];
  const skipped: { id: string; reason: string }[] = [];
  for (const doc of snap.docs) {
    const loc = doc.get("location") as GeoPoint | undefined;
    if (!loc || typeof loc.latitude !== "number" || typeof loc.longitude !== "number") {
      skipped.push({ id: doc.id, reason: "no_location" });
      continue;
    }
    if (Math.abs(loc.latitude) > 90 || Math.abs(loc.longitude) > 180) {
      skipped.push({ id: doc.id, reason: "invalid_coordinates" });
      continue;
    }
    const geohash = encodeGeohash(loc.latitude, loc.longitude);
    const cur = doc.get("position.geohash");
    if (cur === geohash) continue;
    changes.push({ id: doc.id, geohash, loc });
  }

  const report = { dryRun, total: snap.size, affected: changes.length, skipped, sample: changes.slice(0, 20).map((c) => ({ id: c.id, geohash: c.geohash })) };
  if (dryRun) return report;

  for (let i = 0; i < changes.length; i += 400) {
    const batch = db.batch();
    for (const c of changes.slice(i, i + 400)) {
      const ref = db.collection("stores").doc(c.id);
      // 점 표기 update 로 position 만 쓴다 (다른 필드 무변경, updatedAt 도 건드리지 않는다).
      batch.update(ref, { position: { geohash: c.geohash, geopoint: new GeoPoint(c.loc.latitude, c.loc.longitude) } });
    }
    await batch.commit();
  }
  await db.collection("migrationHistory").add({
    name: "backfillStoreGeohash",
    executedBy: adminUid,
    executedAt: FieldValue.serverTimestamp(),
    total: snap.size,
    affected: changes.length,
    skipped: skipped.length,
  });
  return report;
});

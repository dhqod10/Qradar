/**
 * search_keyword_enhancement — `stores/{s}.searchKeywords` 파생 트리거 2개 (CF 전담, soft freshness).
 * 실패는 console.error 후 swallow, 누락은 다음 소스 변경 또는 `backfillStoreSearchKeywords` 가 치유한다.
 *
 *   ① onStoreSearchSourceWritten  stores/{s}  name/brandId/menuCategories 변경(또는 생성)시만 — 자기 파생 쓰기는 무시(루프 가드)
 *   ② onBrandSearchNameWritten    brands/{b}  name 변경시만 산하 매장 fan-out
 */
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { RawDoc } from "./menuVisibility";
import { recomputeBrandSearchStores, recomputeStoreSearchKeywords } from "./recomputeSearchKeywords";

const REGION = "asia-northeast3";

async function guarded(tag: string, fn: () => Promise<unknown>): Promise<void> {
  try {
    await fn();
  } catch (err) {
    console.error(`[${tag}] failed. swallow (soft freshness; backfill heals).`, err);
  }
}

/** 매장 문서 쓰기에서 재계산이 필요한가 — 소스 필드 변경 또는 생성. searchKeywords 만 바뀐 쓰기는 false. */
export function storeSearchSourceChanged(before: RawDoc | undefined, after: RawDoc | undefined): boolean {
  if (after == null) return false; // 삭제
  if (before == null) return true; // 생성 — 시드
  const key = (d: RawDoc) =>
    JSON.stringify([
      typeof d.name === "string" ? d.name : null,
      typeof d.brandId === "string" ? d.brandId : null,
      Array.isArray(d.menuCategories) ? d.menuCategories.filter((x): x is string => typeof x === "string") : [],
    ]);
  return key(before) !== key(after);
}

/** 브랜드 문서 쓰기에서 산하 fan-out 이 필요한가 — 생성/삭제 제외, name 변경시만. */
export function brandNameChanged(before: RawDoc | undefined, after: RawDoc | undefined): boolean {
  if (before == null || after == null) return false;
  return (before.name ?? null) !== (after.name ?? null);
}

export const onStoreSearchSourceWritten = onDocumentWritten(
  { document: "stores/{storeId}", region: REGION, timeoutSeconds: 120 },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!storeSearchSourceChanged(before, after)) return;
    await guarded("onStoreSearchSourceWritten", () => recomputeStoreSearchKeywords(event.params.storeId, after));
  }
);

export const onBrandSearchNameWritten = onDocumentWritten(
  { document: "brands/{brandId}", region: REGION, timeoutSeconds: 540 },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!brandNameChanged(before, after)) return;
    await guarded("onBrandSearchNameWritten", async () => {
      const r = await recomputeBrandSearchStores(event.params.brandId);
      console.info("[onBrandSearchNameWritten] fan-out.", { brandId: event.params.brandId, ...r });
    });
  }
);

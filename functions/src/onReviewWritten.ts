/**
 * onReviewWritten — Cloud Function (onDocumentWritten, asia-northeast3)
 *
 * 매장 평가(reviews) 생성/수정/삭제 시 stores 의 평점 집계를 갱신한다.
 *
 * 설계 (docs/tasks/store_reviews/spec.md §3, §7.2):
 *   - 증분(increment) 이 아니라 **전량 재계산**: count() + sum('score') 집계 쿼리 후 절대값 overwrite.
 *     → 멱등, 시드 오염값/누락 자기 치유, 수정·삭제 보정 불필요.
 *   - stores 에는 `averageScore` / `reviewCount` **2필드만** 쓴다.
 *     `updatedAt`(점주 운영 필드) 과 `grade`(파생 필드, Firestore 에서 읽히지 않음) 는 건드리지 않는다.
 *   - CF 는 등급을 계산하지 않는다 (GradeThresholds 복제 금지).
 *   - 실패는 console.error 후 swallow (트리거 재시도 폭주 방지).
 */

import * as admin from "firebase-admin";
import { AggregateField } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";

/** 한 매장의 평점 집계를 전량 재계산해 stores 에 반영한다. */
async function recomputeStore(storeId: string): Promise<void> {
  const db = admin.firestore();

  const storeRef = db.collection("stores").doc(storeId);
  const storeSnap = await storeRef.get();
  if (!storeSnap.exists) {
    console.warn("[onReviewWritten] store not found. skip. storeId:", storeId);
    return;
  }

  const agg = await db
    .collection("reviews")
    .where("storeId", "==", storeId)
    .aggregate({
      reviewCount: AggregateField.count(),
      scoreSum: AggregateField.sum("score"),
    })
    .get();

  const { reviewCount, scoreSum } = agg.data();
  const averageScore =
    reviewCount === 0 ? 0 : Math.round((scoreSum / reviewCount) * 100) / 100;

  // averageScore / reviewCount 2필드만. updatedAt / grade 금지.
  await storeRef.update({ averageScore, reviewCount });
  console.info("[onReviewWritten] recomputed.", { storeId, reviewCount, averageScore });
}

export const onReviewWritten = onDocumentWritten(
  {
    document: "reviews/{reviewId}",
    region: "asia-northeast3",
  },
  async (event) => {
    const reviewId = event.params.reviewId;
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

    const beforeStoreId = before?.storeId as string | undefined;
    const afterStoreId = after?.storeId as string | undefined;

    if (!beforeStoreId && !afterStoreId) {
      console.warn("[onReviewWritten] storeId missing. reviewId:", reviewId);
      return;
    }

    // 코멘트만 수정 등 score / storeId 무변경이면 집계 불필요.
    if (
      before &&
      after &&
      before.score === after.score &&
      beforeStoreId === afterStoreId
    ) {
      console.info("[onReviewWritten] no aggregate change. skip. reviewId:", reviewId);
      return;
    }

    // storeId 변경(이론상 Rules 로 차단, admin 경로 존재) 이면 양쪽 매장 모두 재계산.
    const targets = new Set<string>();
    if (beforeStoreId) targets.add(beforeStoreId);
    if (afterStoreId) targets.add(afterStoreId);

    for (const storeId of targets) {
      try {
        await recomputeStore(storeId);
      } catch (err) {
        console.error("[onReviewWritten] recompute failed. storeId:", storeId, err);
      }
    }
  }
);

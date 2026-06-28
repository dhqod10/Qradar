/**
 * verifyNaverToken — Cloud Function (onCall, asia-northeast3)
 *
 * 흐름:
 *   1. 입력값 검증 (accessToken 필수)
 *   2. Naver 프로필 API 호출해서 uid 확인
 *   3. Firebase Admin SDK createCustomToken('naver_' + naverUid)
 *   4. 반환 { customToken }
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import axios from "axios";

// ── 입력 타입 ─────────────────────────────────────────────────────────────────

interface VerifyNaverTokenInput {
  accessToken: string;
}

interface NaverProfileResponse {
  resultcode: string;
  message: string;
  response: {
    id: string;
    email?: string;
    name?: string;
    profile_image?: string;
  };
}

// ── 함수 ─────────────────────────────────────────────────────────────────────

export const verifyNaverToken = onCall(
  {
    region: "asia-northeast3",
  },
  async (request) => {
    console.log("[verifyNaverToken] START");

    // 1. 입력값 검증
    const data = request.data as VerifyNaverTokenInput;
    if (!data.accessToken) {
      throw new HttpsError(
        "invalid-argument",
        "accessToken이 필요합니다."
      );
    }

    // 2. Naver 프로필 API 호출
    let naverUid: string;
    try {
      const profileRes = await axios.get<NaverProfileResponse>(
        "https://openapi.naver.com/v1/nid/me",
        {
          headers: {
            Authorization: `Bearer ${data.accessToken}`,
          },
        }
      );

      const profileData = profileRes.data;

      if (profileData.resultcode !== "00") {
        throw new HttpsError(
          "unauthenticated",
          `Naver 프로필 조회 실패: ${profileData.message}`
        );
      }

      naverUid = profileData.response.id;
      console.log("[verifyNaverToken] naverUid:", naverUid);
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      throw new HttpsError(
        "internal",
        `Naver API 호출 실패: ${err instanceof Error ? err.message : String(err)}`
      );
    }

    // 3. Firebase Custom Token 발급
    const uid = `naver_${naverUid}`;
    const customToken = await admin.auth().createCustomToken(uid, {
      provider: "naver",
    });

    console.log("[verifyNaverToken] customToken issued for uid:", uid);

    // 4. 반환
    return { customToken };
  }
);

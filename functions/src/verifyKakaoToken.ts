/**
 * verifyKakaoToken — Cloud Function (onCall, asia-northeast3)
 *
 * 흐름:
 *   1. 입력값 검증 (accessToken 필수)
 *   2. Kakao 프로필 API 호출해서 uid 확인
 *   3. Firebase Admin SDK createCustomToken('kakao_' + kakaoUid)
 *   4. 반환 { customToken }
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import axios from "axios";

// ── 입력 타입 ─────────────────────────────────────────────────────────────────

interface VerifyKakaoTokenInput {
  accessToken: string;
}

interface KakaoProfileResponse {
  id: number;
  kakao_account?: {
    email?: string;
    profile?: {
      nickname?: string;
      profile_image_url?: string;
    };
  };
}

// ── 함수 ─────────────────────────────────────────────────────────────────────

export const verifyKakaoToken = onCall(
  {
    region: "asia-northeast3",
  },
  async (request) => {
    console.log("[verifyKakaoToken] START");

    // 1. 입력값 검증
    const data = request.data as VerifyKakaoTokenInput;
    if (!data.accessToken) {
      throw new HttpsError(
        "invalid-argument",
        "accessToken이 필요합니다."
      );
    }

    // 2. Kakao 프로필 API 호출
    let kakaoUid: number;
    try {
      const profileRes = await axios.get<KakaoProfileResponse>(
        "https://kapi.kakao.com/v2/user/me",
        {
          headers: {
            Authorization: `Bearer ${data.accessToken}`,
          },
        }
      );

      const profileData = profileRes.data;

      if (!profileData.id) {
        throw new HttpsError(
          "unauthenticated",
          "Kakao 사용자 ID를 가져올 수 없습니다."
        );
      }

      kakaoUid = profileData.id;
      console.log("[verifyKakaoToken] kakaoUid:", kakaoUid);
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      throw new HttpsError(
        "internal",
        `Kakao API 호출 실패: ${err instanceof Error ? err.message : String(err)}`
      );
    }

    // 3. Firebase Custom Token 발급
    const uid = `kakao_${kakaoUid}`;
    const customToken = await admin.auth().createCustomToken(uid, {
      provider: "kakao",
    });

    console.log("[verifyKakaoToken] customToken issued for uid:", uid);

    // 4. 반환
    return { customToken };
  }
);

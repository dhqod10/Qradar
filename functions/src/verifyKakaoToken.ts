/**
 * verifyKakaoToken — Cloud Function (onCall, asia-northeast3)
 *
 * 흐름:
 *   1. 입력값 검증 (accessToken 필수)
 *   2. [보안] access_token_info 로 토큰의 app_id(audience) 가 우리 앱(KAKAO_APP_ID)인지 대조
 *   3. Kakao 프로필 API 호출해서 uid 확인
 *   4. Firebase Admin SDK createCustomToken('kakao_' + kakaoUid)
 *   5. 반환 { customToken }
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineString } from "firebase-functions/params";
import axios from "axios";

// 카카오 콘솔의 숫자형 "앱 ID" (네이티브 키 아님). functions .env 로 주입 — 하드코딩 금지.
const kakaoAppId = defineString("KAKAO_APP_ID");

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

interface KakaoAccessTokenInfo {
  id: number;
  expires_in?: number;
  app_id: number;
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

    // 2. [보안] 토큰 audience(app_id) 검증 — 타앱용 토큰으로 세션 획득 차단
    const expectedAppId = kakaoAppId.value();
    if (!expectedAppId) {
      console.error("[verifyKakaoToken] KAKAO_APP_ID 미설정");
      throw new HttpsError("internal", "서버 설정 오류입니다.");
    }
    try {
      const infoRes = await axios.get<KakaoAccessTokenInfo>(
        "https://kapi.kakao.com/v1/user/access_token_info",
        { headers: { Authorization: `Bearer ${data.accessToken}` } }
      );
      if (String(infoRes.data.app_id) !== String(expectedAppId).trim()) {
        console.error(
          "[verifyKakaoToken] REJECTED audience mismatch app_id:",
          infoRes.data.app_id
        );
        throw new HttpsError(
          "unauthenticated",
          "유효하지 않은 Kakao 토큰입니다."
        );
      }
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error("[verifyKakaoToken] access_token_info 실패");
      throw new HttpsError(
        "unauthenticated",
        "Kakao 토큰 검증에 실패했습니다."
      );
    }

    // 3. Kakao 프로필 API 호출
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

    // 4. Firebase Custom Token 발급
    const uid = `kakao_${kakaoUid}`;
    const customToken = await admin.auth().createCustomToken(uid, {
      provider: "kakao",
    });

    console.log("[verifyKakaoToken] customToken issued for uid:", uid);

    // 5. 반환
    return { customToken };
  }
);

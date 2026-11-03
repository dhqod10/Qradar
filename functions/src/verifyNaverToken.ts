/**
 * verifyNaverToken — Cloud Function (onCall, asia-northeast3)
 *
 * Authorization Code flow. 클라는 토큰이 아니라 인증 코드를 보낸다.
 * code → access_token 교환에 서버 전용 client_secret 이 필요하므로
 * 교환 성공 자체가 "우리 앱 전용 코드" 임을 증명한다 (audience 구조적 보장).
 *
 * 흐름:
 *   1. 입력값 검증 ({ code, state, redirect_uri })
 *   2. redirect_uri 가 NAVER_ALLOWED_REDIRECT_URIS 화이트리스트와 정확히 일치하는지 검증
 *   3. nid.naver.com/oauth2.0/token 으로 code 교환 (client_secret 서버 전용)
 *   4. Naver 프로필 API 로 id 확인
 *   5. Firebase Admin SDK createCustomToken('naver_' + id)
 *   6. 반환 { customToken, profile: { email?, name?, imageUrl? } }
 *      profile 은 nid/me 응답 그대로(값이 없으면 키 생략). 앱은 code-flow 라 naver access token 이 없어
 *      스스로 프로필을 못 가져오므로 CF 가 돌려준다.
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret, defineString } from "firebase-functions/params";
import axios from "axios";
import { reactivateIfDeleted } from "./accountReactivation";

const naverClientSecret = defineSecret("NAVER_CLIENT_SECRET");
const naverClientId = defineString("NAVER_CLIENT_ID");
// 콤마 구분. 클라가 보낸 redirect_uri 와 정확히 일치해야 한다.
const naverAllowedRedirectUris = defineString("NAVER_ALLOWED_REDIRECT_URIS");

// ── 입력 타입 ─────────────────────────────────────────────────────────────────

interface VerifyNaverTokenInput {
  code?: string;
  state?: string;
  redirect_uri?: string;
}

interface NaverTokenResponse {
  access_token?: string;
  error?: string;
  error_description?: string;
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
    secrets: [naverClientSecret],
  },
  async (request) => {
    console.log("[verifyNaverToken] START");

    // 1. 입력값 검증 (구 { accessToken } 계약은 폐기 — dual-accept 하지 않음)
    const data = (request.data ?? {}) as VerifyNaverTokenInput;
    if (
      typeof data.code !== "string" || !data.code ||
      typeof data.state !== "string" || !data.state ||
      typeof data.redirect_uri !== "string" || !data.redirect_uri
    ) {
      throw new HttpsError(
        "invalid-argument",
        "code, state, redirect_uri 가 필요합니다."
      );
    }

    // 2. redirect_uri 화이트리스트 (클라 값을 그대로 신뢰하지 않는다)
    const allowed = naverAllowedRedirectUris
      .value()
      .split(",")
      .map((s) => s.trim())
      .filter((s) => s.length > 0);
    if (!allowed.includes(data.redirect_uri)) {
      console.error("[verifyNaverToken] REJECTED redirect_uri not allowed");
      throw new HttpsError("invalid-argument", "허용되지 않은 redirect_uri 입니다.");
    }

    // 3. code → access_token 교환 (client_secret 서버 전용)
    //    Naver 공식 문서: GET/POST /oauth2.0/token 파라미터는
    //    grant_type, client_id, client_secret, code, state. redirect_uri 는 받지 않는다.
    let accessToken: string;
    try {
      const tokenRes = await axios.post<NaverTokenResponse>(
        "https://nid.naver.com/oauth2.0/token",
        null,
        {
          params: {
            grant_type: "authorization_code",
            client_id: naverClientId.value(),
            client_secret: naverClientSecret.value(),
            code: data.code,
            state: data.state,
          },
        }
      );
      // 네이버는 실패도 HTTP 200 + { error } 로 내려줄 수 있다.
      if (!tokenRes.data.access_token) {
        console.error(
          "[verifyNaverToken] token exchange failed:",
          tokenRes.data.error,
          tokenRes.data.error_description
        );
        throw new HttpsError(
          "invalid-argument",
          "Naver 인증 코드 교환에 실패했습니다."
        );
      }
      accessToken = tokenRes.data.access_token;
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error("[verifyNaverToken] token exchange request error");
      throw new HttpsError("internal", "Naver 토큰 교환 호출에 실패했습니다.");
    }

    // 4. Naver 프로필 API 호출 (id 확인)
    let naverUid: string;
    const profile: { email?: string; name?: string; imageUrl?: string } = {};
    try {
      const profileRes = await axios.get<NaverProfileResponse>(
        "https://openapi.naver.com/v1/nid/me",
        { headers: { Authorization: `Bearer ${accessToken}` } }
      );

      const profileData = profileRes.data;

      if (profileData.resultcode !== "00" || !profileData.response?.id) {
        throw new HttpsError(
          "unauthenticated",
          `Naver 프로필 조회 실패: ${profileData.message}`
        );
      }

      naverUid = profileData.response.id;
      const r = profileData.response;
      if (r.email) profile.email = r.email;
      if (r.name) profile.name = r.name;
      if (r.profile_image) profile.imageUrl = r.profile_image;
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      throw new HttpsError(
        "internal",
        `Naver API 호출 실패: ${err instanceof Error ? err.message : String(err)}`
      );
    }

    // 5. Firebase Custom Token 발급 (uid 유도 불변)
    const uid = `naver_${naverUid}`;
    // 탈퇴(익명화)된 동일 uid 재가입 → 깨끗한 신규 상태로 재초기화 (account_deletion §0-9). 실패하면 로그인도 막는다 (deleted 문서 방치 금지).
    try {
      await reactivateIfDeleted(admin.firestore(), uid, "naver");
    } catch (err) {
      console.error("[verifyNaverToken] reactivate failed", uid, err);
      throw new HttpsError("internal", "계정 복구에 실패했습니다. 잠시 후 다시 시도해 주세요.");
    }
    const customToken = await admin.auth().createCustomToken(uid, {
      provider: "naver",
    });

    console.log("[verifyNaverToken] customToken issued for uid:", uid);

    // 6. 반환
    return { customToken, profile };
  }
);

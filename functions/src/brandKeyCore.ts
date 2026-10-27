/**
 * brandKey 공통 — 형식·생성. `issueBrandKey` / `lookupBrandByKey` / 마이그레이션이 같은 규칙을 쓴다 (한 사실에 하나).
 * 형식은 Dart 폼 정규식(`store_core_form_page.dart`)과 같지만 **서버가 재검증한다** — 클라 정규식을 권위로 삼지 않는다 (spec §10.3).
 */
import { randomInt } from "crypto";

export const BRAND_KEY_RE = /^BR-[A-Z2-9]{8}$/;
// 0/O/I/1 제외 — 기존 클라이언트 발급과 같은 alphabet (A-Z + 2-9 중 헷갈리는 글자 제외).
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

export function generateBrandKey(): string {
  let s = "";
  for (let i = 0; i < 8; i++) s += ALPHABET[randomInt(ALPHABET.length)];
  return `BR-${s}`;
}

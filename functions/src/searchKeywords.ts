/**
 * SearchKeywordTokenizer (TS) — search_keyword_enhancement spec §4. 순수 함수(I/O 없음).
 *
 * Dart `lib/core/utils/search_keyword_tokenizer.dart` 와 **동일 규칙**이어야 한다.
 * 양쪽은 `test_fixtures/search_keyword_contract.json` (cross-golden) 으로 lockstep 을 검증한다.
 *
 * buildKeywords(sources):
 *   source 마다 trim → 소문자 → 공백 분할. 각 단어의 모든 prefix(1..len) 추가,
 *   이어서 공백 제거 전체 문자열의 모든 prefix 추가. 중복 제거(삽입 순서 보존), MAX_KEYWORDS 초과 시 앞에서 자른다.
 *   길이/분할은 code point 기준 (Dart runes 와 동일).
 */

export const MAX_KEYWORDS = 300;
export const MAX_QUERY_TOKENS = 10;

const WS = /\s+/;

function prefixes(word: string): string[] {
  const cps = Array.from(word);
  const out: string[] = [];
  let acc = "";
  for (const cp of cps) {
    acc += cp;
    out.push(acc);
  }
  return out;
}

export function buildKeywords(sources: string[], maxKeywords: number = MAX_KEYWORDS): string[] {
  const set = new Set<string>();
  for (const raw of sources) {
    if (typeof raw !== "string") continue;
    const s = raw.trim().toLowerCase();
    if (s === "") continue;
    for (const w of s.split(WS)) {
      if (w === "") continue;
      for (const p of prefixes(w)) set.add(p);
    }
    for (const p of prefixes(s.replace(/\s+/g, ""))) set.add(p);
  }
  return Array.from(set).slice(0, maxKeywords);
}

/** 질의 토큰: trim → 소문자 → 공백 분할 → 빈 것 제거 → 중복 제거 → 최대 10개. */
export function queryTokens(raw: string, max: number = MAX_QUERY_TOKENS): string[] {
  const s = raw.trim().toLowerCase();
  if (s === "") return [];
  const out: string[] = [];
  for (const w of s.split(WS)) {
    if (w === "" || out.includes(w)) continue;
    out.push(w);
    if (out.length >= max) break;
  }
  return out;
}

/** 같은 키워드 목록인가 (결정적 순서이므로 순서 포함 비교). 부재/비배열 = 다름. */
export function sameKeywords(a: unknown, b: string[]): boolean {
  if (!Array.isArray(a) || a.length !== b.length) return false;
  return a.every((v, i) => v === b[i]);
}

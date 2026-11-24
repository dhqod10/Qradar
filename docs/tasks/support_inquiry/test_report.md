# support_inquiry 테스트 리포트 (tester, 2026-11-24)

기준: spec §0 (Q1~Q10), design §11. 배포·커밋·제품 코드 수정 없음.

## 요약
- PASS 다수 / **FAIL 0 (차단급 없음)** / 결함·권고 5건 (Medium 2, Low 3) / 미검증 4영역
- 가장 먼저 고칠 것: **D1 (답변 후 읽기 전 종결 시 고객이 답변을 못 봄)**

## 1. 재실행 결과
| 항목 | 결과 |
|---|---|
| flutter analyze | No issues |
| flutter test | 1110 pass |
| functions build + npm test | 604 pass |
| Firestore Rules (npm test) | SI-* 31건 전부 PASS (FAIL 0) |
| Storage Rules 13건 (developer 하네스) | 13/13 PASS — 단 아래 D4 참고, npm 스크립트 그대로는 실행 불가 |
| Storage 추가 회귀 (tester 작성, 스크래치) | brand_images / menu_images 중첩 read·write, 11MB 거부, non-image 거부, 비로그인 write 거부, `support_inquiries_evil` 접두사 유사 경로 공개 유지, 타인 overwrite 거부 — 전부 PASS |
| CF 에뮬레이터 통합 (tester 작성, firestore+functions 에뮬레이터, 26건) | 전부 PASS |

## 2. ① Storage Rules — PASS
재현: scratchpad 에 `storage.rules` 복사본 + 프로젝트 내부 config 로 `firebase-tools@14 emulators:exec --only storage` (JDK 21).
비로그인 문의첨부 read 거부, 로그인 사용자 read 허용, 남의 uid 경로 write 거부, 6MB 거부, 기존 경로 공개 read/로그인 write 유지. 와일드카드 제외 방식이 에뮬레이터에서 실제 동작함을 확인. 설계 재검토 불필요.

## 3. ② 확정값
| 항목 | 결과 | 근거 |
|---|---|---|
| 3장 / 5MB / maxWidth1600·q85 / 갤러리+카메라 | PASS(코드) | attachment_picker.dart, storage_data_source |
| iOS NSCameraUsageDescription, Android CAMERA | PASS | Info.plist / AndroidManifest diff |
| 수정·삭제 불가, 철회만 | PASS | Rules SI-5/6, 에뮬 |
| 탈퇴 시 보존+authorDeleted+열린 건 종결 | PASS(단위) | deleteMyAccount.ts markSupportInquiries, 테스트 604. Auth 에뮬 통합은 미실행 |
| 정지 계정 | PASS | CF 는 허용(Q7), 로그인 차단은 기존 |
| 도배 분1/일5 서버 강제 | PASS | 에뮬 E3·E9 (6번째 거부, 정확히 5건) |
| 답변 1회, status 4종, 재오픈 없음 | PASS | 에뮬 M3·M6 |
| admin Rules 직접 쓰기 차단 | PASS | SI-8/8b, 4b, 5b |
| dot = AppColors.error + 부제 "새 답변이 도착했어요" | PASS(코드) | more_page.dart diff. 화면 실물은 미검증 |
| 주문 소유 검증/열거 방지, 첨부 경로 주입, 4장·길이 | PASS | 에뮬 E4~E7 |

## 4. ③ 절대 규칙 — PASS
- `Color(0x`/Colors.* 하드코딩 없음, 키·secret 없음
- presentation/domain 의 Firebase import 없음. presentation 은 DI providers 에서만 data 를 import (기존 review/brand 와 동일 선례). image_picker 는 기존 선례대로 presentation 사용

## 5. ④ 회귀
- deleteMyAccount / adminDeleteUser 단위 테스트 통과(mock 갱신). 주문 상세는 `_ActionSection` 미수정, 뒤에 블록 추가 확인. 더보기 `_MoreTile` rename 확인. lib/domain 서식 변경은 되돌려져 있음(diff 없음).
- 콘솔 기존 섹션은 코드 diff 상 가산적 변경만 확인, 브라우저 실동작은 미검증.

## 6. 결함 / 권고
| ID | 심각도 | 내용 | 수정 방향 |
|---|---|---|---|
| D1 | **Medium** | 관리자가 답변(answered) 후 고객이 읽기 전에 종결(closed)하면 `hasUnreadAnswer`(status==answered 필수)와 Rules C2(answered 에서만)가 모두 막혀 **dot 이 뜨지 않고 답변 존재를 알 수 없음.** 답변 후 곧바로 `answered_done` 종결하는 것이 자연스러운 운영 흐름이라 발생 확률 높음 | `hasUnreadAnswer` 를 `answer!=null && answerReadAt==null`(철회 제외)로, Rules C2 를 answered/closed 허용으로 확장. 또는 답변 시 종결 금지 안내 |
| D2 | **Medium** | `createSupportInquiry` 가 첨부 URL 의 **bucket 을 검증하지 않음.** 에뮬 E4c: 타 bucket URL(경로만 일치)이 created:true 로 통과. 관리자 콘솔이 임의 외부 URL 이미지를 로드(IP 노출·추적) | `parseStorageUrl().bucket` 을 프로젝트 bucket 과 비교 |
| D3 | Low | 본인도 첨부 삭제 불가(Storage 규칙에서 delete 시 `request.resource` null → 평가 오류로 거부, 에뮬 확인). 거절 후 `discardImages` 정리가 항상 조용히 실패해 고아 파일 발생. 보존 정책상 의도에 가깝지만 문서화 필요 | 후속 고아 정리 스케줄러(spec §8)에 포함 |
| D4 | Low | `npm run test:storage` 가 `../storage.rules is outside of project directory` 로 실행되지 않음(firebase-tools 14/15 모두). developer 보고 13/13 은 다른 방식으로 실행한 것으로 보이며 재현 불가한 스크립트가 커밋 대상에 포함됨 | config 를 프로젝트 루트로 옮기거나 스크립트 수정 |
| D5 | Low/참고 | 첨부 download URL 은 토큰 포함이라 URL 만 알면 Rules 우회로 열림(Q5 로 수용된 범위). Rules 는 "로그인 사용자 누구나 경로 read" — 경로 추측은 inquiryId/타임스탬프로 사실상 어려움 | 정보 공유용. 엄격안은 후속 `storage_security_rules` |

참고: 클라 5MB 검사(`> 5MB` 거부)와 Rules(`< 5MB`) 경계가 1바이트 어긋나, 정확히 5,242,880B 파일은 클라 통과 후 업로드 실패(실무 영향 극히 낮음).

## 7. 미검증 (사유)
1. **앱 UI 전 과정**: 시뮬레이터에 로그인 세션 없음(로그인 화면에서 중단). 테스트 계정 정보가 없고 운영 Firebase 에 쓰게 되므로 진행 안 함. 앱 빌드·기동은 정상(Xcode build 10s, 로그인 화면 표시). 목록/작성/상세/dot/갤러리 선택·장수 상한/`no_available_camera` 분기는 코드 리뷰와 단위 테스트까지만.
2. **카메라 실촬영·권한 거부·영구 거부**: 실기기 필요.
3. **어드민 콘솔 브라우저 동작**: 로그인(운영 Firebase) 불가. 순수 함수(에러 분류, enum 안전 폴백, safeUrl, esc)는 node 로 확인했고 렌더·모달 포커스 '취소'는 코드상 확인만.
4. **deleteMyAccount Auth 통합**(`test:emulator` 기존 스위트 및 Auth 에뮬 포함 탈퇴 경로)은 미실행. 단위 테스트로 대체.
5. **인덱스 미배포 시 앱 error 상태**: 운영에 인덱스 배포가 선행돼야 목록이 동작(implementation §5 배포 순서 준수 필요).

## 8. 쓰기 기록
운영 Firebase 에 쓰지 않음. 모든 쓰기는 로컬 에뮬레이터(종료됨).

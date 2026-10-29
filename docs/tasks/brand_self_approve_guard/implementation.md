# brand_self_approve_guard 구현 결과

## 변경 파일
- `firestore.rules` (헬퍼 2개 추가 + 브랜드 분기 3곳 교정). Dart/CF 변경 없음.
- `docs/processes/data_ownership.md` (§2.6, §2.8), `docs/processes/entity_lifecycle.md` (§5.2, §5.4, §5.5)

## 헬퍼 (onlyChangedFields 직후, 신규 get() 0)
- `noSelfApproveOnCreate()`: `status` 는 'pending'(부재 시 pending 취급)만, `approvedBy`/`approvedAt` 부재 또는 null.
- `noSelfApproveOnUpdate()`: diff 기반. `status` 변경 시 'pending' 만, `approvedBy`/`approvedAt` 변경 시 null 만. 미변경이면 통과.

## 수정 지점
| # | 경로 | 변경 |
|---|---|---|
| V1 | `brands/{brandId}/menuItems` | `create/update/delete` 분리. create=`isAdmin() \|\| (isBrandHolder && noSelfApproveOnCreate())`, update=`... noSelfApproveOnUpdate()`, delete 유지 |
| V2 | `stores/{storeId}/menuOverrides` | 브랜드 분기에 create/update 각각 헬퍼 `&&`. 점주 분기(`ownerOverrideCreateOk`, `onlyChangedFields`)·delete·admin 불변. 필드명 `status`/`approvedBy`/`approvedAt` 은 `menu_override_repository_impl.dart` 에서 확인 |
| V3 | `stores/{storeId}/menuItems` | one-liner 를 create/update/delete 로 분리, 브랜드 분기만 헬퍼 적용. **점주 분기(isStoreOwner)는 현행 유지 (D2 제외)** |

## 회귀 점검 (Rules 로직상 정적 추론, 하네스 없음)
- 브랜드 create(pending, 승인메타 null): create 헬퍼 통과 (master/store-only/override 모두).
- 브랜드 내용수정·재제출(→pending, approvedBy/At 보존): status 변경 시 'pending' OK, 승인메타는 diff 에 없음 → 통과. `leavingRejectedClearsApproval` 미사용.
- 브랜드 운영 update(visible/tags/soldOut 등): status 미변경 → 현재 approved 여도 통과.
- 브랜드 upsertOverrideCore(pending, 승인메타 부재): create/update 모두 통과.
- admin approve/reject: `isAdmin()` 분기로 헬퍼 밖 → 통과 (admin_menu_management 영향 없음).
- 점주 오버라이드 품절 토글/제외 시드: 점주 분기 불변 → 통과 (store_category_optout, PPA-1~3 영향 없음). 단 브랜드·점주 OR 평가이므로 브랜드 분기 실패가 점주 분기 평가를 막지 않음.
- 악의 케이스: create 시 status approved / approvedBy·approvedAt non-null → 거부. update 로 status →approved/rejected, approvedBy/At non-null → 거부.
- 괄호/중괄호 균형 확인 완료 (`{}` `()` 모두 0). Dart 무변경이라 analyze/test 영향 없음. 에뮬레이터 하네스가 없어 실행 검증은 불가.

## 문서 동기화
data_ownership §2.6 (브랜드 가드 노트, 표 brandHolder 행 분리, 방어 계층 ⚠️ 갱신), §2.8 (브랜드 menuItems 가드, 일관성 문구), entity_lifecycle §5.2 (Rules 분기), §5.4 (브랜드 분기 해소, 점주 분기 ⚠️ 잔존 명시), §5.5 (brandHolder 제출만).

## 배포 안내 (사용자 전담)
`firebase deploy --only firestore:rules` (프로젝트 루트에서 실행). 본 작업은 배포하지 않았다. 배포 후 브랜드 계정으로 메뉴 생성/수정/재제출/운영수정/가격 오버라이드, admin 승인/반려를 수동 스모크 권장.

## 미구현/보류
- stores/menuItems 점주 분기 self-approve (D2, 백로그 별도).
- optionGroups priceDelta 우회로 (비범위).

## tester 테스트 포인트
spec 의 악의/정당 케이스 목록 그대로. 특히 재제출 시 승인메타 보존 케이스와 status 미변경 운영 update.

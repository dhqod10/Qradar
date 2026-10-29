# brand write 왕복 하드닝 (brand_update_partial_hardening) — implementation

## 수정 지점
- `lib/data/repositories/brand_repository_impl.dart` `upsertBrand` 의 `coreChanged` 분기: `_dataSource.set(brandId, model.toFirestore())` (문서 전체) -> `_dataSource.update(brandId, {...})` (부분).
- 테스트 정합: `test/data/brand_private_profile_repository_test.dart` 의 "name 이 바뀌면 pending 회귀" 기대를 set -> update 로 변경하고 보존 키 미전송 단언 추가.

## 전송 필드 (화이트리스트)
`name, logoUrl, description(null 이면 FieldValue.delete()), companyName, status:'pending', submittedBy(uid), submittedAt(Timestamp.fromDate(now), 기존과 동일 값 소스), updatedAt(serverTimestamp, 기존 toFirestore 와 동일)`.

참고: 지시문의 phone/address/businessHours/tags 는 BrandModel/BrandEntity 에 존재하지 않는 필드(Rules whitelist 에만 있음)라 기존 `toFirestore()` 가 보내던 필드와 1:1 로 매핑했다. 누락된 운영 필드 없음.

## 보존 의미 유지
`createdAt, approvedAt, approvedBy, brandKey, rejectedReason` 는 payload 에서 제외 -> Firestore 값 그대로 유지. 직렬화 왕복 의존 제거, Rules `isBrandSelfUpdate` 의 금지 키 diff 에 걸리지 않음. status 는 pending 만 전송(자기 승격 차단 조건 충족). description null 시 기존 set 처럼 필드가 제거되는 동작도 유지. 신규 등록 set, logoUrl-only 분기, `_writePrivate` 는 불변.

## 검증
- `flutter analyze`: No issues found.
- `flutter test`: 최초 전체 실행에서 brand 테스트 1건(위 기대 정합 후 통과) + 무관 2건(payment_failure_test, home_search_stage2_test) 이 실패했으나 변경 없이 단독 재실행 시 통과(플래키). 정합 후 test/data 통과.
- 테스트 포인트(tester): 핵심필드 수정 시 update 맵에 보존 키 부재, 승인 브랜드 수정 후 approvedAt/createdAt 불변, 에뮬레이터 Rules 통과.

## 확장: 동일 왕복 버그 2경로 (brand_self_approve_guard 하 라이브 회귀)
공통 원인: full payload 의 approvedBy/approvedAt 가 serverTimestamp(ns) -> DateTime(us) 왕복에서 절삭되어 noSelfApproveOnUpdate 에 걸림.
- `master_menu_item_repository_impl.updateMasterMenuItemCore`: update 는 유지하되 `toFirestore()` 맵에서 `createdAt, approvedBy, approvedAt` 만 제거. 나머지 운영/회귀 필드(status=pending, submittedBy/At, rejectedReason, 핵심 필드 전부)는 기존과 동일 전송.
- `menu_override_repository_impl.upsertOverrideCore`: 기존이 `set(..., merge:true)` upsert(문서 없을 수 있음)라 update 로 바꾸면 신규 생성이 깨지므로 set merge 유지, 맵에서 `approvedBy, approvedAt` 만 제거 (override 모델에 createdAt 없음). merge 이므로 기존 승인 메타 보존.

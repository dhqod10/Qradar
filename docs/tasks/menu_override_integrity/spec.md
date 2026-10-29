# menu_override_integrity 기능 명세

웹 세션 인계 #3(cascadeDeleteOverrides no-op) + #4(점주 오버라이드 create `masterMenuItemId` 누락) 묶음 수정.
근거: `docs/backlog.md` "웹 세션 인계 — 앱 영역 보안·정합성 8건" 3·4번.

---

## 개요

- **목적**: 점주가 생성한 메뉴 오버라이드가 `masterMenuItemId` 필드를 갖도록 정합화하고(#4), 마스터 메뉴 삭제 시 산하 매장 오버라이드가 실제로 cascade 삭제되도록 경로를 단일 실동작으로 수렴한다(#3). 두 수정으로 "마스터 삭제 → 고아 오버라이드 잔존 → 같은 id 재생성 시 과거 품절/옵션비활성 되살아남" 을 막는다.
- **작업 유형**: 버그 수정 (data 레이어 정합성).
- **영향 범위**:
  - 화면: 없음 (UI 변경 없음)
  - Domain: 없음 (Entity/UseCase/Repository Interface 시그니처 불변)
  - Data: `MenuOverrideRepositoryImpl`(#4), `MasterMenuItemRepositoryImpl`(#3), `MasterMenuItemRemoteDataSource`(#3 no-op 제거)
  - Presentation: `brand_di_providers.dart`(#3 의존성 non-null 전환 시 생성자 인자 1줄)
  - 공통 컴포넌트: 없음
  - 라우팅: 없음
  - 권한 / 환경 설정: **Firestore Rules 변경 없음**(아래 §Rules 검증), **CF 변경 없음**(아래 §CF 검증), **인덱스 신규 없음**(아래 §인덱스 검증)
  - 운영(백필): 기존 점주 오버라이드 백필 여부 — **사용자 결정 필요** (§백필)
- **비범위 (이번 작업 제외)**:
  - `countStoresUsingPriceOverride` 의 복합 인덱스 공백 (별도 관찰 항목, §인덱스 검증 참고)
  - `stores/menuItems` 점주 분기 자가승인 (backlog D2, 별도 task)
  - 옵션 그룹 가격 승인 우회로 (payment_price_authority P2)
  - 메뉴 오버라이드 관련 신규 기능/정책

---

## 선행 검증 결과 (앱 세션 코드 확인 — 재검증 불필요, 설계 전제)

### #4 — `masterMenuItemId` 누락 지점은 **점주 W2 create 1곳뿐**

- 누락: `lib/data/repositories/menu_override_repository_impl.dart` `updateOverrideOperationFields` 의 **W2 create 분기(existing==null, 약 164~180줄)** data 맵에 `masterMenuItemId` 없음. 문서 id 로만 존재한다.
- 정상(필드 포함)인 다른 생성 경로:
  - 브랜드 경로 `upsertOverrideCore`(57~76줄)는 `MenuOverrideModel.fromEntity(override).toFirestore()` 를 펼쳐 쓰는데, 모델 `toFirestore()`(`menu_override_model.dart:126`)가 `masterMenuItemId` 를 포함한다. → 필드 있음.
  - `seedExclusionsForStore`(`menu_override_remote_data_source.dart:138~151`)도 `'masterMenuItemId': masterMenuItemId` 를 명시적으로 쓴다. → 필드 있음.
- 결론: **점주 W2 create 외에 누락 경로 없음.** 수정은 이 1곳에 필드 1개 추가.

### #3 — "no-op" 은 프로덕션에서 **죽은 코드**다. 실제 문제는 "조용한 폴백 + #4"

- `deleteWithCascade`(`master_menu_item_repository_impl.dart:119~127`)는 이미 분기한다:
  - `_menuOverrideRepository != null` → `deleteAllForMaster(menuItemId)` → `cascadeDeleteByMaster` = **실제 collectionGroup where+batch delete**.
  - `_menuOverrideRepository == null` → `_dataSource.cascadeDeleteOverrides` = **no-op(debugPrint)**.
- 프로덕션 DI(`brand_di_providers.dart:70`)는 `menuOverrideRepository: ref.watch(menuOverrideRepositoryProvider)` 를 **항상 주입**한다. → 프로덕션은 실제 cascade 를 탄다. no-op 은 폴백으로만 존재(테스트 등에서 미주입 시).
- 따라서 #3 의 실질 위험은 "no-op 이 돈다" 가 아니라 **조용한 폴백**이다: 리팩터링/테스트로 주입이 끊기면 마스터 삭제가 **아무 신호 없이** 전 오버라이드를 고아로 남긴다.
- 그런데 실제 cascade(`cascadeDeleteByMaster`)는 `where('masterMenuItemId', ==)` 로 질의한다(`menu_override_remote_data_source.dart:104~105`). **필드가 없는 점주 오버라이드는 이 질의에 안 걸려 삭제되지 않는다.** → 이것이 #4 가 #3 의 선행인 이유. #4 를 먼저 고쳐야 실제 cascade 가 점주 오버라이드까지 지운다.

---

## 요구사항

### 기능 요구사항

- [ ] (#4) 점주 W2 create data 맵에 `'masterMenuItemId': override.masterMenuItemId` 추가. 브랜드 경로·seed 경로와 정합.
- [ ] (#3) 마스터 메뉴 삭제 경로가 **단일 실동작 cascade** 를 타게 한다. 죽은 no-op `cascadeDeleteOverrides` 제거, cascade 는 `deleteAllForMaster` → `cascadeDeleteByMaster` 하나로 수렴.
- [ ] (#3) 의존성 미주입 시 **조용히 넘어가지 않게** 한다(아래 D-2 권고: non-null 전환).
- [ ] (백필) 기존 점주 오버라이드 `masterMenuItemId` 누락분 처리 방침 확정 (§백필, 사용자 결정).

### UI 요구사항

- 없음. **designer 불필요** (화면/위젯/흐름 변경 없음).

### 상태 요구사항

- 없음 (Provider/상태 머신 변경 없음). cascade 는 기존 삭제 UseCase 흐름 그대로.

---

## 데이터 모델

- **스키마 변경 없음.** `masterMenuItemId` 는 이미 `MenuOverrideModel` 필드이고 다른 경로가 쓰고 있다. 이번 수정은 **누락 경로를 정합화**하는 것뿐이다.
- `masterMenuItemId` 의 값은 **항상 해당 오버라이드 문서의 id 와 동일**하다(`stores/{storeId}/menuOverrides/{masterMenuItemId}`). 백필이 trivially 안전한 근거(= doc.id).

---

## 레이어 설계

Clean Architecture 상 **전부 data 레이어**에서 끝난다. domain/presentation 의존 방향·시그니처 불변.

### #4 — `MenuOverrideRepositoryImpl.updateOverrideOperationFields` W2 create

`lib/data/repositories/menu_override_repository_impl.dart` 약 164~180줄 data 맵에 `masterMenuItemId` 추가:

```
final data = <String, dynamic>{
  'masterMenuItemId': override.masterMenuItemId,   // ← 추가 (브랜드 경로·seed 경로와 정합)
  'storeId': override.storeId,
  ... (기존 필드 유지)
};
```

- status/priceOverride/excluded/승인 메타는 **현행 유지**(W2 create 는 `status:'approved'`, `priceOverride:null`, `excluded:false`, 승인 메타 null). 필드 1개만 추가.

### #3 — cascade 단일 실동작 수렴

- `MasterMenuItemRemoteDataSource.cascadeDeleteOverrides`(`:146~155`) **메서드 삭제**(죽은 no-op).
- `MasterMenuItemRepositoryImpl.deleteWithCascade`(`:119~127`) 를 분기 없이 단일 경로로:
  ```
  Future<void> deleteWithCascade(String brandId, String menuItemId) async {
    _assertOwnership(brandId);
    await _menuOverrideRepository.deleteAllForMaster(menuItemId); // 항상 실제 cascade
    await _dataSource.delete(brandId, menuItemId);                // 그 다음 마스터 삭제
  }
  ```
- `_menuOverrideRepository` 를 **non-nullable 로 전환**(D-2). 생성자 `required MenuOverrideRepository menuOverrideRepository`. 프로덕션 생성자(`brand_di_providers.dart:66~71`)는 이미 주입 중이라 `?` 제거 + required 전환만. (대안: nullable 유지 + 미주입 시 `throw StateError`. 조용한 no-op 만은 금지.)
- `cascadeDeleteByMaster`(`menu_override_remote_data_source.dart:102~120`)는 **그대로 재사용**:
  - collectionGroup(menuOverrides).where('masterMenuItemId', ==).get()
  - 빈 결과 short-circuit, chunk 490(<500) 순차 batch commit → 500 상한 준수.
  - **멱등**: 이미 삭제된 문서는 재질의 시 안 걸림. 중간 chunk 실패 시 마스터 삭제 전 단계라 마스터는 남고, 재실행이 남은 오버라이드부터 이어 지움. → 추가 보강 불필요.
- **삭제 순서**: 오버라이드 cascade → 마스터. 현행 순서 유지(부분 실패해도 고아 안 생김).

### 재사용/중복 정리 결론

- `cascadeDeleteOverrides`(no-op, remote DS) **제거**.
- `deleteAllForMaster`(`MenuOverrideRepositoryImpl`) → `cascadeDeleteByMaster`(remote DS) **단일 실구현 유지**. 중복 구현 신설 금지(remote DS 간 collectionGroup 질의 복제 금지).

---

## 데이터 흐름

```
마스터 삭제:
브랜드 상세/목록 페이지
  → DeleteMasterMenuItemUseCase
  → MasterMenuItemRepository.deleteWithCascade
      → MenuOverrideRepository.deleteAllForMaster
          → MenuOverrideRemoteDataSource.cascadeDeleteByMaster
              → collectionGroup(menuOverrides).where(masterMenuItemId==).batch delete
      → MasterMenuItemRemoteDataSource.delete (마스터 문서)

점주 품절/옵션 토글(오버라이드 신규):
owner_store_menu_list_page
  → (UseCase)
  → MenuOverrideRepository.updateOverrideOperationFields
      → (existing==null) W2 create: data 맵에 masterMenuItemId 포함 → set
```

---

## Rules / CF / 인덱스 검증 (설계 전제, 모두 변경 불필요)

### Rules 검증 — 통과 (변경 없음)

- `menuOverrides` storeOwner create 분기는 `ownerOverrideCreateOk()`(`firestore.rules:506~516`)만 요구한다. 이 함수는 **`hasOnly` 필드 화이트리스트가 없다** — status 값 집합/승인 메타 null/`approved→price·excluded` 제약만 본다.
- 따라서 W2 create 에 `masterMenuItemId` 가 추가돼도 거부되지 않는다. W2 payload(`status:'approved'`, `priceOverride:null`, `excluded:false`, 승인 메타 null)는 그대로 통과.
- 브랜드 경로·seed 경로가 이미 `masterMenuItemId` 를 써서 통과 중인 것도 방증.

### CF 검증 — 통과 (변경 없음)

- `onStoreMenuOverrideWritten` / `onAvailableCategoriesWritten` / `onMenuPriceWritten` 는 모두 **path 기반 트리거**(`stores/{storeId}/menuOverrides/{masterMenuItemId}`)라 문서 본문의 `masterMenuItemId` 필드 유무와 무관.
- `auditOrderPriceIntegrity.ts:208` 은 `collectionGroup("menuOverrides").get()` 전체 조회라 필드 무관.
- `onMenuPriceWritten` 는 create/update/delete 에 모두 반응 → **cascade 로 지워지는 priceOverride 보유 오버라이드의 삭제는 `priceHistory` 에 before/after 로 이미 기록된다**(§감사 추적).

### 인덱스 검증

- cascade 질의 `where('masterMenuItemId', ==)` (단일 필드 equality, orderBy 없음)는 Firestore 가 **자동 유지하는 단일 필드 collection-group 인덱스**로 커버된다. → 신규 복합 인덱스 불필요. (developer/tester: 에뮬레이터/실환경에서 cascade 1회 실행으로 index 에러 부재 확인.)
- 현 `firestore.indexes.json` 의 menuOverrides 복합 인덱스는 `[status, submittedAt]`(pending 큐)뿐.
- **관찰(비범위)**: `countStoresUsingPriceOverride`(`:158~167`)는 `where(masterMenuItemId==) AND where(status==)` 복합 질의인데 대응 복합 인덱스가 indexes.json 에 없다. 이는 이번 수정과 **독립적인 기존 공백**이다. 이번 작업에서 고치지 않되, tester 가 해당 경로를 실행할 경우 index 에러 발생 가능성을 보고한다(후속 분리 등재 판단).

---

## 백필 — 기존 점주 오버라이드 `masterMenuItemId` 누락분 (사용자 결정 필요)

### 영향도 평가

- 누락 문서 = **점주 W2 create 로 만들어진 기존 오버라이드**뿐. 이들은 `priceOverride:null`, `excluded:false`, `status:'approved'`.
- 누락이 실제로 문제되는 지점:
  - **cascade 삭제**: 마스터 삭제 시 이 문서들이 `where(masterMenuItemId==)` 에 안 걸려 **고아 잔존** → 같은 id 재생성 시 **soldOut/옵션비활성 플래그만** 되살아남(가격/제외는 null/false라 되살 것이 없음). → 심각도 **낮음**.
  - `countStoresUsingPriceOverride`: `priceOverride != null` 필터라 null-가격 문서는 **애초에 집계 대상 아님** → 영향 없음.
  - admin pending 큐: `status=='pending'` 질의 — 이 문서들은 `approved` 라 **영향 없음**.
- 현재는 테스트 기간(계정/매장 소수, `audit_trail.md §7` 참조). 프로덕션 점주 오버라이드 건수는 미상.

### 권고 (architect)

- **기본 권고: (a)+(c) 절충 — 일회성 백필 스크립트를 developer 가 작성하되, 실행은 count 확인 후 사용자 결정.**
  - `masterMenuItemId == doc.id` 이므로 백필은 `set({masterMenuItemId: doc.id}, merge:true)` — **멱등·무손실·안전**.
  - 실행 게이트: 먼저 count 질의(`collectionGroup(menuOverrides)` 중 `masterMenuItemId` 필드 부재 또는 `masterMenuItemId != doc.id`)로 대상 수 확인. **0건이면 생략**, 소수면 수동/스크립트, 다수면 스크립트.
  - 스크립트 형태: **Admin SDK 일회성**(`functions/scripts/` 또는 별도 ops 스크립트). 클라이언트 불가(collectionGroup 전역 write 권한).
  - **감사**: 스크립트 실행 시 `migrationHistory/{autoId}` 1건(`name:'backfillMenuOverrideMasterId'`, `affected` = 처리 건수) 기록 — 기존 일괄 처리 패턴(`data_ownership §2.13`, `audit_trail §4-5`)과 정합.
- **대안**: 테스트 기간·낮은 심각도를 근거로 (b) 생략도 수용 가능. **최종 판단은 사용자.**

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| cascade 중간 chunk commit 실패 | 마스터 삭제 전 단계이므로 마스터는 남음. 재실행이 남은 오버라이드부터 멱등 재개. 별도 롤백 불필요 |
| `_menuOverrideRepository` 미주입 | (D-2 non-null 전환 시 컴파일 차단) / nullable 유지 시 `throw StateError` — **조용한 no-op 금지** |
| cascade collectionGroup index 미배포 | Firestore index 에러 → 로그. 단일 필드 자동 인덱스로 커버 예상(검증 항목) |
| 점주 W2 create Rules 거부 | 발생하지 않음(§Rules 검증). 회귀 테스트로 고정 |

---

## 감사 추적 (audit_trail §4 체크리스트)

1. **돈·권한·정책 값을 바꾸는가?** → **아니오.** `masterMenuItemId` 는 문서 id 와 동일한 **비정규화 키 필드**이고, cascade 실동작화는 기존 삭제 의미를 바꾸지 않는다. 정책/적립률/권한 값 변경 없음. → **설정 변경 이력 신설 불필요.** (사유 명시 완료.)
2. **덮어쓰기로 사라지는 값?** → cascade 는 오버라이드를 **삭제**한다(마스터 삭제의 의도된 정리). priceOverride 보유 오버라이드의 삭제는 `onMenuPriceWritten` → `priceHistory` 에 before/after 로 **이미 기록**된다. 점주 W2 문서는 보존할 값(가격/제외)이 없다.
3. **기록 문서가 정책 값을 참조만?** → 신규 거래/기록 문서 없음. Qoin 원장 등 무관.
4. **"누가" 기록?** → 파괴적 이벤트(오버라이드 삭제) 행위자는 `priceHistory.changedBy`(트리거)가 담당. 추가 불필요.
5. **batch 가 있는가?** → cascade(chunk batch) 있음. 개별 priced override 삭제는 `priceHistory` 가 문서별 1건으로 남김. **백필 스크립트 실행 시 `migrationHistory` 1건 + `affected` 수 기록**(요구사항에 반영).
6. **CF 로그 의존?** → 아니오. 영구 보존은 `priceHistory`/`migrationHistory`(Firestore)로 담김.
7. **(상시) 권한 판정 필드 create/update 교차?** → `masterMenuItemId` 는 권한 판정 입력이 아님. 해당 없음. 단 create 경로 Rules 영향은 §Rules 검증에서 확인 완료.

→ **체크리스트 통과. 신규 감사 인프라 불필요. 백필 스크립트에만 migrationHistory 기록 요구.**

---

## 작업 분배

### designer

- **불필요.** UI/화면/흐름 변경 없음.

### developer

- **구현 항목**:
  1. (#4) `menu_override_repository_impl.dart` W2 create data 맵에 `masterMenuItemId` 추가.
  2. (#3) `master_menu_item_remote_data_source.dart` 의 `cascadeDeleteOverrides`(no-op) 제거.
  3. (#3) `master_menu_item_repository_impl.dart` `deleteWithCascade` 를 단일 cascade 경로로 정리, `_menuOverrideRepository` non-nullable 전환(생성자 `required`).
  4. (#3) `brand_di_providers.dart:66~71` 생성자 인자 정합(이미 주입 중 — `?`/required 정합만).
  5. (백필, 사용자 승인 시) Admin SDK 일회성 스크립트 — `masterMenuItemId = doc.id` set(merge), `migrationHistory` 1건 + affected 기록. **실행은 사용자 게이트.**
- **재사용할 기존 구조**: `deleteAllForMaster` → `cascadeDeleteByMaster`(그대로). `MenuOverrideModel.toFirestore`(필드 정의 원천).
- **주의할 레이어 규칙**: Firebase 직접 사용은 data 레이어에서만. domain/presentation 시그니처 변경 금지(deleteWithCascade 인터페이스 불변). 색상/시크릿 무관.
- **빌드**: freezed/모델 변경 없으므로 `build_runner` 불필요. `flutter analyze` 로 non-null 전환 영향 확인.

### tester

- **주요 검증 기준**:
  - (#4) 점주 W2 create 로 생성된 오버라이드에 `masterMenuItemId` 가 저장되고 값 == 문서 id.
  - (#4) 점주 W2 create 가 Firestore Rules 를 **여전히 통과**(회귀) — `status:'approved'`, priceOverride null, 승인 메타 null.
  - (#3) 마스터 삭제 시 산하 매장의 **점주 생성 + 브랜드 생성 오버라이드 모두** cascade 삭제됨(점주 분기가 #4 덕에 이제 걸림).
  - (#3) cascade 가 `cascadeDeleteByMaster` 단일 경로를 타는지(no-op 미존재 확인).
  - (#3) `_menuOverrideRepository` 미주입 경로가 **조용히 통과하지 않음**(컴파일 차단 or throw).
- **반드시 확인할 예외 케이스**:
  - 브랜드 오버라이드 create/승인/반려/삭제 회귀(안 깨짐).
  - 점주 품절 토글 W2 upsert(create/update 양쪽) 회귀 — 특히 `disabledOptionGroupIds`/`disabledOptionItemIds` 보존(backlog #5 무회귀).
  - 가격 오버라이드 승인 플로우(`approveOverride`/`priceOverride`) 무회귀.
  - seedExclusionsForStore 무회귀(필드 이미 있음).
  - cascade 빈 결과/다수(>490) chunk 경계.
  - `countStoresUsingPriceOverride` 실행 시 복합 인덱스 에러 발생 여부 **보고**(비범위, 관찰).

---

## 완료 기준

- [ ] #4: 점주 W2 create 가 `masterMenuItemId` 저장, Rules 통과 회귀 확인
- [ ] #3: no-op 제거 + 단일 cascade 실동작 경로 + non-null(또는 loud-fail) 전환
- [ ] 마스터 삭제 시 점주·브랜드 오버라이드 모두 삭제됨을 테스트로 확인
- [ ] 백필 방침 사용자 확정(스크립트 작성/실행 또는 생략), 실행 시 migrationHistory 기록
- [ ] 브랜드 create/삭제·점주 W2 upsert·가격 승인 플로우 무회귀
- [ ] `implementation.md` 작성, `test_report.md` 작성, FAIL 없음(또는 후속 분리)
- [ ] designer 불필요 — design.md 생략 명시

---

## 사용자 확인 필요 결정사항

- **D-1 (백필)**: 기존 점주 오버라이드 `masterMenuItemId` 백필 — (a)스크립트+실행게이트(권고) / (b)생략 / (c)수동. 영향 심각도 낮음(테스트 기간). → **사용자 선택.**
- **D-2 (의존성)**: `_menuOverrideRepository` non-nullable 전환(권고) vs nullable 유지+throw. 둘 다 "조용한 no-op" 은 제거. → 기본 권고 non-null, 이견 없으면 진행.

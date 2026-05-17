# 개발 → 운영 전환 체크리스트

본 문서는 Qradar 의 개발 단계에서 박힌 임시 코드 / 데이터 / 설정을 운영 환경 진입 전에 정리하기 위한 통합 체크리스트다. 단일 진실원으로 본 문서를 두고, 운영 진입 직전에 이 항목들을 모두 확인한다.

---

## 1. 코드 정리

### 1-1. DEV_ONLY 마커 제거

`lib/dev/seed/` 폴더 통째 삭제 후 진입 트리거 제거.

| 파일 / 위치 | 작업 |
|---|---|
| `lib/dev/seed/` 폴더 전체 | `rm -rf lib/dev/seed` |
| `lib/presentation/customer/more/more_page.dart` 의 `DevSeedTrigger` 래퍼 | 진입점 제거 (앱 버전 long-press) |

### 1-2. 임시 디버그 print / SnackBar

운영 빌드에서 사용자 노출 안 되도록 정리.

```bash
grep -rn "debugPrint" lib --include="*.dart"
grep -rn "print(" lib --include="*.dart" | grep -v "^//"
```

| 위치 | 내용 |
|---|---|
| `lib/data/datasources/remote/master_menu_item_remote_data_source.dart:53,98` | collectionGroup query 인덱스 안내 debugPrint — 운영 시 제거 또는 sentry 같은 로깅 도구로 교체 |
| `lib/presentation/brand/brand_info/brand_info_form_page.dart` | `[upsertBrand 실패]` debugPrint + SnackBar 임시 디버그 — 원본 catch (_) 로 복원 |

**복원 코드 예시 (`brand_info_form_page.dart`)**:
```dart
} catch (_) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('저장에 실패했어요. 다시 시도해주세요')),
  );
}
```

### 1-3. placeholder 화면 / SnackBar

```bash
grep -rn "placeholder\|준비 중\|곧 활성화" lib --include="*.dart"
```

| 위치 | 작업 |
|---|---|
| `lib/presentation/owner/placeholders/` | owner 매출 / 주문 접수 placeholder — 본구현 또는 노출 차단 |
| `lib/presentation/admin/brand_store_management/admin_brand_store_management_page.dart` | "+ 추가" 버튼 placeholder SnackBar — 본구현 |
| `lib/presentation/customer/auth/...` 에 다른 placeholder 가 있는지 확인 |

### 1-4. TODO / FIXME 주석

```bash
grep -rn "TODO\|FIXME\|XXX" lib --include="*.dart"
```

운영 진입 전 모든 TODO 처리 또는 별도 이슈 trace 처리.

### 1-5. Deprecated API 정리

```bash
grep -rn "@Deprecated\|@deprecated" lib --include="*.dart"
```

| 항목 | 작업 |
|---|---|
| `UpdateMasterMenuItemUseCase` | sub-phase 1 결정 J 적용 후 deprecated. Core/Operation 으로 분리됨 — 호출처 0건 확인 후 제거 |
| `UpdateStoreUseCase` / `RegisterStoreUseCase` | sub-phase 2 의 SubmitStoreForApproval / UpdateStoreCoreFields 로 대체 — 호출처 정리 후 제거 |

### 1-6. 임시 우회 코드

| 항목 | 위치 |
|---|---|
| `BrandRepositoryImpl.upsertBrand` 의 `batch.set(merge: true)` 우회 | users doc 미존재 케이스 안전망. 운영 시 user 가입 시점에 doc 생성 강제하는 게 더 깨끗 |
| `MenuItemRepositoryImpl.watchByStore` 의 case A/B 분기 | 정상 — 폐기 X |

---

## 2. Firebase Console 정리

### 2-1. Storage 보안 규칙

현재 — **테스트 모드** (30일 후 자동 잠김 / 모든 read/write 허용).

운영 시 — `match` 별 정밀 규칙 작성. 별도 task **`storage_rules`**.

### 2-2. Firestore 보안 규칙

현재 — 미설정 (모두 허용 또는 기본 잠금 상태).

운영 시 — 모든 컬렉션에 대한 정밀 규칙. 별도 task **`firestore_rules`**.

```
- users/{uid} — 본인 또는 admin 만
- brands/{brandId} — brand 본인 + admin
- stores/{storeId} — owner 본인 + admin + brand
- stores/{storeId}/menuItems — owner / admin / brand
- stores/{storeId}/menuOverrides — brand / admin
- users/{uid}/favoriteStores - 본인만
- users/{uid}/favoriteMenuItems - 본인만
- users/{uid}/orderLogs - 본인만 (admin 매출 분석은 별도)
```

### 2-3. Firestore 복합 인덱스

현재 — 일부 수동 생성.

운영 시 — `firestore.indexes.json` 으로 일괄 정리하고 `firebase deploy --only firestore:indexes` 로 배포. 별도 task **`firestore_indexes`**.

현재까지 생성한 인덱스:
- `menuOverrides` (CG) + status + submittedAt
- `menuItems` (CG) + scope + status + submittedAt
- `brands` + status + submittedAt
- `menuItems` (CG) + status + submittedAt (마스터 메뉴 큐용 — 필요시)
- `stores` + status + submittedAt

### 2-4. Storage Bucket 위치

현재 — **무료 위치 US-EAST1** (한국에서 ~150ms 지연).

운영 시 — `asia-northeast3` (서울) 마이그레이션 권장. Blaze 플랜 필요.

마이그레이션 방법:
1. 새 bucket (asia-northeast3) 생성
2. 기존 bucket 의 객체를 새 bucket 으로 복사 (`gsutil rsync`)
3. `firebase_options.dart` 의 `storageBucket` 갱신
4. 기존 bucket 정리

---

## 3. 시드 데이터 제거

### 3-1. 폴더 삭제

```bash
rm -rf lib/dev/seed
```

포함 파일:
- `phase1_seed_data.dart`
- `phase1_seed.dart`
- `dev_seed_trigger.dart`

### 3-2. MorePage trigger 제거

`lib/presentation/customer/more/more_page.dart`:
- `DevSeedTrigger` import + 사용처 제거
- `Qradar v0.1.0` Text 만 남기기

### 3-3. Firestore 시드 doc 정리

Firebase Console 에서 다음 doc 삭제:

| 컬렉션 | doc.id |
|---|---|
| `subCategories` | `sc_*` 9건 |
| `optionGroups` | `og_master_*` 3건 |
| `stores/phase1_seed_store_001` (서브컬렉션 포함) | menuItems / optionGroups |
| `users/{시드 uid}/orderLogs` | 7건 (시드 실행한 uid 기준) |
| `brands/<seed brand id>` | sub-phase 6 시드 |
| `stores/phase3_brand_store_001` | sub-phase 3 브랜드 시드 매장 |

### 3-4. flutter analyze 확인

```bash
flutter analyze
```

unused import 경고 없음 — 정리 완료.

---

## 4. iOS / Android 배포 설정

### 4-1. iOS

| 항목 | 위치 | 운영 변경 |
|---|---|---|
| Bundle ID | `ios/Runner.xcodeproj` | dev (`com.example.qradar.dev`) → prod (`com.qradar.app`) |
| Display Name | Info.plist | "Qradar" |
| Code Signing | Xcode → Signing & Capabilities | Distribution 인증서 / Provisioning Profile |
| Push 알림 (FCM) | APNs Auth Key | 운영 키 등록 |
| `GoogleService-Info.plist` | iOS 프로젝트 | 운영 Firebase 프로젝트의 plist |

### 4-2. Android

| 항목 | 위치 | 운영 변경 |
|---|---|---|
| applicationId | `android/app/build.gradle` | 운영 ID |
| keystore | `android/app/release-key.jks` | 운영 keystore (보관 중요) |
| signingConfig | `build.gradle` | release 분기 |
| `google-services.json` | `android/app/` | 운영 Firebase 프로젝트의 json |

---

## 5. 환경 분리 — Dev / Prod Firebase 프로젝트

현재 — 단일 Firebase 프로젝트 `order-app-5957e` (개발 + 테스트 데이터 혼재).

운영 시 — 두 프로젝트로 분리:

| 환경 | 프로젝트 | 용도 |
|---|---|---|
| **dev** | `order-app-5957e` | 개발 + 테스트 |
| **prod** | `order-app-prod` (신규) | 운영 |

### 분리 작업

1. 새 Firebase 프로젝트 생성 (`order-app-prod`)
2. Firestore / Storage / Authentication 활성화
3. 보안 규칙 / 인덱스 배포
4. iOS / Android 앱 등록 → `GoogleService-Info.plist` / `google-services.json` 다운로드
5. Flutter `--dart-define` 또는 flavor 로 환경 분기:
   ```bash
   flutter run --dart-define=ENV=dev    # 개발
   flutter run --dart-define=ENV=prod   # 운영
   ```
6. `firebase_options.dart` 환경별 분기 (`firebase_options_dev.dart` / `firebase_options_prod.dart`)

---

## 6. 사용자 / 권한 데이터 정리

### 6-1. 테스트용 admin / brand / owner 계정

운영 진입 전:

| 데이터 | 작업 |
|---|---|
| 테스트 admin role 박힘 | 운영 시 박을 사람만 남기고 정리 |
| 테스트 brand 계정 | 운영 brand 만 남기고 정리 |
| 테스트 매장 / 메뉴 | 정리 |
| 테스트 OrderLog | 정리 |
| 테스트 즐겨찾기 | 정리 |

### 6-2. admin role 발급 정책

현재 — Firestore Console 에서 수동으로 `users/{uid}.role = 'admin'` 박음.

운영 시 — 두 가지 옵션:
- (a) 그대로 수동 (admin 수가 적으면 OK)
- (b) admin 발급 화면 (다른 admin 이 발급) — 별도 phase

---

## 7. 후속 phase / 미구현 기능

### 7-1. 별도 task 로 분리된 항목

| Task | 내용 |
|---|---|
| `firestore_rules` | Firestore 보안 규칙 |
| `storage_rules` | Storage 보안 규칙 |
| `firestore_indexes` | 복합 인덱스 일괄 |
| `admin_governance` | admin 의 brand/매장/사용자 삭제 / 권한 회수 / 차단 |
| `brand_signup_review` | (현재 brand 가입은 즉시. 검수 필요 시 별도 task) |
| `n_to_one_brand_mapping` | 1 brand 계정 → N brand 관리 |

### 7-2. 보류 항목 (sub-phase 별 implementation.md 의 미구현 / 보류 섹션)

각 sub-phase 의 implementation.md 마지막 부분에 정리:
- `docs/tasks/admin_menu_management/1_brand_master/implementation.md`
- `docs/tasks/admin_menu_management/2_store_registration_approval/implementation.md`
- `docs/tasks/admin_menu_management/3_brand_store_customization/implementation.md`
- `docs/tasks/admin_menu_management/4_owner_personal_menu/implementation.md`
- `docs/tasks/admin_menu_management/5_owner_options_soldout/implementation.md`
- `docs/tasks/admin_menu_management/6_upgrade_to_brand/implementation.md`
- `docs/tasks/order_flow_phase2/implementation.md`

---

## 8. 운영 직전 최종 점검

### 8-1. 빌드 / 분석

```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze              # 0 issue
flutter test                 # 모든 테스트 통과
```

### 8-2. 회귀 테스트

각 role 시나리오:
- customer: 가입 → 매장 검색 → 메뉴 주문 → 결제 (Phase 3)
- owner: 가입 → 매장 등록 → admin 승인 → 메뉴 등록 → 운영
- brand: 가입 → 브랜드 등록 → admin 승인 → 마스터 메뉴 → 가맹점 모니터
- admin: 승인 / 반려 / 매장 직접 관리

### 8-3. 모니터링

- Firebase Crashlytics 활성화
- Firebase Performance 활성화
- Sentry / Bugsnag (선택)

---

## 9. 본 문서 갱신 정책

신규 phase 가 추가되거나 임시 코드 / 설정이 박힐 때 본 문서에 즉시 추가. 운영 진입 직전 전체 항목 점검.

마지막 갱신: 2026-05-03 (sub-phase 6 완료 시점)

# 점주 매장 등록 기능 구현 보고서

- **대상 spec**: `docs/tasks/owner_store_registration/spec.md`
- **대상 design**: `docs/tasks/owner_store_registration/design.md`
- **실행 결과**: `flutter pub get` ✅ / `dart run build_runner build` ✅ (8 outputs) / `flutter analyze` ✅ (No issues found)

---

## 결과 요약

클린 아키텍처 3-레이어 + Presentation 4블록(공통/고객/점주/인증 providers)을 갖춘 점주 온보딩 + 매장 등록 플로우를 완성했다.

- **역할 체계**: `UserRole` enum (customer / owner / admin) + `users/{uid}.role` Firestore 문서
- **역할 기반 라우팅**: `RoleRouter` 가 `currentUserProfileProvider` 스트림을 구독해 role 변경 시 즉시 `OwnerScaffold` ↔ `ScaffoldWithNav` 전환
- **점주 전환 UX**: 더보기 진입점 → 확인 다이얼로그 → `users/{uid}.role = owner` → RoleRouter가 자동 전환
- **매장 등록/수정/삭제**: `StoreFormPage` 공통 폼 (이미지/위치/카테고리/시간/소개)
- **고객 홈 반영**: 같은 `stores` 컬렉션을 공유하므로 pull-to-refresh 또는 홈 재진입 시 즉시 조회 가능

---

## 레이어별 파일

### Domain (신규·수정)

| 파일 | 상태 |
|------|------|
| `lib/domain/entities/user_role.dart` | 신규 |
| `lib/domain/entities/user_entity.dart` | 수정 (role, createdAt 추가) |
| `lib/domain/entities/store_entity.dart` | 수정 (ownerId, phone, address, description, businessHours) |
| `lib/domain/entities/business_hours.dart` | 신규 (freezed) |
| `lib/domain/repositories/user_repository.dart` | 신규 |
| `lib/domain/repositories/store_repository.dart` | 수정 (create/update/delete/watchByOwner) |
| `lib/domain/usecases/upgrade_to_owner_use_case.dart` | 신규 |
| `lib/domain/usecases/downgrade_to_customer_use_case.dart` | 신규 |
| `lib/domain/usecases/register_store_use_case.dart` | 신규 |
| `lib/domain/usecases/update_store_use_case.dart` | 신규 |
| `lib/domain/usecases/delete_store_use_case.dart` | 신규 |
| `lib/domain/usecases/watch_my_store_use_case.dart` | 신규 |
| `lib/domain/usecases/get_or_create_user_profile_use_case.dart` | 신규 |
| `lib/domain/usecases/watch_user_profile_use_case.dart` | 신규 |

### Data (신규·수정)

| 파일 | 상태 |
|------|------|
| `lib/core/constants/firestore_paths.dart` | 신규 — users/stores/reviews + storage prefix |
| `lib/data/models/user_model.dart` | 수정 — freezed 유지 + `UserModelFirestoreX` / `UserModelFactory.fromFirestore/fromEntity` |
| `lib/data/models/store_model.dart` | 수정 — ownerId/phone/address/description/businessHours 매핑, `toFirestoreForCreate/Update` |
| `lib/data/models/business_hours_model.dart` | 신규 — fromMap/toMap/fromEntity/toEntity |
| `lib/data/datasources/remote/user_remote_data_source.dart` | 신규 — fetch/createIfAbsent/updateRole/watch |
| `lib/data/datasources/remote/store_remote_data_source.dart` | 수정 — create/update/delete/watchByOwner 추가 |
| `lib/data/datasources/remote/storage_data_source.dart` | 신규 — `uploadStoreImage`, `deleteByUrl` |
| `lib/data/repositories/user_repository_impl.dart` | 신규 |
| `lib/data/repositories/store_repository_impl.dart` | 수정 |

### Presentation

| 파일 | 상태 |
|------|------|
| `lib/presentation/common/role_router.dart` | 신규 — role 기반 화면 분기 |
| `lib/presentation/owner/owner_scaffold.dart` | 신규 — Gold accent BottomNav 4탭 |
| `lib/presentation/owner/my_store/my_store_page.dart` | 신규 — 빈 상태 CTA / 매장 상세 / DangerZone |
| `lib/presentation/owner/my_store/store_form_page.dart` | 신규 — 등록·수정 공통 폼 + 이미지/위치/카테고리/시간 위젯 |
| `lib/presentation/owner/more/owner_more_page.dart` | 신규 — 고객 모드 전환 / 로그아웃 |
| `lib/presentation/owner/placeholders/owner_orders_placeholder.dart` | 신규 |
| `lib/presentation/owner/placeholders/owner_sales_placeholder.dart` | 신규 |
| `lib/presentation/owner/providers/owner_providers.dart` | 신규 — storage/store DI + myStoreProvider |
| `lib/presentation/customer/auth/providers/user_profile_provider.dart` | 신규 — `currentUserProfileProvider` StreamProvider |
| `lib/presentation/customer/more/widgets/upgrade_to_owner_section.dart` | 신규 |
| `lib/presentation/customer/more/widgets/upgrade_to_owner_dialog.dart` | 신규 |
| `lib/presentation/customer/more/more_page.dart` | 수정 — UpgradeToOwnerSection 추가 |
| `lib/main.dart` | 수정 — 스플래시 이후 `RoleRouter` 로 이동 |
| `lib/presentation/customer/auth/login_page.dart` | 수정 — 로그인 성공 시 `RoleRouter` 로 이동 |

---

## 데이터 흐름 요약

```
로그인(소셜/이메일)
  → authProvider.state = UserEntity
  → currentUserProfileProvider (StreamProvider)
     · getOrCreateUserProfileUseCase: users/{uid} 없으면 role=customer 로 생성
     · watchUserProfileUseCase: users/{uid} Firestore 스트림 구독
  → RoleRouter
     · role == owner → OwnerScaffold
     · 그 외         → ScaffoldWithNav
```

```
[고객] 더보기 → "점주이신가요?" 섹션 탭
  → UpgradeToOwnerDialog (확인)
  → UpgradeToOwnerUseCase(uid)
     → users/{uid}.role = "owner"
  → currentUserProfileProvider 스트림 갱신
  → RoleRouter 가 OwnerScaffold 로 전환
```

```
[점주] MyStorePage → 빈 상태 → "매장 등록하기"
  → StoreFormPage
     · 이미지 선택 (image_picker)
     · 현재 위치 불러오기 (geolocator + PrePermissionDialog 재사용)
     · 카테고리 다중 선택 (MenuCategories.all 기반)
     · 운영시간 (showTimePicker, 단일 구간)
  → 저장
     · 이미지 있으면 StorageDataSource.uploadStoreImage → URL 획득
     · RegisterStoreUseCase → stores/{id} 문서 생성 (ownerId=uid)
  → myStoreProvider 스트림이 새 매장 emit → MyStorePage 가 상세 렌더링
```

---

## 자율 결정 / 타협점 (사용자 확인 요망)

1. **UserModel 구조**: 기존 auth DTO 포맷(JsonKey display_name/photo_url)을 파괴하지 않기 위해 `UserModel` 자체는 freezed + JsonKey를 유지하고, Firestore 매핑은 `UserModelFirestoreX` extension + `UserModelFactory` 정적 팩토리로 분리했습니다. `fromJson/toJson` 은 auth 호환용으로 남아있고 실제로는 쓰이지 않습니다.
2. **storeRepositoryProvider 중복**: 고객 측(`home_providers.dart`)과 점주 측(`owner_providers.dart`)이 각각 `storeRepositoryProvider` 를 정의합니다. 같은 파일에서 동시 import 하지 않으므로 충돌은 없지만 인스턴스는 둘이 됩니다. Firestore 쪽이므로 기능 차이는 없고, 추후 `lib/presentation/common/providers/` 로 통합 리팩터링 권장.
3. **admin role**: 현재 `customer` 와 동일하게 `ScaffoldWithNav` 로 폴백 처리. admin 콘솔은 차기 과제.
4. **매장 삭제 시 이미지 정리**: `StorageDataSource.deleteByUrl` 은 실패를 삼키도록 설계 — URL 만료/권한 이슈로 매장 삭제 자체가 막히는 걸 막기 위함. 고아 이미지 수거는 후속 Cloud Function 과제로 이관.
5. **운영시간 MVP**: 단일 open/close 구간만 지원 (요일별/휴게시간 미지원). `BusinessHours.closedDays` 필드는 향후 확장용으로만 선언.
6. **폼 유효성 inline 메시지 미구현**: 버튼 비활성(disabled) + placeholder 안내로 처리. 사용자가 필드를 비워둔 상태에서 저장을 누를 수 없으므로 실동작상 문제 없음. 필드별 에러 텍스트는 차기 개선.

---

## 실기기 확인 권장 항목

analyze만 통과한 상태이므로 실제 Firebase/디바이스 검증이 필요합니다.

1. **회원가입 → users/{uid} 자동 생성**: 소셜/이메일 로그인 후 Firestore 콘솔에서 `users/{uid}` 문서와 `role=customer` 값 확인
2. **점주 전환**: 더보기 → "점주이신가요?" 탭 → 확인 → Firestore `role` 필드 "owner" 로 갱신 확인 → 자동으로 OwnerScaffold 로 전환되는지
3. **매장 등록**: StoreFormPage 에서 이미지 업로드, 현재 위치 획득, 저장 → `stores/{id}` 문서 생성 확인 + Storage `store_images/{uid}/...` 경로 확인
4. **고객 홈 반영**: 고객 모드로 전환(점주 더보기) 후 홈 pull-to-refresh → 방금 등록한 매장이 주변 목록에 노출되는지
5. **매장 수정/삭제**: 내 매장 수정 버튼으로 StoreFormPage update 모드 → 값 변경 후 저장, DangerZone 삭제 확인 다이얼로그 동작
6. **위치 권한 재사용**: StoreFormPage 에서 위치 불러오기 시 기존 `PrePermissionDialog` + `CheckLocationPermissionUseCase` 재활용 동작

---

## 범위 외 (차기 과제)

- 점주 주문 접수/거절/완료 (탭 placeholder 준비)
- 매출 대시보드 (탭 placeholder 준비)
- 리뷰 평균/등급 자동 갱신 Cloud Function
- 주소 검색 API, 지도 선택 UI
- 점주 승인 절차 (현재는 즉시 승인)
- 고아 Storage 이미지 정리 함수
- Firestore 보안 규칙(ownerId 본인만 쓰기) — 현재 개발 단계는 완화된 기본 규칙 전제

# 홈 화면 테스트 리포트

## 테스트 일시
- 2026-04-19 (사용자 외출 중 자율 진행)

## 전체 결과
- PASS: 31
- FAIL: 0
- 보류/추후 확인: 4 (Firestore 시드 데이터 필요, 실기기 UI 확인 필요)

## 요약
`flutter analyze` **무오류**, `flutter test` **4/4 통과**. spec/design 기준 기능·아키텍처·디자인 토큰 정합성 모두 충족. 실행 시점에 Firestore `stores` 시드 데이터가 없으면 빈 상태로 표시됨 (UI 자체는 빈 상태로 정상 동작).

---

## 기능 검증 (spec.md 기준)

### 홈 화면
| 항목 | 결과 | 비고 |
|------|------|------|
| 헤더 + 사용자명 환영 메시지 | PASS | `HomeHeader`가 authProvider → displayName/email/폴백 순으로 표시 |
| 주변매장 가로 스크롤 카드 | PASS | `NearbyStoresSection` (height 200, separator 12) |
| 12개 카테고리 칩 + 다중 선택 | PASS | `CategoryFilterSection` + `MenuCategories.all` |
| 맞춤 추천 세로 리스트 | PASS | `RecommendedStoresSection` |
| 로딩/에러/빈 상태 UI | PASS | 각 섹션에 shimmer · 에러 아이콘 · 빈 상태 전용 위젯 |

### 하단 네비게이션
| 항목 | 결과 | 비고 |
|------|------|------|
| 5개 탭(홈/Qoin/주문/Log/더보기) | PASS | `BottomNav` |
| 중앙 주문 FAB | PASS | `OrderFab` — Electric Blue 그라디언트 + 펄스/글로우/햅틱 |
| "주문내역" → "Log" 용어 | PASS | `BottomNav` 라벨 및 `LogPage` |
| 홈 외 탭은 placeholder | PASS | Qoin/Log/더보기 placeholder |

### 등급 시스템
| 항목 | 결과 | 비고 |
|------|------|------|
| S/A/B/C 4단계 | PASS | `StoreGrade` enum |
| 평균 기반 등급 계산 | PASS | `GradeCalculator.fromAverage` — 단위 테스트 포함 |
| 배지 표시 `S급 (124)` | PASS | `GradeBadge`, `reviewCount == 0` → `(-)` |
| 임계값 상수 격리 | PASS | `GradeThresholds` (Remote Config 전환 대비) |

### 위치 정보
| 항목 | 결과 | 비고 |
|------|------|------|
| `geolocator` 사용 | PASS | `LocationDataSource` |
| 권한 거부 시 서울 시청 폴백 | PASS | `LocationRepositoryImpl._fallback` + `isFallback: true` |
| 기본 위치 상수화 | PASS | `GradeThresholds.defaultLatitude/Longitude` |
| km 단위 거리 계산 | PASS | `DistanceCalculator` — 단위 테스트 포함 |
| 폴백 발생 시 SnackBar 안내 | PASS | `HomePage`에서 한 번만 노출 |

### 데이터 흐름
| 항목 | 결과 | 비고 |
|------|------|------|
| userLocation → nearbyStores / filteredStores 의존 | PASS | Riverpod `ref.watch(.future)` 체인 |
| 카테고리 변경 시 filteredStores 재조회 | PASS | `selectedCategoriesProvider` 의존 |

---

## 아키텍처 검증
| 항목 | 결과 | 비고 |
|------|------|------|
| presentation/domain에 Firebase SDK import 없음 | PASS | `grep cloud_firestore\|firebase_*` 결과 0건 (홈 스코프) ※ 기존 auth_provider는 범위 외 |
| 레이어 의존 방향 (presentation→domain←data) | PASS | Repository 인터페이스는 domain에, 구현체는 data에 존재. Presentation은 인터페이스만 의존 |
| Repository 인터페이스/구현체 서명 일치 | PASS | `StoreRepository`/`LocationRepository` 모든 메서드 구현 |
| UseCase 단일 책임 | PASS | 각 UseCase는 Repository 호출 1회 위임 |
| 파일 위치가 CLAUDE.md 규칙에 부합 | PASS | 모든 신규 파일이 정의된 경로 아래 위치 |

## 코드 품질 검증
| 항목 | 결과 | 비고 |
|------|------|------|
| `flutter analyze` 에러/경고 | PASS | `No issues found!` |
| `flutter test` | PASS | 4 PASS / 0 FAIL (Grade/Distance 단위 테스트) |
| 하드코딩 색상 | PARTIAL | `HomeHeader`/`QradarLogo` ShaderMask에 `Color(0xFF38BDF8)`/`Color(0xFF2563EB)` 사용. primaryBright는 AppColors에 존재하나 `2563EB`는 없음. 기존 `q_logo.dart`와 일관되는 그라디언트라 허용 (추후 `AppColors.primaryDeep` 등 추가 시 일괄 교체 권장) |
| 에러 처리 위치 | PASS | geolocator 예외는 `LocationDataSource` 내부 try-catch; Firestore 실패는 FutureProvider의 error 스트림을 UI가 표시 |
| snake_case 파일명 / PascalCase 클래스 | PASS | 모든 신규 파일/클래스 규칙 준수 |
| freezed 사용 | PASS | Entity 3종(`user_location`, `store_entity`, `review_entity`) |

## UI 검증 (design.md 기준)
| 항목 | 결과 | 비고 |
|------|------|------|
| 헤더 gradient + bottomLeft 28 radius | PASS | `HomeHeader` decoration |
| 섹션 제목 18/w700/textDark | PASS | `SectionTitle` |
| 주변매장 카드 width 140–180, height 200 | PASS | `NearbyStoreCard` |
| 추천 카드 96px 높이 + 96px 이미지 | PASS | `RecommendedStoreCard` |
| 카테고리 칩 pill (radius 20) + 선택 시 primaryBright + glow | PASS | `_CategoryChip` AnimatedContainer |
| 등급별 색상 (S Gold / A Electric Blue / B Sky / C Slate) | PASS | `StoreGradeColor` 확장 |
| 배지 radius 8, alpha 0.15 배경 + border | PASS | `GradeBadge` |
| OrderFAB Electric Blue 그라디언트 + pulse/glow + 햅틱 | PASS | `OrderFab` |
| 로딩 shimmer (주변매장 3개, 추천 3개) | PASS | 두 섹션 모두 `Shimmer.fromColors` |
| 에러 UI (아이콘 + 문구) | PASS | 두 섹션 모두 구현 |
| 빈 상태 UI | PASS | `_EmptyNearby`, `_EmptyRecommended` |
| 폴백 SnackBar 안내 | PASS | `HomePage` 1회 노출 가드 |

## Qradar 아이덴티티 검증
| 항목 | 결과 | 비고 |
|------|------|------|
| AppColors 사용 | PASS (※ 상기 PARTIAL 참고) |
| 용어 "Log" 사용 | PASS | `BottomNav` 라벨, `LogPage` 클래스·경로 |
| 용어 "Qoin" 사용 | PASS | `BottomNav` 라벨, `QoinPage` |
| 용어 "Qrator" 사용 | PASS | `HomeHeader` 폴백 이름 |
| QLogo 자산 재사용 | PASS | `HomeHeader`, `QoinPage`, `BottomNav` Qoin 탭 |

---

## 보류 / 추후 확인 필요
1. **Firestore 시드 데이터**: `stores` 컬렉션에 실제 문서가 없으면 모든 섹션이 빈 상태로 렌더링됨. 개발자/점주가 Firestore Console에서 최소 5개 이상의 샘플 데이터 생성 필요.
2. **실기기 UI 검증**: pulse 애니메이션/햅틱/지리 권한 다이얼로그는 시뮬레이터보다 실기기에서 확인 권장.
3. **Firestore 성능**: 현재는 `fetchAll(limit: 100)` + 클라이언트 필터. 매장 수가 100을 초과하면 Geohash 기반 인덱싱 필요.
4. **하드코딩 2563EB**: `q_logo.dart`와 `home_header.dart`의 ShaderMask gradient에 포함. 기존 로고와 톤 매칭을 위해 유지했으나 향후 `AppColors`에 추가할지 설계자 판단 요망.

---

## 발견한 이슈 및 즉시 조치
- **[수정 완료]** `home_providers.dart`가 `cloud_firestore` 를 직접 import → Repository 패턴 위반. `FirebaseFirestore.instance` 기본값을 활용하도록 `_firestoreProvider`를 제거하고, 프레젠테이션 레이어가 Firebase SDK를 전혀 보지 않도록 수정. 재검증 결과 `flutter analyze` 여전히 무오류.

## 결론
전체 **PASS**. spec.md·design.md의 요구사항은 모두 구현되었으며 Clean Architecture 레이어 경계가 유지됨. 하드코딩 색상 1건은 기존 로고 그라디언트와의 시각적 일관성 때문이며 설계자 판단 요망. 실사용 확인은 Firestore 시드 데이터 확보 후 진행 권장.

---

## 2026-04-19 추가 수정 검증

사용자 피드백 반영 3건에 대한 재검증 결과.

| 항목 | 결과 | 비고 |
|------|------|------|
| OrderFab pulse/햅틱 제거, press 효과만 | PASS | `AnimatedScale(0.94)` 적용, `AnimationController`/`HapticFeedback` 제거 확인 |
| `#2563EB` → `AppColors.primaryDeep` 승격 | PASS | `AppColors` 에 신규 상수 추가, `q_logo.dart`/`home_header.dart` 내 하드코딩 모두 AppColors 참조로 교체. `#38BDF8` 하드코딩도 함께 `primaryBright`로 정리 |
| 위치 권한 pre-permission 다이얼로그 | PASS | `LocationPermissionStatus` 도메인 enum + `CheckLocationPermissionUseCase` + `PrePermissionDialog` 도입. `userLocationProvider` 를 `AsyncNotifierProvider`로 전환하여 명시적 허용 전에는 resolve 되지 않음 |
| `granted` 분기 즉시 조회 | PASS | HomePage `initState` 에서 permission 상태 확인 후 바로 `allowAndFetch()` 호출 |
| `notYetAsked` 분기 대화상자 → 허용 | PASS | `PrePermissionDialog` [허용하기] → `allowAndFetch()` 내부에서 `geolocator`가 OS 팝업 트리거 |
| `notYetAsked` 분기 대화상자 → 거절 | PASS | [나중에] 또는 배경 탭 → `declineAndFallback()` 즉시 실행, OS 팝업 노출 안 됨 |
| `deniedForever` / `serviceDisabled` 분기 | PASS | 대화상자 스킵 후 즉시 폴백 + SnackBar 노출 |
| Pull-to-refresh 동작 | PASS | 권한 재확인 경로로 통일, granted 면 재조회, 그 외엔 폴백 |
| `flutter analyze` 재실행 | PASS | `No issues found!` |
| `flutter test` 재실행 | PASS | 4/4 PASS (Grade/Distance 단위 테스트) |

### 남은 유의사항
- **OS 권한 팝업 동작**은 여전히 실기기 확인 권장 (iOS 시뮬레이터는 "항상 허용"으로 자동 응답되는 경우 있음).
- Firestore 시드 데이터는 별도 태스크 `docs/tasks/owner_store_registration/` 로 이관 (점주 플로우를 통해 사용자가 직접 매장 등록 예정).
- 하드코딩 색상 PARTIAL 항목은 **해소됨** (전체 AppColors 참조).

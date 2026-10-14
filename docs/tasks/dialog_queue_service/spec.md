# dialog_queue_service 기능 명세

## 개요

- 목적: 앱 전체의 `showDialog` 호출을 글로벌 큐를 통해 직렬화하여, 두 개 이상의 dialog 가 동시에 트리거될 때 발생하는 stacking / race condition / 사용자 인지 불가능 문제를 해소한다.
- 작업 유형: **신규 인프라(infrastructure) 추가 + 기존 호출부 wrapping**
- 영향 범위:
  - 화면: `ScaffoldWithNav`, `OwnerScaffold`, `HomePage` (초기 진입 직후 dialog 가 충돌하는 핫스팟). 그 외 적용 대상 dialog 호출부 (§영향 범위 §3 표 참조).
  - Domain: 없음 (UI 인프라이므로 도메인 엔티티 / UseCase / Repository 변경 없음)
  - Data: 없음 (Firestore / Cloud Function / Firebase SDK 변경 없음)
  - Presentation:
    - 신규 service: `lib/core/dialog/dialog_queue_service.dart` + Provider
    - 신규 helper: `enqueueDialog<T>(...)` API
    - 기존 dialog 호출부 (37곳) 중 race 가능성 있는 곳 wrapping
  - 공통 컴포넌트: 신규 `core/dialog/` 모듈
  - 라우팅: 변경 없음. 단 `Navigator` 의 `rootNavigatorKey` 또는 `BuildContext` 처리 방식 확인 필요 (§레이어 설계 §C-1)
  - 권한 / 환경 설정: 없음
  - 데이터 소유권 (`docs/processes/data_ownership.md`): **영향 없음**. Firestore 컬렉션 / Security Rules / Cloud Function 권한 매트릭스 변경 없음. dialog queue 는 클라이언트 presentation-layer 전용 인프라이며, 데이터 읽기 / 쓰기 권한 흐름과 무관하다.
  - 역할 흐름 (`docs/processes/role_flows.md`): **영향 없음**. customer / owner / brand / admin 모든 역할의 진입점 / 가능 액션은 변경되지 않는다. 단 customer / owner 의 첫 진입 시 dialog 노출 순서가 명확해진다(UX 안정성 개선).
  - 엔티티 lifecycle (`docs/processes/entity_lifecycle.md`): **영향 없음**. 어떤 엔티티의 status 전이도 추가 / 변경되지 않는다.
- 비범위:
  - 기존 dialog 의 UI / 카피 / barrier / button 동작 변경 (그대로 유지)
  - `showModalBottomSheet`, `SnackBar`, `Banner`, `Toast`, 인라인 overlay 직렬화 (별도 task 후보)
  - `Navigator.push` 로 띄우는 full-screen 화면 직렬화 (별도 task 후보)
  - 동시 진행 중인 백그라운드 async 의 cancellation (큐 대기 중 widget unmount 만 처리)
  - dev tool, debug overlay 류 dialog (`lib/dev/seed/dev_seed_trigger.dart`) 직렬화 — opt-in 권장 (사용자 확인)

---

## 현재 상태 (race condition 재현)

### 호출 지점 1 — `ScaffoldWithNav._checkAndRequestNotificationPermission`

`lib/presentation/common/scaffold_with_nav.dart:43-91`:

```dart
@override
void initState() {
  super.initState();
  // 빌드 사이클 방해 없이 첫 프레임 이후에 권한 체크 (OwnerScaffold 동일 패턴)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _checkAndRequestNotificationPermission();
  });
}

Future<void> _checkAndRequestNotificationPermission() async {
  final authState = ref.read(authProvider);
  final uid = authState.asData?.value?.uid;
  if (uid == null) return;

  // notificationPermissionPrompted 플래그 조회
  final prompted = await ref
      .read(userRepositoryProvider)
      .getNotificationPermissionPrompted(uid);
  if (prompted) return; // 이미 노출됨 → 재노출 안 함

  if (!mounted) return;

  // 다이얼로그 노출
  final result = await showNotificationPermissionDialog(
    context,
    audience: NotificationDialogAudience.customer,
  );
  // ...
}
```

플래그 조회를 위한 **Firestore read 가 비동기 ~100-500ms** 소요.

### 호출 지점 2 — `HomePage._resolveLocationPermission`

`lib/presentation/customer/home/home_page.dart:27-58`:

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || _permissionFlowStarted) return;
    _permissionFlowStarted = true;
    _resolveLocationPermission();
  });
}

Future<void> _resolveLocationPermission() async {
  final notifier = ref.read(userLocationProvider.notifier);
  final status = await ref.read(checkLocationPermissionUseCaseProvider)();
  if (!mounted) return;

  switch (status) {
    case LocationPermissionStatus.granted:
      await notifier.allowAndFetch();
    case LocationPermissionStatus.deniedForever:
    case LocationPermissionStatus.serviceDisabled:
      notifier.declineAndFallback();
    case LocationPermissionStatus.notYetAsked:
      final agreed = await PrePermissionDialog.show(context);
      // ...
  }
}
```

OS-level permission status check 는 **~10-100ms**.

### race condition

`ScaffoldWithNav` 는 부모, `HomePage` 는 자식. 두 `initState` 의 `addPostFrameCallback` 이 거의 동시에 firing.

- Firestore read (~100-500ms) > OS permission check (~10-100ms)
- → 일반적으로 `PrePermissionDialog` 가 먼저 push
- → 그 위에 `NotificationPermissionDialog` 가 stack push
- → Flutter 의 modal route stacking 으로 두 dialog 가 비결정적으로 겹침 + 사용자가 둘 다 표시되는 흐름을 인지하지 못함

사용자 관찰 기록:
- `notificationPermissionPrompted = false` 일 때 → 위치 dialog 만 보임 (notification dialog 가 그 뒤에 가려짐 추정)
- `notificationPermissionPrompted` 필드 삭제 시 → 알림 dialog 만 보임

`OwnerScaffold` 의 동일 패턴 (`lib/presentation/owner/owner_scaffold.dart:37-84`) — 자식인 `MyStorePage` 가 dialog 를 띄울 가능성이 있으면 동일한 race 가 발생할 수 있음 (현재는 미발생).

---

## 요구사항

### 기능 요구사항

- [ ] **F-1** 신규 글로벌 `DialogQueueService` 를 `lib/core/dialog/` 에 도입한다.
- [ ] **F-2** `enqueueDialog<T>(...)` API 를 제공한다. 호출자는 `Future<T?>` 를 받으며, 큐가 비어 있고 다른 dialog 가 표시 중이 아니면 즉시 표시, 아니면 직전 dialog 완료까지 대기 후 표시.
- [ ] **F-3** 동시 표시되는 dialog 는 정확히 1개. 큐는 FIFO 기본 (결정 A — 사용자 확인).
- [ ] **F-4** 큐에서 대기 중인 widget 이 unmount 되면 `null` 반환하며 큐에서 제거 (결정 C — 사용자 확인).
- [ ] **F-5** 호출자는 기존 `showDialog<T>(...)` 와 동등한 시그니처 / 반환값을 받아야 한다 (drop-in replacement 가능).
- [ ] **F-6** `ScaffoldWithNav._checkAndRequestNotificationPermission` 의 `showNotificationPermissionDialog` 호출을 큐 경유로 wrapping.
- [ ] **F-7** `HomePage._resolveLocationPermission` 의 `PrePermissionDialog.show` 호출을 큐 경유로 wrapping.
- [ ] **F-8** `OwnerScaffold._checkAndRequestNotificationPermission` 도 동일하게 wrapping (회귀 방지).
- [ ] **F-9** 적용 범위 (결정 D — 사용자 확인): 전체 강제 vs opt-in 점진. 기본 권장은 **opt-in 점진** + race 위험 dialog 만 우선 적용.
- [ ] **F-10** 동일 dialog 중복 enqueue 방어 정책 (결정 B — 사용자 확인). 기본 권장은 **key 기반 dedup (옵션)**.

### UI 요구사항

- [ ] **U-1** 기존 dialog 의 시각적 모양 / 카피 / barrier color / button 동작 100% 그대로 유지.
- [ ] **U-2** 큐 대기 중에는 추가적인 spinner / overlay 표시 없음 (조용히 대기).

### 상태 요구사항

- [ ] 큐 길이 / 표시 중인 dialog 식별자 등은 디버그 로그 수준에서만 추적, 별도 UI 노출 없음.
- [ ] 에러 케이스 (§에러 처리 참조).

---

## 영향 범위 — 적용 대상 dialog 전수조사

`grep -rn "showDialog" lib` 결과 **37건** 발견. race 가능성 평가 + 적용 우선순위.

### 분류 범례

| 우선순위 | 의미 |
|---|---|
| **P0** | 본 task 의 동기인 race 의 직접 당사자. 반드시 wrapping. |
| **P1** | initState / addPostFrameCallback / 상태 stream 변화 등 비결정적 트리거를 가져 race 가능성 있음. wrapping 권장. |
| **P2** | 명시적 사용자 액션(버튼 탭) 으로 trigger. 동시 표시 가능성 낮음. opt-in 결정 시 점진 적용. |
| **P3** | dev / debug 도구. 일반 사용자 경로 아님. opt-in 권장. |

### 전체 목록 (37건)

| # | 파일 경로 | 라인 | 호출자 / 트리거 | dialog 설명 | race 평가 |
|---|---|---|---|---|---|
| 1 | `lib/presentation/common/notification/notification_permission_dialog.dart` | 19 | `showNotificationPermissionDialog` (helper) — `ScaffoldWithNav` / `OwnerScaffold` initState 에서 호출 | FCM 알림 권한 사전 안내 | **P0** — race 의 한 당사자 |
| 2 | `lib/presentation/customer/home/widgets/pre_permission_dialog.dart` | 13 | `PrePermissionDialog.show` (helper) — `HomePage._resolveLocationPermission` 에서 호출 | 위치 권한 사전 안내 | **P0** — race 의 한 당사자 |
| 3 | `lib/presentation/common/widgets/error_dialog.dart` | 14 | `showErrorDialog` (helper) — 임의의 비동기 흐름에서 에러 발생 시 호출 가능 | 공통 에러 안내 | **P1** — 비동기 에러는 동시 발생 가능 |
| 4 | `lib/presentation/common/favorite_login_required_dialog.dart` | 11 | `showFavoriteLoginRequiredDialog` (helper) — 즐겨찾기 탭 시 비로그인 상태 안내 | 로그인 유도 | **P2** — 사용자 액션 trigger |
| 5 | `lib/presentation/customer/cart/cart_page.dart` | 69 | 장바구니 비우기 버튼 | 비우기 확인 | **P2** |
| 6 | `lib/presentation/customer/cart/widgets/replace_cart_dialog.dart` | 11 | `showReplaceCartDialog` (helper) — 다른 매장 메뉴 담기 시 | 장바구니 교체 확인 | **P2** |
| 7 | `lib/presentation/customer/order/orders/order_detail_page.dart` | 77 | `_handleCancelOrder` 액션 | 주문 취소 확인 | **P2** |
| 8 | `lib/presentation/customer/more/widgets/upgrade_to_owner_dialog.dart` | 8 | `showUpgradeToOwnerDialog` (helper) — 더보기 섹션 버튼 | role 전환 확인 | **P2** |
| 9 | `lib/presentation/customer/more/widgets/upgrade_to_brand_dialog.dart` | 8 | `showUpgradeToBrandDialog` (helper) — 더보기 섹션 버튼 | role 전환 확인 | **P2** |
| 10 | `lib/presentation/owner/orders/widgets/owner_order_action_dialogs.dart` | 17 | `showRejectOrder` — 거절 버튼 | 거절 사유 | **P2** |
| 11 | `lib/presentation/owner/orders/widgets/owner_order_action_dialogs.dart` | 92 | `showAcceptOrder` — 접수 버튼 | 접수 확인 | **P2** |
| 12 | `lib/presentation/owner/orders/widgets/owner_order_action_dialogs.dart` | 141 | `showCompletePickup` — 픽업 완료 버튼 | 픽업 완료 확인 | **P2** |
| 13 | `lib/presentation/owner/orders/widgets/owner_order_action_dialogs.dart` | 192 | `showDenyRefund` — 환불 거절 버튼 | 거절 사유 | **P2** |
| 14 | `lib/presentation/owner/sub_categories/owner_store_sub_category_list_page.dart` | 346 | 삭제 버튼 | 삭제 확인 | **P2** |
| 15 | `lib/presentation/owner/store_menu/owner_store_menu_list_page.dart` | 597 | 삭제 버튼 | 삭제 확인 | **P2** |
| 16 | `lib/presentation/owner/my_store/store_form_page.dart` | 280 | 폼 제출 후 안내 | 등록 결과 안내 | **P2** |
| 17 | `lib/presentation/owner/my_store/my_store_page.dart` | 892 | 매장 삭제 버튼 | 삭제 확인 | **P2** |
| 18 | `lib/presentation/owner/option_groups/owner_store_option_group_list_page.dart` | 137 | 삭제 버튼 | 삭제 확인 | **P2** |
| 19 | `lib/presentation/owner/store_menu/owner_store_menu_detail_page.dart` | 219 | 삭제 버튼 | 삭제 확인 | **P2** |
| 20 | `lib/presentation/brand/brand_info/brand_info_form_page.dart` | 107 | 폼 제출 | 등록/수정 확인 | **P2** |
| 21 | `lib/presentation/brand/customization/store_only_menu/brand_store_only_menu_list_page.dart` | 247 | 삭제 버튼 | 삭제 확인 | **P2** |
| 22 | `lib/presentation/brand/sub_categories/brand_sub_category_list_page.dart` | 344 | 삭제 버튼 | 삭제 확인 | **P2** |
| 23 | `lib/presentation/brand/master_menu/master_menu_list_page.dart` | 337 | 삭제 버튼 | 삭제 확인 | **P2** |
| 24 | `lib/presentation/brand/master_menu/master_menu_form_page.dart` | 291 | 폼 제출 / 미저장 종료 | 저장 확인 | **P2** |
| 25 | `lib/presentation/brand/master_menu/master_menu_detail_page.dart` | 191 | 삭제 버튼 | 삭제 확인 | **P2** |
| 26 | `lib/presentation/brand/option_groups/brand_option_group_list_page.dart` | 133 | 삭제 버튼 | 삭제 확인 | **P2** |
| 27 | `lib/presentation/admin/menu_categories/admin_main_category_list_page.dart` | 111 | 삭제 버튼 | 삭제 확인 | **P2** |
| 28 | `lib/presentation/admin/menu_categories/admin_main_category_list_page.dart` | 155 | 추가/수정 버튼 | 카테고리 폼 | **P2** |
| 29 | `lib/presentation/admin/approval/admin_master_menu_approval_detail_page.dart` | 47 | 반려 버튼 | 반려 사유 | **P2** |
| 30 | `lib/presentation/admin/approval/admin_brand_approval_detail_page.dart` | 56 | 반려 버튼 | 반려 사유 | **P2** |
| 31 | `lib/presentation/admin/approval/admin_menu_override_approval_detail_page.dart` | 49 | 반려 버튼 | 반려 사유 | **P2** |
| 32 | `lib/presentation/admin/approval/admin_pending_menus_by_brand_page.dart` | 83 | 반려 버튼 | 반려 사유 | **P2** |
| 33 | `lib/presentation/admin/approval/admin_brand_store_item_approval_detail_page.dart` | 50 | 반려 버튼 | 반려 사유 | **P2** |
| 34 | `lib/presentation/admin/approval/admin_store_approval_detail_page.dart` | 50 | 반려 버튼 | 반려 사유 | **P2** |
| 35 | `lib/presentation/common/widgets/reject_reason_dialog.dart` | 8 | 헬퍼 본체 — 위 admin 반려 dialog 가 호출 | 반려 사유 입력 (공통) | **P2** (helper 자체) |
| 36 | `lib/dev/seed/dev_seed_trigger.dart` | 27 | dev 메뉴 — 시드 데이터 트리거 | seed 실행 확인 | **P3** — dev only |
| 37 | (예약) — 향후 추가 | — | — | — | **opt-in 적용 가이드라인 준수** |

**참고**: `lib/presentation/common/widgets/reject_reason_dialog.dart` 의 본체는 위에 있으며, admin 반려 페이지 6곳이 이를 호출한다. 헬퍼 한 곳만 wrapping 해도 6곳이 동시 적용된다.

### 우선순위별 처리

- **P0 (2건, 반드시 wrapping)**: 1, 2 — race 직접 당사자.
- **P1 (1건, 강력 권장)**: 3 — 에러 dialog 는 비동기 에러 동시 발생 시 stacking 가능. wrapping.
- **P2 (33건, opt-in 결정 D 에 따름)**: 4~35 — 사용자 명시 액션 트리거. 결정 D 가 "전체 강제" 면 모두 적용, "점진" 이면 helper 단위로 순차 적용.
- **P3 (1건, 기본 제외)**: 36 — dev only.

**helper 단위 wrapping 권장**: `showErrorDialog`, `showFavoriteLoginRequiredDialog`, `showNotificationPermissionDialog`, `PrePermissionDialog.show`, `showReplaceCartDialog`, `showUpgradeToOwnerDialog`, `showUpgradeToBrandDialog`, `OwnerOrderActionDialogs.*`, `RejectReasonDialog.show` (있다면) 등 헬퍼 내부에서 `showDialog` → `enqueueDialog` 로 교체하면 한 번에 다수 호출처 적용 가능.

---

## 데이터 모델

본 task 는 도메인 / 데이터 모델 변경 없음. 메모리 상의 큐 자료구조만 정의.

### `DialogRequest<T>` (private)

| 필드 | 타입 | 설명 |
|---|---|---|
| `key` | `Object?` | dedup 식별자 (null 이면 dedup 적용 안 함) |
| `builder` | `WidgetBuilder` | dialog widget builder |
| `barrierDismissible` | `bool` | `showDialog` 의 동명 인자 |
| `barrierColor` | `Color?` | 동상 |
| `useRootNavigator` | `bool` | 동상 |
| `routeSettings` | `RouteSettings?` | 동상 |
| `contextRef` | `WeakReference<BuildContext>?` | 큐 대기 중 unmount 감지용 (결정 C) |
| `completer` | `Completer<T?>` | 호출자에게 결과 전달 |

자료구조는 `Queue<DialogRequest>` (`dart:collection`). FIFO 가 기본. (결정 A 가 priority 이면 `SplayTreeSet` 또는 별도 우선순위 분기 필요)

---

## 레이어 설계

### 위치 결정 — `lib/core/dialog/`

`docs/architecture.md` §9 의 `core/` 기준:
- `core/` 는 "여러 기능에서 공통으로 사용하는 요소" 를 둠.
- 본 service 는 customer / owner / brand / admin 모든 역할에서 호출. 특정 feature 에 종속되지 않음.
- Firebase / 외부 SDK 미사용. 순수 Flutter UI 인프라.
- 결론: `lib/core/dialog/` 가 적절. 기존 `core/` 의 `constants`, `theme`, `utils` 와 동일한 수평 모듈로 둠.

대안 검토:
- `lib/presentation/common/` → `presentation` 레이어이므로 가능하지만 service 성격이라 `common/widgets/` 와는 구분이 모호. `core/` 가 더 명확.
- `lib/data/` → ❌. 외부 데이터 소스 없음. data 레이어 의도와 맞지 않음.
- `lib/domain/` → ❌. UI 인프라이므로 도메인 순수성 위반.

### 신규 파일

```text
lib/core/dialog/
├── dialog_queue_service.dart   # 서비스 본체 + Provider
└── dialog_queue_provider.dart  # (선택) Provider 분리 시
```

권장: 단일 파일 `dialog_queue_service.dart` 에 service + provider 모두 둠 (`auth_provider.dart` 패턴과 유사).

### 공개 API (시그니처)

```dart
/// 글로벌 dialog 큐. 한 번에 하나의 dialog 만 표시한다.
class DialogQueueService {
  DialogQueueService();

  /// 큐에 dialog 를 enqueue 하고 결과를 받는다.
  ///
  /// - 큐가 비어 있고 표시 중인 dialog 가 없으면 즉시 표시.
  /// - 표시 중이면 직전 dialog 완료까지 대기 후 표시.
  /// - 대기 중에 [context] 가 unmount 되면 `null` 반환 + 큐에서 제거 (결정 C).
  /// - [key] 가 지정되고 동일 key 가 큐에 있으면 dedup (결정 B 가 dedup 일 때).
  ///
  /// 반환값은 dialog 가 닫힐 때 pop 된 값 (`showDialog<T>` 와 동일).
  Future<T?> enqueueDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    Object? key,
    bool barrierDismissible = true,
    Color? barrierColor,
    bool useRootNavigator = true,
    RouteSettings? routeSettings,
  });

  /// 현재 큐 길이 (디버그용).
  int get pendingCount;

  /// 현재 dialog 가 표시되고 있는가 (디버그용).
  bool get isShowing;
}

/// Riverpod provider.
final dialogQueueServiceProvider = Provider<DialogQueueService>((ref) {
  return DialogQueueService();
});
```

### 호출 예시 (기존 vs wrapping 후)

**기존**:
```dart
final result = await showNotificationPermissionDialog(
  context,
  audience: NotificationDialogAudience.customer,
);
```

**wrapping 후 (helper 내부 교체)**:
```dart
// notification_permission_dialog.dart 내부
Future<String?> showNotificationPermissionDialog(
  BuildContext context, {
  required NotificationDialogAudience audience,
  required DialogQueueService queue, // ref.read 로 주입
}) {
  return queue.enqueueDialog<String>(
    context: context,
    key: 'notification_permission_$audience',
    barrierDismissible: false,
    barrierColor: AppColors.textHeading.withValues(alpha: 0.6),
    builder: (ctx) => _NotificationPermissionDialog(audience: audience),
  );
}
```

또는 helper 시그니처를 유지하면서 호출부에서 ref 를 통해 큐를 사용:

```dart
// scaffold_with_nav.dart 내부
final result = await ref
    .read(dialogQueueServiceProvider)
    .enqueueDialog<String>(
      context: context,
      key: 'notification_permission_customer',
      barrierDismissible: false,
      barrierColor: AppColors.textHeading.withValues(alpha: 0.6),
      builder: (ctx) => _NotificationPermissionDialog(audience: NotificationDialogAudience.customer),
    );
```

**developer 결정**: 위 두 방식 중 하나로 일관되게 적용. spec 은 helper 내부 교체 방식을 권장 (변경 범위 최소화 + 호출부 코드 거의 그대로 유지).

### Clean Architecture 준수

- Firebase / 외부 SDK import 없음 → 절대 규칙 §2 통과.
- `Color(0x...)` 직접 하드코딩 없음 → 절대 규칙 §3 통과 (호출자가 `AppColors` 그대로 전달).
- `presentation → domain ← data` 의존 방향 위반 없음. `core/` 는 모든 레이어가 의존 가능한 공통 모듈.

### 결정사항 — A~D 비교 및 권장안

#### 결정 A — Queue 정책

| 옵션 | 장점 | 단점 |
|---|---|---|
| **FIFO** (선착순) | 구현 단순. 예측 가능. 사용자가 "먼저 트리거된 게 먼저 보임" 으로 직관적. | 긴급 dialog (예: 에러) 가 뒤늦게 표시될 수 있음. |
| **Priority** (우선순위) | 에러 / critical dialog 를 앞으로 당길 수 있음. | priority enum / 정책 정의 필요. dialog 별로 priority 결정 필요 → 운영 부담. 예측 가능성 저하. |

**architect 권장: FIFO**.

이유:
1. 현재 race 의 두 dialog (위치 / 알림) 는 둘 다 권한 안내로 critical 차이 없음 → FIFO 로 충분.
2. priority 도입은 모든 dialog 호출부에 분류 작업 필요 → scope 확장.
3. 향후 priority 가 필요하면 enqueue API 에 `priority` 인자 추가하는 식으로 확장 가능 (post-MVP).
4. 디버깅 / 재현이 명확함.

#### 결정 B — 중복 dialog 방어

| 옵션 | 장점 | 단점 |
|---|---|---|
| **항상 추가** | 구현 단순. 호출자가 책임. | 동일 dialog 가 두 번 표시될 수 있음 (사용자 혼란). |
| **key 기반 dedup (옵션)** | 호출자가 `key` 를 명시하면 중복 호출 자동 무시. 명시 안 하면 기존 동작. | API 약간 복잡. key 누락 시 의도치 않은 중복. |
| **builder 비교** | 자동 dedup. | builder 는 closure 라 동등성 비교 어려움 → 불완전. |

**architect 권장: key 기반 dedup (옵션)**.

이유:
1. P0 케이스 (위치 / 알림 권한) 는 둘 다 멱등 (한 번만 표시되어야 함) → key 로 보호하는 게 안전.
2. P2 케이스 (사용자 액션 trigger) 는 key 없이 호출 → 기존 동작 그대로.
3. 호출자가 책임 분리 가능 (멱등성이 중요한 dialog 만 key 명시).
4. helper 단위로 적용 시 helper 내부에서 일관된 key 발급 가능 (예: `'notification_permission_$audience'`).

#### 결정 C — Context 만료 처리

| 옵션 | 장점 | 단점 |
|---|---|---|
| **discard** (큐 대기 중 unmount → 큐에서 제거, `null` 반환) | 안전. 누가 호출했는지 안 살아있으면 표시 의미 없음. | 호출자가 결과 처리 시 `null` 가능성 항상 고려해야 (기존에도 `null` 가능). |
| **retry** (다른 active context 로 표시) | "어떻게든 표시" 보장. | rootNavigator 가 살아있는지 추적 복잡. UX 도 모호 (어디서 트리거됐는지 사용자 혼란). |
| **error** (예외 throw) | 명시적. | 호출자 코드가 대거 try/catch 필요 → race 의 본질 해결과 무관한 부담. |

**architect 권장: discard + null 반환**.

이유:
1. 기존 `showDialog<T>` 도 dismiss 시 `null` 반환이 정상 → 호출자가 이미 `null` 핸들링 함.
2. 큐 대기 중 화면이 사라졌으면 dialog 표시할 곳이 없음 → 표시해도 의미 없음.
3. 구현: `WeakReference<BuildContext>` + `(context as Element?).mounted` 체크 (Flutter 3.7+ `BuildContext.mounted` 사용 가능).
4. 큐 진행 시 만료된 request 는 skip + 다음 request 로 진행.

#### 결정 D — 적용 범위

| 옵션 | 장점 | 단점 |
|---|---|---|
| **전체 강제** (`showDialog` 사용을 `enqueueDialog` 로 lint 강제 + 37건 전부 wrapping) | 모든 dialog 의 race 자동 해소. 누락 없음. | 변경 범위 큼 (37건). dev seed 도 적용 — 의도와 다를 수 있음. lint rule 추가 작업. |
| **opt-in 점진** (P0 / P1 우선, P2 는 helper 단위로 점진) | 변경 범위 최소. 안전. | 향후 신규 dialog 추가 시 wrapping 누락 가능성. 가이드라인 문서화 필요. |
| **하이브리드** (helper 일괄 + page-level 은 선택) | 적용 효과 큰 helper (notification, pre-permission, error, reject_reason 등) 만 처리해도 다수 호출처 자동 적용. | 결정 필요한 helper 식별 작업. |

**architect 권장: 하이브리드 — P0 / P1 helper 우선 일괄 적용, P2 는 향후 race 발견 시 추가**.

이유:
1. P0 2건 + P1 1건 (notification, pre-permission, error) 의 helper 만 교체하면 본 task 의 race 해소 + 에러 dialog stacking 도 같이 방어.
2. P2 33건은 명시적 사용자 액션 trigger 라 동시 표시 가능성 매우 낮음.
3. `reject_reason_dialog.dart` 처럼 admin 6곳이 공통 helper 를 호출하는 경우 — 이 helper 를 wrapping 하면 6곳 동시 적용.
4. **향후 신규 dialog 가이드라인**: spec.md 작성 시 권한/시스템 trigger dialog 는 `enqueueDialog` 사용, 사용자 액션 trigger 도 안전을 위해 `enqueueDialog` 권장 (단 강제 아님). `developer_guide.md` 에 한 줄 추가 권장 (별도 task).

---

## 데이터 흐름

```text
호출자 (예: ScaffoldWithNav.initState)
  → ref.read(dialogQueueServiceProvider)
  → DialogQueueService.enqueueDialog<T>(context, builder, key, ...)
    → Queue<DialogRequest> 에 enqueue
    → 표시 중 dialog 가 없으면 즉시 _showNext() 호출
      → showDialog<T>(context, builder, ...)
      → 사용자 액션 → pop(result) 또는 barrier dismiss → null
    → 표시 중 dialog 가 있으면 대기 (Completer)
      → 직전 dialog dismiss → _showNext() 가 다음 request 진행
      → 다음 request 의 context.mounted 검사 → false 면 skip
  → completer.future 반환 → 호출자 await 종료
```

큐 진행 알고리즘 (의사코드):

```dart
void _processQueue() async {
  if (_isShowing) return;
  while (_queue.isNotEmpty) {
    final req = _queue.removeFirst();
    final ctx = req.contextRef?.target;
    if (ctx == null || !ctx.mounted) {
      req.completer.complete(null); // discard
      continue;
    }
    _isShowing = true;
    final result = await showDialog<dynamic>(
      context: ctx,
      builder: req.builder,
      barrierDismissible: req.barrierDismissible,
      barrierColor: req.barrierColor,
      useRootNavigator: req.useRootNavigator,
      routeSettings: req.routeSettings,
    );
    _isShowing = false;
    req.completer.complete(result);
  }
}
```

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| 큐 대기 중 widget unmount | discard + `null` 반환 (결정 C). 호출자가 기존에도 `null` 핸들링하므로 추가 부담 없음. |
| `showDialog` 자체에서 예외 throw (Navigator 비정상 등) | Completer 에 `completeError` 호출 → 호출자에게 그대로 propagate. service 자체는 다음 큐 진행 가능하도록 `_isShowing = false` 보장. |
| 동일 key dedup 시 | 신규 request 는 enqueue 하지 않고 기존 request 의 future 를 반환 (결정 B 가 dedup 일 때). 호출자 동작은 동일. |
| 큐 길이 비정상 증가 | 디버그 로그 경고 (>10건). 운영상 차단은 하지 않음 — 추후 별도 조치 검토. |
| Provider scope 외부 사용 | Provider 가 root scope 에 등록되어야 함. `ProviderScope` 외부 호출은 Riverpod 표준 에러로 처리. |

---

## 작업 분배

### designer

- UI 변경 필요 여부: **없음**.
- 디자인 산출물: **불필요**.
- 전달할 사항: 본 task 는 인프라이며 모든 dialog 의 시각적 모양 / 카피 / barrier 동작은 그대로 유지된다. 따라서 `/designer` 호출하지 않는다.

### developer

- 구현 항목:
  1. `lib/core/dialog/dialog_queue_service.dart` 신규 작성 — `DialogQueueService` 클래스 + `dialogQueueServiceProvider`.
  2. `lib/presentation/common/notification/notification_permission_dialog.dart` — `showNotificationPermissionDialog` 의 `showDialog` 호출을 `enqueueDialog` 로 교체. `WidgetRef` 또는 `DialogQueueService` 를 인자로 받도록 시그니처 조정 (호출부 2곳 동반 수정).
  3. `lib/presentation/customer/home/widgets/pre_permission_dialog.dart` — `PrePermissionDialog.show` 의 `showDialog` 호출을 `enqueueDialog` 로 교체. 호출부(`HomePage._resolveLocationPermission`) 1곳 동반 수정.
  4. `lib/presentation/common/scaffold_with_nav.dart` — `_checkAndRequestNotificationPermission` 의 호출 위 변경 적용.
  5. `lib/presentation/owner/owner_scaffold.dart` — 동일.
  6. `lib/presentation/customer/home/home_page.dart` — `_resolveLocationPermission` 의 호출 위 변경 적용.
  7. **P1**: `lib/presentation/common/widgets/error_dialog.dart` — `showErrorDialog` 의 `showDialog` 호출을 `enqueueDialog` 로 교체. key 사용 권장 (예: `'error_${errorCode}'` 또는 message hash).
  8. 결정 D 가 "전체 강제" 로 결정될 경우 P2 33건 전부 wrapping (helper 우선).
- 재사용할 기존 구조:
  - Riverpod `Provider` 패턴 (`auth_provider.dart` 등).
  - `BuildContext.mounted` (Flutter 3.7+).
  - `dart:collection` 의 `Queue`.
- 주의할 레이어 규칙:
  - `core/dialog/` 는 Firebase / 외부 SDK 절대 import 금지.
  - `presentation` 의 dialog 본체 widget 은 그대로 유지. 호출 메커니즘만 교체.
  - 색상은 `AppColors` 만 사용 — 본 task 는 색상 직접 사용 없음.
  - 호출부 시그니처 변경 시 `flutter analyze` 통과 확인.
- 결정 미확정 시: 사용자 결정 (§결정사항 §A-D) 확인 후 진행. architect 권장안 (FIFO + key 기반 dedup + discard + 하이브리드) 가 기본.

### tester

- 주요 검증 기준:
  - **T-1 (race 해소)**: customer 신규 로그인 → `ScaffoldWithNav` + `HomePage` 동시 진입 시, 두 dialog 가 동시 표시되지 않음. **순차 표시** 되고 한 번에 하나만 보임.
  - **T-2 (순서 결정성)**: FIFO 기준 — 먼저 enqueue 된 dialog 가 먼저 표시. (실제 순서는 두 `addPostFrameCallback` 의 timing 에 따라 결정되므로 어느 쪽이 먼저인지는 비결정적이지만, **둘 다 순차적으로 보임** 이 핵심.)
  - **T-3 (dismiss 후 다음)**: 첫 dialog 의 버튼 탭 또는 barrier dismiss → 즉시 두 번째 dialog 표시.
  - **T-4 (dedup, 결정 B 적용 시)**: 동일 key 로 두 번 enqueue → 한 번만 표시 + 두 호출자 모두 동일 결과 받음.
  - **T-5 (context 만료, 결정 C 적용 시)**: 큐 대기 중 Navigator pop / 로그아웃 등으로 unmount → 해당 request 는 skip + `null` 반환, 다음 request 정상 진행.
  - **T-6 (회귀 — 기존 dialog 단독 표시)**: 적용 대상 dialog 각각이 단독 호출 시 기존과 동일하게 동작 (UI / 결과값 모두).
  - **T-7 (P0 회귀)**: 위치 권한 dialog — `LocationPermissionStatus` 각 상태별 동작 그대로.
  - **T-8 (P0 회귀)**: 알림 권한 dialog — `notificationPermissionPrompted` 플래그 sticky 동작 그대로.
  - **T-9 (P1 회귀, error_dialog 적용 시)**: 에러 dialog 단독 호출 그대로 + 두 에러 동시 발생 시 순차 표시.
  - **T-10 (점주 회귀)**: `OwnerScaffold` 알림 권한 흐름 정상.
  - **T-11 (Phase 3c sub-phase 2 보류 항목 해소)**: `docs/tasks/order_flow_phase3c/2_customer_notification_and_ui/test_report.md` 의 L-10 (T12 — 고객 첫 로그인 → 권한 dialog 노출 → fcmToken 등록) 이 race condition 없이 명확히 노출됨.
- 반드시 확인할 예외 케이스:
  - **E-1**: `addPostFrameCallback` 두 번 firing 의 race — 빠른 디바이스 / 느린 디바이스 양쪽에서 둘 다 보이는지.
  - **E-2**: dialog 표시 중 앱 background → foreground 전환 후 큐 정상 진행.
  - **E-3**: 첫 dialog 의 OS permission popup (예: 알림 허용 후 OS dialog) 표시 중 다른 dialog 가 큐에 enqueue 되어도 정상 대기.
  - **E-4**: 큐 대기 중 hot reload / Provider 재생성 — 큐 상태 초기화 동작 검증.
- `flutter analyze` / `flutter test` 통과 확인.

---

## 완료 기준

- [ ] 요구사항 F-1 ~ F-10 이 모두 구현 또는 보류 사유 명시됨
- [ ] `design.md` 작성 **불필요** (UI 변경 없음 — designer 호출 생략)
- [ ] `implementation.md` 작성 완료
- [ ] `test_report.md` 작성 완료
- [ ] T-1 ~ T-11 모두 PASS 또는 라이브 검증 보류로 명시
- [ ] FAIL 항목이 없거나 후속 작업으로 분리됨
- [ ] 결정사항 A~D 가 사용자 확인을 거쳐 spec.md 의 "결정 확정" 섹션에 기록됨
- [ ] Phase 3c sub-phase 2 의 L-10 (T12) 보류 항목 해소 — race 없는 명확한 dialog 노출 확인

---

## 결정 확정 (사용자 응답 후 기록)

| 결정 | 사용자 확정 | 비고 |
|---|---|---|
| A — Queue 정책 | (대기 중) | architect 권장: FIFO |
| B — 중복 dialog 방어 | (대기 중) | architect 권장: key 기반 dedup (옵션) |
| C — Context 만료 처리 | (대기 중) | architect 권장: discard + null |
| D — 적용 범위 | (대기 중) | architect 권장: 하이브리드 (P0/P1 helper 일괄 + P2 점진) |

---

## 영향받는 다른 task

| task | 영향 | 처리 |
|---|---|---|
| `docs/tasks/order_flow_phase3c/2_customer_notification_and_ui` | L-10 / T12 라이브 검증 보류 항목의 dialog 순서 비결정성을 본 task 가 해소 | 본 task 완료 후 phase3c sub-phase 2 의 L-10 재검증 가능 |
| 향후 신규 dialog 추가 task | 모든 신규 dialog 가 race 가능성 평가 필요 | `developer_guide.md` 에 가이드 한 줄 추가 권장 (별도 task) |
| 향후 `showModalBottomSheet` / `SnackBar` 직렬화 task | 본 task 의 큐 패턴을 재사용 가능 | 별도 task 후보 |

# dialog_queue_service — implementation.md

## 구현 완료 항목

| # | 항목 | 상태 |
|---|---|---|
| F-1 | `DialogQueueService` 신규 도입 (`lib/core/dialog/`) | 완료 |
| F-2 | `enqueueDialog<T>(...)` API 제공 | 완료 |
| F-3 | FIFO 큐, 동시 표시 1개 보장 | 완료 |
| F-4 | context 만료 시 discard + null 반환 | 완료 |
| F-5 | `showDialog<T>` 와 동등한 반환값 (`Future<T?>`) | 완료 |
| F-6 | `ScaffoldWithNav._checkAndRequestNotificationPermission` wrapping | 완료 |
| F-7 | `HomePage._resolveLocationPermission` wrapping | 완료 |
| F-8 | `OwnerScaffold._checkAndRequestNotificationPermission` wrapping | 완료 |
| F-9 | 적용 범위: 하이브리드 (P0/P1 일괄 + P2 점진) | 완료 |
| F-10 | key 기반 dedup (opt-in) | 완료 |
| U-1 | 기존 dialog UI / 카피 / barrier / button 동작 100% 유지 | 완료 |
| U-2 | 큐 대기 중 추가 UI 없음 | 완료 |

---

## 신규 파일

| 파일 | 설명 |
|---|---|
| `lib/core/dialog/dialog_queue_service.dart` | `DialogQueueService` 클래스 + `dialogQueueServiceProvider` |

---

## 수정 파일

| 파일 | 변경 내용 |
|---|---|
| `lib/presentation/common/notification/notification_permission_dialog.dart` | `showNotificationPermissionDialog` 에 `queue` 파라미터 추가 (`required DialogQueueService queue`). 내부 `showDialog` → `queue.enqueueDialog` 교체. key: `'notification_permission_${audience.name}'` |
| `lib/presentation/customer/home/widgets/pre_permission_dialog.dart` | `PrePermissionDialog.show` 에 `queue` 파라미터 추가. 내부 `showDialog` → `queue.enqueueDialog` 교체. key: `'location_pre_permission'` |
| `lib/presentation/common/widgets/error_dialog.dart` | `showErrorDialog` 에 `queue` 파라미터 추가 (optional, `DialogQueueService?`). 전달 시 큐 경유, null 이면 기존 `showDialog` 직접 호출 (P2 점진 적용 호환). key: `'error_${message.hashCode}'` |
| `lib/presentation/common/scaffold_with_nav.dart` | `showNotificationPermissionDialog` 호출 시 `queue: ref.read(dialogQueueServiceProvider)` 전달 |
| `lib/presentation/owner/owner_scaffold.dart` | 동일 |
| `lib/presentation/customer/home/home_page.dart` | `PrePermissionDialog.show` 호출 시 `queue: ref.read(dialogQueueServiceProvider)` 전달 |

---

## enqueueDialog API signature

```dart
Future<T?> enqueueDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Object? key,                         // dedup 식별자 (opt-in)
  bool barrierDismissible = true,
  Color? barrierColor,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
})
```

### Provider

```dart
final dialogQueueServiceProvider = Provider<DialogQueueService>((ref) {
  return DialogQueueService();
});
```

### 사용 예시 (helper 내부 교체)

```dart
// notification_permission_dialog.dart
Future<String?> showNotificationPermissionDialog(
  BuildContext context, {
  required NotificationDialogAudience audience,
  required DialogQueueService queue,
}) {
  return queue.enqueueDialog<String>(
    context: context,
    key: 'notification_permission_${audience.name}',
    barrierDismissible: false,
    barrierColor: AppColors.textHeading.withValues(alpha: 0.6),
    builder: (ctx) => _NotificationPermissionDialog(audience: audience),
  );
}
```

```dart
// scaffold_with_nav.dart (호출부)
final result = await showNotificationPermissionDialog(
  context,
  audience: NotificationDialogAudience.customer,
  queue: ref.read(dialogQueueServiceProvider),
);
```

---

## 설계 결정 요약

| 결정 | 확정값 | 구현 방식 |
|---|---|---|
| A — Queue 정책 | FIFO | `dart:collection Queue` + `while (_queue.isNotEmpty)` 루프 |
| B — 중복 방어 | key 기반 dedup (opt-in) | `_queue.any((r) => r.key == key)` 검사 후 null 즉시 반환 |
| C — Context 만료 | discard + null 반환 | `request.context.mounted` 체크 → false 시 `completer.complete(null)` + continue |
| D — 적용 범위 | 하이브리드 | P0/P1 helper 3개 일괄 적용. P2 33건은 `queue` optional 로 점진 가능 |

---

## 아키텍처 준수 사항

- `lib/core/dialog/` 위치: Firebase / 외부 SDK import 없음. 순수 Flutter UI 인프라.
- `presentation → domain ← data` 의존 방향 위반 없음. `core/` 는 모든 레이어에서 의존 가능.
- `Color(0x...)` 하드코딩 없음 — 색상은 호출부에서 `AppColors` 토큰으로 전달.
- Riverpod `Provider` 패턴 사용 (hooks_riverpod 프로젝트 표준).

---

## 테스트 포인트

| 항목 | 검증 방법 |
|---|---|
| **T-1 race 해소** | customer 신규 로그인 → ScaffoldWithNav + HomePage 동시 진입 시 두 dialog 가 동시 표시되지 않고 순차 표시 |
| **T-2 FIFO 순서** | 먼저 enqueue 된 dialog 가 먼저 표시됨 (결정적 순서) |
| **T-3 dismiss 후 다음** | 첫 dialog 닫힘 → 즉시 두 번째 dialog 표시 |
| **T-4 key dedup** | 동일 key (`'location_pre_permission'`) 로 두 번 enqueue → 한 번만 표시 |
| **T-5 context 만료** | 큐 대기 중 해당 widget unmount → null 반환 + 다음 요청 정상 진행 |
| **T-6 단독 회귀** | notification / location / error dialog 각각 단독 호출 시 기존과 동일 동작 |
| **T-7 위치 dialog 회귀** | LocationPermissionStatus 각 상태별 동작 그대로 |
| **T-8 알림 dialog 회귀** | `notificationPermissionPrompted` 플래그 sticky 동작 그대로 |
| **T-9 error dialog** | 에러 dialog 단독 호출 정상 + queue 전달 시 순차 표시 |
| **T-10 점주 회귀** | OwnerScaffold 알림 권한 흐름 정상 |

---

## 미구현 / 보류 항목

| 항목 | 사유 |
|---|---|
| P2 33건 점진 wrapping | spec 결정 D 에 따라 이번 task 비범위. `showErrorDialog` 의 `queue` 파라미터가 optional 이므로 각 호출처에 `queue: ref.read(dialogQueueServiceProvider)` 를 추가하는 방식으로 점진 적용 가능. |
| P3 dev seed dialog | dev only. opt-in 보류. |
| `showModalBottomSheet` / `SnackBar` 직렬화 | 별도 task 후보. |
| `developer_guide.md` 가이드 한 줄 추가 | 별도 task 권장 (신규 dialog 작성 시 `enqueueDialog` 사용 가이드). |

---

## flutter analyze 결과

```
No issues found!
```

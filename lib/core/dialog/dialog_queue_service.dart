import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Internal request model (non-generic — type erased at queue boundary)
// ─────────────────────────────────────────────────────────────────────────────

class _DialogRequest {
  _DialogRequest({
    required this.context,
    required this.builder,
    required this.completer,
    this.key,
    this.barrierDismissible = true,
    this.barrierColor,
    this.useRootNavigator = true,
    this.routeSettings,
  });

  /// dedup 식별자. null 이면 dedup 적용 안 함.
  final Object? key;

  /// dialog 를 표시할 컨텍스트.
  final BuildContext context;

  final WidgetBuilder builder;
  final bool barrierDismissible;
  final Color? barrierColor;
  final bool useRootNavigator;
  final RouteSettings? routeSettings;

  /// 호출자에게 결과를 전달하는 completer (dynamic — 타입은 enqueueDialog 에서 복원).
  final Completer<dynamic> completer;
}

// ─────────────────────────────────────────────────────────────────────────────
// DialogQueueService
// ─────────────────────────────────────────────────────────────────────────────

/// 앱 전체 dialog 를 FIFO 순서로 직렬화하는 서비스.
///
/// 한 번에 하나의 dialog 만 표시하며, 대기 중인 요청은 이전 dialog 가
/// 닫힌 뒤 순차적으로 표시된다.
///
/// ### 사용 방법
/// ```dart
/// final queue = ref.read(dialogQueueServiceProvider);
/// final result = await queue.enqueueDialog<String>(
///   context: context,
///   key: 'my_dialog',
///   builder: (ctx) => MyDialog(),
/// );
/// ```
class DialogQueueService {
  DialogQueueService();

  final Queue<_DialogRequest> _queue = Queue();
  bool _isShowing = false;

  /// 현재 표시 중인 dialog 의 key (dedup 의 in-flight 검사용).
  Object? _showingKey;

  /// 큐 대기 중인 요청 수 (디버그용).
  int get pendingCount => _queue.length;

  /// 현재 dialog 가 표시 중인지 여부 (디버그용).
  bool get isShowing => _isShowing;

  /// dialog 를 큐에 추가하고 결과를 반환한다.
  ///
  /// - 큐가 비어 있고 표시 중인 dialog 가 없으면 즉시 표시.
  /// - 표시 중이면 직전 dialog 완료까지 대기 후 표시.
  /// - [key] 가 지정되고 동일 key 가 큐에 있으면 중복 enqueue 방지.
  ///   이 경우 `null` 을 즉시 반환한다.
  /// - 대기 중 [context] 가 unmount 되면 `null` 반환 후 다음 요청으로 진행.
  Future<T?> enqueueDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    Object? key,
    bool barrierDismissible = true,
    Color? barrierColor,
    bool useRootNavigator = true,
    RouteSettings? routeSettings,
  }) {
    // key 기반 dedup — 표시 중 + 대기 큐 모두 체크 (FAIL-1 fix)
    if (key != null) {
      final isShowingSameKey = _isShowing && _showingKey == key;
      final isInQueue = _queue.any((r) => r.key == key);
      if (isShowingSameKey || isInQueue) {
        debugPrint('[DialogQueue] dedup: key=$key 는 이미 큐에 있거나 표시 중.');
        return Future.value(null);
      }
    }

    final completer = Completer<dynamic>();
    final request = _DialogRequest(
      context: context,
      builder: builder,
      completer: completer,
      key: key,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
    );

    _queue.addLast(request);

    if (_queue.length > 10) {
      debugPrint(
        '[DialogQueue] 경고: 큐 길이가 ${_queue.length}건으로 비정상적으로 많습니다.',
      );
    }

    _processQueue();

    // dynamic → T? 로 타입 복원 (cast 없이 then 사용)
    return completer.future.then((v) => v as T?);
  }

  /// 큐를 순차 처리한다. 이미 처리 중이면 즉시 반환.
  void _processQueue() {
    if (_isShowing) return;
    _processNext();
  }

  Future<void> _processNext() async {
    while (_queue.isNotEmpty) {
      final request = _queue.removeFirst();

      // context 만료 검사 (결정 C: discard + null 반환)
      if (!request.context.mounted) {
        debugPrint(
          '[DialogQueue] context 만료: key=${request.key} 를 건너뜁니다.',
        );
        request.completer.complete(null);
        continue;
      }

      _isShowing = true;
      _showingKey = request.key;
      try {
        final result = await showDialog<dynamic>(
          context: request.context,
          builder: request.builder,
          barrierDismissible: request.barrierDismissible,
          barrierColor: request.barrierColor,
          useRootNavigator: request.useRootNavigator,
          routeSettings: request.routeSettings,
        );
        request.completer.complete(result);
      } catch (e, st) {
        debugPrint('[DialogQueue] showDialog 오류: $e\n$st');
        request.completer.completeError(e, st);
      } finally {
        _isShowing = false;
        _showingKey = null;
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

/// 앱 전역 [DialogQueueService] provider.
///
/// root [ProviderScope] 에 singleton 으로 등록된다.
final dialogQueueServiceProvider = Provider<DialogQueueService>((ref) {
  return DialogQueueService();
});

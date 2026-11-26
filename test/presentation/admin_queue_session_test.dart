import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/user_entity.dart';
import 'package:qradar/domain/repositories/master_menu_item_repository.dart';
import 'package:qradar/domain/usecases/watch_pending_master_menu_items_use_case.dart';
import 'package:qradar/presentation/admin/providers/admin_master_menu_approval_providers.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';

/// 승인 큐가 **로그인 세션에 묶여 있는지** 확인한다.
///
/// 고장 모양(2026-11-26 실기기): 로그아웃하면 Firestore 리스너가 permission-denied 로
/// 끝나는데, provider 가 autoDispose 가 아니라 그 죽은 스트림을 계속 들고 있었다.
/// 재로그인해도 다시 구독하지 않아 승인 큐가 영원히 "없어요" 로 보였다.
///
/// 여기서는 Firestore 대신 **구독 횟수를 세는 레포지토리**로 같은 조건을 만든다.
/// uid 가 바뀌었는데 구독이 한 번뿐이면 그때의 고장이 그대로 돌아온 것이다.
class _CountingRepo implements MasterMenuItemRepository {
  int subscriptions = 0;

  @override
  Stream<List<MenuItemEntity>> watchPendingForAdmin() {
    subscriptions++;
    // 로그아웃 뒤 리스너가 죽는 상황까지 흉내 낼 필요는 없다 —
    // 확인하려는 건 "새 세션에서 다시 구독하는가" 하나다.
    return Stream<List<MenuItemEntity>>.value(const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} 은 이 테스트가 쓰지 않는다');
}

/// uid 를 밖에서 바꿀 수 있는 auth. 로그아웃은 `null`.
class _SwitchableAuth extends AuthNotifier {
  static String? uid = 'admin1';

  @override
  Future<UserEntity?> build() async =>
      uid == null ? null : UserEntity(uid: uid!, provider: 'email');
}

void main() {
  late _CountingRepo repo;
  late ProviderContainer container;

  setUp(() {
    repo = _CountingRepo();
    _SwitchableAuth.uid = 'admin1';
    container = ProviderContainer(overrides: [
      authProvider.overrideWith(_SwitchableAuth.new),
      watchPendingMasterMenuItemsUseCaseProvider
          .overrideWithValue(WatchPendingMasterMenuItemsUseCase(repo)),
    ]);
    addTearDown(container.dispose);
  });

  /// 승인 큐를 한 번 "열어 본다" — 구독이 생길 때까지 기다린다.
  ///
  /// 세션을 먼저 해소한 뒤에 연다. 실제 앱도 그 순서다 — 승인 큐는 로그인이 끝나야
  /// 그려지는 화면이라, 로그인 전에 Firestore 를 치는 일 자체가 없다.
  Future<void> openQueue() async {
    await container.read(authProvider.future);
    container.listen(pendingMasterMenuItemsProvider, (_, _) {});
    await container.read(pendingMasterMenuItemsProvider.future);
  }

  test('계정이 바뀌면 승인 큐를 다시 구독한다', () async {
    await openQueue();
    expect(repo.subscriptions, 1);

    // 로그아웃 → 재로그인 (다른 uid)
    _SwitchableAuth.uid = null;
    container.invalidate(authProvider);
    await container.read(authProvider.future);

    _SwitchableAuth.uid = 'admin2';
    container.invalidate(authProvider);
    await openQueue();

    expect(
      repo.subscriptions,
      greaterThan(1),
      reason: '세션이 바뀌었는데 첫 구독을 그대로 쓰고 있다 — 로그아웃으로 죽은 스트림을 들고 있는 상태',
    );
  });

  test('같은 세션에서는 다시 구독하지 않는다 (불필요한 재구독 방지)', () async {
    await openQueue();
    await openQueue();
    expect(repo.subscriptions, 1);
  });
}

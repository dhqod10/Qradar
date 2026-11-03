import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/constants/support_contact.dart';
import 'package:qradar/presentation/common/account_suspended_view.dart';
import 'package:qradar/presentation/customer/auth/auth_error_message.dart';

void main() {
  testWidgets('AccountSuspendedView: 제목·본문·공용 연락처·로그아웃 버튼 노출, 사유 미노출', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AccountSuspendedView())),
    );
    expect(find.text('계정이 정지되었어요'), findsOneWidget);
    expect(find.text(kSupportContact), findsOneWidget);
    expect(find.text('로그아웃'), findsOneWidget);
    expect(find.byIcon(Icons.block_outlined), findsOneWidget);
  });

  testWidgets('AccountSuspendedView: 작은 화면에서도 오버플로 없음', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AccountSuspendedView())),
    );
    expect(tester.takeException(), isNull);
  });

  test('user-disabled 오류는 제한 계정 문구로 분류', () {
    final e = Exception(
      '[firebase_auth/user-disabled] The user account has been disabled',
    );
    expect(isAccountDisabledError(e), isTrue);
    expect(authFriendlyMessage(e), kAccountRestrictedMessage);
    expect(isAccountDisabledError(Exception('network')), isFalse);
  });
}

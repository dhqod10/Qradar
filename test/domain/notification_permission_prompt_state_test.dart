import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/domain/entities/notification_permission_prompt_state.dart';

void main() {
  group('NotificationPermissionPromptState', () {
    test('kMaxNotificationPermissionPrompts is 3', () {
      expect(kMaxNotificationPermissionPrompts, 3);
    });

    test('default is unseen and promptable', () {
      const s = NotificationPermissionPromptState();
      expect(s.hasSeenDialog, false);
      expect(s.canPromptAgain, true);
    });

    for (final prompted in [false, true]) {
      for (final later in [0, 1, 2, 3, 4]) {
        test('prompted=$prompted laterCount=$later', () {
          final s = NotificationPermissionPromptState(
            prompted: prompted,
            laterCount: later,
          );
          expect(s.hasSeenDialog, prompted || later > 0);
          expect(s.canPromptAgain, !prompted && later < 3);
        });
      }
    }
  });
}

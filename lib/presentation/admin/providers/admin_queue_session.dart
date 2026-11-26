import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';

/// 승인 큐 stream provider 들이 **로그인 세션에 묶이도록** 하는 장치.
///
/// 왜 필요한가 — 실기기 테스트(2026-11-26)에서 드러난 고장:
///
/// 승인 큐 provider 는 `autoDispose` 가 아니라 앱 생애 내내 살아 있다. 그런데 **로그아웃하는
/// 순간 Firestore 리스너는 `permission-denied` 로 끝난다** (토큰이 사라지므로). Dart 의
/// 스트림은 에러가 나면 거기서 닫히고, provider 는 마지막 값(보통 빈 목록)을 그대로 들고
/// 남는다. 재로그인해도 **다시 구독하지 않는다.**
///
/// 증상이 고약했던 이유: 화면이 "검토 대기 중인 메뉴가 없어요" 라고 **정상처럼** 보였다.
/// 한 번이라도 로그아웃한 관리자는 앱을 완전히 재시작하기 전까지 아무것도 승인할 수 없는데,
/// 화면 어디에도 그 사실이 드러나지 않았다.
///
/// 이 provider 를 `ref.watch` 하면 uid 가 바뀔 때마다(로그아웃 → null, 재로그인 → 새 uid)
/// 구독이 다시 만들어진다.
final adminQueueSessionUidProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).asData?.value?.uid;
});

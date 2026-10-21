import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/notification_category.dart';
import 'package:qradar/domain/entities/notification_permission_status.dart';
import 'package:qradar/domain/entities/user_entity.dart';
import 'package:qradar/domain/entities/user_role.dart';
import 'package:qradar/presentation/common/notification/providers/notification_providers.dart';
import 'package:qradar/presentation/common/notification/providers/notification_settings_providers.dart';
import 'package:qradar/presentation/common/notification/widgets/notification_permission_banner.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';

/// 알림 설정 화면 (Phase 3c-3). customer / owner 공용 — role 로 토글 목록 분기.
///
/// brand / admin 은 customer 토글·카피로 fallback.
class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage>
    with WidgetsBindingObserver {
  NotificationPermissionStatus? _osStatus;
  bool _requestingPermission = false;

  /// 이 화면 인스턴스에서 requestPermission() 을 이미 1회 호출했고 허용되지 않았다.
  /// true 면 이후 CTA 는 요청을 건너뛰고 설정 앱을 바로 연다 (Android 거부 카운터 보호).
  /// 영속화하지 않는다 — 화면을 벗어나면 리셋.
  bool _permissionRequestAttempted = false;

  /// 저장 진행 중 카테고리 (연타 방지).
  final Set<NotificationCategory> _saving = {};

  /// optimistic 값 (저장 진행 중에만 존재).
  final Map<NotificationCategory, bool> _optimistic = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshOsStatus());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshOsStatus(reconcile: true);
    }
  }

  Future<void> _refreshOsStatus({bool reconcile = false}) async {
    try {
      final status = await ref
          .read(pushNotificationRepositoryProvider)
          .getPermissionStatus();
      if (!mounted) return;
      setState(() => _osStatus = status);
    } catch (_) {
      // 조회 실패 시 배너 생략 (토글은 정상 동작)
      return;
    }
    if (reconcile) {
      final uid = ref.read(authProvider).asData?.value?.uid;
      if (uid != null) {
        await ref.read(syncNotificationTokenUseCaseProvider).call(uid);
      }
    }
  }

  /// 배너 CTA: 앱 내 권한 요청을 먼저 시도하고, 요청 전 상태가 denied 이며
  /// 결과도 denied 이면 설정 앱으로 폴백한다 (denied / notDetermined 공용).
  ///
  /// 설정 화면 CTA 는 notificationPermissionPrompted / LaterCount 를 읽거나 쓰지 않는다.
  Future<void> _onPermissionCtaTap(String uid) async {
    if (_requestingPermission) return;
    // _refreshOsStatus() 가 _osStatus 를 덮어쓰므로 요청 전 값을 스냅샷
    final statusBefore = _osStatus;
    setState(() => _requestingPermission = true);
    try {
      if (_permissionRequestAttempted) {
        // 이미 한 번 요청했음 → 요청 건너뛰고 설정 앱
        await _fallbackToAppSettings();
        return;
      }

      NotificationPermissionStatus? result;
      try {
        _permissionRequestAttempted = true;
        result = await ref
            .read(requestNotificationPermissionUseCaseProvider)
            .call();
      } catch (_) {
        // 요청 예외 → 정상 경로와 동일한 기준으로 안내 (결정 E-2).
        // notDetermined 에서 실패한 경우는 안내도 하지 않는다 (배너 톤 변화가 피드백).
        if (statusBefore == NotificationPermissionStatus.denied) {
          _showSettingsHint();
        }
        return;
      }

      if (result == NotificationPermissionStatus.authorized ||
          result == NotificationPermissionStatus.provisional) {
        await ref.read(registerFcmTokenUseCaseProvider).call(uid);
        await _refreshOsStatus();
        return;
      }

      await _refreshOsStatus();
      // 1회차 탭에서는 설정 앱으로 전환하지 않는다 (결정 E-2 개정).
      // 방금 시트에서 거절한 사용자를 즉시 끌고 가는 것은 거절 의사를 무시하는 동작이고,
      // Android 는 "방금 거절" 과 "이미 영구 차단" 을 구분할 수 없어 전자까지 휩쓸린다.
      // 영구 차단된 사용자는 안내 SnackBar 를 보고 다시 탭하면 세션 가드가 설정 앱으로 보낸다.
      // notDetermined 거부는 배너 톤 변화가 피드백이므로 안내도 생략한다.
      if (statusBefore == NotificationPermissionStatus.denied) {
        _showSettingsHint();
      }
    } finally {
      if (mounted) setState(() => _requestingPermission = false);
    }
  }

  /// 기기 설정에서 켜야 한다는 안내만 표시한다 (화면 전환 없음).
  void _showSettingsHint() {
    if (!mounted) return;
    _showSnack(
      '기기 설정에서 알림을 허용해 주세요',
      backgroundColor: AppColors.primary,
      duration: const Duration(seconds: 4),
      clearBefore: true,
    );
  }

  /// 전환 안내 SnackBar 후 설정 앱을 연다 (2회차 탭 전용).
  Future<void> _fallbackToAppSettings() async {
    if (!mounted) return;
    _showSettingsHint();
    // 안내 SnackBar 가 읽힐 시간 확보 (스피너는 _requestingPermission 으로 유지)
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    await _openAppSettings();
  }

  Future<void> _openAppSettings() async {
    try {
      await AppSettings.openAppSettings();
    } catch (_) {
      _showSnack('설정 화면을 열 수 없어요');
    }
  }

  Future<void> _onToggle({
    required String uid,
    required NotificationCategory category,
    required bool enabled,
  }) async {
    if (_saving.contains(category)) return;
    setState(() {
      _saving.add(category);
      _optimistic[category] = enabled;
    });
    try {
      await ref.read(updateNotificationSettingUseCaseProvider).call(
            uid: uid,
            category: category,
            enabled: enabled,
          );
    } catch (_) {
      _showSnack('설정을 저장하지 못했어요. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) {
        setState(() {
          _saving.remove(category);
          _optimistic.remove(category);
        });
      }
    }
  }

  /// 기본은 error 톤. 안내용은 [backgroundColor] 로 톤을 바꾼다.
  void _showSnack(
    String message, {
    Color backgroundColor = AppColors.error,
    Duration duration = const Duration(seconds: 3),
    bool clearBefore = false,
  }) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (clearBefore) messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        duration: duration,
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.onPrimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textHeading, size: 20),
        title: const Text(
          '알림 설정',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
      ),
      body: SafeArea(
        child: profile.when(
          loading: () => const _LoadingBody(),
          error: (_, _) => _ErrorBody(
            onRetry: () => ref.invalidate(currentUserProfileProvider),
          ),
          data: (user) {
            if (user == null) return const SizedBox.shrink();
            return _buildContent(user);
          },
        ),
      ),
    );
  }

  Widget _buildContent(UserEntity user) {
    final isOwner = user.role == UserRole.owner;
    final entries = isOwner
        ? const [
            _ToggleSpec(
              category: NotificationCategory.newOrder,
              title: '신규 주문 알림',
              subtitle: '새 주문이 들어오면 바로 알려드려요',
            ),
            _ToggleSpec(
              category: NotificationCategory.refundRequest,
              title: '환불 요청 알림',
              subtitle: '고객이 환불을 요청하면 알려드려요',
            ),
          ]
        : const [
            _ToggleSpec(
              category: NotificationCategory.orderProgress,
              title: '주문 진행 알림',
              subtitle: '접수, 조리 시작, 픽업 준비 소식을 알려드려요',
            ),
            _ToggleSpec(
              category: NotificationCategory.pickupComplete,
              title: '픽업 완료 알림',
              subtitle: '픽업이 완료되면 알려드려요',
            ),
          ];

    final os = _osStatus;
    final showBanner = os == NotificationPermissionStatus.denied ||
        os == NotificationPermissionStatus.notDetermined;
    final showFootNote = os == NotificationPermissionStatus.authorized ||
        os == NotificationPermissionStatus.provisional;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: showBanner
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: NotificationPermissionBanner(
                    status: os!,
                    isOwner: isOwner,
                    isRequesting: _requestingPermission,
                    onPrimaryTap: () => _onPermissionCtaTap(user.uid),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            isOwner ? '매장 알림' : '주문 알림',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.border,
                    ),
                  ),
                _SettingToggleTile(
                  spec: entries[i],
                  value: _optimistic[entries[i].category] ??
                      user.notificationSettings.valueOf(entries[i].category),
                  onChanged: (v) => _onToggle(
                    uid: user.uid,
                    category: entries[i].category,
                    enabled: v,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (showFootNote)
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Text(
              '알림은 기기 설정에서 알림이 허용된 경우에만 받을 수 있어요.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}

class _ToggleSpec {
  final NotificationCategory category;
  final String title;
  final String subtitle;

  const _ToggleSpec({
    required this.category,
    required this.title,
    required this.subtitle,
  });
}

class _SettingToggleTile extends StatelessWidget {
  final _ToggleSpec spec;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingToggleTile({
    required this.spec,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'notification_toggle_${spec.category.asString}',
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        overlayColor: WidgetStatePropertyAll(
          AppColors.primary.withValues(alpha: 0.08),
        ),
        title: Text(
          spec.title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textHeading,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            spec.subtitle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.4,
              color: AppColors.textMuted,
            ),
          ),
        ),
        activeThumbColor: AppColors.onPrimary,
        activeTrackColor: AppColors.primary,
        inactiveThumbColor: AppColors.textMuted,
        inactiveTrackColor: AppColors.surface,
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.border,
        ),
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Container(
          height: 16,
          width: 72,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 152,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorBody({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: 12),
          const Text(
            '설정을 불러오지 못했어요',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}

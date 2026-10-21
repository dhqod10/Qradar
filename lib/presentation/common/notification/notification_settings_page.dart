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

  Future<void> _requestPermission(String uid) async {
    if (_requestingPermission) return;
    setState(() => _requestingPermission = true);
    try {
      final result =
          await ref.read(requestNotificationPermissionUseCaseProvider).call();
      if (result == NotificationPermissionStatus.authorized ||
          result == NotificationPermissionStatus.provisional) {
        await ref.read(registerFcmTokenUseCaseProvider).call(uid);
      }
      await _refreshOsStatus();
    } finally {
      if (mounted) setState(() => _requestingPermission = false);
    }
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

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
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
                    onPrimaryTap: () => os == NotificationPermissionStatus.denied
                        ? _openAppSettings()
                        : _requestPermission(user.uid),
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

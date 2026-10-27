import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/errors/store_deletion_exception.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/store_deletion.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/admin/providers/admin_store_deletion_providers.dart';
import 'package:qradar/presentation/admin/store_management/admin_store_list_page.dart';
import 'package:qradar/presentation/admin/widgets/brand_scope_badge.dart';
import 'package:qradar/presentation/admin/widgets/store_scope_badge.dart';
import 'package:qradar/presentation/common/providers/store_brand_link_providers.dart';
import 'package:qradar/presentation/common/widgets/approval_status_badge.dart';

/// 삭제 사유 최소/최대 길이 (서버가 trim 후 2~200자를 재검증한다).
const int storeDeletionReasonMin = 2;
const int storeDeletionReasonMax = 200;

/// 삭제 버튼 활성 조건 — 영향 범위 **로드 성공** · 진행 중인 주문 **0건** · 사유 trim 2자 이상 · 확인 입력이
/// 기준 이름과 **정확히 일치**(앞뒤 공백만 무시) · 삭제 중 아님.
///
/// 영향 범위를 못 읽었으면([preview] == null) **false** — 파괴적 동작은 fail-closed (결제 선검증과 반대 방향).
bool canDeleteStore({
  required StoreDeletionPreview? preview,
  required String reason,
  required String confirmInput,
  required String expectedName,
  required bool deleting,
}) {
  if (deleting || preview == null || preview.alreadyDeleted) return false;
  if (preview.affected.inFlightOrders > 0) return false;
  if (reason.trim().length < storeDeletionReasonMin) return false;
  return confirmInput.trim() == expectedName;
}

enum _Phase { idle, deleting, failed, failedInFlight, alreadyDeleted }

/// admin 매장 삭제 — 되돌릴 수 없는 작업이라 다이얼로그가 아니라 전체 화면이다 (design §7.2).
///
/// 화면 숫자는 `deleteStore(dryRun)` 의 "확인 시점 값" 이다. **삭제 이력에 기록되는 값은 서버가 실행 시점에 다시 센다** —
/// 이 화면의 숫자를 서버로 보내지 않는다. 서버 예외 문자열은 어디에도 그리지 않는다.
class AdminStoreDeletePage extends ConsumerStatefulWidget {
  const AdminStoreDeletePage({super.key, required this.store});
  final StoreEntity store;

  @override
  ConsumerState<AdminStoreDeletePage> createState() =>
      _AdminStoreDeletePageState();
}

class _AdminStoreDeletePageState extends ConsumerState<AdminStoreDeletePage> {
  final _reasonCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  _Phase _phase = _Phase.idle;

  @override
  void initState() {
    super.initState();
    _reasonCtrl.addListener(() => setState(() {}));
    _confirmCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String get _expectedName {
    final brandName = ref
        .read(storeBrandLinkProvider(widget.store.brandId))
        .brand
        ?.name;
    return adminStoreDisplayName(widget.store, brandName);
  }

  void _reload() {
    setState(() => _phase = _Phase.idle);
    ref.invalidate(storeDeletionPreviewProvider(widget.store.id));
  }

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _phase = _Phase.deleting);
    try {
      final result = await ref
          .read(adminDeleteStoreUseCaseProvider)
          .call(widget.store.id, reason: _reasonCtrl.text);
      if (!mounted) return;
      if (result.alreadyDeleted) {
        setState(() => _phase = _Phase.alreadyDeleted);
        return;
      }
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('삭제했어요. 삭제 이력이 기록됐어요'),
          duration: Duration(seconds: 2),
        ),
      );
    } on StoreDeletionException catch (e) {
      if (!mounted) return;
      setState(() {
        switch (e.kind) {
          case StoreDeletionFailure.inFlightOrders:
            _phase = _Phase.failedInFlight;
          case StoreDeletionFailure.notFound:
            _phase = _Phase.alreadyDeleted;
          case StoreDeletionFailure.failed:
            _phase = _Phase.failed;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = _Phase.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewAsync = ref.watch(
      storeDeletionPreviewProvider(widget.store.id),
    );
    // 다시 불러오는 중(isLoading)에는 이전 값/오류를 쓰지 않는다 — 스켈레톤으로 돌아가고 삭제 버튼은 꺼진다.
    final settled = !previewAsync.isLoading;
    final preview = settled && !previewAsync.hasError
        ? previewAsync.asData?.value
        : null;
    final previewNotFound =
        settled &&
        previewAsync.error is StoreDeletionException &&
        (previewAsync.error as StoreDeletionException).kind ==
            StoreDeletionFailure.notFound;

    if (_phase == _Phase.alreadyDeleted ||
        (preview?.alreadyDeleted ?? false) ||
        previewNotFound) {
      return const _AlreadyDeletedView();
    }

    final deleting = _phase == _Phase.deleting;
    final inFlight = preview?.affected.inFlightOrders ?? 0;
    final canDelete = canDeleteStore(
      preview: preview,
      reason: _reasonCtrl.text,
      confirmInput: _confirmCtrl.text,
      expectedName: _expectedName,
      deleting: deleting,
    );

    return PopScope(
      canPop: !deleting,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textHeading,
            ),
            onPressed: deleting ? null : () => Navigator.pop(context),
          ),
          title: const Text(
            '매장 삭제',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          bottom: deleting
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.primary,
                    backgroundColor: AppColors.surface,
                  ),
                )
              : null,
        ),
        body: IgnorePointer(
          ignoring: deleting,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryCard(store: widget.store),
                const SizedBox(height: 24),
                const _SectionTitle('삭제되는 데이터'),
                const SizedBox(height: 8),
                _AffectedCard(async: previewAsync, onReload: _reload),
                const SizedBox(height: 24),
                const _SectionTitle('삭제 사유'),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('storeDelete.reason'),
                  controller: _reasonCtrl,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: storeDeletionReasonMax,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textBody,
                  ),
                  decoration: _decoration('예: 폐업 확인 (2026-10-27 점주 요청)'),
                ),
                const SizedBox(height: 16),
                const _SectionTitle('확인'),
                const SizedBox(height: 8),
                const Text(
                  '되돌릴 수 없어요. 계속하려면 아래에 매장 이름을 똑같이 입력해 주세요.',
                  style: TextStyle(fontSize: 13, color: AppColors.textBody),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('storeDelete.confirm'),
                  controller: _confirmCtrl,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textBody,
                  ),
                  decoration: _decoration(_expectedName),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceElevated,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_phase == _Phase.failed) ...[
                  const _FailureBox(),
                  const SizedBox(height: 12),
                ],
                if (_phase == _Phase.failedInFlight) ...[
                  _RaceBox(onReload: _reload),
                  const SizedBox(height: 12),
                ] else if (inFlight > 0) ...[
                  _InFlightBox(count: inFlight, onReload: _reload),
                  const SizedBox(height: 12),
                ],
                if (deleting) ...[
                  const Text(
                    '삭제하는 중이에요. 잠시만 기다려 주세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    key: const ValueKey('storeDelete.submit'),
                    onPressed: canDelete ? _delete : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: AppColors.onPrimary,
                      disabledBackgroundColor: AppColors.surface,
                      disabledForegroundColor: AppColors.textMuted,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: deleting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.textMuted,
                            ),
                          )
                        : const Text(
                            '이 매장 삭제',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textMuted),
    filled: true,
    fillColor: AppColors.surfaceElevated,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: AppColors.textHeading,
    ),
  );
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({required this.store});
  final StoreEntity store;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBrand = store.brandId != null && store.brandId!.isNotEmpty;
    final brandName = ref
        .watch(storeBrandLinkProvider(store.brandId))
        .brand
        ?.name;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            adminStoreDisplayName(store, brandName),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ApprovalStatusBadge(
                status: store.status,
                isRevision:
                    store.approvedAt != null &&
                    store.status == EntityApprovalStatus.pending,
              ),
              if (isBrand)
                BrandScopeBadge(brandId: store.brandId!)
              else
                const StoreScopeBadge.personal(),
            ],
          ),
          if (store.address.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              store.address,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
          if (store.ownerId.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              store.ownerId,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 영향 범위 카드 — loading(스켈레톤) / error(다시 불러오기) / data(0 도 표시).
class _AffectedCard extends StatelessWidget {
  const _AffectedCard({required this.async, required this.onReload});
  final AsyncValue<StoreDeletionPreview> async;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('메뉴', '개'),
      ('메뉴 오버라이드', '개'),
      ('하위 카테고리', '개'),
      ('옵션 그룹', '개'),
      ('Qoin 적립률 이력', '건'),
      ('매장 이미지', '장'),
      ('진행 중인 주문', '건'),
    ];
    Widget body;
    if (async.hasError && !async.isLoading) {
      body = Row(
        key: const ValueKey('storeDelete.affectedError'),
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: AppColors.error,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '영향 범위를 불러오지 못했어요',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textBody,
              ),
            ),
          ),
          TextButton(
            onPressed: onReload,
            child: const Text(
              '다시 불러오기',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryBright,
              ),
            ),
          ),
        ],
      );
    } else {
      final a = async.isLoading ? null : async.asData?.value.affected;
      final values = a == null
          ? null
          : [
              a.menuItems,
              a.menuOverrides,
              a.subCategories,
              a.optionGroups,
              a.qoinRateHistory,
              a.images,
              a.inFlightOrders,
            ];
      body = Column(
        key: ValueKey(
          values == null
              ? 'storeDelete.affectedLoading'
              : 'storeDelete.affected',
        ),
        children: [
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    rows[i].$1,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textBody,
                    ),
                  ),
                  if (values == null)
                    Container(
                      width: 40,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )
                  else
                    Text(
                      '${values[i]}${rows[i].$2}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHeading,
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          body,
          const SizedBox(height: 8),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          const Text(
            '삭제 이력(매장 정보 스냅샷 포함)이 1건 남아요.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// 진행 중인 주문 n ≥ 1 — 삭제 버튼 위의 비활성 사유. 강제 종결 버튼은 만들지 않는다.
class _InFlightBox extends StatelessWidget {
  const _InFlightBox({required this.count, required this.onReload});
  final int count;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('storeDelete.inFlightBox'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '진행 중인 주문이 $count건 있어요',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '모두 완료·취소된 뒤에 삭제할 수 있어요.',
            style: TextStyle(fontSize: 13, color: AppColors.textBody),
          ),
          const SizedBox(height: 4),
          const Text(
            '지금 삭제하면 그 주문의 취소·환불을 처리할 수 없게 돼요.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: _ReloadButton(onPressed: onReload),
          ),
        ],
      ),
    );
  }
}

/// 실행 시 CF 가 `[STORE_HAS_INFLIGHT_ORDERS]` 로 거부한 경쟁 변형 (화면은 0건이었다).
class _RaceBox extends StatelessWidget {
  const _RaceBox({required this.onReload});
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('storeDelete.raceBox'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '방금 새 주문이 들어왔어요. 다시 확인해 주세요.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: _ReloadButton(onPressed: onReload),
          ),
        ],
      ),
    );
  }
}

class _ReloadButton extends StatelessWidget {
  const _ReloadButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: EdgeInsets.zero,
      ),
      child: const Text(
        '다시 불러오기',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryBright,
        ),
      ),
    );
  }
}

/// 삭제가 중간에 멈췄다 — 서버 문자열은 싣지 않는다. 문구의 두 약속(이어서 진행 / 이력 중복 없음)은 서버 멱등 계약이다.
class _FailureBox extends StatelessWidget {
  const _FailureBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('storeDelete.failureBox'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '삭제가 중간에 멈췄어요',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.error,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '같은 매장을 다시 삭제하면 이어서 진행돼요. 삭제 이력은 중복 기록되지 않아요.',
            style: TextStyle(fontSize: 12, color: AppColors.textBody),
          ),
        ],
      ),
    );
  }
}

class _AlreadyDeletedView extends StatelessWidget {
  const _AlreadyDeletedView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          '매장 삭제',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              '이미 삭제된 매장이에요',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeading,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                '목록으로',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/config/map_config.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/user_location.dart';
import 'package:qradar/presentation/customer/home/providers/home_providers.dart';
import 'package:qradar/presentation/customer/order/providers/order_providers.dart';
import 'package:qradar/presentation/customer/order/widgets/grade_filter_chips.dart';
import 'package:qradar/presentation/customer/order/widgets/kakao_map_view.dart';
import 'package:qradar/presentation/customer/order/store/store_menu_page.dart';
import 'package:qradar/presentation/customer/order/widgets/order_search_bar.dart';
import 'package:qradar/presentation/customer/order/widgets/store_map_marker_sheet.dart';

/// 주문 화면 "지도 검색" 탭 — Kakao Maps WebView + 마커 + 미니 카드 시트.
class StoreMapTab extends ConsumerStatefulWidget {
  const StoreMapTab({super.key});

  @override
  ConsumerState<StoreMapTab> createState() => _StoreMapTabState();
}

class _StoreMapTabState extends ConsumerState<StoreMapTab> {
  final GlobalKey<KakaoMapViewState> _mapKey =
      GlobalKey<KakaoMapViewState>();

  String? _selectedStoreId;
  bool _webViewReady = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<StoreEntity>>>(orderStoresProvider,
        (previous, next) {
      _syncToMap();
      next.whenData((stores) {
        if (_selectedStoreId != null &&
            !stores.any((s) => s.id == _selectedStoreId)) {
          setState(() => _selectedStoreId = null);
          _mapKey.currentState?.setSelected(null);
        }
      });
    });

    final asyncStores = ref.watch(orderStoresProvider);
    final baseCount =
        ref.watch(orderBaseStoresProvider).asData?.value.length ?? 0;
    final asyncLocation = ref.watch(userLocationProvider);
    final userLocation = asyncLocation.asData?.value;

    final selectedStore = _selectedStoreForList(asyncStores);
    final sheetOpen = selectedStore != null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: OrderSearchBar(onFocusChange: _onSearchFocusChange),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: GradeFilterChips(),
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: KakaoMapView(
                  key: _mapKey,
                  initialLocation: userLocation,
                  onReady: _onMapReady,
                  onMarkerTap: _onMarkerTap,
                  onMapTap: _onMapTap,
                  onError: _onMapError,
                ),
              ),
              Positioned(
                top: 12,
                left: 20,
                right: 20,
                child: _buildBanner(asyncStores, baseCount),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                right: 20,
                bottom: sheetOpen ? 176 : 20,
                child: _MyLocationFab(
                  enabled: userLocation != null,
                  onTap: () => _onMyLocationTap(userLocation),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  ignoring: !sheetOpen,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    offset: sheetOpen ? Offset.zero : const Offset(0, 1.2),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: sheetOpen ? 1 : 0,
                      child: selectedStore == null
                          ? const SizedBox.shrink()
                          : StoreMapMarkerSheet(
                              store: selectedStore,
                              onClose: _closeSheet,
                              onOrderPressed: () =>
                                  _openStoreMenu(selectedStore),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Callbacks ──────────────────────────────────────────────────────────

  void _onMapReady() {
    if (!mounted) return;
    _webViewReady = true;
    _syncToMap();
  }

  void _onMapError() {
    // KakaoMapView 내부 에러 UI 가 표시되므로 추가 액션 불필요.
    // 선택 상태만 초기화.
    if (_selectedStoreId != null) {
      setState(() => _selectedStoreId = null);
    }
  }

  void _onMarkerTap(String storeId) {
    if (!mounted) return;
    setState(() => _selectedStoreId = storeId);
    _mapKey.currentState?.setSelected(storeId);
  }

  void _onMapTap() {
    if (!mounted) return;
    if (_selectedStoreId != null) {
      setState(() => _selectedStoreId = null);
      _mapKey.currentState?.setSelected(null);
    }
  }

  void _onSearchFocusChange(bool focused) {
    if (focused && _selectedStoreId != null) {
      setState(() => _selectedStoreId = null);
      _mapKey.currentState?.setSelected(null);
    }
  }

  void _onMyLocationTap(UserLocation? location) {
    if (location == null) return;
    _mapKey.currentState?.moveTo(location.latitude, location.longitude);
  }

  void _closeSheet() {
    setState(() => _selectedStoreId = null);
    _mapKey.currentState?.setSelected(null);
  }

  void _openStoreMenu(StoreEntity store) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoreMenuPage(store: store),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  StoreEntity? _selectedStoreForList(AsyncValue<List<StoreEntity>> async) {
    final id = _selectedStoreId;
    if (id == null) return null;
    final list = async.asData?.value;
    if (list == null) return null;
    for (final s in list) {
      if (s.id == id) return s;
    }
    return null;
  }

  void _syncToMap() {
    if (!_webViewReady) return;
    final stores = ref.read(orderStoresProvider).asData?.value ?? const [];
    final payload = <String, dynamic>{
      'stores': stores
          .map((s) => {
                'id': s.id,
                'lat': s.location.latitude,
                'lng': s.location.longitude,
                'grade': s.grade.asString,
                'color': MapConfig.markerColorHexForGrade(s.grade),
              })
          .toList(),
    };
    _mapKey.currentState?.setStores(payload);
  }

  Widget _buildBanner(
    AsyncValue<List<StoreEntity>> async,
    int baseCount,
  ) {
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => _MapStatusBanner.error(
        onRetry: () => ref.invalidate(orderBaseStoresProvider),
      ),
      data: (list) {
        if (list.isNotEmpty) return const SizedBox.shrink();
        if (baseCount == 0) return const _MapStatusBanner.noNearby();
        return const _MapStatusBanner.noMatch();
      },
    );
  }
}

// ── 내부 위젯 ──────────────────────────────────────────────────────────────

class _MyLocationFab extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _MyLocationFab({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '내 위치로 이동',
      button: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: IgnorePointer(
          ignoring: !enabled,
          child: Material(
            color: AppColors.surfaceElevated,
            shape: const CircleBorder(
              side: BorderSide(color: AppColors.border, width: 1),
            ),
            elevation: 0,
            shadowColor: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Ink(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    Icons.my_location_rounded,
                    size: 22,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _BannerKind { noMatch, noNearby, error }

class _MapStatusBanner extends StatelessWidget {
  final _BannerKind kind;
  final VoidCallback? onRetry;

  const _MapStatusBanner._(this.kind, {this.onRetry});

  const _MapStatusBanner.noMatch() : this._(_BannerKind.noMatch);
  const _MapStatusBanner.noNearby() : this._(_BannerKind.noNearby);
  const _MapStatusBanner.error({required VoidCallback onRetry})
      : this._(_BannerKind.error, onRetry: onRetry);

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String text;
    final Color iconColor;
    final Color borderColor;
    switch (kind) {
      case _BannerKind.noMatch:
        icon = Icons.search_off_rounded;
        text = '조건에 맞는 매장이 없어요';
        iconColor = AppColors.textMuted;
        borderColor = AppColors.border;
        break;
      case _BannerKind.noNearby:
        icon = Icons.storefront_outlined;
        text = '주변 10km 이내에 매장이 없어요';
        iconColor = AppColors.textMuted;
        borderColor = AppColors.border;
        break;
      case _BannerKind.error:
        icon = Icons.error_outline;
        text = '매장 정보를 불러올 수 없어요';
        iconColor = AppColors.error;
        borderColor = AppColors.error.withValues(alpha: 0.4);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textBody,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (kind == _BannerKind.error && onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '다시 시도',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

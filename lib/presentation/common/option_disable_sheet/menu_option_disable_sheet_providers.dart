import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/option_remote_data_source.dart';
import 'package:qradar/data/repositories/option_repository_impl.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/repositories/option_repository.dart';

// ── DI (시트 한정) ────────────────────────────────────────────────────────
//
// customer 측 menu_detail_providers.dart 의 _optionRemoteDataSourceProvider /
// optionRepositoryProvider 와 동일 인스턴스를 공유할 필요는 없음 (각각 stateless).
// 단일 사용처라 시트 트리에 둠.
final _sheetOptionRemoteDataSourceProvider =
    Provider<OptionRemoteDataSource>((_) => OptionRemoteDataSource());

final _sheetOptionRepositoryProvider = Provider<OptionRepository>(
  (ref) => OptionRepositoryImpl(ref.watch(_sheetOptionRemoteDataSourceProvider)),
);

// ── 옵션 그룹 fetch (entity 직접 입력) ────────────────────────────────────
//
// 시트 한정. menuItemDetailProvider 의존을 끊는다.
// disabled 필터는 적용하지 않고 전체 그룹/항목을 반환 — 시트는 모든 옵션을 토글 가능하게 표시.
// (sub-phase 5 의 menuItemAllOptionGroupsProvider 와 동등한 의미 — disabled 필터 없음)
final optionGroupsForMenuItemEntityProvider = FutureProvider.autoDispose
    .family<List<OptionGroupEntity>, MenuItemEntity>((ref, menuItem) async {
  if (menuItem.optionGroupRefs.isEmpty) return const [];
  return ref.watch(_sheetOptionRepositoryProvider).getOptionGroupsForMenuItem(
        menuItem,
        // 시트는 모든 옵션을 표시 후 토글하므로 disabled 필터 미적용.
        disabledGroupIds: const {},
        disabledItemIds: const {},
      );
});

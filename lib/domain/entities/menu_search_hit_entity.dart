import 'package:freezed_annotation/freezed_annotation.dart';

part 'menu_search_hit_entity.freezed.dart';

/// 메뉴 검색 결과 출처 (디버깅 · 후속 F2 판단용).
enum MenuHitSource { brandMaster, storeOwn }

/// 메뉴 검색 결과 1행 = (메뉴 1개 x 매장 1개).
///
/// **가격 필드를 일부러 두지 않는다.** 메뉴 인덱스는 `menuOverrides` 를 읽지 않아 매장별 실제 가격과 다를 수 있다 —
/// 가격은 매장 메뉴 화면이 정식 머지로 보여준다 (spec §2.1 / §4.1). 숫자 칸(할인·품절·별점)도 예약하지 않는다.
@freezed
abstract class MenuSearchHitEntity with _$MenuSearchHitEntity {
  const factory MenuSearchHitEntity({
    /// 메뉴 문서 ID (브랜드 마스터면 마스터 ID — 매장 화면 머지 목록의 id 와 같다).
    required String menuItemId,
    required String menuName,

    /// 없으면 `''`.
    @Default('') String menuImageUrl,
    required String mainCategoryCode,
    required String storeId,
    required String storeName,

    /// 스냅샷의 값 그대로.
    double? distanceKm,
    required MenuHitSource source,
  }) = _MenuSearchHitEntity;
}

/// 메뉴 인덱스(세션 캐시) — 결과 + 출처별 실패 수.
///
/// 출처 하나가 실패해도 검색 전체를 죽이지 않는다 (spec §11). 전부 실패하면 인덱스 대신 예외가 된다.
class MenuSearchIndex {
  const MenuSearchIndex({
    required this.hits,
    this.failedSourceCount = 0,
    this.searchedStoreCount = 0,
  });

  final List<MenuSearchHitEntity> hits;

  /// 가져오지 못한 출처(브랜드/개인 매장) 수. 1 이상이면 `일부 매장의 메뉴를 불러오지 못했어요`.
  final int failedSourceCount;

  /// 실제로 메뉴를 찾아본 후보 매장 수 (범위 안내 문구의 근거 — 고정 숫자를 말하지 않는다).
  final int searchedStoreCount;

  bool get isPartial => failedSourceCount > 0;
}

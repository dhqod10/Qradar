import 'package:freezed_annotation/freezed_annotation.dart';

part 'menu_search_hit_entity.freezed.dart';

/// 메뉴 검색 결과 출처 (디버깅 · 후속 F2 판단용).
enum MenuHitSource { brandMaster, storeOwn }

/// 메뉴 검색 결과 1행 = (메뉴 1개 x 매장 1개).
///
/// **2차 개정(spec §15.5, D8)**: 가격(`basePrice`)과 품절(`soldOut`)만 둔다.
/// 1차는 인덱스가 `menuOverrides` 를 읽지 않아 가격이 틀릴 수 있어 금지했지만, 2단계 검증이 override 를
/// `applyOverrideForCustomer` 로 적용하므로 그 이유가 사라졌다. 1단계 직후의 값(마스터 가격)은 **화면에 쓰이지 않는다** —
/// 검증을 통과한 행만 그려진다. 할인·별점·리뷰 수·옵션 최저가 칸은 여전히 두지 않는다 (해제한 것은 가격 하나뿐).
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

    /// 매장 메뉴 화면 카드와 같은 값 (검증 후 override 적용분). 표기는 `PriceFormatter.formatKrw` 한 곳.
    required int basePrice,
    @Default(false) bool soldOut,
  }) = _MenuSearchHitEntity;
}

/// 2단계 검증 계획 — 어느 브랜드 매장의 override 를 읽을지 (거리순 상한 적용).
class MenuVerifyPlan {
  const MenuVerifyPlan({required this.storeIds, required this.truncated});

  /// override 를 읽을 distinct 브랜드 매장 id (가까운 순, 최대 상한).
  final List<String> storeIds;

  /// 상한 밖 브랜드 매장의 행이 있어 버려졌는가 (`검색 범위를 좁혀 보세요`).
  final bool truncated;
}

/// 2단계 검증 결과.
class VerifiedMenuHits {
  const VerifiedMenuHits({
    required this.hits,
    this.failedStoreCount = 0,
    this.truncated = false,
  });

  /// 검증을 통과한 행 (제외·검증 실패·상한 밖은 없다).
  final List<MenuSearchHitEntity> hits;
  final int failedStoreCount;
  final bool truncated;
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

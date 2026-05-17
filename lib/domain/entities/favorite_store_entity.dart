import 'package:freezed_annotation/freezed_annotation.dart';

part 'favorite_store_entity.freezed.dart';

/// Qrator 가 즐겨찾기한 매장.
///
/// 본 phase 에서는 인터페이스 호환용. 실제 사용은 Phase 1c.
@freezed
abstract class FavoriteStoreEntity with _$FavoriteStoreEntity {
  const factory FavoriteStoreEntity({
    required String storeId,
    required DateTime addedAt,
  }) = _FavoriteStoreEntity;
}

import 'package:qradar/domain/entities/sub_category_entity.dart';
import 'package:qradar/domain/repositories/sub_category_repository.dart';

/// 같은 scope 내 동일 normalized name 존재 여부 조회 (폼 디바운스 lookup 용).
class FindDuplicateSubCategoryNameUseCase {
  final SubCategoryRepository _repository;
  FindDuplicateSubCategoryNameUseCase(this._repository);

  Future<bool> call({
    required String name,
    required SubCategoryScope scope,
    String? brandId,
    String? storeId,
    String? excludeId,
  }) =>
      _repository.findDuplicateName(
        name: name,
        scope: scope,
        brandId: brandId,
        storeId: storeId,
        excludeId: excludeId,
      );
}

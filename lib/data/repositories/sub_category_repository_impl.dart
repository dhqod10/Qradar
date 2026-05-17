import 'package:qradar/core/errors/duplicate_sub_category_name_exception.dart';
import 'package:qradar/core/errors/sub_category_in_use_exception.dart';
import 'package:qradar/data/datasources/remote/sub_category_remote_data_source.dart';
import 'package:qradar/data/models/sub_category_model.dart';
import 'package:qradar/domain/entities/sub_category_entity.dart';
import 'package:qradar/domain/repositories/sub_category_repository.dart';

class SubCategoryRepositoryImpl implements SubCategoryRepository {
  final SubCategoryRemoteDataSource _dataSource;

  SubCategoryRepositoryImpl(this._dataSource);

  @override
  Stream<List<SubCategoryEntity>> watchByBrand({
    required String brandId,
    bool activeOnly = false,
  }) {
    return _dataSource
        .streamByBrand(brandId: brandId, activeOnly: activeOnly)
        .map((models) => models.map((m) => m.toEntity()).toList(growable: false));
  }

  @override
  Stream<List<SubCategoryEntity>> watchByStore({
    required String storeId,
    bool activeOnly = false,
  }) {
    return _dataSource
        .streamByStore(storeId: storeId, activeOnly: activeOnly)
        .map((models) => models.map((m) => m.toEntity()).toList(growable: false));
  }

  @override
  Future<SubCategoryEntity?> findById({
    required String id,
    required SubCategoryScope scope,
    String? brandId,
    String? storeId,
  }) async {
    SubCategoryModel? model;
    if (scope == SubCategoryScope.brand && brandId != null) {
      model = await _dataSource.getBrandSubById(brandId: brandId, id: id);
    } else if (scope == SubCategoryScope.store && storeId != null) {
      model = await _dataSource.getStoreSubById(storeId: storeId, id: id);
    }
    return model?.toEntity();
  }

  @override
  Future<void> upsert(SubCategoryEntity entity) async {
    final normalizedName = entity.name.trim().toLowerCase();
    final isNew = entity.createdAt == null;

    // scope null 은 legacy global sub. CRUD 비범위 — 명시적 거부.
    final scope = entity.scope;
    if (scope == null) {
      throw ArgumentError('upsert 는 scope 가 brand/store 인 경우만 허용됩니다.');
    }

    // 중복 이름 검증
    final isDuplicate = await findDuplicateName(
      name: entity.name,
      scope: scope,
      brandId: entity.brandId,
      storeId: entity.storeId,
      excludeId: isNew ? null : entity.id,
    );
    if (isDuplicate) {
      throw DuplicateSubCategoryNameException(
        name: entity.name,
        scope: scope.name,
      );
    }

    // normalizedName 필드를 포함해 저장
    final model = SubCategoryModel.fromEntity(entity);
    final data = isNew ? model.toFirestoreCreate() : model.toFirestore();
    final dataWithNorm = <String, dynamic>{
      ...data,
      'normalizedName': normalizedName,
    };

    if (entity.scope == SubCategoryScope.brand && entity.brandId != null) {
      await _dataSource.upsertBrandSub(
        brandId: entity.brandId!,
        model: _ModelWithData(model, dataWithNorm),
        isNew: isNew,
      );
    } else if (entity.scope == SubCategoryScope.store && entity.storeId != null) {
      await _dataSource.upsertStoreSub(
        storeId: entity.storeId!,
        model: _ModelWithData(model, dataWithNorm),
        isNew: isNew,
      );
    }
  }

  @override
  Future<void> toggleActive({
    required String id,
    required SubCategoryScope scope,
    required bool active,
    String? brandId,
    String? storeId,
  }) async {
    if (scope == SubCategoryScope.brand && brandId != null) {
      await _dataSource.toggleBrandSubActive(
          brandId: brandId, id: id, active: active);
    } else if (scope == SubCategoryScope.store && storeId != null) {
      await _dataSource.toggleStoreSubActive(
          storeId: storeId, id: id, active: active);
    }
  }

  @override
  Future<void> delete({
    required String id,
    required SubCategoryScope scope,
    String? brandId,
    String? storeId,
  }) async {
    final usage = await countUsage(id);
    if (usage > 0) {
      throw SubCategoryInUseException(
          subCategoryId: id, usageCount: usage);
    }
    if (scope == SubCategoryScope.brand && brandId != null) {
      await _dataSource.deleteBrandSub(brandId: brandId, id: id);
    } else if (scope == SubCategoryScope.store && storeId != null) {
      await _dataSource.deleteStoreSub(storeId: storeId, id: id);
    }
  }

  @override
  Future<bool> findDuplicateName({
    required String name,
    required SubCategoryScope scope,
    String? brandId,
    String? storeId,
    String? excludeId,
  }) async {
    final normalizedName = name.trim().toLowerCase();
    if (scope == SubCategoryScope.brand && brandId != null) {
      return _dataSource.findDuplicateNameInBrand(
        brandId: brandId,
        normalizedName: normalizedName,
        excludeId: excludeId,
      );
    } else if (scope == SubCategoryScope.store && storeId != null) {
      return _dataSource.findDuplicateNameInStore(
        storeId: storeId,
        normalizedName: normalizedName,
        excludeId: excludeId,
      );
    }
    return false;
  }

  @override
  Future<int> countUsage(String subCategoryId) async {
    return _dataSource.countMenuItemUsage(subCategoryId);
  }
}

/// upsert 시 normalizedName 포함 데이터를 주입하기 위한 내부 헬퍼.
class _ModelWithData extends SubCategoryModel {
  final Map<String, dynamic> _overrideData;

  _ModelWithData(SubCategoryModel base, this._overrideData)
      : super(
          id: base.id,
          mainCategory: base.mainCategory,
          name: base.name,
          displayOrder: base.displayOrder,
          active: base.active,
          scope: base.scope,
          brandId: base.brandId,
          storeId: base.storeId,
          createdAt: base.createdAt,
          updatedAt: base.updatedAt,
        );

  @override
  Map<String, dynamic> toFirestore() => _overrideData;

  @override
  Map<String, dynamic> toFirestoreCreate() => _overrideData;
}

import 'package:qradar/domain/entities/sub_category_entity.dart';

/// 부 카테고리(글로벌) Repository 인터페이스.
abstract class MenuCategoryRepository {
  /// 메인 카테고리 id 에 속한 부 카테고리 stream.
  /// active=true && displayOrder asc.
  Stream<List<SubCategoryEntity>> watchSubCategories(String mainCategoryId);
}

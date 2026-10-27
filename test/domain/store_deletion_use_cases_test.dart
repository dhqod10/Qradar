import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/domain/entities/brand_key_lookup.dart';
import 'package:qradar/domain/entities/store_deletion.dart';
import 'package:qradar/domain/repositories/store_deletion_repository.dart';
import 'package:qradar/domain/usecases/admin_delete_store_use_case.dart';
import 'package:qradar/domain/usecases/preview_store_deletion_use_case.dart';
import 'package:qradar/domain/usecases/lookup_brand_by_key_use_case.dart';
import 'package:qradar/domain/repositories/brand_repository.dart';

class _Repo implements StoreDeletionRepository {
  final List<String> previewed = [];
  final List<(String, String)> deleted = [];

  @override
  Future<StoreDeletionPreview> preview(String storeId) async {
    previewed.add(storeId);
    return const StoreDeletionPreview(
      affected: StoreDeletionAffected(menuItems: 2),
    );
  }

  @override
  Future<StoreDeletionResult> delete(
    String storeId, {
    required String reason,
  }) async {
    deleted.add((storeId, reason));
    return const StoreDeletionResult(deletionId: 'd1');
  }
}

class _BrandRepo implements BrandRepository {
  @override
  Future<BrandKeyLookup> lookupBrandByKey(String brandKey) async =>
      BrandKeyLookup(brandId: 'b-$brandKey', name: 'N');

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

void main() {
  test(
    'PreviewStoreDeletionUseCase 는 repository.preview 에 위임한다 (쓰기 없음)',
    () async {
      final r = _Repo();
      final p = await PreviewStoreDeletionUseCase(r)('s1');
      expect(p.affected.menuItems, 2);
      expect(r.previewed, ['s1']);
      expect(r.deleted, isEmpty);
    },
  );

  test('AdminDeleteStoreUseCase 는 사유를 trim 해서 위임한다', () async {
    final r = _Repo();
    final res = await AdminDeleteStoreUseCase(r)('s1', reason: '  폐업 확인  ');
    expect(res.deletionId, 'd1');
    expect(r.deleted, [('s1', '폐업 확인')]);
  });

  test('StoreDeletionPreview.isBlocked 는 진행 중 주문 1건 이상', () {
    expect(
      const StoreDeletionPreview(
        affected: StoreDeletionAffected(inFlightOrders: 1),
      ).isBlocked,
      isTrue,
    );
    expect(
      const StoreDeletionPreview(affected: StoreDeletionAffected()).isBlocked,
      isFalse,
    );
  });

  test('LookupBrandByKeyUseCase 는 BrandKeyLookup 값 객체를 돌려준다', () async {
    final r = await LookupBrandByKeyUseCase(_BrandRepo())('BR-AAAAAAAA');
    expect(r.brandId, 'b-BR-AAAAAAAA');
  });
}

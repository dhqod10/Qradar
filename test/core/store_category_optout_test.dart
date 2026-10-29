import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/utils/store_menu_visibility.dart';
import 'package:qradar/data/models/store_model.dart';

void main() {
  group('isMenuShownOnStoreScreen — excludedCategoryIds', () {
    const active = {'coffee', 'dessert'};

    test('제외 인자 없으면 기존 동작 (active 만 본다)', () {
      expect(
        isMenuShownOnStoreScreen(
          visible: true,
          mainCategoryCode: 'dessert',
          activeCategoryIds: active,
        ),
        isTrue,
      );
    });

    test('점주가 끈 카테고리는 active 여도 숨긴다', () {
      expect(
        isMenuShownOnStoreScreen(
          visible: true,
          mainCategoryCode: 'dessert',
          activeCategoryIds: active,
          excludedCategoryIds: const {'dessert'},
        ),
        isFalse,
      );
      expect(
        isMenuShownOnStoreScreen(
          visible: true,
          mainCategoryCode: 'coffee',
          activeCategoryIds: active,
          excludedCategoryIds: const {'dessert'},
        ),
        isTrue,
      );
    });

    test('비활성 카테고리 코드가 excluded 에 남아 있어도 (휴면) 무해', () {
      expect(
        isMenuShownOnStoreScreen(
          visible: true,
          mainCategoryCode: 'coffee',
          activeCategoryIds: active,
          excludedCategoryIds: const {'bakery'},
        ),
        isTrue,
      );
    });
  });

  group('StoreModel.excludedMainCategories 쓰기 맵', () {
    StoreModel store() => StoreModel(
          id: 's1',
          name: 'n',
          imageUrl: '',
          latitude: 0,
          longitude: 0,
          averageScore: 0,
          reviewCount: 0,
          menuCategories: const [],
          createdAt: DateTime(2026),
          excludedMainCategories: const ['dessert'],
        );

    test('운영 필드 update 맵에만 들어간다 (create / core update 에는 없다)', () {
      final m = store();
      expect(m.toFirestoreForOperationUpdate()['excludedMainCategories'],
          ['dessert']);
      expect(m.toFirestoreForCreate().containsKey('excludedMainCategories'),
          isFalse);
      expect(
          m
              .toFirestoreForCoreUpdate(isResubmit: false)
              .containsKey('excludedMainCategories'),
          isFalse);
      expect(
          m.toFirestoreForBrandCreate().containsKey('excludedMainCategories'),
          isFalse);
    });

    test('entity 왕복 패스스루', () {
      expect(store().toEntity().excludedMainCategories, ['dessert']);
      expect(
        StoreModel.fromEntity(store().toEntity()).excludedMainCategories,
        ['dessert'],
      );
    });
  });

  group('StoreModel.availableMainCategories (CF 파생, 읽기 전용)', () {
    StoreModel store() => StoreModel(
          id: 's1',
          name: 'n',
          imageUrl: '',
          latitude: 0,
          longitude: 0,
          averageScore: 0,
          reviewCount: 0,
          menuCategories: const [],
          createdAt: DateTime(2026),
          availableMainCategories: const ['coffee'],
        );

    test('어떤 쓰기 맵에도 들어가지 않는다', () {
      final m = store();
      expect(m.toFirestoreForCreate().containsKey('availableMainCategories'),
          isFalse);
      expect(
          m
              .toFirestoreForOperationUpdate()
              .containsKey('availableMainCategories'),
          isFalse);
      expect(
          m
              .toFirestoreForCoreUpdate(isResubmit: false)
              .containsKey('availableMainCategories'),
          isFalse);
      expect(
          m
              .toFirestoreForBrandCreate()
              .containsKey('availableMainCategories'),
          isFalse);
    });

    test('entity 왕복 패스스루 / 기본값은 빈 목록', () {
      expect(store().toEntity().availableMainCategories, ['coffee']);
      expect(
        StoreModel.fromEntity(store().toEntity()).availableMainCategories,
        ['coffee'],
      );
      expect(
        StoreModel(
          id: 's',
          name: 'n',
          imageUrl: '',
          latitude: 0,
          longitude: 0,
          averageScore: 0,
          reviewCount: 0,
          menuCategories: const [],
          createdAt: DateTime(2026),
        ).availableMainCategories,
        isEmpty,
      );
    });
  });
}

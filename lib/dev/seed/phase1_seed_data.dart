// DEV_ONLY_SEED — order_flow_phase1, phase2 추가. 사용자 요청 시 lib/dev/seed/ 폴더 통째로 삭제.
import 'package:cloud_firestore/cloud_firestore.dart';

/// Phase 1 시드 페이로드 모음.
///
/// 모든 데이터는 임의의 고정 ID를 가지므로 동일 ID 재시드 시 merge 되어 안전.
class Phase1SeedData {
  Phase1SeedData._();

  static const String storeId = 'phase1_seed_store_001';

  // ── sub-phase 3 brand 시드 ID ─────────────────────────────────────────────
  static const String brandId = 'phase3_seed_brand_001';
  static const String brandStoreId = 'phase3_brand_store_001';

  // ── brand doc (`brands/{brandId}`) ───────────────────────────────────────
  /// sub-phase 6: brandKey 필드 추가. 시드 매장(`brandStoreId`) 등록 매핑 확인용.
  static Map<String, dynamic> brandDoc() => <String, dynamic>{
        'name': 'Q브루어리',
        'logoUrl': '',
        'description': 'Qradar 시드 브랜드. 고품질 스페셜티 커피 전문 체인.',
        'status': 'approved',
        'brandKey': 'BR-SEED0001',
        'submittedBy': 'seed',
        'companyName': '(주)Qradar 시드 브랜드',
        'businessRegistrationNumber': '123-45-67890',
        'contactName': '홍길동',
        'contactPhone': '010-1234-5678',
        'headOfficeAddress': '서울시 강남구 테헤란로 1',
        'representativeName': '김대표',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  // ── brand master menu items (`brands/{brandId}/menuItems`) ───────────────
  static List<Map<String, dynamic>> brandMasterMenuItems() =>
      <Map<String, dynamic>>[
        {
          'id': 'bm_signature_americano',
          'name': '시그니처 아메리카노',
          'imageUrl':
              'https://images.unsplash.com/photo-1494314671902-399b18174975?w=600',
          'description': '브랜드 대표 블렌드로 추출한 아메리카노.',
          'mainCategory': 'coffee',
          'subCategoryId': 'sc_coffee_espresso',
          'basePrice': 4800,
          'optionGroupRefs': [
            {'scope': 'master', 'id': 'og_master_temperature'},
            {'scope': 'master', 'id': 'og_master_shot'},
          ],
          'soldOut': false,
          'displayOrder': 10,
          'status': 'approved',
          'scope': 'brand',
          'brandId': brandId,
        },
        {
          'id': 'bm_house_latte',
          'name': '하우스 라떼',
          'imageUrl':
              'https://images.unsplash.com/photo-1561882468-9110e03e0f78?w=600',
          'description': '브랜드 시그니처 하우스 블렌드 라떼.',
          'mainCategory': 'coffee',
          'subCategoryId': 'sc_coffee_latte',
          'basePrice': 5800,
          'optionGroupRefs': [
            {'scope': 'master', 'id': 'og_master_temperature'},
            {'scope': 'master', 'id': 'og_master_shot'},
            {'scope': 'master', 'id': 'og_master_syrup'},
          ],
          'soldOut': false,
          'displayOrder': 20,
          'status': 'approved',
          'scope': 'brand',
          'brandId': brandId,
        },
      ];

  // ── brand store doc (`stores/{brandStoreId}`) ────────────────────────────
  static Map<String, dynamic> brandStoreDoc() => <String, dynamic>{
        'name': 'Q브루어리 강남점',
        'imageUrl':
            'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=800',
        'location': const GeoPoint(37.4979, 127.0276),
        // 평점은 실제 리뷰에서만 생긴다 (onReviewWritten CF 가 집계). grade 는 averageScore 에서 파생되므로 저장하지 않는다.
        'averageScore': 0.0,
        'reviewCount': 0,
        'menuCategories': ['coffee'],
        'ownerId': '',
        'phone': '02-1111-2222',
        'address': '서울특별시 강남구 테헤란로 1',
        'description': 'Q브루어리 강남 플래그십 스토어 (시드 데이터).',
        'businessHours': {
          'openHour': 8,
          'openMinute': 0,
          'closeHour': 21,
          'closeMinute': 0,
        },
        'brandId': brandId,
        'status': 'approved',
        'createdAt': FieldValue.serverTimestamp(),
      };

  // ── subCategories (global) ───────────────────────────────────────────────
  static const List<Map<String, dynamic>> subCategories = [
    {
      'id': 'sc_coffee_espresso',
      'mainCategory': 'coffee',
      'name': '에스프레소',
      'displayOrder': 10,
      'active': true,
    },
    {
      'id': 'sc_coffee_coldbrew',
      'mainCategory': 'coffee',
      'name': '콜드브루',
      'displayOrder': 20,
      'active': true,
    },
    {
      'id': 'sc_coffee_latte',
      'mainCategory': 'coffee',
      'name': '라떼',
      'displayOrder': 30,
      'active': true,
    },
    {
      'id': 'sc_noncoffee_tea',
      'mainCategory': 'nonCoffee',
      'name': '티',
      'displayOrder': 10,
      'active': true,
    },
    {
      'id': 'sc_noncoffee_smoothie',
      'mainCategory': 'nonCoffee',
      'name': '스무디',
      'displayOrder': 20,
      'active': true,
    },
    {
      'id': 'sc_noncoffee_juice',
      'mainCategory': 'nonCoffee',
      'name': '주스',
      'displayOrder': 30,
      'active': true,
    },
    {
      'id': 'sc_dessert_cake',
      'mainCategory': 'dessert',
      'name': '케이크',
      'displayOrder': 10,
      'active': true,
    },
    {
      'id': 'sc_dessert_bread',
      'mainCategory': 'dessert',
      'name': '빵',
      'displayOrder': 20,
      'active': true,
    },
    {
      'id': 'sc_dessert_sandwich',
      'mainCategory': 'dessert',
      'name': '샌드위치',
      'displayOrder': 30,
      'active': true,
    },
  ];

  // ── global optionGroups ──────────────────────────────────────────────────
  static const List<Map<String, dynamic>> masterOptionGroups = [
    {
      'id': 'og_master_temperature',
      'name': '온도',
      'selectionType': 'single',
      'required': true,
      'displayOrder': 10,
      'items': [
        {'id': 'oi_temp_hot', 'label': 'HOT', 'priceDelta': 0},
        {'id': 'oi_temp_iced', 'label': 'ICED', 'priceDelta': 0},
      ],
    },
    {
      'id': 'og_master_shot',
      'name': '샷 추가',
      'selectionType': 'multi',
      'required': false,
      'displayOrder': 20,
      'items': [
        {'id': 'oi_shot_extra', 'label': '샷 1회 추가', 'priceDelta': 500},
        {'id': 'oi_shot_decaf', 'label': '디카페인 변경', 'priceDelta': 500},
      ],
    },
    {
      'id': 'og_master_syrup',
      'name': '시럽',
      'selectionType': 'multi',
      'required': false,
      'displayOrder': 30,
      'items': [
        {'id': 'oi_syrup_vanilla', 'label': '바닐라 시럽', 'priceDelta': 500},
        {'id': 'oi_syrup_hazelnut', 'label': '헤이즐넛 시럽', 'priceDelta': 500},
        {'id': 'oi_syrup_caramel', 'label': '카라멜 시럽', 'priceDelta': 500},
      ],
    },
  ];

  // ── store-scoped optionGroups ────────────────────────────────────────────
  static const List<Map<String, dynamic>> storeOptionGroups = [
    {
      'id': 'og_store_tumbler',
      'name': '텀블러 할인',
      'selectionType': 'single',
      'required': false,
      'displayOrder': 100,
      'items': [
        {'id': 'oi_tumbler_use', 'label': '텀블러 사용', 'priceDelta': -300},
      ],
    },
  ];

  // ── store ────────────────────────────────────────────────────────────────
  static Map<String, dynamic> storeDoc() => <String, dynamic>{
        'name': '큐레이더 시드 매장',
        'imageUrl':
            'https://images.unsplash.com/photo-1453614512568-c4024d13c247?w=800',
        'location': const GeoPoint(37.5665, 126.9780),
        'averageScore': 0.0,
        'reviewCount': 0,
        'menuCategories': ['coffee', 'nonCoffee', 'dessert'],
        'ownerId': '',
        'phone': '02-0000-0000',
        'address': '서울특별시 중구 세종대로 1',
        'description': 'Phase 1 시드 데이터로 생성된 임시 매장입니다.',
        'businessHours': {
          'openHour': 8,
          'openMinute': 0,
          'closeHour': 22,
          'closeMinute': 0,
        },
        'createdAt': FieldValue.serverTimestamp(),
      };

  // ── menu items (store/{storeId}/menuItems) ───────────────────────────────
  static List<Map<String, dynamic>> menuItems() => <Map<String, dynamic>>[
        {
          'id': 'mi_americano',
          'name': '아메리카노',
          'imageUrl':
              'https://images.unsplash.com/photo-1494314671902-399b18174975?w=600',
          'description': '깔끔한 산미와 묵직한 바디감의 시그니처 아메리카노.',
          'mainCategory': 'coffee',
          'subCategoryId': 'sc_coffee_espresso',
          'basePrice': 4500,
          'optionGroupRefs': [
            {'scope': 'master', 'id': 'og_master_temperature'},
            {'scope': 'master', 'id': 'og_master_shot'},
            {'scope': 'store', 'id': 'og_store_tumbler'},
          ],
          'soldOut': false,
          'displayOrder': 10,
        },
        {
          'id': 'mi_coldbrew',
          'name': '콜드브루',
          'imageUrl':
              'https://images.unsplash.com/photo-1517701604599-bb29b565090c?w=600',
          'description': '12시간 저온 추출한 부드러운 콜드브루.',
          'mainCategory': 'coffee',
          'subCategoryId': 'sc_coffee_coldbrew',
          'basePrice': 5500,
          'optionGroupRefs': [
            {'scope': 'master', 'id': 'og_master_shot'},
            {'scope': 'store', 'id': 'og_store_tumbler'},
          ],
          'soldOut': false,
          'displayOrder': 20,
        },
        {
          'id': 'mi_vanilla_latte',
          'name': '바닐라 라떼',
          'imageUrl':
              'https://images.unsplash.com/photo-1561882468-9110e03e0f78?w=600',
          'description': '진한 에스프레소와 바닐라의 달콤한 조화.',
          'mainCategory': 'coffee',
          'subCategoryId': 'sc_coffee_latte',
          'basePrice': 6000,
          'optionGroupRefs': [
            {'scope': 'master', 'id': 'og_master_temperature'},
            {'scope': 'master', 'id': 'og_master_shot'},
            {'scope': 'master', 'id': 'og_master_syrup'},
            {'scope': 'store', 'id': 'og_store_tumbler'},
          ],
          'soldOut': false,
          'displayOrder': 30,
        },
        {
          'id': 'mi_earl_grey',
          'name': '얼그레이 티',
          'imageUrl':
              'https://images.unsplash.com/photo-1597481499750-3e6b22637e12?w=600',
          'description': '베르가못 향이 깊은 클래식 얼그레이.',
          'mainCategory': 'nonCoffee',
          'subCategoryId': 'sc_noncoffee_tea',
          'basePrice': 5000,
          'optionGroupRefs': [
            {'scope': 'master', 'id': 'og_master_temperature'},
            {'scope': 'store', 'id': 'og_store_tumbler'},
          ],
          'soldOut': false,
          'displayOrder': 40,
        },
        {
          'id': 'mi_strawberry_smoothie',
          'name': '딸기 스무디',
          'imageUrl':
              'https://images.unsplash.com/photo-1553530666-ba11a7da3888?w=600',
          'description': '국산 딸기를 듬뿍 갈아 만든 진한 스무디.',
          'mainCategory': 'nonCoffee',
          'subCategoryId': 'sc_noncoffee_smoothie',
          'basePrice': 6500,
          'optionGroupRefs': [
            {'scope': 'store', 'id': 'og_store_tumbler'},
          ],
          'soldOut': true,
          'displayOrder': 50,
        },
        {
          'id': 'mi_chocolate_cake',
          'name': '클래식 초콜릿 케이크',
          'imageUrl':
              'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=600',
          'description': '진한 다크 초콜릿이 가득한 한 조각.',
          'mainCategory': 'dessert',
          'subCategoryId': 'sc_dessert_cake',
          'basePrice': 7500,
          'optionGroupRefs': <Map<String, dynamic>>[],
          'soldOut': false,
          'displayOrder': 60,
        },
        {
          'id': 'mi_butter_croissant',
          'name': '버터 크루아상',
          'imageUrl':
              'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=600',
          'description': '겹겹이 살아있는 결과 진한 버터 풍미.',
          'mainCategory': 'dessert',
          'subCategoryId': 'sc_dessert_bread',
          'basePrice': 4200,
          'optionGroupRefs': <Map<String, dynamic>>[],
          'soldOut': false,
          'displayOrder': 70,
        },
      ];

  // ── orderLogs (Phase 2 시드) ─────────────────────────────────────────────
  // `users/{uid}/orderLogs/{logId}` 에 기록될 7건 — 4건 최근(<7일)·3건 과거(7~30일).
  // 동일 매장 내 mi_americano 가 4회 등장 → frequentMenuPair 통과.
  // visit 횟수: 큐레이더 시드 매장 7회 → frequentStore 통과.
  //
  // [now] 는 다이얼로그 트리거 시점 DateTime.now(). offset days 만큼 빼서 paidAt 결정.
  static List<Map<String, dynamic>> orderLogs({
    required String uid,
    required DateTime now,
  }) {
    Map<String, dynamic> log({
      required String id,
      required int daysAgo,
      required List<Map<String, dynamic>> items,
    }) {
      final paidAt = now.subtract(Duration(days: daysAgo, hours: 2));
      var total = 0;
      for (final it in items) {
        total += it['lineTotal'] as int;
      }
      return <String, dynamic>{
        'id': id,
        'userId': uid,
        'storeId': storeId,
        'storeName': '큐레이더 시드 매장',
        'items': items,
        'total': total,
        'paidAt': Timestamp.fromDate(paidAt),
        'paymentMethod': 'seed',
      };
    }

    Map<String, dynamic> line({
      required String menuItemId,
      required String menuItemName,
      required int quantity,
      required int unitPrice,
      List<Map<String, dynamic>>? options,
    }) {
      final opts = options ?? const <Map<String, dynamic>>[];
      var optionsTotal = 0;
      for (final o in opts) {
        optionsTotal += (o['priceDelta'] as int? ?? 0);
      }
      final lineTotal = (unitPrice + optionsTotal) * quantity;
      return <String, dynamic>{
        'menuItemId': menuItemId,
        'menuItemName': menuItemName,
        'quantity': quantity,
        'optionsSnapshot': opts,
        'lineTotal': lineTotal,
      };
    }

    final hotIced = <Map<String, dynamic>>[
      {
        'groupId': 'og_master_temperature',
        'groupName': '온도',
        'itemId': 'oi_temp_iced',
        'label': 'ICED',
        'priceDelta': 0,
      },
    ];

    return <Map<String, dynamic>>[
      // 최근 4건
      log(
        id: 'seedlog_today_1',
        daysAgo: 0,
        items: [
          line(
            menuItemId: 'mi_americano',
            menuItemName: '아메리카노',
            quantity: 1,
            unitPrice: 4500,
            options: hotIced,
          ),
          line(
            menuItemId: 'mi_butter_croissant',
            menuItemName: '버터 크루아상',
            quantity: 1,
            unitPrice: 4200,
          ),
        ],
      ),
      log(
        id: 'seedlog_d2',
        daysAgo: 2,
        items: [
          line(
            menuItemId: 'mi_americano',
            menuItemName: '아메리카노',
            quantity: 2,
            unitPrice: 4500,
            options: hotIced,
          ),
        ],
      ),
      log(
        id: 'seedlog_d4',
        daysAgo: 4,
        items: [
          line(
            menuItemId: 'mi_vanilla_latte',
            menuItemName: '바닐라 라떼',
            quantity: 1,
            unitPrice: 6000,
            options: hotIced,
          ),
          line(
            menuItemId: 'mi_chocolate_cake',
            menuItemName: '클래식 초콜릿 케이크',
            quantity: 1,
            unitPrice: 7500,
          ),
        ],
      ),
      log(
        id: 'seedlog_d6',
        daysAgo: 6,
        items: [
          line(
            menuItemId: 'mi_americano',
            menuItemName: '아메리카노',
            quantity: 1,
            unitPrice: 4500,
            options: hotIced,
          ),
        ],
      ),
      // 과거 3건
      log(
        id: 'seedlog_d10',
        daysAgo: 10,
        items: [
          line(
            menuItemId: 'mi_americano',
            menuItemName: '아메리카노',
            quantity: 1,
            unitPrice: 4500,
            options: hotIced,
          ),
        ],
      ),
      log(
        id: 'seedlog_d18',
        daysAgo: 18,
        items: [
          line(
            menuItemId: 'mi_coldbrew',
            menuItemName: '콜드브루',
            quantity: 1,
            unitPrice: 5500,
          ),
        ],
      ),
      log(
        id: 'seedlog_d25',
        daysAgo: 25,
        items: [
          line(
            menuItemId: 'mi_earl_grey',
            menuItemName: '얼그레이 티',
            quantity: 1,
            unitPrice: 5000,
            options: hotIced,
          ),
        ],
      ),
    ];
  }
}

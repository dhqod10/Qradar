# brand_logo_fit — implementation

## 목적
브랜드 로고를 **표시**하는 화면들이 `BoxFit.cover` 로 로고를 잘라 보이던 문제 수정.
로고는 잘리면 안 되므로 `BoxFit.contain` + 중립 배경(`ColoredBox(color: AppColors.surface)`) 으로 변경.
(업로드 폼 `ImageUploadField` / `brand_info_form_page` 는 2026-10-28 에 이미 contain 적용됨 — 이번은 **표시** 화면 정합.)

## 수정 파일 (표시 지점 4곳만)
| 파일 | 위치 | 대상 |
|---|---|---|
| lib/presentation/brand/brand_info/brand_info_page.dart | `_BrandCard` 로고 (72×72) | `brand.logoUrl` |
| lib/presentation/admin/approval/admin_brand_approval_detail_page.dart | 승인 상세 로고 (80×80) | `brand.logoUrl` |
| lib/presentation/admin/approval/admin_approval_queue_page.dart | 브랜드 승인 큐 아이템 (52×52) | `brand.logoUrl` |
| lib/presentation/admin/approval/admin_approval_queue_page.dart | 브랜드-스토어 승인 큐 아이템 (52×52) | `logoUrl` |

변경 패턴(각 지점 동일):
```dart
// before
? Image.network(<URL>, fit: BoxFit.cover)
// after
? ColoredBox(
    color: AppColors.surface,
    child: Image.network(<URL>, fit: BoxFit.contain),
  )
```

## 비범위 (건드리지 않음)
- **메뉴 사진 / 매장 사진**(`item.imageUrl`, `firstImage`, store imageUrls, 메뉴 카드/상세/검색 타일/장바구니 썸네일 등)의 `BoxFit.cover` — 사진은 cover 유지가 맞음.
- 업로드 폼(이미 contain 적용됨).

## 검증
- `flutter analyze` (수정 3개 파일): **No issues found**.
- diff: 3개 파일 28 insertions / 4 deletions — 로고 4곳만. (초기 `dart format` 로 범위 밖 재포맷이 섞였던 건 되돌리고 4곳만 재적용.)
- 실기기 확인: 비정사각 로고가 잘리지 않고 레터박스 중립배경으로 표시되는지 (브랜드 정보 / admin 승인 화면).

## 미구현 / 보류
- 없음. (매장 카드는 브랜드 로고가 아니라 매장 사진이라 범위 제외.)

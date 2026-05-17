# Admin 모듈 디자인 명세 — sub-phase 2 (store_registration_approval)

> 파일 위치: `lib/presentation/admin/approval/`
> 참조: sub-phase 1 `admin_module.md`, sub-phase 1 `common_components.md`

---

## 디자인 결정사항 요약

- **AdminPendingQueuePage 세그먼트 확장**: 기존 2탭 (`브랜드 승인` / `마스터 메뉴 승인`) → 3탭 (`브랜드 승인` / `마스터 메뉴 승인` / `매장 승인`) 으로 확장. 인덱스 2 에 `매장 승인` 추가. 기존 탭 위치 변경 없음.
- **StoreScopeBadge 색상**: `AppColors.info.withOpacity(0.15)` 배경 + `AppColors.info` 텍스트/dot. "개인 매장" 은 정보성 성격 = info 톤.
- **AdminStoreApprovalDetailPage 이미지 영역**: 매장 대표 이미지 (imageUrls[0]) 를 상단 전체 너비로 표시. 없으면 placeholder.
- **수정 대기 라벨**: sub-phase 1 패턴 동일 (`approvedAt != null` 이면 `ApprovalStatusBadge(isRevision: true)` → 라벨 `'수정 대기'`).

---

## 1. AdminPendingQueuePage (수정 — 세그먼트 3탭화)

- 파일: `presentation/admin/approval/admin_approval_queue_page.dart`
- 변경 내용: 세그먼트 탭 바에 `'매장 승인'` 탭 추가 (인덱스 2)

### 세그먼트 탭 바 (3탭)

```
PreferredSize (preferredSize: Size.fromHeight(44))
  └─ Container (border-bottom AppColors.border 1px)
       └─ Row
            ├─ _SegTab('브랜드 승인', index: 0)          ← 기존 그대로
            ├─ _SegTab('마스터 메뉴 승인', index: 1)      ← 기존 그대로
            └─ _SegTab('매장 승인', index: 2)             ← 신규 추가
```

`_SegTab` 스타일: sub-phase 1 admin_module.md 와 동일 (선택 = `AppColors.primary` + 2px 언더라인 / 비선택 = `AppColors.textMuted`).

### body — IndexedStack 확장

```
IndexedStack
  ├─ index 0: _BrandPendingList        ← 기존 그대로
  ├─ index 1: _MasterMenuPendingList   ← 기존 그대로
  └─ index 2: AdminPendingStoresPage   ← 신규
```

### 탭 라벨 pending count 뱃지 (선택적)

sub-phase 1 에서 BadgedSegmentControl 을 도입했다면 매장 세그먼트에도 동일하게 pending count 뱃지 노출. 없으면 라벨만으로 충분.

뱃지 스타일 (적용 시):
- 배경: `AppColors.warning`, radius: 999
- 텍스트: `AppColors.onPrimary`, fontSize 10, w700
- 위치: 라벨 텍스트 우측 상단 (Positioned 또는 Stack)

---

## 2. AdminPendingStoresPage (신규)

- 파일: `presentation/admin/approval/admin_pending_stores_page.dart`
- 역할: status=pending 매장 리스트. `AdminPendingQueuePage` 의 세그먼트 index 2 본문.

### 레이아웃

- 최상위: `Widget` (Scaffold 없음 — `AdminPendingQueuePage` 내 IndexedStack 의 자식)
- 배경: `AppColors.background`
- 스크롤: `ListView.builder` (padding: horizontal 16, vertical 8)

### 데이터

- `WatchPendingStoresForAdminUseCase` stream → `ref.watch`
- 정렬: `submittedAt` 내림차순 (최근 제출이 상단)

### _StoreQueueTile (매장 승인 큐 카드)

```
Card
  ├─ color: AppColors.surfaceElevated
  ├─ radius: 14
  ├─ border: AppColors.border 1px
  ├─ elevation: 0
  ├─ shadow: AppColors.primary.withOpacity(0.04) blurRadius 8
  └─ ListTile (contentPadding: horizontal 16, vertical 10)
       ├─ leading: ClipRRect (radius 10, 56×56)   ← 매장 대표 이미지 (imageUrls[0])
       ├─ title: Row
       │           ├─ Expanded — Text(매장 이름, fontSize 15, w600, AppColors.textHeading, maxLines 1, overflow ellipsis)
       │           └─ SizedBox(width: 6) + StoreScopeBadge('개인 매장')
       ├─ subtitle: Column(crossAxisAlignment: start)
       │              ├─ SizedBox(height: 4)
       │              ├─ Text(store.address, fontSize 12, AppColors.textMuted, maxLines 1, overflow ellipsis)
       │              ├─ SizedBox(height: 2)
       │              ├─ Text('카테고리: {mainCategory}', fontSize 12, AppColors.textMuted)
       │              ├─ SizedBox(height: 4)
       │              ├─ Text('제출: {submittedAt yyyy.MM.dd HH:mm}', fontSize 12, AppColors.textMuted)
       │              └─ (approvedAt != null) SizedBox(height: 2)
       │                                      + Text('수정 대기', fontSize 11, w600, AppColors.warning)
       ├─ trailing: Column (mainAxisAlignment: center)
       │              ├─ ApprovalStatusBadge(status: store.status, isRevision: store.approvedAt != null)
       │              └─ SizedBox(height: 4)
       │              └─ Icon(Icons.chevron_right_rounded, 18, AppColors.textMuted)
       └─ onTap: Navigator.push → AdminStoreApprovalDetailPage(storeId: store.id)
```

**이미지 없을 때 leading placeholder**:
- 배경: `AppColors.surface`
- 아이콘: `Icons.storefront_outlined`, size 26, `AppColors.textMuted`
- ClipRRect radius 10 유지

### 빈 상태

```
Center
  └─ Column
       ├─ Icon(Icons.check_circle_outline_rounded, 56, AppColors.textMuted)
       ├─ SizedBox(height: 20)
       ├─ Text '승인 대기 중인 매장이 없어요', fontSize 16, w600, AppColors.textHeading
       ├─ SizedBox(height: 8)
       └─ Text '새로운 매장 등록 요청이 들어오면 여기에 표시돼요.',
                fontSize 13, AppColors.textMuted, 중앙 정렬
```

- CTA 없음 (admin 은 직접 등록하지 않음)

### 로딩 상태

- `CircularProgressIndicator(color: AppColors.primary)` 화면 중앙 (sub-phase 1 CircularProgressIndicator 통일 패턴)
- shimmer 대신 CircularProgressIndicator 사용 (sub-phase 1 일관성 유지)

### 에러 상태

공통 Error 패턴 (sub-phase 1 common_components.md):

```
Center
  └─ Column
       ├─ Icon(Icons.error_outline_rounded, 48, AppColors.error)
       ├─ SizedBox(height: 16)
       ├─ Text '데이터를 불러오는 데 실패했어요.', fontSize 16, w700, AppColors.textHeading
       ├─ SizedBox(height: 8)
       ├─ Text '일시적인 오류가 발생했어요.\n잠시 후 다시 시도해주세요.',
       │         fontSize 13, AppColors.textMuted, 중앙 정렬
       ├─ SizedBox(height: 24)
       └─ ElevatedButton '다시 시도'
            - 배경: AppColors.primary
            - 텍스트: AppColors.onPrimary, w600
            - radius: 12
            - padding: horizontal 24, vertical 12
            - 탭 → ref.refresh(pendingStoresProvider)
```

---

## 3. AdminStoreApprovalDetailPage (신규)

- 파일: `presentation/admin/approval/admin_store_approval_detail_page.dart`
- 역할: 매장 상세 정보 + 승인/반려 액션. sub-phase 1 의 `AdminBrandApprovalDetailPage` 패턴 계승.

### 레이아웃

- Scaffold
- 배경: `AppColors.background`
- AppBar:
  - leading: `Icons.arrow_back_ios_new_rounded`, color `AppColors.textHeading`
  - title: `'매장 승인 심사'`, fontSize 17, w700, `AppColors.textHeading`
  - backgroundColor: `AppColors.background`, elevation 0, surfaceTintColor: transparent
- body: `SingleChildScrollView`
- bottomNavigationBar: `ApprovalActionsBar` (sub-phase 1 재사용, status 조건에 따라 노출/숨김)

### 주요 섹션 (위→아래)

```
Column
  ├─ [섹션 A] 대표 이미지 (전체 너비, height 220)
  ├─ SizedBox(height: 16)
  ├─ [섹션 B] 매장 이름 + scope 뱃지 + status 배지
  ├─ SizedBox(height: 16)
  ├─ [섹션 C] 핵심 정보 카드 (주소 / 사업자번호 / 카테고리)
  ├─ SizedBox(height: 16)
  ├─ [섹션 D] 운영 정보 카드 (영업시간 / 전화번호 / 소개 / 매장 안내)
  ├─ SizedBox(height: 16)
  ├─ [섹션 E] 제출 정보 카드
  ├─ SizedBox(height: 16)
  └─ (status == rejected) [섹션 F] 기존 반려 사유 카드
```

### 섹션 A — 대표 이미지

```
ClipRRect (radius 0)
  └─ [imageUrls.isNotEmpty ? 이미지 : placeholder]
       height: 220, 전체 너비
```

이미지 없을 때 placeholder:
- 배경: `AppColors.surface`
- 아이콘: `Icons.storefront_outlined`, size 64, `AppColors.textMuted.withOpacity(0.4)`, 중앙

이미지 있을 때:
- `Image.network(imageUrls[0], fit: BoxFit.cover)`

### 섹션 B — 매장 이름 + 뱃지

```
Padding(horizontal 20)
  └─ Column (crossAxisAlignment: start)
       ├─ Row
       │    ├─ Expanded — Text(매장 이름, fontSize 22, w700, AppColors.textHeading)
       │    └─ ApprovalStatusBadge(status, isRevision: store.approvedAt != null, 큰 variant)
       ├─ SizedBox(height: 8)
       └─ StoreScopeBadge('개인 매장')
```

`ApprovalStatusBadge` 큰 variant: height 32, padding horizontal 14 vertical 6, dot 10×10, fontSize 13 w700 (sub-phase 1 common_components.md)

### 섹션 C — 핵심 정보 카드

`_AdminDetailSectionCard` (sub-phase 1 패턴):
- 섹션 헤더: `'매장 정보'`, fontSize 13, w600, `AppColors.textMuted`
- `_InfoRow('주소', store.address)`
- `_InfoRow('사업자등록번호', store.businessRegistrationNumber ?? '미등록')`
- `_InfoRow('카테고리', store.mainCategory)`
- `(store.subCategories.isNotEmpty)` `_InfoRow('서브 카테고리', store.subCategories.join(', '))`

`_AdminDetailSectionCard` 스타일 (sub-phase 1 동일):
- 배경: `AppColors.surfaceElevated`
- border: `AppColors.border` 1px
- radius: 14
- padding: 16
- margin: horizontal 20

`_InfoRow` 스타일 (sub-phase 1 동일):
- `Row(mainAxisAlignment: spaceBetween)`
- 라벨: fontSize 12, `AppColors.textMuted`
- 값: fontSize 13, w500, `AppColors.textBody`
- padding: vertical 6
- 구분선: `Divider(height: 1, color: AppColors.border)` (마지막 항목 제외)

### 섹션 D — 운영 정보 카드

`_AdminDetailSectionCard`:
- 섹션 헤더: `'운영 정보'`, fontSize 13, w600, `AppColors.textMuted`
- `(businessHours != null)` `_InfoRow('영업시간', '${businessHours.openTime} ~ ${businessHours.closeTime}')`
- `(phoneNumber.isNotEmpty)` `_InfoRow('전화번호', store.phoneNumber)`
- `(temporaryClosed)` Row: `Icon(Icons.warning_amber_rounded, 14, AppColors.warning)` + `Text('현재 임시 휴무 중', fontSize 13, w500, AppColors.warning)`
- `(description != null)` `_InfoRow('소개', store.description!)` — 값은 최대 3줄 clamp
- `(notice != null)` `_InfoRow('매장 안내', store.notice!)`

### 섹션 E — 제출 정보 카드

`_AdminDetailSectionCard`:
- 섹션 헤더: `'제출 정보'`, fontSize 13, w600, `AppColors.textMuted`
- `_InfoRow('점주 UID', store.submittedBy ?? '-')`
- `_InfoRow('제출 시각', store.submittedAt != null ? '${yyyy.MM.dd HH:mm}' : '-')`
- `(store.approvedAt != null)` `_InfoRow('이전 처리 시각', '${approvedAt yyyy.MM.dd HH:mm}')`
- `(store.approvedBy != null)` `_InfoRow('처리자 UID', store.approvedBy!)`

### 섹션 F — 반려 사유 카드 (status == rejected 일 때만)

sub-phase 1 `AdminBrandApprovalDetailPage` 의 반려 사유 섹션 동일 스타일:

```
_AdminDetailSectionCard
  (border: AppColors.error.withOpacity(0.3) 1px, 배경: AppColors.error.withOpacity(0.04))
  ├─ Row
  │    ├─ Icon(Icons.info_outline_rounded, 16, AppColors.error)
  │    └─ Text '반려 사유', fontSize 13, w600, AppColors.error
  ├─ SizedBox(height: 8)
  └─ Text(store.rejectedReason ?? '사유 없음', fontSize 13, AppColors.textBody)
```

### ApprovalActionsBar 조건 (sub-phase 1 패턴 동일)

- `status == pending` → `ApprovalActionsBar` 정상 노출 (반려 / 승인)
- `status == approved` → `ApprovalActionsBar` 숨김 + informational 배너:
  ```
  Container
    (color: AppColors.success.withOpacity(0.1), radius 10, padding horizontal 16 vertical 10, margin horizontal 20 bottom 16)
    └─ Text '이미 승인된 매장입니다.', fontSize 13, w500, AppColors.success, 중앙 정렬
  ```
- `status == rejected` → `ApprovalActionsBar` 숨김 + informational 배너:
  ```
  Container
    (color: AppColors.error.withOpacity(0.1), radius 10, padding horizontal 16 vertical 10, margin horizontal 20 bottom 16)
    └─ Text '반려된 매장입니다. 재제출을 기다리세요.', fontSize 13, w500, AppColors.error, 중앙 정렬
  ```

### 인터랙션

- '승인' 탭:
  1. `ApproveStoreUseCase(storeId, adminUid)` 호출
  2. 로딩 중: `ApprovalActionsBar` 두 버튼 disabled + 승인 버튼 내부 `CircularProgressIndicator(크기 20, AppColors.onPrimary)`
  3. 성공 → SnackBar `'매장을 승인했어요'` + `Navigator.pop`
  4. 실패 → SnackBar `'처리에 실패했어요. 다시 시도해주세요'`

- '반려' 탭:
  1. `RejectReasonDialog` 노출 (sub-phase 1 공통 위젯 재사용)
  2. 사유 입력 후 '반려 확정' → `RejectStoreUseCase(storeId, adminUid, reason)` 호출
  3. 성공 → SnackBar `'반려 처리되었습니다'` + `Navigator.pop`
  4. 실패 → SnackBar `'처리에 실패했어요. 다시 시도해주세요'`

### 로딩 상태 (storeId 로 fetch 중)

```
Column
  ├─ Container(color: AppColors.surface, height: 220, width: double.infinity)   ← 이미지 영역 skeleton
  ├─ SizedBox(height: 16)
  └─ Center(child: CircularProgressIndicator(color: AppColors.primary))
```

### 에러 상태 (getById 실패 또는 null 반환)

```
Center
  └─ Column
       ├─ Icon(Icons.error_outline_rounded, 48, AppColors.error)
       ├─ SizedBox(height: 16)
       ├─ Text '매장 정보를 불러오지 못했어요.', fontSize 16, w700, AppColors.textHeading
       ├─ SizedBox(height: 8)
       ├─ Text '매장이 삭제되었거나 접근할 수 없어요.', fontSize 13, AppColors.textMuted, 중앙 정렬
       ├─ SizedBox(height: 24)
       └─ ElevatedButton '돌아가기'
            - 탭 → Navigator.pop
            - 배경: AppColors.primary
            - 텍스트: AppColors.onPrimary, w600
            - radius: 12
```

---

## 4. StoreScopeBadge (신규 위젯)

- 파일: `presentation/admin/widgets/store_scope_badge.dart`
- 역할: 매장의 scope (개인 매장 / 브랜드 매장) 를 시각화하는 인라인 배지. 본 sub-phase 에서는 항상 '개인 매장'.

### 위젯 구조

```
Container (pill)
  └─ Row
       ├─ Icon(Icons.storefront_outlined, 11, AppColors.info)
       ├─ SizedBox(width: 4)
       └─ Text(label, fontSize 11, w600, AppColors.info)
```

### 스타일

- 배경: `AppColors.info.withOpacity(0.12)`
- border: 없음
- radius: 999 (pill)
- height: 22
- padding: horizontal 8, vertical 3
- 아이콘: `Icons.storefront_outlined`, size 11, color `AppColors.info`
- 텍스트: `AppColors.info`, fontSize 11, w600
- 라벨: `'개인 매장'` (고정, sub-phase 3 에서 `'브랜드 매장'` 추가)

### Props

```dart
StoreScopeBadge({required String label})
// 현재: StoreScopeBadge(label: '개인 매장')
// sub-phase 3: StoreScopeBadge(label: '브랜드 매장') 으로 확장 가능
```

---

## 5. 인터랙션 정리 (Admin 모듈)

| 동작 | 반응 |
|---|---|
| `AdminPendingQueuePage` 매장 탭 선택 | IndexedStack index 2 → `AdminPendingStoresPage` 노출 |
| `_StoreQueueTile` 카드 탭 | `AdminStoreApprovalDetailPage(storeId)` Navigator.push |
| `AdminStoreApprovalDetailPage` '승인' | `ApproveStoreUseCase` → SnackBar `'매장을 승인했어요'` + pop |
| `AdminStoreApprovalDetailPage` '반려' | `RejectReasonDialog` → `RejectStoreUseCase` → SnackBar `'반려 처리되었습니다'` + pop |
| `RejectReasonDialog` '취소' | 다이얼로그 pop, 아무 동작 없음 |
| `RejectReasonDialog` 사유 0자 | '반려 확정' 버튼 disabled |

---

## 6. 개발자 전달 특이사항 (Admin 모듈)

### AdminPendingQueuePage 세그먼트 확장

기존 2탭 enum (`brands`, `masterMenus`) 에 `stores` 추가. enum 추가만으로 세그먼트 컨트롤 / IndexedStack 자동 확장 구조라면 최소 변경. 그렇지 않으면 `_SegTab` 목록과 `IndexedStack` children 에 각각 1개씩 추가.

### 공통 위젯 재사용 목록

| 위젯 | 파일 위치 | 재사용 방식 |
|---|---|---|
| `ApprovalStatusBadge` | `presentation/common/widgets/approval_status_badge.dart` | import 그대로 |
| `RejectReasonDialog` | `presentation/common/widgets/reject_reason_dialog.dart` | import 그대로 |
| `ApprovalActionsBar` | `presentation/admin/widgets/approval_actions_bar.dart` | import 그대로 |
| `_AdminDetailSectionCard` | sub-phase 1 Admin 상세 페이지 내부 위젯 | 공통 위젯으로 추출 권장 또는 복사 |
| `_InfoRow` | 동일 | 공통 위젯으로 추출 권장 또는 복사 |

> `_AdminDetailSectionCard` 와 `_InfoRow` 는 sub-phase 1 에서 private 위젯으로 구현되었을 가능성이 높다. 본 sub-phase 에서 재사용이 필요하므로 `presentation/admin/widgets/admin_detail_section_card.dart` 로 분리 추출 권장.

### 이미지 처리 — imageUrls vs imageUrl

기존 `StoreEntity` 는 `imageUrl: String` (단일). sub-phase 2 에서 `imageUrls: List<String>` 로 확장될 가능성 있음 (spec 의 운영 필드 목록에 `imageUrls` / `interiorImages` 가 있음). Admin 상세 화면에서는 `imageUrls.isNotEmpty ? imageUrls[0] : null` 로 대표 이미지만 표시. 나머지 이미지는 본 sub-phase 에서 별도 갤러리 미표시 (MVP).

개발자 확인 필요: `StoreEntity.imageUrl` (String) 을 `imageUrls: List<String>` 으로 마이그레이션할지, 아니면 별도 필드를 추가할지. 마이그레이션 시 기존 imageUrl 사용처 (customer Phase 1a, owner) 영향 없는지 확인.

### 날짜 포맷

`submittedAt`, `approvedAt` 모두 `yyyy.MM.dd HH:mm` 포맷. 기존 sub-phase 1 상세 페이지와 동일.

### admin_store_approval_providers.dart (신규)

`WatchPendingStoresForAdminUseCase`, `ApproveStoreUseCase`, `RejectStoreUseCase`, `GetStoreByIdUseCase` 를 Riverpod provider 로 노출. sub-phase 1 의 `admin_brand_approval_providers.dart` 패턴 동일하게 작성.

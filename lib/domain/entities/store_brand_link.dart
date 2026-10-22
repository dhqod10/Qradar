import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';

/// 매장이 가리키는 브랜드를 admin 이 **무엇으로 읽어야 하는가** (brand_authorization_hardening D5 / design §2).
///
/// 매장 create Rules 는 "존재하는 approved 브랜드" 까지만 막는다 (`brandKey` 가 공개라 가맹 관계를 증명할 수 없다).
/// 실질 통제는 admin 승인이므로, 승인 화면은 admin 이 무엇을 승인하는지 숨김 없이 보여야 한다.
/// 승인 상세 · 승인 대기 목록 배지 · 승인 버튼이 **이 한 함수의 결과**를 공유한다 (같은 사실을 두 화면이 다르게 말하면 안 된다).
enum StoreBrandLinkKind {
  /// 개인 매장 (brandId 없음).
  personal,

  /// 브랜드 조회 중.
  checking,

  /// 브랜드 문서가 있고 승인됨.
  approved,

  /// 브랜드 문서는 있으나 승인 대기/반려.
  unapproved,

  /// 조회는 성공했는데 문서가 없다 (잘못 입력됐거나 지워진 브랜드).
  missing,

  /// 조회 자체가 실패 (네트워크·권한). `없음` 과 구별한다.
  lookupFailed,
}

class StoreBrandLink {
  const StoreBrandLink(this.kind, {this.brandId, this.brand});

  static const StoreBrandLink personal = StoreBrandLink(
    StoreBrandLinkKind.personal,
  );

  final StoreBrandLinkKind kind;
  final String? brandId;

  /// [StoreBrandLinkKind.approved] / [StoreBrandLinkKind.unapproved] 에서만 non-null.
  final BrandEntity? brand;

  bool get hasBrand => kind != StoreBrandLinkKind.personal;

  /// 승인 버튼은 `personal` 과 `approved` 에서만 켜진다 (fail-closed). 반려는 항상 켜져 있다.
  bool get approveEnabled =>
      kind == StoreBrandLinkKind.personal ||
      kind == StoreBrandLinkKind.approved;

  /// 승인 버튼이 꺼진 이유 한 줄 (design §2-f). 켜져 있으면 null.
  String? get approveDisabledReason {
    switch (kind) {
      case StoreBrandLinkKind.personal:
      case StoreBrandLinkKind.approved:
        return null;
      case StoreBrandLinkKind.checking:
        return '브랜드를 확인하고 있어요';
      case StoreBrandLinkKind.unapproved:
        return '승인되지 않은 브랜드라 승인할 수 없어요';
      case StoreBrandLinkKind.missing:
        return '존재하지 않는 브랜드라 승인할 수 없어요';
      case StoreBrandLinkKind.lookupFailed:
        return '브랜드를 확인한 뒤 승인할 수 있어요';
    }
  }
}

/// 브랜드 문서 조회 결과 (Riverpod 비의존).
sealed class BrandLookup {
  const BrandLookup();
}

class BrandLookupLoading extends BrandLookup {
  const BrandLookupLoading();
}

class BrandLookupFailed extends BrandLookup {
  const BrandLookupFailed();
}

class BrandLookupLoaded extends BrandLookup {
  /// null = 조회는 성공했으나 문서가 없다.
  const BrandLookupLoaded(this.brand);
  final BrandEntity? brand;
}

/// 분류 단일 함수. 이름 폴백(`브랜드`) 같은 자리표시를 만들지 않는다 — 이름은 [StoreBrandLink.brand] 가 있을 때만 쓴다.
StoreBrandLink resolveStoreBrandLink({
  required String? brandId,
  required BrandLookup lookup,
}) {
  if (brandId == null || brandId.isEmpty) return StoreBrandLink.personal;
  switch (lookup) {
    case BrandLookupLoading():
      return StoreBrandLink(StoreBrandLinkKind.checking, brandId: brandId);
    case BrandLookupFailed():
      return StoreBrandLink(StoreBrandLinkKind.lookupFailed, brandId: brandId);
    case BrandLookupLoaded(:final brand):
      if (brand == null) {
        return StoreBrandLink(StoreBrandLinkKind.missing, brandId: brandId);
      }
      return StoreBrandLink(
        brand.status == EntityApprovalStatus.approved
            ? StoreBrandLinkKind.approved
            : StoreBrandLinkKind.unapproved,
        brandId: brandId,
        brand: brand,
      );
  }
}

/// 승인하면 이 매장이 따르게 될 적립률의 종류.
enum InheritedRateKind { brand, global, brandDisabled, invalid }

class InheritedRate {
  const InheritedRate(this.kind, this.sentence, this.sub);
  final InheritedRateKind kind;

  /// 한 문장. **승인 상세 블록과 승인 확인 다이얼로그가 글자 그대로 공유한다** (각자 조립 금지).
  final String sentence;
  final String? sub;
}

/// 신규 매장(개별 값 없음)이 승인 후 따르게 될 적립률. `resolveEffectiveQoinRate` 를 매장 값 없음 입력으로 한 번 돌린다.
InheritedRate resolveInheritedRate({
  required BrandEntity brand,
  required QoinRateSetting global,
}) {
  final e = resolveEffectiveQoinRate(
    store: QoinRateSetting.absent,
    brand: brand.qoinAccrualRate,
    brandSwitch: brand.qoinAccrualEnabled,
    global: global,
    hasBrand: true,
  );
  if (e.isInvalid) {
    return const InheritedRate(
      InheritedRateKind.invalid,
      '적립률 설정에 문제가 있어 승인 후에도 적립되지 않을 수 있어요',
      null,
    );
  }
  if (e.isDisabled) {
    return const InheritedRate(
      InheritedRateKind.brandDisabled,
      '브랜드가 적립 사용 안 함이라 이 매장도 적립되지 않아요',
      '브랜드의 ‘적립 사용’ 을 켜야 적립돼요',
    );
  }
  final pct = QoinPolicy.formatRatePercent(e.rate!);
  if (e.source == QoinRateSource.brand) {
    return InheritedRate(
      InheritedRateKind.brand,
      '승인하면 브랜드 "${brand.name}" 의 적립률 $pct 를 따라요',
      '이 매장은 이 값으로 Qoin 을 적립해요',
    );
  }
  return InheritedRate(
    InheritedRateKind.global,
    '승인하면 전역 기본값 $pct 를 따라요',
    '브랜드에 따로 정한 적립률이 없어요',
  );
}

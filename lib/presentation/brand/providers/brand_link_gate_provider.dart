import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/errors/brand_claim_exception.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/presentation/brand/providers/brand_info_providers.dart';

/// `brandId` 가 없는 brand 계정의 진입 게이트 상태 (brand_authorization_hardening D1-2 / design §3).
///
/// 불변: **조회가 끝나기 전이나 실패했을 때 등록 폼을 그리지 않는다.** 폼은 [BrandGateNeedsRegistration] 일 때만 그려진다.
/// 이미 등록한 브랜드가 있는데 연결만 실패한 사용자가 폼으로 떨어지면 같은 브랜드를 다시 등록해 고아 브랜드가 쌓인다.
sealed class BrandGateState {
  const BrandGateState();
}

/// `brands where submittedBy == uid` 조회 중.
class BrandGateChecking extends BrandGateState {
  const BrandGateChecking();
}

/// 조회 실패 — "0건" 이 아니다. 폼으로 가지 않는다.
class BrandGateLookupFailed extends BrandGateState {
  const BrandGateLookupFailed();
}

/// 제출한 브랜드가 0건 -> 등록 폼.
class BrandGateNeedsRegistration extends BrandGateState {
  const BrandGateNeedsRegistration();
}

/// 자동 연결 중 (사용자 조작 0). [totalCount] 가 2 이상이면 가장 이른 1건을 골랐다.
class BrandGateLinking extends BrandGateState {
  const BrandGateLinking({required this.brand, required this.totalCount});
  final BrandEntity brand;
  final int totalCount;
}

/// 연결 성공 — 프로필 스트림(`users.brandId`)이 갱신되면 게이트가 사라진다. 그때까지 `연결 중` 을 유지한다.
class BrandGateLinked extends BrandGateState {
  const BrandGateLinked({required this.brand, required this.totalCount});
  final BrandEntity brand;
  final int totalCount;
}

/// 연결 실패. [failure] 가 terminal 이면 재시도 버튼이 없다 (이미 다른 브랜드 / 내 브랜드 아님).
class BrandGateClaimFailed extends BrandGateState {
  const BrandGateClaimFailed({
    required this.brand,
    required this.totalCount,
    required this.failure,
  });
  final BrandEntity brand;
  final int totalCount;
  final BrandClaimFailure failure;
}

/// 게이트 상태 기계. **진입(평가)당 자동 claim 은 1회**다 — 실패하면 사용자 조작 없이 반복하지 않는다(무한 루프·서버 부하 방지).
/// 재시도는 [retryLookup] / [retryClaim] (사용자 버튼) 이다. 등록 폼이 브랜드를 만든 직후에는 provider 를 invalidate 해
/// 새로 평가시킨다 (방금 만든 브랜드를 찾아 연결한다).
class BrandLinkGateNotifier extends Notifier<BrandGateState> {
  BrandEntity? _target;
  int _count = 0;

  @override
  BrandGateState build() {
    Future.microtask(_evaluate);
    return const BrandGateChecking();
  }

  Future<void> _evaluate() async {
    if (!ref.mounted) return;
    state = const BrandGateChecking();
    final List<BrandEntity> brands;
    try {
      brands = await ref.read(fetchMySubmittedBrandsUseCaseProvider)();
    } catch (_) {
      if (ref.mounted) state = const BrandGateLookupFailed();
      return;
    }
    if (!ref.mounted) return;
    if (brands.isEmpty) {
      state = const BrandGateNeedsRegistration();
      return;
    }
    // 2건 이상: 가장 이른 submittedAt 1건으로 연결하고 나머지는 admin 정리 대상 (spec D1-2). 목록은 이미 그 순서다.
    _target = brands.first;
    _count = brands.length;
    await _claim();
  }

  Future<void> _claim() async {
    final target = _target;
    if (target == null || !ref.mounted) return;
    state = BrandGateLinking(brand: target, totalCount: _count);
    try {
      await ref.read(claimSubmittedBrandUseCaseProvider)(target.id);
      if (ref.mounted) {
        state = BrandGateLinked(brand: target, totalCount: _count);
      }
    } on BrandClaimException catch (e) {
      if (ref.mounted) {
        state = BrandGateClaimFailed(
          brand: target,
          totalCount: _count,
          failure: e.kind,
        );
      }
    } catch (_) {
      if (ref.mounted) {
        state = BrandGateClaimFailed(
          brand: target,
          totalCount: _count,
          failure: BrandClaimFailure.retryable,
        );
      }
    }
  }

  /// `다시 시도` (조회 실패).
  Future<void> retryLookup() => _evaluate();

  /// `다시 연결` (연결 실패 — retryable 만).
  Future<void> retryClaim() => _claim();
}

final brandLinkGateProvider =
    NotifierProvider.autoDispose<BrandLinkGateNotifier, BrandGateState>(
      BrandLinkGateNotifier.new,
    );

import 'package:cloud_functions/cloud_functions.dart';
import 'package:qradar/core/errors/brand_key_issue_exception.dart';
import 'package:qradar/core/errors/brand_key_lookup_exception.dart';
import 'package:qradar/core/errors/store_deletion_exception.dart';
import 'package:qradar/domain/entities/brand_key_lookup.dart';
import 'package:qradar/domain/entities/store_deletion.dart';

/// payment_server_authority 의 서버 권위 callable 3종 (region: asia-northeast3).
///
/// - `lookupBrandByKey` — 점주 매장 등록 폼. `{brandKey}` -> `{brandId, name, logoUrl}`.
/// - `issueBrandKey`    — admin 전용. `{brandId}` -> `{brandKey, alreadyIssued}`. 멱등.
/// - `deleteStore`      — admin 전용. `{storeId, reason?, dryRun}`.
///
/// **SDK 예외는 이 파일 밖으로 나가지 않는다.** 도메인 예외로 변환하며, 서버 message 는 어디에도 싣지 않는다
/// (화면에 새지 않게 — 단, `[STORE_HAS_INFLIGHT_ORDERS]` 토큰은 분류에만 쓰인다).
class AuthorityCallablesRemoteDataSource {
  AuthorityCallablesRemoteDataSource({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final FirebaseFunctions _functions;

  /// `deleteStore` 진행 중 주문 가드 토큰 (spec §11.4). `details` 가 실기기에서 비는 경우가 있어 message 끝도 본다.
  static const String inFlightOrdersToken = '[STORE_HAS_INFLIGHT_ORDERS]';

  // ── lookupBrandByKey ─────────────────────────────────────────────────────

  /// 승인된 브랜드 조회. 실패는 [BrandKeyLookupException].
  Future<BrandKeyLookup> lookupBrandByKey(String brandKey) async {
    final Object? data;
    try {
      final result = await _functions
          .httpsCallable(
            'lookupBrandByKey',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
          )
          .call<Object?>(<String, dynamic>{'brandKey': brandKey});
      data = result.data;
    } on FirebaseFunctionsException catch (e) {
      throw BrandKeyLookupException(classifyLookupCode(e.code));
    } catch (_) {
      throw const BrandKeyLookupException(BrandKeyLookupFailure.failed);
    }
    if (data is! Map) {
      throw const BrandKeyLookupException(BrandKeyLookupFailure.failed);
    }
    final brandId = data['brandId'];
    final name = data['name'];
    if (brandId is! String || brandId.isEmpty || name is! String) {
      // 형식이 깨진 응답은 "없는 키" 가 아니라 "확인하지 못했다" 다.
      throw const BrandKeyLookupException(BrandKeyLookupFailure.failed);
    }
    final logo = data['logoUrl'];
    return BrandKeyLookup(
      brandId: brandId,
      name: name,
      logoUrl: logo is String ? logo : '',
    );
  }

  /// 에러 코드 -> 조회 실패 분류. `invalid-argument`(서버 형식 재검증) 는 not-found 와 같이 취급한다.
  static BrandKeyLookupFailure classifyLookupCode(String code) {
    switch (code) {
      case 'not-found':
      case 'invalid-argument':
        return BrandKeyLookupFailure.notFound;
      case 'resource-exhausted':
        return BrandKeyLookupFailure.rateLimited;
      default:
        return BrandKeyLookupFailure.failed;
    }
  }

  // ── issueBrandKey ────────────────────────────────────────────────────────

  /// 브랜드 키 발급(멱등). 이미 있으면 그 키를 돌려준다. 실패는 [BrandKeyIssueException].
  Future<({String brandKey, bool alreadyIssued})> issueBrandKey(
    String brandId,
  ) async {
    final Object? data;
    try {
      final result = await _functions
          .httpsCallable(
            'issueBrandKey',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
          )
          .call<Object?>(<String, dynamic>{'brandId': brandId});
      data = result.data;
    } on FirebaseFunctionsException catch (e) {
      throw BrandKeyIssueException(code: e.code);
    } catch (_) {
      throw const BrandKeyIssueException();
    }
    final key = data is Map ? data['brandKey'] : null;
    if (key is! String || key.isEmpty) {
      // 키 없는 성공 응답을 성공으로 취급하지 않는다 — 승인이 키 없이 진행되면 안 된다.
      throw const BrandKeyIssueException();
    }
    return (
      brandKey: key,
      alreadyIssued: data is Map && data['alreadyIssued'] == true,
    );
  }

  // ── deleteStore ──────────────────────────────────────────────────────────

  /// `dryRun: true` — 쓰기 0건. 실패는 [StoreDeletionException].
  Future<StoreDeletionPreview> previewDeleteStore(String storeId) async {
    final data = await _callDeleteStore(<String, dynamic>{
      'storeId': storeId,
      'dryRun': true,
    });
    return parsePreview(data);
  }

  /// `deleteStore(dryRun)` 응답 파싱. 숫자를 읽지 못한 응답은 "0건" 이 아니라 실패다 (파괴적 동작 — fail-closed).
  /// 진행 중 주문 수는 `affected.inFlightOrders` 와 `blockedBy.inFlightOrders` 중 큰 쪽 — 한쪽만 와도 가드가 풀리지 않는다.
  static StoreDeletionPreview parsePreview(Map<String, dynamic> data) {
    if (data['alreadyDeleted'] == true) {
      return const StoreDeletionPreview(
        affected: StoreDeletionAffected(),
        alreadyDeleted: true,
      );
    }
    final affected = data['affected'];
    if (affected is! Map) {
      throw const StoreDeletionException(StoreDeletionFailure.failed);
    }
    int n(Object? v) => v is num ? v.toInt() : 0;
    final blocked = data['blockedBy'];
    final inFlight = [
      n(affected['inFlightOrders']),
      if (blocked is Map) n(blocked['inFlightOrders']),
    ].reduce((a, b) => a > b ? a : b);
    return StoreDeletionPreview(
      affected: StoreDeletionAffected(
        menuItems: n(affected['menuItems']),
        menuOverrides: n(affected['menuOverrides']),
        subCategories: n(affected['subCategories']),
        optionGroups: n(affected['optionGroups']),
        qoinRateHistory: n(affected['qoinRateHistory']),
        images: n(affected['images']),
        inFlightOrders: inFlight,
      ),
    );
  }

  /// `dryRun: false`. 실패는 [StoreDeletionException].
  Future<StoreDeletionResult> deleteStore(
    String storeId, {
    required String reason,
  }) async {
    final data = await _callDeleteStore(<String, dynamic>{
      'storeId': storeId,
      'reason': reason,
      'dryRun': false,
    });
    final id = data['deletionId'];
    return StoreDeletionResult(
      deletionId: id is String ? id : null,
      alreadyDeleted: data['alreadyDeleted'] == true,
    );
  }

  Future<Map<String, dynamic>> _callDeleteStore(
    Map<String, dynamic> payload,
  ) async {
    final Object? data;
    try {
      final result = await _functions
          .httpsCallable(
            'deleteStore',
            // 서브컬렉션·Storage 삭제가 길 수 있다 — CF 최대 시간에 맞춘다.
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 120),
            ),
          )
          .call<Object?>(payload);
      data = result.data;
    } on FirebaseFunctionsException catch (e) {
      throw StoreDeletionException(
        classifyDeleteError(e.code, e.message),
        code: e.code,
      );
    } catch (_) {
      throw const StoreDeletionException(StoreDeletionFailure.failed);
    }
    if (data is! Map) {
      throw const StoreDeletionException(StoreDeletionFailure.failed);
    }
    return Map<String, dynamic>.from(data);
  }

  /// 에러 코드 + message 끝 토큰 -> 분류. 토큰 없는 `failed-precondition` 은 가드로 읽지 않는다
  /// (다른 사전조건 실패를 "새 주문" 이라고 말하지 않는다).
  static StoreDeletionFailure classifyDeleteError(
    String code,
    String? message,
  ) {
    if (code == 'failed-precondition' &&
        (message ?? '').trimRight().endsWith(inFlightOrdersToken)) {
      return StoreDeletionFailure.inFlightOrders;
    }
    if (code == 'not-found') return StoreDeletionFailure.notFound;
    return StoreDeletionFailure.failed;
  }
}

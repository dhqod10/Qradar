import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_results.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';

/// Qoin 적립률 쓰기(Cloud Function 전담) + 변경 이력 조회.
///
/// 쓰기는 Firestore 직접 쓰기가 아니라 callable 이다 — 값과 이력을 같은 트랜잭션에 쓰기 위해서다.
/// 실패는 [QoinRateException] 으로 확정 실패 / 결과 불명을 구분해 던진다.
abstract class QoinRateRepository {
  /// 한 범위의 적립률 설정. [rate] 비율(0 = 적립 안 함) 또는 [clear] (상위 설정 따르기) 중 정확히 하나.
  /// [targetId] 는 global 이면 null.
  Future<QoinRateSetResult> setRate({
    required QoinRateScope scope,
    String? targetId,
    double? rate,
    bool clear = false,
    String? reason,
  });

  /// 브랜드 값 설정 + 산하 매장 개별 설정 처리. [resumeHistoryId] 가 있으면 partial 재개.
  Future<QoinBulkApplyResult> applyBrandRate({
    required String brandId,
    double? rate,
    bool clear = false,
    required QoinBulkMode mode,
    String? reason,
    String? resumeHistoryId,
  });

  /// 한 대상의 이력 (최신순). 점주/브랜드/admin 공용.
  Stream<List<QoinRateChangeEntity>> watchHistory(
    QoinRateScope scope,
    String targetId, {
    required int limit,
  });

  /// 전체 이력 (admin 전용, collectionGroup, 최신순).
  Stream<List<QoinRateChangeEntity>> watchAllHistory({required int limit});
}

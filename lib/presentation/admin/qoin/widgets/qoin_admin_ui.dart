import 'package:flutter/material.dart';
import 'package:qradar/core/errors/qoin_rate_exception.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/domain/entities/qoin_rate_results.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';

/// 관리자 Qoin 화면 공용 AppBar (1차와 동일: 뒤로가기 + 17/w700, `background`, elevation 0).
PreferredSizeWidget qoinAppBar(BuildContext context, String title, {bool canPop = true}) {
  return AppBar(
    automaticallyImplyLeading: false,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textBody),
      onPressed: canPop ? () => Navigator.of(context).pop() : null,
    ),
    title: Text(title),
    titleTextStyle: const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: AppColors.textHeading,
    ),
    backgroundColor: AppColors.background,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
  );
}

void qoinSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

/// Qoin 관리자 화면 문구 (design §15-b). SnackBar 문구가 한 곳에 있어야 어긋나지 않는다.
class QoinMessages {
  QoinMessages._();

  static const String saveFailed = '저장에 실패했어요. 다시 시도해주세요';
  static const String bulkFailed = '적용하지 못했어요. 다시 시도해주세요';
  static const String resumeFailed = '이어서 적용하지 못했어요. 잠시 후 다시 시도해주세요';

  /// 결과 불명 — 서버에서는 반영됐을 수 있다. **재시도를 권하지 않는다**
  /// (이미 적용됐는데 다시 누르면 같은 값의 중복 이력/덮어쓰기가 생긴다).
  static const String unknownOutcome = '결과를 확인하지 못했어요. 변경 이력에서 적용 여부를 확인해주세요';

  static const String enabledOn = 'Qoin 적립을 시작했어요';
  static const String enabledOff = 'Qoin 적립을 중단했어요';
  static const String enabledFailed = '변경하지 못했어요. 다시 시도해주세요';

  /// 일괄 적용이 진행 중인 브랜드(또는 그 산하 매장)에 대한 단건 변경 거부 (`failed-precondition`).
  static const String bulkInProgress =
      '이 브랜드에 일괄 적용이 진행 중이에요. 끝난 뒤 다시 시도해주세요';

  /// 재개 시 브랜드 값이 그 사이 바뀌었다 (`failed-precondition`).
  static const String resumeStale = '브랜드 값이 그 뒤에 변경됐어요. 다시 적용하세요';

  /// TRANSITIONAL(spec §20.4.5): 일괄 적용 레거시 0 가드.
  static String legacyZeroGuard(int count) =>
      '레거시 0% 매장 $count곳이 있어요. Qoin 설정 허브에서 마이그레이션을 먼저 실행하세요';

  /// 스위치 변경 성공 SnackBar. [scope] 는 store 또는 brand.
  static String switchChanged(QoinRateScope scope, {required bool enabled}) {
    final who = scope == QoinRateScope.brand ? '이 브랜드' : '이 매장';
    return enabled ? '$who의 적립을 다시 시작했어요' : '$who의 적립을 중단했어요';
  }

  /// 실패 분류별 문구. [bulk]/[resume] 로 확정 실패 문구가 달라진다.
  static String failure(
    Object e, {
    bool bulk = false,
    bool resume = false,
    bool switchChange = false,
  }) {
    if (e is QoinRateException && e.isUnknownOutcome) return unknownOutcome;
    if (e is QoinRateException && e.code == 'failed-precondition') {
      // TRANSITIONAL(spec §20.4.5): 레거시 0 가드
      if (e.isLegacyZeroGuard) return legacyZeroGuard(e.legacyZeroCount!);
      return resume ? resumeStale : bulkInProgress;
    }
    if (resume) return resumeFailed;
    if (switchChange) return enabledFailed;
    return bulk ? bulkFailed : saveFailed;
  }

  /// 단일 범위 저장 성공. [global] 이면 `전역 기본값을 N% 로 변경했어요`.
  static String saved(QoinRateValue value, {required bool global}) {
    switch (value) {
      case QoinRateValueRate(:final tenths):
        final pct = QoinPolicy.formatTenths(tenths);
        return global ? '전역 기본값을 $pct% 로 변경했어요' : '적립률을 $pct% 로 변경했어요';
      case QoinRateValueInherit():
        return '상위 설정을 따르도록 되돌렸어요';
    }
  }
}

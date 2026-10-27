import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/constants/app_client_level.dart';
import 'package:qradar/core/utils/client_update.dart';
import 'package:qradar/domain/repositories/app_config_repository.dart';
import 'package:qradar/domain/usecases/check_client_update_required_use_case.dart';

/// payment_price_authority H-01 — 최소 클라이언트 수준 게이트. 방향이 핵심이다: **막는 건 구버전임이 확인됐을 때뿐**.
class _Repo implements AppConfigRepository {
  _Repo({this.min, this.error, this.hang = false});
  final int? min;
  final Object? error;
  final bool hang;

  @override
  Future<int?> fetchMinClientLevel() async {
    if (hang) return Completer<int?>().future;
    if (error != null) throw error!;
    return min;
  }
}

Future<bool> _check(_Repo r, {int level = 1}) =>
    CheckClientUpdateRequiredUseCase(
      r,
      clientLevel: level,
      timeout: const Duration(milliseconds: 50),
    )();

void main() {
  test('순수 판정: min 이 client 보다 클 때만 true', () {
    expect(isClientUpdateRequired(clientLevel: 1, minClientLevel: 2), isTrue);
    expect(isClientUpdateRequired(clientLevel: 2, minClientLevel: 2), isFalse);
    expect(isClientUpdateRequired(clientLevel: 3, minClientLevel: 2), isFalse);
    expect(
      isClientUpdateRequired(clientLevel: 1, minClientLevel: null),
      isFalse,
    );
  });

  test('구버전으로 확인됨 → 막는다', () async {
    expect(await _check(_Repo(min: 2)), isTrue);
  });

  test('충분한 수준 / 설정 없음 → 막지 않는다', () async {
    expect(await _check(_Repo(min: 1)), isFalse);
    expect(await _check(_Repo(min: null)), isFalse);
  });

  test('확인 실패(예외) → 막지 않는다 (게이트가 정상 결제를 멈추면 안 된다)', () async {
    expect(await _check(_Repo(error: StateError('offline'))), isFalse);
  });

  test('시간 초과 → 막지 않는다', () async {
    expect(await _check(_Repo(hang: true)), isFalse);
  });

  test('이 빌드의 수준은 1 이다 (서버 minClientLevel 이 2 이상이 되기 전까지 이 빌드는 막히지 않는다)', () {
    expect(kPaymentClientLevel, 1);
  });
}

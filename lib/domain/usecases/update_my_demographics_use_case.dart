import 'package:qradar/domain/entities/demographics.dart';
import 'package:qradar/domain/repositories/user_repository.dart';

/// 본인 성별·출생연도를 저장한다 (선택 수집, 통계 전용).
///
/// 둘 다 null 이어도 **저장을 호출한다** — 값이 아니라 "물어봤다"(`demographicsAskedAt`) 를 남기는 게
/// 목적이기 때문이다. 그래야 앱을 열 때마다 다시 묻지 않는다.
///
/// 출생연도는 만 [kMinSignupAge]세 이상만 받는다. 이용약관이 그 아래 연령의 가입을 제한하므로,
/// 알고도 저장하면 약관 위반 상태를 보관하는 셈이 된다. 범위를 벗어나면 [ArgumentError]
/// (값은 메시지에 넣지 않는다 — 로그에 남을 수 있다).
class UpdateMyDemographicsUseCase {
  final UserRepository _repository;
  UpdateMyDemographicsUseCase(this._repository);

  Future<void> call({
    required String uid,
    Gender? gender,
    int? birthYear,
    /// 나이 계산 기준 연도. 테스트가 고정값을 넣을 수 있게 주입받는다.
    DateTime? now,
  }) {
    if (birthYear != null) {
      final nowYear = (now ?? DateTime.now()).year;
      if (!isValidBirthYear(birthYear, nowYear: nowYear)) {
        throw ArgumentError('birth year out of range');
      }
    }
    return _repository.updateMyDemographics(
      uid: uid,
      gender: gender,
      birthYear: birthYear,
    );
  }
}

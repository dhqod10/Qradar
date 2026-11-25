import 'package:characters/characters.dart';
import 'package:qradar/domain/repositories/user_repository.dart';

/// 표시 이름 최대 길이. 가입 화면(`email_signup_page`)의 입력 제한과 **같은 값이어야 한다** —
/// 가입 때 통과한 이름이 수정 화면에서 길다고 거부되면 안 된다.
const int kDisplayNameMaxLength = 20;

/// 본인 표시 이름을 저장한다.
///
/// 저장 전에 앞뒤 공백을 떼고 검증한다. 빈 값이거나 최대 길이를 넘으면 저장하지 않고
/// [ArgumentError] (이름 자체는 메시지에 넣지 않는다 — 로그에 남을 수 있다).
class UpdateMyDisplayNameUseCase {
  final UserRepository _repository;
  UpdateMyDisplayNameUseCase(this._repository);

  Future<void> call({required String uid, required String displayName}) {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('display name is empty');
    }
    if (trimmed.characters.length > kDisplayNameMaxLength) {
      throw ArgumentError('display name too long');
    }
    return _repository.updateMyDisplayName(uid: uid, displayName: trimmed);
  }
}

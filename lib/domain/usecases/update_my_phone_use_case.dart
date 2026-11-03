import 'package:qradar/core/utils/phone_validator.dart';
import 'package:qradar/domain/repositories/user_repository.dart';

/// 본인 전화번호를 저장한다. 형식이 틀리면 저장하지 않고 [ArgumentError] (값은 메시지에 넣지 않음).
class UpdateMyPhoneUseCase {
  final UserRepository _repository;
  UpdateMyPhoneUseCase(this._repository);

  Future<void> call({required String uid, required String phone}) {
    if (!isValidKoreanMobile(phone)) {
      throw ArgumentError('invalid phone format');
    }
    return _repository.updateMyPhone(uid: uid, phone: phone);
  }
}

/// 한국 휴대폰 번호 검증 (숫자만 10~11자리). signup 과 전화 수집 시트가 공유하는 단일 소스.
final RegExp kKoreanMobilePattern = RegExp(r'^01[016789]\d{7,8}$');

/// 전화번호 최대 입력 길이.
const int kPhoneMaxLength = 11;

bool isValidKoreanMobile(String phone) => kKoreanMobilePattern.hasMatch(phone);

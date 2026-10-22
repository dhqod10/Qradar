import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/entities/qoin_config_entity.dart';
import 'package:qradar/presentation/common/providers/qoin_di_providers.dart';

/// `config/qoin` (null = 문서 없음). 고객은 안내 문구, 관리자는 편집 화면, 점주·브랜드는 읽기 행이 사용한다.
final qoinConfigProvider = StreamProvider<QoinConfigEntity?>((ref) {
  return ref.watch(watchQoinConfigUseCaseProvider)();
});

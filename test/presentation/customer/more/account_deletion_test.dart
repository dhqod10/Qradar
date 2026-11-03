import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/errors/account_deletion_exception.dart';
import 'package:qradar/data/datasources/remote/account_deletion_remote_data_source.dart';
import 'package:qradar/domain/entities/account_deletion_preview.dart';
import 'package:qradar/presentation/customer/more/account_deletion/account_deletion_page.dart';

void main() {
  const ok = AccountDeletionPreview(inFlightOrderCount: 0, qoinToForfeit: 100);
  const blocked = AccountDeletionPreview(
    inFlightOrderCount: 2,
    qoinToForfeit: 0,
  );

  group('canSubmitAccountDeletion (fail-closed)', () {
    test('일치 + 로드 성공 + 비차단 + 비처리 → true (앞뒤 공백 허용)', () {
      expect(
        canSubmitAccountDeletion(
          preview: ok,
          input: ' 탈퇴합니다 ',
          processing: false,
        ),
        isTrue,
      );
    });
    test('불일치/조합 중 입력 → false', () {
      for (final i in ['', '탈퇴합니', '탈퇴 합니다', '탈퇴합니다.', 'ㅌ']) {
        expect(
          canSubmitAccountDeletion(preview: ok, input: i, processing: false),
          isFalse,
          reason: i,
        );
      }
    });
    test('미리보기 미로드/진행중주문/처리중/차단 → 일치해도 false', () {
      expect(
        canSubmitAccountDeletion(
          preview: null,
          input: '탈퇴합니다',
          processing: false,
        ),
        isFalse,
      );
      expect(
        canSubmitAccountDeletion(
          preview: blocked,
          input: '탈퇴합니다',
          processing: false,
        ),
        isFalse,
      );
      expect(
        canSubmitAccountDeletion(preview: ok, input: '탈퇴합니다', processing: true),
        isFalse,
      );
      expect(
        canSubmitAccountDeletion(
          preview: ok,
          input: '탈퇴합니다',
          processing: false,
          blocked: true,
        ),
        isFalse,
      );
    });
  });

  group('AccountDeletionRemoteDataSource 분류/파싱', () {
    test('토큰 있는 failed-precondition → inFlightOrders, 토큰 없으면 failed', () {
      expect(
        AccountDeletionRemoteDataSource.classifyError(
          'failed-precondition',
          '진행 중 [ACCOUNT_HAS_INFLIGHT_ORDERS]',
        ),
        AccountDeletionFailure.inFlightOrders,
      );
      expect(
        AccountDeletionRemoteDataSource.classifyError(
          'failed-precondition',
          '기타',
        ),
        AccountDeletionFailure.failed,
      );
      expect(
        AccountDeletionRemoteDataSource.classifyError('unauthenticated', null),
        AccountDeletionFailure.unauthenticated,
      );
      expect(
        AccountDeletionRemoteDataSource.classifyError('internal', null),
        AccountDeletionFailure.failed,
      );
    });
    test('parsePreview: 정상/숫자 누락은 실패', () {
      final p = AccountDeletionRemoteDataSource.parsePreview({
        'dryRun': true,
        'inFlightOrders': 1,
        'qoinToForfeit': 50,
      });
      expect(p.inFlightOrderCount, 1);
      expect(p.qoinToForfeit, 50);
      expect(p.canDelete, isFalse);
      expect(
        () => AccountDeletionRemoteDataSource.parsePreview({'dryRun': true}),
        throwsA(isA<AccountDeletionException>()),
      );
    });
  });
}

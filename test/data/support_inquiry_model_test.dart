import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/errors/support_inquiry_exception.dart';
import 'package:qradar/data/datasources/remote/support_inquiry_remote_data_source.dart';
import 'package:qradar/data/models/support_inquiry_model.dart';
import 'package:qradar/domain/entities/support_inquiry_category.dart';
import 'package:qradar/domain/entities/support_inquiry_status.dart';
import 'package:qradar/domain/repositories/support_inquiry_repository.dart';
import 'package:qradar/domain/usecases/create_support_inquiry_use_case.dart';

void main() {
  group('SupportInquiryModel.fromMap', () {
    test('모르는 status 는 closed, 모르는 category 는 etc (안전한 쪽)', () {
      final m = SupportInquiryModel.fromMap('i', {
        'status': 'weird',
        'category': 'weird',
        'createdAt': Timestamp.fromDate(DateTime(2026, 11, 24)),
      });
      expect(m.status, SupportInquiryStatus.closed);
      expect(m.category, SupportInquiryCategory.etc);
      expect(m.toEntity().hasUnreadAnswer, isFalse);
    });

    test('answered + answer + answerReadAt null → 미확인 / 읽으면 해제', () {
      Map<String, dynamic> data({Object? read}) => {
        'status': 'answered',
        'answer': {'body': '답변', 'answeredBy': 'adm'},
        'answerReadAt': read,
        'createdAt': Timestamp.now(),
      };
      expect(
        SupportInquiryModel.fromMap('i', data()).toEntity().hasUnreadAnswer,
        isTrue,
      );
      expect(
        SupportInquiryModel.fromMap(
          'i',
          data(read: Timestamp.now()),
        ).toEntity().hasUnreadAnswer,
        isFalse,
      );
    });

    test('답변 후 종결(closed)된 미확인 건도 dot, 철회·답변 없음은 dot 없음', () {
      bool unread(Map<String, dynamic> d) => SupportInquiryModel.fromMap('i', {
        'createdAt': Timestamp.now(),
        ...d,
      }).toEntity().hasUnreadAnswer;
      const ans = {'body': '답변', 'answeredBy': 'adm'};
      expect(unread({'status': 'closed', 'answer': ans}), isTrue);
      expect(
        unread({
          'status': 'closed',
          'answer': ans,
          'answerReadAt': Timestamp.now(),
        }),
        isFalse,
      );
      expect(unread({'status': 'closed'}), isFalse);
      expect(unread({'status': 'withdrawn', 'answer': ans}), isFalse);
      expect(unread({'status': 'open'}), isFalse);
    });

    test('필드 누락·오염에도 던지지 않는다', () {
      final m = SupportInquiryModel.fromMap('i', {
        'imageUrls': 'oops',
        'answer': 3,
        'orderSnapshot': 'x',
      });
      expect(m.imageUrls, isEmpty);
      expect(m.answer, isNull);
      expect(m.orderSnapshot, isNull);
    });

    test('철회·읽음 patch 키 집합 = Rules 화이트리스트 (drift 방지)', () {
      expect(SupportInquiryModel.patchForWithdraw().keys.toSet(), {
        'status',
        'withdrawnAt',
        'updatedAt',
      });
      expect(SupportInquiryModel.patchForAnswerRead().keys.toSet(), {
        'answerReadAt',
        'updatedAt',
      });
      expect(SupportInquiryModel.patchForWithdraw()['status'], 'withdrawn');
    });
  });

  group('classifyCode', () {
    final c = SupportInquiryRemoteDataSource.classifyCode;
    test('details.reason / message 토큰', () {
      expect(
        c('resource-exhausted', 'x [SUPPORT_RATE_LIMITED]', null),
        SupportInquiryFailure.rateLimited,
      );
      expect(
        c('invalid-argument', 'x', {'reason': 'SUPPORT_INVALID_ATTACHMENT'}),
        SupportInquiryFailure.invalidAttachment,
      );
      expect(
        c('not-found', '주문 [SUPPORT_ORDER_NOT_FOUND]', null),
        SupportInquiryFailure.orderNotFound,
      );
      expect(
        c('permission-denied', '[SUPPORT_ACCOUNT_DELETED]', null),
        SupportInquiryFailure.accountDeleted,
      );
    });
    test('토큰 없는 code 분류 / raw message 는 무시', () {
      expect(c('unavailable', 'boom', null), SupportInquiryFailure.network);
      expect(
        c('unauthenticated', null, null),
        SupportInquiryFailure.unauthenticated,
      );
      expect(c('internal', 'secret stack', null), SupportInquiryFailure.failed);
    });
  });

  group('CreateSupportInquiryUseCase.validate', () {
    CreateSupportInquiryInput input({
      String title = 't',
      String body = 'b',
      int images = 0,
    }) => CreateSupportInquiryInput(
      inquiryId: 'id',
      category: SupportInquiryCategory.order,
      title: title,
      body: body,
      imageUrls: List.filled(images, 'u'),
    );
    void ok(CreateSupportInquiryInput i) =>
        CreateSupportInquiryUseCase.validate(i);
    void bad(CreateSupportInquiryInput i) => expect(
      () => CreateSupportInquiryUseCase.validate(i),
      throwsA(isA<SupportInquiryException>()),
    );

    test('경계값', () {
      ok(input(title: 'a' * 60, body: 'a' * 2000, images: 3));
      bad(input(title: 'a' * 61));
      bad(input(body: 'a' * 2001));
      bad(input(title: '   '));
      bad(input(body: ''));
      bad(input(images: 4));
    });
  });
}

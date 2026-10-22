import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/errors/review_submit_exception.dart';
import 'package:qradar/core/utils/grade_calculator.dart';
import 'package:qradar/core/utils/qrator_name.dart';
import 'package:qradar/core/utils/review_window.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/order_status.dart';
import 'package:qradar/domain/entities/payment_channel.dart';
import 'package:qradar/domain/entities/payment_info_entity.dart';
import 'package:qradar/domain/entities/payment_method.dart';
import 'package:qradar/domain/entities/review_entity.dart';
import 'package:qradar/domain/entities/store_grade.dart';
import 'package:qradar/domain/repositories/review_repository.dart';
import 'package:qradar/domain/usecases/submit_store_review_use_case.dart';

class _FakeRepo implements ReviewRepository {
  final calls = <Map<String, Object?>>[];

  @override
  Future<void> upsertReview({
    required String storeId,
    required String userId,
    required String orderId,
    required StoreGrade grade,
    String? comment,
  }) async {
    calls.add({
      'storeId': storeId,
      'userId': userId,
      'orderId': orderId,
      'grade': grade,
      'comment': comment,
    });
  }

  @override
  Stream<ReviewEntity?> watchMyReview({
    required String storeId,
    required String userId,
  }) => const Stream.empty();

  @override
  Stream<List<ReviewEntity>> watchStoreReviews(String storeId, {int? limit}) =>
      const Stream.empty();
}

final _now = DateTime.utc(2026, 10, 22, 12);

OrderEntity _order({
  OrderStatus status = OrderStatus.completed,
  String userId = 'u1',
  String storeId = 's1',
  DateTime? completedAt,
}) {
  return OrderEntity(
    id: 'o1',
    userId: userId,
    storeId: storeId,
    storeName: 'store',
    subtotal: 4500,
    totalPrice: 4500,
    status: status,
    paymentInfo: PaymentInfoEntity(
      method: PaymentMethod.card,
      channel: PaymentChannel.toss,
      paymentKey: 'pk',
      approvedAt: DateTime.utc(2026, 10, 1),
      amount: 4500,
    ),
    createdAt: DateTime.utc(2026, 10, 1),
    updatedAt: DateTime.utc(2026, 10, 1),
    completedAt: completedAt,
  );
}

void main() {
  group('U1 GradeCalculator.fromAverage 경계', () {
    test('경계값', () {
      expect(GradeCalculator.fromAverage(4.0), StoreGrade.s);
      expect(GradeCalculator.fromAverage(3.5), StoreGrade.s);
      expect(GradeCalculator.fromAverage(3.49), StoreGrade.a);
      expect(GradeCalculator.fromAverage(2.5), StoreGrade.a);
      expect(GradeCalculator.fromAverage(2.49), StoreGrade.b);
      expect(GradeCalculator.fromAverage(1.5), StoreGrade.b);
      expect(GradeCalculator.fromAverage(1.49), StoreGrade.c);
      expect(GradeCalculator.fromAverage(1.0), StoreGrade.c);
    });
  });

  group('U2 StoreGrade score/fromString/asString 왕복', () {
    test('4등급 전부', () {
      const expectedScore = {
        StoreGrade.s: 4,
        StoreGrade.a: 3,
        StoreGrade.b: 2,
        StoreGrade.c: 1,
      };
      for (final g in StoreGrade.values) {
        expect(StoreGrade.fromString(g.asString), g);
        expect(g.score, expectedScore[g]);
      }
    });
  });

  group('U3 SubmitStoreReviewUseCase 자격 검증', () {
    late _FakeRepo repo;
    late SubmitStoreReviewUseCase useCase;
    setUp(() {
      repo = _FakeRepo();
      useCase = SubmitStoreReviewUseCase(repo);
    });

    Future<void> submit(OrderEntity o, {String storeId = 's1'}) => useCase(
      storeId: storeId,
      userId: 'u1',
      order: o,
      grade: StoreGrade.s,
      now: _now,
    );

    Matcher failure(ReviewSubmitFailure f) => throwsA(
      isA<ReviewSubmitException>().having((e) => e.reason, 'reason', f),
    );

    test('정상: completed / 본인 / 매장 일치 / 기한 내', () async {
      await submit(_order(completedAt: _now.subtract(const Duration(days: 3))));
      expect(repo.calls, hasLength(1));
      expect(repo.calls.single['orderId'], 'o1');
    });

    test('status != completed', () {
      expect(
        submit(_order(status: OrderStatus.paid)),
        failure(ReviewSubmitFailure.orderNotCompleted),
      );
    });

    test('타인 주문', () {
      expect(
        submit(_order(userId: 'other')),
        failure(ReviewSubmitFailure.notOrderOwner),
      );
    });

    test('storeId 불일치', () {
      expect(
        submit(_order(), storeId: 's2'),
        failure(ReviewSubmitFailure.storeMismatch),
      );
    });

    test('14일 초과', () {
      expect(
        submit(_order(completedAt: _now.subtract(const Duration(days: 15)))),
        failure(ReviewSubmitFailure.windowExpired),
      );
    });

    test('실패 시 저장소 호출 없음', () async {
      await expectLater(
        submit(_order(status: OrderStatus.ready)),
        throwsA(anything),
      );
      expect(repo.calls, isEmpty);
    });

    test('공백 코멘트는 null 로 전달, 앞뒤 공백은 trim', () async {
      await useCase(
        storeId: 's1',
        userId: 'u1',
        order: _order(),
        grade: StoreGrade.a,
        comment: '   ',
        now: _now,
      );
      await useCase(
        storeId: 's1',
        userId: 'u1',
        order: _order(),
        grade: StoreGrade.a,
        comment: '  좋아요 ',
        now: _now,
      );
      expect(repo.calls[0]['comment'], isNull);
      expect(repo.calls[1]['comment'], '좋아요');
    });
  });

  group('U5 ReviewWindow (14일)', () {
    test('completedAt == null -> 허용', () {
      expect(ReviewWindow.isExpired(null, _now), isFalse);
    });
    test('13일 허용 / 15일 만료', () {
      expect(
        ReviewWindow.isExpired(_now.subtract(const Duration(days: 13)), _now),
        isFalse,
      );
      expect(
        ReviewWindow.isExpired(_now.subtract(const Duration(days: 15)), _now),
        isTrue,
      );
    });
    test('정확히 14일은 허용, 1초 초과부터 만료', () {
      expect(
        ReviewWindow.isExpired(_now.subtract(const Duration(days: 14)), _now),
        isFalse,
      );
      expect(
        ReviewWindow.isExpired(
          _now.subtract(const Duration(days: 14, seconds: 1)),
          _now,
        ),
        isTrue,
      );
    });
    test('카운트다운 캡션', () {
      String? cap(Duration ago) =>
          ReviewWindow.countdownCaption(_now.subtract(ago), _now);
      expect(cap(const Duration(days: 5)), isNull); // 남은 9일
      expect(cap(const Duration(days: 11)), '3일 후 평가 기간이 끝나요');
      expect(cap(const Duration(days: 12, hours: 6)), '2일 후 평가 기간이 끝나요');
      expect(
        cap(const Duration(days: 10, hours: 23)),
        isNull,
      ); // 남은 3일+1시간 -> 4일
      expect(cap(const Duration(days: 13, hours: 12)), '오늘까지 평가할 수 있어요');
      expect(cap(const Duration(days: 15)), isNull); // 만료
      expect(ReviewWindow.countdownCaption(null, _now), isNull);
    });
  });

  group('maskedQratorName', () {
    test('같은 uid 는 항상 같은 코드 (결정적)', () {
      expect(maskedQratorName('a3f9xyz'), maskedQratorName('a3f9xyz'));
    });

    test('코드는 4자리 16진수', () {
      final name = maskedQratorName('dUFcFv71FzVA4feodWnxv3k0MKF3');
      expect(name, startsWith('Qrator '));
      final code = name.substring('Qrator '.length);
      expect(code.length, 4);
      expect(RegExp(r'^[0-9a-f]{4}$').hasMatch(code), isTrue);
    });

    // 회귀: uid 앞 4자 방식은 provider 접두사 때문에 소셜 로그인 사용자가
    // 전부 같은 코드가 됐다 (kakao_ -> 'kaka', naver_ -> 'nave').
    test('같은 provider 접두사를 가진 uid 들이 서로 다른 코드', () {
      final kakao = [
        maskedQratorName('kakao_1234567890'),
        maskedQratorName('kakao_9876543210'),
        maskedQratorName('kakao_1111111111'),
      ];
      expect(kakao.toSet().length, 3);

      final naver = [
        maskedQratorName('naver_abcdefgh'),
        maskedQratorName('naver_ijklmnop'),
      ];
      expect(naver.toSet().length, 2);
    });

    test('provider 가 달라도 접두사가 코드에 드러나지 않음', () {
      expect(maskedQratorName('kakao_1234567890'), isNot(contains('kaka')));
      expect(maskedQratorName('naver_abcdefgh'), isNot(contains('nave')));
    });

    test('짧은 uid / 빈 uid 방어', () {
      expect(maskedQratorName('ab'), startsWith('Qrator '));
      expect(maskedQratorName('ab').length, 'Qrator '.length + 4);
      expect(maskedQratorName(''), 'Qrator');
    });
  });
}

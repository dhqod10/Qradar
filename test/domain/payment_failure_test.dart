import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/errors/verify_payment_failure.dart';
import 'package:qradar/domain/entities/payment_failure.dart';
import 'package:qradar/presentation/customer/cart/cart_line_availability.dart';
import 'package:qradar/presentation/customer/checkout/payment_failure_copy.dart';

VerifyPaymentFailure _v(
  String message, [
  String code = 'failed-precondition',
]) => VerifyPaymentFailure(code: code, message: message);

void main() {
  group('PaymentFailure.from — 토큰 파싱 (spec §15.1)', () {
    test('MENU_SOLD_OUT:id1,id2 -> 갈래 B, id 2개', () {
      final f = PaymentFailure.from(_v('품절된 메뉴가 있어요 [MENU_SOLD_OUT:id1,id2]'));
      expect(f.family, PaymentFailureFamily.gate);
      expect(f.reason, PaymentFailureReason.menuSoldOut);
      expect(f.menuItemIds, ['id1', 'id2']);
    });

    test('알려진 6개 사유 전부 갈래 B', () {
      for (final r in PaymentFailureReason.values.where(
        (r) => r != PaymentFailureReason.unknown,
      )) {
        final token = r.isMenuReason ? '[${r.token}:a1]' : '[${r.token}]';
        final f = PaymentFailure.from(_v('문장 $token'));
        expect(f.family, PaymentFailureFamily.gate, reason: r.token);
        expect(f.reason, r);
      }
    });

    test('메뉴 사유 아닌 토큰의 ids 는 무시', () {
      final f = PaymentFailure.from(_v('x [STORE_NOT_SELLABLE:a,b]'));
      expect(f.reason, PaymentFailureReason.storeNotSellable);
      expect(f.menuItemIds, isEmpty);
    });

    test('READ_FAILED (unavailable) 토큰이 살아 있다', () {
      final f = PaymentFailure.from(
        _v('일시적인 오류예요 [READ_FAILED]', 'unavailable'),
      );
      expect(f.family, PaymentFailureFamily.gate);
      expect(f.reason, PaymentFailureReason.readFailed);
    });

    test('id 정규식 불통과 조각은 폐기, 중복 제거', () {
      final f = PaymentFailure.from(
        _v('x [MENU_EXCLUDED:ok1,,${'a' * 65},ok1,ok-2_]'),
      );
      expect(f.menuItemIds, ['ok1', 'ok-2_']);
    });

    test('토큰 없음 -> 갈래 C', () {
      for (final input in <Object>[
        _v('Unable to resolve host', 'unavailable'),
        Exception('boom'),
        StateError('x'),
        '',
      ]) {
        final f = PaymentFailure.from(input);
        expect(f.family, PaymentFailureFamily.unknown);
        expect(f.rawCode, isNull);
      }
    });

    test('모르는 토큰 -> 갈래 C (+ 형식 통과한 식별자만 캡션용으로 남김)', () {
      final f = PaymentFailure.from(_v('x [BRAND_NEW_REASON:a1]'));
      expect(f.family, PaymentFailureFamily.unknown);
      expect(f.reason, PaymentFailureReason.unknown);
      expect(f.rawCode, 'BRAND_NEW_REASON');
    });

    test('토큰이 message 끝이 아니면 읽지 않는다', () {
      final f = PaymentFailure.from(_v('[MENU_SOLD_OUT:a1] 뒤에 문장'));
      expect(f.family, PaymentFailureFamily.unknown);
    });

    test('STORE_HAS_INFLIGHT_ORDERS (admin 전용) 는 결제 화면에서 갈래 C', () {
      final f = PaymentFailure.from(_v('x [STORE_HAS_INFLIGHT_ORDERS]'));
      expect(f.family, PaymentFailureFamily.unknown);
    });

    test('launch: 형식 불통과 code 는 버린다', () {
      expect(PaymentFailure.launch(errorCode: 'bad code <b>').rawCode, isNull);
      expect(
        PaymentFailure.launch(errorCode: 'NOT_ENOUGH_BALANCE').launchCode,
        'NOT_ENOUGH_BALANCE',
      );
      expect(PaymentFailure.launch().family, PaymentFailureFamily.launch);
    });
  });

  group('가드 (design §9.2 / spec §18.3 6-c)', () {
    String texts(PaymentFailure f) => [
      f.family.name,
      f.reason.name,
      ...f.menuItemIds,
      f.launchCode ?? '',
      f.rawCode ?? '',
    ].join('|');

    test('ⓐ 임의 입력 문자열이 결과의 어떤 텍스트에도 포함되지 않는다', () {
      final inputs = <String>[
        'Exception: 서버 원문 문장입니다',
        '서버가 보낸 이상한 문장 [UNKNOWN_THING:zzz]',
        '품절된 메뉴가 있어요 [MENU_SOLD_OUT:id1,<script>]',
        'FirebaseFunctionsException(internal): secret detail',
        '결제가 거절되었습니다 [A]',
        '   ',
        '한글 [MENU_NOT_FOUND:가나다,id9]',
      ];
      for (final input in inputs) {
        for (final f in [
          PaymentFailure.from(input),
          PaymentFailure.from(_v(input)),
          PaymentFailure.from(Exception(input)),
        ]) {
          final out = texts(f);
          expect(
            out.contains(input.trim()) && input.trim().isNotEmpty,
            isFalse,
            reason: input,
          );
          // 한글/공백 등 식별자 문법 밖 문자는 어디에도 새지 않는다.
          expect(RegExp(r'[가-힣 ]').hasMatch(f.rawCode ?? ''), isFalse);
          for (final id in f.menuItemIds) {
            expect(RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(id), isTrue);
          }
        }
      }
    });

    test('ⓑ 알려진 8개 사유 각각이 design §3.1 의 헤드라인·주 버튼을 가진다', () {
      const expectedHeadline = {
        PaymentFailureReason.menuSoldOut: '품절된 메뉴가 있어요',
        PaymentFailureReason.menuExcluded: '판매가 중단된 메뉴가 있어요',
        PaymentFailureReason.menuNotFound: '메뉴 정보가 바뀌었어요',
        PaymentFailureReason.priceMismatch: '메뉴 가격이 바뀌었어요',
        PaymentFailureReason.optionUnavailable: '선택하신 옵션이 바뀌었어요',
        PaymentFailureReason.storeNotSellable: '지금은 이 매장에서 주문할 수 없어요',
        PaymentFailureReason.storeNotFound: '매장 정보를 찾을 수 없어요',
        PaymentFailureReason.readFailed: '일시적인 오류가 생겼어요',
      };
      const expectedPrimary = {
        PaymentFailureReason.menuSoldOut: '카트에서 확인하기',
        PaymentFailureReason.menuExcluded: '카트에서 확인하기',
        PaymentFailureReason.menuNotFound: '카트에서 확인하기',
        PaymentFailureReason.priceMismatch: '최신 가격으로 다시 담기',
        PaymentFailureReason.optionUnavailable: '카트에서 확인하기',
        PaymentFailureReason.storeNotSellable: '카트로 돌아가기',
        PaymentFailureReason.storeNotFound: '카트 비우고 메뉴 보러가기',
        PaymentFailureReason.readFailed: '카트로 돌아가기',
      };
      final known = PaymentFailureReason.values.where(
        (r) => r != PaymentFailureReason.unknown,
      );
      // 사유가 추가되면 표(위 const)에 행이 없어 실패한다.
      expect(expectedHeadline.keys.toSet(), known.toSet());
      for (final r in known) {
        final c = gateFailureCopy(r, hasNames: true);
        expect(c.headline, expectedHeadline[r], reason: r.token);
        expect(c.primaryLabel, expectedPrimary[r], reason: r.token);
        expect(c.body, isNotEmpty);
      }
      // 이름을 모르는 MENU_NOT_FOUND 는 카트 비우기 변형 (design §3.1 변경점).
      final noName = gateFailureCopy(
        PaymentFailureReason.menuNotFound,
        hasNames: false,
      );
      expect(noName.primaryLabel, '카트 비우고 메뉴 보러가기');
      expect(noName.listHeader, isNull);
    });

    test('ⓒ 갈래 C 문구에 `요금`/`청구` 가 없다', () {
      final all = [
        kUnknownHeadline,
        kUnknownBody,
        kUnknownSubBody,
        kUnknownPrimaryLabel,
        kUnknownSecondaryLabel,
      ].join(' ');
      expect(all.contains('요금'), isFalse);
      expect(all.contains('청구'), isFalse);
    });

    test('ⓓ CartLineAvailability 에 verified / ok 가 없다 (design N2)', () {
      final names = CartLineAvailability.values.map((v) => v.name).toSet();
      // optionUnavailable 은 위반이다 (payment_price_authority design §5.5) — "확인됨" 이 아니다.
      expect(names, {
        'normal',
        'soldOut',
        'unavailable',
        'optionUnavailable',
        'rejectedByServer',
      });
      expect(names.contains('verified'), isFalse);
      expect(names.contains('ok'), isFalse);
      expect(names.contains('priceChecked'), isFalse);
    });

    test('돈 줄은 갈래 B 상수에만 있다', () {
      expect(kGateMoneyLine, contains('요금'));
    });
  });
}

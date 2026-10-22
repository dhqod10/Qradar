import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/data/models/review_model.dart';
import 'package:qradar/domain/entities/store_grade.dart';

void main() {
  group('U4 ReviewModel.fromMap', () {
    test('정상 문서', () {
      final created = DateTime.utc(2026, 10, 1);
      final updated = DateTime.utc(2026, 10, 2);
      final m = ReviewModel.fromMap('s_u', {
        'storeId': 's',
        'userId': 'u',
        'orderId': 'o',
        'grade': 'A',
        'score': 3,
        'comment': 'hi',
        'createdAt': Timestamp.fromDate(created),
        'updatedAt': Timestamp.fromDate(updated),
      });
      final e = m.toEntity();
      expect(e.id, 's_u');
      expect(e.orderId, 'o');
      expect(e.grade, StoreGrade.a);
      expect(e.comment, 'hi');
      expect(e.createdAt.isAtSameMomentAs(created), isTrue);
      expect(e.updatedAt!.isAtSameMomentAs(updated), isTrue);
    });

    test('필드 누락 -> 안전한 기본값, updatedAt/comment 는 null', () {
      final m = ReviewModel.fromMap('x', const {});
      expect(m.storeId, '');
      expect(m.userId, '');
      expect(m.orderId, '');
      expect(m.grade, StoreGrade.c);
      expect(m.comment, isNull);
      expect(m.updatedAt, isNull);
    });

    test('score 없이도 grade 로 복원 (score 는 읽지 않는다)', () {
      final m = ReviewModel.fromMap('x', {'grade': 'S'});
      expect(m.grade, StoreGrade.s);
    });

    test('잘못된 grade 문자열 -> C 폴백, 소문자 허용', () {
      expect(ReviewModel.fromMap('x', {'grade': 'Z'}).grade, StoreGrade.c);
      expect(ReviewModel.fromMap('x', {'grade': 's'}).grade, StoreGrade.s);
    });
  });

  group('쓰기 페이로드', () {
    test('create: serverTimestamp, score 비정규화, 코멘트 없으면 키 없음', () {
      final p = ReviewModel.toFirestoreForCreate(
        storeId: 's',
        userId: 'u',
        orderId: 'o',
        grade: StoreGrade.b,
      );
      expect(p['score'], 2);
      expect(p['createdAt'], isA<FieldValue>());
      expect(p.containsKey('comment'), isFalse);
      expect(p.keys.toSet(), {
        'storeId',
        'userId',
        'orderId',
        'grade',
        'score',
        'createdAt',
      });
    });

    test('update: 허용 필드만, 코멘트 없으면 FieldValue.delete', () {
      final p = ReviewModel.toFirestoreForUpdate(
        orderId: 'o',
        grade: StoreGrade.s,
      );
      expect(p.keys.toSet(), {
        'orderId',
        'grade',
        'score',
        'comment',
        'updatedAt',
      });
      expect(p['score'], 4);
      expect(p['comment'], isA<FieldValue>());
      expect(p['updatedAt'], isA<FieldValue>());
    });

    test('docId 규칙', () {
      expect(ReviewModel.docId('s', 'u'), 's_u');
    });
  });
}

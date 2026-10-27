import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/data/models/store_model.dart';

/// payment_server_authority §6.8 — 반려는 approvedAt 을 쓰지 않는다 (rejectedAt 분리).
/// approvedAt 이 승인 행위에서만 쓰여야 결제 게이트의 승인 이력 판정(canSellNow)이 반려 매장에 오염되지 않는다.
void main() {
  StoreModel store() => StoreModel(
    id: 's',
    name: 'S',
    imageUrl: '',
    latitude: 0,
    longitude: 0,
    averageScore: 0,
    reviewCount: 0,
    menuCategories: const [],
    createdAt: DateTime(2026),
  );

  test('rejectFields: rejectedAt 을 쓰고 approvedAt 은 쓰지 않는다', () {
    final m = StoreModel.rejectFields('adm', '사유');
    expect(m['status'], 'rejected');
    expect(m['rejectedReason'], '사유');
    expect(m['approvedBy'], 'adm');
    expect(m['rejectedAt'], isA<FieldValue>());
    expect(
      m.containsKey('approvedAt'),
      isFalse,
      reason: '반려가 approvedAt 에 값을 쓰면 F-02 가 되살아난다',
    );
  });

  test('approveFields: approvedAt 만 쓴다 (승인 행위에서만)', () {
    final m = StoreModel.approveFields('adm');
    expect(m['approvedAt'], isA<FieldValue>());
    expect(m.containsKey('rejectedAt'), isFalse);
    expect(m['rejectedReason'], isNull);
  });

  test('재제출: 승인 메타 4종 모두 null 클리어 (Rules 의 rejected→pending 전이 제약 충족)', () {
    final m = store().toFirestoreForCoreUpdate(isResubmit: true);
    for (final k in [
      'approvedBy',
      'approvedAt',
      'rejectedAt',
      'rejectedReason',
    ]) {
      expect(m.containsKey(k), isTrue, reason: k);
      expect(m[k], isNull, reason: k);
    }
  });

  test('일반 핵심 필드 수정(승인 매장): 승인 메타를 건드리지 않는다 (approvedAt 보존 → R2 불변식)', () {
    final m = store().toFirestoreForCoreUpdate(isResubmit: false);
    for (final k in [
      'approvedBy',
      'approvedAt',
      'rejectedAt',
      'rejectedReason',
    ]) {
      expect(m.containsKey(k), isFalse, reason: k);
    }
  });

  test('fromFirestore 대응 필드: 엔티티 왕복에서 rejectedAt 이 보존된다', () {
    final at = DateTime(2026, 10, 27);
    final m = StoreModel(
      id: 's',
      name: 'S',
      imageUrl: '',
      latitude: 0,
      longitude: 0,
      averageScore: 0,
      reviewCount: 0,
      menuCategories: const [],
      createdAt: DateTime(2026),
      rejectedAt: at,
    );
    expect(m.toEntity().rejectedAt, at);
    expect(StoreModel.fromEntity(m.toEntity()).rejectedAt, at);
  });
}

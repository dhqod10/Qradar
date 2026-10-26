// RECOVERY(2026-10-26): `brands` 컬렉션 삭제 사고 복구 전용. 확인 후 이 파일을 삭제한다.
//
// Console 에서 `brands` 를 통째로 지워 ChaCha / 낫심플 / Q브루어리(시드) 문서가
// 사라졌다. PITR 과 예약 백업이 꺼져 있어 자동 복구가 불가능했다.
//
// 기존 `runPhase1Seed` 로는 복구할 수 없다. 그 함수가 한 batch 안에서
// `users/{uid}/orderLogs` 까지 쓰는데, 그 경로는 `allow create: if false`(CF 전담)라
// 거부되고 **batch 는 원자적이라 전체가 실패**한다.
//
// 그래서 브랜드 문서만 쓰는 경로를 따로 둔다. 매장·카테고리·주문로그를 건드리지
// 않아 영향 범위도 작다. `brands` create 는 admin 이면 통과한다 (firestore.rules).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/core/constants/firestore_paths.dart';
import 'package:qradar/dev/seed/phase1_seed_data.dart';

class BrandRecoveryResult {
  final List<String> ids;
  const BrandRecoveryResult(this.ids);

  String summary() => '브랜드 ${ids.length}건\n${ids.join('\n')}';
}

/// 삭제된 브랜드 문서를 **원본과 같은 ID** 로 복원한다.
///
/// ID 를 유지하는 것이 핵심이다. `stores.brandId` 가 살아 있으므로 같은 ID 로
/// 만들면 매장 ↔ 브랜드 연결이 그대로 돌아온다.
Future<BrandRecoveryResult> runBrandRecovery({
  FirebaseFirestore? firestore,
}) async {
  final db = firestore ?? FirebaseFirestore.instance;
  final batch = db.batch();
  final ids = <String>[];

  // 운영 브랜드 2건 (스크린샷 + brand_authorization_hardening/spec.md §11 기준)
  Phase1SeedData.recoveryBrandDocs().forEach((id, data) {
    batch.set(db.collection(FirestorePaths.brands).doc(id), data,
        SetOptions(merge: true));
    ids.add(id);
  });

  // 시드 브랜드 1건 + 마스터 메뉴
  final seedRef =
      db.collection(FirestorePaths.brands).doc(Phase1SeedData.brandId);
  batch.set(seedRef, Phase1SeedData.brandDoc(), SetOptions(merge: true));
  ids.add(Phase1SeedData.brandId);

  for (final bm in Phase1SeedData.brandMasterMenuItems()) {
    final id = bm['id'] as String;
    final data = Map<String, dynamic>.from(bm)
      ..remove('id')
      ..['createdAt'] = FieldValue.serverTimestamp();
    batch.set(
      seedRef.collection(FirestorePaths.brandMenuItems).doc(id),
      data,
      SetOptions(merge: true),
    );
  }

  await batch.commit();
  return BrandRecoveryResult(ids);
}

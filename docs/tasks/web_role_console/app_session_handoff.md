# 앱 세션 인계 노트 — `lib/` · `functions/` · `firestore.rules` 영역

작성 2026-10-29. 작성자: 웹 콘솔(`landing/`) 작업 세션.

웹 관리자 콘솔(`web_admin_console`) 구현과 역할별 콘솔(`web_role_console`) 설계 과정에서
**앱 영역의 문제 5건**을 발견했다. 그 영역은 이 세션에서 읽기 전용이라 고치지 않았다.

각 항목에 **[확인됨]** / **[확인 필요]** 를 붙였다. 확인됨은 코드를 직접 읽고 재현 경로까지 확인한 것이고,
확인 필요는 정황은 있으나 호출부까지 보지 못한 것이다. 우선순위는 그쪽에서 판단할 일이다.

> 줄번호 주의: `firestore.rules` 는 `store_category_optout` Phase A·B 에서 822 → **825줄**이 됐다.
> 아래 줄번호는 **825줄 기준(2026-10-29)** 이다.

---

## 1. ⚠️ 소셜 로그인 CF 가 토큰 수신자를 검증하지 않는다 **[확인됨 — 심각도 정정]**

**위치**: `functions/src/verifyKakaoToken.ts` · `functions/src/verifyNaverToken.ts`

두 CF 모두 받은 `accessToken` 으로 공급자 프로필 API 를 호출하고, 돌아온 `id` 를 그대로 믿어
`createCustomToken('kakao_' + id)` 를 발급한다. **그 토큰이 어느 카카오/네이버 앱에서 발급된
것인지 확인하지 않는다.**

```ts
// verifyKakaoToken.ts
const profileRes = await axios.get("https://kapi.kakao.com/v2/user/me", {
  headers: { Authorization: `Bearer ${data.accessToken}` },
});
kakaoUid = profileRes.data.id;              // ← 출처 검증 없음
const uid = `kakao_${kakaoUid}`;
const customToken = await admin.auth().createCustomToken(uid, { provider: "kakao" });
```

> ### ⚠️ 심각도 정정 (2026-10-29, 앱 세션 검증 후)
>
> **최초 작성에서 이 항목을 "피해자 계정 직접 탈취" 로 서술했는데 과장이었다.**
>
> 카카오 회원번호는 **앱 단위 스코프**다(앱 그룹으로 묶이지 않는 한). 따라서 공격자 앱에서 받은
> 토큰을 재사용해도 `kakao_<다른 id>` 로 매핑되어 **피해자의 Qradar 계정에 닿지 않는다.**
> "id 충돌에 기대지 않는다" 는 최초 서술은 **틀렸다.**
>
> **실제 분류**: 계정 탈취 경로 ❌ → **표준 하드닝 누락 + 조건부 위험** ⭕

**남는 위험**

1. **앱 그룹**: 공격자 앱이 Qradar 의 카카오 앱과 **같은 앱 그룹**에 묶여 있으면 회원번호를
   공유하므로 직접 탈취가 성립한다. 현재 앱 그룹 구성은 확인하지 못했다.
2. **네이버**: 앱 세션 판단으로 **스코프 특성이 달라 더 노출될 수 있다.** 별도 확인이 필요하다.
3. **인증 없는 계정 생성**: 이 CF 은 임의의 외부 토큰으로 **Firebase 계정을 만들 수 있는
   엔드포인트**다. 탈취는 아니지만 남용·할당량 문제는 남는다.
4. **표준 하드닝**: 토큰 수신자 검증은 소셜 로그인 백엔드의 기본 요건이고, 지금은 없다.

**현재 노출**: 웹과 무관하게 **앱 경로로 이미 존재한다.** 웹 콘솔은 아직 소셜 로그인이 없다.

**표준 해법**
- 카카오: `https://kapi.kakao.com/v1/user/access_token_info` 로 `app_id` 가 우리 앱인지 검증
- 네이버: 클라이언트가 보낸 accessToken 을 받지 말고, **서버가 authorization code 를 자기
  client secret 으로 교환**하는 흐름으로 전환

**웹 콘솔과의 관계**: 고객 섹션(리뷰·게시글·QnA)에 웹 소셜 로그인을 붙일 계획이다. 고객 다수가
카카오/네이버로 보이기 때문이다. **그 전에 이 검증을 넣어두는 편이 좋다** — 안 그러면 같은 구멍에
표면이 하나 더 붙는다.

---

## 2. 🔴 브랜드가 자기 제출물을 스스로 승인할 수 있다 — Rules 비대칭 **[확인됨]**

**위치**: `firestore.rules:605-609` (`brands/{brandId}/menuItems`), `:490-494` (`stores/*/menuOverrides`)

```
match /brands/{brandId}/menuItems/{menuItemId} {
  allow read: if isSignedIn();
  allow create, update, delete:
    if isAdmin() || isBrandHolder(brandId);     // ← 필드 제한 없음
}
```

브랜드 보유자에게 **필드 화이트리스트가 없다.** `status`, `approvedBy`, `approvedAt` 을 직접 쓸 수 있다.
`stores/*/menuOverrides` 의 브랜드 분기도 같다(`:492`). 점주 분기만 `onlyChangedFields([...])` 로 좁다.

즉 **승인 경계를 Rules 가 집행하지 않고, 앱 리포지토리의 `_assertAdminOnly` 만 집행한다.**
클라이언트 코드가 유일한 방어선이다. 스크립트로 SDK 를 직접 호출하면 우회된다.

이 비대칭은 의도된 것일 수도 있다(브랜드에게 자기 트리 전권을 주는 설계). 다만 **의도라면 문서에,
아니라면 Rules 에** 있어야 한다. 지금은 어느 쪽인지 코드만 보고 알 수 없다.

---

## 3. ⚠️ `cascadeDeleteOverrides` 가 no-op 이다 — 고아 데이터 **[확인됨]**

**위치**: `lib/data/datasources/remote/master_menu_item_remote_data_source.dart:146-154`

```dart
/// cascade: 모든 매장의 `menuOverrides/{masterMenuItemId}` batch delete (S9).
/// 본 sub-phase: 대상 컬렉션(`menuOverrides`) 자체가 없으므로 항상 0건.
Future<void> cascadeDeleteOverrides(String masterMenuItemId) async {
  // sub-phase 3 에서 menuOverrides 가 도입된 후 실제 동작.
  // 현재는 no-op.
  debugPrint('... menuOverrides 컬렉션은 sub-phase 3 에서 활성화됩니다.');
}
```

**주석의 전제가 더 이상 맞지 않는다.** `menuOverrides` 는 지금 살아 있다 — Rules(`:484-498`),
리포지토리(`menu_override_repository_impl.dart`), 시드에 모두 있다.

따라서 **마스터 메뉴를 삭제해도 각 매장의 오버라이드가 남는다.** 삭제된 마스터를 가리키는
고아 문서가 쌓이고, 같은 id 로 마스터가 재생성되면 과거 오버라이드(가격·제외·품절)가
**되살아난다.**

> 참고 — 설계 문서(`web_role_console/spec.md`)에 "cascade delete 가 490건 청크 배치를 써서
> Rules 문서 접근 상한 20회에 걸린다" 고 적혀 있는데 **그건 사실이 아니다.** 위처럼 delete 는
> 아무 일도 하지 않는다. 490 청크는 **브랜드 일괄 제외 create** 경로
> (`menu_override_remote_data_source.dart:132`)에 있다. 그쪽은 한 배치의 모든 문서가 **같은
> `storeId`** 를 보므로 Rules 의 `get(stores/{storeId})` 가 한 경로에 집중된다 —
> 동일 경로 중복 `get()` 이 1회로 집계되는지에 따라 갈리고, **실측이 필요하다.**
> 설계 문서 쪽은 이 노트 기준으로 정정이 필요하다.

---

## 4. ⚠️ 점주 오버라이드 create 에 `masterMenuItemId` 필드가 빠진다 **[확인됨]**

**위치**: `lib/data/repositories/menu_override_repository_impl.dart:162-178` (`existing == null` 분기)

점주 경로가 만드는 문서에는 `masterMenuItemId` **필드가 없다.** 문서 ID 로만 존재한다.

```dart
final data = <String, dynamic>{
  'storeId': override.storeId,
  'brandId': override.brandId,
  // 'masterMenuItemId' 없음
  'priceOverride': null,
  'excluded': false,
  ...
};
```

반면 **브랜드 일괄 제외 경로는 넣는다** (`menu_override_remote_data_source.dart:136`):

```dart
batch.set(ref, {
  'masterMenuItemId': masterMenuItemId,   // ← 이쪽은 있다
  'storeId': storeId,
  ...
}, SetOptions(merge: true));
```

**영향**: `menuOverrides` 를 `masterMenuItemId` 로 거르는 **컬렉션 그룹 쿼리가 점주 생성분을
놓친다.** 위 3번의 cascade 를 살릴 때, 그리고 가격 감사(`auditOrderPriceIntegrity`)
같은 집계에서 문제가 된다. `price_audit_remote_data_source.dart:124` 가 이 필드를 읽는다.

**웹 콘솔 쪽 처리**: 콘솔은 create 시 이 필드를 **넣도록** 설계했다. 다만 앱이 계속 빼면
데이터가 두 모양으로 섞인 채 남는다.

---

## 5. ✅ 품절 토글 옵션 덮어쓰기 — **문제 없음으로 판정됨** (2026-10-29, 앱 세션 검증)

> **결론: 결함이 아니다.** 앱 세션이 호출부를 확인한 결과 —
> `owner_store_menu_list_page._toggleSoldOut` 가 두 경로 모두
> `item.copyWith(soldOut:)` / `override.copyWith(soldOut:)` 로 **현재 항목에서 복사해** 넘긴다.
> 리포지토리가 3필드를 함께 쓰지만 호출부가 빈 배열이 아닌 **현재값**을 넘기므로 덮어쓰기가 없다.
> `disabled*` 를 빈 배열로 넘기는 경로는 **존재하지 않는다.** 남는 것은 이론상 좁은 stale-read
> 레이스뿐이고, 옵션을 날리는 버그가 아니다.
>
> 아래는 최초 제보 당시의 서술이다(리포지토리만 보고 [확인 필요] 로 올렸던 것). 기록으로 남긴다.

**위치**: `lib/data/repositories/menu_override_repository_impl.dart:169-171, 191-194`

create·update 양쪽 모두 `soldOut` · `disabledOptionGroupIds` · `disabledOptionItemIds` **3개를
함께** 쓴다. 리포지토리 API 로는 자연스러운 모양이다.

문제가 되는 경우는 **호출부가 품절만 바꾸려 하면서 `disabled*` 를 빈 배열로 채운 엔티티를
넘길 때**다. 그러면 기존 옵션 비활성 설정이 조용히 날아간다.

**호출부(`lib/presentation/owner/store_menu/**`)를 확인하지 못했다.** 리포지토리만 보고는
실제 결함인지 단정할 수 없어 [확인 필요] 로 남긴다. 설계 문서에는 "결함 ⓐ" 로 적혀 있으나
그 판단의 근거까지는 따라가지 못했다.

웹 콘솔은 품절 토글 시 **`soldOut`·`updatedBy`·`updatedAt` 3키만** 보내도록 설계해
이 경로를 복제하지 않는다.

---

## 6. ℹ️ 브랜드 정보 수정을 full `set(merge:true)` 로 옮기면 거부될 수 있다 **[확인됨]**

**위치**: `firestore.rules:568-571`

```
// brandKey / approvedBy / approvedAt / createdAt 는 본인 변경 불가
&& !request.resource.data.diff(resource.data).affectedKeys().hasAny(
  ['brandKey', 'approvedBy', 'approvedAt', 'createdAt']
);
```

앱은 기존 값을 그대로 다시 써서 `affectedKeys` 를 비우는 방식으로 통과한다.
**타임스탬프 왕복(Timestamp → DateTime → Timestamp)에서 1비트라도 달라지면
"승인 메타 변경" 으로 판정돼 update 전체가 거부된다.**

지금 깨져 있다는 뜻은 아니다. **이 방식에 의존하고 있다는 사실을 적어둔다** — 모델이나
직렬화를 손볼 때 조용히 깨질 수 있는 종류다. 웹 콘솔은 변경분만 담은 좁은 payload 를 보낸다.

---

## 7. ℹ️ `firebase.json` 의 Android appId 가 실제 등록 앱과 다르다 **[확인됨]**

| | 값 |
|---|---|
`firebase.json` flutter 블록 | `1:835847199015:android:eaa7fba75a1895cc327102` |
실제 등록 앱 (`firebase apps:list`) | `1:835847199015:android:1b45f24b099287e8327102` |

빌드에는 `google-services.json` 이 쓰이므로 **당장 영향은 없다.**
`flutterfire configure` 를 다시 돌릴 때만 문제가 된다.

`firebase.json` 은 이 세션에서 hosting 블록만 건드리기로 돼 있어 **손대지 않았다.**

---

## 8. ℹ️ 이 세션이 Firebase 프로젝트와 저장소에 한 변경

다른 세션이 알아야 할 것만 적는다.

| 변경 | 내용 | 영향 |
|---|---|---|
**Web 앱 등록** | `order-app-5957e` 에 `Qradar Admin Console` (`1:835847199015:web:d44f3e33...`) 추가 | Android·iOS 앱 무관. **`flutterfire configure` 를 다시 돌리면 플랫폼 목록에 `web` 이 뜬다** — 자동 선택되지는 않는다 |
**`.firebaserc` 신규** | `default` → `order-app-5957e` | 저장소 전체의 기본 프로젝트가 고정된다. `--project` 없이 firebase 명령을 쓰면 이 값이 적용된다. 불필요하면 지워도 된다(웹 쪽 명령은 `--project` 를 항상 명시한다) |
**`firebase.json` hosting 블록 추가** | `public: "landing"` 외 4키. **기존 `firestore`·`storage`·`functions`·`flutter`·`emulators` 블록은 무변경**(diff +30 / −0) | 없음 |
**`landing/` 신규** | 토스 PG 심사용 랜딩 4페이지 + 관리자 콘솔 `landing/console/` | `lib/` · `functions/` 와 무관 |

**아직 배포한 적이 없다.** 랜딩도 콘솔도 로컬에만 있다.

---

## 참고 문서

| 문서 | 내용 |
|---|---|
`docs/tasks/web_admin_console/{spec,design,implementation,test_report}.md` | 완성된 admin 웹 콘솔. test_report 판정 GO |
`docs/tasks/web_role_console/spec.md` | 역할별 콘솔 설계. §5 에 역할 × 액션 × 허용필드 × Rules 줄번호 매트릭스, §17 에 별 과제 T1~T16 |

> `web_admin_console/spec.md` §7.2 의 Rules 줄번호는 **825줄 반영 전**이라 3~5줄씩 밀려 있다.
> 코드는 에뮬레이터 실측으로 검증됐으므로(test_report 64건 통과) **낡은 것은 문서의 참조뿐이다.**

# existing_user_phone_collection 기능 명세

로그인은 했지만 `users.phone` 이 비어 있는 유저(그 기능 이전 가입한 이메일 유저 + 카카오/네이버 소셜 유저)에게, **앱 내에서 전화번호를 입력받아 `users/{uid}.phone` 을 채운다.** 이름(`displayName`)은 범위 제외(엣지케이스만 §0-7).

`signup_profile_fields` 가 열어둔 "후속 수정/백필 경로"(firestore.rules 의 `phone` self-update 화이트리스트)를 **이번 기능이 실제로 처음 사용**한다. 검증 규칙·쓰기 경로는 그 기능과 **동일 재사용**한다.

---

## §0 사용자 확인 필요 결정사항 (권고 포함)

> **✅ 2026-11-03 사용자 확정**: **D1 = B(체크아웃 직전 게이트)** 로 선택. 이에 따라 D2~D6 전부 **권고안대로 확정**된다 (D2 사실상 필수·신규 카운트 필드 없음, D3 signup 검증 재사용+유틸 공용 승격, D4 수동입력·소셜 자동수집 Phase 2, D5 self-write·Rules/CF 무변경, D6 이름 미수집·`'Qrator'` 폴백 유지). → **Entity/Model/Rules/CF/소셜 verify/라우팅 전부 무변경.**
>
> 설계자가 권고안을 정해두었다. 설계 본문은 **권고안 기준**으로 작성되어 있다.

| # | 결정할 것 | 권고안 | 근거 / 트레이드오프 |
|---|---|---|---|
| **D1** | **언제/어디서 입력받을지** (A 홈 게이트 / B 체크아웃 게이트 / C 소프트 배너) | **B — 체크아웃(결제) 직전 게이트** | 전화번호의 **유일한 운영 목적은 픽업 주문 식별·연락**이다. 가치가 발생하는 지점(주문)에서만 막으면 ① 둘러보기만 하는 유저를 괴롭히지 않고 ② 수집 사유 문구가 자연스럽고("픽업 연락을 위해 전화번호가 필요해요") ③ 다음 앱 오픈 시 **전체 기존 유저를 일괄 차단**하는 리텐션 리스크가 없다. **결정적 근거**: 체크아웃은 이미 `currentUserProfileProvider` 를 읽고(`checkout_page.dart:59`) `profile.email`/`displayName` 을 결제에 쓰며(`:126-127`), 결제 직전 **차단 바텀시트 선례**(`showCheckoutBlockedSheet`, `checkout_blocked_sheet.dart`)가 있어 "결제는 아직 시작되지 않았어요" 패턴을 그대로 복제하면 된다. <br> **A(홈 게이트)**는 `role_router.dart:39` 의 suspension 게이트 선례로 구현이 단순하고 **수집 보장률이 가장 높지만**, 주문 의사 없는 기존 유저까지 첫 진입에 전면 차단한다(과함). → **보장률을 최우선하면 A 로 바꿔도 설계 골격은 동일**(§레이어 설계에 A 분기 메모). **C(배너)**는 수집률이 낮아 비권장. |
| **D2** | **필수 vs 건너뛰기(N회 미루기)** | **B 게이트에서 사실상 필수 — 별도 "미루기 카운트" 필드 두지 않음** | B 는 **주문을 하려면 phone 이 필요**하고, 주문 의사가 없으면 시트를 닫고 둘러보면 그만이다. 즉 "미루기"가 앱 레벨 상태 없이 자연히 구현된다. `notificationPermissionLaterCount`(`user_entity.dart:29`) 같은 **신규 카운트 필드 불필요**. <br> **D1 을 A(홈 게이트)로 바꿀 경우에만** 미루기 정책이 필요 → 그때는 알림 패턴을 미러링해 `phonePromptLaterCount` 류 신규 필드 + N회 후 강제 를 둔다(이 경우 user_entity/model/rules 화이트리스트 추가 발생). **B 권고 유지 시 이 필드는 만들지 않는다.** |
| **D3** | **입력 검증 수준** | **`signup_profile_fields` 와 100% 동일** (SMS 인증 없음) | `digitsOnly` + `maxLength 11` + 정규식 `^01[016789]\d{7,8}$`. 현재 이 검증이 `email_signup_page.dart:12`(`_phonePattern`, private)·`:126-129`(inputFormatters)에 **중복 정의**돼 있으므로, 이번에 **공용 유틸로 승격**해 signup 과 신규 입력 UI 가 **한 소스**를 쓰게 한다(중복 제거). SMS 본인인증은 비범위(비용·UX·MVP 목적 초과). |
| **D4** | **소셜 자동수집 여부** (네이버 `mobile` 스코프 / 카카오 `phone_number`) | **수동 입력 기본. 소셜 자동수집은 Phase 2 / 비범위** | 현재 소셜 verify 함수는 phone 을 **받지 않는다**(네이버 profile=`email/name/imageUrl` — `verifyNaverToken.ts:146-148`; 카카오 profile=`nickname/profile_image_url` — `verifyKakaoToken.ts:32-33`). 자동수집은 **카카오 비즈앱 검수 + 추가 동의 스코프 + verify 함수 수정**이 얽혀 리스크가 크다. **전 유저 동일한 수동 입력 1경로**로 통일하면 소셜/이메일/기존 유저 구분 없이 같은 UI·같은 쓰기 경로를 탄다. 자동수집은 별 task 로 분리. |
| **D5** | **쓰기 경로 / 권한** (self-write vs CF callable) | **본인 self-write 직접** (`users/{uid}.update`) — **CF 불필요, Rules 변경 불필요** | phone 은 **돈·권한·정책 값이 아니라 본인 소유 프로필 PII** 라 CF 전담 대상이 아니다. ⭐ **핵심 확인**: `phone` 은 **이미** `firestore.rules:178` 의 `isSelfProfileUpdate` 화이트리스트에 들어 있다(signup_profile_fields 가 후속 수정 UI 대비해 미리 열어둠). `data_ownership.md:41` 에도 이미 문서화돼 있다. → **firestore.rules 수정 0건, 재배포 불필요.** 쓰기는 `fillProfile`/`updateFcmToken`/`updateNotificationSetting`(`user_remote_data_source.dart:33·63·108`)와 동일한 `_doc(uid).update({'phone':..., 'updatedAt':...})` 패턴을 그대로 복제한다(= signup 의 create 경로와 일관, 같은 self-write 모델). |
| **D6** | **displayName 이 빈 엣지케이스 처리** | **이 기능에서 이름은 수집하지 않음. 기존 폴백 유지** | 소셜은 provider 이름이 `displayName` 에 저장되고, 기존 이메일 유저도 로그인 응답에 이름이 있으면 `getOrCreateUserProfile` 가 비어있을 때만 자동 백필한다(`user_repository_impl.dart:20-34`). 이름이 끝내 비어도 홈 인사말/결제는 **`'Qrator'` 폴백**(`checkout_page.dart:127`)이 받으므로 기능이 깨지지 않는다. 이름 재수집 UI 는 비범위(별 백로그). |

---

## 개요

- **목적**: 로그인은 됐지만 `users.phone` 이 null/'' 인 유저(기존 이메일 + 소셜)에게 전화번호를 받아 채운다. 픽업 주문의 **고객 식별·연락** 수단 확보.
- **작업 유형**: 신규 기능 (presentation 입력 UI + domain usecase + data self-write). **스키마/Entity/Model 변경 없음**(phone 필드 이미 존재), **Rules 변경 없음**(화이트리스트 이미 포함), **Cloud Function 없음**, **소셜 verify 함수 변경 없음**.
- **영향 범위**:
  - **화면**: (권고 B) `checkout_page.dart` 의 결제 진입 분기(`_handlePay`)에 phone 게이트 추가 + 신규 전화 입력 바텀시트/위젯(`showCheckoutBlockedSheet` 패턴 복제). signup 의 phone TextField 스타일·검증 재사용.
  - **Domain**: `UserRepository` 에 `updateMyPhone({uid, phone})` 추가. 신규 `UpdateMyPhoneUseCase`. **Entity 변경 없음**(`UserEntity.phone` 이미 존재 — `user_entity.dart:15`).
  - **Data**: `UserRemoteDataSource.updateMyPhone`(= `_doc(uid).update`), `UserRepositoryImpl.updateMyPhone`. **Model 변경 없음**(`UserModel.phone`/`fromFirestore` 이미 존재 — `user_model.dart:23·110`).
  - **Presentation**: phone 게이트 상태/호출(provider 또는 체크아웃 컨트롤러 내 분기). 입력 성공 시 `currentUserProfileProvider` 스트림이 갱신돼 자동 반영.
  - **공통 컴포넌트**: 전화 검증 유틸 **공용 승격**(signup 중복 제거 — D3).
  - **라우팅**: 변경 없음(권고 B). D1→A 선택 시에만 `role_router.dart` 분기 추가.
  - **권한 / 환경 설정**: **변경 없음**(D5). `data_ownership.md §users` 에 "phone self-update 경로를 이 기능이 처음 실사용" 1줄 주석만 갱신.
- **비범위 (명시)**:
  - **SMS 본인인증** (D3)
  - **이름(displayName) 재수집** (D6 — 폴백 유지, 별 백로그)
  - **약관/개인정보 재동의 UI** (별 백로그)
  - **소셜 자동수집**(네이버 mobile / 카카오 phone_number) + verify 함수 수정 (D4 — Phase 2)
  - owner/brand/admin 역할 phone 수집 (해당 역할은 픽업 주문을 하지 않음 — 게이트는 customer 결제 흐름에만)
  - D1 을 A(홈 게이트)로 바꿀 때 필요한 `phonePromptLaterCount` 신규 필드 (B 권고 유지 시 불필요)

---

## 요구사항

### 기능 요구사항

- [ ] (권고 B) customer 가 결제를 시도할 때(`_handlePay`) `profile.phone` 이 비어 있으면 결제를 **시작하지 않고** 전화 입력 시트를 띄운다. "결제는 아직 시작되지 않았어요" 톤(`checkout_blocked_sheet` 패턴).
- [ ] 시트에서 전화번호 입력 → 검증 통과 시 `users/{uid}.phone` 에 self-write 로 저장한다.
- [ ] 저장 성공 후 결제 흐름을 **이어서 진행**(시트 닫고 사용자가 금액 확인 후 다시 결제 탭 — 자동 결제 시작 금지, 기존 차단 시트 정책과 동일)하거나, 시트를 닫고 체크아웃에 머문다.
- [ ] 전화번호 검증은 `signup_profile_fields` 와 동일(`digitsOnly`, `maxLength 11`, `^01[016789]\d{7,8}$`, SMS 없음 — D3).
- [ ] phone 이 이미 있는 유저는 게이트가 뜨지 않고 기존 결제 흐름 그대로(회귀).
- [ ] 이름(displayName)은 수집하지 않는다(D6). 비어 있으면 기존 `'Qrator'` 폴백 유지.

### UI 요구사항 (designer 산출물로 상세화)

- [ ] 전화 입력 바텀시트(또는 소형 전체화면): 제목 + 수집 사유 1줄("픽업 연락을 위해 전화번호가 필요해요") + 전화 TextField(signup 과 동일 스타일·키패드·formatter) + 저장 CTA + 닫기.
- [ ] 검증 실패 시 필드 인라인 에러(빈값/형식오류) — signup 문구 재사용.
- [ ] 저장 중 로딩/비활성, 저장 실패 시 재시도 안내.
- [ ] 색상은 `AppColors` 만. (단 `checkout_blocked_sheet.dart` 가 쓰는 토큰 계열과 일관 — `surfaceElevated`/`textHeading`/`textBody`/`border`.)

### 상태 요구사항

- [ ] loading: phone 저장 중 CTA 비활성/인디케이터.
- [ ] error: self-write 실패(네트워크/permission) → 서버 raw 노출 금지, 재시도 안내. 검증 오류는 제출 전 클라이언트 인라인.
- [ ] empty: 해당 없음(단건 입력).

---

## 데이터 모델

### 변경 없음 — 기존 필드 재사용

- `UserEntity.phone: String?` — **이미 존재** (`user_entity.dart:15`, "읽기 전용 PII — 화면 노출/로그 금지" 주석 포함).
- `UserModel.phone: String?` — **이미 존재**, JSON 직렬화 제외(`user_model.dart:23`), `fromFirestore` 파싱(`:110`), `toFirestoreForCreate` 는 빈값이면 키 생략(`:89`).
- `users/{uid}.phone` — 숫자만 문자열(예: `"01012345678"`). read 는 `self(uid) OR admin` 뿐(`firestore.rules:142`)이라 PII 노출 없음 → **별도 private 서브컬렉션 불필요**(signup 과 동일 판단).

### 신규 쓰기 payload (self-write update)

```
users/{uid}.update({
  phone: "01012345678",   // 검증 통과한 숫자만 문자열
  updatedAt: serverTimestamp,
})
```

- `fillProfile`/`updateFcmToken`/`updateNotificationSetting` 과 **동일한 self-write update 형태**. `updatedAt` 동반(기존 self-write 관례).

---

## 레이어 설계

### Domain

- **Entity**: 변경 없음(`UserEntity.phone` 존재).
- **UseCase**: `UpdateMyPhoneUseCase.call({uid, phone})` — 단일 책임, repository 위임. (phone 정규화/검증은 presentation 에서 끝내고, usecase 는 이미 정규화된 숫자 문자열을 받는다. 방어적으로 usecase 에서 재검증 1줄 둘지는 developer 재량 — signup 과 일관되게 presentation 검증이 1차.)
- **Repository Interface**: `UserRepository.updateMyPhone({required String uid, required String phone})` 추가.

### Data

- **Model / DTO**: 변경 없음.
- **DataSource**: `UserRemoteDataSource.updateMyPhone(uid, phone)` — `_doc(uid).update({'phone': phone, 'updatedAt': FieldValue.serverTimestamp()})`. (`fillProfile`/`updateFcmToken` 과 동일 구조 — `user_remote_data_source.dart:33·63`.)
- **Repository Impl**: `UserRepositoryImpl.updateMyPhone` — datasource 위임(기존 메서드들과 동형 — `user_repository_impl.dart:61-88`).

### Presentation

- **공용 유틸**: 전화 검증(`_phonePattern` + formatter 세트)을 `email_signup_page.dart` 에서 공용 위치로 승격(예: `core/` 또는 `presentation/common/` 의 phone validator). signup 과 신규 시트가 공유(D3).
- **Page/Widget**: 전화 입력 시트 위젯(신규). `checkout_page.dart` 의 `_handlePay` 진입부에서 `profile.phone` 비었으면 시트 호출 → 저장 → 사용자가 다시 결제 탭.
- **Provider**: `UpdateMyPhoneUseCase` 를 호출하는 저장 액션(신규 작은 notifier 또는 체크아웃 컨트롤러 내 메서드 — developer 가 기존 체크아웃 상태관리와 일관되게 선택). 저장 성공 시 `currentUserProfileProvider`(users 스트림 — `user_profile_provider.dart:54`)가 자동 갱신.

> **D1→A(홈 게이트) 선택 시 변경점**: `role_router.dart` 의 `data(user)` 분기에서 `user.suspended` 게이트(`:39`) **다음, role switch(`:54`) 직전**에 `if (user.role == customer && (user.phone ?? '').isEmpty) return const PhoneCollectionPage();` 를 추가하고, 미루기 허용 시 D2 의 신규 필드 로직을 둔다. 이 경우에만 라우팅/entity/model/rules 화이트리스트 변경이 추가된다.

---

## 데이터 흐름 (권고 B)

```text
CheckoutPage._handlePay(cart)
  → profile = currentUserProfileProvider.asData.value   (checkout_page.dart:59)
  → if ((profile.phone ?? '').isEmpty):
        showPhoneCollectionSheet()                        (신규, checkout_blocked_sheet 패턴)
          → 입력·검증(공용 validator)
          → UpdateMyPhoneUseCase.call(uid, phone)
          → UserRepository.updateMyPhone
          → UserRepositoryImpl → UserRemoteDataSource.updateMyPhone
          → users/{uid}.update({phone, updatedAt})         (self-write, Rules:178 화이트리스트)
          → currentUserProfileProvider 스트림 갱신 → profile.phone 채워짐
        시트 닫음 → 결제 자동 시작 안 함 (사용자가 금액 확인 후 다시 결제 탭)
  → else: 기존 결제 흐름 그대로
```

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| phone 빈값/형식 오류 | 제출 전 인라인 에러(signup 문구 재사용), 저장 차단 |
| self-write 실패(네트워크/permission-denied) | 서버 raw 노출 금지, "저장에 실패했어요. 다시 시도해 주세요" + 재시도. phone 미저장이므로 결제 진행 안 됨(게이트 유지) |
| 저장 성공 직후 스트림 반영 지연 | `updateMyPhone` 성공을 기다린 뒤 시트 닫음 → 다음 결제 탭 시 최신 profile.phone 사용 |
| phone 이미 존재 | 게이트 미발동, 기존 흐름(회귀) |
| displayName 빈값 | 기존 `'Qrator'` 폴백 유지(결제/인사말 영향 없음 — D6) |
| 소셜/기존 유저 로그인 | 동일 수동 입력 경로(구분 없음 — D4) |

---

## 이력 / 감사 추적 (`audit_trail.md §4` 체크리스트)

| # | 항목 | 판정 |
|---|---|---|
| 1 | **돈·권한·정책 값을 바꾸는가? → 설정 변경 이력 필요?** | **아니오.** `phone` 은 **본인 소유 프로필 PII** 일 뿐 돈(`qoinBalance`)·권한(`brandId`/`role`)·정책 계수가 아니다. → **설정 변경 이력 불필요.** (거래 이력이 있다고 설정 변경 이력이 생기는 것 아님 — 해당 없음.) |
| 2 | **덮어쓰기로 사라지는 값이 있는가?** | 대상 유저는 정의상 phone 이 **비어 있던** 유저라 "덮어써 사라지는 기존 값"이 없다(null/'' → 값). 추후 **전화번호 변경 UI** 를 만들 때 "이전 번호 보존 이력"이 필요한지는 그 task 에서 재판단(현재 과도설계 회피). |
| 3 | 거래/기록 문서가 정책 값을 참조만 하는가? | 해당 없음(거래 문서 아님). orders 는 phone 스냅샷 없음(account_deletion 조사 확인). |
| 4 | "누가"가 기록되는가? | 본인이 본인 문서를 쓰는 self-write(`uid` 가 주인). 운영자 행위 아님 → 별도 행위자 기록 불필요. `updatedAt` 만 동반(기존 관례). |
| 5 | 일괄 처리(batch)가 있는가? | 없음. 서버 백필 불가(본인 정보) — 앱 내 수동 입력으로만. |
| 6 | CF 로그에 의존하는가? | 아니오(CF 미사용). |
| 7 | 권한 판정 필드의 create/update 양쪽 확인 | `phone` 은 권한 판정 입력이 아니다. **Rules 변경이 없으므로** 신규 Rules 회귀 케이스는 없다. 다만 "self update 로 phone 이 통과하는가"는 이미 signup 하네스 SP1 에 존재(`implementation.md`) → tester 가 해당 회귀가 여전히 PASS 인지 확인. |

**결론**: 돈·권한·정책 값 변경이 아니므로 **설정 변경 이력을 남기지 않는다**(사유: 본인 PII 최초 입력, 사라지는 값 없음). 개인정보 수집 고지 1줄(수집 목적)은 입력 UI 에 노출한다(미성년자 정책 B 범위 확정 시 재검토 — signup 과 동일 단서).

---

## firestore.rules 변경

**변경 없음.** `phone` 은 이미 `match /users/{userId}` 의 `isSelfProfileUpdate` `onlyChangedFields` 화이트리스트에 포함돼 있다(`firestore.rules:178`). self-write update 가 추가 배포 없이 통과한다.

- `data_ownership.md §users`(line 41 인근): 화이트리스트 자체는 변경 없음. "phone self-update 경로를 `existing_user_phone_collection` 이 처음 실사용" 1줄 비고만 추가(추적 명확화).

---

## 작업 분배

### designer (필요 — 경량)

- **UI 변경**: 있음(신규 전화 입력 시트 1종). 단 signup phone 필드·`checkout_blocked_sheet` 스타일을 **대부분 재사용**하므로 경량.
- **산출물**: `docs/tasks/existing_user_phone_collection/design.md`
- **전달 사항**:
  - 전화 입력 바텀시트 레이아웃(제목/수집 사유 1줄/TextField/저장 CTA/닫기) — `checkout_blocked_sheet.dart` 톤·토큰과 일관(`surfaceElevated`/`textHeading`/`textBody`/`border`).
  - "결제는 아직 시작되지 않았어요" 계열 안내 문구, 저장 성공 후 동작 문구.
  - 인라인 에러·로딩·저장 실패 상태.
  - 수집 목적 고지 1줄.
  - `AppColors` 만.
  - (참고) D1 권고가 B 라 **홈/라우팅 화면 변경 없음**.

### developer

- **산출물**: `docs/tasks/existing_user_phone_collection/implementation.md`
- **구현 항목**:
  - `UpdateMyPhoneUseCase` + `UserRepository.updateMyPhone`(interface/impl) + `UserRemoteDataSource.updateMyPhone`(`_doc(uid).update({phone, updatedAt})`).
  - 전화 검증 유틸 **공용 승격** 후 `email_signup_page.dart` 가 그 유틸을 쓰도록 리팩터(중복 제거 — D3). **signup 동작 회귀 금지.**
  - `checkout_page.dart._handlePay` 진입부에 phone 게이트 분기 + 전화 입력 시트 호출/저장/흐름 재개.
  - `data_ownership.md §users` 비고 1줄 갱신.
  - **Entity/Model/Rules/CF/소셜 verify 함수 변경 없음**(확인 후 불필요 확정).
- **재사용할 기존 구조**: `fillProfile`/`updateFcmToken`/`updateNotificationSetting` self-write 패턴(`user_remote_data_source.dart:33·63·108`), `showCheckoutBlockedSheet`(`checkout_blocked_sheet.dart`), signup phone 필드/formatter(`email_signup_page.dart:12·126-129`), `currentUserProfileProvider`(`user_profile_provider.dart:54`).
- **주의할 레이어 규칙**: Firebase 는 data 레이어에서만(presentation/domain 에서 Firestore 직접 import 금지). 색상 `AppColors` 만. phone 은 로그/타 화면 노출 금지(PII — entity 주석).

### tester (developer 구현 완료 후 호출)

- **산출물**: `docs/tasks/existing_user_phone_collection/test_report.md`
- **주요 검증 기준**:
  - phone 없는 유저 결제 시도 → 게이트 시트 노출, 결제 **미시작**.
  - 시트 입력 → `users/{uid}.phone` 저장 확인, 스트림 갱신 후 재결제 시 게이트 미발동.
  - 검증(빈값/형식오류) 인라인 에러, 정상값 저장.
  - phone 이미 있는 유저 결제 회귀(게이트 미발동).
  - 소셜/기존 이메일 유저 동일 경로 동작.
  - self-write 실패 시 재시도, phone 미저장 상태 유지.
- **반드시 확인할 예외 케이스**:
  - **Rules 회귀**: phone self-update 가 여전히 통과(기존 SP1 하네스), 타 필드 변조 거부 — **신규 Rules 변경이 없음**을 확인(화이트리스트에 phone 이미 존재).
  - 공용 validator 승격 후 **signup 가입 흐름 회귀**(동일 검증 동작).
  - displayName 빈 유저 결제 시 `'Qrator'` 폴백 정상.
  - 저장 성공 후 자동 결제가 시작되지 않는지(사용자 재탭 필요).

---

## 완료 기준

- [ ] §0 결정사항(D1~D6)이 사용자 확인으로 확정됨 (특히 D1 게이트 위치, D2 필수성)
- [ ] `design.md` 작성 완료(전화 입력 시트)
- [ ] `implementation.md` 작성 완료 (usecase/repository/datasource + 게이트 + validator 공용 승격)
- [ ] `test_report.md` 작성 완료
- [ ] Entity/Model/Rules/CF/소셜 verify **무변경** 확인 반영
- [ ] signup 회귀 통과(공용 validator 승격 후)
- [ ] FAIL 항목이 없거나 후속(소셜 자동수집 Phase 2, 전화 변경 UI)으로 분리됨

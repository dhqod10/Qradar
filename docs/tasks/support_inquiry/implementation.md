# support_inquiry — 구현 기록 (developer, 2026-11-24)

spec §0 Q1~Q10 확정, design.md(카메라 반영본) 기준. **배포·커밋하지 않았다.**

## 1. 구현 항목

| 영역 | 파일 |
|---|---|
| Domain | `entities/support_inquiry_{entity,category,status}.dart`(+freezed), `repositories/support_inquiry_repository.dart`, UseCase 6 (`watch_my_support_inquiries` / `watch_support_inquiry` / `create_support_inquiry`(클라 1차 검증) / `upload_support_inquiry_images` / `withdraw_support_inquiry` / `mark_support_inquiry_answer_read`), `core/errors/support_inquiry_exception.dart` |
| Data | `models/support_inquiry_model.dart`(수동, `patchForWithdraw`/`patchForAnswerRead` 키 = Rules 화이트리스트 1:1), `datasources/remote/support_inquiry_remote_data_source.dart`(토큰 분류, raw message 비노출), `repositories/support_inquiry_repository_impl.dart`, `StorageDataSource.uploadSupportInquiryImage`(**`_validateFileSize` 호출 + image/* contentType 명시** — `uploadStoreImage` 누락 미복제), `firestore_paths.dart` 상수 2 |
| Presentation | `customer/support/` 페이지 3 + 위젯 7(타일·배지·답변카드·주문요약·주문선택시트·첨부 picker·이미지 뷰어) + providers 2. 진입점: `more_page.dart`(`_NotificationSettingsTile`→`_MoreTile` rename, 고객센터 타일+dot), `order_detail_page.dart`(`_ActionSection` 분기 **미수정**, 뒤에 `_OrderInquiryBlock`) |
| Functions | `createSupportInquiry.ts`, `moderateSupportInquiry.ts`, `index.ts` export 2, `deleteMyAccount.ts` phase `inquiriesMarked`(favoritesDeleted 다음, `affected.supportInquiries`), `parseStorageUrl` 은 이미 export 상태라 그대로 재사용 |
| Rules | `firestore.rules`(supportInquiries C1/C2 + supportInquiryLimits), `firestore.indexes.json` 3개, `storage.rules` |
| 콘솔 | `section-admin.js`(NAV 운영 그룹 "문의 관리"+뱃지, `viewInquiryQueue`/`viewInquiryDetail`/`openInquiryModal`), `console-data.js`, `console-format.js`. 셸·`index.html`·`console-payloads.js` 미수정 |
| 플랫폼 | iOS `Info.plist` `NSCameraUsageDescription`, Android `CAMERA` 권한 |
| 문서 | `data_ownership.md`(§2.10a + CF 카탈로그 2줄 + deleteMyAccount 설명) · `entity_lifecycle.md`(§1 표 + §6a) · `role_flows.md`(§4.1·§4.4) |

## 2. Storage Rules 평가 순서 실측 (이 작업의 유일한 설계 리스크)

**결론: spec 원안(와일드카드 그대로 + 신규 블록)은 무력화된다. 와일드카드에서 `support_inquiries/` 를 제외하면 의도대로 동작한다. 설계 재검토는 불필요.**

방법: Storage 에뮬레이터(firebase-tools 15, JDK 21) + `@firebase/rules-unit-testing` 로 13케이스. 하네스를 `test_rules/storage.test.mjs` 로 보존했다.

| 규칙 | 결과 |
|---|---|
| 원안(기존 와일드카드 `read: if true` / `write: auth+10MB` 유지 + 신규 블록 추가) | **3건 FAIL** — 비로그인 문의첨부 read 허용됨 / 남의 uid 경로 write 허용됨 / 자기 경로 6MB write 허용됨 (OR 평가로 와일드카드가 이김) |
| 채택안 (와일드카드의 read·write 에 `!resource.name.matches('support_inquiries/.*')` / `!request.resource.name...` 추가) | **13/13 PASS** |

채택안 케이스: 비로그인 read 거부 · 로그인(타인) read 허용 · 자기 경로 write 허용 · 남의 uid 경로 write 거부 · 비로그인 write 거부 · 6MB 거부 · non-image 거부 · **기존 경로 회귀**(비로그인 `store_images` read 허용, 루트 파일 read 허용, 로그인 write 허용, 6MB write 허용(10MB 미만 현행), 비로그인 write 거부).

- 시행착오: `allPaths.matches(...)` 는 path 타입이라 불가, `string(allPaths)` 도 불가(에뮬레이터가 `Function not found` / `Unsupported operation` 으로 평가 실패 → 전부 deny 되는 회귀를 만들 뻔함). **`resource.name`(read) / `request.resource.name`(write) 문자열을 쓴다.**
- 매장·브랜드·메뉴 경로의 공개 설정(read true, write 10MB)은 **그대로** — 전면 재작성은 비범위(후속 `storage_security_rules`).
- 재실행: `cd test_rules && npm run test:storage` (JDK 21 필요: `JAVA_HOME=/opt/homebrew/opt/openjdk@21`).
- ⚠️ 배포 순서 §5 참조: **Storage Rules 가 앱 업로드 경로 허용의 전제**다.

## 3. 검증 결과

| 항목 | 결과 |
|---|---|
| `flutter analyze` | No issues |
| `flutter test` | 1110 pass (신규 `test/data/support_inquiry_model_test.dart` 7건 포함) |
| `functions npm run build` / `npm test` | 통과, 604 pass (신규 `supportInquiry.test.mjs` 13건: 멱등·경계값·rate limit(분1/일5, 60s·24h 경계)·첨부 경로 주입 4종·남의/없는 주문 동일 응답·deleted 거부/suspended 허용·답변 append-only·종결 사유·no-op) |
| Firestore Rules 하네스 (`test_rules`, `npm test`) | **564/564 PASS** — 신규 `SI-*` 31건(create 거부, delete 거부(admin 포함), 타인 read/쿼리 거부, 철회 정상·answered/closed/withdrawn 거부·화이트리스트 밖 필드·시각 위조·answer 위조 거부, 읽음 정상·open 거부·변조 거부, **admin 직접 update 거부**, limits 전면 차단). 기존 케이스 회귀 없음 |
| Storage Rules | 13/13 (§2) |
| 어드민 콘솔 | 구문 검증(`node --check`)만 수행. **브라우저 실동작은 미검증** — tester/사용자 확인 필요 |
| 실기기 | 미검증(카메라 촬영·거부·영구 거부, 첨부 업로드, 더보기 dot). 에뮬레이터 Functions 통합(`test:emulator`)도 미실행 |

## 4. spec/design 과 달라진 점 (판단 근거)

1. **주문 선택 시트가 `users/{uid}/orderLogs` 가 아니라 `myOrdersProvider`(주문 스트림)를 쓴다.** `verifyTossPayment` 가 `logId` 를 별도 uuid 로 발급하고 `orderLogs` 문서에 `orderId` 필드가 없어, 로그에서는 CF 가 검증할 `orders/{orderId}` 를 얻을 수 없다. 그래서 `GetRecentOrdersForInquiryUseCase`/`recentOrdersForLink` 는 만들지 않았다(UseCase 7→6). 최근 10건 표시.
2. **첨부 진행 표시는 타일별 %가 아니라 "완료 n장 + 현재 장 스피너"** 이다. 레포지토리가 `onProgress(done,total)` 만 노출. 버튼 라벨(`사진 업로드 중 (n/N)`)·완료 체크·실패 표시는 design 대로.
3. `appVersion` 은 보내지 않는다(`package_info_plus` 미의존, 신규 의존성 회피). `platform` 만 전송. CF 는 두 필드 모두 optional.
4. 작성 성공 후 상세로 `pushReplacement` (design §5-6) — spec 의 "목록으로 복귀"보다 design 을 따랐다.
5. 응답 유실 대비: CF 호출이 **네트워크/알 수 없는 오류**로 실패하면 올라간 첨부를 지우지 않는다(서버가 이미 생성했을 수 있어 지우면 문서가 깨진 URL 을 가리킨다). **확정 거절**(rate limit·입력·첨부·주문·탈퇴)에서만 best-effort 정리.
6. "설정 열기" 버튼 없음, 카메라 권한 안내는 문구만(design §6-2a). image_picker 는 `store_form_page`/`ImageUploadField` 선례대로 presentation 에서 직접 사용(신규 SDK 아님).
7. iOS 사진 보관함은 PHPicker(iOS 14+)라 `NSPhotoLibraryUsageDescription` 불필요 — 추가하지 않았다. 카메라 키만 추가.
8. 콘솔: 상태 필터 없이 유형만 고르면 해당 복합 인덱스가 없어(`category+createdAt`) 서버는 최신순 500건만 가져오고 유형은 클라이언트에서 거른다.

## 5. 배포 순서 (사용자 실행)

1. **`firestore.indexes.json` 배포 + 빌드 완료 대기** (`firebase deploy --only firestore:indexes`) — 앱 릴리스 선행 조건. 에뮬레이터는 인덱스를 강제하지 않으므로 로컬 통과를 믿지 말 것. 미배포 시 목록 쿼리가 `failed-precondition` → 앱 error 상태.
2. `firestore.rules` + `storage.rules` 배포 (`--only firestore:rules,storage`). Storage Rules 배포 전 앱 출시 금지(업로드 경로 `support_inquiries/**` 는 현행 와일드카드로도 write 가능하지만, 공개 read 가 남는다).
3. Functions 배포 (`createSupportInquiry`, `moderateSupportInquiry`, `deleteMyAccount`, `adminDeleteUser`(코어 승계로 재배포 포함)). `--only functions:createSupportInquiry,functions:moderateSupportInquiry,functions:deleteMyAccount,functions:adminDeleteUser`.
4. 콘솔: `landing` hosting 배포(hosting 전용 규칙 준수, `git add landing/` 만).
5. 앱 릴리스 (카메라 권한 선언 포함 — 스토어 심사 메타 갱신 필요 여부 확인).
6. 랜딩 2건(§8 `privacy.html` 보존기간·수집항목, `index.html` "더보기 → 고객센터" 정정)은 별도 landing 커밋. 이후 토스 재신청.

## 6. tester 테스트 포인트

- 작성→목록→상세→(콘솔 답변)→답변 카드 노출→더보기 dot 소거 전 과정 (실기기 2대 권장).
- 멱등: 응답 유실 상황에서 같은 폼 재제출 시 문서 1건. rate limit 2번째 제출 시 인라인 경고 + 입력·첨부 유지.
- 첨부: 3장 성공 / 보관함 남은 장수 제한 / 카메라 촬영 / 카메라 거부·영구 거부 문구 / 시뮬레이터 `no_available_camera`.
- 주문 연결: 주문 상세 진입 시 preset·유형 '주문' / 시트에서 해제 / 남의 orderId 직접 호출 거부(CF 단위 테스트로는 확인됨).
- 탈퇴: 문서·첨부 존재, `authorDeleted`, 열린 건 `closed(account_deleted)`, `accountDeletionHistory.affected.supportInquiries`. self-탈퇴 회귀, `adminDeleteUser` 승계(userModeration 테스트 mock 갱신됨).
- 콘솔: 뱃지 수치, 필터, 답변 2단계(확정 단계 포커스 '취소'), 이미 답변된 건 재답변 시 "최신 상태 보기", 성공 후 서버 재조회, 인덱스 미배포 시 raw 에러 미노출.
- 모르는 status/category 문자열이 closed/etc 로 읽히는지(단위 테스트로 확인됨).

## 7. 남은 리스크 / 미구현

- **[실수 — 사용자 조치 필요]** 작업 중 `dart format lib/domain` 을 실행해 **기존 `lib/domain/**` 파일 48개가 서식만 변경**됐다(내 의도 아님, 로직 변경 없음, 194+/168-). 되돌리려 시도한 `git checkout` 이 권한 정책으로 거부돼 **그대로 남아 있다.** 커밋 전에 `git checkout -- $(git diff --name-only -- lib/domain)` 로 되돌리거나(신규 `support_inquiry_*` 파일은 untracked 라 영향 없음), 검토에서 제외해야 한다.
- 콘솔 UI 브라우저 실검증·앱 실기기 검증·`test:emulator` 통합 미실행.
- 첨부 고아 파일 정리 / 3년 만료 정리 / 답변 FCM / 다중 턴 / `storage_security_rules` 전면 재작성은 spec §8 후속 그대로.
- `suspended` 사용자는 CF 가 거부하지 않는다(Q7) — 토큰 잔여창 내 호출 허용이 의도.
- 대시보드 `allZero` 배너("처리할 승인 대기가 없어요")가 이제 미답변 문의 0건도 포함해 판정한다.


## 8. tester 결함 수정 (test_report D1/D2/경계/D4)

| 항목 | 수정 | 근거 |
|---|---|---|
| **D1** dot 소실 | `hasUnreadAnswer` = `(answered \| closed) && answer != null && answerReadAt == null` (`withdrawn` 제외). `firestore.rules` C2 를 `status in ['answered','closed']` 로 확장. spec(§0 Q10·읽음 요구사항·Rules 스케치·전이표)·design §1-3·`entity_lifecycle`·`data_ownership` 갱신 | FCM 부재로 dot 이 답변 도착을 아는 유일한 경로. 답변 후 즉시 종결하는 운영 흐름에서 기능이 상실됨 |
| **D2** bucket 미검증 | `attachmentsBelongTo(urls, uid, inquiryId, bucket)` 가 `parseStorageUrl().bucket === bucket` 도 요구. bucket 은 새 port `projectBucket()` = `admin.storage().bucket().name`(런타임 설정, 하드코딩 없음). 알 수 없으면(null) 첨부가 있을 때 **fail-closed** | 경로만 같은 타 bucket URL 이 통과해 관리자 콘솔이 외부 이미지를 로드하는 경로 차단 |
| **경계 5MB** | Storage Rules 를 `size <= 5MB` 로 변경(클라이언트는 기존 `> 5MB` 거부 유지) | 클라이언트 문구가 "5MB 이하" 이고 spec Q4 도 "장당 5MB" 라 허용 경계를 올리는 쪽이 사용자 의도에 부합. 클라이언트(앱 배포 필요)를 건드리지 않는다. **storage.rules 재배포 필요** |
| **D4** test:storage | 설정 파일을 `test_rules/firebase.storage.json` → 저장소 루트 `firebase.storage.json`(rules: `storage.rules`)로 이동, 스크립트 `--config firebase.storage.json` | firebase-tools 가 프로젝트 밖 경로(`../storage.rules`)를 거부함. 구조 변경 없이 파일 1개 이동 |
| D3 | 수정 안 함 — spec §8 후속 과제에 한 줄 등재 | |

### 추가 테스트
- Functions: bucket 불일치 거부·bucket null fail-closed (`functions/test/supportInquiry.test.mjs`)
- Firestore Rules: SI-7f(closed+답변 읽음 허용) / 7g(closed 에서 변조 동반 거부) / 7h(타인 거부) / 7i(withdrawn 거부) — 568/568 PASS
- Storage Rules: 정확히 5MB 허용 / 5MB+1B 거부 추가 — 15/15 PASS
- Dart: closed 미확인 dot, closed+읽음, 답변 없음 closed, withdrawn, open (`test/data/support_inquiry_model_test.dart`)

### 실행 결과
- `flutter analyze` 무경고, `flutter test` 1111 pass, functions `npm run build` + `npm test` 605 pass
- Rules 하네스·`npm run test:storage` 는 JDK 21 이 PATH 에 있어야 한다(`JAVA_HOME=/opt/homebrew/Cellar/openjdk@21/.../libexec/openjdk.jdk/Contents/Home`)
- 배포 순서 추가: `firestore.rules`·`storage.rules`·functions(`createSupportInquiry`) 재배포 필요(이번에 배포하지 않음)

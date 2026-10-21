# Firestore Rules 검증 하네스

리포지토리 루트의 `firestore.rules` 를 로컬 Firestore 에뮬레이터에 올려 실제로 allow / deny 를 확인한다.
Firebase Console 의 Rules Playground 는 **제거되어** (`개발 및 테스트` 버튼이 Cloud Shell 튜토리얼로 연결됨) 더 이상 쓸 수 없으므로, Rules 변경 시 이 하네스로 검증한다.

## 실행

```
cd /Users/Byeonguk/Developer/OrderApp/test_rules && npm install
cd /Users/Byeonguk/Developer/OrderApp/test_rules && npm test
```

`npm install` 은 최초 1회만 하면 된다. 종료 코드 0 이면 전건 PASS, 1 이면 실패 케이스가 출력된다.

## 전제 조건

- **JDK 17 이상.** `firebase-tools@15` 부터 JDK 21 을 요구하므로 하네스는 **14 로 고정**했다.
  JDK 21 이상으로 올린 뒤에는 `package.json` 의 `firebase-tools@14` 를 올려도 된다.
- 에뮬레이터 포트는 루트 `firebase.json` 의 `emulators.firestore.port` (8137) 를 따른다.
- 네트워크 없이 동작한다. 실제 Firestore 를 건드리지 않는다.

## 케이스

`rules.test.mjs` 참조. 2026-10-21 기준 12건.

| # | 시나리오 | 기대 |
|---|---|---|
| R1 | 타인 doc `notificationSettings` update | deny |
| R2 | 본인 doc `notificationSettings` update | allow |
| R3 | 본인 doc `notificationSettings` 2키 동시 | allow |
| R4 | 본인 doc `uid` 변경 (immutable) | deny |
| R5 | 본인 doc 화이트리스트 밖 필드 추가 | deny |
| R6 | 타인 doc read | deny |
| R7 | 본인 doc read | allow |
| R8 | 본인 doc `fcmToken` update | allow |
| R9 | 본인 doc `notificationPermissionLaterCount` increment | allow |
| R10 | 본인 doc `notificationPermissionPrompted = true` | allow |
| R11 | 타인 doc `laterCount` increment | deny |
| R12 | 본인 doc `laterCount` + `role: 'admin'` 동반 | deny |

R12 는 화이트리스트를 통과하는 필드에 금지된 role 전이를 끼워 넣는 **우회 시도**다.

## 케이스 추가

`rules.test.mjs` 의 `run(이름, 'allow' | 'deny', () => 작업)` 한 줄을 추가하면 된다.
`firestore.rules` 를 고칠 때는 **해당 경로의 deny 케이스를 함께 추가**한다 — allow 만 늘리면 권한이 넓어진 것을 잡지 못한다.

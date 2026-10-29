/* ============================================================================
   Firebase 웹 설정 — 시크릿이 아니다. (CLAUDE.md 절대규칙 4 와의 관계)

   절대규칙 4 는 "API key, secret, 환경별 설정값을 코드에 하드코딩하지 않는다" 이다.
   그러나 Firebase web config (apiKey, authDomain, projectId, appId, messagingSenderId …) 는
   프로젝트를 식별하는 공개 값이며, 브라우저로 내려보내지 않으면 SDK 가 동작하지 않는다.
   즉 노출을 전제로 설계된 값이라 "노출되면 피해가 나는 값" 에 해당하지 않는다.
   이 값을 지킨다고 보호되는 것은 없다 — 실제 보호는 아래 세 곳이 한다.
     1. Firestore Security Rules (firestore.rules)  ← 권위 ①
     2. Cloud Functions 의 서버측 requireAdmin()     ← 권위 ②
     3. Firebase Auth 승인된 도메인 / (별 과제) App Check
   Rules 가 허용한 것 이상을 이 콘솔은 할 수 없고, 화면 구성은 그 권위를 대체하지 않는다.

   반대로 아래는 웹·깃 어디에도 절대 넣지 않는다.
     - 서비스 계정 키 / Admin SDK 자격증명 (Rules 를 전부 우회한다)
     - 토스페이먼츠 시크릿 키 등 PG 자격증명 (서버(CF)에만 존재)
   이 콘솔은 Admin SDK 를 쓰지 않는다. 특권 작업은 기존 Cloud Function 호출로만 한다.

   ★ 설정 완료 (2026-10-29): Firebase 프로젝트 order-app-5957e 에 웹 앱 'Qradar Admin Console' 을
     등록하고(appId ...web:d44f3e33...) 그 SDK 설정값을 아래에 채웠다. android/ios 용 apiKey 를
     재사용하지 않았다 — 웹 앱 등록 시 발급된 브라우저용 키다.
     나머지 값(authDomain / projectId / storageBucket / messagingSenderId)은 등록 전 하드코딩되어
     있던 값과 일치함을 `firebase apps:sdkconfig` 출력으로 확인했다.
     재발급이 필요하면:
       cd /Users/Byeonguk/Developer/OrderApp && firebase apps:sdkconfig WEB 1:835847199015:web:d44f3e334dfc3d49327102 --project order-app-5957e
   ========================================================================== */

export const firebaseWebConfig = Object.freeze({
  apiKey: 'AIzaSyBL2Mq--W_Tr8OB8YUzVBJt8TqpdeSZvN4',          // 웹 앱 'Qradar Admin Console' SDK 설정값
  authDomain: 'order-app-5957e.firebaseapp.com',
  projectId: 'order-app-5957e',
  storageBucket: 'order-app-5957e.firebasestorage.app',      // lib/firebase_options.dart 와 동일
  messagingSenderId: '835847199015',                          // lib/firebase_options.dart 와 동일
  appId: '1:835847199015:web:d44f3e334dfc3d49327102',          // 웹 앱 'Qradar Admin Console' SDK 설정값
});

/** Cloud Functions 리전. 서버 함수는 전부 asia-northeast3 — SDK 에 명시하지 않으면 us-central1 로 간다. */
export const FUNCTIONS_REGION = 'asia-northeast3';

export const isFirebaseConfigured =
  typeof firebaseWebConfig.apiKey === 'string' && firebaseWebConfig.apiKey.length > 0 &&
  typeof firebaseWebConfig.appId === 'string' && firebaseWebConfig.appId.length > 0;

# Qradar Cloud Functions

Firebase Cloud Functions v2 (Node.js 22, TypeScript).
region: `asia-northeast3` (서울)

## 포함 함수

| 함수명 | 타입 | 역할 |
|---|---|---|
| `verifyTossPayment` | onCall | Toss 결제 승인 검증 + Firestore 주문 생성 |
| `cancelTossPayment` | onCall | paid → cancelled (PG 취소 + Firestore 업데이트) |
| `processRefund` | onCall | accepted+ → refunded (점주 환불 승인) |

---

## 초기 설정

```bash
cd functions
npm install
```

---

## 환경변수 설정 (TOSS_SECRET_KEY)

### 운영 환경 — Firebase Secrets Manager (권장)

```bash
# 최초 1회 등록
firebase functions:secrets:set TOSS_SECRET_KEY

# 확인
firebase functions:secrets:access TOSS_SECRET_KEY
```

> Secret 이 없으면 배포 시 오류가 발생합니다. 배포 전 반드시 등록하세요.

### 로컬 에뮬레이터 전용

1. `.env.example` 을 복사해 `.env` 생성
2. `.env` 에 실제 테스트 키 입력

```bash
cp .env.example .env
# .env 에 TOSS_SECRET_KEY=test_sk_xxx 입력
```

`.env` 는 `.gitignore` 에 포함되어 있으므로 절대 commit 되지 않습니다.

---

## 로컬 에뮬레이터 실행

```bash
# functions 디렉토리에서
npm run serve

# 또는 프로젝트 루트에서
firebase emulators:start --only functions
```

Flutter 앱에서 에뮬레이터 연결:

```dart
// main.dart 또는 firebase_options.dart 초기화 후
FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
```

---

## 빌드

```bash
npm run build       # TypeScript 컴파일 → lib/
npm run build:watch # watch 모드
```

---

## 배포

```bash
# 전체 functions 배포
firebase deploy --only functions

# 특정 함수만 배포
firebase deploy --only functions:verifyTossPayment
firebase deploy --only functions:cancelTossPayment
firebase deploy --only functions:processRefund
```

---

## region 변경 시 주의사항

현재 모든 함수는 `asia-northeast3` (서울) 로 고정되어 있습니다.
region 을 변경하려면:

1. `src/verifyTossPayment.ts`, `src/cancelTossPayment.ts`, `src/processRefund.ts` 의 `region` 옵션 수정
2. Flutter 클라이언트(`cloud_functions_remote_data_source.dart`)의 `FirebaseFunctions.instanceFor(region: ...)` 도 동일하게 수정
3. **기존 배포된 함수를 먼저 삭제한 후 새 region 으로 재배포** (동일 이름 다른 region 은 별도 함수로 취급됨)

---

## 함수별 입력 / 출력

### verifyTossPayment

**입력**:
```json
{
  "paymentKey": "...",
  "orderId": "...",
  "amount": 10000,
  "idempotencyKey": "...",
  "cart": {
    "storeId": "...",
    "storeName": "...",
    "brandId": null,
    "items": [...],
    "subtotal": 10000,
    "discount": null,
    "totalPrice": 10000
  },
  "paymentMethod": "card"
}
```

**출력**:
```json
{ "orderId": "...", "status": "paid" }
```

### cancelTossPayment

**입력**:
```json
{
  "orderId": "...",
  "reason": "고객 요청",
  "approvedBy": "customer"
}
```

**출력**:
```json
{ "orderId": "...", "status": "cancelled" }
```

### processRefund

**입력**:
```json
{
  "orderId": "...",
  "reason": "환불 사유"
}
```

**출력**:
```json
{ "orderId": "...", "status": "refunded" }
```

---

## 에러 코드

| HttpsError code | 의미 |
|---|---|
| `unauthenticated` | 로그인 필요 |
| `permission-denied` | 권한 없음 (점주 불일치 등) |
| `invalid-argument` | 입력 누락 / amount 불일치 |
| `failed-precondition` | 상태 불일치 (이미 cancelled 인데 cancel 요청 등) |
| `not-found` | 주문 / 매장 문서 없음 |
| `internal` | Toss API 호출 실패 |

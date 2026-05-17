# Qradar — Quality Grade Radar

고품질을 찾는 사람들의 레이더 역할을 하는 카페 주문 앱.

## 소개

Qradar 는 카페 매장과 메뉴를 등급(S/A/B/C)으로 평가하고, Qrator(품질 선별자) 가 가까운 매장에서 음료를 주문·결제할 수 있는 프리미엄 카페 주문 플랫폼입니다.

### 핵심 가치

- **Quality First** — 매장 등급제로 고품질 카페만 큐레이션
- **간편한 주문 흐름** — 위치 기반 추천 + 사이렌오더식 픽업
- **결제 통합** — 토스페이먼츠 기반 카드 / 카카오페이 / Qoin (앱 화폐)

## 주요 기능

### Customer (Qrator)
- 위치 기반 매장 탐색 (반경 / 등급 필터)
- 메뉴 / 옵션 / 점포 한정 메뉴 조회
- 카트 + 토스페이먼츠 결제 (카드 / 카카오페이)
- 주문 내역(Log) + 환불 요청
- Qoin 적립 / 사용 (Phase 4)

### Owner (점주)
- 매장 / 메뉴 / 옵션 관리
- 신규 주문 접수 + 환불 동의
- 매출 조회 (별 phase)

### Brand (브랜드)
- 마스터 메뉴 / 카테고리 / 옵션 그룹 관리
- 가맹점 매장 read-only + 가격 오버라이드 / 점포 한정 메뉴

### Admin
- 메뉴 분류 체계 관리
- 회원 / 매출 / 공지 / 쿠폰 (별 phase)

## 기술 스택

- **Flutter** (Dart) — iOS / Android 단일 코드베이스
- **Firebase** — Firestore / Authentication / Storage / Cloud Functions
- **Riverpod** — 상태 관리 (StreamProvider / NotifierProvider / family)
- **Clean Architecture** — domain / data / presentation 3-layer
- **freezed** — immutable entity + json_serializable
- **토스페이먼츠 결제위젯 SDK v2** — 카드 + 카카오페이
- **Cloud Functions (Node.js + TypeScript)** — 결제 검증 / 환불 처리

## 아키텍처

```
presentation/  ←  domain/  ←  data/
   (UI)         (entities,    (Firebase / Toss SDK
                 usecases,     adapters)
                 repositories)
```

Firebase / Toss SDK 직접 사용은 data 레이어 한정. 색상은 AppColors 토큰만 사용.

자세한 내용:
- `docs/architecture.md` — 아키텍처 / 디렉토리 / 네이밍
- `docs/product_scope.md` — 제품 범위 / 사용자 역할
- `docs/operations.md` — 환경 변수 / 빌드 / 배포
- `docs/tasks/[기능명]/` — 기능별 spec / design / implementation / test_report

## 개발 환경

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --dart-define-from-file=env.json
```

### 환경 변수

`env.json` (gitignore 처리됨) 에 다음 키 정의:
```json
{
  "TOSS_CLIENT_KEY": "test_ck_xxx"
}
```

### Cloud Functions

```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

`TOSS_SECRET_KEY` 는 Firebase secrets 로 관리:
```bash
firebase functions:secrets:set TOSS_SECRET_KEY
```

## 라이선스

본 프로젝트는 개인 학습 / 포트폴리오 목적으로 공개됩니다.

# 새 맥 개발환경 세팅 가이드

맥을 새로 바꿨을 때 Qradar 개발환경을 복구하는 절차.
**원칙: 소스는 git clone(깨끗), git에 없는 비밀/설정만 수동 배치, 도구는 새로 설치.**

> 이 문서를 새 맥의 Claude Code에게 주면 아래 "자동으로 시킬 수 있는 것"을 대신 실행해 준다.
> `github.com/dhqod10/Qradar 를 clone 하고 docs/new_mac_setup.md 대로 세팅해줘` 라고 하면 된다.

---

## 0. 사전 준비 (사람이 직접)

1. **이전 맥에서 만든 `qradar_migrate` 폴더를 새 맥으로 옮겨둔다** (AirDrop/iCloud/USB).
   - 보통 `~/Downloads/qradar_migrate/` 에 있게 됨. 이 가이드는 그 위치를 가정한다.
   - 폴더 구성: `project/`(비밀·설정 5종), `claude/`(memory·settings·config·skills·plugins), `README.txt`
2. **Xcode** (App Store, 용량 큼) — iOS 빌드할 때만 필요. 당장 안 급하면 나중에 설치해도 됨.
   - 설치 후 1회: `sudo xcodebuild -license accept`
3. **VS Code + Claude Code** 설치. 이후 ①~③을 Claude에게 맡길 수 있다.

---

## ① 개발도구 설치

> Claude가 대신 실행 가능. 단 Homebrew 설치·brew 설치 중 **맥 로그인 암호**를 물으면 사람이 입력.

```bash
# 1) Command Line Tools (Xcode 설치했으면 생략 가능)
xcode-select --install

# 2) Homebrew (암호 물으면 입력, 끝나면 안내하는 PATH 등록 2줄도 실행)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 3) Flutter · Node · CocoaPods · Firebase CLI
brew install --cask flutter
brew install node cocoapods
npm install -g firebase-tools

# 4) (안드로이드 빌드 시) Android Studio
brew install --cask android-studio

# 5) 점검
flutter doctor
```

---

## ② 코드 받고 비밀파일 배치

> Claude가 대신 실행 가능. **같은 경로에 clone 권장**: `~/Developer/OrderApp`

```bash
mkdir -p ~/Developer && cd ~/Developer
git clone https://github.com/dhqod10/Qradar.git OrderApp
```

그다음 `~/Downloads/qradar_migrate/project/` 의 파일들을 저장소 제자리에 복사:

```bash
MIG=~/Downloads/qradar_migrate
APP=~/Developer/OrderApp
cp "$MIG/project/env.json"                            "$APP/env.json"
cp "$MIG/project/.firebaserc"                         "$APP/.firebaserc"
cp "$MIG/project/android/app/google-services.json"    "$APP/android/app/google-services.json"
cp "$MIG/project/ios/Runner/GoogleService-Info.plist" "$APP/ios/Runner/GoogleService-Info.plist"
cp "$MIG/project/functions/.env.order-app-5957e"      "$APP/functions/.env.order-app-5957e"
```

> ⚠️ `env.json` 은 지금 Toss 키. **KG이니시스로 결제사 전환 시 이 파일 내용을 KG 값으로 교체**한다.

---

## ③ Claude Code 메모리/설정 복원

> `~/.claude/` 아래로 복사. **memory 폴더 이름은 프로젝트 절대경로**를 따른다.

```bash
MIG=~/Downloads/qradar_migrate
# 현재 사용자 기준 memory 목적지 경로 자동 계산 (OrderApp 를 ~/Developer/OrderApp 에 둔 경우)
MEMKEY="-Users-$(whoami)-Developer-OrderApp"
mkdir -p "$HOME/.claude/projects/$MEMKEY"
cp -R "$MIG/claude/memory"      "$HOME/.claude/projects/$MEMKEY/memory"
cp    "$MIG/claude/settings.json" "$HOME/.claude/settings.json"
cp    "$MIG/claude/config.json"   "$HOME/.claude/config.json"
cp -R "$MIG/claude/skills"        "$HOME/.claude/skills"
cp -R "$MIG/claude/plugins"       "$HOME/.claude/plugins"
```

> 사용자명이 `Byeonguk` 이 아니거나 clone 위치가 다르면 `MEMKEY` 가 새 경로와 맞아야 메모리가 인식된다.
> 복사 후 Claude Code를 재시작하면 메모리가 로드된다.

---

## ④ 의존성 설치 + 빌드 확인

> Claude가 대신 실행 가능. 단 `firebase login` 은 브라우저 인증이라 사람이 진행.

```bash
cd ~/Developer/OrderApp
flutter pub get
(cd functions && npm install)
(cd ios && pod install)          # Xcode 설치돼 있어야 함
flutter analyze                  # "No issues found!" 기대
firebase login                   # 브라우저에서 로그인 (사람)
firebase use order-app-5957e
flutter run                      # 기기/시뮬에서 실행 확인
```

---

## 역할 요약

| 단계 | Claude 자동 | 사람이 직접 |
|---|---|---|
| Xcode 설치 | ✗ | App Store에서 설치 |
| ① 도구 설치 | ○ | Homebrew 암호 입력만 |
| ② clone + 비밀파일 | ○ | — |
| ③ 메모리/설정 복원 | ○ | — |
| ④ 의존성·빌드 | ○ | `firebase login`(브라우저), 빌드 확인 |

---

## 참고 (옮기지 않은 것)

- 소스코드: git clone 으로 받음
- 세션 대화기록(`~/.claude/projects/*/*.jsonl`): 용량 커서 제외(복구 불필요)
- Android 릴리스 keystore: 아직 미생성. 출시용 생성 시 **절대 분실 금지**(별도 백업)
- iOS 서명 인증서: Xcode에서 Apple ID 로그인 시 자동 재발급

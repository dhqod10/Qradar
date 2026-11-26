#!/usr/bin/env python3
"""iOS Simulator 자동화 헬퍼 — 접근성 라벨 기반 조작.

Flutter 앱은 화면의 Text 위젯이 접근성 라벨(AXLabel)로 자동 노출되므로,
좌표를 추측하지 않고 라벨로 요소를 찾아 조작할 수 있다.

전제 조건:
  1. idb 설치:  brew install idb-companion && pip3 install fb-idb
  2. Simulator 접근성 활성화:
     xcrun simctl spawn <UDID> defaults write com.apple.Accessibility \
       ApplicationAccessibilityEnabled -int 1

사용법:
  python3 tools/ios_sim.py list                 # 현재 화면 요소 전체
  python3 tools/ios_sim.py find "준비"           # 라벨 부분 검색
  python3 tools/ios_sim.py tap "준비 완료"        # 라벨로 찾아 탭
  python3 tools/ios_sim.py wait "홈"            # 라벨이 뜰 때까지 대기
  python3 tools/ios_sim.py tapwait "로그인" "홈"  # 탭 후 다음 화면까지 대기
  python3 tools/ios_sim.py type "이메일" a@b.com # 필드 탭 + ASCII 입력
  python3 tools/ios_sim.py paste "이름"          # 클립보드 붙여넣기 (한글)
  python3 tools/ios_sim.py shot out.png         # 스크린샷
  python3 tools/ios_sim.py udid                 # Booted Simulator UDID
"""

import json
import os
import subprocess
import sys
import time

def _find_idb():
    """idb 실행 파일 위치. 맥마다 설치 경로가 달라 후보를 차례로 본다."""
    cands = [
        os.environ.get("IDB_PATH"),
        os.path.expanduser("~/.local/bin/idb"),
        os.path.expanduser("~/Library/Python/3.9/bin/idb"),
        "/opt/homebrew/bin/idb",
        "/usr/local/bin/idb",
    ]
    for c in cands:
        if c and os.path.exists(c):
            return c
    return "idb"  # PATH 에 있기를 기대


IDB = _find_idb()


def _run(args, **kw):
    return subprocess.run([IDB] + args, capture_output=True, text=True, **kw)


def booted_udid():
    """현재 Booted 상태인 Simulator 의 UDID 를 반환."""
    env = os.environ.get("IOS_SIM_UDID")
    if env:
        return env
    out = _run(["list-targets"])
    for line in out.stdout.splitlines():
        parts = [p.strip() for p in line.split("|")]
        if len(parts) >= 4 and parts[2] == "Booted" and parts[3] == "simulator":
            return parts[1]
    print("[FAIL] Booted 상태인 Simulator 가 없습니다.", file=sys.stderr)
    sys.exit(1)


def describe_all(udid):
    """현재 포그라운드 앱의 접근성 요소 전체를 반환."""
    out = _run(["ui", "describe-all", "--udid", udid])
    txt = out.stdout.strip()
    if not txt.startswith("["):
        print(f"[FAIL] 접근성 트리를 읽을 수 없습니다: {txt or out.stderr.strip()}",
              file=sys.stderr)
        print("  → Simulator 접근성이 꺼져 있거나 앱이 포그라운드에 없습니다.",
              file=sys.stderr)
        sys.exit(1)
    return json.loads(txt)


def _label(el):
    return (el.get("AXLabel") or "").replace("\n", " / ")


def _center(el):
    f = el["frame"]
    return int(f["x"] + f["width"] / 2), int(f["y"] + f["height"] / 2)


def cmd_list(udid):
    for el in describe_all(udid):
        lab = _label(el)
        if not lab:
            continue
        x, y = _center(el)
        print(f"{el.get('type','?'):<16} ({x:>4},{y:>4})  {lab}")


def cmd_find(udid, keyword):
    hits = [el for el in describe_all(udid) if keyword in _label(el)]
    if not hits:
        print(f"[MISS] '{keyword}' 포함 요소 없음")
        return
    for el in hits:
        x, y = _center(el)
        print(f"{el.get('type','?'):<16} ({x:>4},{y:>4})  {_label(el)}")


def cmd_tap(udid, keyword):
    hits = [el for el in describe_all(udid) if keyword in _label(el)]
    if not hits:
        print(f"[FAIL] '{keyword}' 라벨을 찾을 수 없습니다. 현재 화면 요소:")
        cmd_list(udid)
        sys.exit(1)
    # 가장 작은 요소 우선 (큰 컨테이너보다 실제 버튼일 확률이 높음)
    el = min(hits, key=lambda e: e["frame"]["width"] * e["frame"]["height"])
    x, y = _center(el)
    _run(["ui", "tap", "--udid", udid, str(x), str(y)])
    print(f"[OK] tap '{_label(el)}' at ({x}, {y})")


def cmd_wait(udid, keyword, timeout=15.0):
    """라벨이 화면에 나타날 때까지 기다린다.

    탭 직후 곧바로 다음 탭을 보내면 아직 이전 화면이라 엉뚱한 곳이 눌린다.
    화면 전환 시간은 기기·네트워크마다 달라 고정 sleep 으로는 맞출 수 없다.
    """
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            if any(keyword in _label(el) for el in describe_all(udid)):
                print(f"[OK] '{keyword}' 도착")
                return
        except SystemExit:
            pass  # 전환 중에는 트리를 못 읽는다 — 계속 기다린다.
        time.sleep(0.6)
    print(f"[TIMEOUT] {timeout}초 안에 '{keyword}' 가 나타나지 않음. 현재 화면:")
    cmd_list(udid)
    sys.exit(1)


def cmd_tap_wait(udid, keyword, expect):
    """탭한 뒤 기대 화면이 뜰 때까지 기다린다."""
    cmd_tap(udid, keyword)
    cmd_wait(udid, expect)


def cmd_type(udid, keyword, text):
    """라벨로 필드를 찾아 탭하고 ASCII 텍스트를 입력한다.

    ⚠️ 한글은 idb 가 입력하지 못한다 — 맥 `pbcopy` 로 복사한 뒤 `paste` 명령을 쓴다.
    """
    cmd_tap(udid, keyword)
    time.sleep(0.6)
    _run(["ui", "text", "--udid", udid, text])
    print(f"[OK] type into '{keyword}'")


def cmd_paste(udid, keyword):
    """라벨로 필드를 찾아 길게 눌러 클립보드 내용을 붙여넣는다 (한글 입력용).

    맥 클립보드를 거친다 — `simctl pbcopy` 로 시뮬레이터 클립보드에 직접 넣으면
    Paste 항목이 뜨지 않는다.
    """
    hits = [el for el in describe_all(udid) if keyword in _label(el)]
    if not hits:
        print(f"[FAIL] '{keyword}' 없음")
        sys.exit(1)
    el = min(hits, key=lambda e: e["frame"]["width"] * e["frame"]["height"])
    x, y = _center(el)
    _run(["ui", "tap", "--udid", udid, str(x), str(y), "--duration", "1.5"])
    time.sleep(1.2)
    paste = [e for e in describe_all(udid) if _label(e) == "Paste"]
    if not paste:
        print("[FAIL] Paste 팝업이 뜨지 않음 (클립보드가 비었거나 롱프레스 실패)")
        sys.exit(1)
    px, py = _center(paste[0])
    _run(["ui", "tap", "--udid", udid, str(px), str(py)])
    print(f"[OK] paste into '{keyword}'")


def cmd_shot(udid, path):
    _run(["screenshot", "--udid", udid, path])
    size = os.path.getsize(path) if os.path.exists(path) else 0
    print(f"[OK] screenshot -> {path} ({size} bytes)")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(0)
    cmd = sys.argv[1]
    udid = booted_udid()

    if cmd == "udid":
        print(udid)
    elif cmd == "list":
        cmd_list(udid)
    elif cmd == "find":
        cmd_find(udid, sys.argv[2])
    elif cmd == "tap":
        cmd_tap(udid, sys.argv[2])
    elif cmd == "wait":
        cmd_wait(udid, sys.argv[2],
                 float(sys.argv[3]) if len(sys.argv) > 3 else 15.0)
    elif cmd == "tapwait":
        cmd_tap_wait(udid, sys.argv[2], sys.argv[3])
    elif cmd == "type":
        cmd_type(udid, sys.argv[2], sys.argv[3])
    elif cmd == "paste":
        cmd_paste(udid, sys.argv[2])
    elif cmd == "shot":
        cmd_shot(udid, sys.argv[2] if len(sys.argv) > 2 else "ios_shot.png")
    else:
        print(f"[FAIL] 알 수 없는 명령: {cmd}")
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()

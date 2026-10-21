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
  python3 tools/ios_sim.py shot out.png         # 스크린샷
  python3 tools/ios_sim.py udid                 # Booted Simulator UDID
"""

import json
import os
import subprocess
import sys

IDB = os.path.expanduser("~/Library/Python/3.9/bin/idb")


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
    elif cmd == "shot":
        cmd_shot(udid, sys.argv[2] if len(sys.argv) > 2 else "ios_shot.png")
    else:
        print(f"[FAIL] 알 수 없는 명령: {cmd}")
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()

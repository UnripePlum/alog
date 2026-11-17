#!/usr/bin/env bash
# 패키징된 .app 이 "빌드하지 않은 맥"에서도 뜨는지 확인한다.
# SwiftPM 빌드 폴더를 잠시 숨기고(빌드 머신 절대경로 폴백 차단) 빈 홈에서 실행해,
# 일정 시간 살아 있으면 통과. 실행 직후 죽는 패키징 실수를 잡는다.
# 사용: scripts/smoke_app.sh [앱경로]
# 환경: ALOG_SMOKE_SECONDS (기본 5)
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
IDENTITY="$HERE/Sources/MonitorKit/Resources/identity.json"
read_identity() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))[sys.argv[2]])' "$IDENTITY" "$1"; }

APP="${1:-$HERE/dist/$(read_identity bundleFileName).app}"
BIN="$APP/Contents/MacOS/$(read_identity executableName)"
SECONDS_ALIVE="${ALOG_SMOKE_SECONDS:-5}"
BUILD_DIR="$HERE/.build"
HIDDEN="$HERE/.build.smoke-hidden-$$"

if [[ ! -x "$BIN" ]]; then
  echo "실행 파일이 없습니다: $BIN (먼저 scripts/build_app.sh)" >&2
  exit 1
fi

FAKE_HOME="$(mktemp -d)"
PID=""
cleanup() {
  if [[ -n "$PID" ]]; then
    kill "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true
  fi
  [[ -d "$HIDDEN" ]] && mv "$HIDDEN" "$BUILD_DIR"
  rm -rf "$FAKE_HOME"
}
trap cleanup EXIT

[[ -d "$BUILD_DIR" ]] && mv "$BUILD_DIR" "$HIDDEN"

echo "==> 빌드 폴더 없이 ${SECONDS_ALIVE}초 실행: $BIN"
CFFIXED_USER_HOME="$FAKE_HOME" "$BIN" >/dev/null 2>&1 &
PID=$!
sleep "$SECONDS_ALIVE"

if kill -0 "$PID" 2>/dev/null; then
  echo "통과: 앱이 살아 있습니다."
else
  STATUS=0
  wait "$PID" || STATUS=$?
  PID=""
  echo "실패: 앱이 실행 직후 종료했습니다 (exit $STATUS)." >&2
  exit 1
fi

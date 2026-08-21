#!/usr/bin/env bash
# SiteMonitor.app 번들 생성 (재현 가능한 로컬 빌드).
# 사용: scripts/build_app.sh [출력디렉터리]
#   기본 출력: ./dist/SiteMonitor.app
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${1:-$HERE/dist}"
APP="$OUT_DIR/SiteMonitor.app"

echo "==> swift build -c release"
( cd "$HERE" && swift build -c release )

BIN="$(cd "$HERE" && swift build -c release --show-bin-path)/SiteMonitor"
if [[ ! -x "$BIN" ]]; then
  echo "빌드 산출물을 찾을 수 없습니다: $BIN" >&2
  exit 1
fi

echo "==> .app 번들 구성: $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/SiteMonitor"
cp "$HERE/Info.plist" "$APP/Contents/Info.plist"

# 로컬 실행용 ad-hoc 코드서명 (배포 시 Developer ID 서명/공증 권장)
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || \
  echo "경고: ad-hoc 코드서명 실패(무시 가능, Gatekeeper 우클릭 열기 필요)"

echo "완료: $APP"

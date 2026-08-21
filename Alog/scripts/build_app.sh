#!/usr/bin/env bash
# Alog.app 번들 생성 (재현 가능한 로컬 빌드).
# 사용: scripts/build_app.sh [출력디렉터리]
# 이름/실행파일은 Sources/MonitorKit/Resources/identity.json 에서 읽는다.
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${1:-$HERE/dist}"
IDENTITY="$HERE/Sources/MonitorKit/Resources/identity.json"

if [[ ! -f "$IDENTITY" ]]; then
  echo "identity.json 이 없습니다: $IDENTITY" >&2
  exit 1
fi

eval "$(python3 - "$IDENTITY" <<'PY'
import json, shlex, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
for key, env in (
    ("displayName", "DISPLAY_NAME"),
    ("executableName", "EXECUTABLE_NAME"),
    ("bundleFileName", "BUNDLE_FILE_NAME"),
):
    print(f"{env}={shlex.quote(d[key])}")
PY
)"

APP="$OUT_DIR/${BUNDLE_FILE_NAME}.app"

echo "==> swift build -c release"
( cd "$HERE" && swift build -c release )

BIN="$(cd "$HERE" && swift build -c release --show-bin-path)/${EXECUTABLE_NAME}"
if [[ ! -x "$BIN" ]]; then
  echo "빌드 산출물을 찾을 수 없습니다: $BIN" >&2
  exit 1
fi

echo "==> .app 번들 구성: $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/${EXECUTABLE_NAME}"
cp "$HERE/Info.plist" "$APP/Contents/Info.plist"
if [[ -f "$HERE/Resources/AppIcon.icns" ]]; then
  cp "$HERE/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

VERSION_FILE="$HERE/../VERSION"
if [[ -f "$VERSION_FILE" ]]; then
  VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
  SHORT="$(python3 -c "print('.'.join('${VERSION}'.split('.')[:3]))")"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $SHORT" "$APP/Contents/Info.plist"
  echo "==> 버전 $VERSION (short $SHORT)"
fi

codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || \
  echo "경고: ad-hoc 코드서명 실패(무시 가능, Gatekeeper 우클릭 열기 필요)"

ZIP="$OUT_DIR/${BUNDLE_FILE_NAME}.zip"
echo "==> zip: $ZIP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "완료: $APP"
echo "배포용: $ZIP"
echo "다른 맥에서 처음 열 때: 우클릭 → 열기"
echo "표시 이름: ${DISPLAY_NAME}  (macOS 26+ 필요)"

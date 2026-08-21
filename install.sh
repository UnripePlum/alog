#!/usr/bin/env bash
# 다른 맥에서 소스만 있으면 앱을 만들어 연다. macOS 26+ 와 Xcode/Swift 필요.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/Alog"
swift test
./scripts/build_app.sh
open "dist/Alog.app"

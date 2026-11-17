#!/usr/bin/env bash
# 다른 맥에서 소스만 있으면 앱을 만들어 연다. macOS 26+ 와 Xcode/Swift 필요.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/Alog"
swift test
./scripts/build_app.sh
./scripts/smoke_app.sh
APP_NAME="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["bundleFileName"])' Sources/MonitorKit/Resources/identity.json)"
open "dist/${APP_NAME}.app"

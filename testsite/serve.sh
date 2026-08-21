#!/usr/bin/env bash
# 테스트 사이트를 로컬에서 서빙 (모니터링 픽스처).
# 사용: testsite/serve.sh [포트]   기본 포트 8765
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PORT="${1:-8765}"
echo "테스트 사이트: http://127.0.0.1:${PORT}/  (Ctrl+C로 중지)"
exec python3 -m http.server "$PORT" --directory "$HERE"

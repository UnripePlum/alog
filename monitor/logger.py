"""결과 로거: 점검 결과를 JSON Lines 파일에 append + stdout 출력.

알림/자동복구는 non-goal — 로그만 남긴다.
"""

from __future__ import annotations

import json
from pathlib import Path

from .models import CheckResult, LoggingConfig


class FileResultLogger:
    """JSONL 파일 로거. 디렉터리는 없으면 생성."""

    def __init__(self, config: LoggingConfig, *, echo: bool = True) -> None:
        self._path = Path(config.file)
        self._echo = echo
        self._path.parent.mkdir(parents=True, exist_ok=True)

    def log(self, result: CheckResult) -> None:
        record = {
            "timestamp": result.timestamp,
            "target": result.target_name,
            "url": result.url,
            "action": result.action_type,
            "status": "ok" if result.ok else "fail",
            "detail": result.detail,
            "duration_ms": result.duration_ms,
        }
        line = json.dumps(record, ensure_ascii=False)
        with self._path.open("a", encoding="utf-8") as f:
            f.write(line + "\n")
        if self._echo:
            mark = "OK " if result.ok else "FAIL"
            print(
                f"[{result.timestamp}] {mark} {result.target_name} "
                f"({result.action_type}) {result.detail} "
                f"{result.duration_ms}ms"
            )

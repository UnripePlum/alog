"""폴백 기본값을 한 곳에 모은다 (분기 리터럴 금지 원칙).

설정 파일에 값이 없을 때만 여기 상수가 쓰인다. 매장/대상-특정 값은
절대 여기 두지 않는다 — 그런 값은 오직 사용자 설정 파일에서 온다.
"""

from __future__ import annotations

DEFAULT_HEADLESS: bool = True
DEFAULT_TIMEOUT_MS: int = 30_000

DEFAULT_MIN_SECONDS: float = 300.0
DEFAULT_MAX_SECONDS: float = 900.0

DEFAULT_LOG_FILE: str = "logs/monitor.log"

DEFAULT_CONFIG_PATH: str = "config.yaml"

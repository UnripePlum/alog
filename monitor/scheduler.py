"""랜덤 간격 스케줄러.

매 사이클: 각 대상마다 다음 동작(라운드로빈)을 점검하고 로깅한 뒤,
[min, max] 사이 랜덤 초만큼 대기. 고정 시각 반복을 피한다.

라운드로빈 인덱스는 이 프로세스 안에서만 사는 휘발성 상태(단일 writer =
이 루프). 재시작하면 0부터 — 재현성/단순성 우선.
"""

from __future__ import annotations

import random
import time
from typing import Callable

from .interfaces import Checker, ResultLogger
from .models import AppConfig, CheckResult


class RandomIntervalScheduler:
    def __init__(
        self,
        config: AppConfig,
        checker: Checker,
        logger: ResultLogger,
        *,
        sleep: Callable[[float], None] = time.sleep,
        rng: random.Random | None = None,
    ) -> None:
        self._config = config
        self._checker = checker
        self._logger = logger
        self._sleep = sleep
        self._rng = rng or random.Random()
        # 대상 이름 → 다음에 수행할 동작 인덱스 (휘발성 라운드로빈 커서)
        self._cursor: dict[str, int] = {}

    def _next_index(self, target_name: str) -> int:
        idx = self._cursor.get(target_name, 0)
        self._cursor[target_name] = idx + 1
        return idx

    def run_once(self) -> list[CheckResult]:
        """모든 대상을 한 번씩 점검(각자 다음 동작)하고 결과를 로깅."""
        results: list[CheckResult] = []
        for target in self._config.targets:
            idx = self._next_index(target.name)
            result = self._checker.run_check(target, idx)
            self._logger.log(result)
            results.append(result)
        return results

    def _random_delay(self) -> float:
        s = self._config.schedule
        return self._rng.uniform(s.min_seconds, s.max_seconds)

    def run_forever(self) -> None:
        while True:
            self.run_once()
            delay = self._random_delay()
            self._sleep(delay)

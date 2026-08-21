"""설정 로더: YAML → AppConfig. 검증 + 기본값 적용.

진실의 원천은 이 YAML 하나. 대상 URL·동작·간격 등 환경/데이터 값은
전부 여기서 읽고, 코드에는 박지 않는다.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import yaml

from . import defaults
from .models import (
    ActionSpec,
    AppConfig,
    BrowserConfig,
    LoggingConfig,
    ScheduleConfig,
    Target,
)


class ConfigError(ValueError):
    """설정 파일이 유효하지 않을 때."""


def load(path: str) -> AppConfig:
    """설정 파일 경로를 받아 검증된 AppConfig를 돌려준다.

    Raises:
        ConfigError: 파일이 없거나, 필수 필드 누락, 타입 불일치.
    """
    p = Path(path)
    if not p.is_file():
        raise ConfigError(f"설정 파일을 찾을 수 없습니다: {path}")

    raw = yaml.safe_load(p.read_text(encoding="utf-8")) or {}
    if not isinstance(raw, dict):
        raise ConfigError("설정 최상위는 매핑(dict)이어야 합니다.")

    targets = _parse_targets(raw.get("targets"))
    schedule = _parse_schedule(raw.get("schedule") or {})
    browser = _parse_browser(raw.get("browser") or {})
    logging_cfg = _parse_logging(raw.get("logging") or {})

    return AppConfig(
        targets=targets,
        schedule=schedule,
        browser=browser,
        logging=logging_cfg,
    )


def _parse_targets(raw: Any) -> tuple[Target, ...]:
    if not isinstance(raw, list) or not raw:
        raise ConfigError("`targets`는 비어있지 않은 리스트여야 합니다.")
    out: list[Target] = []
    for i, item in enumerate(raw):
        if not isinstance(item, dict):
            raise ConfigError(f"targets[{i}]는 매핑이어야 합니다.")
        name = item.get("name")
        url = item.get("url")
        if not isinstance(url, str) or not url:
            raise ConfigError(f"targets[{i}].url 이 없습니다.")
        if not isinstance(name, str) or not name:
            name = url
        actions = _parse_actions(item.get("actions"), i)
        out.append(Target(name=name, url=url, actions=actions))
    return tuple(out)


def _parse_actions(raw: Any, target_idx: int) -> tuple[ActionSpec, ...]:
    if not isinstance(raw, list) or not raw:
        raise ConfigError(
            f"targets[{target_idx}].actions 는 비어있지 않은 리스트여야 합니다."
        )
    specs: list[ActionSpec] = []
    for j, a in enumerate(raw):
        if not isinstance(a, dict):
            raise ConfigError(
                f"targets[{target_idx}].actions[{j}] 는 매핑이어야 합니다."
            )
        atype = a.get("type")
        if not isinstance(atype, str) or not atype:
            raise ConfigError(
                f"targets[{target_idx}].actions[{j}].type 이 없습니다."
            )
        params = {k: v for k, v in a.items() if k != "type"}
        specs.append(ActionSpec(type=atype, params=params))
    return tuple(specs)


def _parse_schedule(raw: dict) -> ScheduleConfig:
    min_s = float(raw.get("min_seconds", defaults.DEFAULT_MIN_SECONDS))
    max_s = float(raw.get("max_seconds", defaults.DEFAULT_MAX_SECONDS))
    if min_s <= 0 or max_s <= 0:
        raise ConfigError("schedule 간격은 양수여야 합니다.")
    if min_s > max_s:
        raise ConfigError("schedule.min_seconds 는 max_seconds 이하여야 합니다.")
    return ScheduleConfig(min_seconds=min_s, max_seconds=max_s)


def _parse_browser(raw: dict) -> BrowserConfig:
    return BrowserConfig(
        headless=bool(raw.get("headless", defaults.DEFAULT_HEADLESS)),
        timeout_ms=int(raw.get("timeout_ms", defaults.DEFAULT_TIMEOUT_MS)),
    )


def _parse_logging(raw: dict) -> LoggingConfig:
    return LoggingConfig(file=str(raw.get("file", defaults.DEFAULT_LOG_FILE)))

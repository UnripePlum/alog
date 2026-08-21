"""데이터 모델 (진실의 원천은 설정 파일 → 이 불변 구조체로 로드).

모든 구조체는 frozen dataclass. 내부 상태 보관 지양 원칙에 따라
런타임에 변형하지 않고, 설정에서 읽어 그대로 들고 다닌다.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class ActionSpec:
    """페이지 안에서 수행할 단일 점검 동작의 명세.

    type: actions 레지스트리에 등록된 동작 종류 키.
    params: 동작별 파라미터(예: selector, text, pixels). 하드코딩 금지 —
            모든 값은 설정에서 주입된다.
    """

    type: str
    params: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class Target:
    """점검 대상 사이트 하나와, 그 안에서 돌아가며 수행할 동작 목록."""

    name: str
    url: str
    actions: tuple[ActionSpec, ...]


@dataclass(frozen=True)
class ScheduleConfig:
    """랜덤화된 점검 간격(초). 매 사이클 [min, max] 사이 랜덤 대기."""

    min_seconds: float
    max_seconds: float


@dataclass(frozen=True)
class BrowserConfig:
    headless: bool
    timeout_ms: int


@dataclass(frozen=True)
class LoggingConfig:
    file: str


@dataclass(frozen=True)
class AppConfig:
    targets: tuple[Target, ...]
    schedule: ScheduleConfig
    browser: BrowserConfig
    logging: LoggingConfig


@dataclass(frozen=True)
class ActionResult:
    """단일 동작 수행 결과."""

    ok: bool
    detail: str


@dataclass(frozen=True)
class CheckResult:
    """한 번의 점검(접속 + 동작 1개) 결과. 로거로 그대로 넘어간다."""

    timestamp: str
    target_name: str
    url: str
    action_type: str
    ok: bool
    detail: str
    duration_ms: int

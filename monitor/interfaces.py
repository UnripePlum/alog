"""모듈 경계 계약 (인터페이스 우선). 구현은 각 모듈이 이 Protocol을 만족.

호출부는 구현체가 아니라 이 인터페이스에만 의존한다.
"""

from __future__ import annotations

from typing import Protocol, runtime_checkable

from .models import ActionResult, AppConfig, CheckResult, Target


@runtime_checkable
class Page(Protocol):
    """동작(actions)이 의존하는 페이지의 최소 계약.

    Playwright의 sync Page를 덕타이핑으로 감싼다 — 테스트에서 스텁 주입 가능.
    """

    def goto(self, url: str, *, timeout: float) -> object: ...
    def query_selector(self, selector: str) -> object | None: ...
    def click(self, selector: str, *, timeout: float) -> None: ...
    def content(self) -> str: ...
    def evaluate(self, expression: str, arg: object = ...) -> object: ...
    def wait_for_timeout(self, timeout: float) -> None: ...


class ActionFn(Protocol):
    """단일 동작 구현. 페이지와 파라미터를 받아 결과를 돌려준다."""

    def __call__(
        self, page: Page, params: dict, timeout_ms: int
    ) -> ActionResult: ...


class ConfigLoader(Protocol):
    def load(self, path: str) -> AppConfig: ...


class Checker(Protocol):
    """대상 + 동작명세 하나를 실제로 점검하고 결과를 만든다."""

    def run_check(self, target: Target, action_index: int) -> CheckResult: ...


class ResultLogger(Protocol):
    def log(self, result: CheckResult) -> None: ...


class Scheduler(Protocol):
    def run_forever(self) -> None: ...
    def run_once(self) -> list[CheckResult]: ...

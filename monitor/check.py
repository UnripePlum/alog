"""브라우저 점검 실행기.

한 번의 점검 = (대상 접속) + (동작 1개 수행). 매 점검마다 새 브라우저
컨텍스트를 띄워 상태 누적/오염을 피한다(내부 상태 보관 지양).

Playwright는 선택적 의존성으로 취급한다 — import 실패 시 명확히 안내한다.
"""

from __future__ import annotations

import time
from datetime import datetime, timezone

from . import actions
from .interfaces import Page
from .models import BrowserConfig, CheckResult, Target


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


class SyncBrowserChecker:
    """Playwright sync API 기반 Checker 구현."""

    def __init__(self, browser: BrowserConfig) -> None:
        self._browser = browser

    def run_check(self, target: Target, action_index: int) -> CheckResult:
        spec = target.actions[action_index % len(target.actions)]
        start = time.monotonic()
        ok, detail = self._execute(target, action_index)
        duration_ms = int((time.monotonic() - start) * 1000)
        return CheckResult(
            timestamp=_now_iso(),
            target_name=target.name,
            url=target.url,
            action_type=spec.type,
            ok=ok,
            detail=detail,
            duration_ms=duration_ms,
        )

    def _execute(self, target: Target, action_index: int) -> tuple[bool, str]:
        spec = target.actions[action_index % len(target.actions)]
        try:
            from playwright.sync_api import sync_playwright
        except ImportError:
            return (
                False,
                "playwright 미설치: `pip install playwright && playwright install chromium`",
            )

        timeout_ms = self._browser.timeout_ms
        try:
            with sync_playwright() as p:
                browser = p.chromium.launch(headless=self._browser.headless)
                try:
                    page = browser.new_page()
                    page.goto(target.url, timeout=timeout_ms)
                    fn = actions.get(spec.type)
                    result = fn(page, spec.params, timeout_ms)
                    return result.ok, result.detail
                finally:
                    browser.close()
        except actions.UnknownActionError as exc:
            return False, str(exc)
        except Exception as exc:  # noqa: BLE001 - 점검 실패는 결과로 기록
            return False, f"{type(exc).__name__}: {exc}"


def run_action_on_page(page: Page, action_type: str, params: dict, timeout_ms: int):
    """테스트/재사용용: 이미 열린 페이지에 동작 하나를 적용."""
    return actions.get(action_type)(page, params, timeout_ms)

"""페이지 내 점검 동작 레지스트리.

새 동작은 @register("type")로 추가한다 — 호출부에 분기 리터럴을 늘리지 않는다.
각 동작은 성공/실패를 ActionResult로 돌려주며, 성공 = "그 부분이 정상 렌더링/동작".
"""

from __future__ import annotations

from typing import Callable

from .interfaces import Page
from .models import ActionResult

_REGISTRY: dict[str, "ActionFnImpl"] = {}

ActionFnImpl = Callable[[Page, dict, int], ActionResult]


class UnknownActionError(KeyError):
    """설정에 등록되지 않은 동작 type이 지정된 경우."""


def register(action_type: str) -> Callable[[ActionFnImpl], ActionFnImpl]:
    def deco(fn: ActionFnImpl) -> ActionFnImpl:
        _REGISTRY[action_type] = fn
        return fn

    return deco


def get(action_type: str) -> ActionFnImpl:
    try:
        return _REGISTRY[action_type]
    except KeyError as exc:
        raise UnknownActionError(
            f"알 수 없는 동작 type: {action_type!r}. "
            f"등록된 동작: {sorted(_REGISTRY)}"
        ) from exc


def registered_types() -> list[str]:
    return sorted(_REGISTRY)


# ---- 기본 제공 동작들 --------------------------------------------------------


@register("check_selector")
def _check_selector(page: Page, params: dict, timeout_ms: int) -> ActionResult:
    """특정 CSS 요소가 존재하면 정상."""
    selector = params.get("selector")
    if not selector:
        return ActionResult(False, "check_selector: selector 파라미터 누락")
    el = page.query_selector(selector)
    if el is None:
        return ActionResult(False, f"요소 없음: {selector}")
    return ActionResult(True, f"요소 확인: {selector}")


@register("check_text")
def _check_text(page: Page, params: dict, timeout_ms: int) -> ActionResult:
    """페이지 본문에 특정 텍스트가 있으면 정상."""
    text = params.get("text")
    if not text:
        return ActionResult(False, "check_text: text 파라미터 누락")
    body = page.content()
    if text in body:
        return ActionResult(True, f"텍스트 확인: {text!r}")
    return ActionResult(False, f"텍스트 없음: {text!r}")


@register("click")
def _click(page: Page, params: dict, timeout_ms: int) -> ActionResult:
    """특정 요소를 클릭. 에러 없이 완료되면 정상."""
    selector = params.get("selector")
    if not selector:
        return ActionResult(False, "click: selector 파라미터 누락")
    page.click(selector, timeout=timeout_ms)
    return ActionResult(True, f"클릭: {selector}")


@register("scroll")
def _scroll(page: Page, params: dict, timeout_ms: int) -> ActionResult:
    """지정 픽셀만큼 스크롤. 렌더링 여부와 스크립트 동작 확인용."""
    pixels = int(params.get("pixels", 0))
    page.evaluate("(y) => window.scrollBy(0, y)", pixels)
    return ActionResult(True, f"스크롤: {pixels}px")


@register("wait")
def _wait(page: Page, params: dict, timeout_ms: int) -> ActionResult:
    """지정 ms만큼 대기 (동적 렌더링 안정화용)."""
    ms = int(params.get("ms", 0))
    page.wait_for_timeout(ms)
    return ActionResult(True, f"대기: {ms}ms")

import pytest

from monitor import actions
from monitor.models import ActionResult


class StubPage:
    """Page 계약을 최소 구현한 테스트용 스텁 (브라우저 불필요)."""

    def __init__(self, *, html="", elements=None):
        self._html = html
        self._elements = elements or {}
        self.clicked = []
        self.scrolled = []
        self.waited = []

    def goto(self, url, *, timeout):
        return None

    def query_selector(self, selector):
        return self._elements.get(selector)

    def click(self, selector, *, timeout):
        self.clicked.append(selector)

    def content(self):
        return self._html

    def evaluate(self, expression, arg=None):
        self.scrolled.append(arg)
        return None

    def wait_for_timeout(self, timeout):
        self.waited.append(timeout)


def test_check_selector_found():
    page = StubPage(elements={"h1": object()})
    res = actions.get("check_selector")(page, {"selector": "h1"}, 1000)
    assert isinstance(res, ActionResult)
    assert res.ok is True


def test_check_selector_missing():
    page = StubPage(elements={})
    res = actions.get("check_selector")(page, {"selector": "h1"}, 1000)
    assert res.ok is False


def test_check_selector_no_param():
    page = StubPage()
    res = actions.get("check_selector")(page, {}, 1000)
    assert res.ok is False


def test_check_text_present():
    page = StubPage(html="<body>Hello World</body>")
    res = actions.get("check_text")(page, {"text": "Hello"}, 1000)
    assert res.ok is True


def test_check_text_absent():
    page = StubPage(html="<body>Hello</body>")
    res = actions.get("check_text")(page, {"text": "Missing"}, 1000)
    assert res.ok is False


def test_click_records():
    page = StubPage()
    res = actions.get("click")(page, {"selector": "button"}, 1000)
    assert res.ok is True
    assert page.clicked == ["button"]


def test_scroll():
    page = StubPage()
    res = actions.get("scroll")(page, {"pixels": 300}, 1000)
    assert res.ok is True
    assert page.scrolled == [300]


def test_wait():
    page = StubPage()
    res = actions.get("wait")(page, {"ms": 250}, 1000)
    assert res.ok is True
    assert page.waited == [250]


def test_unknown_action():
    with pytest.raises(actions.UnknownActionError):
        actions.get("does_not_exist")


def test_registered_types():
    types = actions.registered_types()
    assert {"check_selector", "check_text", "click", "scroll", "wait"} <= set(types)

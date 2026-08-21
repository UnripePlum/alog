import random

from monitor.models import (
    ActionSpec,
    AppConfig,
    BrowserConfig,
    CheckResult,
    LoggingConfig,
    ScheduleConfig,
    Target,
)
from monitor.scheduler import RandomIntervalScheduler


class FakeChecker:
    """호출된 (target, action_index)를 기록하는 가짜 Checker."""

    def __init__(self):
        self.calls = []

    def run_check(self, target, action_index):
        self.calls.append((target.name, action_index))
        spec = target.actions[action_index % len(target.actions)]
        return CheckResult(
            timestamp="t",
            target_name=target.name,
            url=target.url,
            action_type=spec.type,
            ok=True,
            detail="",
            duration_ms=1,
        )


class FakeLogger:
    def __init__(self):
        self.logged = []

    def log(self, result):
        self.logged.append(result)


def _config(targets):
    return AppConfig(
        targets=tuple(targets),
        schedule=ScheduleConfig(min_seconds=1, max_seconds=2),
        browser=BrowserConfig(headless=True, timeout_ms=1000),
        logging=LoggingConfig(file="x.log"),
    )


def _target(name):
    return Target(
        name=name,
        url=f"https://{name}/",
        actions=(ActionSpec("check_text", {"text": "a"}), ActionSpec("scroll", {"pixels": 1})),
    )


def test_run_once_covers_all_targets():
    cfg = _config([_target("a"), _target("b")])
    checker, logger = FakeChecker(), FakeLogger()
    sched = RandomIntervalScheduler(cfg, checker, logger)

    results = sched.run_once()
    assert len(results) == 2
    assert len(logger.logged) == 2
    assert {c[0] for c in checker.calls} == {"a", "b"}


def test_action_rotation_round_robin():
    cfg = _config([_target("a")])
    checker, logger = FakeChecker(), FakeLogger()
    sched = RandomIntervalScheduler(cfg, checker, logger)

    sched.run_once()
    sched.run_once()
    sched.run_once()
    # 동일 대상의 action_index 가 0,1,2 로 증가해야 함
    assert [idx for (_, idx) in checker.calls] == [0, 1, 2]


def test_run_forever_uses_random_delay_and_stops():
    cfg = _config([_target("a")])
    checker, logger = FakeChecker(), FakeLogger()
    sleeps = []

    def fake_sleep(sec):
        sleeps.append(sec)
        if len(sleeps) >= 3:
            raise KeyboardInterrupt

    sched = RandomIntervalScheduler(
        cfg, checker, logger, sleep=fake_sleep, rng=random.Random(42)
    )
    try:
        sched.run_forever()
    except KeyboardInterrupt:
        pass

    assert len(sleeps) == 3
    for s in sleeps:
        assert 1 <= s <= 2  # schedule 범위 내 랜덤

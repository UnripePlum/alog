import textwrap

import pytest

from monitor import config as config_mod
from monitor import defaults


def _write(tmp_path, text):
    p = tmp_path / "config.yaml"
    p.write_text(textwrap.dedent(text), encoding="utf-8")
    return str(p)


def test_load_minimal(tmp_path):
    path = _write(
        tmp_path,
        """
        targets:
          - name: home
            url: https://example.com/
            actions:
              - type: check_text
                text: Example
        """,
    )
    cfg = config_mod.load(path)
    assert len(cfg.targets) == 1
    t = cfg.targets[0]
    assert t.url == "https://example.com/"
    assert t.actions[0].type == "check_text"
    assert t.actions[0].params == {"text": "Example"}
    # 기본값 적용 확인
    assert cfg.schedule.min_seconds == defaults.DEFAULT_MIN_SECONDS
    assert cfg.browser.headless == defaults.DEFAULT_HEADLESS
    assert cfg.logging.file == defaults.DEFAULT_LOG_FILE


def test_name_defaults_to_url(tmp_path):
    path = _write(
        tmp_path,
        """
        targets:
          - url: https://x.example/
            actions:
              - type: scroll
                pixels: 100
        """,
    )
    cfg = config_mod.load(path)
    assert cfg.targets[0].name == "https://x.example/"


def test_missing_file():
    with pytest.raises(config_mod.ConfigError):
        config_mod.load("/nonexistent/config.yaml")


def test_empty_targets(tmp_path):
    path = _write(tmp_path, "targets: []\n")
    with pytest.raises(config_mod.ConfigError):
        config_mod.load(path)


def test_action_without_type(tmp_path):
    path = _write(
        tmp_path,
        """
        targets:
          - url: https://x/
            actions:
              - selector: h1
        """,
    )
    with pytest.raises(config_mod.ConfigError):
        config_mod.load(path)


def test_bad_schedule_order(tmp_path):
    path = _write(
        tmp_path,
        """
        targets:
          - url: https://x/
            actions:
              - type: wait
                ms: 1
        schedule:
          min_seconds: 100
          max_seconds: 10
        """,
    )
    with pytest.raises(config_mod.ConfigError):
        config_mod.load(path)

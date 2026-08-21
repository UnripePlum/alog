"""엔트리포인트: 설정 로드 → 컴포넌트 조립 → 스케줄러 실행.

사용법:
    python -m monitor --config config.yaml
    python -m monitor --config config.yaml --once   # 한 사이클만
"""

from __future__ import annotations

import argparse
import sys

from . import config as config_mod
from . import defaults
from .check import SyncBrowserChecker
from .logger import FileResultLogger
from .scheduler import RandomIntervalScheduler


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="monitor",
        description="사이트 가동 모니터링 (synthetic monitoring)",
    )
    parser.add_argument(
        "--config",
        default=defaults.DEFAULT_CONFIG_PATH,
        help=f"설정 파일 경로 (기본: {defaults.DEFAULT_CONFIG_PATH})",
    )
    parser.add_argument(
        "--once",
        action="store_true",
        help="한 사이클만 실행하고 종료",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)

    try:
        cfg = config_mod.load(args.config)
    except config_mod.ConfigError as exc:
        print(f"설정 오류: {exc}", file=sys.stderr)
        return 2

    checker = SyncBrowserChecker(cfg.browser)
    logger = FileResultLogger(cfg.logging)
    scheduler = RandomIntervalScheduler(cfg, checker, logger)

    if args.once:
        results = scheduler.run_once()
        return 0 if all(r.ok for r in results) else 1

    try:
        scheduler.run_forever()
    except KeyboardInterrupt:
        print("\n중단됨.", file=sys.stderr)
        return 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

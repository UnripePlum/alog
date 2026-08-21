# Testing

100% test coverage is the goal — tests make changes safe.

## Commands
- Python unit tests: `python -m pytest` (deps: `requirements-dev.txt`)
- Swift engine tests: `cd Alog && swift test`
- macOS app bundle: `cd Alog && ./scripts/build_app.sh`

## Layers
- **Unit:** `MonitorKit` (TargetFactory, ConfigStore, ActionJS, logger) and `tests/` for the Python CLI.
- **Integration:** Swift `swift test` covers config round-trip and starter fallback.
- **Manual:** first-run empty window → 사이트 추가 (⌘N) → URL → 대상이 목록에 생기고 기본 점검 동작 4개가 붙는지. 설정 → 업데이트 확인.

## Conventions
- Swift tests live in `Alog/Tests/MonitorKitTests/`.
- Python tests live in `tests/test_*.py`.
- New functions get a corresponding test. Bug fixes get a regression test.

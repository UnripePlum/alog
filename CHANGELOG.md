# Changelog

## [0.6.0.0] - 2026-08-21

### Added
- 원격 `update-policy.json`의 `minimumVersion`보다 낮은 앱은 점검을 막고 업데이트만 받습니다. 지금은 0.0.0.0이라 강제하지 않습니다.

## [0.5.0.0] - 2026-08-21

### Added
- 앱 안에서 업데이트 확인. GitHub Releases의 최신 zip을 받아 설치하고 다시 시작합니다 (설정, 메뉴 막대, Alog → 업데이트 확인).

## [0.4.0.0] - 2026-08-21

### Changed
- 앱 이름을 **Alog** 로 바꿨습니다. identity.json · 번들 · 설정 폴더 · GitHub 저장소가 모두 Alog입니다.
- 예전 SiteMonitor / Web Visitor 설정은 첫 실행 때 `~/Library/Application Support/Alog/` 로 복사합니다.

## [0.3.0.0] - 2026-08-21

### Changed
- 앱 이름을 **Web Visitor** 로 바꿨습니다. 표시 이름·번들 id·설정 폴더는 `identity.json` 한 곳에서 읽습니다.
- GitHub 저장소: `web-visitor`. 설치는 릴리즈 zip 또는 `./install.sh`.

### Added
- 예전 SiteMonitor 설정 폴더를 WebVisitor 폴더로 한 번 복사합니다.
- 태그 `v*` 푸시 시 zip을 GitHub Release에 올리는 워크플로.

## [0.2.0.0] - 2026-08-21

### Added
- 사이트 추가 화면: 이름·주소를 넣고 바로 모니터링 대상을 만듭니다 (⌘N, 툴바 +, 왼쪽 아래 버튼).
- 추가 즉시 WebKit으로 실제 페이지를 열고, 창을 닫아도 메뉴 막대에서 백그라운드 점검을 이어갑니다.
- 처음 실행하면 빈 목록과 안내가 나옵니다. 다른 사람 사이트는 기본값으로 넣지 않습니다.
- 주소에 `https://`가 없으면 자동으로 붙입니다.
- 소스에서 `.app`과 배포용 zip을 만드는 빌드 스크립트, GitHub Actions 테스트 워크플로.

### Fixed
- 사이트 추가 버튼이 창 툴바에 가려져 보이지 않던 문제를 고쳤습니다.
- `mailto:`, `https:/…` 같은 잘못된 주소는 더 이상 사이트로 추가되지 않습니다.

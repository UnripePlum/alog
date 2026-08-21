# SiteMonitor — 사이트 가동 모니터링 (Synthetic Monitoring)

설정한 웹사이트가 **정상적으로 살아있는지** 실제 브라우저로 주기적으로 접속해 확인합니다.
매 사이클 페이지 안의 서로 다른 동작(요소 확인·텍스트 확인·클릭·스크롤)을 돌아가며 수행해
사이트의 여러 부분이 제대로 렌더링/동작하는지 점검하고, 결과를 로그로 남깁니다.

> **정당한 용도 전용**입니다. 조회수 조작, 봇 탐지 회피, 대량 트래픽 생성은 **비목표(non-goal)** 이며
> 이 프로젝트의 범위가 아닙니다. 본인이 소유/운영하거나 모니터링 권한이 있는 사이트에 사용하세요.

## 두 가지 형태

| | **Swift macOS 앱** (`SiteMonitorApp/`) | **Python CLI** (`monitor/`) |
|---|---|---|
| 대상 사용자 | 다운받아 GUI로 쓰는 일반 사용자 | 서버/터미널 자동화 |
| 브라우저 엔진 | WebKit `WebPage` (OS 내장, 의존성 0) | Playwright(Chromium) |
| 최소 요구 | **macOS 26+** | Python 3.11+ |
| 설정 | 앱 UI에서 편집 (JSON 저장) | `config.yaml` |
| 배포 | 단일 `.app` | pip 설치 |

---

## Swift macOS 앱

### 빌드 & 실행
```bash
cd SiteMonitorApp
swift test                 # 엔진 유닛 테스트
./scripts/build_app.sh     # dist/SiteMonitor.app 생성 (ad-hoc 서명)
open dist/SiteMonitor.app
```
> 서명되지 않은 앱이라 처음 열 때 Gatekeeper가 막으면 **우클릭 → 열기**로 허용하세요.
> 타인 배포 시에는 Developer ID 서명 + 공증(notarization)을 권장합니다.

### 사용
1. 왼쪽 **＋** 로 대상 추가 → 이름/URL 입력.
2. **점검 동작**을 추가 (매 사이클 순환 수행):
   - **요소 확인** / **클릭**: CSS 선택자 (예: `#main`, `.article-title`)
   - **텍스트 확인**: 페이지에 있어야 할 실제 텍스트
   - **스크롤** / **대기**
3. 상단 **설정**에서 주기(랜덤 최소~최대 초)·타임아웃·안정화 대기 조정.
4. **시작**으로 주기 모니터링, **즉시 점검**으로 1회 실행.
5. 설정: `~/Library/Application Support/SiteMonitor/config.json`,
   로그: 같은 폴더의 `monitor.log` (JSON Lines).

### ⚠️ 살아있음 판정 팁 (중요)
`html`, `body`처럼 **에러 페이지에도 존재하는** 요소로 확인하면, 사이트가 죽어
브라우저 에러 페이지가 떠도 "정상"으로 잡힙니다. 반드시 **정상 페이지에만 있는
실제 콘텐츠**(고유 텍스트/요소)를 확인 대상으로 쓰세요. 접속 자체가 실패(DNS·연결 실패)하면
네비게이션 오류로 즉시 실패 처리됩니다.

---

## Python CLI

### 설치 & 실행
```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
playwright install chromium         # 최초 1회 브라우저 다운로드
cp config.example.yaml config.yaml  # 대상/동작/주기 편집
python -m monitor --config config.yaml          # 주기 실행
python -m monitor --config config.yaml --once   # 1회 실행
```

### 테스트
```bash
pip install -r requirements-dev.txt
pytest
```

설정 스키마는 `config.example.yaml` 참고. 로그는 `logging.file` 경로에 JSON Lines로 append.

---

## 설계 원칙
- **인터페이스 우선 · 모듈화**: 설정 로더 / 스케줄러 / 체커 / 동작 레지스트리 / 로거를 분리.
- **하드코딩 금지**: 대상 URL·동작·주기 등은 전부 설정에서 읽음(코드에 없음).
- **재현성**: 머신 고유값 미포함, 예시 설정 템플릿 제공, 위 절차만으로 부팅.
- **비목표**: 알림·자동복구·다중 디바이스·조회수 조작·탐지 회피.

전체 요구사항 스펙: `.omc/specs/deep-interview-site-liveness-monitor.md`

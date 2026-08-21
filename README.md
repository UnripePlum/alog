# SiteMonitor — 사이트 가동 모니터링

설정한 웹사이트가 **정상적으로 살아있는지**, 백그라운드에서 **실제 브라우저(WebKit)로 페이지를 열어** 주기적으로 확인합니다.
창을 닫아도 메뉴 막대에서 계속 돌고, 매 사이클 로드·제목·본문·스크롤을 점검한 뒤 로그로 남깁니다.

> **정당한 용도 전용.** 조회수 조작, 봇 탐지 회피, 대량 트래픽 생성은 범위가 아닙니다.
> 본인이 소유·운영하거나 모니터링 권한이 있는 사이트에만 쓰세요.

## 두 가지 형태

| | **Swift macOS 앱** (`SiteMonitorApp/`) | **Python CLI** (`monitor/`) |
|---|---|---|
| 대상 사용자 | GUI로 쓰는 일반 사용자 | 서버/터미널 자동화 |
| 브라우저 엔진 | WebKit `WebPage` (OS 내장) | Playwright(Chromium) |
| 최소 요구 | **macOS 26+** | Python 3.11+ |
| 설정 | 앱에서 사이트 추가 (JSON 저장) | `config.yaml` |
| 배포 | `SiteMonitor.app` / zip | pip 설치 |

---

## macOS 앱 — 설치

### 소스에서 빌드 (권장, 재현 가능)
```bash
git clone https://github.com/UnripePlum/sitemonitor.git
cd sitemonitor/SiteMonitorApp
swift test
./scripts/build_app.sh
open dist/SiteMonitor.app
```
산출물: `dist/SiteMonitor.app`, 배포용 `dist/SiteMonitor.zip`.

처음 열 때 Gatekeeper가 막으면 **우클릭 → 열기**. (로컬 ad-hoc 서명. 타인 배포 시 Developer ID + 공증을 권장합니다.)

`Applications`로 쓰려면:
```bash
cp -R dist/SiteMonitor.app /Applications/
```

### 첫 실행
1. 창이 비어 있으면 **사이트 추가** (⌘N) 또는 왼쪽 아래 버튼을 누릅니다.
2. 이름(선택)과 주소를 넣습니다. `example.com`처럼 스킴이 없으면 `https://`를 붙입니다.
3. 추가하는 순간 실제 페이지를 열고 점검을 시작합니다. 창을 닫아도 메뉴 막대에서 계속 돌아갑니다.
4. **중지**로 그 사이트만 끄고, **즉시 점검**으로 지금 한 번 더 들어갑니다.

설정: `~/Library/Application Support/SiteMonitor/config.json`  
로그: 같은 폴더의 `monitor.log` (JSON Lines).

다른 사람의 블로그 URL은 기본값으로 들어가지 않습니다. 각자 자기 사이트를 추가합니다.

### 살아있음 판정 팁
`html`, `body`처럼 에러 페이지에도 있는 요소로 확인하면, 사이트가 죽어도 "정상"으로 잡힙니다.
접속 실패(DNS·연결 실패)는 네비게이션 오류로 즉시 실패입니다. 고유 텍스트/요소를 확인 대상으로 쓰세요.

---

## Python CLI

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
playwright install chromium
cp config.example.yaml config.yaml
python -m monitor --config config.yaml
python -m monitor --config config.yaml --once
```

테스트:
```bash
pip install -r requirements-dev.txt
pytest
```

설정 스키마는 `config.example.yaml`. 로그는 `logging.file` 경로에 JSON Lines로 append.

---

## 설계 원칙
- 인터페이스 우선 · 모듈화: 설정 / 스케줄러 / 체커 / 동작 / 로거 / 대상 생성 계약을 분리.
- 하드코딩 금지: 대상 URL·동작·주기는 설정에서 읽음. 앱은 빈 목록으로 시작합니다.
- 재현성: 머신 고유값 없음. 위 절차만으로 빌드·실행.

스펙: `.omc/specs/deep-interview-site-liveness-monitor.md`

# Alog

백그라운드에서 **실제 브라우저(WebKit)** 로 페이지를 열어, 사이트가 살아 있는지 점검합니다.
창을 닫아도 메뉴 막대에서 계속 돌고, 매 사이클 로드·제목·본문·스크롤을 확인한 뒤 로그로 남깁니다.

> **정당한 용도 전용.** 조회수 조작, 봇 탐지 회피, 대량 트래픽 생성은 범위가 아닙니다.
> 본인이 소유·운영하거나 모니터링 권한이 있는 사이트에만 쓰세요.

**다른 맥에서도 동일하게 돌아가야 합니다.** 머신 고유 경로·계정·사이트 URL은 코드에 없습니다.

## 설치 (다른 컴퓨터)

요구: **macOS 26+**. 그 이하는 WebKit `WebPage` API가 없어 실행되지 않습니다.

### 1) 릴리즈 zip (Xcode 없이)

1. [Releases](https://github.com/UnripePlum/alog/releases/latest)에서 `Alog.zip`을 받습니다.
2. 압축을 풀고 `Alog.app`을 `/Applications`로 옮깁니다.
3. **우클릭 → 열기** (서명·공증 전이라 Gatekeeper가 한 번 막습니다).
4. 사이트 추가 (⌘N). 넣는 순간 실제 페이지를 열고 점검을 시작합니다.
5. 이후 버전은 앱의 **설정 → 버전 → 업데이트 확인** 또는 메뉴 **업데이트 확인…** 으로 받습니다. GitHub Releases zip을 받아 현재 앱을 교체한 뒤 다시 시작합니다.

구버전을 막으려면 저장소 루트 `update-policy.json`의 `minimumVersion`을 올리면 됩니다. 그 버전보다 낮은 앱은 점검을 멈추고 업데이트만 할 수 있습니다. 지금은 `0.0.0.0`이라 아무도 막지 않습니다.

CI가 같은 스크립트(`Alog/scripts/build_app.sh`)로 zip을 만듭니다.

### 2) 소스에서 빌드 (재현용)

Xcode 또는 Swift toolchain이 있는 맥:

```bash
git clone https://github.com/UnripePlum/alog.git
cd alog
chmod +x install.sh
./install.sh
```

또는:

```bash
cd Alog
swift test
./scripts/build_app.sh
open dist/Alog.app
```

표시 이름·번들 id·설정 폴더는 `Alog/Sources/MonitorKit/Resources/identity.json` 한 곳입니다.

설정: `~/Library/Application Support/Alog/config.json`  
로그: 같은 폴더의 `monitor.log`

예전에 SiteMonitor / Web Visitor로 쓰던 설정은 첫 실행 때 이 폴더로 복사합니다. 다른 사람 사이트 URL은 기본값으로 넣지 않습니다.

### 살아있음 판정 팁
`html`, `body`처럼 에러 페이지에도 있는 요소로 확인하면, 사이트가 죽어도 "정상"으로 잡힙니다.
접속 실패(DNS·연결 실패)는 즉시 실패입니다. 고유 텍스트/요소를 확인 대상으로 쓰세요.

---

## Python CLI (서버/터미널)

앱과 같은 점검이지만 Playwright를 씁니다.

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
playwright install chromium
cp config.example.yaml config.yaml
python -m monitor --config config.yaml
```

테스트: `pip install -r requirements-dev.txt && python -m pytest`

---

## 설계 원칙
- 인터페이스 우선 · 모듈화
- 하드코딩 금지: 대상 URL·동작·주기·앱 이름은 설정/identity에서 읽음
- 재현성: 위 절차만으로 다른 맥에서 빌드·실행

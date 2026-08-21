# Deep Interview Spec: 사이트 가동 모니터링 (Site Liveness Monitor)

## Metadata
- Interview ID: site-liveness-monitor
- Rounds: 7 (+ Round 0 topology)
- Final Ambiguity Score: 16%
- Type: greenfield
- Generated: 2026-07-07
- Threshold: 0.2
- Threshold Source: default
- Initial Context Summarized: no
- Status: PASSED

## Clarity Breakdown
| Dimension | Score | Weight | Weighted |
|-----------|-------|--------|----------|
| Goal Clarity | 0.90 | 0.40 | 0.36 |
| Constraint Clarity | 0.80 | 0.30 | 0.24 |
| Success Criteria | 0.80 | 0.30 | 0.24 |
| **Total Clarity** | | | **0.84** |
| **Ambiguity** | | | **0.16** |

## Topology
| Component | Status | Description | Coverage / Deferral Note |
|-----------|--------|-------------|--------------------------|
| 설정(Config) | active | 대상 사이트·점검 동작·주기 등을 유저가 설정 | 설정 파일 기반, 하드코딩 금지 |
| 스케줄러(Scheduler) | active | 랜덤화된 간격으로 점검 트리거 | 랜덤 간격 반복 |
| 방문 동작(Check) | active | 실제 브라우저로 접속, 페이지 내 여러 동작을 돌아가며 수행 | 동작 성공 = 렌더링 정상 |
| 기록(Logging) | active | 언제/무엇을/성공·실패를 로그로 남김 | 알림·자동복구 없음, 로그만 |

> 처음 defer했던 기록 컴포넌트는 Round 3("로그만 남기면 됨")에서 유일한 출력 채널로 확정되어 active로 전환됨. 디바이스 오케스트레이션은 Round 2("실행기 하나면 충분")에서 제거됨.

## Goal
유저가 설정한 웹사이트(들)가 정상적으로 살아있는지를, **실제 브라우저로 주기적으로 접속**해 확인하는 가동 모니터링 프로그램. 단일 실행기(PC)에서 랜덤화된 간격으로 실행하며, 매 사이클마다 **페이지 안의 서로 다른 동작을 돌아가며** 수행해 사이트의 여러 부분이 정상 렌더링/동작하는지 점검하고 결과를 로그로 남긴다. (조회수 조작·봇 탐지 회피 목적 아님 — 정상 synthetic monitoring.)

## Constraints
- 실행기는 **하나**로 충분 (여러 디바이스/원격 디바이스 오케스트레이션 불필요).
- 대상 사이트는 **코드에 박지 않고 설정 파일**에서 읽는다 (하드코딩 금지).
- 점검 주기는 **랜덤화된 간격** (고정 시각 반복 회피, 부하 분산).
- 실제 브라우저 렌더링을 확인하므로 헤드리스 브라우저(예: Playwright) 사용.
- 정상/비정상 판정 = 지정된 **페이지 내 동작이 에러 없이 완료**되는지.

## Non-Goals
- 조회수 증가/지표 부풀리기 (명시적 제외).
- 봇 탐지 회피를 위한 행동 변조 (명시적 제외 — 동작을 바꾸는 이유는 오직 "여러 부분 점검").
- 실패 시 알림(카톡/메일/Slack 등) — 이번 범위 아님, 로그만.
- 실패 시 자동 복구(재시작 등) — 범위 아님.
- 여러 위치/IP 분산 접속 — 범위 아님.

## Acceptance Criteria
- [ ] 대상 사이트 URL과 점검 동작 목록을 설정 파일에서 읽어 동작한다 (코드 수정 없이 대상 변경 가능).
- [ ] 랜덤화된 간격으로 반복 실행된다.
- [ ] 매 사이클 헤드리스 브라우저로 대상에 접속한다.
- [ ] 매 사이클 설정된 여러 페이지 내 동작 중 하나(또는 로테이션)를 수행하고, 에러 없이 완료되면 "정상"으로 판정한다.
- [ ] 각 점검의 시각·대상·수행 동작·성공/실패를 로그로 남긴다.
- [ ] 다른 사람이 클론 후 문서대로 셋업하면 동일하게 동작한다 (재현성).

## Assumptions Exposed & Resolved
| Assumption | Challenge | Resolution |
|------------|-----------|------------|
| "조회수 증가" (README) | 실제 목적 확인 | 가동 모니터링이 목적, 조회수 아님 |
| "봇 분류 안되게" = 탐지 회피 | 왜 필요한가 | 감시 접속이 차단당하면 모니터링 불가 방지용, 회피 목적 아님 |
| "다양한 디바이스" | 왜 여러 디바이스 | 실행기 하나면 충분, 요구 아니었음 |
| "제대로 렌더링" | 구체 판정법 | 페이지 내 동작이 에러 없이 완료 |
| "매번 다른 행동" | 진짜 이유(탐지회피 vs 점검) | 사이트의 여러 부분을 돌아가며 점검 |
| 실패 시 대응 | 알림/복구 필요? | 로그만 |

## Technical Context
- 스택(README 기준): Python + Playwright(헤드리스 브라우저) + 로그(파일/SQLite).
- 코딩 규약: 인터페이스 우선(점검 동작·스케줄러·로거의 계약을 먼저 정의), 모듈화(1 책임 1 모듈), 설정/데이터에서 진실을 읽고 상태 중복 지양, 머신 고유값 주입, example 설정 템플릿 제공.
- 제안 모듈 경계(초안): `config`(설정 로더) / `scheduler`(랜덤 간격) / `check`(브라우저 접속 + 동작 로테이션) / `logger`(결과 기록).

## Ontology (Key Entities)
| Entity | Type | Fields | Relationships |
|--------|------|--------|---------------|
| TargetSite | core domain | url, name | has many CheckAction |
| CheckAction | core domain | id, type(클릭/스크롤/검색 등), selector/params | belongs to TargetSite |
| CheckRun | core domain | timestamp, target, action, result(성공/실패), error | produces LogEntry |
| Schedule | supporting | interval_range(랜덤 min~max) | triggers CheckRun |
| Config | supporting | sites[], actions[], schedule | drives all |
| LogEntry | supporting | timestamp, target, action, status | from CheckRun |

## Ontology Convergence
| Round | 핵심 엔티티 변화 |
|-------|------------------|
| 1-2 | 대상·방문 개념 등장, 디바이스 개념 제거 |
| 3-4 | 로그(LogEntry) 확정, 알림/복구 제거 |
| 5-7 | CheckAction(페이지 내 동작 로테이션) 확정, Config 중심으로 안정화 |

## Interview Transcript
<details>
<summary>Full Q&A (7 rounds + Round 0)</summary>

- **R0 토폴로지:** 4개 후보 제시 → "한번 설정하면 핸드폰에서 주기적으로 그 사이트에 들어가는거야"
- **R1 실행환경:** "pc에서 자동으로 접속하는거지. 대신 봇으로 분류되면 안돼" → (조회수+회피로 해석되어 일시 거절) → 유저 정정: "조회수가 아니라 사이트가 살아있는지 판단하려고 직접 접속 필요"
- **R1' 판정기준:** "페이지가 제대로 렌더링되는지"
- **R2 디바이스 이유:** "실행기 하나면 충분"
- **R3 실패 시 동작:** "로그만 남기면 됨"
- **R4 렌더링 판정(Contrarian):** "매번 체크할 때 다른 행동을 해서 성공하면 돼"
- **R5 다른 행동 이유:** "사이트의 여러 부분을 돌아가며 점검하려고" (→ 정당한 synthetic monitoring 확정)
- **R6 주기(Simplifier):** "랜덤화된 간격"
- **R7 대상 범위:** "대상 사이트는 유저가 설정할 수 있게, 페이지 안의 여러 동작으로"

</details>

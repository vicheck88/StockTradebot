---
description: 문서·코드를 라운드 단위로 다중 채점(claude 측 + codex)과 교차 합의로 점수화하고 약점을 일괄 수정하는 반복 개선 루프
argument-hint: "[path|--path path] [--mode m] [--target N] [--rounds N] [--score-only] [--focus dims] [--model-policy 역할=모델] [--tdd|--no-tdd] [--from m] [--to m] [--reset] [--ask]"
---

문서와 코드를 반복적으로 평가하고 개선하는 커맨드. 차원 가중 종합점수 평가 → 약점 전체 진단 → 일괄 수정 → 재평가.

사용 경계: /refine은 측정 가능한 품질 점수를 **반복 라운드**로 끌어올릴 때 쓴다. 단발 리뷰는 /review·/code-review, 원인 조사·버그 수정은 /investigate 계열, 이미 알려진 실패를 고치는 반복 fix-verify 루프는 /qa 계열 스킬(설치된 경우)이 맞다. /refine은 점수·차원·audit ledger를 기준으로 batch 개선할 때만 선택한다.

**한 라운드 = 모든 약점 일괄 수정**. 한 라운드에 한 약점 모델은 폐기됨. DIAGNOSE에서 70 미만 모든 차원/문항을 식별하고, PROPOSE에서 각각의 수정안을 작성하고, APPLY에서 동시에 반영한다.

**⚠ HARD CONSTRAINT**
- 절차를 임의로 변경하지 마라. main thread 단독 채점 금지 — 채점은 main이 아닌 별도 채점 주체가 수행한다: named Agent(claude-scorer) **또는 Workflow 채점 파이프라인** (refine-steps.md `## 오케스트레이션 & 모델 정책`). codex 역할(scorer/조건부 proposer/reviewer)은 Agent가 **아니라 CLI job**으로 호출한다 — `codex:codex-rescue`는 Bash 전용이라 `SendMessage`가 없어 조율/정상 종료가 안 되기 때문 (SSOT: refine-steps.md `## Step 0 멤버 구성`, `## Codex CLI job 호출 공통 규칙`).
- 매 라운드 시작 시 `Read("~/.claude/commands/refine-steps.md")` 로 절차를 다시 읽어라. 기억에 의존하지 마라.
- 절차 변경이 필요하면: (1) 파일을 먼저 수정하고 (2) 사용자에게 알린 뒤 (3) 수정된 절차를 따라라.
- 데이터 날조 절대 금지. 출처 없는 수치 = 해당 차원 0점.
- **판단 위임 금지**: main은 종료 여부, PROPOSE_COMPARE 채택, audit cap 보정, KEEP/ROLLBACK 판정을 사용자·서브에이전트·codex 결과에 떠넘기지 않는다. 조기 종료·날조 수치와 동급 함정으로 취급하며, "어느 안이 나은지 사용자가 정해 달라" 또는 "reviewer가 통과라서 그대로 종료" 같은 위임형 결론은 절차 위반이다.
- **doc:\* 모드 사전 audit 필수**: 차원 채점 전 Audit 1(구조), Audit 2(contract/stale-term), Audit 3(Missing-Info/Back-Question) 모두 필수로 수행하라 (refine-steps.md `## doc:* 사전 audit` 섹션, refine-modes.md `## 모든 doc:* 공통 규칙`). 셋 중 하나라도 생략하고 점수를 매기면 절차 위반 → 해당 라운드 SCORE 무효.
- **doc:\* 완료 gate**: 삭제된 field/enum/table/API route/model 개념이 active contract 텍스트로 남아있는 동안에는 종료 금지. out-of-scope 또는 migration-history 섹션으로 명시 분리되지 않으면 종합 점수가 TARGET을 넘어도 미완료로 처리한다.

모드: doc:idea / doc:design / doc:spec / doc:plan / doc:skill / doc:test / code / test / integrate
메타 모드: doc, next, auto

## 파라미터 파싱

**⛔ 파라미터 파싱이 끝나기 전에는 다른 작업을 시작하지 마라.**

`$ARGUMENTS`에서 추출:
- `DOC_PATH` / `--path path`: `--path @/path` 또는 `--path path`가 있으면 그 값. 없으면 나머지 인자 중 실존 파일/디렉토리(`[path]`). 없으면 Glob 검색(범위: cwd 이하 + 모드 기본 경로). 다중 매칭 tie-break: ① 인자 문자열과 최장 일치 → ② 최근 수정 → ③ 동률이면 사용자 질문. 무매칭 시: 사용자가 생성 의도를 밝혔거나 모드 기본 경로가 명확하면(doc:*→`docs/{mode}.md` 등) 그 경로로 확정하고 **부트스트랩 경로**로 진행, 불명확하면 사용자 질문 — 파라미터 파싱 단계는 질문 허용(AUTO_CONTINUE의 "묻지 마라"는 라운드 루프 안에만 적용).
- `MODE` / `--mode m`: 명시적 `--mode` 또는 자동 감지 (경로 기반 우선: `.claude/commands/*.md`·`.claude/skills/**/SKILL.md`·`.claude/agents/**/*.md`→doc:skill, .ts→code, .→integrate, 내용 기반: idea/spec/plan/design/test 키워드. **주의: 스킬/커맨드 파일에 doc:plan을 쓰지 마라** — API Surface·Dependency Awareness 같은 구현 플랜 차원이 오작동함)
- `TARGET_SCORE` / `--target N`: 기본 70
- `MAX_ROUNDS` / `--rounds N`: 우선순위 — `--rounds` 명시값 > 사용자 전역 메모리(CLAUDE.md)에 명시된 기본값 > 50 (전역 메모리는 세션 컨텍스트에 이미 로드돼 있어 파싱 시점에 바로 참조한다)
- `SCORE_ONLY` / `--score-only`: Step 0 + (doc:*) 사전 audit + SCORE까지 수행하고 SCORE 출력 직후 종료. DIAGNOSE 이후 미진입, Step 6 정리 수행, `.refine.log`에 `[score-only]` 마커와 점수 기록
- `FOCUS` / `--focus dims`: 집중 차원 (쉼표 구분)
- `MODEL_POLICY`: `--model-policy '역할=모델'` (반복 지정 가능) — 기본값·역할 목록은 refine-steps.md `## 오케스트레이션 & 모델 정책`
- `TDD`: `--tdd` 강제 ON / `--no-tdd` 강제 OFF. 미지정이면 **자동 판정** — code 모드에서 설계 정보가 확인되면 ON (refine-steps.md `### TDD 변형`)
- `AUTO_CONTINUE`: 기본 true. `--ask`면 false
- `FROM`/`TO`: `--from m`, `--to m` 범위 실행. 범위의 자연 시퀀스·`--from` 단독·`--to` 단독 해석은 아래 `### next / auto / --from-to`가 SSOT다.
- `RESET`: 채점 초기화

DOC_PATH 자동 매핑: code/test→`packages/`, integrate→`.`, doc:skill→명시 필수(기본값 없음), 그 외 doc:*→`docs/{mode}.md`

### --reset

1. `.refine.log`에 `[reset]` 마커 추가
2. `STATUS.md` 점수→미채점
3. `--from`/`--mode`와 함께면 초기화 후 즉시 재실행

### next / auto / --from-to

**doc**: DOC_PATH 내용으로 doc:* 하위 모드를 자동 감지해 단일 실행. 감지 신호가 경합(2개+)하거나 없으면 사용자에게 모드를 질문한다(파싱 단계는 질문 허용).
**next**: STATUS.md에서 첫 미완료 단계 → 실행
**auto**: 미완료 단계 순차 전부 실행. MAX_ROUNDS 소진 시 다음 단계로 자동 진행 — 단 **blocking open question이 남은 단계는 완료로 처리하지 않는다** — OPEN QUESTIONS를 노출하고 그 단계를 미완료로 표기한 채 다음 단계로 진행한다(진행 자체는 멈추지 않는다). `integrate` 완료 후에는 아래 **auto 회귀 점검**을 최대 3회 수행한다.

자연 시퀀스(next/auto/FROM-TO 공용): `doc:idea → doc:design → doc:spec → doc:plan → code → test → integrate` (doc:test 산출물이 존재하면 doc:plan 다음 선택 단계, **test 단계는 TDD ON 완료 시 조건부** — 아래 TDD 연결). `doc:skill`은 시퀀스 밖 단독 모드 — 명시 호출 전용.

TDD 연결: 설계 정보(doc:test/spec/design 산출물)가 확인되면 code 단계는 자동으로 **TDD 변형**(red→green→refactor, refine-steps.md `### TDD 변형`)으로 돈다. 신규 기능을 처음부터 TDD로 만들 때는 doc:test를 먼저 두고(없으면 부트스트랩으로 생성) `doc:test → code → integrate`로 진행한다. TDD ON으로 code가 완료되고 Failure-Mode NONE 0건이면 test 단계는 `해당없음` 처리 가능.
**--from/--to**: 완료 여부 무관하게 지정 범위 실행. **`--from`만 지정하면 해당 모드부터 자연 시퀀스의 끝까지 실행** (예: `--from code` → code → test → integrate). `--to`만 지정하면 첫 모드부터 해당 모드까지.

auto 단계 전환: STATUS.md 업데이트 → 다음 단계 시작.

### auto 회귀 점검 (최대 3회)

`auto`가 `integrate`까지 도달하면 즉시 완료하지 말고 최대 3회 `REGRESSION_PASS`를 돈다.

1. **무엇을 점검**: 이번 auto run에서 변경·완료 처리한 모든 단계의 `STATUS.md`, `.refine.log`, 라운드 patch, 최종 SCORE gate를 훑어 (a) 완료 단계에 남은 70 미만 차원, (b) doc:* active stale contract/open question, (c) code/test/integrate 실패 테스트·lint·검증 누락, (d) cross-doc 불일치, (e) 직전 단계 산출물이 다음 단계 전제와 충돌하는 항목을 찾는다.
2. **어떻게 점검**: 각 pass 시작에 `REGRESSION_PASS {i}/3`를 출력하고, 단계별로 `☑ <mode>: clear` 또는 `☐ <mode>: regression {항목} → owner={mode}`를 기록한다. 점검은 새 채점이 아니라 gate/ledger/patch 기반 확인이며, 새 문제가 발견된 owner stage만 라운드 루프로 재진입한다.
3. **실패 시 분기**: owner가 특정되면 그 mode로 돌아가 라운드 루프의 Step 1 SCORE부터 다시 실행하되, **regression 항목을 그 라운드 DIAGNOSE에 `REGRESSION_ISSUE` 입력으로 강제 주입**한다 — FOCUS(차원명 목록)와는 별개 입력이며 차원 약점과 합쳐 batch로 수정한다(refine-steps.md `## DIAGNOSE`). owner가 둘 이상이면 lifecycle상 가장 이른 mode부터 처리한다. owner가 불명확하면 `integrate`로 분기한다.
4. **종료**: 한 pass에서 모든 단계가 `clear`면 auto 완료. 3회 후에도 regression이 남으면 완료로 표시하지 말고 해당 owner stage를 `진행중`으로 남긴 뒤(STATUS enum 준수) 최종 리포트에 `[auto-regression-blocked]`와 남은 항목을 출력한다.

## 산출물 위치 & STATUS.md

- `.refine.log`·`STATUS.md` 위치: DOC_PATH가 파일이면 같은 디렉토리, 디렉토리면 그 안. 공유 디렉토리(예: `~/.claude/commands/`)가 대상이면 `<대상 기본이름>.refine.log`·`<대상 기본이름>.STATUS.md`로 **둘 다 파일별 분리**(예: `refine.refine.log`).
- STATUS.md 스키마 — next/auto가 참조하며, 없으면 아래 헤더로 생성(전 모드 미채점):

```markdown
# REFINE STATUS
| mode | 상태(미채점|진행중|완료|해당없음) | 최종점수 | 라운드 | 갱신 |
|------|------|------|------|------|
| doc:design | 완료 | 84.2 | 6 | 2026-07-03T12:00 |
```

- 갱신 책임: main이 각 라운드 종료·단계 종료 시 갱신. `--reset`은 상태를 미채점으로 되돌린다.

## 라운드 루프

```
Step 0: 초기화
  - MODE 확정 (부트스트랩보다 먼저 — 부트스트랩의 산출물 형식·대조 기준이 모드에 의존)
  - DOC_PATH 읽기. **확정 경로에 파일이 없거나 빈 파일이면 부트스트랩 생성**: claude ∥ codex 독립 생성 → 약식 대조 → 사용자와
    논의 선택 (refine-steps.md `## Step 0 부트스트랩 생성`) → 확정 DOC_PATH 경로에 선택본 기록 후 평소 루프(Round 1 SCORE) 진입
  - 모델/오케스트레이션 정책 확인 (refine-steps.md `## 오케스트레이션 & 모델 정책`)
  - ⚡ PREP: Codex 병렬 사전 작업 발사 (모든 모드 필수, DOC_PATH·MODE 확정 직후 가장 먼저) — refine-steps.md `## Step 0 PREP` 참조.
    codex 작업을 background CLI job으로 띄워 대상을 미리 정독·분석하게 한다 (doc:*는 사전 audit까지 위임).
    비차단 — 발사 후 아래 단계(차원 로드·테스트·lint)와 병렬 진행. 첫 SCORE 진입 전 PREP_CHECK 출력 필수.
    이후 모든 codex 호출(scorer/proposer/reviewer)이 산출물을 재사용.
  - 🧑‍🤝‍🧑 멤버 구성 — 팀은 세션당 자동(implicit)이라 TeamCreate 불필요(v2.1.178+에서 제거됨). SCORE/PROPOSE/APPLY의 **claude 계열 Agent(claude-scorer/cross-reviewer)만** `Agent({ name })`로 named spawn(Round 2+는 SendMessage로 재사용). **codex 역할은 CLI job** (refine-steps.md `## Step 0 멤버 구성`).
  - Read("~/.claude/commands/refine-modes.md")로 해당 모드의 차원 테이블 확인 → DIMENSIONS 변수에 저장
  - code/integrate: 테스트 실행 + lint (PREP와 병렬)
  - 로그 파일 경로 결정 (`## 산출물 위치 & STATUS.md` 규칙)

while round < MAX_ROUNDS:
  ┌─────────────────────────────────────────────────────┐
  │ ⚠ Read("~/.claude/commands/refine-steps.md") 실행  │
  │   매 라운드마다 절차를 다시 읽어라!                    │
  └─────────────────────────────────────────────────────┘
  이번 라운드 LEDGER를 열고 재독 행을 채운다(refine-steps.md `## ROUND LEDGER` — 생략 시 그 라운드 SCORE 무효):
    ━━ ROUND {N} LEDGER ━━
    ☑ 재독: round={N}, lines={wc -l 값}, mtime={stat 값}, dimensions={MODE} 유지(refine-modes.md)

  Step 1: SCORE (refine-steps.md 참조)
    - claude 측 채점(Workflow 파이프라인 우선, 불가 시 named Agent(claude-scorer)) + codex-scorer **CLI job 발사** — 병렬.
      Agent 경로의 Round 2+는 SendMessage 재사용(context 유지), Workflow 경로는 args.priorScores로 delta 채점
    - 채점 결과가 2개면 named agent Agent(cross-reviewer) 교차 리뷰, 1개면 생략하고 그 결과 채택(audit cap 보정은 main) — codex만 실패하면(claude가 Workflow 원점수든 Agent 단일 보고든 동일하게) lazy-consensus(opus, 그 라운드 1회성)를 스폰해 과대평가를 재검토하고 단독 채택
    - 종합 점수 산출

  Step 2: DIAGNOSE — 70 미만인 모든 차원/문항을 식별 (배치)

  Step 3: PROPOSE — codex-proposer(**CLI job**) 조건부 발사(Round==1 | 직전 Result==ROLLBACK | 정체 감지 발동 | codex가 claude보다 20점+ 낮게 본 차원이 이번 DIAGNOSE 포함 시) ∥ claude 수정안 작성 → PROPOSE_COMPARE 항목별 채택(claude|codex|merge|재작성|조건 미충족—claude 단독)
    → 채택본 검증은 APPLY(Step 4) codex-reviewer가 통합 수행 (조건 미충족·proposer 실패 시 claude 단독 초안으로 fallback)

  Step 4: APPLY — N개 수정안 일괄 Edit 반영 + lint + cross-doc 동기화 + codex-reviewer(**CLI job**)의 채택본 항목별 정확성/완전성/부작용 검증(PROPOSE의 분리 검증 통합) + 묶음 diff 교차 리뷰

  Step 5: 반복 판단 (RE-SCORE는 별도 단계 없음 — 다음 라운드 SCORE가 RE-SCORE 역할. KEEP/ROLLBACK 판정 절차(해시 비교·patch 역적용) SSOT: refine-steps.md `## APPLY` 8번)
    종료 조건: (1) 종합 >= TARGET AND 70 미만 차원 없음 AND 결함 cap으로 정확히 70에 묶인 차원 없음 (2) round >= MAX_ROUNDS
    — 단 doc:* 완료 gate·blocking open question이 걸려 있거나, audit/절차/검증 결함 cap 때문에 어떤 차원이 정확히 70으로 제한된 상태거나, 미해소 `[unverified-carryover]` 마커 또는 미해소 `[unverified-consensus]` 마커가 있으면 (1)을 충족해도 종료 금지 (cap 70은 `70 미만 차원 없음` 게이트 미통과로 간주; 결함을 해소해 71+로 재채점되어야 통과. unverified-carryover는 codex 검증/리뷰 PASS(2라운드 연속 미해소 시 발동하는 대체 검증자 PASS 포함) 확인 전까지 종료 금지 — 단 3라운드 연속 미해소로 `[unverified-final]`로 전환된 항목은 그 캐비앗 표기를 유지한 채 종료를 허용한다(refine-steps.md `## Codex CLI job 호출 공통 규칙 > ### 절차` 7번); unverified-consensus는 다음 라운드 cross-reviewer 재교차검증이 `[unverified-consensus-resolved]`로 확인될 때까지 종료 금지)
    — **SCORE 직후 (1)을 즉시 충족하고 위 예외도 전부 해당 없으면, DIAGNOSE/PROPOSE/APPLY를 건너뛰고 곧장 Step 6으로 진행한다**(이 경우 Result=SKIP, 허용 조건 (4))
    ⛔ 금지된 종료 사유 — 아래 이유로 종료하거나 "다음 단계로 넘어갈까요?" 질문하면 규칙 위반:
      - "구조적 한계/병목" → FOCUS 전환하거나 대안 찾아라
      - "저비용 개선 소진" → FOCUS 전환하라
      - "도구/프레임워크 부재" → 설치하거나 대안을 구현하라
      - "이 점수가 현실적 상한" → MAX_ROUNDS까지 계속하라
      - 사용자에게 "계속할까요?" 질문 → AUTO_CONTINUE=true면 묻지 마라
    정체 감지: 3라운드 연속 +3미만 → FOCUS 자동 전환 (종료 아님)
    진동 감지: 4라운드 +/- 반복 → 해당 차원은 항목 단위 defer로 `Items`에 `deferred: {차원}` 표기 + `[skip-oscillation]` 기록 후 다음 FOCUS로 전환 (Result SKIP 아님 — 로그 형식 `Result 의미` 참조. 종료 아님, out-of-scope 아님)

Step 6: 정리 + 로그 기록 + 최종 리포트 (SSOT: refine-steps.md `## Step 0 멤버 구성 > ### 종료`)
  - named agent(claude-scorer/cross-reviewer)는 결과 반환 후 세션 종료 시 자동 정리 — 별도 TeamDelete/shutdown_request 불필요
  - PREP/scorer/proposer/reviewer codex CLI job 미완료 시 cancel
  - 이 run의 /tmp 산출물 삭제: `/tmp/refine_*_${RUN}*`, `/tmp/codex_*_${RUN}*` — RUN 스코프 한정, 다른 세션 파일 금지
  - .refine.log에 기록 + STATUS.md 갱신 + 최종 리포트 출력
  - ⛔ STEP6_CHECK 출력 후 종료:
    ```
    STEP6_CHECK:
    ☑ codex CLI job 정리: 완료|cancelled|해당 없음
    ☑ RUN 스코프 /tmp 산출물 정리: 완료 (다른 세션 파일 미삭제)
    ☑ .refine.log 기록: round/result/items 일치
    ☑ STATUS.md 갱신: {MODE}={상태}, 점수={최종}
    ☑ 최종 리포트 출력: 완료(시작/최종/라운드/차원별 포함)
    ```
    (이 CHECK는 최종 리포트를 실제로 출력한 직후에 남긴다 — 출력 전 "준비됨"으로 미리 표기하지 않는다.)
```

## 로그 형식

```
## Round {N} — {timestamp} ({MODE})
- Targets: {차원 × K}
- Before→After: {이전 종합}→{이번 종합} (Delta {±})
- Items: {N}건 — 항목당 1줄 (APPLY 7번 "모두 나열"과 일치)
- Result: {KEEP|ROLLBACK|SKIP} (KEEP/ROLLBACK 판정·복구 절차: refine-steps.md `## APPLY` 8번)
```

Result 의미:
- `KEEP`: APPLY가 실제 파일 변경을 만들었고 다음 SCORE에서 동일 채점 기반의 종합이 유지·상승했거나, 하락이 이번 라운드 diff와 무관하다는 근거가 있어 keep-override로 판정한 경우.
- `ROLLBACK`: APPLY가 실제 파일 변경을 만들었고 다음 SCORE에서 동일 채점 기반의 종합이 하락했으며, 하락 원인이 이번 라운드 diff에 연결되어 APPLY 8번 절차로 묶음 전체를 되돌린 경우.
- `SKIP`: **라운드에서 APPLY된 항목이 0건**인 경우에만 쓴다 — Result는 라운드 단위 필드다. 허용 조건: (1) `SCORE_ONLY`, (2) auto/next에서 해당 stage가 `해당없음`으로 판정됨(STATUS.md 상태로 기록), (3) 외부 blocking requirement·전 항목 deferred로 적용 가능한 수정안이 0건, (4) 라운드 시작 SCORE 시점부터 이미 목표 달성 상태라 DIAGNOSE 자체를 생략(Step 5 fast-path)했거나, DIAGNOSE를 수행했지만 LEDGER 진단 행 결과 약점이 0건이라 APPLY할 항목이 없는 경우. **항목 단위 defer**(PROPOSE 충돌 deferred, Step 5 진동 감지의 차원 제외)는 Result가 아니라 `Items` 줄에 `deferred: {항목}`으로 표기하며, 진동 감지는 `.refine.log`에 `[skip-oscillation] dimension=<name> rounds=4 next_focus=<name>`를 기록한다. `SKIP`은 성공이 아니며, out-of-scope가 아닌 미해결 항목은 다음 DIAGNOSE 또는 owner stage에 남긴다.

## 최종 리포트

```
═══ REFINE COMPLETE ({MODE}) ═══
시작: {초기}/100 → 최종: {최종}/100 ({변동})
라운드: {완료}/{시도} (롤백 {N}회)
차원별: {각 차원 시작→최종 (delta)}
```

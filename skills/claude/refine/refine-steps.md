---
description: /refine 보조 파일 — 라운드 스텝별 상세 절차 (직접 호출용 아님, refine.md가 매 라운드 Read)
---

# /refine 스텝별 절차

**⚠ 이 파일은 매 라운드 시작 시 Read로 다시 로드된다. main thread가 이 절차를 건너뛰거나 축약하면 규칙 위반이다.** 라운드 시작 출력에는 반드시 `## ROUND LEDGER`의 재독 행을 포함해 재독 사실(lines + mtime/stat 값)을 관측 가능하게 남긴다 — 생략 시 그 라운드 SCORE 무효.

## Step 0 도구 점검 (첫 라운드 진입 전 1회)

> ⚠️ 순서: **`## Step 0 PREP`의 codex 병렬 발사를 가장 먼저** 한 뒤(codex는 background로 오래 돈다 — 일찍 띄울수록 이득), 이 도구 점검을 그와 병렬로 수행한다. 문서상 이 섹션이 PREP보다 위에 있다고 먼저 실행하지 마라.

모드에 따라 필요한 도구를 점검하고 없으면 **즉시 설치**한다. "도구가 없다"는 절대 종료/스킵 사유가 아니다.

패키지 매니저 판정은 lockfile allowlist를 따른다: pnpm-lock.yaml→pnpm / yarn.lock→yarn / package-lock.json→npm / poetry.lock→poetry / uv.lock→uv. 설치 실패·권한 거부 시: 대체 수단을 1회 시도하고, 불가하면 `TOOL_CHECK`에 `☐ {도구}: 미수행({사유})`로 표기 + 관련 차원 채점에 불이익을 반영한다 — 종료 사유는 아니며, 동일 설치의 무한 재시도는 금지.

| 모드 | 필요 도구 | 점검 방법 | 없으면 |
|------|----------|----------|--------|
| test | `@vitest/coverage-v8` | lockfile 판정 매니저로 ls (예: `pnpm ls @vitest/coverage-v8`) | 판정 매니저로 add (예: `pnpm add -D @vitest/coverage-v8`) |
| code/integrate | lint/formatter | `npx eslint --version` 또는 프로젝트 lint 명령 | 프로젝트 설정에 따라 설치 |
| code | lock 파일 동기화 | `poetry lock --check` 또는 `pnpm install --frozen-lockfile` | lock 재생성 |

```
TOOL_CHECK:
☑ {도구명}: 설치됨 (버전: {X})
또는
☑ {도구명}: 미설치 → 설치 완료 (버전: {X})
```

---

## Step 0 부트스트랩 생성 (대상 부재 시)

파라미터 파싱에서 **확정된 DOC_PATH 경로**에 파일이 없거나 빈 파일이면, MODE 확정 후 채점 전에 초기 산출물을 만든다(경로 확정·질문은 파싱 단계의 책임 — `refine.md` 파라미터 파싱). 파일이 있으면 이 섹션을 건너뛰고 평소 루프로 간다.

1. **독립 생성**: claude 측 생성 워커(sonnet — `## 오케스트레이션 & 모델 정책` 계층 원칙)와 codex(CLI job, `## Codex CLI job 호출 공통 규칙` 준수)가 각자 초기 산출물을 생성한다 — 모드별: doc:* = 초안 문서, code = 초기 구현, test = 초기 테스트 스위트. 서로의 안을 보여주지 않으며(독립성), main은 생성에 개입하지 않고 대조·선택 판정을 맡는다.
   codex 발사: `OUTFILE=/tmp/refine_codex-bootstrap_${RUN}.md`, 프롬프트에 spec/요구사항/사용자 지시 + "초안을 정확히 $OUTFILE 에 기록" 지시.
2. **약식 대조**: 두 후보를 해당 모드 차원 기준으로 차원별 강약 1줄씩 대조표로 만든다 (정식 문항 채점은 선택본에만 한다).
3. **논의 선택**: 대조표를 근거로 사용자와 논의해 선택/병합한다 — 부트스트랩 선택은 라운드 루프 밖이라 AUTO_CONTINUE여도 질문 허용 지점(AskUserQuestion). 사용자 응답이 불가한 autonomous 실행이면 main이 대조표 근거로 선택하고 근거를 `.refine.log`에 남긴다.
4. 선택/병합본을 확정 DOC_PATH 경로에 기록(경로 자체는 파싱 단계에서 이미 확정됨) → Round 1 SCORE부터 평소 루프 진입 — **부트스트랩 산출물도 문항별 채점을 그대로 받는다.**
5. codex 생성 실패/timeout/빈 결과 → claude 단독 생성으로 fallback (`### 즉시 실패`·timeout 규칙 준용, `☐ codex-bootstrap 실패: {사유}` 표기).

---

## Step 0 PREP — Codex 병렬 사전 발사 (모든 모드, 첫 SCORE 전 1회)

**⚡ refine 시작 시 가장 먼저 codex 병렬 CLI job을 띄워 대상을 미리 읽고 정리해 둔다.** codex task는 stateless라 호출마다 worktree 탐색을 반복하는데, 이 탐색이 시간의 대부분이다. Step 0에서 사전 작업을 발사해 두면 이후 SCORE/DIAGNOSE/PROPOSE/리뷰의 모든 codex 호출이 탐색 없이 그 산출물을 재사용한다. **이 단계는 SCORE를 막지 않는다 — background로 발사만 하고 Step 0의 나머지(테스트/lint)와 병렬로 진행한다.**

### 발사 절차

1. **main이 컨텍스트 패키지 생성** (codex가 탐색 없이 바로 읽도록 인라인):
   ⛔ **PREP 산출물은 run-유니크 네임스페이스를 쓴다.** `/tmp/refine_ctx.*`·`/tmp/codex_prenotes.md`·`/tmp/codex_audit.md` 고정명은 **동시 실행되는 다른 refine 세션과 충돌**한다(실측: 한 세션의 `cat > /tmp/refine_ctx.txt` 와 `rm -f` 가 다른 세션 PREP 산출물을 덮어쓰거나 지워, codex 가 엉뚱한 대상을 audit). 아래 `### 결과 파일 규칙`의 유니크 OUTFILE 원칙을 PREP 에도 적용해, **세션마다 한 번** `RUN` 토큰을 잡고 모든 PREP 파일명에 끼운다:
   ```bash
   : "${RUN:=$(date +%s)$$}"   # 세션·run 유니크 토큰(이미 잡혀 있으면 보존). 이후 PREP/OUTFILE 파일은 모두 이 RUN 을 끼운다.
   # ⚠ Bash 호출 간 셸이 비영속인 환경에서는 echo $RUN 으로 값을 한 번 받아 이후 모든 명령·polling에 리터럴로 박는다 — $$ 는 호출마다 달라진다.
   CTX="$(~/.claude/commands/refine-scripts/ctx-package.sh "$RUN" <base> <대상 파일들>)"   # dirty→two-dot / clean→three-dot / non-git→전문 cat / 빈 diff→전문 cat 자동 폴백 (### ⚡ 속도 규칙 1 참조) — stdout 산출 경로를 $CTX 로 캡처해 이후 모든 codex 호출에 리터럴로 재사용한다(RUN 토큰과 동일 원칙)
   # doc:* 모드는 구조 audit(Audit 1·2·3)이 diff가 아니라 문서 전체를 필요로 하므로 위 호출 대신 --full을 붙인다(같은 CTX 에 재대입):
   CTX="$(~/.claude/commands/refine-scripts/ctx-package.sh --full "$RUN" <base> <대상 파일들>)"
   ```
   아래 문서의 `/tmp/refine_ctx.*`·`/tmp/codex_prenotes.md`·`/tmp/codex_audit.md` 표기는 모두 **이 RUN 을 끼운 실제 경로의 줄임 템플릿**이다(예: `/tmp/codex_prenotes_${RUN}.md`).

2. **모드별 codex task를 병렬 발사** — 모두 background. 각 task는 산출물을 `/tmp/`에 파일로 남긴다:

   | task | 적용 모드 | 산출물 | 지시 요약 |
   |------|----------|--------|----------|
   | `codex-prep` | **모든 모드** | `/tmp/codex_prenotes_${RUN}.md` | 대상(`/tmp/refine_ctx_${RUN}.*`)을 정독하고 분석 노트 작성: 구성요소별 책임 1줄, 핵심 데이터/제어 흐름, 의존 관계, 의심 지점(버그 후보·중복·dead code·모호 표현) 목록. |
   | `codex-audit` | **doc:\* 만** | `/tmp/codex_audit_${RUN}.md` | 아래 `## doc:* 사전 audit`의 Audit 1·2·3(구조 audit + contract/stale-term audit + Missing-Info / Back-Question 도출)을 미리 수행: 섹션 맵, 1급 개념→owning section, 고아/중복, reader path, 활성/제거 용어, stale leak, 구현 함정 5개 카테고리 스캔, 개념·섹션별 누락 정보→역질문(back-question) 도출 및 blocking/non-blocking/out-of-scope 분류. |
   | `codex-scout` | **code/integrate 만** | `codex-prep` 노트에 통합 | 베이스라인 테스트/lint와 병렬로 잠재 결함(경계 미처리·N+1·예외 누락·dead branch)을 추가 스캔. 별도 task로 분리하지 말고 `codex-prep` 지시에 합쳐 1개 task로 발사한다. |

   발사는 사용자 CLAUDE.md의 Codex 경로 규칙을 따른다. **`--background`로 발사해야 비동기로 돈다** — codex `task`는 `--wait` 사용이 가능하지만 foreground 대기 모드라 PREP에서는 main을 멈춘다. 비동기 PREP/phase 호출은 `--background`를 사용하고, foreground 대기가 필요한 예외 상황에서만 `--wait`를 쓴다. 발사·task-id 캡처·`rm -f`는 `codex-job.sh launch`가 수행한다 — 모드별로 위 표의 지시 + 컨텍스트 파일 경로를 인라인한 프롬프트를 `-`(stdin) 인자로 heredoc째 흘려 넣는다:
   ```bash
   ~/.claude/commands/refine-scripts/codex-job.sh launch codex-prep prep "$RUN" - <<PROMPT_EOF
   <codex-prep 지시 + /tmp/refine_ctx_${RUN}.* 경로 + '결과를 /tmp/codex_prenotes_${RUN}.md 에 기록하고 wc -l 로 확인'>
   PROMPT_EOF
   # doc:* 모드면 codex-audit도 같은 방식(프롬프트는 위 표의 codex-audit 지시)으로 launch codex-audit prep "$RUN" - <<PROMPT_EOF ... PROMPT_EOF
   ```
   `launch`는 stdout에 `TASK_ID=<id> OUTFILE=<path> ISOLATE=<dir|none>` 한 줄을 출력한다 — **stdout에서 task ID를 직접 캡처**하므로(`Codex Task started in the background as <task-id>` 형식) `status --all`로 찾을 필요가 없다(동시 발사한 codex-prep/codex-audit/이전 task가 섞여 혼동되는 문제 회피). 캡처한 `TASK_ID`/`OUTFILE`을 role에 매핑(`PREP_PREP_ID`, `PREP_AUDIT_ID`)한 뒤, 아래 `## Codex CLI job 호출 공통 규칙`의 `codex-job.sh poll`을 **task별 1개씩 `run_in_background` Bash로** 띄운다. **단 PREP polling은 공통 규칙과 한 가지가 다르다: `completed` AND 그 task의 노트가 비어있지 않을 때만 성공으로 본다** — 검사 파일은 task별로 다르다(codex-prep → `[ -s /tmp/codex_prenotes_${RUN}.md ]`, codex-audit → `[ -s /tmp/codex_audit_${RUN}.md ]`. 두 task에 같은 파일을 검사하지 마라) — `codex-job.sh poll`은 `launch`가 돌려준 role별 OUTFILE을 그대로 받으므로 이 구분은 자동으로 성립한다. `completed`라도 그 노트가 비었거나(빈 결과) `failed|cancelled|timeout`이면 **그 task의 산출물만** 삭제하고(codex-prep → `/tmp/codex_prenotes_${RUN}.md`, codex-audit → `/tmp/codex_audit_${RUN}.md`. 와일드카드·고정명으로 다른 task·다른 세션 노트를 지우지 마라) 그 task를 unavailable/fallback으로 마킹한다 (실패·빈 노트를 정상처럼 재사용 금지). 그런 다음 main은 기다리지 말고 Step 0의 나머지와 첫 SCORE로 진행한다.

   **⛔ PREP_CHECK — 첫 SCORE의 PHASE1 진입 전 반드시 출력 (생략 시 절차 위반):**
   ```
   PREP_CHECK:
   ☑ codex-prep 결과: launched ({task-id})
   ☐ codex-prep 실패: unavailable (Codex 미설치|$CODEX_SCRIPT 빈값) | spawn_failed ({사유})
   ☑ codex-audit 결과: launched ({task-id}) | N/A (non-doc 모드)
   ☐ codex-audit 실패: unavailable (Codex 미설치|$CODEX_SCRIPT 빈값) | spawn_failed ({사유})
   ```
   줄 형식 계약: 각 역할은 실제 상태에 맞는 **한 줄만** 출력한다. 성공·N/A는 `☑ <역할> 결과: <상태>`, 실패는 `☐ <역할> 실패: <사유>`를 쓴다. `unavailable`/`spawn_failed`여도 `PREP_CHECK` 블록은 생략하지 말고 fallback(아래 분기)으로 진행한다. polling 결과(`completed`/실패)는 SCORE 재사용 시점에 다시 확인한다.

3. **재사용**: SCORE 시작 시점에 PREP task가 `completed`로 끝나 노트가 유효하면(failed/cancelled 산출물은 이미 폐기됨), 이후 **모든 codex 호출(scorer/proposer/reviewer, 전 라운드)** 프롬프트 맨 앞에 붙인다:
   > "먼저 /tmp/codex_prenotes_${RUN}.md(+ doc:*면 /tmp/codex_audit_${RUN}.md)를 읽어라. 코드/문서 탐색 없이 노트 + 아래 첨부(diff/수정안)만으로 평가하라."

4. **노트 갱신**: 라운드가 진행되며 대상이 바뀌어도 노트를 재생성하지 않는다 — round diff를 누적 첨부해 노트 위에 얹는다 (구조·책임은 천천히 변하고, 변경분은 diff가 운반).

### 분기 (실패/미완료 시 절대 멈추지 않는다)

- **Codex 미설치 / `$CODEX_SCRIPT` 빈값 / spawn 실패** → PREP 산출물 없이 진행. 이후 codex 호출은 각 phase에서 아래 `### 즉시 실패` 표기를 따른다. SCORE는 여전히 **claude-scorer Agent를 스폰**해 진행하고(codex-scorer만 빠짐 — "main thread 단독 채점 금지" hard constraint 유지), doc:* 사전 audit는 sonnet 실무 워커(Agent 스폰)가 수행하고 main이 검토·보강한다.
- **SCORE/audit 시점까지 미완료** → 기다리지 말고 fallback: SCORE는 `### ⚡ 속도 규칙 1`(인라인 패키징)로, doc:* audit는 sonnet 실무 워커가 수행(main은 검토·보강). 미완료 PREP task는 cancel.
- **doc:\* `codex-audit` 완료 시** → main은 결과를 그대로 신뢰하지 말고 **검토·보강**(누락/오탐 보정)해 SCORE에 반영한다.

---

## Step 0 멤버 구성 — named-agent spawn (모든 Agent 스폰 공통)

**⛔ /refine이 스폰하는 claude 채점 Agent는 main thread가 아니라 별도 named agent로 스폰한다(main 단독 채점 금지).** 팀은 세션당 자동(implicit)으로 구성되므로 `TeamCreate`가 필요 없다 — Claude Code v2.1.178+에서 `TeamCreate`/`TeamDelete`는 제거되었고 Agent의 `team_name` 인자는 무시된다. claude-scorer/cross-reviewer만 named agent 멤버이고, codex 역할은 CLI job이다.

### 팀 생성
별도 생성 단계 없음 — `Agent({ name })`로 멤버를 스폰하면 세션의 implicit 팀에 자동 편입되고, 세션 종료 시 자동 정리된다. PREP 발사 직후 바로 SCORE의 멤버 스폰으로 진행한다. ⛔ `~/.claude/teams/`·`~/.claude/tasks/`를 `rm`으로 지우지 마라 — 다른 세션이 쓰는 중일 수 있다.

### 멤버 스폰 규칙
SCORE/PROPOSE/APPLY의 **모든 claude Agent 호출에 `name`을 지정**한다. `subagent_type`만 주는 익명 스폰 금지 — 재사용·조율을 위해 항상 `name`을 부여한다(`team_name`은 무시됨).

| 멤버 | subagent_type | 단계 | name 규칙 | 라운드 간 |
|------|---------------|------|----------|----------|
| claude-scorer | general-purpose | SCORE P1 | 고정 `claude-scorer` | **long-lived 재사용** |
| cross-reviewer | general-purpose | SCORE P2 | 고정 `cross-reviewer` | long-lived 재사용 |

long-lived 팀 멤버는 claude-scorer/cross-reviewer 2개뿐이다(실무 워커는 필요 시 one-shot으로 스폰).

> ⛔ **codex 역할(codex-scorer/codex-proposer/codex-reviewer)을 팀 멤버 Agent로 스폰하지 마라.** `codex:codex-rescue`의 도구는 `Bash` 전용 → `SendMessage`가 없어 `shutdown_request`에 `shutdown_response`로 답할 수 없다 → **shutdown으로 종료되지 않는다**. 팀 멤버로 띄우면 "종료 요청 확인" 텍스트만 남기고 매 라운드 idle 멤버로 영구 잔존한다(실측 확인). **codex는 PREP과 동일하게 CLI job(`node $CODEX_SCRIPT task --background`)으로만 호출**하고, 진행은 `status <task_id>` polling으로 추적하고 결과는 발사 시 지시한 `/tmp/*.md` 파일을 읽어 수집한다(아래 `## Codex CLI job 호출 공통 규칙` — ⛔ `result <task_id>`는 요약일 뿐이라 결과 수집에 쓰지 않는다). CLI job은 팀 멤버가 아니므로 잔존하지 않으며 `completed`/`cancel`로 즉시 정리된다.

- **general-purpose 멤버 (long-lived)**: **Round 1에만** `Agent({ name, subagent_type, model, prompt })`로 스폰한다(`team_name` 불필요 — 무시됨. `model`은 `## 오케스트레이션 & 모델 정책` 표: claude-scorer=sonnet, cross-reviewer=opus). **Round 2+에는 재스폰하지 말고** `SendMessage({ to: "claude-scorer", summary: "<5-10단어 요약>", message: "Round N delta 채점: ..." })`로 깨운다 (string message에는 `summary`가 **필수**다). 완료된 멤버도 메시지를 받으면 이전 점수·근거 context를 유지한 채 delta 채점한다.
- **codex 역할 (CLI job, 팀 멤버 아님)**: `node $CODEX_SCRIPT task --background --write "<지시 + 결과를 /tmp/refine_<role>_r{N}_${RUN}.md 에 기록하라>"`로 호출하고, stdout의 task-id를 캡처 → `## Codex CLI job 호출 공통 규칙`의 polling → 완료 시 `/tmp/refine_<role>_r{N}_${RUN}.md`를 읽어 수집한다(파일명은 `### 결과 파일 규칙`의 role·round·run 유니크 규칙을 따른다). 매 호출이 독립 job이라 "재스폰/재사용" 개념이 없고, `completed`/`cancel`이면 잔존하지 않는다. ⛔ `Agent({subagent_type:"codex:codex-rescue"})`로 팀에 넣지 마라(종료 불가 → 영구 잔존).
- **Codex 미설치/spawn 실패**: codex CLI job을 발사하지 않고 해당 phase의 `*_CHECK`에 `☐ codex-<role> 미설치/spawn 실패`로 표기한다 (공통 규칙 `### 즉시 실패`). 이는 "호출 안 함=절차 위반"이 아니라 **환경상 호출 불가로 허용**되며, claude 멤버만으로 진행한다.

### 멤버 timeout & 강제 정리 (codex job과 동일한 30분 cap)
멤버가 hang/무응답이어도 라운드가 멈추지 않도록, codex job timeout(30분)과 **같은 30분 cap**을 멤버 agent에도 적용한다. (config.json에는 멤버 liveness 필드가 없어 — 등록부일 뿐 — "살아있는지"를 파일로 판단할 수 없다. 아래 신호로 판단한다.)

- **heartbeat 계약**: long-lived 멤버(claude-scorer/cross-reviewer) 스폰(`Agent({ name, ... })`)과 재사용(`SendMessage`) 프롬프트 모두에 "5분 경과마다 진행 1줄을 SendMessage로 보고하라"는 지시를 포함한다 — 아래 stale 판단 신호 ①(idle/완료 메시지 push 수신 여부)이 기댈 관측 신호를 능동적으로 확보한다.
- **작업(assignment)당 단일 30분 deadline (이중 대기 금지)**: 각 멤버에게 **새 작업을 줄 때마다(라운드별 채점 등)** `DEADLINE = 시작+1800s` **하나**를 기록한다. **한 작업 안에서는** 그 멤버의 codex job polling도 새 `start`를 잡지 말고 이 deadline을 물려받아 남은 시간만 쓴다 — 멤버 cap(30분)과 codex job cap(30분)이 직렬로 겹쳐 최대 60분이 되는 것을 막는다. **다음 라운드에 같은 멤버를 다시 깨우면(SendMessage) 그 시점에 deadline을 새로 잡는다** — 직전 라운드의 만료된 deadline을 물려받지 않는다.
- **stale 판단 신호** (⚠️ active 플래그를 믿지 마라 — "멈췄는데 active로 표시"되는 좀비가 실재한다): ① idle/완료 메시지 push 수신 여부, ② **`status`의 Phase + codex job log 파일(`status`의 `Log:` 경로) size/mtime + OUTFILE mtime이 갱신되는가** — ~30초 간격 2회 확인해 갱신이면 진짜 작업 중, **정지면 멈춤(좀비)** (polling 템플릿의 liveness probe가 이 검사를 자동 수행해 300초 무변화 시 `STALLED`로 조기 종결한다), ③ 작업 부여 후 **30분 무신호**. ②의 progress 정지 또는 ③이면 stale로 판정한다.
- **codex CLI job**: `status <task_id>` polling의 30분 cap이 1차 안전장치 — timeout 시 `cancel` + `☐ codex-<role> 호출 실패 (30분 timeout)` 표기(공통 규칙). CLI job은 팀 멤버가 아니라 팀 메시징을 쓰지 않으므로(아래 *결과 수집* 참고), liveness는 polling 결과(`status` Phase + log size/mtime + OUTFILE mtime)로만 판단한다.
- **멤버 agent 무응답 → 3단 ladder (probe → respawn → 포기)**: **heartbeat 무신호**(신호 ①)로 stale이 감지되면 아래 순서로 회복을 시도한다 — 어느 단계에서 해소되든 남은 단계는 건너뛴다. probe+respawn 대기(최대 10분)는 그 작업의 단일 30분 DEADLINE 안에서 소진되는 것이지 그 위에 추가되는 대기가 아니다 — DEADLINE에 먼저 도달하면(신호 ③) ladder 단계를 건너뛰고 즉시 3번 포기 분기로 간다(이중 대기 금지 원칙 유지).
  1. **probe** — heartbeat 무신호 시 `SendMessage({ to: "<name>", summary: "생존 확인", message: "상태 보고 요청 — 진행 중이면 1줄 응답하라" })`로 상태를 1회 질의한다. 5분 내 응답(진행 보고든 결과든)이 오면 stale 해제, 정상 진행.
  2. **respawn** — probe 후 5분 무응답이면 같은 역할을 새 `name`(예: `claude-scorer-r2`)으로 **1회** 재스폰한다. 재스폰 프롬프트에는 직전 컨텍스트 요약(이전 라운드 점수·근거 요약)을 브리핑으로 포함해, 처음부터 다시 조사하지 않게 한다. **deadline 상속**: respawn은 새 30분을 잡지 않고 그 작업의 남은 DEADLINE을 물려받는다 — 새 30분을 잡지 않고 남은 시간만 쓰는 `## Codex CLI job 호출 공통 규칙`의 STALLED 재발사와 동일한 원칙이다.
  3. **포기** — respawn도 무신호면 기존 포기 분기로 연결한다: `SendMessage({ to: "<name>", message: { type: "shutdown_request", reason: "30분 timeout" } })`로 강제 종료를 시도하고, 그래도 신호가 없으면 그 멤버를 **포기**한다 — 그 멤버 결과는 빼고 살아있는 나머지 멤버(claude/codex)로 라운드를 진행하고 `.refine.log`에 `[member-timeout] member=<name> round=<N>` 기록. harness는 멤버 강제 kill API를 제공하지 않으므로 "포기 후 진행"이 강제 정리의 현실적 상한이다 (잔존 멤버는 세션 종료 시 자동 정리). **단 ⛔ `claude-scorer`마저 포기돼 살아있는 채점 Agent가 0개면 그 라운드 SCORE는 무효다** — main이 직접 채점하지 않는다("main thread 단독 채점 금지" hard constraint). 다음 라운드에서 재스폰으로 재시도한다.

> 실측 2026-07-04 — workflow 구현 에이전트 2개가 스폰 수분 만에 조용히 사망 후 재시도로 회복. probe/respawn ladder는 30분 timeout만으로 생기는 대기 낭비를 5-10분 내로 줄인다.

> *결과 수집*:
> - **general-purpose(claude-scorer/cross-reviewer) = 팀 멤버**: SendMessage 도구가 있어 **결과를 SendMessage로 main에 반환**한다(자동 delivery). 완료 시 결과 없이 `idle_notification`만 오면, 그 멤버에 "채점 결과를 메시지로 보고하라"고 SendMessage해 회수한다.
> - **codex = CLI job (팀 멤버 아님)**: 도구가 `Bash`뿐이라 SendMessage가 불가하므로 **애초에 팀 멤버로 만들지 않는다**. 진행은 `status <task_id>` polling으로 추적하고, 결과는 발사 시 지시한 `/tmp/refine_<role>_r{N}_${RUN}.md` 파일을 읽어 수집한다(팀 메시징으로 대체 불가, 실측 확인. ⛔ `result <task_id>`는 요약 stdout일 뿐이라 결과 수집에 쓰지 않는다 — `### 결과 파일 규칙` 참조).

### 종료 (refine 완료 / MAX_ROUNDS / TARGET 도달)
```
1. codex CLI job(PREP/scorer/proposer/reviewer): 진행 중인 `status <task_id>` polling이 끝났는지 확인 — 미완료면 `cancel` (CLI job은 shutdown_request 대상이 아니다 — `cancel`로 종결·잔존 없음).
2. claude 멤버(claude-scorer/cross-reviewer)는 결과 반환 후 **세션 종료 시 자동 정리**된다 — 팀이 implicit이라 `TeamDelete`가 없고(v2.1.178+에서 제거됨), `shutdown_request`는 legacy이므로 직접 보내지 않는다.
3. 라운드 도중 멈춰야 할 좀비 멤버가 있을 때만 예외적으로 `SendMessage({ to: "<name>", message: { type: "shutdown_request", reason: "..." } })`로 종료를 시도한다 (무한 대기 금지, 30분 cap; 미응답이면 포기).
```

implicit 팀과 그 task 디렉토리는 **세션 종료 시 자동 정리**되므로 `TeamDelete`나 수동 force-rm이 필요 없다. ⛔ `~/.claude/teams/`·`~/.claude/tasks/`를 `rm`으로 지우지 마라 — 다른 세션이 쓰는 중일 수 있다.

---

## 오케스트레이션 & 모델 정책

### 모델 정책

**계층 원칙 (allowlist)** — 모델은 역할 계층으로 배정한다:
- **전체 ultracode 오케스트레이션 총괄 = main, fable 우선·불가 시 opus가 총괄 대신**: 루프 관장·발사·수집·PROPOSE_COMPARE 채택·audit cap 보정·KEEP/ROLLBACK 판정·로그/STATUS 기록·사용자 소통. main은 관리자이며 실무 작성(창작)을 직접 수행하지 않는다. main의 모델은 세션 launch 시점에 정해지는 값이라 이 문서가 라운드 중 바꿀 수 없다 — fable을 세션 모델로 쓸 수 없을 때만 opus가 총괄 전체를 대신한다는 뜻이다.
- **sub-project(단계·판정 단위) 관리 = opus (고정)**: cross-reviewer(교차 판정), lazy-consensus(codex-scorer 실패 시 1회성 sonnet 원점수 종합 — `## ROUND LEDGER`의 claude채점/codex채점 행 생존 분기 참조). main이 fable이든 opus든 이 계층은 항상 opus다 — fable은 총괄(main) 계층에만 쓰고 sub-project 계층으로 내려보내지 않는다. 루프 내 판정(부트스트랩 선택·PROPOSE_COMPARE 채택 등)은 main의 관리 영역이다(`### main 단독 판단의 경계`).
- **실제 작성·채점 실무 = 정확히 sonnet / 단순 반복·기계적 검사 = 정확히 haiku**: 수정안 초안·코드 구현·테스트 코드·부트스트랩 초안 작성과 차원별 채점은 sonnet, 경로 실존·stale grep 같은 결정적 반복은 haiku.

여기서 '실무 작성'은 산출물의 **창작**(문서 초안·코드·테스트·수정안·audit 분석)을 뜻한다. code/test 모드에서는 이 '창작'이 곧 `.py`/설정/migration 파일에 들어갈 실제 코드·스키마·테스트 본문을 구상하는 일이다 — main이 조사·설계를 통해 무엇을 만들지 이미 알고 있어도, 그 내용을 sonnet 워커(Agent 또는 Workflow `agent()`)에게 브리핑으로 넘겨 실제로 작성하게 한다. 도구 실행(컨텍스트 패키징 cat/diff·워커가 만든 내용을 Edit/Write로 반영·로그/STATUS 기록)은 main의 관리 업무에 속한다 — 즉 main은 **무엇을 어떻게 바꿀지 사양(브리핑)을 쓰고, 워커의 산출물을 파일에 옮긴다.** main 자신의 판단으로 새 코드/문장을 처음부터 구성해 그대로 Edit/Write하면(브리핑 위임 없이) 조사·설계가 아무리 완결되어 있어도 위반이다.

Agent 스폰은 `model` 옵션만, Workflow `agent()`는 `model`+`effort`를 받는다. codex CLI job은 모델 지정 대상이 아니다(자체 고정). 사용자 `--model-policy '역할=모델'`이 표보다 우선한다. `--model-policy`를 같은 역할에 반복 지정하면 **가장 오른쪽 지정이 최종값**이다(예: `--model-policy '차원별 scorer=haiku' --model-policy '차원별 scorer=sonnet'` → `차원별 scorer=sonnet` — 역할명은 아래 표의 정식 명칭 사용).

Agent 스폰 역할:

| 역할 | model | 계층 |
|------|-------|------|
| claude-scorer | sonnet | 실무 — 루브릭 적용 채점 |
| cross-reviewer | opus | sub-project 관리 — 두 채점 보고 비교 판정 |
| lazy-consensus | opus | sub-project 관리 — codex-scorer 실패 시 1회성 sonnet perDimension 원점수 종합 (LEDGER claude채점/codex채점 행 생존 분기 한정) |
| 부트스트랩 생성자(claude 측) | sonnet | 실무 — 초안 작성 (선택 판정은 main) |
| 실무 작성 워커(PROPOSE 초안·code 구현·테스트 코드) | sonnet | 실무 — main은 검수·통합만 |

Workflow `agent()` 역할:

| 역할 | model | effort | 계층 |
|------|-------|--------|------|
| 차원별 scorer | sonnet | high (code·test 모드: xhigh) | 실무 — fan-out 채점, 원점수(perDimension) 그대로 반환 (품질 교정·과대평가 지적은 cross-reviewer가 담당) |
| 약점별 proposer | sonnet | high (code·test 모드: xhigh) | 실무 — PROPOSE fan-out 수정안 초안 (컨센서스 불필요, 조율은 PROPOSE Step 2·2b) |
| 기계적 스캔(경로 실존·stale grep) | haiku | 미지정(생략) | 단순 반복 — 결정적 검사 (Haiku 4.5는 `effort` 파라미터 자체가 에러 대상이라 옵션에서 제외한다) |

### main 단독 판단의 경계 (allowlist)

main 단독 금지의 범위는 정확히 **'점수 생성'**이다. 다음은 main의 판단 영역이다(단독 수행 허용): PROPOSE 비교 채택(PROPOSE_COMPARE), 부트스트랩 선택(사용자 무응답 시), audit cap 보정, codex 실패 시 fallback 결정.

### Workflow(ultracode) 오케스트레이션

`ultracode`는 Claude Code Workflow 런타임(`phase`/`parallel`/`agent()` DSL)을 가리키는 내부 별칭이며, 별도 팀 멤버나 Codex CLI job 이름이 아니다.

Workflow 도구가 세션에 존재하면 SCORE Phase 1의 **claude 측 채점**을 Workflow로 fan-out한다 — 이 스킬 지시가 곧 Workflow 사용 opt-in이다. codex-scorer CLI job은 Workflow 밖에서 main이 기존 규칙대로 병렬 발사한다.

- fallback(allowlist): Workflow 도구 부재, 스크립트 오류 2회, 또는 소형 프로파일(`### 소형 프로파일` 조건 충족 — 실측값 기재 의무) → named Agent(claude-scorer) 경로로 전환.
- 용어 동기화: 이후 절차의 "claude 측 채점"은 두 경로를 통칭한다. LEDGER claude채점 행 표기 — Agent 경로 `☑ claude채점: (claude-scorer) ...`, Workflow 경로 `☑ claude채점: (workflow) ...`.
- delta 채점: Agent 경로는 SendMessage 재사용(context 유지), Workflow 경로는 `args.priorScores`로 이전 점수를 넘겨 변경 영향 차원만 재채점.
- Workflow의 차원별 원점수(perDimension)는 opus 가공 없이 그대로 codex-scorer 결과와 함께 Phase 2(cross-reviewer)에 입력된다 — Workflow에는 별도 Consensus phase가 없다(opus 판정은 cross-reviewer 한 곳에 집중). Workflow가 cross-reviewer를 대체하지 않는다(이종 채점자 간 교차 검증).
- 어휘 정리: Workflow `agent()`의 `label`은 Workflow 내부 trace/로그용 식별자이고 `SendMessage` 대상이 아니다. `Agent({ name })`의 `name`은 라운드 간 재사용·메시징을 위한 세션 전역 주소다. `label: "score:Correctness"`와 `name: "claude-scorer"`는 같은 네임스페이스가 아니며 서로 대체하지 않는다.

복붙 템플릿 (차원 테이블·이전 점수는 args로 주입 — audit cap 보정은 main이 별도로 수행하므로 이 스크립트는 audit 요약을 받지 않는다):

```js
export const meta = {
  name: 'refine-score',
  description: 'refine SCORE: 차원별 병렬 채점 (원점수 배열 반환 — 합의는 cross-reviewer가 codex 점수와 함께 수행)',
  phases: [{ title: 'Score' }],
}
// args: { docPaths: [...], mode: 'doc:skill', dimensions: [{name, weight, criteria, special}...], priorScores: {...}|null }
const A = typeof args === 'string' ? JSON.parse(args) : args   // 하네스가 args를 JSON-문자열로 전달하는 케이스 방어 (실측 2026-07-03: 문자열 도착 → args.dimensions undefined 즉시 실패)
const SCORE_EFFORT = (A.mode === 'code' || A.mode === 'test') ? 'xhigh' : 'high'
const DIM_SCHEMA = { type:'object', required:['dimension','score','evidence'], properties:{
  dimension:{type:'string'}, score:{type:'number'}, evidence:{type:'array', items:{type:'string'}},
  questions:{type:'array', items:{type:'object', properties:{q:{type:'string'}, score:{type:'number'}, why:{type:'string'}}}} } }
phase('Score')
const scores = await parallel(A.dimensions.map(d => () => agent(
  `너는 /refine 채점자다. 대상 파일(${A.docPaths.join(', ')})을 읽고 모드 ${A.mode}의 차원 "${d.name}"만 채점하라.
   기준: ${d.criteria} / 특별규칙: ${d.special || '없음'} / 앵커: 0-20 없음, 21-40 추상적, 41-60 절반 미충족, 61-70 중요 빈틈, 71-85 사소한 빈틈, 86-95 추가 깊이, 96-100 완벽. 관대 금지. 날조 수치 = 해당 차원 0점.
   ${A.priorScores ? `이전 점수 ${A.priorScores[d.name]} — 이번 diff가 영향 주는 문항만 재채점, 나머지 유지.` : ''}
   문항(물음표) 단위로 분해해 각각 근거 2-3문장과 함께 채점하라.`,
  { label: `score:${d.name}`, phase: 'Score', schema: DIM_SCHEMA, model: 'sonnet', effort: SCORE_EFFORT })))
return { perDimension: scores.filter(Boolean) }
```

PROPOSE 단계의 claude 측 초안도 같은 방식으로 항목별 fan-out할 수 있다 — 단, 각 항목은 이미 완결된 수정안이라 SCORE의 opus 조정(cross-reviewer)을 이식하지 않는다(항목 간 조율은 PROPOSE 절차의 Step 2·2b가 담당):

```js
export const meta = {
  name: 'refine-propose',
  description: 'refine PROPOSE: 약점 항목별 병렬 수정안 초안',
  phases: [{ title: 'Propose' }],
}
// args: { docPaths: [...], mode: 'doc:skill', weakItems: [{item, dimension, score, diagnosis}...] }
const A = typeof args === 'string' ? JSON.parse(args) : args
const PROPOSE_EFFORT = (A.mode === 'code' || A.mode === 'test') ? 'xhigh' : 'high'
const PROPOSAL_SCHEMA = { type:'object', required:['item','proposal','rationale'], properties:{
  item:{type:'string'}, proposal:{type:'string', description:'그대로 반영 가능한 수정 텍스트/diff/코드'},
  rationale:{type:'string'} } }
phase('Propose')
const drafts = await parallel(A.weakItems.map(w => () => agent(
  `너는 /refine PROPOSE의 claude 측 작성자다. 대상 파일(${A.docPaths.join(', ')})을 읽고 아래 약점 항목 하나에 대한 수정안만 작성하라.
   항목: ${w.item} (차원 ${w.dimension}, 점수 ${w.score}) — 진단: ${w.diagnosis}
   산출물 형식(모드별): doc:* = 반영 가능한 수정 텍스트, code = patch/diff, test = 테스트 코드.
   다른 항목의 수정안은 신경 쓰지 마라(충돌 조율은 별도 단계에서 한다) — 이 항목 하나에만 집중해 정확하고 간결하게.`,
  { label: `propose:${w.item}`, phase: 'Propose', schema: PROPOSAL_SCHEMA, model: 'sonnet', effort: PROPOSE_EFFORT })))
const missing = A.weakItems.filter((w, i) => !drafts[i]).map(w => w.item)
return { drafts: drafts.filter(Boolean), missing }
```

### 소형 프로파일 (기계 판정)

조건(모두 실측값으로 판정 — 재량 판단 금지): 대상 파일 **2개 이하** AND 대상 파일 총합 **300줄 이하**(`wc -l` 실측) AND 이번 라운드 평가 차원 **7개 이하**. **측정 범위**: "대상 파일"은 이번 라운드 수정 대상 파일 + 그 검증에 필수인 대상(관련 테스트 파일 등)을 합산한 집합이며, Step 0에서 이 측정 목록(파일 경로 나열)을 남긴다.

효과: 위 조건을 모두 충족하는 라운드는 SCORE의 claude 측 채점을 (Workflow fan-out 대신) **단일 claude-scorer Agent**로, PROPOSE의 claude 측 초안을 (Workflow fan-out 대신) **single-worker**로 수행할 수 있다.

불변(소형이어도 그대로): codex-scorer CLI job, cross-reviewer 교차 판정, `## Codex CLI job 호출 공통 규칙`의 모든 timeout·격리·결과 파일 가드, `## ROUND LEDGER`의 채점경로·claude채점·codex채점·합의·초안경로·채택·reviewer 행 게이트 — 소형 프로파일은 claude 측 fan-out 여부만 바꾸고 다른 어떤 검증도 생략하지 않는다.

표기 형식(LEDGER 채점경로·초안경로 행 공용, 실측값 기재 의무): `"소형 프로파일: {N}파일 {M}줄, wc -l 실측 — 차원 {K}개"` (예: `소형 프로파일: 1파일 214줄, wc -l 실측 — 차원 5개`). 실측값 없이 "소형이라서"라고만 쓰면 무효 — `## ROUND LEDGER`의 fallback 근거 allowlist 중 측정 기반 표기만 유효하고, "간단해서"·"직접이 빠르다" 같은 재량 판단은 여전히 금지다.

---

## Codex CLI job 호출 공통 규칙 (⏱ 30분 timeout)

codex 역할(codex-scorer / codex-proposer / codex-reviewer)은 **CLI job으로 호출한다** — `node $CODEX_SCRIPT task --background`, 팀 멤버 Agent가 **아니다**(`codex:codex-rescue`는 Bash 전용이라 팀에 넣으면 shutdown 불가로 잔존). 호출 시 **반드시** 아래 timeout 가드를 적용한다 — codex 가 hang/loop 에 빠지면 라운드가 무한정 멈추기 때문이다.

**⛔ 모든 codex 역할, 모든 모드 공통 — 실제 대상 파일 직접 수정 금지, OUTFILE에만 쓴다.** `--write`는 `$OUTFILE` 작성 권한이지 대상 소스 수정 허가가 아니다. code/test 모드는 같은 시간대에 claude 측(Workflow fan-out 또는 single-worker)도 같은 대상 파일을 실제로 Edit/Write하고 있어, codex가 대상 파일을 직접 고치면 두 트랙이 동시에 같은 파일을 써서 서로 다른 이름/구조가 뒤섞이거나 한쪽이 다른 쪽을 덮어쓴다. 모든 codex 프롬프트에 "너는 실제 저장소의 어떤 파일도 Edit/Write/apply_patch로 수정하지 않는다 — 오직 읽기만 하고 결과는 $OUTFILE 에만 작성한다. 다른 파일을 고치면 이 작업은 실패로 간주된다"를 포함한다. 폴링 중 최소 1회 `git status --porcelain -- <대상 파일들>`로 대상 파일이 안 건드려졌는지 확인하고, 건드려졌으면 `cancel` 후 그 job을 `launch`할 때 받은 `ISOLATE`(`TASK_ID=... OUTFILE=... ISOLATE=...`의 그 값)가 `none`이 아니면 `~/.claude/commands/refine-scripts/snapshot.sh restore "$ISOLATE"`로 대상 파일만 복원한다 — `git checkout HEAD --`는 pre-해시 이전의 미커밋 변경까지 되돌려 파괴하므로 쓰지 않는다. `ISOLATE=none`이거나 `snapshot.sh restore`가 실패하면 자동 복구를 멈추고 `☐ codex-<role> 격리 위반 — 스냅샷 복원 불가, blocked` 표기 후 사용자에게 보고한다. 복원에 성공하면 `☐ codex-<role> 격리 위반 (실제 파일 수정 감지, 스냅샷 복원됨)` 표기 후 claude 단독 진행으로 전환한다.

### ⚡ 속도 규칙 1 — 컨텍스트 인라인 패키징 (PREP 노트가 없을 때의 fallback)

**codex에 파일 경로 목록만 주지 마라.** 호출 전에 main이 대상을 묶어 프롬프트에 인라인으로 박아준다:

```bash
: "${RUN:=$(date +%s)$$}"   # Step 0 PREP 1번에서 잡은 run 토큰 재사용. 단독 실행이면 여기서 할당(빈 ${RUN} 방지).
# <base> 결정: PR 브랜치면 git merge-base HEAD <기본 브랜치(main→develop 순 존재 확인)>. PR이 아니면 라운드 시작 시점 HEAD 고정. non-git이면 스크립트가 자동으로 전체 파일 패키징으로 전환한다.
CTX="$(~/.claude/commands/refine-scripts/ctx-package.sh "$RUN" <base> <paths>)"   # dirty→two-dot / clean→three-dot(커밋된 변경만) / non-git→전문 cat / 빈 diff(BASE==HEAD인 라운드 1 등)→전문 cat 자동 폴백 — stdout 산출 경로를 $CTX 로 캡처해 리터럴로 재사용한다
# doc:* 사전 audit·라운드 1 전체 채점처럼 diff가 아니라 전문이 필요하면 --full을 맨 앞에 붙인다(같은 CTX 에 재대입):
CTX="$(~/.claude/commands/refine-scripts/ctx-package.sh --full "$RUN" <base> <paths>)"   # 대상 전문을 "=== 파일 ===" 헤더와 함께 cat — stdout 산출 경로를 $CTX 로 캡처
```

프롬프트에 "대상 코드는 아래에 전문 포함되어 있다 — 파일 탐색 없이 바로 평가하라" + 내용 첨부. 프롬프트가 과대해지면(>150KB) 핵심 파일만 인라인하고 나머지는 경로로.

### ⚡ 속도 규칙 2 — Round 2+ delta 채점

Round 2부터 codex-scorer에게 전체 재채점을 시키지 않는다. "이전 라운드 차원별 점수 + 이번 라운드에 적용된 diff"를 주고 **변경이 영향을 주는 차원만 재채점**, 나머지는 이전 점수 유지로 지시한다. claude-scorer도 동일. **delta 재요청 메시지에는 모드·라운드를 명시**한다 — 안 그러면 claude-scorer 가 직전 라운드 보고를 그대로 재전송하는 혼동이 생긴다(실측). 결과 미수신 시 모드·라운드를 못 박아 1회 재요청한다.

### ⚡ 결과 파일 규칙 — stale·빈 결과 방지 (⛔ 모든 codex CLI 호출 필수)

`/tmp` 결과 파일은 **세션·라운드 간 공유**라 이전 실행 잔여 파일을 현재 결과로 오인하면 채점이 오염된다(실측: 이전 세션 score 파일을 현재 라운드 codex 결과로 읽어 cross-reviewer 가 불일치 플래그를 띄움).

1. **유니크 파일명**: OUTFILE 은 role·라운드 **그리고 run(`${RUN}`)** 으로 유니크하게 — `/tmp/refine_<role>_r{N}_${RUN}.md` (예 `/tmp/refine_codex-scorer_r2_${RUN}.md`). `RUN` 은 `## Step 0 PREP` 1번에서 잡은 토큰(미설정 시 `RUN="$(date +%s)$$"`). role·round 만으로는 **동시 실행되는 다른 refine 세션**이 같은 role·round 에서 충돌하므로 run 토큰을 끼운다. `codex_score_r1.md` 처럼 고정·세션 간 충돌 이름은 쓰지 마라.
2. **발사 직전 `rm -f "$OUTFILE"`**: 잔여 파일 제거 후 launch. 그래야 completed 시점의 non-empty 가 "이번 호출이 새로 썼다"를 보장한다. `codex-job.sh launch`가 이 제거를 자동 수행하며, 대상은 정확히 그 role의 OUTFILE 하나다.
3. **completed 후 `[ -s "$OUTFILE" ]` 검증**: `codex-job.sh poll`이 수행 — 비었으면 빈 결과(실패)로 처리(`### 절차` 4번).
4. **프롬프트에 절대경로 명시**: codex 에게 "결과를 정확히 `<OUTFILE 절대경로>` 에 Bash 로 기록하고 `wc -l` 로 확인하라"고 지시. PREP 의 `/tmp/codex_prenotes_${RUN}.md` 도 동일 — 발사 전 그 run 파일만 `rm -f`, 완료 후 non-empty 확인(비면 PREP unavailable 처리, fallback 으로 진행).

### 절차

1. Agent 스폰(또는 라운드별 재호출) 직후 main 이 **그 작업의 단일 deadline 기록**: `DEADLINE_TS=$(( $(date +%s) + 1800 ))`. **한 작업(라운드) 안에서는** 그 멤버의 codex polling이 새 start를 잡지 않고 이 deadline을 공유한다 — 멤버 cap과 polling cap이 직렬로 겹쳐 60분이 되는 것을 막는다. **다음 라운드 재호출 시에는 새 `DEADLINE_TS`를 잡는다**(만료된 deadline 물려받기 금지).
2. codex-rescue 러너는 codex CLI 에 background job 으로 작업을 forward 한다. task ID(`task-mpXXXXXX-XXXXX`)는 **가능하면 spawn 결과(stdout)의 `started in the background as <task-id>`에서 직접 캡처**한다 (PREP와 동일 원칙) — `codex-job.sh launch`가 이 캡처를 수행하고 `TASK_ID=... OUTFILE=... ISOLATE=...`로 반환한다(TARGET_FILE 인자를 줬을 때만 ISOLATE가 실제 격리 스냅샷 경로 — 격리 위반 복원 자산, `## Codex CLI job 호출 공통 규칙` 도입부 참조). 직접 못 얻으면(TASK_ID 캡처 실패) `codex-job.sh launch`는 즉시 `SPAWN_FAILED`(exit 5)로 종료한다(`### 즉시 실패` 표기로 이어짐) — 이 시점에 codex job이 실제로는 이미 스폰돼 있었다면 추적 수단이 없는 orphan job으로 남을 수 있으니, 호출자는 claude 단독 진행으로 전환하고 그 job 정리는 codex 서비스 쪽에 맡긴다.
3. main 은 `run_in_background` Bash 로 `codex-job.sh poll`을 띄운다 — **위 `DEADLINE_TS`까지 (기본 30분) cap**:

```bash
# ⛔ 이 polling 은 별도 run_in_background Bash 라 부모 셸 변수를 못 본다 — 아래 세 값을 이 명령 안에서 직접 박아 넣어라(부모 셸의 값으로 치환):
TASK_ID="task-XXXX"                              # 캡처한 codex task-id (codex-job.sh launch stdout 의 TASK_ID=...)
OUTFILE="/tmp/refine_codex-scorer_r2_${RUN}.md"  # 그 task 발사 시 지시한 결과 파일(codex-job.sh launch stdout 의 OUTFILE=... — 발사 직전 rm -f 로 이미 비워짐)
DEADLINE_TS=$(( $(date +%s) + 1800 ))            # 멤버 작업 시작 시 정한 단일 deadline(epoch). 한 작업 안에서 멤버 cap과 공유 — 미설정 시에만 now+1800 fallback.
~/.claude/commands/refine-scripts/codex-job.sh poll "$TASK_ID" "$OUTFILE" "$DEADLINE_TS"
```

`codex-job.sh poll`은 위 값들로 완료/실패/정체/타임아웃까지 감시하며 `=== <토큰> ===` 형태로 결과를 echo한다(POLL START 생존 마커, task-id 라인 앵커 grep, grace-retry 15회×2초, file-stable 90초 조기 채택, liveness probe 300초 무변화 STALLED+cancel, HEARTBEAT ~100초, DEADLINE 초과 cancel — 방어 로직과 실측 근거 주석은 스크립트 본문에 보존).

4. **결과 분기:** (아래 토큰은 `codex-job.sh poll`이 `=== <토큰> ===` 형태로 echo 하는 문자열과 1:1 대응 — grep 시 `=== ===` 래퍼를 감안하라. `poll`은 `result` 폴백 분기를 만들지 않는다.)
   - `UNAVAILABLE` (폴링 진입 전 `$CODEX_SCRIPT` 탐색이 빈값) → 폴링 루프(POLL START·liveness probe)에 들어가지도 않고 즉시 종료 — 300초 무변화 `STALLED`로 오분류되는 것을 방지한다. `☐ codex-<role> 미설치` 표기(`### 즉시 실패`와 동일 처리) 후 claude 단독 진행.
   - `DONE (file)` → **OUTFILE 을 읽어** 다음 단계 진행 (`result` stdout 이 아니라 OUTFILE 기준 — `[ -s ]` 로 비어있지 않음 확인됨).
   - `EMPTY RESULT — codex 실패 처리` (completed 인데 grace-retry 후에도 OUTFILE 이 빔) → `☐ codex-<role> 호출 실패 (빈 결과)` 표기 후 **claude 단독으로 진행**. ⛔ 빈 codex 결과를 "채점/검증/리뷰했다"로 간주하지 마라(실측: 이 케이스를 completed 로 착각해 무검증 통과한 사례 있음). `.refine.log` 에 `[codex-empty] phase=<role> task=<task_id>` 기록.
   - `FAILED/CANCELLED` → `☐ codex-<role> 호출 실패 (job failed)` 표기 후 claude 단독 진행.
   - `STALLED — cancel` (Phase·job 로그·산출물 300초 무변화, OUTFILE 빈 상태) → **같은 지시로 1회 재발사 허용**: 새 task 를 발사하고 **남은 DEADLINE_TS 를 물려받아** polling 재개 — 새 30분을 잡지 않는다. `.refine.log` 에 `[codex-stalled] phase=<role> task=<task_id>` + 재발사 시 `[codex-relaunch]` 기록. 재발사도 STALLED/실패면 `☐ codex-<role> 실패 (stalled)` 표기 후 claude 단독 진행.
   - `DONE (file-stable, status!=completed)` (OUTFILE 이 non-empty 상태로 90초+ mtime 무변화 — status 는 아직 completed 로 전이 안 됨, codex-job.sh 의 조기 채택 분기) → 아래 `DEADLINE TIMEOUT`과 **동일한 완결 형식 게이트**(OUTFILE 이 non-empty AND 발사 프롬프트가 요구한 산출 구조를 마지막 항목까지 완결 형식으로 갖춤)를 통과할 때만 그 파일을 결과로 채택한다. 통과 시 `☑ codex-<role> 결과: file-stable-kept` 표기 + `.refine.log` 에 `[codex-filestable-kept]` 기록. 미통과(중간 절단·요구 구조 미달)면 `☐ codex-<role> 호출 실패 (file-stable — 구조 미달)` 표기 후 claude 단독 진행 — 부분 출력을 완결로 오채택하지 않는다.
   - `DEADLINE TIMEOUT — cancel` → main 이 OUTFILE 을 확인해 두 갈래로 처리한다. **채택 조건은 정확히: OUTFILE 이 non-empty AND 발사 프롬프트가 요구한 산출 구조를 마지막 항목까지 완결 형식으로 갖춤**(예: scorer=차원별 점수+가중평균 종합, reviewer=항목 1..N 전부의 PASS|CAVEAT|FAIL). 조건 충족 시 cancel 후에도 그 파일을 결과로 채택하고 `☑ codex-<role> 결과: timeout-kept` 표기 + `.refine.log` 에 `[codex-timeout-kept]` 기록 — 실측(2026-07-03): codex 가 완결 보고를 기록한 뒤 task 마무리만 못 하고 25분+ running 으로 잔존. 조건 미충족(중간 절단·요구 구조 미달)이면 `☐ codex-<role> 호출 실패 (30분 timeout — cancel 됨)` 표기 후 진행.
5. timeout/빈결과/실패/stalled/timeout-채택/file-stable-채택으로 정리한 경우 `.refine.log` 에 마커 기록 (`[codex-timeout]`/`[codex-empty]`/`[codex-failed]`/`[codex-stalled]`/`[codex-relaunch]`/`[codex-timeout-kept]`/`[codex-filestable-kept]` + `phase=<scorer|proposer|reviewer> task=<task_id>`). **reviewer 역할이 위 사유 중 어느 것으로든 검증/리뷰 없이 진행하게 되면** 같은 로그에 `[unverified-carryover] role=reviewer round=<N> items=<항목 목록>`도 함께 기록한다 — 다음 라운드 `DIAGNOSE`가 이 마커를 1급 약점으로 강제 포함해 codex PASS 확인 전까지 매 라운드 반복한다(3라운드 연속 미해소면 아래 7번의 `[unverified-final]` 캐비앗 표기로 종료 가능. `## DIAGNOSE` 참조).
6. **즉석 수동 확인(사용자·main 공용)**: `node "$CODEX_SCRIPT" status <task-id>` 의 Phase·Elapsed 확인 + `tail -20 <status 의 Log: 경로>` — job 로그가 자라고 있으면 실제 작업 중이다. 폴링 output 파일을 Read 하면 HEARTBEAT 이력(phase·로그 크기·산출물 크기 ~100초 간격)으로 진행 추이를 볼 수 있다.
7. **연속 실패 가드**: 같은 phase 의 codex 가 2라운드 연속 `빈 결과/실패`면 그 phase 의 codex 호출을 이후 라운드에서 **생략**하고 claude 단독으로 진행한다(매 라운드 빈 codex 를 기다리느라 낭비 금지). `*_CHECK` 에 `☐ codex-<role> 생략 (연속 실패)` 표기. **단 reviewer는 이 생략 규칙의 대상에서 제외한다** — reviewer를 생략하면 `[unverified-carryover]`를 해소할 경로 자체가 사라져 교착에 빠지므로, reviewer는 실패해도 매 라운드 호출을 계속 시도한다. `[unverified-carryover]`가 **2라운드 연속 미해소**로 확인되면 3번째 라운드 DIAGNOSE 진입 전 claude 측 대체 검증자(cross-reviewer 재사용 또는 1회성 opus)를 1회 발동해 그 항목을 adversarial 재검토한다 — PASS로 확인되면 codex PASS와 동등하게 `[unverified-carryover]`를 해소하고, 그래도 미해소면 대체 검증에 추가 대기를 걸지 않고 예정대로 3라운드째 진행한다. `[unverified-carryover]`가 (대체 검증까지 거쳤음에도) **3라운드 연속 미해소**면 `.refine.log`와 최종 리포트에 `[unverified-final] items=<항목 목록>`으로 명시해 그 항목을 미검증 상태로 캐비앗 표기한 채 종료를 허용한다(다른 종료 조건은 그대로 적용 — 이 캐비앗은 unverified-carryover 종료 금지 게이트의 유일한 예외다. `refine.md` `## 라운드 루프` Step 5와 동기화).

### 즉시 실패 (timeout 이전)

- Codex CLI 미설치 / `$CODEX_SCRIPT` 빈값 → 그 phase 의 codex 결과는 즉시 `☐ codex-<role> 미설치` 표기
- codex job spawn 실패 (network/auth 오류) → 즉시 `☐ codex-<role> spawn 실패` 표기
- `codex-job.sh launch`가 `EMPTY_PROMPT`(exit 3)/`OVERSIZE_PROMPT`(exit 4)를 내면 codex 환경 문제가 아니라 호출부 입력 오류다 — 빈 프롬프트는 내용을 채우고, 150KB 초과 프롬프트는 핵심 파일만 인라인해 축소한(`### ⚡ 속도 규칙 1`) 뒤 즉시 재시도한다. 재시도도 같은 오류면 `☐ codex-<role> 프롬프트 오류 ({EMPTY_PROMPT|OVERSIZE_PROMPT})` 표기 후 claude 단독 진행
- 위 경우 모두 30분 기다리지 않음

### 절대 금지

- Foreground 로 codex 결과 polling (Bash `sleep` 체이닝) — main thread 가 멈춤
- Timeout 없이 무한 대기 (사용자가 명시한 9시간 hang 같은 케이스 방지)

각 phase 의 codex 호출 부근에 표시: **⏱ Codex 호출 공통 규칙 적용 (30분 timeout)**.

---

## doc:* 사전 audit (모든 doc:* 모드 필수, SCORE 전에 수행)

**⛔ 이 audit 없이 차원 채점만 하면 라운드 SCORE 무효. field/API/code 일치만 본 채점도 무효.**

doc:* 모드(`doc:idea`, `doc:design`, `doc:spec`, `doc:plan`, `doc:skill`, `doc:test`) 채점은 차원 채점 전에 아래 audit를 순서대로 수행한다: **Audit 1·2·3 모두 모든 doc:* 필수** — Audit 3의 역질문은 문서를 concrete하게 만드는 1급 장치다. 결과는 SCORE 출력 위에 함께 노출한다.

**PREP 연계**: `## Step 0 PREP`에서 발사한 `codex-audit`(`/tmp/codex_audit_${RUN}.md`)가 `completed`면 그 결과를 출발점으로 삼아 **검토·보강**한다. **rubber-stamp 금지** — codex-audit의 각 발견 항목을 `수용 | 반려(사유) | 보강(main 추가 발견)` 중 하나로 표기한 검토 라인을 audit 출력에 반드시 포함한다:
```
━━━ CODEX-AUDIT 검토 ━━━
{codex 발견 항목} → 수용 | 반려: {사유} | 보강: {추가 발견}  × N
```
codex-audit가 미완료/미설치/실패면 sonnet 실무 워커(Agent 스폰)가 아래 절차를 처음부터 수행하고 main이 검토·보강한다. 어느 경우든 audit 누락은 SCORE 무효 사유다.

### Audit 1: 구조 audit (Structural Audit)

대상 문서의 구조를 다음 4개 관점으로 점검:

1. **Section map** — 최상위 섹션을 모두 나열하고 각 섹션의 reader job(누가 왜 읽는가)을 1줄로 적는다.
2. **First-class concept map** — 제목·goals·entity/component 목록·API contract·다이어그램에 등장하는 1급 개념을 모두 나열한다. 명시적으로 derived/out-of-scope/그룹 소속이라고 표기되지 않은 것은 모두 1급으로 본다.
3. **고아/중복 섹션 체크** — owning section이 없는 1급 개념, 같은 contract를 반복 재기술하는 섹션, reader job이 다른 섹션과 겹치는 섹션을 식별한다.
4. **Reader-path 체크** — 주요 reader(FE 개발자, sync 운영자, MCP consumer 등)별로 필요한 정보를 어느 섹션에서 어떤 순서로 얻는지 추적한다. 끊긴 경로/순환 참조가 있으면 기록한다.

```
━━━ STRUCTURAL AUDIT ━━━
섹션 맵: {섹션명: reader job} × N
1급 개념: {개념명 → owning section 또는 UNCLAIMED} × M
고아/중복: {항목 × K}
Reader path: {reader → 경로 OK/끊김} × R
```

### Audit 2: Contract / Stale-Term audit

구조 audit 직후, 문서 contract의 정합성을 점검:

1. **활성 contract 용어 추출** — schema/API/Pydantic 예시·테이블·enum 값·필드명에서 현재 활성으로 선언된 용어 목록을 만든다.
2. **제거/Out-of-scope 용어 추출** — "deprecated", "removed", "out-of-scope", "후속 design", "별도 revision" 등으로 분리된 용어 목록.
3. **Stale term sweep** — 대상 문서와 동급 doc(같은 디렉토리 + 명시적으로 참조하는 peer doc) 전체에 `grep`으로 제거된 용어가 active contract 텍스트(섹션·표·예시·다이어그램)에 남아있는지 확인. out-of-scope/migration-history 섹션에 명시 격리된 경우만 통과.
4. **구현 함정 체크** — 아래 5개 카테고리를 반드시 훑는다:
   - **Reserved SQL/ORM 이름**: `references`, `metadata`, `user`, `order`, `groups`, `level` 등 PostgreSQL/SQLAlchemy `DeclarativeBase` 예약어가 unquoted column/attribute로 등장하는가?
   - **Mutable list index identity**: array index 기반 PATCH/DELETE/외부 status table FK 등 race condition으로 deg되는 식별 패턴.
   - **미강제 invariant**: 문서엔 "X == Y여야 한다"라고 적혀 있지만 모델 코드·validator·DB constraint·service guard 어디에도 강제 지점이 없는 규칙.
   - **모호한 ID/URL encoding**: percent-encode 횟수(단일 vs 이중), framework 자동 decode 여부, segment 구분자 충돌이 명시되지 않은 식별자 문법.
   - **무한/대용량 hot-row payload**: JSONB `raw`/`extra`/`custom`/inline SQL 등 entity row에 size limit 없이 누적되는 필드.

```
━━━ CONTRACT / STALE-TERM AUDIT ━━━
활성 용어: {N개 요약}
제거/OOS 용어: {N개}
Stale leak: {용어 → 발견 위치 × K} (없으면 "없음")
구현 함정:
  - Reserved name: {발견 × N}
  - Index identity: {발견 × N}
  - 미강제 invariant: {발견 × N}
  - ID/URL encoding 모호: {발견 × N}
  - Hot-row payload: {발견 × N}
```

### Audit 3: Missing-Info / Back-Question 도출 (모든 doc:* 필수)

무모순성(Audit 1·2)은 "서로 어긋나는가"만 본다. Audit 3은 **"맞는데 빠진 것"**을 잡는다. Audit 1의 1급 개념 맵을 입력으로, 각 개념/섹션마다 점검한다:

1. **구현·운영에 필요한데 문서에 없는 정보**를 항목별로 나열한다 (예: 새 필드의 타입/제약/기본값/nullable, 관계 cardinality, API 에러응답/권한, 상태 전이의 트리거·동시성·멱등성, 마이그레이션 순서, 외부 의존 실패 동작).
2. 누락 항목마다 사용자에게 던질 **역질문(back-question)**을 1줄로 형성한다 (추정으로 메우지 마라 — 빠진 정보 날조 = 해당 차원 0점).
3. 각 역질문을 `[blocking | non-blocking | out-of-scope]`로 분류한다. blocking = 핵심 contract(데이터 모델·API·상태 전이·충돌 규칙) 결정.

```
━━━ OPEN QUESTIONS (Audit 3) ━━━
{개념/섹션 → 누락 정보 → 역질문 [blocking|non-blocking|out-of-scope]} × Q
```

AUTO_CONTINUE라도 OPEN QUESTIONS 블록은 사용자에게 반드시 노출한다. blocking 역질문은 답변 또는 명시적 out-of-scope 분류 전까지 종료 금지.

역질문 생성 트리거(확대): 누락 정보뿐 아니라 **모호 표현도 역질문 대상이다** — 정량 기준 없는 형용사/부사("적절히·빠르게·충분히"), 미정 수치·임계값, 예시 없는 규칙, 판단 기준 없는 선택지. 목적은 문서를 **concrete**하게 만드는 것: 답을 받으면 그 자리에 수치·기준·예시로 반영한다.

질문 배치 규칙: 라운드 경계(SCORE 출력 직후 또는 APPLY 완료 후)에서 누적 역질문을 AskUserQuestion으로 **최대 4개씩 배치 질문**한다. 질문은 1회 제시하고 무응답이면 답 없이 진행한다 — 질문 노출과 개선 진행은 병행이며, 질문이 라운드를 멈추지 않는다. blocking 처리 순서: (1) 사용자 지시·기존 문서에서 답을 찾으면 출처 인용으로 해소 (2) 못 찾으면 노출을 유지한 채 그 항목만 제외하고 개선을 계속한다 — 멈춰 기다리지 않는다(금지는 '종료'와 auto의 '단계 완료 처리'뿐) (3) 답변 도착 시 다음 라운드 APPLY에 반영. non-blocking은 답변을 기다리지 않고 진행한다.

### Audit 결과 → SCORE 반영

- Stale leak 1건 이상 → 해당 차원(Architecture/Model Consistency 또는 Self-Consistency) 상한 60.
- 구현 함정 카테고리 1개 이상 미식별 상태로 active contract에 남음 → Completeness/Edge Cases 또는 Constraint Enforcement 상한 65.
- 고아/중복 섹션 1건 이상 → Structural Coherence/Procedure Rigor 상한 70.
- Reader path 끊김 → Readability 또는 Self-Consistency 상한 70.
- (doc:design) 미해결 역질문(Audit 3) 1건+ → Completeness/Edge Cases 상한 70. blocking 역질문 → 종료 금지 gate.

DIAGNOSE는 audit에서 식별된 항목을 차원 약점과 합쳐 batch로 다룬다.

---

## ROUND LEDGER — 라운드 원장

라운드마다 반복 출력하던 9종 체크 블록을 라운드 하나당 10개 원장 행(재독·채점경로·claude채점·codex채점·합의·진단·초안경로·채택·reviewer·TDD)으로 통합한다. 각 단계가 끝나는 즉시 그 행을 원장에 추가하고, 행이 채워지기 전에는 다음 단계로 진행하지 않는다 — 행 누락은 그 행이 속한 단계만 무효로 만든다(무효 범위는 아래 행별 스펙 참조). 성공은 `☑ {값}`, 실패는 `☐ {사유}`로 적으며, 실패해도 행 자체는 생략하지 않고 사유로 채운다.

TOOL_CHECK·PREP_CHECK·STEP6_CHECK는 라운드마다 반복되지 않는 일회성 체크라 이 원장 밖에 Step 0/Step 6 형태 그대로 유지한다.

```
━━ ROUND {N} LEDGER ━━
☑ 재독: round={N}, lines={wc -l 값}, mtime={stat 값}, dimensions={MODE} 유지(모드 변경 시만 재로드)
☑ 채점경로: Workflow 가용={yes/no}, 선택={workflow|agent-fallback}(, 근거={...})
☑ claude채점: ({claude-scorer|workflow}) {차원별 점수 1줄 요약}
☑ codex채점: {차원별 점수 1줄 요약}
☑ 합의: {cross-reviewer 정상 성공 — 점수 | 잠정합의[unverified-consensus] dimensions=<...> | 단독채택={claude|codex|claude(lazy-consensus)}+사유}
☑ 진단: 전수 {N}건 / 반영 {M}건|해당없음 / carryover {있음 K건|없음} / 충돌노트 {요약 1줄}
☑ 초안경로: Workflow 가용={yes/no}, 선택={workflow-fanout|single-worker}(, 근거={...})
☑ 채택: 초안 {N}개 완료 → claude {a}/codex {b}/merge {c}/재작성 {d}/조건미충족—claude단독
☑ reviewer: 항목 1..N {PASS|CAVEAT|FAIL} — {묶음 전반 1줄 요약}
☑ TDD: red {N}개 실패확인(원천: {doc:test 항목|spec AC|버그 재현}) / green 전체통과 / refactor 후 통과유지   ← TDD ON 라운드만
```

### 행별 스펙 (사유 allowlist·생존 분기·줄 형식 계약·무효 조건의 SSOT)

**fallback 근거 allowlist** (채점경로·초안경로 공용, 정확히 이 셋만 유효 — 실측값 기재 의무, 재량 판단 금지): `"Workflow 도구 부재"` | `"스크립트 오류 2회 누적({직전 오류 요약})"` | `"소형 프로파일: {N}파일 {M}줄, wc -l 실측 — 차원 {K}개"`(`### 소형 프로파일` 조건 충족). 이 셋 중 하나가 아니면 대체 경로(agent-fallback|single-worker)를 쓸 수 없다 — 간단해서·손에 익어서·이미 조사·설계를 마쳐서 알고 있어서·항목이 간단해서·직접이 빠르다·codex 쪽과 통일하려고 등은 모두 절차 위반 신호이며, 실측값 없는 "소형이라서"도 이 금지에 포함된다. Workflow/workflow-fanout이 가용한데 이 allowlist 밖 사유를 쓰면 그 경로로 되돌아간다.

**재독** — 라운드 시작 시 refine-steps.md를 다시 Read한 뒤 채운다(refine.md 라운드 루프). dimensions 재확인은 모드가 바뀐 경우에만 refine-modes.md를 다시 Read. 생략 시 그 라운드 SCORE 무효 — Step 1 SCORE 진입 전 필수. (실패 의미: block — 재독 후 재시도해야 다음 단계로 진행.)

**채점경로** — Phase 1 채점 코드(Workflow든 Agent든) 실행 전에 채운다. 선택이 agent-fallback이면 위 allowlist 근거를 함께 적는다. 생략 시 그 라운드 SCORE 무효. (실패 의미: block.)

**claude채점 / codex채점** — Phase 1 완료 직후 두 행을 함께 채운다. 실패 행: `☐ claude채점 실패: {사유}` / `☐ codex채점 실패: {사유}`(행은 유지, 실패 사유로 대체). 생존 분기 — 하나라도 성공이면 라운드 계속:
- 둘 다 성공 → 합의 행으로 진행(Phase 2 교차 리뷰).
- codex만 실패(에러·미설치·deadline timeout) → claude 결과 단독 채택(교차 리뷰 생략). claude가 **Workflow 경로**(원점수 배열 perDimension, 미종합)든 **Agent 경로**(claude-scorer, 이미 종합된 단일 보고)든 이번 라운드 1회 한정 lazy-consensus(opus — `## 오케스트레이션 & 모델 정책` Agent 스폰 역할 표)를 발동해 과대평가를 지적한 뒤(Workflow 경로는 원점수 종합까지, Agent 경로는 이미 종합된 점수의 과대평가 여부만 재검토) `claude(lazy-consensus)`로 표기해 채택한다(audit cap 미적용 — cap 보정은 여전히 main 책임) — 두 경로 모두 동일하게 lazy-consensus를 거쳐 fallback 품질을 균일하게 유지한다.
- claude만 실패(멤버 timeout·포기) → codex 결과 단독 채택.
- 둘 다 실패 → 그 라운드 SCORE 무효(main 직접 채점 금지, hard constraint) — 다음 라운드 두 멤버 재스폰으로 재시도.
Codex가 설치돼 있는데 호출 자체를 안 한 것은 "실패"가 아니라 절차 위반이다(예외: 미설치·spawn 실패로 `### 즉시 실패` 표기한 경우만 환경상 허용). 두 행이 채워지기 전 합의 행으로 진행하면 절차 위반이며 그 라운드 SCORE 무효로 이어진다. (실패 의미: 편측 실패=continue — 생존 분기로 라운드 지속; 양측 실패=block — SCORE 무효.)

**합의** — cross-reviewer(또는 그 실패 시 아래 대체 절차) 완료 직후 채운다. 아래 세 값 중 이번 라운드에 실제로 성립하는 것 정확히 하나만 쓴다:
- `cross-reviewer 정상 성공 — {차원별 최종 점수 1줄 요약}`: Phase 1 둘 다 성공하고 cross-reviewer가 정상 완료된 경우.
- `잠정합의[unverified-consensus] round=<N> dimensions=<영향 차원 목록>`: Phase 1 둘 다 성공(claude채점·codex채점 행 모두 `☑`)했지만 cross-reviewer 자체가 스폰 실패했거나 `## Step 0 멤버 구성 > ### 멤버 timeout & 강제 정리`의 30분 cap까지 거쳐 포기된 경우. main은 새 채점 판단을 만들지 않고 고정 산술만 대입한다(`## 오케스트레이션 & 모델 정책 > ### main 단독 판단의 경계`가 허용하는 "codex 실패 시 fallback 결정"과 같은 성격) — 차원별 점수차 5점 이내면 평균, 5점 초과면 근거 설득력과 무관하게 더 낮은 쪽을 잠정치로 채택. `.refine.log`에 마커 기록(결함 cap이 아니며 점수 상한을 걸지 않는다 — 이번 라운드 Phase 2가 비어 잠정 합의로 메웠다는 절차 상태만 남긴다). 다음 라운드 SCORE Phase 2는 이 마커의 `dimensions`를 통상 cross-reviewer 호출에 포함시켜 재교차검증해야 한다("이전 합의 유지"로 생략하면 절차 위반) — 성공하면 `[unverified-consensus-resolved] round=<N>`을 추가 기록, 재실패하면 같은 5점 규칙으로 잠정치를 다시 산출해 그 라운드 번호로 마커를 재기록한다.
- `단독채택={claude|codex|claude(lazy-consensus)}+사유`: Phase 1 결과 1개만 성공해 교차 리뷰가 구조적으로 불필요했던 경우(claude채점/codex채점 행의 생존 분기 참조).
위 셋 중 어느 것도 성립하지 않거나 행 자체를 생략하면 `☐ 합의 미충족`이며 그 라운드 SCORE는 무효다 — main은 검증되지 않은 두 점수 중 하나를 임의로 채택하거나 새 합의를 만들어 이 게이트를 우회할 수 없다(Phase 1 둘 다 실패는 claude채점·codex채점 행의 생존 분기에서 이미 SCORE 무효가 확정되어 이 행 자체가 발생하지 않는다). (실패 의미: 잠정합의=carryover — 다음 라운드 재교차검증 의무; 합의 미충족=block — SCORE 무효.)

**진단** — DIAGNOSE 완료 직후 채운다: 70미만+cap70 전수 대조 건수, audit/REGRESSION_ISSUE/codex 20점차 반영 여부, 직전 라운드 `[unverified-carryover]` 반영 여부, 의존성/충돌 노트(각 항목의 정의는 위 `## DIAGNOSE` 참조). 누락 발견 시 `☐ 진단 누락: {누락 범주}`로 표기하고 DIAGNOSE에 추가한 뒤 행을 다시 쓴다. 생략 시 그 라운드 PROPOSE 무효. (실패 의미: block.)

**초안경로** — claude 측 초안 작성 방식(fan-out 여부)을 정한 직후 채운다. 선택이 single-worker면 위 allowlist 근거를 함께 적는다(경로쌍만 workflow-fanout|single-worker로 바뀐다). allowlist 밖 사유로 single-worker를 쓰거나 행을 생략하면 절차 위반이며 그 라운드 PROPOSE 무효로 이어진다. (실패 의미: block.)

**채택** — PROPOSE_COMPARE 판정 직후 채운다: claude 측 초안 완료 개수 + PROPOSE_COMPARE 채택 집계. 채택본 항목별 정확성/완전성/부작용 검증은 이 행이 아니라 APPLY의 reviewer 행이 수행한다. 실패: `☐ 채택 실패: {항목} 누락 — 재시도 후에도 미완료. codex-proposer 결과가 있으면 그 단독안으로 대체, 없으면 다음 라운드로 defer`. 생략 시 APPLY 진행 불가. (실패 의미: 항목 결손=continue — codex-proposer 단독안으로 대체하거나 다음 라운드로 defer; 행 생략=block — APPLY 진행 불가.)

**reviewer** — codex-reviewer 완료 직후 채운다: 항목 1..N의 PASS|CAVEAT|FAIL과 묶음 전반 1줄 요약. 호출 실패 시만 `☐ reviewer 호출 실패 — 정의된 예외 분기로 진행`. 생략 시 다음 라운드 진행 불가. (실패 의미: carryover — `[unverified-carryover]` 기록 후 다음 라운드 1급 약점으로 재검증.)

**TDD**(TDD ON 라운드만 — OFF 라운드는 원장에서 이 행을 생략하며, 이는 무효 대상이 아니다) — APPLY의 red→green→refactor 완료 직후 채운다. 실패는 항목별로 대체 가능: `☐ red 실패: 테스트가 이미 통과(대상 기구현 — red 재설계 또는 항목 제외)` / `☐ green 미달: {사유} — 그 항목은 Items에 deferred로 기록` / `☐ refactor 회귀: 리팩토링을 되돌리고 green 상태로 복원`. 생략 시 그 라운드 APPLY 무효. (실패 의미: 항목별 실패=해당 항목 deferred — Items에 표기 후 계속 진행; 행 생략=block.)

---

## SCORE — 2-Phase 채점

**⛔ main thread 단독 채점 금지 — 점수 생성은 채점 주체(Workflow 파이프라인 또는 아래 named Agent)가 수행한다. main의 역할은 발사·수집·audit cap 보정까지다.**

SCORE 진입 전제: 이번 라운드 `## ROUND LEDGER`의 재독 행(refine.md 라운드 루프)이 이미 채워져 있어야 한다 — 없으면 이 SCORE는 무효이고, 재독 행(절차 재독 포함)을 채운 뒤 SCORE를 다시 실행한다. 재독 행의 dimensions 표기는 Step 0 로드값의 유지 확인이며, 모드가 바뀐 경우에만 refine-modes.md를 다시 Read한다.

### Phase 1: 병렬 채점 — claude 측 채점과 codex-scorer를 동시에 발사

claude 측 채점은 **Workflow 파이프라인 우선**(`## 오케스트레이션 & 모델 정책` 템플릿), 불가 시 아래 named Agent 스폰. 어느 경로든 codex-scorer CLI job과 한 타이밍에 병렬로 발사한다. Agent() 코드블록이 바로 아래 인라인으로 보인다고 조건 확인 없이 그대로 실행하지 마라 — 아래 LEDGER 채점경로 행이 Phase 1 코드 실행 직전 필수 게이트다.

**⛔ `## ROUND LEDGER`의 채점경로 행을 채워야 Phase 1 코드(Workflow든 Agent든) 실행 가능 (생략 시 그 라운드 SCORE 무효 — 형식·근거 allowlist는 그 섹션 참조).**

```
Agent({ name: "claude-scorer", subagent_type: "general-purpose", model: "sonnet",   // 모델 정책: 채점 실무 계층
  prompt: "너는 /refine의 채점자이다.
    대상: {DOC_PATH}, 모드: {MODE}
    평가 차원: {DIMENSIONS — refine-modes.md에서 읽은 차원 테이블}
    
    1. 대상 파일을 읽어라.
    2. 각 차원의 평가 기준 문항을 분해하라 (물음표 단위).
    3. 각 문항을 0-100으로 채점하라 (근거 2-3문장).
    4. code 모드면 소스 파일도 읽어 정확성 검증.
    5. 결과: 차원명: [점수]/100 — 문항별 상세
    
    채점 기준: 0-20 없음, 21-40 추상적, 41-60 절반 미충족, 61-70 중요 빈틈,
    71-85 사소한 빈틈, 86-95 추가 깊이, 96-100 완벽.
    관대하지 마라. 50은 부족, 71이 괜찮음의 시작.
    날조 수치 = 해당 차원 0점." })

# codex-scorer = CLI job (⛔ 팀 멤버 Agent 아님). PREP 컨텍스트 재사용 + 결과를 /tmp 파일로 수집.
CTX="<Step 0 PREP 1번(없으면 ### ⚡ 속도 규칙 1)의 ctx-package.sh 호출이 stdout 으로 출력한 산출 경로 — 그 캡처값을 그대로 쓴다>"   # ctx-package.sh는 호출마다 반대 유형의 stale 산출물을 rm해 RUN당 .diff/.txt 중 정확히 1개만 남기고 그 경로를 stdout에 출력한다 — 이 캡처값이 CTX의 유일한 출처다. doc:* 사전 audit·라운드 1 전체 채점처럼 전문이 필요하면 그 생성 호출에 --full을 써서 .txt(전문)를 캡처해 둔다. 대상 파일 갱신은 항상 ctx-package.sh 실행을 통해서만 한다 — 그래야 이 stdout 캡처 보장이 유지된다.
OUTFILE=/tmp/refine_codex-scorer_r{N}_${RUN}.md   # codex-job.sh launch가 동일 공식으로 내부 계산 — 프롬프트 본문에 박아 넣을 값
~/.claude/commands/refine-scripts/codex-job.sh launch codex-scorer {N} "$RUN" - <대상 파일들> <<PROMPT_EOF
먼저 /tmp/codex_prenotes_${RUN}.md(있으면)와 $CTX 를 읽어라(파일 탐색 금지). 대상을 adversarial하게 평가하라.
모드: {MODE} / 평가 차원: {DIMENSIONS}
기준: (a) 주장이 코드로 뒷받침되나 (b) 빠진 항목 (c) 모호 표현 반례 (d) 날조 수치=0점.
⛔ 결과는 반드시 Bash로 정확히 $OUTFILE 에 기록하라: 차원별 [점수]/100 + 가중평균 종합 + 근거. 기록 후 wc -l "$OUTFILE" 로 확인.
PROMPT_EOF
# → stdout: TASK_ID=... OUTFILE=...(위 OUTFILE과 동일) ISOLATE=...(격리 위반 시 복원용 스냅샷 디렉터리) 캡처 → ## Codex CLI job 호출 공통 규칙의 codex-job.sh poll(OUTFILE 비었으면 EMPTY RESULT=실패) → DONE 시 OUTFILE 읽어 채점 반영.
```

**⏱ Codex 호출 공통 규칙 적용 (30분 timeout)** — codex-scorer 가 1800초 안에 결과 없으면 cancel + `☐ codex-scorer 호출 실패 (30분 timeout)` 표기 후 Phase 2 진행.

**⛔ Phase 1 완료 직후 `## ROUND LEDGER`의 claude채점·codex채점 행을 채워야 Phase 2 진행 가능 (형식·생존 분기·무효 조건은 그 섹션 참조).**

### Phase 2: 교차 리뷰 — Phase 1 결과를 모은 후

```
Agent({ name: "cross-reviewer", subagent_type: "general-purpose", model: "opus",   // 모델 정책: sub-project 관리 계층. Workflow에 별도 Consensus phase가 없어 이 호출이 유일한 opus 중재 지점이다.
  prompt: "claude 측 차원별 원점수와 codex 채점을 직접 대조해 차원별로 중재하라.
    Claude 차원별 원점수(근거 포함, 사전 합의·조정 없는 원본): {claude_scores} — Workflow perDimension 배열 또는 claude-scorer 문항별 보고 그대로
    Codex 차원별 점수: {codex_scores}
    
    1. 차원마다 양쪽 근거를 읽고 5점 이내 차이면 평균, 5점 초과면 근거가 더 설득력 있는 쪽을 채택 (판단 이유 명시).
    2. claude 측 원점수 중 근거 대비 부풀려진(과대평가) 차원이 있으면 지적하고 하향 조정.
    3. 차원별 최종 점수를 확정한 뒤 가중치를 적용해 종합 점수를 산출하라. (audit cap 보정은 main이 별도로 수행 — 이 호출의 책임이 아니다.)" })
```

**⛔ Phase 2 완료 직후(cross-reviewer 자체가 실패하면 그 대체 절차 완료 직후) `## ROUND LEDGER`의 합의 행을 채워야 SCORE 출력으로 진행 가능 (세 값 중 정확히 하나, 산출 규칙·마커 수명주기·무효 조건은 그 섹션 참조).**

### SCORE 출력

```
═══ Round {N} — SCORE ({MODE}) ═══
  {차원} ({가중치}%): {점수}/100 [claude:{X}, codex:{Y} → 합의:{Z}] "{근거}"
  ...
  종합: {가중평균}/100
```

한쪽 채점 실패 시 표기: `[claude:{X}, codex:—({사유}) → 채택:{X}]` — 합의가 아니라 단독 채택임을 명시한다. codex 실패 + lazy-consensus가 종합한 경우(claude가 Workflow 원점수든 Agent 단일 보고든)는 `[claude(lazy-consensus):{X}, codex:—({사유}) → 채택:{X}]`로 표기해 opus 종합을 거쳤음을 남긴다.

Phase 2 fallback(`## ROUND LEDGER` 합의 행의 잠정합의 값)이 적용된 차원은 표기를 구분한다: `[claude:{X}, codex:{Y} → 잠정합의:{Z}] [unverified-consensus]` (예: `Procedure Rigor (25%): 76/100 [claude:74, codex:78 → 잠정합의:76] [unverified-consensus] "{근거}"`). 확정 합의 표기(`→ 합의:{Z}`)와 구분되며, 다음 라운드 재교차검증으로 `.refine.log`에 `[unverified-consensus-resolved]`가 기록되기 전까지 이 표기를 유지한다.

종료 조건 판정은 refine.md `## 라운드 루프` Step 5가 SSOT다 — 종합 점수·70 미만 차원 존재 여부·round 상한의 기본 조건과 doc:* 완료 gate·blocking open question 예외까지 전부 거기서 정의한다.
조건 미충족 시 계속 (70 미만 우선 수정).

**Round 2+에서의 SCORE는 이전 라운드 수정의 RE-SCORE 역할도 겸한다.** 별도 RE-SCORE 단계는 없다.
이전 라운드 대비 올랐으면 KEEP, 내렸으면 이전 수정을 ROLLBACK 후 다른 차원 시도.

---

## DIAGNOSE — 약점 전체 식별 (Batch)

이 라운드에서 **동시에 수정할 모든 약점**을 식별한다. 한 라운드 = 한 약점 모델은 폐기됨.

- 기본: 70 미만인 모든 차원/문항 + 결함 cap으로 정확히 70에 고정된 차원/문항을 전부 나열(둘 다 종료 게이트 미통과 대상이므로 동일하게 다룬다).
- auto 회귀 점검이 주입한 `REGRESSION_ISSUE`가 있으면 1급 약점으로 포함한다 (refine.md `### auto 회귀 점검`).
- `.refine.log`에 직전 라운드의 `[unverified-carryover]` 마커가 있으면(codex-reviewer 호출 실패로 검증·리뷰 없이 진행한 항목), 그 항목 전체를 1급 약점으로 우선 포함해 재검증 대상으로 삼는다 — 이번 라운드 codex 검증/리뷰가 PASS로 확인될 때까지 매 라운드 반복 포함한다(3라운드 연속 미해소면 `## Codex CLI job 호출 공통 규칙 > ### 절차` 7번의 `[unverified-final]` 캐비앗 표기로 종료 가능).
- FOCUS 지정 시: 해당 차원 안의 모든 70 미만 문항.
- code/integrate에서 테스트 통과율 < 100%이면 통과율 회복을 우선 항목으로 배치.
- Codex가 Claude보다 20점+ 낮게 평가한 문항도 추가 (잠재 위험).
- 우선순위는 그래도 부여 (가중치 높은 차원 우선) — APPLY 충돌 시 결정용. 그러나 모두 같은 라운드 안에서 수정.

```
━━━ DIAGNOSE (Batch) ━━━
대상 약점 N개:
  1. {차원} ({점수}) — {문항} ({문항점수}) — 진단: {1-2문장}
  2. {차원} ({점수}) — {문항} ({문항점수}) — 진단: {1-2문장}
  ...
의존성/충돌 노트: {약점 간 상호작용 1-2줄}
```

**⛔ DIAGNOSE 완료 직후 `## ROUND LEDGER`의 진단 행을 채워야 PROPOSE 진행 가능 (생략 시 그 라운드 PROPOSE 무효 — 형식은 그 섹션 참조).**

---

## PROPOSE — 수정안 전체 작성 (Batch, 조건부 dual-track)

DIAGNOSE에서 나열한 N개 약점 각각에 대해 **claude가 매 라운드 독립 수정안을 작성**한다. 아래 발사 조건을 충족하는 라운드는 codex도 병렬로 독립 수정안을 작성해 비교 채택한다 — 검증은 비교 채택 시점이 아니라 **APPLY 이후 codex-reviewer가 통합 수행**한다(`## APPLY` 4번).

### codex-proposer 발사 조건 (allowlist, 기계 판정)

codex-proposer는 매 라운드 무조건 발사하지 않는다. 아래 중 **하나라도** 성립할 때만 발사한다:
1. Round == 1
2. 직전 라운드 Result == ROLLBACK (`.refine.log` 직전 `## Round {N}` 기록의 `Result:` 필드로 판정)
3. 정체 감지 발동 — 직전 3라운드 연속 델타 +3 미만 (refine.md `## 라운드 루프` Step 5 정체 감지 정의와 동일 조건)
4. 직전 SCORE에서 codex가 claude보다 20점 이상 낮게 본 차원이 이번 라운드 DIAGNOSE에 포함된 경우 (`## DIAGNOSE`의 "Codex가 Claude보다 20점+ 낮게 평가한 문항" 입력과 동일 근거 — codex가 지적한 위험을 수정안에도 반영한다)

네 조건 모두 불성립하면 이번 라운드는 codex-proposer를 발사하지 않고 **claude 단독 초안**으로 진행한다 — 아래 2b PROPOSE_COMPARE는 항목별 비교 없이 "조건 미충족—claude 단독"으로 표기만 남긴다.

0. **codex-proposer 발사 (위 조건 충족 시, DIAGNOSE 확정 직후 즉시, background)** — 독립성: claude 수정안을 프롬프트에 넣지 않는다.

**⛔ code/test 모드 필수 격리 — 실제 대상 파일 직접 수정 절대 금지**: doc 모드는 codex-proposer가 텍스트만 다뤄 OUTFILE 외에 건드릴 파일이 없지만, code/test 모드는 codex가 실제 소스를 직접 고칠 유인(그리고 `--write` 권한)이 있다 — 같은 시간대에 claude 측(Workflow fan-out 또는 single-worker)도 같은 대상 파일을 실제로 Edit/Write하고 있으므로, codex가 실제 파일을 직접 고치면 두 트랙이 같은 파일을 동시에 써서 결과가 서로 다른 이름/구조로 뒤섞이거나 한쪽이 다른 쪽을 덮어쓴다(실측 2026-07-04: 서로 다른 이름의 데이터클래스/함수를 각자 도입해 cross-file import가 깨졌고, 회복에 별도 라운드가 필요했다). 프롬프트에 아래 문장을 코드/문서 지시보다 먼저, 반드시 포함한다: "너는 실제 저장소의 어떤 파일도 Edit/Write/apply_patch로 수정하지 않는다 — 오직 읽기만 하고, 제안하는 코드 전체를 텍스트로 $OUTFILE 에만 작성한다. 다른 파일을 고치면 이 작업은 실패로 간주된다." 발사 후 폴링 중간에 `git status --porcelain -- <대상 파일들>`로 대상 파일이 실제로 안 건드려졌는지 1회 이상 확인하고, 건드려졌으면 즉시 `cancel` 후 codex-proposer `launch` 시점에 받은 `ISOLATE`가 `none`이 아니면 `~/.claude/commands/refine-scripts/snapshot.sh restore "$ISOLATE"`로 대상 파일만 복원한다 — `git checkout HEAD --`는 pre-해시 이전의 미커밋 변경까지 되돌려 파괴하므로 쓰지 않는다. `ISOLATE=none`이거나 복원 실패면 자동 복구를 멈추고 `☐ codex-proposer 격리 위반 — 스냅샷 복원 불가, blocked`로 표기 후 보고한다. 복원 성공 시 `☐ codex-proposer 격리 위반 (실제 파일 수정 감지, 스냅샷 복원됨)`으로 표기, claude 단독 진행으로 전환한다.

```bash
# codex-proposer = CLI job (⛔ 팀 멤버 Agent 아님).
OUTFILE=/tmp/refine_codex-proposer_r{N}_${RUN}.md   # codex-job.sh launch가 동일 공식으로 내부 계산 — 프롬프트 본문에 박아 넣을 값
~/.claude/commands/refine-scripts/codex-job.sh launch codex-proposer {N} "$RUN" - <대상 파일들> <<PROMPT_EOF
먼저 /tmp/codex_prenotes_${RUN}.md(있으면)와 $CTX 를 읽어라(파일 탐색 금지).
⛔ 너는 실제 저장소의 어떤 파일도 Edit/Write/apply_patch로 수정하지 않는다 — 오직 읽기만 하고, 제안하는 코드/텍스트 전체를 아래 $OUTFILE 에만 작성한다. 다른 파일을 고치면 이 작업은 실패로 간주된다.
아래 약점 목록 각각에 대해 독립 수정안을 작성하라. 산출물 형식(모드별): doc:* = 반영 가능한 수정 텍스트,
code = patch/diff 또는 전체 파일 내용(텍스트로만, 실제 파일에 쓰지 마라),
test = 테스트 코드(텍스트로만).
약점들: {DIAGNOSE 결과 N개}
⛔ 결과는 반드시 Bash로 정확히 $OUTFILE 에 기록: 항목별 수정안 전문. 기록 후 wc -l "$OUTFILE" 확인.
PROMPT_EOF
# stdout task-id/OUTFILE/ISOLATE 캡처 → ## Codex CLI job 호출 공통 규칙의 codex-job.sh poll + 위 격리 위반 확인(위반 시 ISOLATE에서 복원).
```
1. **claude 측 초안 작성** — 약점 항목별 fan-out 여부를 SCORE Phase 1과 같은 원칙(Workflow 우선, 불가 시 단일 워커)으로 정하되, 독립 게이트로 확인한다(생략 시 그 라운드 PROPOSE 무효). **code/test 모드도 예외 없이 적용된다** — main이 조사·설계로 무엇을 만들지 이미 알고 있어도 실제 텍스트/코드 작성은 sonnet 워커에게 브리핑으로 넘긴다:

**⛔ `## ROUND LEDGER`의 초안경로 행을 채워야 아래 초안 작성이 진행 가능 (근거 allowlist·무효 조건은 그 섹션 참조).**
   - **workflow-fanout**: `## 오케스트레이션 & 모델 정책`의 `refine-propose` 복붙 템플릿으로 N개 약점 항목을 `parallel(weakItems.map(item => agent(...)))`로 동시에 작성한다. 각 항목은 이미 완결된 수정안이므로 SCORE의 opus 조정(cross-reviewer)은 이식하지 않는다 — 항목 간 조율은 아래 2번·2b가 담당한다. fan-out 결과 중 일부 항목이 null(에이전트 실패/스킵)이면 템플릿의 `missing` 목록으로 식별한다 — 그 항목만 single-worker로 1회 재시도하고, 재시도도 실패하면: codex-proposer가 이번 라운드 발사되어 그 항목의 결과가 있으면 codex-proposer 단독안으로 처리한다(2b에서 채택={codex} 강제, claude 부재를 이유로 명시). codex-proposer 미발사(위 발사 조건 불성립) 또는 그 항목마저 실패/빈 결과면 대체할 안이 없으므로 그 항목은 다음 라운드 DIAGNOSE로 defer하고 `Items`에 `deferred: {항목}`으로 표기한다(PROPOSE `규칙:` 절의 해소 불가 약점과 동일 처리).
   - **single-worker**: sonnet 실무 워커 1명이 N개 항목 초안을 한 번에 작성한다(기존 방식, `## 오케스트레이션 & 모델 정책` 계층 원칙). 아래 템플릿을 그대로 사용한다(one-shot 워커이며 long-lived 멤버로 재사용하지 않는다. `Agent({...})`는 Claude Code의 Agent 도구 호출이며, workflow-fanout의 `agent(...)`는 별개로 Workflow 스크립트 내부 DSL 함수다 — 혼동 금지):
     ```js
     Agent({ name: "claude-proposer", subagent_type: "general-purpose", model: "sonnet",
       prompt: `너는 /refine PROPOSE의 claude 측 작성자다.
대상: {DOC_PATH}, 모드: {MODE}
아래 DIAGNOSE 약점 N개 각각에 대해 그대로 반영 가능한 수정안을 작성하라.

규칙:
1. 항목을 누락하지 마라. 한 라운드 = 모든 약점 일괄 수정이다.
2. 산출물 형식: doc:* = old -> new 수정 텍스트, code = patch/diff, test = 테스트 코드.
3. 각 수정안은 파일명, old 텍스트, new 텍스트를 포함해 main이 바로 APPLY할 수 있어야 한다.
4. 항목 간 충돌이 있으면 충돌 노트와 적용 순서를 제시하라.
5. 추정 수치/날조 금지. 근거 없는 수치는 해당 항목 실패로 표기하라.

DIAGNOSE:
{DIAGNOSE 결과 N개}

출력:
항목 1..N 각각에 대해 파일 / old / new / rationale / 충돌 여부를 작성하라.` })
     ```
   - 어느 경로든 main은 검수·통합만 한다(대상에 직접 반영 가능한 수준).
2. 수정안 간 충돌/중복 검사 — 같은 파일/심볼을 건드리는 경우 통합하거나 순서 명시.
2b. **PROPOSE_COMPARE (비교 채택)**: codex-proposer가 발사된 라운드는 그 결과 도착 시 항목별로 두 안을 나란히 비교해 채택한다. 판단 기준 순서: 정확성 > 부작용 적음 > 간결함.
```
PROPOSE_COMPARE:
항목 k: 채택={claude|codex|merge|재작성} — {이유 1줄}  × N
```
codex-proposer 실패/timeout/빈 결과 → claude 단독안으로 진행 (`☐ codex-proposer 실패: {사유}` 표기 — 기존 단일 트랙과 동일). codex-proposer **미발사**(위 발사 조건 불성립) 라운드는 비교 자체가 없다 — `PROPOSE_COMPARE: 조건 미충족—claude 단독 (codex-proposer 미발사, 전 항목 claude 초안 채택)` 한 줄로 표기만 남긴다.

**⛔ PROPOSE_COMPARE 판정 직후 `## ROUND LEDGER`의 채택 행을 채워야 APPLY 진행 가능 (형식·실패 표기는 그 섹션 참조).**

채택본 항목별 정확성/완전성/부작용 검증은 이 단계에서 하지 않는다 — APPLY 4번 codex-reviewer가 diff 교차 리뷰와 함께 통합 수행한다.

3. PROPOSE_COMPARE 채택본(또는 조건 미충족 시 claude 단독 초안)을 그대로 APPLY로 넘긴다 — 항목별 검증은 APPLY 4번 codex-reviewer가 통합 수행한다.

규칙:
- 한 라운드 = 식별된 모든 약점 동시 수정. 빠뜨리면 절차 위반.
- 충돌이 해소 불가능한 두 약점은 우선순위 높은 쪽만 이번 라운드에 수정하고, 나머지는 다음 라운드 DIAGNOSE에서 재식별 (묻지 말고 진행).
- code Correctness Q2가 약점이고 원인이 미구현이면 → 기능 구현이 수정안.

---

## APPLY — 모든 수정안 일괄 반영

0. **스냅샷(ROLLBACK 자산)**: 대상 파일 pre-해시(`shasum`) 기록 + **git 여부와 무관하게** 대상 파일을 `/tmp/refine_backup_r{N}_${RUN}/`로 cp — 라운드 diff와 역적용은 이 백업 기준이다. pre-해시 이전부터 있던 dirty 변경은 백업에 그대로 담겨 보존된다(이번 라운드 적용분과 자동 분리). 백업 파일명↔원본 절대경로 매핑은 `BACKUP_DIR/manifest.tsv`에 기록된다(절대경로의 `/`를 `__`로 치환해 유니크화 — 서로 다른 디렉토리의 동일 basename 충돌 제거). 이번 라운드에 새로 생성될 파일(스냅샷 시점에 아직 부재)은 백업을 생략하고 manifest에 `added`로만 남긴다.
```bash
~/.claude/commands/refine-scripts/snapshot.sh /tmp/refine_backup_r{N}_${RUN} <대상 파일 절대경로들>
```
1. PROPOSE의 N개 수정안(PROPOSE_COMPARE 채택본)을 모두 Edit으로 반영.
   - 같은 파일에 여러 수정이 들어가면 한 번에 적용 (충돌 방지).
2. code/integrate: lint 실행. 실패 시 **결정적·기계적 수정(포맷터/린터 자동수정, 예: `black .`/`eslint --fix`)은 main이 즉시 적용**하고, 자동수정으로 해소되지 않는 나머지는 sonnet 워커(`## 오케스트레이션 & 모델 정책`의 실무 작성 원칙과 동일)에게 브리핑으로 위임해 그 산출물을 반영한다.
3. Cross-doc 동기화: 데이터 모델/인터페이스 변경 시 `grep -r "변경 용어" docs/*.md` 확인.
4. Codex 교차 리뷰 — codex 가용 시 필수 호출 (**채택 수정안 항목별 정확성/완전성/부작용 검증**(PROPOSE에서 분리 검증하던 임무를 통합) **+ 전체 diff 회귀 리뷰**를 한 번에 수행. PROPOSE의 비교 채택은 이 검증을 대체하지 않는다 — 병합·재작성본은 여기서 처음 adversarial하게 검토된다. 미설치/spawn 실패/timeout 시에는 아래 정의된 예외 분기를 따른다):
```
# codex-reviewer = CLI job (⛔ 팀 멤버 Agent 아님).
OUTFILE=/tmp/refine_codex-reviewer_r{N}_${RUN}.md   # codex-job.sh launch가 동일 공식으로 내부 계산 — 프롬프트 본문에 박아 넣을 값
ROUND_DIFF_FILE=/tmp/refine_r{N}_review_${RUN}.patch
BACKUP_DIR=/tmp/refine_backup_r{N}_${RUN}
# reviewer 직전 실제 적용 diff를 백업 기준으로 생성해 프롬프트에 인라인한다(pre-existing dirty 변경과 분리).
# <수정 파일 절대경로들>은 APPLY 0번에서 스냅샷한 대상 파일의 절대경로 목록이다(예: /Users/.../refine.md) — round-diff.sh가 BACKUP_DIR/manifest.tsv로 절대경로 매칭해 대조한다.
~/.claude/commands/refine-scripts/round-diff.sh "$BACKUP_DIR" "$ROUND_DIFF_FILE" <수정 파일 절대경로들>
# ⛔ 위가 exit 1(backup 누락 또는 변경 있는데 빈 patch — round-diff.sh가 WARNING과 함께 종료)이면 codex-reviewer를 발사하지 말고 그 경로부터 해결한다 — 빈 diff를 "리뷰 완료"로 오인하지 않는다.
# ⛔ exit 2(diff 자체 오류 — 파일 접근/권한 등, "차이 있음"인 rc=1과 구분)면 backup 경로 문제가 아니므로 codex-reviewer 발사 전 오류 원인부터 점검한다.
ROUND_DIFF="$(cat "$ROUND_DIFF_FILE")"
~/.claude/commands/refine-scripts/codex-job.sh launch codex-reviewer {N} "$RUN" - <수정 파일 절대경로들> <<PROMPT_EOF
먼저 /tmp/codex_prenotes_${RUN}.md(있으면)와 /tmp/codex_audit_${RUN}.md(doc:*면 있으면)를 읽어라. PREP 노트가 없으면 이 프롬프트에 포함된 diff/수정안만으로 평가하고 파일 탐색은 하지 마라.
이번 라운드 diff 전문:
$ROUND_DIFF

수정 파일: {경로 목록} / 약점들: {DIAGNOSE 결과 N개} / 채택된 수정안(적용됨): {PROPOSE_COMPARE 채택본 N개 1줄 요약}
각 항목별로 (a) 원래 약점 대비 정확성·완전성 (b) 부작용 (c) 새 버그/에지 케이스 + 항목 간 상호작용 회귀를 검증하라.
⛔ 결과는 반드시 Bash로 정확히 $OUTFILE 에 기록: 항목별 PASS|CAVEAT|FAIL + 사유 + 묶음 1줄. 기록 후 wc -l "$OUTFILE" 확인.
PROMPT_EOF
# stdout의 task-id/OUTFILE/ISOLATE 캡처 → ## Codex CLI job 호출 공통 규칙의 codex-job.sh poll(OUTFILE 비면 EMPTY=실패) → DONE 시 OUTFILE 읽기. 격리 위반 시 ISOLATE에서 복원(위 도입부 참조).
```

**⏱ Codex 호출 공통 규칙 적용 (30분 timeout)** — codex-reviewer 가 1800초 안에 결과 없으면 cancel + `☐ codex-reviewer 호출 실패 (30분 timeout) — 정의된 예외 분기로 진행` 표기 후 다음 라운드.

**⛔ codex-reviewer 완료 직후 `## ROUND LEDGER`의 reviewer 행을 채워야 다음 라운드 진행 가능 (형식은 그 섹션 참조).**

5. code/integrate: 테스트 재실행 (전체 묶음 적용 후 한 번).
5b. **(test/integrate + TDD ON code 한정) Mutation sanity check** — 이번 라운드에 새로 쓰거나 강화한 테스트가 검증하는 **그 분기만** 1-라인 mutation으로 임시로 깨뜨려(예: 비교 연산 반전, early-return 제거, write 호출 주석화) 해당 테스트가 **실패(red)** 하는지 확인하고 즉시 원복한다. 여전히 통과(green)면 그 테스트는 분기를 실제로 검증하지 못하는 것이다 → 그 항목을 다음 DIAGNOSE의 1급 약점으로 올리고 Failure-Mode Coverage에서 NONE 처리한다. ⛔ 전체 파일 mutation testing이 아니다 — 이번 라운드 변경분이 검증하는 분기로만 한정한다. mutation은 워킹트리에 남기지 말고 확인 직후 원복한다.
6. 유효 이슈(위치 인용 + 조건 명시 + 수정 제안)가 있으면 반영한다 — **결정적·기계적 수정(포맷터/린터 자동수정)은 main이 즉시 적용**하고, 비기계적 수정(코드/문장 재구성)은 sonnet 워커에게 브리핑으로 위임해 그 산출물을 Edit/Write로 반영한다(`## 오케스트레이션 & 모델 정책` 원칙과 동일).
7. .refine.log에 라운드 기록 — 적용된 N개 항목 모두 나열.
8. **라운드 diff·post-해시를 저장하고 다음 라운드 SCORE로 돌아간다.** APPLY 직후 라운드 diff를 **백업 대비**로 생성한다: `~/.claude/commands/refine-scripts/round-diff.sh /tmp/refine_backup_r{N}_${RUN} /tmp/refine_r{N}_round_${RUN}.patch <대상 파일들>` (git diff가 아니라 백업 기준 — 이번 라운드 적용분만 정확히 담기고 pre-existing dirty 변경은 patch 밖에 남는다). **exit 0(patch 생성 성공)일 때만** 다음 단계로 진행한다 — exit 1(backup 누락 또는 변경 있는데 빈 patch, APPLY 4번과 동일한 가드)이면 ROLLBACK 자산을 불완전한 채로 남기지 말고 그 경로부터 해결한 뒤 저장을 재시도한다. exit 2(diff 자체 오류 — 파일 접근/권한 등, "차이 있음"인 rc=1과 구분, APPLY 4번과 동일한 가드)면 backup 경로 문제가 아니므로 오류 원인부터 점검한 뒤 저장을 재시도한다. 대상 post-해시도 함께 저장한다 — ROLLBACK 자산은 '적용 직후 상태' 기준이다. 다음 SCORE가 이전 대비 종합으로 올랐으면 KEEP, 내렸으면 ROLLBACK: **현재 해시가 post-해시와 일치할 때만** 라운드 patch를 역적용한다(`patch -R -p0 < patch` 또는 backup 복원 — 묶음 전체, 부분 롤백 금지, 부분 롤백은 다음 라운드 DIAGNOSE의 책임). 해시 불일치(외부 변경 개입)면 자동 복원을 멈추고 사용자에게 보고한다. **종합 비교는 동일 채점 기반일 때만 기계적으로 적용한다** — 채점 방식이 라운드 간 바뀌었거나(예: Agent 단독 → Workflow fan-out), 하락 기여분이 '이번 라운드 diff와 무관하게 이전부터 존재한 결함의 신규 발견'으로 확인되면(라운드 백업 대비 grep 검증), main이 KEEP|ROLLBACK을 근거와 함께 판정하고 `.refine.log`에 `[keep-override]`/`[rollback]` 마커로 남긴다. **reviewer 호출이 실패해 그 라운드에 `[unverified-carryover]`가 기록된 경우는 keep-override 판정 자체가 불가하다** — carryover가 해소되기 전까지는 다음 SCORE가 상승해도 그 라운드를 KEEP으로 확정 기록하지 않고 `.refine.log`에 `KEEP [unverified-carryover]`로 잠정 표기한다.

---

## code 모드 특별 규칙

**⛔ code 모드도 라운드 루프(Step 0→SCORE→DIAGNOSE→PROPOSE→APPLY) 밖에서 진행하지 마라.** "설계 문서를 읽었으니 바로 구현 시작"은 SCORE/DIAGNOSE를 건너뛰는 절차 위반이다 — 미구현 상태의 SCORE·DIAGNOSE(대개 Correctness Q2=0, `## code 모드 특별 규칙` spec AC 게이트)부터 정식으로 거치고, PROPOSE에서 LEDGER 초안경로 행을 채워 실제 코드 작성을 sonnet 워커에게 위임한 뒤 그 산출물을 APPLY에서 Edit/Write로 반영한다.

- 테스트 통과율 < 100% → 종합 상한 60.
- **spec AC 게이트**: spec/test/design 문서가 있으면, spec에 명시적으로 제외 표기된 AC(별도 마일스톤·외부 의존 대기 등)를 제외하고 미구현 AC가 1건이라도 있으면 Correctness Q2=0.
- **spec gap 모드**: 마일스톤 완료 + AC 미구현 → 기능별 구현 루프 (많은 AC 순). 구현 후 품질 폴리싱.
- **마일스톤 모드**: 미완료 마일스톤 → branch별 구현 + refine 루프 → merge.
- lint/formatter: 매 APPLY 후 실행.

### TDD 변형 (`--tdd` | 자동 판정)

**자동 판정**: code 모드 Step 0에서 설계 정보를 탐지한다 — 우선순위: doc:test 산출물(테스트 설계 doc) > spec > design. 판정 근거는 순서대로 확인한다: (a) 진행 중인 자연 시퀀스 run이면 그 run의 STATUS.md(`## 산출물 위치 & STATUS.md` 위치 규칙 — 공유 디렉토리의 파일별 분리 포함)에 해당 단계 완료 기록, (b) `docs/{test,spec,design}.md` 실존, (c) cwd 이하 Glob으로 설계 문서 탐색(다중 매칭은 DOC_PATH tie-break 준용). 셋 다 없으면 OFF. `--tdd`/`--no-tdd` 명시가 자동 판정보다 우선한다. 판정 결과는 TOOL_CHECK와 함께 출력한다:
```
TDD_MODE: ON (원천: {경로}) | OFF (설계 정보 없음) | ON|OFF (--tdd/--no-tdd 명시)
```

**사이클 — TDD ON 라운드의 APPLY는 항목마다 이 순서를 강제한다**:
1. **red** — 실패 테스트를 먼저 작성하고(작성 실무는 sonnet 워커 — `## 오케스트레이션 & 모델 정책`) **실행해서 실패를 확인**한다. red 원천 우선순위: doc:test 항목 > spec AC > design 계약 > 버그 재현. **범위 판정은 spec이 우선한다** — spec이 명시적으로 제외한 AC는 doc:test에 항목이 남아 있어도 red 대상이 아니다. 원천이 없는 항목(순수 리팩토링)은 red를 생략하고 기존 테스트 green 유지 확인으로 대체한다.
2. **green** — 그 테스트를 통과시키는 최소 구현.
3. **refactor** — 동작 유지 정리(Simplicity 차원이 채점) 후 전체 테스트 통과 유지 확인.

**⛔ TDD ON 라운드는 APPLY의 red→green→refactor 완료 직후 `## ROUND LEDGER`의 TDD 행을 채운다 (생략 시 그 라운드 APPLY 무효 — 형식·실패 표기는 그 섹션 참조).**

- mutation sanity와의 관계: red의 "구현 전 실패 확인"이 신규 테스트의 mutation check를 대체한다. 기존 테스트를 강화한 항목은 기존 mutation 규칙(APPLY 5b)을 그대로 따른다.
- 간단한 수정: 설계 정보가 있어 자동 ON이면 `--mode code` 단일 실행에서 사이클이 작게 돈다(버그 재현 실패 테스트 1개 → 수정 → 통과). 설계 정보가 없는 순수 버그 수정에서 TDD를 원하면 `--tdd`를 명시한다(자동 판정은 OFF를 내린다). doc:test 선생성이 필요한 풀 TDD 스택은 신규 기능 전용이다.
- test 단계와의 관계: **test 모드는 그대로 유지된다.** `해당없음` 처리 조건은 정확히: TDD ON인 code 단계의 **마지막 라운드에서 `STATE-MACHINE / FAILURE-MODE 열거`(`## test 모드 특별 규칙`의 절차 준용)를 직접 수행해 NONE 0건을 확인**한 경우. 열거표를 만들지 않았거나 NONE이 있으면 test 단계는 정상 실행한다 — 표 없이 "문제없다"고 가정한 건너뛰기 금지. TDD OFF면 기존대로 test 단계가 돈다.

## test 모드 특별 규칙

- 소스 코드 변경 금지. 테스트 코드만 추가/수정.
- spec AC 대조 필수 → 미커버 AC에 테스트 작성.
- APPLY = 테스트 코드 작성 + test-map.md 동기화.
- 구현 안 된 기능은 테스트 불가 → 건너뜀.

### State-Machine / Failure-Mode 열거 (SCORE 전 필수 — 생략 시 라운드 SCORE 무효)

spec AC는 분모의 일부일 뿐이다. 대상 코드가 **상태를 갖는 경우**(conflict/충돌 resolver, 동기화·재시도·수렴 루프, baseline/snapshot/source_description 갱신, 외부 시스템 write 후 진행 분기) 다음을 **코드에서 직접** 도출해 SCORE 출력 위에 노출한다:

1. **상태·전이 매트릭스**: 대상의 분기(if/except/early-return/상태 필드 갱신)를 읽어 (진입 상태 × 트리거 × 해소 경로 × 결과 상태)를 표로 만든다. spec에 enumerate되지 않은 전이도 코드에 있으면 모두 포함한다.
2. **Failure-mode 목록**: 각 경로에 대해 '깨지면 조용히 잘못된 결과를 내는' 실패 양식을 적는다 (예: stale snapshot을 거부 대신 덮어씀 / 수렴해도 닫히지 않음 / 동시 pending 직렬화 실패 / 외부 write 실패 시 baseline을 잘못 전진 / 같은 트리거가 happy-path와 abort-path로 갈리는데 happy만 또는 abort만 테스트됨).
3. **커버 대조표**: 각 (전이, failure-mode)에 매핑되는 기존 테스트를 적는다. 없으면 `NONE`.

```
━━━ STATE-MACHINE / FAILURE-MODE 열거 ━━━
상태·전이: {진입→트리거→경로→결과} × N
Failure-mode: {경로 → 조용한-오작동 양식} × M
커버 대조: {(전이|mode) → 테스트명 또는 NONE} × (N+M)
```

이 표의 `NONE`은 다음 라운드 DIAGNOSE의 1급 입력이며 `Failure-Mode Coverage` 차원(refine-modes.md `## test`)으로 집계한다.

## integrate 모드 특별 규칙

- Integration 테스트 작성 게이트: 테스트 설계 doc(doc:test 산출물)의 integration 계층 항목 확인 → 0건이면 SCORE 전에 먼저 작성.
- 통과율 = 단위 + 통합. 통합 0건이면 TestPass 상한 85.
- **Fault-Injection 근거 필수**: Error Resilience / Data Flow 점수는 '재시도/타임아웃/에러전달 코드가 보인다'(정적 읽기)로 매기지 않는다. 각 실패 양식(외부 호출 예외·부분 실패·정책 차단·값 divergence·환경별 분기)에 대해 **그 분기를 실제로 구동하는 테스트**(mock에 예외 side_effect·divergent 반환·non-prod policy 주입)가 있어야 한다. 근거 테스트가 없는 실패 양식은 해당 항목 상한 60.
- **분기 비대칭 게이트**: 같은 진입점이 happy-path와 실패-path로 갈리는데 한쪽만 테스트되면(예: write 성공 경로 없이 abort 경로만, 또는 그 반대), Data Flow 상한 65 + DIAGNOSE 1급 항목.
- **진입점 커버**: e2e 흐름은 실제 진입점(라우트/standalone orchestrator)을 통해 검증한다. helper를 직접 호출해 진입점 배선을 우회한 테스트만 있으면 Data Flow 상한 70.

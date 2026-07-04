---
description: /refine 보조 파일 — 라운드 스텝별 상세 절차 (직접 호출용 아님, refine.md가 매 라운드 Read)
---

# /refine 스텝별 절차

**⚠ 이 파일은 매 라운드 시작 시 Read로 다시 로드된다. main thread가 이 절차를 건너뛰거나 축약하면 규칙 위반이다.** 라운드 시작 출력에는 반드시 `ROUND_CHECK`를 포함해 재독 사실(lines + mtime/stat 값)을 관측 가능하게 남긴다 — 생략 시 그 라운드 SCORE 무효.

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
   # PR/라운드 diff가 대상이면 (선호):
   git diff <base>...HEAD -- <paths> > /tmp/refine_ctx_${RUN}.diff
   # 전체 파일 평가가 필요하면:
   for f in <대상 파일들>; do echo "=== $f ==="; cat "$f"; done > /tmp/refine_ctx_${RUN}.txt
   ```
   아래 문서의 `/tmp/refine_ctx.*`·`/tmp/codex_prenotes.md`·`/tmp/codex_audit.md` 표기는 모두 **이 RUN 을 끼운 실제 경로의 줄임 템플릿**이다(예: `/tmp/codex_prenotes_${RUN}.md`).

2. **모드별 codex task를 병렬 발사** — 모두 background. 각 task는 산출물을 `/tmp/`에 파일로 남긴다:

   | task | 적용 모드 | 산출물 | 지시 요약 |
   |------|----------|--------|----------|
   | `codex-prep` | **모든 모드** | `/tmp/codex_prenotes_${RUN}.md` | 대상(`/tmp/refine_ctx_${RUN}.*`)을 정독하고 분석 노트 작성: 구성요소별 책임 1줄, 핵심 데이터/제어 흐름, 의존 관계, 의심 지점(버그 후보·중복·dead code·모호 표현) 목록. |
   | `codex-audit` | **doc:\* 만** | `/tmp/codex_audit_${RUN}.md` | 아래 `## doc:* 사전 audit`의 Audit 1·2·3(구조 audit + contract/stale-term audit + Missing-Info / Back-Question 도출)을 미리 수행: 섹션 맵, 1급 개념→owning section, 고아/중복, reader path, 활성/제거 용어, stale leak, 구현 함정 5개 카테고리 스캔, 개념·섹션별 누락 정보→역질문(back-question) 도출 및 blocking/non-blocking/out-of-scope 분류. |
   | `codex-scout` | **code/integrate 만** | `codex-prep` 노트에 통합 | 베이스라인 테스트/lint와 병렬로 잠재 결함(경계 미처리·N+1·예외 누락·dead branch)을 추가 스캔. 별도 task로 분리하지 말고 `codex-prep` 지시에 합쳐 1개 task로 발사한다. |

   발사는 사용자 CLAUDE.md의 Codex 경로 규칙을 따른다. **`--background`로 발사해야 비동기로 돈다** — codex `task`는 `--wait` 사용이 가능하지만 foreground 대기 모드라 PREP에서는 main을 멈춘다. 비동기 PREP/phase 호출은 `--background`를 사용하고, foreground 대기가 필요한 예외 상황에서만 `--wait`를 쓴다:
   ```bash
   CODEX_SCRIPT=$(ls -1d $HOME/.claude/plugins/cache/openai-codex/codex/*/scripts/codex-companion.mjs 2>/dev/null | tail -1)
   rm -f /tmp/codex_prenotes_${RUN}.md /tmp/codex_audit_${RUN}.md   # ### 결과 파일 규칙: 발사 전 이 run 노트만 제거(stale 방지). ⛔ 와일드카드·고정명 rm 금지 — 다른 세션 산출물을 지운다.
   # 모드별로 위 표의 지시 + 컨텍스트 파일 경로를 인라인해 task당 1회 발사 (--write: /tmp 노트 작성 권한).
   # task별로 OUTFILE 을 분리한다: codex-prep → /tmp/codex_prenotes_${RUN}.md, codex-audit → /tmp/codex_audit_${RUN}.md.
   # 프롬프트에 "결과를 정확히 <그 task의 OUTFILE> 에 Bash 로 기록하고 wc -l 로 확인" 을 명시한다:
   PREP_OUT=/tmp/codex_prenotes_${RUN}.md   # codex-audit 발사 시엔 AUDIT_OUT=/tmp/codex_audit_${RUN}.md 로 바꿔 박는다
   node "$CODEX_SCRIPT" task --background --write "<지시 + /tmp/refine_ctx_${RUN}.* 경로 + '결과를 $PREP_OUT 에 기록'>" 2>/dev/null || true
   ```
   발사 명령의 **stdout에서 task ID를 직접 캡처**한다 (`Codex Task started in the background as <task-id>` 형식). `status --all`로 찾으면 동시 발사한 codex-prep/codex-audit/이전 task가 섞여 혼동되므로 쓰지 않는다. 캡처한 ID를 role에 매핑(`PREP_PREP_ID`, `PREP_AUDIT_ID`)한 뒤, 아래 `## Codex CLI job 호출 공통 규칙`의 polling 루프를 **task별 1개씩 `run_in_background` Bash로** 띄운다. **단 PREP polling은 공통 규칙과 한 가지가 다르다: `completed` AND 그 task의 노트가 비어있지 않을 때만 성공으로 본다** — 검사 파일은 task별로 다르다(codex-prep → `[ -s /tmp/codex_prenotes_${RUN}.md ]`, codex-audit → `[ -s /tmp/codex_audit_${RUN}.md ]`. 두 task에 같은 파일을 검사하지 마라). `completed`라도 그 노트가 비었거나(빈 결과) `failed|cancelled|timeout`이면 **그 task의 산출물만** 삭제하고(codex-prep → `/tmp/codex_prenotes_${RUN}.md`, codex-audit → `/tmp/codex_audit_${RUN}.md`. 와일드카드·고정명으로 다른 task·다른 세션 노트를 지우지 마라) 그 task를 unavailable/fallback으로 마킹한다 (실패·빈 노트를 정상처럼 재사용 금지). 그런 다음 main은 기다리지 말고 Step 0의 나머지와 첫 SCORE로 진행한다.

   **⛔ PREP_CHECK — 첫 SCORE의 PHASE1 진입 전 반드시 출력 (생략 시 절차 위반):**
   ```
   PREP_CHECK:
   ☑ codex-prep 결과: launched ({task-id})
   ☐ codex-prep 실패: unavailable (Codex 미설치|$CODEX_SCRIPT 빈값) | spawn_failed ({사유})
   ☑ codex-audit 결과: launched ({task-id}) | N/A (non-doc 모드)
   ☐ codex-audit 실패: unavailable (Codex 미설치|$CODEX_SCRIPT 빈값) | spawn_failed ({사유})
   ```
   줄 형식 계약: 각 역할은 실제 상태에 맞는 **한 줄만** 출력한다. 성공·N/A는 `☑ <역할> 결과: <상태>`, 실패는 `☐ <역할> 실패: <사유>`를 쓴다. `unavailable`/`spawn_failed`여도 `PREP_CHECK` 블록은 생략하지 말고 fallback(아래 분기)으로 진행한다. polling 결과(`completed`/실패)는 SCORE 재사용 시점에 다시 확인한다.

3. **재사용**: SCORE 시작 시점에 PREP task가 `completed`로 끝나 노트가 유효하면(failed/cancelled 산출물은 이미 폐기됨), 이후 **모든 codex 호출(scorer/proposer/verifier/reviewer, 전 라운드)** 프롬프트 맨 앞에 붙인다:
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

> ⛔ **codex 역할(codex-scorer/codex-proposer/codex-verifier/codex-reviewer)을 팀 멤버 Agent로 스폰하지 마라.** `codex:codex-rescue`의 도구는 `Bash` 전용 → `SendMessage`가 없어 `shutdown_request`에 `shutdown_response`로 답할 수 없다 → **shutdown으로 종료되지 않는다**. 팀 멤버로 띄우면 "종료 요청 확인" 텍스트만 남기고 매 라운드 idle 멤버로 영구 잔존한다(실측 확인). **codex는 PREP과 동일하게 CLI job(`node $CODEX_SCRIPT task --background`)으로만 호출**하고, 진행은 `status <task_id>` polling으로 추적하고 결과는 발사 시 지시한 `/tmp/*.md` 파일을 읽어 수집한다(아래 `## Codex CLI job 호출 공통 규칙` — ⛔ `result <task_id>`는 요약일 뿐이라 결과 수집에 쓰지 않는다). CLI job은 팀 멤버가 아니므로 잔존하지 않으며 `completed`/`cancel`로 즉시 정리된다.

- **general-purpose 멤버 (long-lived)**: **Round 1에만** `Agent({ name, subagent_type, model, prompt })`로 스폰한다(`team_name` 불필요 — 무시됨. `model`은 `## 오케스트레이션 & 모델 정책` 표: claude-scorer=sonnet, cross-reviewer=opus). **Round 2+에는 재스폰하지 말고** `SendMessage({ to: "claude-scorer", summary: "<5-10단어 요약>", message: "Round N delta 채점: ..." })`로 깨운다 (string message에는 `summary`가 **필수**다). 완료된 멤버도 메시지를 받으면 이전 점수·근거 context를 유지한 채 delta 채점한다.
- **codex 역할 (CLI job, 팀 멤버 아님)**: `node $CODEX_SCRIPT task --background --write "<지시 + 결과를 /tmp/refine_<role>_r{N}_${RUN}.md 에 기록하라>"`로 호출하고, stdout의 task-id를 캡처 → `## Codex CLI job 호출 공통 규칙`의 polling → 완료 시 `/tmp/refine_<role>_r{N}_${RUN}.md`를 읽어 수집한다(파일명은 `### 결과 파일 규칙`의 role·round·run 유니크 규칙을 따른다). 매 호출이 독립 job이라 "재스폰/재사용" 개념이 없고, `completed`/`cancel`이면 잔존하지 않는다. ⛔ `Agent({subagent_type:"codex:codex-rescue"})`로 팀에 넣지 마라(종료 불가 → 영구 잔존).
- **Codex 미설치/spawn 실패**: codex CLI job을 발사하지 않고 해당 phase의 `*_CHECK`에 `☐ codex-<role> 미설치/spawn 실패`로 표기한다 (공통 규칙 `### 즉시 실패`). 이는 "호출 안 함=절차 위반"이 아니라 **환경상 호출 불가로 허용**되며, claude 멤버만으로 진행한다.

### 멤버 timeout & 강제 정리 (codex job과 동일한 30분 cap)
멤버가 hang/무응답이어도 라운드가 멈추지 않도록, codex job timeout(30분)과 **같은 30분 cap**을 멤버 agent에도 적용한다. (config.json에는 멤버 liveness 필드가 없어 — 등록부일 뿐 — "살아있는지"를 파일로 판단할 수 없다. 아래 신호로 판단한다.)

- **작업(assignment)당 단일 30분 deadline (이중 대기 금지)**: 각 멤버에게 **새 작업을 줄 때마다(라운드별 채점 등)** `DEADLINE = 시작+1800s` **하나**를 기록한다. **한 작업 안에서는** 그 멤버의 codex job polling도 새 `start`를 잡지 말고 이 deadline을 물려받아 남은 시간만 쓴다 — 멤버 cap(30분)과 codex job cap(30분)이 직렬로 겹쳐 최대 60분이 되는 것을 막는다. **다음 라운드에 같은 멤버를 다시 깨우면(SendMessage) 그 시점에 deadline을 새로 잡는다** — 직전 라운드의 만료된 deadline을 물려받지 않는다.
- **stale 판단 신호** (⚠️ active 플래그를 믿지 마라 — "멈췄는데 active로 표시"되는 좀비가 실재한다): ① idle/완료 메시지 push 수신 여부, ② **codex job log 파일(`status`의 `Log:` 경로) mtime + `status`의 Phase/Elapsed가 갱신되는가** — ~30초 간격 2회 확인해 갱신이면 진짜 작업 중, **정지면 멈춤(좀비)** (polling 템플릿의 liveness probe가 이 검사를 자동 수행해 300초 무변화 시 `STALLED`로 조기 종결한다), ③ 작업 부여 후 **30분 무신호**. ②의 progress 정지 또는 ③이면 stale로 판정한다.
- **codex CLI job**: `status <task_id>` polling의 30분 cap이 1차 안전장치 — timeout 시 `cancel` + `☐ codex-<role> 호출 실패 (30분 timeout)` 표기(공통 규칙). CLI job은 팀 멤버가 아니라 팀 메시징을 쓰지 않으므로(아래 *결과 수집* 참고), liveness는 polling 결과(`status` Phase/Elapsed + log mtime)로만 판단한다.
- **멤버 agent 무응답(30분)** → stale 판정 시:
  1. `SendMessage({ to: "<name>", message: { type: "shutdown_request", reason: "30분 timeout" } })`로 강제 종료 시도.
  2. 그래도 신호가 없으면 그 멤버를 **포기**한다 — 그 멤버 결과는 빼고 살아있는 나머지 멤버(claude/codex)로 라운드를 진행하고 `.refine.log`에 `[member-timeout] member=<name> round=<N>` 기록. harness는 멤버 강제 kill API를 제공하지 않으므로 "포기 후 진행"이 강제 정리의 현실적 상한이다 (잔존 멤버는 세션 종료 시 자동 정리). **단 ⛔ `claude-scorer`마저 포기돼 살아있는 채점 Agent가 0개면 그 라운드 SCORE는 무효다** — main이 직접 채점하지 않는다("main thread 단독 채점 금지" hard constraint). 다음 라운드에서 재스폰으로 재시도한다.

> *결과 수집*:
> - **general-purpose(claude-scorer/cross-reviewer) = 팀 멤버**: SendMessage 도구가 있어 **결과를 SendMessage로 main에 반환**한다(자동 delivery). 완료 시 결과 없이 `idle_notification`만 오면, 그 멤버에 "채점 결과를 메시지로 보고하라"고 SendMessage해 회수한다.
> - **codex = CLI job (팀 멤버 아님)**: 도구가 `Bash`뿐이라 SendMessage가 불가하므로 **애초에 팀 멤버로 만들지 않는다**. 진행은 `status <task_id>` polling으로 추적하고, 결과는 발사 시 지시한 `/tmp/refine_<role>_r{N}_${RUN}.md` 파일을 읽어 수집한다(팀 메시징으로 대체 불가, 실측 확인. ⛔ `result <task_id>`는 요약 stdout일 뿐이라 결과 수집에 쓰지 않는다 — `### 결과 파일 규칙` 참조).

### 종료 (refine 완료 / MAX_ROUNDS / TARGET 도달)
```
1. codex CLI job(PREP/scorer/proposer/verifier/reviewer): 진행 중인 `status <task_id>` polling이 끝났는지 확인 — 미완료면 `cancel` (CLI job은 shutdown_request 대상이 아니다 — `cancel`로 종결·잔존 없음).
2. claude 멤버(claude-scorer/cross-reviewer)는 결과 반환 후 **세션 종료 시 자동 정리**된다 — 팀이 implicit이라 `TeamDelete`가 없고(v2.1.178+에서 제거됨), `shutdown_request`는 legacy이므로 직접 보내지 않는다.
3. 라운드 도중 멈춰야 할 좀비 멤버가 있을 때만 예외적으로 `SendMessage({ to: "<name>", message: { type: "shutdown_request", reason: "..." } })`로 종료를 시도한다 (무한 대기 금지, 30분 cap; 미응답이면 포기).
```

codex CLI job(PREP/scorer/proposer/verifier/reviewer)은 Agent 도구가 아닌 `node $CODEX_SCRIPT` 직접 호출이라 팀 멤버가 아니다 — 위 1번에서 미완료 시 `cancel`로 정리한다 (shutdown_request 대상 아님). implicit 팀과 그 task 디렉토리는 **세션 종료 시 자동 정리**되므로 `TeamDelete`나 수동 force-rm이 필요 없다. ⛔ `~/.claude/teams/`·`~/.claude/tasks/`를 `rm`으로 지우지 마라 — 다른 세션이 쓰는 중일 수 있다.

---

## 오케스트레이션 & 모델 정책

### 모델 정책

**계층 원칙 (allowlist)** — 모델은 역할 계층으로 배정한다:
- **전체 ultracode 오케스트레이션 총괄 = main (세션 모델, fable/opus급)**: 루프 관장·발사·수집·PROPOSE_COMPARE 채택·audit cap 보정·KEEP/ROLLBACK 판정·로그/STATUS 기록·사용자 소통. main은 관리자이며 실무 작성(창작)을 직접 수행하지 않는다.
- **sub-project(단계·판정 단위) 관리 = opus**: cross-reviewer(교차 판정), Workflow 합의(consensus). 루프 내 판정(부트스트랩 선택·PROPOSE_COMPARE 채택 등)은 main의 관리 영역이다(`### main 단독 판단의 경계`).
- **실제 작성·채점 실무 = 정확히 sonnet / 단순 반복·기계적 검사 = 정확히 haiku**: 수정안 초안·코드 구현·테스트 코드·부트스트랩 초안 작성과 차원별 채점은 sonnet, 경로 실존·stale grep 같은 결정적 반복은 haiku.

여기서 '실무 작성'은 산출물의 **창작**(문서 초안·코드·테스트·수정안·audit 분석)을 뜻한다. 도구 실행(컨텍스트 패키징 cat/diff·Edit 반영·로그/STATUS 기록)은 main의 관리 업무에 속한다.

Agent 스폰은 `model` 옵션만, Workflow `agent()`는 `model`+`effort`를 받는다. codex CLI job은 모델 지정 대상이 아니다(자체 고정). 사용자 `--model-policy '역할=모델'`이 표보다 우선한다. `--model-policy`를 같은 역할에 반복 지정하면 **가장 오른쪽 지정이 최종값**이다(예: `--model-policy '차원별 scorer=haiku' --model-policy '차원별 scorer=sonnet'` → `차원별 scorer=sonnet` — 역할명은 아래 표의 정식 명칭 사용).

Agent 스폰 역할:

| 역할 | model | 계층 |
|------|-------|------|
| claude-scorer | sonnet | 실무 — 루브릭 적용 채점 |
| cross-reviewer | opus | sub-project 관리 — 두 채점 보고 비교 판정 |
| 부트스트랩 생성자(claude 측) | sonnet | 실무 — 초안 작성 (선택 판정은 main) |
| 실무 작성 워커(PROPOSE 초안·code 구현·테스트 코드) | sonnet | 실무 — main은 검수·통합만 |

Workflow `agent()` 역할:

| 역할 | model | effort | 계층 |
|------|-------|--------|------|
| 차원별 scorer | sonnet | high (code·test 모드: xhigh) | 실무 — fan-out 채점 (대형·복잡 대상의 품질 교정은 consensus(opus)가 담당) |
| 약점별 proposer | sonnet | high (code·test 모드: xhigh) | 실무 — PROPOSE fan-out 수정안 초안 (컨센서스 불필요, 조율은 PROPOSE Step 2·2b) |
| 합의(consensus) | opus | high | sub-project 관리 — cap 적용·과대평가 교정 |
| 기계적 스캔(경로 실존·stale grep) | haiku | 미지정(생략) | 단순 반복 — 결정적 검사 (Haiku 4.5는 `effort` 파라미터 자체가 에러 대상이라 옵션에서 제외한다) |

### main 단독 판단의 경계 (allowlist)

main 단독 금지의 범위는 정확히 **'점수 생성'**이다. 다음은 main의 판단 영역이다(단독 수행 허용): PROPOSE 비교 채택(PROPOSE_COMPARE), 부트스트랩 선택(사용자 무응답 시), audit cap 보정, codex 실패 시 fallback 결정.

### Workflow(ultracode) 오케스트레이션

`ultracode`는 Claude Code Workflow 런타임(`phase`/`parallel`/`agent()` DSL)을 가리키는 내부 별칭이며, 별도 팀 멤버나 Codex CLI job 이름이 아니다.

Workflow 도구가 세션에 존재하면 SCORE Phase 1의 **claude 측 채점**을 Workflow로 fan-out한다 — 이 스킬 지시가 곧 Workflow 사용 opt-in이다. codex-scorer CLI job은 Workflow 밖에서 main이 기존 규칙대로 병렬 발사한다.

- fallback(allowlist): Workflow 도구 부재, 또는 스크립트 오류 2회 → named Agent(claude-scorer) 경로로 전환.
- 용어 동기화: 이후 절차의 "claude 측 채점"은 두 경로를 통칭한다. PHASE1_CHECK 표기 — Agent 경로 `☑ claude 측 채점(claude-scorer) 결과: ...`, Workflow 경로 `☑ claude 측 채점(workflow) 결과: ...`.
- delta 채점: Agent 경로는 SendMessage 재사용(context 유지), Workflow 경로는 `args.priorScores`로 이전 점수를 넘겨 변경 영향 차원만 재채점.
- Workflow의 consensus 결과는 codex-scorer 결과와 함께 Phase 2(cross-reviewer)에 입력된다 — Workflow가 cross-reviewer를 대체하지 않는다(이종 채점자 간 교차 검증).
- 어휘 정리: Workflow `agent()`의 `label`은 Workflow 내부 trace/로그용 식별자이고 `SendMessage` 대상이 아니다. `Agent({ name })`의 `name`은 라운드 간 재사용·메시징을 위한 세션 전역 주소다. `label: "score:Correctness"`와 `name: "claude-scorer"`는 같은 네임스페이스가 아니며 서로 대체하지 않는다.

복붙 템플릿 (차원 테이블·이전 점수·audit 요약은 args로 주입):

```js
export const meta = {
  name: 'refine-score',
  description: 'refine SCORE: 차원별 병렬 채점 + 합의',
  phases: [{ title: 'Score' }, { title: 'Consensus' }],
}
// args: { docPaths: [...], mode: 'doc:skill', dimensions: [{name, weight, criteria, special}...], priorScores: {...}|null, auditSummary: '...' }
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
phase('Consensus')
const consensus = await agent(
  `차원별 채점 결과를 검토해 과대평가를 지적하고 종합하라. audit 요약: ${A.auditSummary}
   audit cap 규칙(refine-modes.md 공통 규칙 표)을 적용해 차원별 최종 점수와 가중평균을 산출하라.
   입력: ${JSON.stringify(scores.filter(Boolean))} / 가중치: ${JSON.stringify(A.dimensions.map(d=>({name:d.name,weight:d.weight})))}`,
  { label: 'consensus', phase: 'Consensus', model: 'opus', effort: 'high',
    schema: { type:'object', required:['final','total'], properties:{ final:{type:'object'}, total:{type:'number'}, capsApplied:{type:'array', items:{type:'string'}} } } })
return { perDimension: scores.filter(Boolean), consensus }
```

PROPOSE 단계의 claude 측 초안도 같은 방식으로 항목별 fan-out할 수 있다 — 단, 각 항목은 이미 완결된 수정안이라 SCORE의 opus Consensus 단계를 이식하지 않는다(항목 간 조율은 PROPOSE 절차의 Step 2·2b가 담당):

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

---

## Codex CLI job 호출 공통 규칙 (⏱ 30분 timeout)

codex 역할(codex-scorer / codex-proposer / codex-verifier / codex-reviewer)은 **CLI job으로 호출한다** — `node $CODEX_SCRIPT task --background`, 팀 멤버 Agent가 **아니다**(`codex:codex-rescue`는 Bash 전용이라 팀에 넣으면 shutdown 불가로 잔존). 호출 시 **반드시** 아래 timeout 가드를 적용한다 — codex 가 hang/loop 에 빠지면 라운드가 무한정 멈추기 때문이다.

### ⚡ 속도 규칙 1 — 컨텍스트 인라인 패키징 (PREP 노트가 없을 때의 fallback)

**codex에 파일 경로 목록만 주지 마라.** 호출 전에 main이 대상을 묶어 프롬프트에 인라인으로 박아준다:

```bash
: "${RUN:=$(date +%s)$$}"   # Step 0 PREP 1번에서 잡은 run 토큰 재사용. 단독 실행이면 여기서 할당(빈 ${RUN} 방지).
# <base> 결정: PR 브랜치면 git merge-base HEAD <기본 브랜치(main→develop 순 존재 확인)>. PR이 아니면 라운드 시작 시점 HEAD 고정. non-git이면 아래 전체 파일 패키징.
# 채점/리뷰 대상이 PR/라운드 diff면 (선호) — working tree가 dirty(미커밋 변경 포함)면 three-dot 대신 two-dot(working tree 포함):
if [ -n "$(git status --porcelain -- <paths>)" ]; then
  git diff <base> -- <paths> > /tmp/refine_ctx_${RUN}.diff        # dirty tree 포함(two-dot)
else
  git diff <base>...HEAD -- <paths> > /tmp/refine_ctx_${RUN}.diff # 커밋된 변경만(three-dot)
fi
# 전체 파일 평가가 필요하면:
for f in <files>; do echo "=== $f ==="; cat "$f"; done > /tmp/refine_ctx_${RUN}.txt
```

프롬프트에 "대상 코드는 아래에 전문 포함되어 있다 — 파일 탐색 없이 바로 평가하라" + 내용 첨부. 프롬프트가 과대해지면(>150KB) 핵심 파일만 인라인하고 나머지는 경로로.

### ⚡ 속도 규칙 2 — Round 2+ delta 채점

Round 2부터 codex-scorer에게 전체 재채점을 시키지 않는다. "이전 라운드 차원별 점수 + 이번 라운드에 적용된 diff"를 주고 **변경이 영향을 주는 차원만 재채점**, 나머지는 이전 점수 유지로 지시한다. claude-scorer도 동일. **delta 재요청 메시지에는 모드·라운드를 명시**한다 — 안 그러면 claude-scorer 가 직전 라운드 보고를 그대로 재전송하는 혼동이 생긴다(실측). 결과 미수신 시 모드·라운드를 못 박아 1회 재요청한다.

### ⚡ 결과 파일 규칙 — stale·빈 결과 방지 (⛔ 모든 codex CLI 호출 필수)

`/tmp` 결과 파일은 **세션·라운드 간 공유**라 이전 실행 잔여 파일을 현재 결과로 오인하면 채점이 오염된다(실측: 이전 세션 score 파일을 현재 라운드 codex 결과로 읽어 cross-reviewer 가 불일치 플래그를 띄움).

1. **유니크 파일명**: OUTFILE 은 role·라운드 **그리고 run(`${RUN}`)** 으로 유니크하게 — `/tmp/refine_<role>_r{N}_${RUN}.md` (예 `/tmp/refine_codex-scorer_r2_${RUN}.md`). `RUN` 은 `## Step 0 PREP` 1번에서 잡은 토큰(미설정 시 `RUN="$(date +%s)$$"`). role·round 만으로는 **동시 실행되는 다른 refine 세션**이 같은 role·round 에서 충돌하므로 run 토큰을 끼운다. `codex_score_r1.md` 처럼 고정·세션 간 충돌 이름은 쓰지 마라.
2. **발사 직전 `rm -f "$OUTFILE"`**: 잔여 파일 제거 후 launch. 그래야 completed 시점의 non-empty 가 "이번 호출이 새로 썼다"를 보장한다.
3. **completed 후 `[ -s "$OUTFILE" ]` 검증**: 위 polling 루프가 수행 — 비었으면 빈 결과(실패)로 처리(`### 절차` 4번).
4. **프롬프트에 절대경로 명시**: codex 에게 "결과를 정확히 `<OUTFILE 절대경로>` 에 Bash 로 기록하고 `wc -l` 로 확인하라"고 지시. PREP 의 `/tmp/codex_prenotes_${RUN}.md` 도 동일 — 발사 전 그 run 파일만 `rm -f`, 완료 후 non-empty 확인(비면 PREP unavailable 처리, fallback 으로 진행).

### 절차

1. Agent 스폰(또는 라운드별 재호출) 직후 main 이 **그 작업의 단일 deadline 기록**: `DEADLINE_TS=$(( $(date +%s) + 1800 ))`. **한 작업(라운드) 안에서는** 그 멤버의 codex polling이 새 start를 잡지 않고 이 deadline을 공유한다 — 멤버 cap과 polling cap이 직렬로 겹쳐 60분이 되는 것을 막는다. **다음 라운드 재호출 시에는 새 `DEADLINE_TS`를 잡는다**(만료된 deadline 물려받기 금지).
2. codex-rescue 러너는 codex CLI 에 background job 으로 작업을 forward 한다. task ID(`task-mpXXXXXX-XXXXX`)는 **가능하면 spawn 결과(stdout)의 `started in the background as <task-id>`에서 직접 캡처**한다 (PREP와 동일 원칙). 직접 못 얻을 때만 `node "$CODEX_SCRIPT" status --all` 로 찾되, 동시 발사 시 혼동 위험이 있어 **fallback으로만** 쓴다.
3. main 은 `run_in_background` Bash 로 polling 루프를 띄운다 — **위 `DEADLINE_TS`까지 (기본 30분) cap**:

```bash
CODEX_SCRIPT=$(ls -1d $HOME/.claude/plugins/cache/openai-codex/codex/*/scripts/codex-companion.mjs 2>/dev/null | tail -1)
# ⛔ 이 polling 은 별도 run_in_background Bash 라 부모 셸 변수를 못 본다 — 아래 세 값을 이 명령 안에서 직접 박아 넣어라(부모 셸의 값으로 치환):
TASK_ID="task-XXXX"                              # 캡처한 codex task-id
OUTFILE="/tmp/refine_codex-scorer_r2_${RUN}.md"  # 그 task 발사 시 지시한 결과 파일(발사 직전 rm -f 로 비워둔 것 — 아래 ### 결과 파일 규칙)
DEADLINE_TS=$(( $(date +%s) + 1800 ))            # 멤버 작업 시작 시 정한 단일 deadline(epoch). 한 작업 안에서 멤버 cap과 공유 — 미설정 시에만 now+1800 fallback.
(DEADLINE_TS=${DEADLINE_TS:-$(( $(date +%s) + 1800 ))}
 echo "POLL START $TASK_ID"   # 폴링 생존 마커: output 파일이 이 줄조차 없으면 루프가 시작 못 한 것(폴링 사망과 "아직 조용함"을 구분)
 LOG=$(node "$CODEX_SCRIPT" status "$TASK_ID" 2>&1 | sed -n 's/^  Log: //p' | head -1)   # liveness probe용 job 로그 경로
 _it=0; _last_sig=""; _last_progress=$(date +%s)
 while true; do
   out=$(node "$CODEX_SCRIPT" status "$TASK_ID" 2>&1)
   # status <id> 단일 호출은 dash bullet 형식: "- $TASK_ID | <status> | rescue | Codex Task"
   # status --all 은 표 형식: "| $TASK_ID | rescue | <status> | ..." — 둘 다 매칭되도록 보수적 패턴 사용.
   # ⛔ 느슨한 `grep completed` 금지 — status 출력의 'Command completed: ...' 로그 echo 에 오탐해 codex 가 끝나기 전 completed 로 착각한다(실측 2026-06-16). 반드시 위처럼 task_id 라인 앵커.
   if echo "$out" | grep -E "(^- |^\| )$TASK_ID \|" | grep -qE "\b(completed)\b"; then
     # ⚠️ completed 직후 OUTFILE 이 host /tmp 로 flush 되기까지 수초 지연될 수 있다(실측: codex 가 정상 기록했는데 폴링이 그 전에 [ -s ] false 로 보고 EMPTY 오판→rm→직후 파일 출현). 즉시 EMPTY 판정 말고 grace-retry.
     # ⛔ result 폴백 금지: `result <id>` 는 codex *요약*("Wrote ... wc -l N")일 뿐 --write 파일 내용이 아니다 → 요약을 결과로 오인하면 채점 오염.
     for _i in $(seq 1 15); do [ -s "$OUTFILE" ] && break; sleep 2; done
     if [ -s "$OUTFILE" ]; then echo "=== DONE (file) ==="; else echo "=== EMPTY RESULT — codex 실패 처리 ==="; fi
     break
   fi
   if echo "$out" | grep -E "(^- |^\| )$TASK_ID \|" | grep -qE "\b(failed|cancelled)\b"; then
     echo "=== FAILED/CANCELLED ==="; break
   fi
   # ⚡ file-stable 조기 채택: status 가 completed 로 전이되지 않아도(실측 2026-07-03: 완결 보고 기록 후 25분+ running 잔존)
   #    OUTFILE 이 non-empty 이고 mtime 이 90초+ 정지면 결과가 이미 나온 것으로 보고 조기 break.
   #    main 은 아래 4번의 완결 형식 게이트를 통과할 때만 채택한다 (부분 쓰기 오채택 방지).
   if [ -s "$OUTFILE" ]; then
     _now=$(date +%s); _mt=$(stat -f %m "$OUTFILE" 2>/dev/null || stat -c %Y "$OUTFILE" 2>/dev/null || echo "$_now")
     if [ $(( _now - _mt )) -ge 90 ]; then echo "=== DONE (file-stable, status!=completed) ==="; break; fi
   fi
   # ⚡ liveness probe — "실제 작업 중인가"를 관측한다: Phase 변화·job 로그(size/mtime) 성장·OUTFILE 변화 중
   #    무엇도 300초간 안 변하면 stalled 로 조기 종결(실측 2026-07-03: scorer r2 가 phase 'starting' 23분 정체 → 30분 deadline 전부 낭비. 이 probe 는 5분에 끊는다).
   _sig="$(echo "$out" | sed -n 's/^  Phase: //p')|$(stat -f '%z %m' "$LOG" 2>/dev/null || stat -c '%s %Y' "$LOG" 2>/dev/null)|$(stat -f %m "$OUTFILE" 2>/dev/null || stat -c %Y "$OUTFILE" 2>/dev/null)"
   if [ "$_sig" != "$_last_sig" ]; then _last_sig="$_sig"; _last_progress=$(date +%s); fi
   if [ $(( $(date +%s) - _last_progress )) -ge 300 ] && [ ! -s "$OUTFILE" ]; then
     echo "=== STALLED — cancel (phase/로그/산출물 300s 무변화) ==="; node "$CODEX_SCRIPT" cancel "$TASK_ID"; break
   fi
   # HEARTBEAT(~100초마다): 폴링 output 파일을 Read 하면 진행 이력이 보인다 — "지금 실제로 돌고 있나"의 관측 로그.
   _it=$(( _it + 1 ))
   [ $(( _it % 5 )) -eq 0 ] && echo "HEARTBEAT $(date +%H:%M:%S) phase=$(echo "$out" | sed -n 's/^  Phase: //p') log=$([ -f "$LOG" ] && wc -c < "$LOG" | tr -d ' ' || echo -)B out=$([ -s "$OUTFILE" ] && wc -c < "$OUTFILE" | tr -d ' ' || echo 0)B"
   if [ $(date +%s) -ge $DEADLINE_TS ]; then
     echo "=== DEADLINE TIMEOUT — cancel ==="; node "$CODEX_SCRIPT" cancel "$TASK_ID"; break
   fi
   sleep 20
 done)
```

> ⚠️ **이전 버그 (2026-05-22 수정)**: 이전 패턴 `^\| <id> \|.*\|\s+(completed|...)\s+\|` 은 `status --all` 표 형식만 가정해서 `status <id>` 단일 호출의 dash-bullet 형식 (`- <id> | completed | ...`)을 못 잡았다. 결과적으로 codex 가 1~3분에 끝나도 polling 이 30분 timeout 까지 hang 처럼 멈춰 있었다. 위 패턴은 두 형식 모두 매칭한다.
>
> ⚠️ **이전 버그 (2026-06-16 수정)**: codex `task` 가 `completed` 로 끝나도 OUTFILE 을 안 쓰는 **'빈 결과'** 가 잦았는데(한 run 에서 reviewer/scorer-r2/test-score 3회), polling 이 `completed` 만 보고 DONE 처리해 **무검증/무채점을 "통과"로 착각**했다. 또 고정 `/tmp` 파일명(`codex_score_r1.md` 등)이 **세션 간 stale 충돌**을 일으켜 이전 세션 결과를 현재 라운드로 오인했다(cross-reviewer 가 점수 불일치 플래그). → 수정: (1) OUTFILE 유니크(`/tmp/refine_<role>_r{N}_${RUN}.md`) + 발사 전 `rm -f`, (2) `completed` 후 `[ -s "$OUTFILE" ]` non-empty 검증(비면 EMPTY — ⚠️ 아래 #2 수정으로 `result` stdout 폴백은 **제거**됨), (3) 빈 결과 = codex 실패로 처리(claude 단독 진행, `[codex-empty]` 로그), (4) 같은 phase 2라운드 연속 실패 시 그 codex phase 생략.
>
> ⚠️ **이전 버그 (2026-06-16 #2 수정)**: 위 (2)의 `result` stdout 폴백이 **틀렸다** — `result <id>` 는 codex *요약*("Wrote ... wc -l N")이지 `--write` 파일 내용이 아니라서, 폴백이 요약을 결과로 써 채점을 오염시킨다. 게다가 codex `--write` 는 completed *후* host `/tmp` 로 flush 되기까지 수초 지연이 있어(실측: prep/scorer 가 90/24줄을 정상 기록했는데 폴링이 그 전에 EMPTY 오판→`rm`→직후 파일 출현), 즉시 판정이 valid 결과를 버렸다. 추가로 느슨한 `grep completed` 가 status 의 'Command completed' echo 에 오탐했다. → 수정: task_id 앵커 grep + completed 후 OUTFILE **grace-retry(~30s)** + `result` 폴백 **제거**(위 polling 블록에 반영). (2)의 result-폴백 문구는 이 노트로 대체됨.

4. **결과 분기:** (아래 토큰은 위 polling 루프가 `=== <토큰> ===` 형태로 echo 하는 문자열과 1:1 대응 — grep 시 `=== ===` 래퍼를 감안하라. 루프는 `result` 폴백 분기를 만들지 않는다.)
   - `DONE (file)` → **OUTFILE 을 읽어** 다음 단계 진행 (`result` stdout 이 아니라 OUTFILE 기준 — `[ -s ]` 로 비어있지 않음 확인됨).
   - `EMPTY RESULT — codex 실패 처리` (completed 인데 grace-retry 후에도 OUTFILE 이 빔) → `☐ codex-<role> 호출 실패 (빈 결과)` 표기 후 **claude 단독으로 진행**. ⛔ 빈 codex 결과를 "채점/검증/리뷰했다"로 간주하지 마라(실측: 이 케이스를 completed 로 착각해 무검증 통과한 사례 있음). `.refine.log` 에 `[codex-empty] phase=<role> task=<task_id>` 기록.
   - `FAILED/CANCELLED` → `☐ codex-<role> 호출 실패 (job failed)` 표기 후 claude 단독 진행.
   - `STALLED — cancel` (Phase·job 로그·산출물 300초 무변화, OUTFILE 빈 상태) → **같은 지시로 1회 재발사 허용**: 새 task 를 발사하고 **남은 DEADLINE_TS 를 물려받아** polling 재개 — 새 30분을 잡지 않는다. `.refine.log` 에 `[codex-stalled] phase=<role> task=<task_id>` + 재발사 시 `[codex-relaunch]` 기록. 재발사도 STALLED/실패면 `☐ codex-<role> 실패 (stalled)` 표기 후 claude 단독 진행.
   - `DEADLINE TIMEOUT — cancel` → main 이 OUTFILE 을 확인해 두 갈래로 처리한다. **채택 조건은 정확히: OUTFILE 이 non-empty AND 발사 프롬프트가 요구한 산출 구조를 마지막 항목까지 완결 형식으로 갖춤**(예: scorer=차원별 점수+가중평균 종합, verifier/reviewer=항목 1..N 전부의 PASS|CAVEAT|FAIL). 조건 충족 시 cancel 후에도 그 파일을 결과로 채택하고 `☑ codex-<role> 결과: timeout-kept` 표기 + `.refine.log` 에 `[codex-timeout-kept]` 기록 — 실측(2026-07-03): codex 가 완결 보고를 기록한 뒤 task 마무리만 못 하고 25분+ running 으로 잔존. 조건 미충족(중간 절단·요구 구조 미달)이면 `☐ codex-<role> 호출 실패 (30분 timeout — cancel 됨)` 표기 후 진행.
5. timeout/빈결과/실패/stalled/timeout-채택으로 정리한 경우 `.refine.log` 에 마커 기록 (`[codex-timeout]`/`[codex-empty]`/`[codex-failed]`/`[codex-stalled]`/`[codex-relaunch]`/`[codex-timeout-kept]` + `phase=<scorer|proposer|verifier|reviewer> task=<task_id>`). **verifier/reviewer 역할이 위 사유 중 어느 것으로든 검증/리뷰 없이 진행하게 되면** 같은 로그에 `[unverified-carryover] role=<verifier|reviewer> round=<N> items=<항목 목록>`도 함께 기록한다 — 다음 라운드 `DIAGNOSE`가 이 마커를 1급 약점으로 강제 포함해 codex PASS 확인 전까지 매 라운드 반복한다(`## DIAGNOSE` 참조).
6. **즉석 수동 확인(사용자·main 공용)**: `node "$CODEX_SCRIPT" status <task-id>` 의 Phase·Elapsed 확인 + `tail -20 <status 의 Log: 경로>` — job 로그가 자라고 있으면 실제 작업 중이다. 폴링 output 파일을 Read 하면 HEARTBEAT 이력(phase·로그 크기·산출물 크기 ~100초 간격)으로 진행 추이를 볼 수 있다.
7. **연속 실패 가드**: 같은 phase 의 codex 가 2라운드 연속 `빈 결과/실패`면 그 phase 의 codex 호출을 이후 라운드에서 **생략**하고 claude 단독으로 진행한다(매 라운드 빈 codex 를 기다리느라 낭비 금지). `*_CHECK` 에 `☐ codex-<role> 생략 (연속 실패)` 표기.

### 즉시 실패 (timeout 이전)

- Codex CLI 미설치 / `$CODEX_SCRIPT` 빈값 → 그 phase 의 codex 결과는 즉시 `☐ codex-<role> 미설치` 표기
- codex job spawn 실패 (network/auth 오류) → 즉시 `☐ codex-<role> spawn 실패` 표기
- 두 경우 모두 30분 기다리지 않음

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

## SCORE — 2-Phase 채점

**⛔ main thread 단독 채점 금지 — 점수 생성은 채점 주체(Workflow 파이프라인 또는 아래 named Agent)가 수행한다. main의 역할은 발사·수집·audit cap 보정까지다.**

SCORE 진입 전제: 이번 라운드의 `ROUND_CHECK`(refine.md 라운드 루프)가 이미 출력되어 있어야 한다 — 없으면 이 SCORE는 무효이고, ROUND_CHECK(절차 재독 포함)를 수행한 뒤 SCORE를 다시 실행한다. ROUND_CHECK의 `mode dimensions` 줄은 Step 0 로드값의 유지 확인이며, 모드가 바뀐 경우에만 refine-modes.md를 다시 Read한다.

### Phase 1: 병렬 채점 — claude 측 채점과 codex-scorer를 동시에 발사

claude 측 채점은 **Workflow 파이프라인 우선**(`## 오케스트레이션 & 모델 정책` 템플릿), 불가 시 아래 named Agent 스폰. 어느 경로든 codex-scorer CLI job과 한 타이밍에 병렬로 발사한다.

> ⚠️ **이전 버그 (2026-07-03 수정)**: main이 "Workflow 우선, 불가 시 Agent"를 읽고도 fallback 조건(Workflow 도구 부재 / 스크립트 오류 2회)을 실제로 확인하지 않은 채 바로 아래 Agent() 템플릿을 실행했다 — 이 섹션에 Agent() 코드블록만 인라인으로 박혀 있어서 "우선" 문구와 무관하게 눈앞의 코드를 그대로 쓴 것이 원인이었다(Workflow 복붙 템플릿은 `## 오케스트레이션 & 모델 정책`에 250줄 이상 떨어져 있음). → 수정: 아래 WORKFLOW_CHECK를 Phase 1 코드 실행 **직전** 필수 게이트로 추가해 조건 확인을 건너뛸 수 없게 한다.

**⛔ WORKFLOW_CHECK — 아래를 출력해야 Phase 1 코드(Workflow든 Agent든) 실행 가능 (생략 시 그 라운드 SCORE 무효):**
```
WORKFLOW_CHECK:
☑ Workflow 도구 세션 내 사용 가능: {yes/no}
☑ 선택 경로: workflow | agent-fallback
☑ agent-fallback 선택 시 근거: "Workflow 도구 부재" | "스크립트 오류 2회 누적({직전 오류 요약})" — 이 둘 중 하나가 아니면 agent-fallback을 쓸 수 없다. Workflow가 사용 가능한데 다른 이유(간단해서·손에 익어서·codex 쪽과 통일하려고 등)로 Agent를 쓰려는 것은 그 자체로 절차 위반 신호다 — workflow 경로로 되돌아간다.
```

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
CTX=/tmp/refine_ctx_${RUN}.diff   # PREP 인라인 컨텍스트 (없으면 ### 속도 규칙 1 로 생성)
OUTFILE=/tmp/refine_codex-scorer_r{N}_${RUN}.md; rm -f "$OUTFILE"   # ### 결과 파일 규칙: role·round·run 유니크 + 발사 전 비움(stale 방지)
node "$CODEX_SCRIPT" task --background --write \
  "먼저 /tmp/codex_prenotes_${RUN}.md(있으면)와 $CTX 를 읽어라(파일 탐색 금지). 대상을 adversarial하게 평가하라.
   모드: {MODE} / 평가 차원: {DIMENSIONS}
   기준: (a) 주장이 코드로 뒷받침되나 (b) 빠진 항목 (c) 모호 표현 반례 (d) 날조 수치=0점.
   ⛔ 결과는 반드시 Bash로 정확히 $OUTFILE 에 기록하라: 차원별 [점수]/100 + 가중평균 종합 + 근거. 기록 후 wc -l \"$OUTFILE\" 로 확인."
# stdout의 task-id 캡처 → ## Codex CLI job 호출 공통 규칙 polling(OUTFILE 비었으면 EMPTY RESULT=실패) → DONE 시 $OUTFILE 읽어 채점 반영.
```

**⏱ Codex 호출 공통 규칙 적용 (30분 timeout)** — codex-scorer 가 1800초 안에 결과 없으면 cancel + `☐ codex-scorer 호출 실패 (30분 timeout)` 표기 후 Phase 2 진행.

### ⛔ Phase 1 완료 체크 — 아래를 출력해야 Phase 2 진행 가능

```
PHASE1_CHECK:
☑ claude 측 채점({claude-scorer|workflow}) 결과: {차원별 점수 1줄 요약}
☑ codex-scorer 결과: {차원별 점수 1줄 요약}
```

줄 형식 계약: 성공 `☑ <역할> 결과: <요약>` / 실패 `☐ <역할> 실패: <사유>` — 실패 줄로 대체하되 블록 출력 자체는 생략하지 않는다.

생존 분기 — **하나라도 살아있으면 라운드 계속**: 채점 결과가 2개면 Phase 2 교차 리뷰, 1개면 교차 리뷰를 생략하고 그 결과를 채택한다(audit cap 적용은 main 책임):
- **둘 다 성공** → 정상 (Phase 2 교차 리뷰).
- **codex만 실패** (호출했으나 에러/미설치/deadline timeout) → `☐ codex-scorer 호출 실패 (사유)` 표기 후 claude-scorer 결과로 진행 (교차 리뷰 없이 claude 점수 채택).
- **claude만 실패** (멤버 timeout/포기) → `☐ claude-scorer 실패 (사유)` 표기 후 codex-scorer 결과로 진행.
- ⛔ **둘 다 실패** → **그 라운드 SCORE 무효** — main이 직접 채점하지 않는다(hard constraint). 다음 라운드에서 두 멤버 재스폰으로 재시도.

**Codex가 설치돼 있는데 호출조차 안 한 것은 "실패"가 아니라 절차 위반이다.** (예외: Codex 미설치/`$CODEX_SCRIPT` 빈값/spawn 실패로 `### 즉시 실패` 표기한 경우는 환경상 호출 불가로 허용 — `### 즉시 실패` 분기를 따른다.) 이 체크리스트 없이 Phase 2로 넘어가면 절차 위반.

### Phase 2: 교차 리뷰 — Phase 1 결과를 모은 후

```
Agent({ name: "cross-reviewer", subagent_type: "general-purpose", model: "opus",   // 모델 정책: sub-project 관리 계층
  prompt: "두 채점자의 결과를 교차 리뷰하라.
    Claude 채점: {claude_scores}
    Codex 채점: {codex_scores}
    
    1. 양쪽 근거를 읽고 더 설득력 있는 쪽 판단.
    2. 5점 이내 차이 → 평균. 5점 초과 → 근거 기반 채택 (판단 이유 명시).
    3. 과대평가 지적.
    4. 차원별 최종 점수 + 가중 평균 산출." })
```

### Phase 2 생존 분기 — cross-reviewer 자체가 실패한 경우

위 생존 분기의 "둘 다 성공 → 정상 (Phase 2 교차 리뷰)"는 Phase 2가 실제로 완료된다는 것을 전제한다. 그 전제가 깨지는 경우 — PHASE1_CHECK에서 claude 측 채점과 codex-scorer 둘 다 `☑` 성공했는데 cross-reviewer가 스폰 실패 또는 `## Step 0 멤버 구성 > ### 멤버 timeout & 강제 정리`의 30분 cap(shutdown_request 시도 후에도 무응답)까지 거쳐 포기된 경우 — 는 위 4갈래 어디에도 해당하지 않는다. (Phase 1 자체가 하나라도 실패한 경우는 여전히 위 codex만 실패/claude만 실패 갈래를 따르며 이 규칙과 무관하다.)

이 경우 main은 **새로운 채점 판단을 만들지 않는다** — 두 채점 결과에 이미 담긴 숫자만으로 계산되는 고정 산술 규칙을 그대로 대입할 뿐이며, 이는 `## 오케스트레이션 & 모델 정책 > ### main 단독 판단의 경계`가 이미 허용하는 "codex 실패 시 fallback 결정"과 같은 성격(채점 주체가 실패했을 때 사전 정의된 규칙으로 대체)이다 — 점수 생성도 아니고, 어느 쪽 근거가 설득력 있는지 main이 새로 판정하는 것도 아니다:
- 차원별 점수 차이가 5점 이내면 평균을 잠정 합의 점수로 채택한다.
- 차원별 점수 차이가 5점을 초과하면 두 점수 중 더 낮은 쪽을 잠정 합의 점수로 채택한다(근거 설득력 판정이 아닌 순수 산술 비교 — 관대하지 않는 기본값).

산출한 값은 확정 합의가 아니라 잠정치다 — `.refine.log`에 `[unverified-consensus] round=<N> dimensions=<영향 차원 목록>`을 기록한다. ⛔ **결함 cap과 혼동 금지**: 이 마커는 특정 차원 점수를 70 등으로 제한하는 결함 cap이 아니다 — 차원 점수에 어떤 상한도 걸지 않으며, 이번 라운드 Phase 2가 비어 잠정 합의로 메웠다는 절차 상태만 남긴다.

다음 라운드가 SCORE Phase 2에 도달하면, 직전 라운드에 미해소 `[unverified-consensus]`가 있는 한 그 마커의 `dimensions`를 그 라운드의 통상 cross-reviewer 호출(별도 호출 아님)에 포함시켜 재교차검증한다 — 그 사이 재채점으로 두 점수가 갱신됐으면 갱신된 값을, 그대로면 동일한 두 값을 그대로 제출한다. "이전 합의 유지"로 넘기고 재검증을 생략하면 절차 위반이다. 재호출이 성공하면 `.refine.log`에 `[unverified-consensus-resolved] round=<N>`을 추가 기록해 해소를 남기고, 다시 실패하면 위 5점 규칙으로 잠정치를 다시 산출해 `[unverified-consensus] round=<N> dimensions=<...>`을 그 라운드 번호로 다시 기록한다.

### ⛔ PHASE2_CHECK — 아래를 출력해야 SCORE 출력 진행 가능 (생략 시 그 라운드 SCORE 무효)

```
PHASE2_CHECK:
☑ cross-reviewer 정상 성공: 합의 완료 — {차원별 최종 점수 1줄 요약}
☑ Phase2 fallback 적용: [unverified-consensus] round=<N> dimensions=<영향 차원 목록> 기록됨
☑ Phase 2 해당 없음: Phase 1 결과 1개만 성공 — 교차 리뷰 생략, {claude|codex} 단독 채택 (PHASE1_CHECK 생존 분기의 codex만 실패/claude만 실패 갈래)
☐ PHASE2_CHECK 미충족: cross-reviewer 미완료 + fallback 마커 미기록 + 단일 채택 사유도 없음
```

줄 형식 계약: 위 네 줄 중 이번 라운드에 실제로 성립하는 것 **정확히 한 줄만** 출력한다 — Phase 1(PHASE1_CHECK) 둘 다 성공하고 cross-reviewer가 정상 완료됐으면 1번째 줄, 둘 다 성공했지만 cross-reviewer 자체가 실패해 위 `### Phase 2 생존 분기`의 고정 산술 규칙(5점 이내 평균 / 5점 초과 시 낮은 쪽 채택)으로 잠정 합의를 산출하고 `.refine.log`에 마커를 기록했으면 2번째 줄, Phase 1에서 애초에 하나만 성공해 교차 리뷰가 구조적으로 불필요했으면 3번째 줄을 쓴다. 위 세 조건 중 어느 것도 성립하지 않은 채 `### SCORE 출력`으로 넘어가려 하면 4번째 줄로 표기하고, 그 라운드 SCORE는 무효다 — main은 검증되지 않은 두 점수 중 하나를 임의로 채택하거나 새 합의를 만들어 이 게이트를 우회할 수 없다. 이 블록 자체를 생략해도 동일하게 그 라운드 SCORE는 무효다.

(Phase 1 둘 다 실패한 경우는 PHASE1_CHECK 생존 분기에서 이미 그 라운드 SCORE가 무효로 확정되어 Phase 2 코드가 실행되지 않는다 — 이 게이트의 대상이 아니다.)

### SCORE 출력

```
═══ Round {N} — SCORE ({MODE}) ═══
  {차원} ({가중치}%): {점수}/100 [claude:{X}, codex:{Y} → 합의:{Z}] "{근거}"
  ...
  종합: {가중평균}/100
```

한쪽 채점 실패 시 표기: `[claude:{X}, codex:—({사유}) → 채택:{X}]` — 합의가 아니라 단독 채택임을 명시한다.

Phase 2 fallback(`### Phase 2 생존 분기`)이 적용된 차원은 표기를 구분한다: `[claude:{X}, codex:{Y} → 잠정합의:{Z}] [unverified-consensus]` (예: `Procedure Rigor (25%): 76/100 [claude:74, codex:78 → 잠정합의:76] [unverified-consensus] "{근거}"`). 확정 합의 표기(`→ 합의:{Z}`)와 구분되며, 다음 라운드 재교차검증으로 `.refine.log`에 `[unverified-consensus-resolved]`가 기록되기 전까지 이 표기를 유지한다.

종료 조건 판정은 refine.md `## 라운드 루프` Step 5가 SSOT다 — 종합 점수·70 미만 차원 존재 여부·round 상한의 기본 조건과 doc:* 완료 gate·blocking open question 예외까지 전부 거기서 정의한다.
조건 미충족 시 계속 (70 미만 우선 수정).

**Round 2+에서의 SCORE는 이전 라운드 수정의 RE-SCORE 역할도 겸한다.** 별도 RE-SCORE 단계는 없다.
이전 라운드 대비 올랐으면 KEEP, 내렸으면 이전 수정을 ROLLBACK 후 다른 차원 시도.

---

## DIAGNOSE — 약점 전체 식별 (Batch)

이 라운드에서 **동시에 수정할 모든 약점**을 식별한다. 한 라운드 = 한 약점 모델은 폐기됨.

- 기본: 70 미만인 모든 차원/문항 + 결함 cap으로 정확히 70에 고정된 차원/문항을 전부 나열(둘 다 종료 게이트 미통과 대상이므로 동일하게 다룬다).
- auto 회귀 점검이 주입한 `REGRESSION_ISSUE`가 있으면 1급 약점으로 포함한다 (refine.md `### auto 회귀 점검`).
- `.refine.log`에 직전 라운드의 `[unverified-carryover]` 마커가 있으면(codex-verifier/reviewer 호출 실패로 검증·리뷰 없이 진행한 항목), 그 항목 전체를 1급 약점으로 우선 포함해 재검증 대상으로 삼는다 — 이번 라운드 codex 검증/리뷰가 PASS로 확인될 때까지 매 라운드 반복 포함한다.
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

### ⛔ DIAGNOSE_CHECK — 아래를 출력해야 PROPOSE 진행 가능

```
DIAGNOSE_CHECK:
☑ 70 미만+cap-70 차원/문항 전수 대조: {N}건
☑ audit/REGRESSION_ISSUE/codex 20점+ 낮은 문항 반영: {반영 N건 | 해당 없음}
☑ 직전 라운드 [unverified-carryover] 마커 반영: {있음→포함 N건 | 없음}
☑ 의존성/충돌 노트 작성: {요약 1줄}
```

줄 형식 계약: 누락 발견 시 `☐ DIAGNOSE 누락: {누락 범주}`로 표기하고, 누락 항목을 DIAGNOSE에 추가한 뒤 다시 CHECK를 출력한다. 이 게이트 없이 PROPOSE로 넘어가면 그 라운드 PROPOSE는 무효다.

---

## PROPOSE — 수정안 전체 작성 (Batch, dual-track)

DIAGNOSE에서 나열한 N개 약점 각각에 대해 **claude와 codex가 병렬로 독립 수정안을 작성**하고, 비교 채택 후 검증한다.

0. **codex-proposer 발사 (DIAGNOSE 확정 직후 즉시, background)** — 독립성: claude 수정안을 프롬프트에 넣지 않는다:
```bash
# codex-proposer = CLI job (⛔ 팀 멤버 Agent 아님).
OUTFILE=/tmp/refine_codex-proposer_r{N}_${RUN}.md; rm -f "$OUTFILE"   # ### 결과 파일 규칙 준수
node "$CODEX_SCRIPT" task --background --write \
  "먼저 /tmp/codex_prenotes_${RUN}.md(있으면)와 /tmp/refine_ctx_${RUN}.* 를 읽어라(파일 탐색 금지).
   아래 약점 목록 각각에 대해 독립 수정안을 작성하라. 산출물 형식(모드별): doc:* = 반영 가능한 수정 텍스트,
   code = patch/diff, test = 테스트 코드.
   약점들: {DIAGNOSE 결과 N개}
   ⛔ 결과는 반드시 Bash로 정확히 $OUTFILE 에 기록: 항목별 수정안 전문. 기록 후 wc -l \"$OUTFILE\" 확인."
# stdout task-id 캡처 → ## Codex CLI job 호출 공통 규칙 polling.
```
1. **claude 측 초안 작성** — 약점 항목별 fan-out 여부를 SCORE Phase 1과 같은 원칙(Workflow 우선, 불가 시 단일 워커)으로 정하되, 독립 게이트로 확인한다(생략 시 그 라운드 PROPOSE 무효):
```
PROPOSE_WORKFLOW_CHECK:
☑ Workflow 도구 세션 내 사용 가능: {yes/no}
☑ 선택 경로: workflow-fanout | single-worker
☑ single-worker 선택 시 근거: "Workflow 도구 부재" | "스크립트 오류 2회 누적({직전 오류 요약})" — 이 외의 사유로 single-worker를 쓰면 절차 위반.
```
   - **workflow-fanout**: `## 오케스트레이션 & 모델 정책`의 `refine-propose` 복붙 템플릿으로 N개 약점 항목을 `parallel(weakItems.map(item => agent(...)))`로 동시에 작성한다. 각 항목은 이미 완결된 수정안이므로 SCORE의 opus Consensus 단계는 이식하지 않는다 — 항목 간 조율은 아래 2번·2b가 담당한다. fan-out 결과 중 일부 항목이 null(에이전트 실패/스킵)이면 템플릿의 `missing` 목록으로 식별한다 — 그 항목만 single-worker로 1회 재시도하고, 재시도도 실패하면 그 항목은 codex-proposer 단독안으로 처리한다(2b에서 채택={codex} 강제, claude 부재를 이유로 명시).
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
2b. **PROPOSE_COMPARE (비교 채택)**: codex-proposer 결과 도착 시 항목별로 두 안을 나란히 비교해 채택한다. 판단 기준 순서: 정확성 > 부작용 적음 > 간결함.
```
PROPOSE_COMPARE:
항목 k: 채택={claude|codex|merge|재작성} — {이유 1줄}  × N
```
codex-proposer 실패/timeout/빈 결과 → claude 단독안으로 진행 (`☐ codex-proposer 실패: {사유}` 표기 — 기존 단일 트랙과 동일).
3. Codex 검증 — codex 가용 시 필수 호출 (**채택/병합된 수정안 묶음**을 한 번에 검증. 비교 채택은 검증을 대체하지 않는다 — 병합·재작성본은 아직 아무도 adversarial하게 보지 않았다. 미설치/spawn 실패/timeout 시에는 아래 정의된 예외 분기를 따른다):
```
# codex-verifier = CLI job (⛔ 팀 멤버 Agent 아님).
OUTFILE=/tmp/refine_codex-verifier_r{N}_${RUN}.md; rm -f "$OUTFILE"   # ### 결과 파일 규칙: role·round·run 유니크 + 발사 전 비움
node "$CODEX_SCRIPT" task --background --write \
  "먼저 /tmp/codex_prenotes_${RUN}.md(있으면)와 /tmp/codex_audit_${RUN}.md(doc:*면 있으면)를 읽어라. PREP 노트가 있으면 파일 탐색 금지 — 없으면 아래 '약점들'·'채택된 수정안들'에 이미 전문이 인라인되어 있으니(플레이스홀더가 아니라 실제 텍스트) 그것만으로 평가하고 별도 탐색은 하지 마라.
   수정안 묶음을 adversarial 검증하라. 각 항목의 정확성/완전성/부작용 + 묶음 차원의 충돌·회귀 가능성.
   약점들: {DIAGNOSE 결과 N개} / 채택된 수정안들: {PROPOSE_COMPARE 채택본 N개 전문 — 항목별 분리} / 대상: {파일 경로 목록}
   ⛔ 결과는 반드시 Bash로 정확히 $OUTFILE 에 기록: 항목별 PASS|CAVEAT|FAIL + 사유 + 묶음 1줄. 기록 후 wc -l \"$OUTFILE\" 확인."
# stdout의 task-id 캡처 → ## Codex CLI job 호출 공통 규칙 polling(OUTFILE 비면 EMPTY=실패) → DONE 시 $OUTFILE 읽기.
```

**⏱ Codex 호출 공통 규칙 적용 (30분 timeout)** — codex-verifier 가 1800초 안에 결과 없으면 cancel + `☐ codex-verifier 호출 실패 (30분 timeout) — 정의된 예외 분기로 진행` 표기 후 APPLY.

### ⛔ PROPOSE 체크 — 아래를 출력해야 APPLY 진행 가능

```
PROPOSE_CHECK:
☑ claude 측 초안 결과: {workflow-fanout N개 완료 | single-worker N개 완료} — 실패 시 ☐ 줄로 대체
☑ PROPOSE_COMPARE 결과(main 판정): 채택 요약 (claude {a} / codex {b} / merge {c} / 재작성 {d}) — 실패 시 ☐ 줄로 대체
☑ codex-verifier 결과: 채택본 항목 1..N 각각 {PASS|CAVEAT|FAIL} — 묶음 전반 1줄 요약
```

실패 줄: `☐ claude 측 초안 실패: {항목} 누락 — 재시도 후에도 미완료, codex-proposer 단독안으로 대체` / `☐ codex-verifier 호출 실패 — 정의된 예외 분기로 진행`

4. Codex 피드백 반영 후 즉시 APPLY.

규칙:
- 한 라운드 = 식별된 모든 약점 동시 수정. 빠뜨리면 절차 위반.
- 충돌이 해소 불가능한 두 약점은 우선순위 높은 쪽만 이번 라운드에 수정하고, 나머지는 다음 라운드 DIAGNOSE에서 재식별 (묻지 말고 진행).
- code Correctness Q2가 약점이고 원인이 미구현이면 → 기능 구현이 수정안.

---

## APPLY — 모든 수정안 일괄 반영

0. **스냅샷(ROLLBACK 자산)**: 대상 파일 pre-해시(`shasum`) 기록 + **git 여부와 무관하게** 대상 파일을 `/tmp/refine_backup_r{N}_${RUN}/`로 cp — 라운드 diff와 역적용은 이 백업 기준이다. pre-해시 이전부터 있던 dirty 변경은 백업에 그대로 담겨 보존된다(이번 라운드 적용분과 자동 분리).
1. PROPOSE의 N개 수정안(PROPOSE_COMPARE 채택본)을 모두 Edit으로 반영.
   - 같은 파일에 여러 수정이 들어가면 한 번에 적용 (충돌 방지).
   - Codex가 FAIL/CAVEAT한 항목은 피드백 반영 후 적용. 명백히 잘못된 항목은 제외하고 그 사유를 .refine.log에 기록.
2. code/integrate: lint 실행. 실패 시 즉시 수정.
3. Cross-doc 동기화: 데이터 모델/인터페이스 변경 시 `grep -r "변경 용어" docs/*.md` 확인.
4. Codex 교차 리뷰 — codex 가용 시 필수 호출 (전체 diff 한 번에 리뷰. 미설치/spawn 실패/timeout 시에는 아래 정의된 예외 분기를 따른다):
```
# codex-reviewer = CLI job (⛔ 팀 멤버 Agent 아님).
OUTFILE=/tmp/refine_codex-reviewer_r{N}_${RUN}.md; rm -f "$OUTFILE"   # ### 결과 파일 규칙: role·round·run 유니크 + 발사 전 비움
ROUND_DIFF_FILE=/tmp/refine_r{N}_review_${RUN}.patch
BACKUP_DIR=/tmp/refine_backup_r{N}_${RUN}
# reviewer 직전 실제 적용 diff를 백업 기준으로 생성해 프롬프트에 인라인한다(pre-existing dirty 변경과 분리).
# <수정 파일 절대경로들>은 APPLY 0번에서 스냅샷한 대상 파일의 절대경로 목록이다(예: /Users/.../refine.md). $f는 절대경로, 백업은 basename으로 찾는다.
: > "$ROUND_DIFF_FILE"
DIFF_OK=1
for f in <수정 파일 절대경로들>; do
  bn=$(basename "$f")
  if [ ! -f "$BACKUP_DIR/$bn" ]; then echo "MISSING BACKUP: $bn" >&2; DIFF_OK=0; continue; fi
  diff -u "$BACKUP_DIR/$bn" "$f" >> "$ROUND_DIFF_FILE"
done
ROUND_DIFF="$(cat "$ROUND_DIFF_FILE")"
# ⛔ DIFF_OK=0이거나 변경 파일이 있는데도 $ROUND_DIFF_FILE이 비어 있으면(diff -u는 차이 없을 때만 0바이트) codex-reviewer를 발사하지 말고 backup 누락·경로 오류부터 해결한다 — 빈 diff를 "리뷰 완료"로 오인하지 않는다.
node "$CODEX_SCRIPT" task --background --write \
  "먼저 /tmp/codex_prenotes_${RUN}.md(있으면)와 /tmp/codex_audit_${RUN}.md(doc:*면 있으면)를 읽어라. PREP 노트가 없으면 이 프롬프트에 포함된 diff/수정안만으로 평가하고 파일 탐색은 하지 마라.
   이번 라운드 diff 전문:
$ROUND_DIFF

   수정 파일: {경로 목록} / 적용된 수정안: {N개 항목 1줄 요약}
   각 항목별로 새 버그/에지 케이스 + 항목 간 상호작용 회귀 검증.
   ⛔ 결과는 반드시 Bash로 정확히 $OUTFILE 에 기록: 항목별 PASS|CAVEAT|FAIL + 묶음 1줄. 기록 후 wc -l \"$OUTFILE\" 확인."
# stdout의 task-id 캡처 → ## Codex CLI job 호출 공통 규칙 polling(OUTFILE 비면 EMPTY=실패) → DONE 시 $OUTFILE 읽기.
```

**⏱ Codex 호출 공통 규칙 적용 (30분 timeout)** — codex-reviewer 가 1800초 안에 결과 없으면 cancel + `☐ codex-reviewer 호출 실패 (30분 timeout) — 정의된 예외 분기로 진행` 표기 후 다음 라운드.

### ⛔ APPLY 체크 — 아래를 출력해야 다음 라운드 진행 가능

```
APPLY_CHECK:
☑ codex-reviewer 결과: 항목 1..N {PASS|CAVEAT|FAIL} — 묶음 전반 1줄 요약
```

호출 실패 시만: `☐ codex-reviewer 호출 실패 — 정의된 예외 분기로 진행`

5. code/integrate: 테스트 재실행 (전체 묶음 적용 후 한 번).
5b. **(test/integrate + TDD ON code 한정) Mutation sanity check** — 이번 라운드에 새로 쓰거나 강화한 테스트가 검증하는 **그 분기만** 1-라인 mutation으로 임시로 깨뜨려(예: 비교 연산 반전, early-return 제거, write 호출 주석화) 해당 테스트가 **실패(red)** 하는지 확인하고 즉시 원복한다. 여전히 통과(green)면 그 테스트는 분기를 실제로 검증하지 못하는 것이다 → 그 항목을 다음 DIAGNOSE의 1급 약점으로 올리고 Failure-Mode Coverage에서 NONE 처리한다. ⛔ 전체 파일 mutation testing이 아니다 — 이번 라운드 변경분이 검증하는 분기로만 한정한다. mutation은 워킹트리에 남기지 말고 확인 직후 원복한다.
6. 유효 이슈 (위치 인용 + 조건 명시 + 수정 제안) 있으면 즉시 수정.
7. .refine.log에 라운드 기록 — 적용된 N개 항목 모두 나열.
8. **라운드 diff·post-해시를 저장하고 다음 라운드 SCORE로 돌아간다.** APPLY 직후 라운드 diff를 **백업 대비**로 생성한다: `diff -u /tmp/refine_backup_r{N}_${RUN}/<f> <f>` → `/tmp/refine_r{N}_round_${RUN}.patch` (git diff가 아니라 백업 기준 — 이번 라운드 적용분만 정확히 담기고 pre-existing dirty 변경은 patch 밖에 남는다). 대상 post-해시도 함께 저장한다 — ROLLBACK 자산은 '적용 직후 상태' 기준이다. 다음 SCORE가 이전 대비 종합으로 올랐으면 KEEP, 내렸으면 ROLLBACK: **현재 해시가 post-해시와 일치할 때만** 라운드 patch를 역적용한다(`patch -R -p0 < patch` 또는 backup 복원 — 묶음 전체, 부분 롤백 금지, 부분 롤백은 다음 라운드 DIAGNOSE의 책임). 해시 불일치(외부 변경 개입)면 자동 복원을 멈추고 사용자에게 보고한다. **종합 비교는 동일 채점 기반일 때만 기계적으로 적용한다** — 채점 방식이 라운드 간 바뀌었거나(예: Agent 단독 → Workflow fan-out), 하락 기여분이 '이번 라운드 diff와 무관하게 이전부터 존재한 결함의 신규 발견'으로 확인되면(라운드 백업 대비 grep 검증), main이 KEEP|ROLLBACK을 근거와 함께 판정하고 `.refine.log`에 `[keep-override]`/`[rollback]` 마커로 남긴다.

---

## code 모드 특별 규칙

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

**⛔ TDD_CHECK — TDD ON 라운드의 APPLY마다 출력 (생략 시 그 라운드 APPLY 무효):**
```
TDD_CHECK:
☑ red: 실패 테스트 {N}개 — 실패 로그 확인됨 (원천: {doc:test 항목|spec AC|버그 재현})
☑ green: 전체 통과
☑ refactor 후 통과 유지
```

실패 줄 형식(PHASE1_CHECK 계약과 동일 — 실패 줄로 대체하되 블록 생략 불가): `☐ red 실패: 테스트가 이미 통과(대상 기구현 — red 재설계 또는 항목 제외)` / `☐ green 미달: {사유} — 그 항목은 Items에 deferred로 기록` / `☐ refactor 회귀: 리팩토링을 되돌리고 green 상태로 복원`.

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

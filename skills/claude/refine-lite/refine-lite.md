---
description: 소형~중형 코드/테스트 파일을 작성하거나 수정한 뒤, 독립 채점자 1명 + 최대 2 채점 라운드(기본값에서 일괄 수정 1회) + 종료 직전 codex 리뷰 1회로 빠르게 검증하는 경량 개선 루프. 대형 캠페인이나 문서 계열(doc:*, 다세션 점수 이력)은 /refine을 쓴다.
argument-hint: "[path] [--target N] [--rounds N] [--mode code|test]"
---

/refine의 경량 자매 스킬. 다중 채점 fan-out·codex 4역할·라운드 원장·STATUS/ledger 대신, 채점자 1명 + 최대 2 채점 라운드(기본값에서 일괄 수정 1회) + 종료 직전 codex 리뷰 1회로 "통과 기준을 넘었는가"를 빠르게 검증한다.

## 사용 경계 (allowlist)

- **refine-lite**: 모듈 단위 코드 파일, PR로 나가는 코드, 엣지케이스 리스크가 있는 테스트 스위트.
- **스킬 없이 직접 작성 + `/code-review`**: 함수 1-2개짜리 초소형 변경 — 이 조합만으로 충분하다.
- **`/refine`**: 계약 문서(doc:idea/design/spec/plan/skill/test 등), 다세션 캠페인, 점수 이력(STATUS.md/ledger)이 필요한 작업.

## 파라미터

`$ARGUMENTS`에서 추출:
- `[path]`: 대상 파일 경로 (필수).
- `--target N`: 목표 종합 점수. 기본 70.
- `--rounds N`: 최대 라운드(MAX_ROUNDS). 기본 2.
- `--mode code|test`: 명시 없으면 자동 감지 — 파일명이 테스트 패턴(`test_*`·`*_test.*`·`*.test.*`·`tests/` 하위)과 일치하면 `test`, 그 외는 `code`.

## 종료 계약

종료 조건은 정확히 둘 중 하나다: ① 종합 점수 >= TARGET **AND** 70 미만 차원 없음 (Step 2 통과), ② 채점 라운드(ROUND)가 MAX_ROUNDS(기본 2회)에 도달 — ROUND는 채점 횟수 기준이며 그 사이의 일괄 수정은 기본 1회(Step 3)다. ②로 종료할 때는 남은 이슈를 Step 5 리포트에 담아 종료하고, 라운드 연장은 사용자가 `--rounds`로 다시 지시할 때 적용한다. 사용자 전역 메모리의 `/refine loop` Hard Rule(MAX_ROUNDS 소진 전 중단 금지)은 `/refine` 전용이다 — `/refine-lite`의 종료 계약은 이 문서가 정의한다.

## 절차

### Step 0 — 대상 확인

입력: PATH, MODE(자동 감지 포함).
- PATH에 파일이 없으면 대화에 명시 요구사항이 있을 때만 그 요구사항대로 새로 작성하고 수용 기준을 산출에 1-3줄로 기록한다 — 이 작성은 **Round 0**으로 기록하고 MAX_ROUNDS 카운트는 Round 1부터 시작한다. 명시 요구사항이 없으면 요구사항을 사용자에게 요청하고 응답을 대기한다.
- PATH에 파일이 있으면 수정 전 `backup="/tmp/refine-lite-backup-$(date +%s)-$(basename -- "{PATH}")"; cp -- "{PATH}" "$backup"`로 되돌림 기준점과 원본 hash를 남기고 곧장 Round 1로 진행한다. 적용 batch마다 별도 snapshot/hash를 남겨, 새 검증 실패 또는 점수 하락 시 writer 출력 hash가 일치할 때만 그 batch를 rollback한다.

산출: 확정된 대상 파일(신규 작성 시 수용 기준 1-3줄 포함), 기존 파일이면 백업 사본 경로. 다음 분기: 파일이 확정됐으면 항상 Step 1(ROUND=1)로.

### Step 1 — 채점

입력: 대상 파일, MODE. 채점은 독립 채점자 lite-scorer가 전담한다 — main의 역할은 스폰과 결과 수집이다. lite-scorer가 10분 내 무응답이면 동일 프롬프트로 1회 재스폰한다(name: lite-scorer-r2):

```
Round 1:
Agent({ name: "lite-scorer", subagent_type: "general-purpose", model: "sonnet",
  prompt: "너는 /refine-lite의 독립 채점자다. main과 분리된 시각으로 채점하라.
    대상: {PATH} (모드: {MODE})
    평가 차원(고정): Correctness 40% / Test Coverage 25% / Simplicity 20% / Edge Cases 15%
    (모드=test면 대상 자체가 테스트 스위트 — Test Coverage는 시나리오 커버 폭, Edge Cases는
    경계·예외 케이스 포함 여부로 채점)
    (Simplicity는 인지 복잡도 기준으로 채점 — main path가 edge case보다 먼저 읽히는지,
    가드 클로즈 미사용 3단+ 중첩, 긴 if/switch 체인, 반복 부정, callback chain,
    boolean flag/mode string으로 한 함수에 여러 동작을 넣는 패턴, parsing/I/O/mutation/formatting
    혼재, 불필요한 mutable state, dead/future-only branch, 파라미터 5개+는 감점.)

    1. 대상 파일과 관련 테스트/피대상 코드를 읽어라.
    2. 각 차원을 0-100으로 채점하고 근거를 파일:라인 단위로 남겨라.
    3. 채점 기준: 61-70=과반 충족·중요 빈틈 1-2개, 71-85=대부분 충족·사소한 빈틈.
       엄격 기준을 유지하라 — 50점대는 부족, 71점부터 괜찮음이다.
    4. 날조 수치 = 해당 차원 0점.

    출력: 차원별 [점수]/100 + 가중 종합 점수 + 파일:라인 이슈 목록." })

Round 2+ (활성 lite-scorer 재사용 — 최초 스폰이 무응답으로 재스폰됐다면 활성 대상은 lite-scorer-r2):
SendMessage({ to: "{활성 lite-scorer}", summary: "Round {N} 재채점 요청",
  message: "적용한 수정: {Step 3 수정 요약}. 전체 차원을 처음부터 full로 재채점하라 — 직전 점수를 재사용하지 말고 근거를 새로 남겨라." })
```

채점과 병행해 프로젝트 테스트 러너(리포지토리에 이미 설정된 pytest/jest 등 — PATH가 속한 프로젝트 기준)를 실행한다 — 러너를 찾지 못하면 리포트에 러너=not_found로 남기고 Step 2의 테스트 게이트를 생략한다. Python 대상이면 pre-commit도 실행하고 `flake8 --select=CCR001 --max-cognitive-complexity=15 <PATH>`가 있으면 인지복잡도를 측정한다(없으면 `cc=not_available`).
산출: 차원별 점수, 종합 점수, 파일:라인 이슈 목록, 테스트/pre-commit/cc 결과. 다음 분기: 항상 Step 2로.

### Step 2 — 게이트

입력: Step 1 산출. 산출: 통과/미통과 판정.
- **통과 → Step 4**: 테스트 100% 통과(러너가 없는 프로젝트면 이 조건은 생략) AND (Python 대상이면 pre-commit 통과) AND (cc=not_available이면 생략, 그 외 CCR001 위반 0) AND 종합 >= TARGET AND 70 미만 차원 없음.
- **미통과 → Step 3**: 위 중 하나라도 불만족 — 테스트 미통과는 점수와 무관하게 미달로 확정한다. 단 ROUND >= MAX_ROUNDS면 이미 채점 상한에 도달했으므로 Step 3(일괄 수정)를 건너뛰고 곧장 Step 4로 진행한다(예: `--rounds 1`에서 채점 1회 후 초과 수정 방지).

### Step 3 — 일괄 수정

입력: Step 1/2의 이슈 목록. 이슈를 전부 한 번에 수정한다(테스트 실패 항목 최우선) — PATH가 테스트 파일(mode=test)이면 수정은 PATH 자체를 기본 범위로 하고, 실패 원인이 대상 소스 코드의 버그로 확인되면 그 소스도 함께 고친다.

수정에는 작은 단순화 pass를 포함한다: main path가 먼저 읽히도록 guard clause/early return으로 중첩을 줄이고, parsing·branching·I/O·mutation·formatting이 섞인 함수는 도메인 규칙 기준으로 분리하며, dead/duplicate branch와 불필요한 mutable state를 제거한다. boolean flag/mode string이 divergent behavior를 만들면 이름 있는 함수 또는 더 단순한 dispatch shape를 검토한다. 새 추상화는 실제 분기/상태 복잡도를 줄일 때만 유지한다.

수정 후 위 Round 2+ 템플릿으로 lite-scorer를 재사용해 재채점한다(full).
산출: 수정 반영된 파일, full 재채점 결과. ROUND += 1.
다음 분기: ROUND < MAX_ROUNDS면 Step 2로(게이트 재확인). ROUND >= MAX_ROUNDS면 게이트 결과와 무관하게 Step 4로 진행한다.

### Step 4 — codex 최종 리뷰 (1회)

입력: 확정 직전 대상 파일 전체(이번 실행에서 변경된 파일 목록 — mode=test에서 소스도 함께 고쳤다면 그 소스 포함). 사용자 전역 Codex Collaboration Protocol의 Pattern A(코드 변경 후 리뷰) 취지를 이 1회 호출로 충족한다 — 리뷰 대상이 git diff 전체가 아니라 특정 파일 목록이므로, diff 스코프인 `adversarial-review` 대신 파일을 직접 지정하는 `task` 서브커맨드를 쓴다. Bash 도구 timeout은 넉넉히 600000ms로 지정한다 — timeout으로 미완료 시 Step 5에 미실행 사유=timeout으로 남긴다.

```bash
CODEX_SCRIPT=$(ls -1d $HOME/.claude/plugins/cache/openai-codex/codex/*/scripts/codex-companion.mjs 2>/dev/null | tail -1)
CODEX_LOG=/tmp/refine-lite-codex.$(date +%s).log
if [ -z "$CODEX_SCRIPT" ]; then
  echo "not_installed" > "$CODEX_LOG"
else
  node "$CODEX_SCRIPT" task "{CHANGED_FILES} 적대적 리뷰: 버그·누락 케이스·과잉 복잡도(main path를 가리는 중첩/긴 조건 체인/반복 부정/boolean-mode 분기/혼재 책임/불필요 state/dead branch)를 지적하라." > "$CODEX_LOG" 2>&1 || true
fi
```

`task`는 `--background` 없이 호출하면 동기 실행이라 결과가 바로 `$CODEX_LOG`에 남는다 — 리뷰 전용이므로 읽기 전용으로 호출한다. `$CODEX_SCRIPT`가 빈 값이면 위 가드가 `not_installed`로 결정적으로 분류해 `$CODEX_LOG`에 남기고, 그 외 호출 실패는 `$CODEX_LOG` 내용을 근거로 사유(spawn_failed|timeout)를 Step 5에 남기고 다음 단계로 진행한다(`|| true`). 지적의 반영은 main이 수행한다 — 결정적·기계적 수정(포맷터/린터 자동수정)은 main이 즉시 적용하고, 비기계적 수정(코드/문장 재구성)은 sonnet 워커에게 브리핑으로 위임해 그 산출물을 반영한다. 유효한 지적이 있으면 위 원칙대로 반영하고 테스트·pre-commit·cc를 재실행한 뒤 lite-scorer에 전체 차원 재채점 1회를 요청한다(라운드 카운트 없음). 최종 Step 2 gate를 다시 평가해 검증 실패·점수 하락·미해결 blocking finding이 있는 이전 PASS를 보존하지 않는다.
산출: codex 리뷰 요약(또는 미실행 사유), 반영 시 delta 재채점 결과. 다음 분기: 항상 Step 5로.

### Step 5 — 리포트

대화 리포트로 결과를 낸다(로그·STATUS 파일 대신 이 리포트 하나로 완결):
- 판정: `PASSED`(Step 4 반영 후 전체 재채점과 최종 게이트 통과) 또는 `STOPPED_AT_MAX_ROUNDS`(최종 게이트 미통과, ROUND>=MAX_ROUNDS로 종료 — 아래 남은 이슈 참조) 중 실제 최종 게이트 결과와 일치하는 값 하나만 쓴다. Step 4의 리뷰 반영·delta 재채점에서 검증 실패, 점수 하락, 미해결 blocking finding이 발생하면 이전 PASS를 보존하지 말고 최종 게이트를 미통과로 판정한다.
- 시작 → 최종 종합 점수, 차원별 점수 (Step 4에서 반영이 있었다면 그 delta 재채점을 반영한 최종본 기준 점수)
- 실행한 라운드 수, 테스트 러너 사용 여부(러너=not_found면 그렇게 표기)
- 남은 이슈(있으면 파일:라인까지)
- codex 리뷰 요약(또는 미실행 사유: not_installed|spawn_failed|timeout)

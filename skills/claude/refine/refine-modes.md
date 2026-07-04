---
description: /refine 보조 파일 — 모드별 평가 차원 테이블 (직접 호출용 아님, Step 0에서 Read)
---

# /refine 모드별 평가 차원

Step 0에서 MODE 확정 후 이 파일을 Read하여 해당 모드의 차원을 확인한다.

## 모든 doc:* 공통 규칙 (idea/design/spec/plan/skill/test)

차원 채점 전에 `refine-steps.md`의 `## doc:* 사전 audit` 절차를 반드시 수행한다. 이 audit는 모든 doc:* 모드에 동일하게 적용되며, **Audit 1·2·3 모두 필수다** — Audit 3의 역질문은 문서를 concrete하게 만드는 1급 장치로, 라운드 경계에서 사용자에게 배치 질문한다(refine-steps.md `### Audit 3`).

audit 결과 → 차원 상한 매핑 (audit 출력의 결론을 차원 점수에 그대로 반영):

| audit 발견 | 영향 받는 차원 | 상한 |
|------------|----------------|------|
| Stale term이 active contract 텍스트에 leak (out-of-scope 격리 안 됨) | Architecture/Model Consistency, Self-Consistency | 60 |
| 구현 함정 1개 카테고리 이상이 active contract에 미식별 잔존 | Completeness / Edge Cases, Constraint Enforcement | 65 |
| 고아 1급 개념 또는 동급 contract 중복 재기술 섹션 1건+ | Structural Coherence, Procedure Rigor | 70 |
| Reader path 끊김 또는 순환 참조 1건+ | Readability, Self-Consistency | 70 |
| 제거된 field/enum/table/API route/model 개념이 active contract에 잔존 | **종료 금지 gate** — 종합 점수가 TARGET 넘어도 미완료 처리 |

구현 함정 5개 카테고리(reserved SQL/ORM 이름, mutable list index identity, 미강제 invariant, 모호한 ID/URL encoding, 무한/대용량 hot-row payload) 모두 audit에서 확인하고 결과를 SCORE 출력 위에 노출해야 한다.

## doc:idea

| 차원 | 가중치 | 평가 기준 |
|------|--------|----------|
| Problem Clarity | 25% | 문제를 겪는 사람이 특정되어 있는가? 빈도/심각도 뒷받침 데이터? |
| User Model | 25% | 타겟 사용자 1문장 정의? 현재 대안(workaround) 명시? |
| Differentiation | 20% | 기존 대안 1개+ 이름 언급 + 차이 설명? 타이밍 근거? |
| Feasibility | 15% | 핵심 기술 리스크 나열? 각 검증 방법? |
| Scope | 15% | MVP 포함/제외 각각 나열? |

## doc:spec

| 차원 | 가중치 | 평가 기준 |
|------|--------|----------|
| Requirements | 20% | 검증 가능한 AC? "적절히/빠르게" 없는가? |
| User Flow | 20% | 전체 단계 순서? 각 단계 입출력? |
| Edge Cases | 20% | 5개+ 예외 시나리오? 각 시스템 응답? |
| Measurability | 15% | KPI 1개+? 측정 방법/판단 시점? |
| Scope Boundary | 15% | "안 하는 것" 목록? 판단 기준? |
| Dependencies | 10% | 외부 의존성 이름+가용성 전제? |

## doc:plan

| 차원 | 가중치 | 평가 기준 |
|------|--------|----------|
| Goal Clarity | 20% | 1-2문장 목표? done criteria? |
| Step Completeness | 25% | 빠진 단계 없는가? 입력/산출물? 순서=의존성? |
| Edge Cases | 20% | 실패/경계/빈입력/동시성/롤백 3개+? |
| API Surface | 15% | 함수 시그니처/타입 코드 수준? 호출 예시? |
| Dependency Awareness | 10% | 의존 모듈 나열? 영향 범위(caller)? |
| Simplicity | 10% | 더 적은 단계로 가능? 삭제 가능 단계? |

## doc:skill

스킬/커맨드/에이전트 지침 등 **AI에게 주는 지시문 (prompt 문서)** 용. 대상 예시: `~/.claude/commands/*.md`, `~/.claude/skills/**/SKILL.md`, `.claude/agents/**/*.md`, CLAUDE.md 섹션 등.

**doc:plan이 아니다** — 이 파일들은 함수 시그니처·의존 모듈·caller가 없고, 대신 "LLM이 틀리지 않게 실행하도록 지시하는 것" 자체가 품질의 축이다.

| 차원 | 가중치 | 평가 기준 |
|------|--------|----------|
| Intent Clarity | 15% | 목적/트리거 조건/사용 시점(언제 쓰라/쓰지 마라) 명확? frontmatter description 구체적? 모드·파라미터 설명? |
| Procedure Rigor | 25% | 단계별 절차 완결? 각 스텝의 입력/산출물/분기/종료 조건? 체크리스트·게이트로 스킵 방지? |
| Constraint Enforcement | 20% | 금지(⛔/NEVER)/필수(반드시/MUST) 제약 명시? LLM이 흔히 빠지는 함정(조기 종료·판단 위임·날조 수치) 경고? 위반 시 조치? |
| Edge/Failure Handling | 15% | 실패/예외/정체/롤백/재시도 처리? 도구 부재·에러 반환·사용자 거부 시 분기? 애매한 입력 처리? |
| Tool & Agent Usage | 15% | 도구 호출 형식 정확(Agent/Bash/Skill/Workflow)? Agent 스폰 템플릿·Workflow `agent()` DSL·프롬프트 예시? 병렬/순차 판단 기준? 파라미터 파싱 규칙? |
| Self-Consistency | 10% | 용어/포맷 일관? 교차 파일 참조 경로 실존? frontmatter↔본문 일치? 예시와 규칙 일치? 중복/상충 지시 없음? |

**doc:skill 특별 규칙:**
- **레퍼런스 실존 검증**: 본문에서 참조하는 경로(`~/.claude/...`, 다른 스킬·커맨드)는 모두 실존해야 함. 죽은 링크 1건당 Self-Consistency −5.
- **지시 일관성**: "반드시 X하라"라고 적어놓고 X 없이 진행 가능한 경로가 존재하면 Constraint Enforcement 상한 70.
- **종료 조건**: 루프/반복/iterative 스킬은 명확한 종료 조건이 최소 2개 이상(성공/한계)이어야 함. 아니면 Procedure Rigor 상한 70.
- **Agent 호출 패턴**: Agent를 스폰하는 스킬은 프롬프트 템플릿을 그대로 복붙 가능한 수준으로 제공해야 함. 플레이스홀더뿐이면 Tool & Agent Usage 상한 75.
- **테스트/lint 실행 안 함**: doc 모드이므로 pytest/eslint 미실행.

## doc:design

| 차원 | 가중치 | 평가 기준 |
|------|--------|----------|
| Problem Clarity | 10% | 문제 서술 명확? 영향 사용자? 왜 지금? |
| Reader / User Model | 10% | 타겟 독자가 이해할 만큼 사용자 행동/맥락/결정/제약이 분명한가? |
| Structural Coherence | 20% | 최상위 섹션이 각각 고유 목적? 1급 개념마다 owning section 또는 명시적 owner? 동급 개념이 동일 추상 레벨 또는 의도적 그룹핑? |
| Architecture / Model Consistency | 20% | 책임 분리? 용어 일관? data/API/control flow가 end-to-end로 추적 가능? |
| Feasibility / Risk | 15% | 현재 스택으로 실현 가능? 구현 delta·외부 의존·마이그레이션 리스크·검증 방법 명시? |
| Completeness / Edge Cases | 15% | 에러 케이스·모호 경계·라이프사이클 상태·"안 하는 결정" 다루는가? |
| Simplicity / Editorial Economy | 10% | 잘라도 의도 손실 없는 섹션/개념/레이어 존재? contract 중복 재기술 회피? |

**doc:design 특별 규칙:**
- 위 `## 모든 doc:* 공통 규칙`의 구조 audit + contract/stale-term audit를 그대로 적용. 추가로 아래 design-specific 강화 규칙 적용.
- "Contract", "Overview", "Detail" 같은 섹션은 고유 reader job이 있을 때만 구조 점수를 받는다. model/API/DB 섹션이 이미 가진 필드를 재기술할 뿐이면 merge 또는 rename 대상.
- 새 model component를 도입했는데 전용 model 섹션도, 명시적 그룹핑 규칙도 없으면 `Structural Coherence` 상한 65, `Completeness / Edge Cases` 상한 70.
- schema/Pydantic/SQL 예시가 등장하는 design은 contract/stale-term audit의 구현 함정 5개 카테고리 중 어느 하나도 미식별 잔존하면 `Architecture / Model Consistency` 상한 65.
- **Open Questions / 역질문 도출 (필수, 무모순성 확인과 별개)**: 구조·contract audit는 "서로 모순되는가"만 본다. 그것에 그치지 말고, **각 1급 개념/섹션마다 "이 설계를 구현·운영하려면 결정돼야 하는데 문서에 빠진 정보"를 식별**하고, 누락 항목마다 사용자에게 던질 **역질문(back-question)**을 형성해 `refine-steps.md`의 `## doc:* 사전 audit > Audit 3`을 수행한다. 결과는 SCORE 출력 위 `OPEN QUESTIONS` 블록으로 노출한다.
  - 미해결 역질문 1건+ → `Completeness / Edge Cases` 상한 70.
  - 핵심 contract(데이터 모델 필드·관계·API 계약·상태 전이·동시성/충돌 규칙)에 누락 역질문이 있으면 → **종료 금지 gate**(종합이 TARGET 넘어도 미완료 처리). 각 역질문은 사용자 답변으로 해소되거나 명시적 'out-of-scope/후속 결정'으로 분류돼야 통과.
  - AUTO_CONTINUE라도 역질문은 사용자에게 **반드시 노출**한다(추정으로 메우지 말 것 — 빠진 정보를 날조하면 해당 차원 0점).

## doc:test

테스트 설계 doc은 "무엇을 어느 계층에서 검증하는가"를 명시해야 한다. unit·integration·e2e 3계층 커버리지를 요구사항별로 표로 적는 것이 1급 품질 축이다.

| 차원 | 가중치 | 평가 기준 |
|------|--------|----------|
| Spec Coverage | 20% | 스펙 모든 요구사항 커버? 매핑 추적? |
| Test Tier Coverage | 15% | **unit·integration·e2e 3계층을 요구사항별로 명시 매핑하는가?** 각 요구사항/기능이 어느 계층에서 검증되는지 표로 적혔는가? 상태기계 전이·failure-mode가 적절한 계층(단위=분기, 통합=진입점 배선, e2e=전체 흐름)에 배정됐는가? |
| Edge Cases | 20% | 경계값/예외/실패/빈입력/대량입력 + **상태기계 전이**(stale 거부, 수렴/정체, 동시 다중 pending, race)? |
| Independence | 10% | 독립 실행? 순서 무관? |
| Clarity | 15% | 이름만으로 검증 대상 파악? AAA? |
| Redundancy | 10% | 중복 없이 고유 검증? |
| Maintainability | 10% | 스펙 변경 시 수정 5개 이하? fixture 추출? |

**doc:test 특별 규칙:**
- **3계층 게이트**: 테스트 설계 doc이 unit·integration·e2e 각 계층을 요구사항별로 명시 매핑하지 않으면 `Test Tier Coverage` 상한 60. 한 계층이 "해당 없음"이면 그 사유를 명시해야 통과(빈칸=미완료).
- **failure-mode 계층 배정**: 상태기계 전이·조용한-오작동 mode(stale 덮어쓰기, 수렴 미종료, 동시 pending, 외부 write 실패 후 baseline 오전진)가 어느 계층에서 검증되는지 미배정이면 `Edge Cases` 상한 65.

## code

| 차원 | 가중치 | 평가 기준 |
|------|--------|----------|
| Correctness | 25% | 의도대로 동작? 버그 없는가? 스펙 일치? |
| Simplicity | 20% | 불필요한 추상화/계층/wrapper 없는가? premature abstraction? 동일 동작을 더 적은 코드로? dead code · 미사용 import · future-only 분기/feature flag 회피? |
| Readability | 15% | 함수명으로 동작 예측? 네이밍 컨벤션? |
| Structure | 15% | 단일 책임? 의존성 상위→하위? 동일 로직 반복? |
| Error Handling | 5% | 외부 호출 에러 처리? 에러 context? |
| Test Coverage | 10% | 핵심 로직 테스트? 테스트 통과? |
| Performance | 10% | N+1/루프 I/O/O(n²)? 메모리 무한 증가? |

**code 특별 규칙:**
- 테스트 통과율 < 100% → 상한 60
- spec AC 게이트: spec에 명시적으로 제외 표기된 AC(별도 마일스톤·외부 의존 대기 등) 제외, 미구현 AC 1건+ → Correctness Q2=0
- 더 적은 코드로 레이어/분기를 제거해도 요구된 동작이 유지되면, 그 선택지를 검토하거나 근거와 함께 기각하기 전까지 `Simplicity` 상한 70
- TDD ON 라운드(refine-steps.md `### TDD 변형`)에서 red 선행 없이 구현된 항목 1건+ → `Test Coverage` 상한 70 (TDD_CHECK로 검증)
- spec gap 모드: 마일스톤 완료 + AC 미구현 → 기능별 구현 루프. Correctness Q2가 약점이면 기능 구현이 수정안
- 마일스톤 모드: design 마일스톤별 branch → 구현 → refine → merge

## test

> **범위(refine vs review)**: test 모드는 *기존 테스트 스위트*가 대상 코드의 상태기계 전이·failure mode를 잡는지 측정·보강한다. 신규 PR diff의 SQL 안전성·LLM trust-boundary·조건부 side effect 등 *변경분 위험 카탈로그*는 `/review`·`/code-review`의 책임이며 여기서 복제하지 않는다. refine이 도출한 '미커버 전이'는 테스트 작성으로 처리한다.

| 차원 | 가중치 | 평가 기준 |
|------|--------|----------|
| Spec AC Coverage | 30% | spec AC 중 테스트 커버 비율? 70% 미만→상한 60 |
| Branch Coverage | 20% | 핵심 로직 분기 커버리지? vitest/pytest --coverage? |
| Edge Case Tests | 20% | 경계값/예외/실패/빈입력/대량입력 + **상태기계 전이**(stale 거부, 수렴/정체 종료, 동시 다중 pending, 외부 write 실패 후 baseline 처리)? |
| Failure-Mode Coverage | 15% | 'State-Machine / Failure-Mode 열거'(refine-steps.md) 표의 (전이·조용한-오작동 mode) 중 NONE 비율? **NONE 1건+ → 상한 60. 핵심 경로(외부 시스템 write happy-path·baseline/snapshot 전진·같은 트리거의 happy/abort 양분기 중 한쪽만 커버) NONE → 종료 금지 gate(종합이 TARGET 넘어도 미완료 처리)** |
| Test Quality | 10% | Given/When/Then? AAA? 독립성? fixture? |
| Gap Resolution | 5% | 미커버 AC/전이 발견→테스트 작성? test-map 동기화? |

## integrate

> **범위(refine vs review)**: integrate 모드는 *기존 테스트 스위트*가 e2e/통합 경로의 failure mode를 실제 구동해 잡는지 측정·보강한다. 변경분 위험 카탈로그(SQL 안전성·trust-boundary 등)는 `/review`·`/code-review` 책임이며 여기서 복제하지 않는다.

| 차원 | 가중치 | 평가 기준 |
|------|--------|----------|
| Test Pass Rate | 25% | 전체 통과율? 100% 미만→상한 60 |
| Contract Match | 20% | API/인터페이스 spec 일치? 타입/응답/에러코드? |
| Error Resilience | 20% | 타임아웃/재시도/fallback/정책차단 각각을 **실제로 구동하는 fault-injection 테스트**(예외 주입·부분 실패·non-prod policy)가 있는가? 코드 존재만으로는 상한 60 |
| Data Flow | 15% | e2e 데이터 흐름이 의도대로? **실제 진입점(라우트/standalone orchestrator)을 통해** 검증되는가(helper 직접 호출로 진입점 배선을 우회하지 않음)? 손실/변형? |
| Deploy Readiness | 10% | 환경설정/의존성/빌드 문제? |
| Documentation | 10% | 사용법/API 문서 코드 동기화? |

## 채점 앵커

| 점수 | 의미 |
|------|------|
| 0-20 | 존재하지 않음 |
| 21-40 | 추상적으로만 언급 |
| 41-60 | 절반 이상 미충족 |
| 61-70 | 과반 충족, 중요 빈틈 1-2개 |
| 71-85 | 대부분 충족, 사소한 빈틈 |
| 86-95 | 모든 조건 + 추가 깊이 |
| 96-100 | 완벽 |

50은 "부족". 71이 "괜찮음"의 시작. 관대하지 마라.

TARGET 기본 70은 "괜찮음(71) 직전의 최소 합격선"이다 — 종합 70 도달만으로 끝나지 않도록 종료 조건의 "70 미만 차원 없음"이 실질 품질선을 앵커와 정렬한다.

# Refine Mode Tables

Load the matching table after mode confirmation.

## All `doc:*` Modes

Before dimension scoring for `doc:idea`, `doc:design`, `doc:spec`, `doc:plan`, `doc:skill`, or `doc:test`, run the mandatory structural audit, contract/stale-term audit, and Audit 3 open back-question pass from [refine-steps.md](./refine-steps.md). Carry the audit conclusions into dimension caps and completion gates.

| Audit finding | Affected dimensions | Cap / gate |
|---------------|---------------------|------------|
| Stale term leaks into active contract text without out-of-scope or migration-history isolation | the mode's consistency dimension, or `Self-Consistency` for `doc:skill` | cap `60` |
| One or more implementation hazard categories remain unidentified in active contract text | the mode's edge/failure/constraint dimension | cap `65` |
| Orphan first-class concept or duplicate peer contract restatement exists | the mode's structure/procedure dimension | cap `70` |
| Reader path is broken or circular | the mode's clarity/readability/self-consistency dimension | cap `70` |
| Removed field, enum, table, API route, or model concept remains active | completion forbidden even if the weighted score meets target | gate |
| Unresolved contract-level back-question from Audit 3 | the nearest completeness/edge/failure dimension | completion forbidden until answered or explicitly scoped |

Map the affected dimension to the loaded mode table before scoring. For example, use `Self-Consistency`, `Constraint Enforcement`, and `Procedure Rigor` in `doc:skill`; use `Architecture / Model Consistency`, `Completeness / Edge Cases`, and `Structural Coherence` in `doc:design`; use the closest named dimension in the other document modes. The implementation hazard check must explicitly cover reserved SQL/ORM names, mutable list index identity, unenforced invariants, ambiguous ID/URL encoding, and unbounded hot-row payloads.

## doc:idea

| Dimension | Weight | Evaluation Criteria |
|-----------|--------|---------------------|
| Problem Clarity | 25% | Is the affected user specific? Is there evidence for frequency or severity? |
| User Model | 25% | Is the target user defined in one sentence? Is the current workaround named? |
| Differentiation | 20% | Is at least one existing alternative named and contrasted? Is timing justified? |
| Feasibility | 15% | Are core technical risks listed with validation methods? |
| Scope | 15% | Are MVP inclusions and exclusions both explicit? |

## doc:spec

| Dimension | Weight | Evaluation Criteria |
|-----------|--------|---------------------|
| Requirements | 20% | Are acceptance criteria testable and free of vague words like "fast" or "appropriate"? |
| User Flow | 20% | Is the end-to-end flow ordered with clear inputs and outputs for each step? |
| Edge Cases | 20% | Are at least five exceptional scenarios covered with expected system behavior? |
| Measurability | 15% | Is there at least one KPI with a measurement method and decision timing? |
| Scope Boundary | 15% | Is there an explicit "not doing" list with decision rules? |
| Dependencies | 10% | Are external dependencies named with availability assumptions? |

## doc:plan

| Dimension | Weight | Evaluation Criteria |
|-----------|--------|---------------------|
| Goal Clarity | 20% | Is the goal clear in 1-2 sentences with done criteria? |
| Step Completeness | 25% | Are the steps complete, ordered by dependency, and tied to inputs and outputs? |
| Edge Cases | 20% | Are failure, rollback, boundary, empty-input, or concurrency cases covered? |
| API Surface | 15% | Are interfaces or signatures concrete enough to implement? |
| Dependency Awareness | 10% | Are dependent modules and impact areas identified? |
| Simplicity | 10% | Can steps or layers be removed without losing intent? |

## doc:skill

Use for AI-facing instruction files such as Codex skills, Claude slash commands, agent prompts, `AGENTS.md`, `CLAUDE.md`, and similar prompt documents. This is not `doc:plan`; prompt instructions need a quality model focused on execution reliability, constraints, and self-consistency.

| Dimension | Weight | Evaluation Criteria |
|-----------|--------|---------------------|
| Intent Clarity | 15% | Are purpose, trigger conditions, when-to-use/when-not-to-use, frontmatter description, modes, and parameters clear? |
| Procedure Rigor | 25% | Are steps complete with inputs, outputs, branches, gates, and stop conditions? |
| Constraint Enforcement | 20% | Are mandatory and forbidden behaviors explicit, including common failure modes like early stopping, delegating judgment, or invented metrics? |
| Edge/Failure Handling | 15% | Are ambiguous inputs, failures, exceptions, stalls, rollbacks, retries, user denial, and tool errors handled? |
| Tool & Agent Usage | 15% | Are tool calls, sub-agent rules, prompt templates, parallel/sequential criteria, and parameter parsing specific enough to execute? |
| Self-Consistency | 10% | Are terms, formats, examples, references, and cross-file paths consistent and non-conflicting? |

Special rules:
- dead references reduce Self-Consistency by `5` points each
- if a mandatory action has a bypass path, Constraint Enforcement is capped at `70`
- iterative skills need at least two stop conditions or Procedure Rigor is capped at `70`
- iterative refine-like skills must diagnose and apply a compatible batch of below-threshold weaknesses per round; if the skill still instructs single-weakness rounds without a conflict/blocker exception, Procedure Rigor and Self-Consistency are capped at `70`
- if a skill permits sub-agents, it must state when delegation is allowed and what each delegated task owns
- do not run project test/lint commands for pure instruction changes unless executable code is also changed

## doc:design

| Dimension | Weight | Evaluation Criteria |
|-----------|--------|---------------------|
| Problem Clarity | 10% | Is the problem explicit, with affected users and why now? |
| Reader / User Model | 10% | Are user behavior, context, decisions, and constraints clear enough for the target reader? |
| Structural Coherence | 20% | Do top-level sections each have a distinct purpose? Are first-class concepts given an owning section or explicit owner? Are peer concepts covered at the same abstraction level or intentionally grouped? |
| Architecture / Model Consistency | 20% | Are responsibilities separated, terminology stable, and data/API/control flows traceable end to end? |
| Feasibility / Risk | 15% | Is the design feasible in the current stack, with implementation deltas, external dependencies, migration risks, and validation methods called out? |
| Completeness / Edge Cases | 15% | Are error cases, ambiguity boundaries, lifecycle states, and not-doing decisions addressed? |
| Simplicity / Editorial Economy | 10% | Can sections, concepts, or layers be removed or merged without losing intent? Does the doc avoid redundant contract restatement? |

Special rules:
- `Structural Coherence` must use the mandatory structural audit from `refine-steps.md`.
- `Architecture / Model Consistency` must use the mandatory contract/stale-term audit from `refine-steps.md`.
- If a concept appears in the title, goals, entity/component list, API contract, or diagram, it is first-class unless the document explicitly marks it as derived, out-of-scope, or grouped under another section.
- A section like "Contract", "Overview", or "Detail" only earns structure credit if it has a unique reader job. If it merely repeats fields already owned by model/API/DB sections, merge or rename it.
- If the design introduces a new model component but lacks either a dedicated model section or an explicit grouping rule, `Structural Coherence` is capped at `65` and `Completeness / Edge Cases` is capped at `70`.
- If a removed field, enum, table, API route, or model concept appears as active contract text, `Architecture / Model Consistency` is capped at `60` and the document cannot pass until fixed or explicitly scoped as history/out-of-scope.
- If prose, SQL/DB schema, Pydantic/model snippets, API examples, diagrams, or implementation plan disagree about a first-class contract item, `Architecture / Model Consistency` is capped at `60`.
- If identifier, URL, or API path encoding rules can reasonably produce incompatible implementations, `Feasibility / Risk` is capped at `70`.
- If SQL reserved words, ORM-reserved attributes, or framework-reserved names are used without a clear alias/quoting policy, `Feasibility / Risk` is capped at `65`.
- If list/array index is used as durable identity for API routes, background jobs, link checkers, audit logs, or status rows, `Architecture / Model Consistency` is capped at `65`.
- If a prose invariant is not enforced by a model validator, DB constraint, repository/service gate, or explicitly assigned implementation layer, `Architecture / Model Consistency` is capped at `65`.
- If a JSON/raw/blob field in a hot row has no size/content boundary, `Feasibility / Risk` is capped at `70`.
- Audit 3 / back-question gate: if a first-class concept lacks a decision needed for implementation or operation, list the question in `OPEN QUESTIONS`. Unresolved core contract questions block completion even when all numeric dimensions meet target; unresolved operational questions cap `Completeness / Edge Cases` at `70`.

## doc:test

Test design documents must say which behavior is verified at which layer. Unit, integration, and e2e coverage are first-class, not optional prose.

| Dimension | Weight | Evaluation Criteria |
|-----------|--------|---------------------|
| Spec Coverage | 20% | Are all spec requirements covered and traceable? |
| Test Tier Coverage | 15% | Are unit, integration, and e2e layers mapped to each requirement or explicitly marked not applicable with reasons? Are state transitions and failure modes assigned to the right layer? |
| Edge Cases | 20% | Are boundary, exception, failure, empty-input, large-input, stale-state, convergence/stall, concurrent-pending, race, and external-write-failure cases covered at the right layer? |
| Independence | 10% | Can tests run independently and in any order? |
| Clarity | 15% | Is each test intent obvious from naming and structure? |
| Redundancy | 10% | Is duplicated assertion coverage minimized? |
| Maintainability | 10% | Can the suite evolve with limited changes and shared fixtures? |

Special rules:
- if the document does not map requirements across unit, integration, and e2e layers, `Test Tier Coverage` is capped at `60`
- if a layer is not applicable, the reason must be explicit; a blank cell is incomplete
- if state-machine transitions or quiet failure modes are not assigned to a test layer, `Edge Cases` is capped at `65`
- if a future `code` stage is expected to use TDD, the doc:test target should identify the RED source for each behavior; missing RED sources cap `Test Tier Coverage` at `70`

## code

| Dimension | Weight | Evaluation Criteria |
|-----------|--------|---------------------|
| Correctness | 25% | Does the code implement intended behavior correctly and match the spec? |
| Simplicity | 20% | Is the implementation the simplest coherent solution? Is the main path clear before edge cases? Are unnecessary abstractions, layers, options, state, indirection, cleverness, dead code, unused imports, future-only branches, deep nesting, boolean-mode behavior, repeated negations, and long condition chains avoided? |
| Readability | 15% | Are names and local control flow easy to follow? |
| Structure | 15% | Are responsibilities separated with limited duplication and clear ownership boundaries? |
| Error Handling | 5% | Are external or boundary failures handled with useful context? |
| Test Coverage | 10% | Is critical logic tested and passing? |
| Performance | 10% | Are obvious N+1, repeated I/O, or quadratic patterns avoided? |

Special rules:
- if tests are not passing, overall score is capped at `60`
- if required acceptance criteria are missing in implementation, the relevant correctness item is `0`
- if simpler code can remove a layer or branch without losing required behavior, `Simplicity` is capped at `70` until that option is considered or rejected with evidence
- if a reader must trace deep nesting, callback chains, repeated negations, or long `if`/`switch` chains to understand the main path, `Simplicity` is capped at `70` until the flow is flattened or a domain constraint justifies it
- if one function mixes parsing, branching, I/O, mutation, and formatting when those responsibilities can be split along domain rules, `Structure` is capped at `75` and `Simplicity` is capped at `70`
- if boolean flags or mode strings create multiple divergent behaviors inside one function, `Simplicity` is capped at `70` until separate named functions or a simpler dispatch shape are considered
- if TDD is active and a behavior item was implemented without RED evidence first, `Test Coverage` is capped at `70`
- if TDD is active and the final code round does not enumerate state-machine/failure-mode coverage before marking the following `test` stage not applicable, `Test Coverage` is capped at `70`
- if the issue closure ledger has any open applicable `critical` issue, overall score is capped at `60`
- if the issue closure ledger has any open applicable `important` issue, overall score is capped at `75`
- if a reviewer finding is marked fixed without file/line evidence and a targeted verification command or search sweep, treat it as open

## test

| Dimension | Weight | Evaluation Criteria |
|-----------|--------|---------------------|
| Spec AC Coverage | 30% | What share of acceptance criteria are covered by tests? If below `70%`, cap this dimension at `60`. |
| Branch Coverage | 20% | Are important branches covered with real evidence, preferably coverage output? |
| Edge Case Tests | 20% | Are failure, boundary, empty-input, scale, stale-state, convergence/stall, concurrent pending, race, and external-write-failure cases covered? |
| Failure-Mode Coverage | 15% | Are state-machine transitions and quiet failure modes enumerated from the implementation and mapped to tests, with no core path left as `NONE`? |
| Test Quality | 10% | Are tests deterministic, readable, independent, and well-structured? |
| Gap Resolution | 5% | Are uncovered acceptance criteria identified and closed, and is any test map synced? |

Special rules:
- if the issue closure ledger has any code-fixed issue without a regression test or explicit untestable rationale, overall score is capped at `70`
- if a test only proves the happy path while the issue was about an edge/error/concurrency case, that issue remains open
- if test evidence is not tied to issue IDs or acceptance criteria, `Gap Resolution` is capped at `60`
- if any core state-machine transition or quiet failure mode is left as `NONE`, completion is blocked even if the weighted score meets target
- if the state/failure table is omitted for stateful code, discard the test score and rerun scoring with the table
- if a new or strengthened test survives a feasible one-line mutation of the branch it claims to cover, keep that issue open and cap `Failure-Mode Coverage` at `70`

## integrate

| Dimension | Weight | Evaluation Criteria |
|-----------|--------|---------------------|
| Test Pass Rate | 25% | Are unit and integration checks both passing? If not, cap overall score at `60`. |
| Contract Match | 20% | Do interfaces, types, responses, and errors match documented expectations? |
| Error Resilience | 20% | Are timeout, retry, fallback, policy denial, partial failure, divergent values, and error propagation actually exercised through fault-injection tests, not just present in code? |
| Data Flow | 15% | Does end-to-end data move through the real entrypoint without loss or unintended mutation, instead of bypassing route/CLI/orchestrator/service wiring through direct helper calls? |
| Deploy Readiness | 10% | Are environment, dependency, and build concerns resolved? |
| Documentation | 10% | Are usage and API docs synced with the code? |

Special rules:
- if any applicable issue is not `integrated`, `not_applicable`, or `blocked` with evidence, overall score is capped at `75`
- if unit tests pass but schema/API/doc contracts are not checked against implementation, `Contract Match` is capped at `65`
- if stale terms or old API/schema names remain active in code, tests, migrations, docs, or route definitions, `Contract Match` is capped at `60`
- if integration evidence omits migration/backfill compatibility for a schema-changing issue, `Deploy Readiness` is capped at `65`
- if retry/fallback/error handling is only statically present and not exercised by fault-injection tests, `Error Resilience` is capped at `60`
- if tests bypass the public entrypoint and only call helpers, `Data Flow` is capped at `70`; if one side of a happy/failure branch pair is missing, cap `Data Flow` at `65`

## Scoring Anchors

| Score | Meaning |
|-------|---------|
| 0-20 | Absent |
| 21-40 | Mentioned only abstractly |
| 41-60 | More than half unmet |
| 61-70 | Mostly there with important gaps |
| 71-85 | Solid with minor gaps |
| 86-95 | Complete with extra depth |
| 96-100 | Essentially complete |

`50` is not "fine". `71` is the start of "acceptable". Be strict.

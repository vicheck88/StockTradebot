---
name: "refine"
description: "Iteratively evaluate and improve a document, skill, command, code area, test suite, or project status in Codex, using the updated Claude Code /refine batch-scoring model adapted for Codex. Use for repeated score-diagnose-propose-apply-rescore loops across idea, design, spec, skill, plan, code, test, and integrate modes when measurable quality, audit ledgers, or lifecycle refinement are requested."
---

# Refine

Iteratively evaluate and improve documents, prompt/skill instructions, code, tests, or integrated project state. The Sol Ultra main owns acceptance; an independent Sonnet Workflow reviewer and proposer supply read-only evidence and proposal text when available. A round is batch-oriented: diagnose every below-threshold or open issue, propose fixes for the whole compatible set, apply them together, then rescore.

Use `refine` only when the user wants measurable quality to improve over repeated rounds or across lifecycle stages. For a small code/test file that only needs quick score -> batch fix -> final review without doc audits, ledgers, or status files, use `refine-lite` instead. For a one-shot code review, debugging investigation, or known failing test fix, use the more specific review/debug/QA workflow instead.

## Hard Constraints

- Finish parameter parsing before doing other work.
- Require the active main session to be `gpt-5.6-sol:ultra` before PREP. If the known route is not Sol Ultra, stop before spawning work and ask the user to switch; if route metadata is unavailable, mark the gate unverifiable and do not claim Ultra executed.
- Do not improvise the procedure. Read [refine-steps.md](./refine-steps.md) at the start of every round and follow it; emit the required `ROUND_CHECK`.
- After mode confirmation, read [refine-modes.md](./refine-modes.md) and use that mode's weighted dimensions.
- If the target path is missing or empty after parameter parsing and the mode clearly supports creation, run the Step 0 bootstrap procedure before Round 1 scoring; do not score a nonexistent artifact.
- Do not fabricate metrics, coverage, pass rates, or implementation status. Unsupported claims score `0` for that dimension.
- Do not do single-lens scoring. Every SCORE must include a Codex `baseline scorer` view and an independent `reviewer scorer` view.
- Default `reviewer scorer` is the Sonnet Workflow wrapper at `$CODEX_HOME/skills/refine/scripts/claude-review.sh` (fall back to `$HOME/.codex/skills/refine/...`) when `claude`, `jq`, and Workflow are available. A direct single-model Claude answer is not a valid reviewer result.
- For each proposal batch, attempt the paired Sonnet Workflow proposer at `$CODEX_HOME/skills/refine/scripts/claude-propose.sh` when that wrapper is installed; verify its presence during tool check. It returns proposal text only. The assigned Codex writer alone edits target files.
- The installed wrappers default to `1800` seconds; an invocation may lower that only when the user explicitly sets the timeout. If a local execution policy requires a tighter cap, record that override rather than silently weakening the workflow.
- If Workflow is unavailable, times out, returns invalid/non-Sonnet output, or cannot inspect the target, use the documented independent Codex adversarial fallback and record the exact reason.
- Do not claim Claude reviewed unless the Claude review command succeeded and its output was used in Phase 2 Cross-Review.
- Sol Ultra may assign only the declared bounded prep, audit, scorer, proposer, writer, adjudicator, verifier, and reviewer roles. Each owns one concrete lane; Claude Workflow is a CLI reviewer/proposer, not a Codex sub-agent.
- A round must be batch-based. Identify all dimensions/questions below `70`, all unresolved audit failures, and all open applicable issue-ledger items; propose and apply all compatible fixes in the same round. A single-weakness round is valid only when fixes conflict, the user narrowed `FOCUS` to one item, or a blocker makes the other items impossible; record that reason.
- For every `doc:*` mode, scoring must include a structural audit before dimension scoring: section map, first-class concept map, orphan/duplicate section check, peer coverage check, and reader-path check. A doc score that only checks field/API/code consistency is invalid.
- For every `doc:*` mode, scoring must include a contract/stale-term audit after the structural audit: identify active contract terms, removed or out-of-scope terms, schema/API/Pydantic examples, and run a text sweep for stale terms across the target and peer docs. This audit must also check implementation hazards such as reserved SQL/ORM names, mutable list index identity, unenforced invariants, ambiguous ID/URL encoding, and unbounded hot-row payloads. A doc score that misses a prose/schema contradiction or predictable implementation trap is invalid.
- For every `doc:*` mode, run Audit 3: derive open back-questions for missing decisions required to implement or operate each first-class concept. Unresolved contract-level back-questions block completion; do not invent answers.
- A `doc:*` target cannot be marked complete while a removed field, enum, table, API route, or model concept still appears as active contract text outside an explicit out-of-scope or migration-history note.
- For `code`, `test`, and `integrate`, every applicable reviewer finding, user-raised issue, and unresolved contract hazard must be tracked in an issue closure ledger. A stage cannot pass while an applicable issue remains open without concrete code, test, and integration evidence, or an explicit blocker/not-applicable rationale.
- For `code`, `test`, and `integrate`, Simplicity scoring must include a cognitive-complexity pass: inspect nesting depth, long condition chains, boolean flags or mode strings that create divergent behavior, mixed responsibilities inside one function, repeated negations, unnecessary mutable state, and future-only branches. Cap or diagnose the relevant Simplicity/Readability/Structure dimension until the simpler equivalent is applied or rejected with evidence.
- Before the first SCORE, run the Codex PREP step from [refine-steps.md](./refine-steps.md): package context with a unique `RUN` token, launch any available read-only prep/audit work, and emit `PREP_CHECK`. If a prep job is unavailable, record the failure and continue with inline context; missing prep is not a stop reason.
- Use `MODEL_POLICY` only as role-to-model routing input. It never overrides evidence requirements, stop gates, or the final score owner. Use Luna for prep/scouting, Terra for audit/scoring/proposal/writing, Sol xhigh for adjudication/verification/final review, and Sol Ultra only for the main.
- For `code` mode, set TDD automatically when design/spec/test artifacts exist unless the user passes `--no-tdd`. With TDD active, capture RED before GREEN and emit `TDD_CHECK`; skipped RED caps Test Coverage as defined in [refine-modes.md](./refine-modes.md).
- A dimension held exactly at `70` by an audit, verification, TDD, or issue-ledger cap is not completion-ready; diagnose the capped finding until the dimension can rescore above the cap or the item is explicitly blocked/not applicable.
- If the procedure itself must change, update the skill files first, tell the user, then follow the updated procedure.

## Modes

Primary modes:
- `doc:idea`
- `doc:design`
- `doc:spec`
- `doc:plan`
- `doc:skill`
- `doc:test`
- `code`
- `test`
- `integrate`

Meta modes:
- `doc`
- `next`
- `auto`

When the user says `idea`, `spec`, `plan`, `design`, or `test` for a document target, normalize to the matching `doc:*` mode. When the user explicitly says `doc` or `--mode doc`, treat it as a meta mode: infer the safest concrete `doc:*` mode from the target path/content before loading dimensions. Do not score directly as `doc`.

Use `doc:skill` for AI-facing instruction files such as Codex skills, Claude slash commands, agent prompts, and `CLAUDE.md`/`AGENTS.md` sections. Do not score those as `doc:plan`; plan dimensions such as API surface and dependency awareness are usually the wrong quality model for prompt instructions.

## Parameter Parsing

Accepted patterns:
- `refine <path>`
- `refine <path> --mode doc`
- `refine <path> --mode doc:spec`
- `refine <path> --mode doc:skill`
- `refine <path> --mode code --target 85`
- `refine <path> --mode code --rounds 5`
- `refine <path> --mode code --reviewer claude-auto`
- `refine <path> --mode code --reviewer codex`
- `refine <path> --mode code --focus correctness,test-coverage`
- `refine <path> --mode code --model-policy codex-scorer=gpt-5.6-terra:xhigh`
- `refine <path> --mode doc:skill --model-policy codex-prep=gpt-5.6-luna:low`
- `refine <path> --mode integrate --model-policy codex-main=gpt-5.6-sol:ultra`
- `refine <path> --mode code --model-policy claude-proposer=sonnet:xhigh`
- `refine <path> --mode code --tdd`
- `refine <path> --mode code --no-tdd`
- `refine . --mode integrate`
- `refine --mode next`
- `refine --mode auto`
- `refine --from code`
- `refine --from code --to integrate`

Extract from the user request:
- `DOC_PATH`: from explicit `--path @/path` or `--path path`, otherwise an existing file or directory mentioned in the request, otherwise a mode-default path, otherwise resolve by glob/search. For multiple matches, prefer longest argument match, then most recently modified, then ask one narrow question. For no match, use the clear mode-default path as a bootstrap target only when the user asked to create/refine that artifact; otherwise ask.
- `MODE`: explicit `--mode`, otherwise infer from path first, then content. If explicit mode is `doc`, resolve it to a concrete `doc:*` mode using the inference priority before scoring.
- `TARGET_SCORE`: default `70`
- `MAX_ROUNDS`: explicit `--rounds`, otherwise a project/user rule if one is already loaded and unambiguous, otherwise `50`
- `SCORE_ONLY`: score without editing; still run Step 0, doc:* audits, SCORE, final cleanup, and append a `[score-only]` marker with scores to the log
- `FOCUS`: comma-separated dimensions to prioritize
- `REVIEWER`: `claude-auto` by default; `claude-auto` and `claude` attempt Claude Code first then fall back to Codex adversarial scoring; `codex` skips Claude and uses Codex-only scoring
- `MODEL_POLICY`: optional role-to-model routing hints; Claude reviewer/proposer routes require Sonnet and the rightmost repeated role wins
- `TDD`: `--tdd` forces TDD on, `--no-tdd` forces it off, otherwise infer from code mode plus available design/spec/test artifacts
- `AUTO_CONTINUE`: default `true`; if the user asks before each round or uses `--ask`, set `false`
- `FROM`, `TO`: optional lifecycle range
- `RESET`: reinitialize tracking

Default path mapping:
- `code` or `test`: `packages/`
- `integrate`: `.`
- `doc:skill`: no default; require an explicit file/path or resolve by search from the request
- other `doc:*`: `docs/{mode-name}.md`

Mode inference priority:
1. Codex skills, Claude commands, agent prompts, `AGENTS.md`, `CLAUDE.md` instruction sections -> `doc:skill`
2. test strategy or test-plan documents -> `doc:test`
3. source-code paths -> `code`
4. test implementation paths or filenames -> `test`
5. repo root `.` -> `integrate`
6. files mentioning requirements, PRD, or acceptance criteria -> `doc:spec`
7. files mentioning architecture, components, or data flow -> `doc:design`
8. files mentioning milestones, rollout, or implementation sequence -> `doc:plan`
9. files mentioning idea, concept, problem, or opportunity -> `doc:idea`
10. otherwise make the safest reasonable choice and state it briefly

## Reset / Next / Auto

`--reset`:
1. append a `[RESET]` marker to the applicable `.refine.log` or `<target-base>.refine.log` if the log exists
2. reset tracked status in `STATUS.md` or `<target-base>.STATUS.md` if the project uses it
3. if combined with `--from`, `--to`, or `--mode`, continue immediately after reset

Natural lifecycle order:
`doc:idea -> doc:design -> doc:spec -> doc:plan -> code -> test -> integrate`

`doc:test` is an optional design artifact between `doc:plan` and `code` when a test strategy document already exists, the user requests it, or TDD-first new feature work needs it. `doc:skill` is standalone unless the target project explicitly lists it in status.

Rules:
- `doc:skill` is a standalone documentation mode for AI-facing instructions; it is not part of the product delivery lifecycle unless the target project explicitly lists it in `STATUS.md`
- `STATUS.md`, when present, should contain lifecycle stage names and enough status text to classify each as incomplete, complete, blocked, or not applicable; if the format is unclear, inspect nearby docs and state the inference before proceeding
- `next`: execute the first incomplete stage from `STATUS.md`; if there is no usable `STATUS.md`, infer the first incomplete lifecycle stage from existing target files and report that no status file was available
- `auto`: run all incomplete stages, or only the `FROM..TO` range if provided. A stage with blocking open questions remains incomplete, but `auto` may continue to later stages with the blocker recorded.
- `--from` without `--to`: run from that mode to the natural end of the lifecycle
- `--to` without `--from`: run from the first lifecycle mode through that mode
- after each stage, update `STATUS.md` when the project clearly uses it; for shared instruction directories, keep per-target log/status files such as `<target-base>.refine.log` and `<target-base>.STATUS.md`
- after `integrate`, perform up to three `REGRESSION_PASS` checks over completed stages before declaring `auto` complete. A regression pass checks status/log consistency, score gates, stale active contract terms, open questions, missed tests/lint, cross-doc drift, and stage-to-stage assumption conflicts; any found regression is injected into the owning stage's next DIAGNOSE as `REGRESSION_ISSUE`.

## Round Loop

```text
Step 0: initialization
  - confirm MODE
  - if DOC_PATH is missing or empty and the mode supports creation, run Step 0 bootstrap from refine-steps.md, write the selected initial artifact, then begin Round 1
  - read the target
  - read refine-modes.md and load the dimension table for MODE
  - read refine-steps.md and perform the mode-critical tool check
  - resolve effective routes and emit `MODEL_ROUTE_CHECK`, then run Step 0 PREP from refine-steps.md
  - for code or integrate modes, run the most relevant tests and lint checks early
  - determine the log path

while round < MAX_ROUNDS:
  - read refine-steps.md again and emit ROUND_CHECK with line count and mtime/stat evidence
  - SCORE
  - if SCORE_ONLY, stop after reporting
  - if SCORE already satisfies all stop gates, skip DIAGNOSE/PROPOSE/APPLY and finalize with Result=SKIP
  - DIAGNOSE
  - PROPOSE
  - APPLY
  - continue unless a real stop condition is met

Finalize:
  - append the round summary to .refine.log
  - emit the final report
```

Pass only when:
- weighted score >= target and no dimension is below `70`
- no dimension is stuck at an audit, verification, TDD, or issue-ledger cap of exactly `70`
- no doc:* stale active contract or unresolved contract-level back-question blocks completion
- issue-ledger statuses are mode-compatible: `fixed|tested|integrated` for `code`, `tested|integrated` for `test`, `integrated` for `integrate`, or evidence-backed `not_applicable`

Non-passing termination is `STOPPED_AT_MAX_ROUNDS` or `BLOCKED`; never report either as complete.

Do not stop just because improvements are harder, the score seems "good enough", tool setup is inconvenient, or progress is slow. If progress stalls for three rounds, shift focus. If the score oscillates on one dimension for four rounds, deprioritize that dimension and continue.

## Editing Rules

- Each round should target the full compatible set of weaknesses found by DIAGNOSE.
- If two fixes conflict, apply the higher-priority fix first and keep the deferred fix visible in the next DIAGNOSE instead of asking whether to continue.
- Preserve user intent unless the structure itself is the root problem.
- For code mode, prefer real fixes over cosmetic edits when correctness is weak, then run a simplification pass: flatten guardable branches, split mixed-responsibility functions, remove dead or future-only paths, replace unclear boolean-mode behavior with named functions when behavior diverges, and keep abstractions only when they reduce actual branch/state complexity.
- For document modes, improve precision, falsifiability, edge-case coverage, and dependency clarity rather than adding filler.
- For `doc:skill`, improve instruction clarity, gates, failure handling, tool usage, and self-consistency rather than adding generic prose.
- For test mode, avoid changing source code unless the user explicitly broadens scope.

## Output

During use, report:
- current mode
- reviewer path: `claude`, `codex fallback`, or `codex`
- current score and target
- the below-threshold dimensions/questions and open audit/ledger items selected for the batch
- what changed this round, grouped by weakness
- the new score or the residual blocker

Final report shape:

```text
=== REFINE <PASSED|STOPPED_AT_MAX_ROUNDS|BLOCKED|SCORE_ONLY> (<MODE>) ===
verdict: <passed|target not reached|exact blocker|score only>
start: <initial>/100 -> final: <final>/100 (<delta>)
rounds: <completed>/<attempted> (rollbacks <n>)
dimensions: <dimension start -> final (delta)>
```

## Safety

- Never claim objective precision. Scores are strict heuristics for iteration.
- Do not edit unrelated files to chase score gains.
- If external systems or missing requirements block further progress, stop and state the blocker clearly.

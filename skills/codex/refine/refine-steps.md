# Refine Steps

Read this file at the start of every round. Do not rely on memory for the current round procedure.

At the start of every round emit:

```text
ROUND_CHECK:
- refine-steps.md reread: round=<N>, lines=<wc -l>, mtime=<stat value>
- mode dimensions loaded: <MODE> from refine-modes.md
```

If `ROUND_CHECK` is missing, discard the SCORE for that round and rerun it.

## Step 0 Tool Check

Run Step 0 PREP first, because read-only prep can run while tool checks continue. Missing tools are not a valid reason to skip refinement; install or configure them when the environment and permissions allow it. If approval or sandboxing blocks setup, record that as a blocker with the exact command/error and continue scoring with the missing-tool penalty.

Before the first round, verify mode-critical tools. Missing tools are not a valid reason to skip refinement. Install or configure them when the environment and permissions allow it; if approval or sandboxing blocks setup, record that as a blocker with the exact command/error.

Examples:
- `test`: coverage tooling such as `@vitest/coverage-v8`
- `code` or `integrate`: lint and formatter commands used by the project
- `code`: lockfile consistency checks when the project depends on them
- all modes unless `REVIEWER=codex`: the Sonnet Workflow review wrapper at `$CODEX_HOME/skills/refine/scripts/claude-review.sh` and, when present, the paired `claude-propose.sh` proposer, plus local `claude` and `jq`; their default timeout is `1800` seconds unless the user overrides it

Report the result in this shape:

```text
TOOL_CHECK:
- <tool>: installed (<version or command>)
- <tool>: missing -> installed (<version or command>)
- <tool>: blocked (<reason and next action>)
- claude-ultracode: available (<claude --version>; Sonnet Workflow + jq; timeout 1800s or configured override) or unavailable (<reason>) -> codex fallback, or skipped (--reviewer codex)
```

## Step 0 Bootstrap Creation

If parameter parsing resolved a `DOC_PATH` but the file is missing or empty, bootstrap only after `MODE` is confirmed. Skip this section when the file already contains usable content.

Rules:
- Bootstrap is valid for `doc:*`, `code`, and `test` only when the user asked for creation/refinement of that artifact or the mode-default path is unambiguous.
- Create the smallest initial artifact that can be honestly scored in Round 1. Do not mark bootstrap output as complete or skip scoring.
- If Claude review is available and the target is high-risk or ambiguous, ask Claude for a read-only alternative outline through `scripts/claude-review.sh` and compare it with the Codex draft before writing. If Claude is unavailable, continue with the Codex draft and record the fallback.
- If user input is required to choose between materially different bootstrap directions, ask one narrow question. Otherwise choose the simpler artifact that best matches the user's stated goal and record the rationale in the round log.
- Treat bootstrap as Round 0. `MAX_ROUNDS` starts at Round 1 after the file exists.

Emit:

```text
BOOTSTRAP_CHECK:
- target: <DOC_PATH> (<missing|empty>)
- mode: <MODE>
- candidate review: claude (<summary>) | codex-only (<reason>)
- result: wrote initial artifact; Round 1 will score it
```

## Step 0 PREP

Before the first SCORE, prepare reusable context and emit `PREP_CHECK`.

1. Choose one `RUN` token for the whole refine run. Use that token in every temporary path so concurrent refine sessions cannot read each other's stale files:

```sh
RUN="${RUN:-$(date +%s)$$}"
CTX="/tmp/refine_ctx_${RUN}.txt"
DIFF="/tmp/refine_ctx_${RUN}.diff"
PREP_OUT="/tmp/codex_prenotes_${RUN}.md"
AUDIT_OUT="/tmp/codex_audit_${RUN}.md"
```

2. Build an inline context package. Prefer a diff when refining changed work; otherwise concatenate the target files. Keep the package around `150KB` or smaller when practical.
3. Sol Ultra authorizes one bounded read-only Luna prep lane (and Terra audit lane for doc modes). The prep task writes `PREP_OUT`; code/integrate scouting folds into prep. If the independent lane is unavailable, mark it unavailable and continue from deterministic context.
4. Never use fixed names such as `/tmp/refine_ctx.txt`, `/tmp/codex_prenotes.md`, or `/tmp/codex_audit.md`.
5. Treat a completed prep job with an empty output file as failed. Do not reuse stale or empty prep output.

Emit exactly one line per role:

```text
PREP_CHECK:
- codex-prep: launched (<task id>) | unavailable (<reason>) | skipped (--reviewer codex or delegation unavailable)
- codex-audit: launched (<task id>) | unavailable (<reason>) | n/a (non-doc mode)
- context package: <path> (<bytes> bytes)
```

When prep output is available, prepend it to later scorer/proposer/verifier prompts. If prep is not available by SCORE time, score from the context package directly; do not block indefinitely.

## Step 0 Context Package

Before the first SCORE, build a compact evidence package when the target spans multiple files, a diff, or a repo area. This reduces repeated exploration and gives the baseline and reviewer scorers the same evidence surface.

Preferred package contents:
- target path list and mode
- relevant file excerpts or full files when the package remains manageable
- current git diff for the target, when the task is about changed work
- prior `.refine.log` entries or `STATUS.md` lines that affect the target
- relevant test/lint command names and the latest observed results

Use existing files and commands to produce the package; do not create persistent repo files for temporary context. Use `RUN`-scoped names such as `/tmp/refine_ctx_${RUN}.txt` or `/tmp/refine_ctx_${RUN}.diff`. If the package would exceed roughly `150KB`, include the critical files inline and list secondary paths for selective inspection.

For round `2+`, do not force every scorer to rediscover the whole target. Provide the previous dimension scores, the previous DIAGNOSE batch, and the round diff. Ask scorers to rescore affected dimensions and keep unaffected dimensions unchanged unless they find evidence that the previous score was wrong.

## MODEL_POLICY and TDD

`MODEL_POLICY` is routing input only. Parse repeated `role=model[:effort]` values with the rightmost entry winning. Claude reviewer/proposer roles require Sonnet (`high` for doc modes, `xhigh` otherwise); `codex-main` is always `gpt-5.6-sol:ultra`. Reject unknown roles, non-Sonnet Claude routes, and unsupported efforts rather than silently ignoring them.

Required default routes:

| Role | Default model | Default effort | Notes |
|------|---------------|----------------|-------|
| `claude-reviewer` / `claude-proposer` | `sonnet` | `high` doc / `xhigh` code | Workflow only; proposal text never edits targets |
| `codex-main` | `gpt-5.6-sol` | `ultra` | required orchestrator and final acceptance owner |
| `codex-prep` / `codex-scout` | `gpt-5.6-luna` | `low` | one reusable prep lane |
| `codex-audit` / `codex-scorer` / `codex-proposer` / `codex-writer` | `gpt-5.6-terra` | `high` doc / `xhigh` code | bounded work lanes |
| `codex-adjudicator` / `codex-verifier` / `codex-reviewer` | `gpt-5.6-sol` | `xhigh` | independent evidence and final-diff lanes |

Do not route leaf roles to Ultra or substitute the main when an independent lane fails. Each leaf has one 1800-second deadline and one replacement; report it unavailable after a second failure.

When using the Codex companion CLI for a role with a default or user-selected model/effort, pass routing as runtime flags, not prompt text:

```sh
node "$CODEX_SCRIPT" task --background --write \
  --model <model> --effort <effort> \
  "<prompt>"
```

Omit `--model` or `--effort` when no value is selected, the companion route is unavailable, or the role is not a Codex companion task. The companion accepts `spark` as an alias for `gpt-5.3-codex-spark`; other model names should be passed through exactly. If a requested model or effort is rejected by the runtime, record the exact error, retry once with that role's default, then retry once without `--effort` before treating that companion role as unavailable.

For `code` mode, infer TDD when design/spec/test artifacts exist unless the user passes `--no-tdd`; `--tdd` forces it on. Detection priority is: the current lifecycle `STATUS.md`, then `docs/test.md`, `docs/spec.md`, `docs/design.md`, then a focused search for nearby test/spec/design artifacts. Emit `TDD_MODE: ON (<source>)`, `OFF (no design/spec/test artifact)`, or the explicit flag source.

With TDD active:

1. Capture RED first through the cheapest faithful channel.
2. Apply the smallest GREEN change.
3. Refactor only after the test is green.
4. Emit:

```text
TDD_CHECK:
- red: <command/artifact or n/a with reason>
- green: <command/artifact>
- refactor: <none|summary>
```

If TDD is active and a behavior item lacks RED evidence, apply the caps in `refine-modes.md`.

## Codex CLI Job Result Rules

When a Codex companion CLI job is used for prep, scoring, proposing, verifying, or reviewing, it is a background CLI job, not a conversational reviewer. Give it a unique output file such as `/tmp/refine_<role>_r<N>_${RUN}.md`.

Required handling:
- remove only that exact output file before launch
- pass the absolute output path in the prompt
- poll with a finite timeout
- accept the job only when the output file is non-empty and structurally complete
- treat `EMPTY RESULT`, timeout without complete output, failed, cancelled, or stalled jobs as unavailable and continue with the other reviewer path
- never use a task summary as the review result when the output file is empty
- clean up only files matching the current `RUN`
- for code/test targets, instruct companion jobs to write only to `OUTFILE` and never edit repository files directly; if a companion job unexpectedly modifies target files, cancel it, report an isolation violation, and continue with the trusted local path without silently keeping those edits

## SCORE

Use a two-phase score. Single-lens scoring is not acceptable.

### Mandatory Structural Audit for `doc:*`

Before Phase 1 scoring for any `doc:*` mode, both scorers must build a compact structural audit. This audit is required evidence, not optional commentary.

Required checks:
- **Section map**: list top-level sections and state each section's unique job in one phrase. Flag any section whose job is only "repeat/summarize other sections" unless it is explicitly an overview or appendix.
- **First-class concept map**: list concepts named in the title, goals, component list, data model, or API contract. Each first-class concept must have either its own section or an explicit pointer to the section that owns it.
- **Peer coverage check**: if a section lists peer components (for example source/provenance/sync/custom, tables, services, APIs), verify all comparable peers are covered at the same abstraction level or explain why they are intentionally grouped.
- **Reader-path check**: verify a reader can move from problem -> concepts -> model -> flows -> edge cases without encountering an unexplained section, missing concept owner, or surprise implementation detail.

Structural cap rules:
- If a first-class concept is introduced but has no owning section or explicit owning subsection, cap the mode's completeness/edge/failure dimension at `65` and its structure/procedure dimension at `70`.
- If a standalone section has no distinct job, cap the mode's structure/procedure/simplicity dimension at `75` until it is removed, renamed, or merged.
- If peer components are represented unevenly without a stated grouping rule, cap the mode's architecture/structure/procedure dimension at `70`.
- If the score report omits the structural audit in a `doc:*` mode, discard the score and rerun scoring.

### Mandatory Contract / Stale-Term Audit for `doc:*`

After the structural audit and before dimension scoring, both scorers must run a contract/stale-term audit. This is required even when the document is prose-heavy.

Required checks:
- **Active contract inventory**: list fields, enums, tables, APIs, identifiers, routes, diagrams, Pydantic/classes, SQL schemas, and named components that the document currently treats as valid.
- **Retired-term inventory**: infer terms that were removed, renamed, marked out-of-scope, or contradicted by current schema/examples. Use user feedback, recent diffs, out-of-scope lists, and schema/Pydantic/API tables as evidence.
- **Text sweep**: search the target and relevant peer docs for retired terms and old route/model names. Inspect each hit. Classify it as active contradiction, allowed history/out-of-scope mention, or false positive. Do not rely on memory; use a search command such as `rg`.
- **Contract matrix**: for each first-class data/interface concept, compare prose, SQL/DB schema, Pydantic/model snippets, API examples, diagrams, and implementation plan. A field/table/enum/route present in one contract surface but absent from peers must be either fixed or explicitly scoped.
- **Identifier/API encoding check**: when IDs, URLs, path params, or derived URIs are part of the target, verify display identifiers and HTTP path/query encodings are unambiguous and consistently named.
- **Implementation hazard check**: inspect contract names and identity schemes for predictable implementation traps:
  - SQL reserved words or fragile unquoted identifiers used as table/column names.
  - ORM/framework-reserved attribute names such as SQLAlchemy `metadata`.
  - Mutable array/list positions used as durable identity in APIs, background jobs, status tables, or audit logs.
  - Invariants stated in prose but not enforced by the shown model, validator, DB constraint, repository/service gate, or explicit implementation responsibility.
  - Size/unbounded payload risks for JSON/raw/blob fields that live in hot rows.

Contract cap rules:
- If a removed or out-of-scope term appears as active contract text, cap the mode's consistency/self-consistency dimension at `60` and its completeness/edge/failure dimension at `65` until removed or explicitly scoped.
- If prose says a field/table/enum/route exists but SQL/Pydantic/API contract omits it, cap the mode's consistency/self-consistency dimension at `60`.
- If SQL/Pydantic/API contract includes a field/table/enum/route that prose says is removed, cap the mode's consistency/self-consistency dimension at `55`.
- If an ID/URL/path encoding rule is ambiguous enough to produce two plausible implementations, cap the mode's feasibility/risk/failure-handling dimension at `70`.
- If a SQL/ORM/framework reserved identifier is used without an explicit alias/quoting policy, cap the mode's feasibility/risk/failure-handling dimension at `65`.
- If mutable list index is used as stable API/background-job/audit identity, cap the mode's consistency/self-consistency dimension at `65` and its feasibility/risk/failure-handling dimension at `70`.
- If a documented invariant lacks any enforcement location, cap the mode's consistency/self-consistency dimension at `65`.
- If a JSON/raw/blob field in a hot row has no size/content boundary, cap the mode's feasibility/risk/failure-handling dimension at `70`.
- If the score report omits this audit in a `doc:*` mode, discard the score and rerun scoring.

### Audit 3: Open Back-Questions for `doc:*`

After structural and contract/stale-term audits, identify missing decisions that a real implementer or operator would need answered. This is required for every `doc:*` mode, even when the document is internally consistent.

For each first-class concept or section, ask:
- What behavior, owner, boundary, lifecycle state, field meaning, API encoding, failure policy, or rollout decision is implied but not specified?
- Would two reasonable implementers make incompatible choices from the current text?
- Is the missing decision core contract, operational policy, or optional future detail?

Emit:

```text
OPEN QUESTIONS:
- Q<n>: <back-question>; owner=<section/concept>; impact=<contract|operation|future>; status=<open|answered|out-of-scope>
```

Completion gates:
- any unresolved contract-level back-question blocks completion
- any open operational back-question caps the nearest completeness/edge/failure dimension at `70`
- future-detail questions may be marked out-of-scope with evidence
- AUTO_CONTINUE does not allow inventing answers; surface the question or mark it explicitly out-of-scope

Question handling:
- Batch open questions at round boundaries, at most four at a time.
- First try to answer from existing user instructions or peer docs with file/line evidence.
- If no answer exists, expose the question and keep improving non-conflicting items; do not block the round waiting for an answer.
- A blocking question prevents marking the doc stage complete until answered or explicitly scoped out.

### Phase 1: Independent Scoring

Produce two score views for the same target and dimensions:
- `baseline scorer`: Codex straightforward quality assessment
- `reviewer scorer`: Claude Code review by default; if Claude is unavailable or `REVIEWER=codex`, use Codex local adversarial scoring that attempts to falsify claims, find missing support, and punish ambiguity

If the user explicitly authorized delegation or asked for parallel agent work, extra scorer or verifier work may use bounded Codex sub-agents. Otherwise do not spawn Codex sub-agents without explicit authorization. Claude Code review is invoked through the CLI wrapper and does not count as a Codex sub-agent.

#### Claude Reviewer Default

When `REVIEWER` is `claude-auto` or `claude`, attempt Claude before local adversarial fallback:

1. Build a concise read-only prompt containing `MODE`, target path, round number, dimensions with weights, scoring anchors, the context package or delta package, and the exact evidence requirement.
2. Run [scripts/claude-review.sh](./scripts/claude-review.sh) from this skill directory or by absolute path. Let its default timeout remain `1800` seconds unless the user explicitly overrides `CLAUDE_REVIEW_TIMEOUT_SECONDS`. The wrapper must use the Sonnet Workflow route; reject `CLAUDE_REVIEW_MODEL` values other than `sonnet` rather than silently routing to another model.
3. Treat exit `0` with parseable dimension scores as the `reviewer scorer`.
4. Treat exit `11` as a caller/prompt error, not as reviewer unavailability: fix the prompt or wrapper invocation, then rerun the reviewer before scoring.
5. Treat missing CLI, auth failure, timeout, exit `10`, empty output, unparseable scores, or `UNAVAILABLE` output as unavailable and immediately run Codex local adversarial scoring instead.
6. Never stop refinement solely because Claude is unavailable.

Claude prompt template:

```text
You are the independent reviewer for Codex /refine.
Read-only: do not edit files, do not run mutating commands, do not change git state.
Target: <DOC_PATH>
Mode: <MODE>
Round: <N>
Dimensions and weights:
<dimension table>
Context package:
<target excerpts, relevant diff, prior scores, or path list; for round 2+ include prior scores and this round's diff>

Task:
1. Inspect the target and relevant source/test files if needed.
2. For doc modes, first produce the mandatory structural audit: section map, first-class concept map, peer coverage check, and reader-path check.
3. For doc modes, also produce the mandatory contract/stale-term audit: active contract inventory, retired-term text sweep, prose/schema/API/Pydantic/diagram consistency matrix, ID/API encoding check when applicable, and implementation hazard check for reserved names, unstable list identity, unenforced invariants, and unbounded raw payloads.
4. For code/test/integrate modes, produce the issue closure ledger: reviewer/user/contract findings, status, and evidence. Treat any fixed/tested/integrated claim without evidence as open.
5. Score each dimension 0-100 using only evidence you can verify.
6. Punish ambiguity, unsupported claims, missing tests, dead references, orphan sections, missing concept owners, uneven peer coverage, stale active terms, prose/schema contradictions, reserved-name traps, mutable-index identity, unenforced invariants, unbounded hot-row payloads, high cognitive complexity, and open issue closure items.
7. For round 2+, rescore dimensions affected by the diff and keep unaffected dimensions unchanged only when the prior evidence still applies.
8. If you cannot inspect enough evidence, write UNAVAILABLE: <reason>.

Return exactly:
CLAUDE_REVIEW:
- structural_audit: "<section/concept/peer/reader-path findings; one compact paragraph>"
- contract_audit: "<active contract, retired-term sweep, matrix, encoding, and implementation hazard findings; one compact paragraph>"
- issue_closure: "<code/test/integrate only; issue ids/status/evidence/open gaps; otherwise n/a>"
- <dimension> (<weight>%): <score>/100 "<evidence>"
- overall_risk: "<one sentence>"
```

Codex adversarial fallback must use the same dimensions and evidence requirements. Produce this shape:

```text
CODEX_ADVERSARIAL_REVIEW:
- structural_audit: "<doc modes only; otherwise n/a>"
- contract_audit: "<doc modes only; otherwise n/a>"
- issue_closure: "<code/test/integrate only; otherwise n/a>"
- <dimension> (<weight>%): <score>/100 "<evidence that attempts to falsify the baseline score>"
- overall_risk: "<one sentence>"
```

Codex must still own the final score, diagnosis, edits, and final report.

Each scorer must:
1. read the target
2. break each dimension into concrete questions
3. score each question `0-100`
4. provide evidence per dimension
5. for `code`, `test`, or `integrate`, read the relevant source/test files and check actual implementation

Bounded Codex sub-agents, when explicitly authorized by the user, must be read-only unless assigned to implement one named APPLY item, must receive the target paths plus the current context package, must own only one role (`scorer`, `verifier`, or `reviewer`), and must return the same output contract as the corresponding local phase. Do not let a sub-agent decide final scores, stop conditions, or whether a finding is closed.

Scoring anchors:
- `0-20`: absent
- `21-40`: only abstract mention
- `41-60`: more than half unmet
- `61-70`: mostly there, but important gaps remain
- `71-85`: solid with minor gaps
- `86-95`: complete with extra depth
- `96-100`: essentially complete

Unsupported numbers or fabricated evidence force that dimension to `0`.

### Mandatory Issue Closure Ledger for `code`, `test`, and `integrate`

Before scoring any `code`, `test`, or `integrate` round, build or refresh an issue closure ledger. The ledger turns reviewer comments into tracked closure work, not optional commentary.

Inputs:
- latest Claude/Codex review findings from current and previous refine rounds
- user-raised issues since the last completed stage
- unresolved contract/stale-term or implementation-hazard findings from `doc:*` rounds
- failing tests, refine-created TODOs, and `.refine.log` items still marked open
- unresolved `[unverified-carryover]`, `[score-only]` gaps, or `REGRESSION_ISSUE` items from previous stages

Each ledger item must include:
- `id`: stable short id such as `ISSUE-001`
- `severity`: `critical`, `important`, or `minor`
- `summary`: concrete defect or missing behavior
- `stage`: one or more of `code`, `test`, `integrate`
- `status`: `open`, `fixed`, `tested`, `integrated`, `not_applicable`, or `blocked`
- `evidence`: file/line, test name, command output, search sweep, schema/API check, or blocker reason

Closure rules:
- `code`: applicable issues must be implemented or marked `not_applicable`/`blocked` with evidence. Retired terms and old API/schema names must be searched in source, migrations, schemas, and API routes.
- `test`: every code-fixed issue needs a regression test or an explicit untestable rationale tied to source/spec evidence. Passing existing tests alone is not closure evidence for a newly fixed issue.
- `integrate`: each issue must have end-to-end evidence: relevant unit/integration checks, schema/API/doc contract match, migration compatibility when applicable, and stale-term sweep across code, tests, and docs.
- `blocked` is allowed only for an external dependency, missing requirement, unavailable service, or user decision. It must include the exact blocker and the smallest next action.

Cap rules:
- If the ledger is omitted for `code`, `test`, or `integrate`, discard the score and rerun scoring.
- Any open applicable `critical` issue caps overall score at `60`.
- Any open applicable `important` issue caps overall score at `75`.
- Any code-fixed issue without test coverage or explicit untestable evidence caps `test` and `integrate` overall score at `70`.
- Any issue marked fixed/tested/integrated without evidence is treated as `open`.

Emit a check before continuing:

```text
PHASE1_CHECK:
- structural audit: <doc modes only; section/concept/peer/reader-path summary or n/a>
- contract audit: <doc modes only; active/stale/matrix/encoding/hazard summary or n/a>
- open questions: <doc modes only; open/answered/out-of-scope summary or n/a>
- issue closure: <code/test/integrate only; open/fixed/tested/integrated/blocked summary or n/a>
- baseline scorer: <dimension summary>
- reviewer scorer: claude (<dimension summary>) or codex fallback (<reason>; <dimension summary>)
```

### Phase 2: Cross-Review

Compare both score sets and derive final dimension scores:
- within `5` points: average them
- more than `5` points apart: choose the more persuasive evidence and state why
- call out over-scoring explicitly
- compute a weighted average
- if Claude review was unavailable, explicitly label the second score set as Codex adversarial fallback

Output format:

```text
=== Round <N> - SCORE (<MODE>) ===
- <dimension> (<weight>%): <final>/100 [baseline:<x>, reviewer:<y> -> final:<z>] "<reason>"
- overall: <weighted>/100
```

Rules:
- if the overall score meets target but a dimension remains below `70`, continue
- on round `2+`, this score also functions as the re-score of the previous round
- if the previous round made the score worse, roll back only the changes from that round when practical, record the rollback, and choose a different batch shape

## DIAGNOSE

Identify the full batch of weaknesses to attack this round:
- include every dimension or concrete question below `70`
- include every dimension or concrete question capped at exactly `70` by an audit, verification, TDD, or issue-ledger rule
- in `doc:*` modes, include every unresolved structural audit failure before ordinary weak dimensions
- in `doc:*` modes, include every active stale term, prose/schema/API contradiction, and implementation hazard before ordinary weak dimensions; these must be fixed before scoring the target complete
- in `code`, `test`, and `integrate`, include every open applicable issue closure ledger item; critical items outrank important items
- if `FOCUS` is set, include every below-threshold question inside the focused dimensions, plus any critical audit/ledger blocker that would make completion invalid
- include any question where the reviewer score is `20+` lower than the baseline score, even if the averaged dimension is not below `70`
- in `code` or `integrate`, failing tests outrank everything else
- in `code`, `test`, or `integrate`, include cognitive-complexity findings when the main path is obscured by deep nesting, callback chains, repeated negations, long condition chains, boolean flags or mode strings that create divergent behavior, mixed parsing/I/O/mutation/formatting responsibilities, unnecessary mutable state, dead branches, or future-only paths
- include any `REGRESSION_ISSUE` injected by auto regression passes as a first-class weakness
- assign priority by blocker status, severity, then higher-weight dimension; priority resolves conflicts but does not reduce the batch by itself
- if two weaknesses require incompatible edits, keep the higher-priority one in this round and explicitly defer the other to the next DIAGNOSE with the conflict reason

Output:

```text
DIAGNOSE:
- batch size: <N>
- weakness <id>: <dimension/ledger/audit> - <question or issue>; priority <critical|important|minor>; status <selected|deferred>; why: <1-2 sentences>
- dependency/conflict notes: <one compact paragraph or n/a>
```

## PROPOSE

Write concrete fix proposals for every selected weakness in the DIAGNOSE batch.

Rules:
- one proposal per selected weakness, merged when several weaknesses share the same file or contract surface
- each proposal must be specific enough to apply directly
- if the weakness is an unimplemented feature in `code`, implementation is the proposal, not commentary
- if a selected weakness is intentionally not fixed this round, mark it `deferred` with the conflict or blocker reason; do not silently drop it

If delegation is authorized, use a bounded verifier sub-agent on the whole proposal batch. Otherwise run a local adversarial verification pass that checks correctness, completeness, side effects, and conflicts across the batch.

Emit:

```text
PROPOSE_CHECK:
- verifier: <PASS|CAVEAT|FAIL> for batch; <item ids needing changes or n/a>; <one-line summary>
```

Then immediately move to APPLY.

## APPLY

0. Snapshot target files before editing when practical: record pre-change hashes and, for dirty worktrees, keep a `RUN`-scoped backup under `/tmp/refine_backup_r<N>_${RUN}` so rollback can distinguish pre-existing user changes from this round's patch.
1. apply all compatible proposals in the batch
2. for `code` or `integrate`, run lint and fix failures
3. if contracts, data models, or interface terms changed, sync related docs
4. run a review pass on the whole diff and verify the batch did not introduce conflicting behavior
5. run a simplification pass for code/test/integrate changes: prefer guard clauses and early returns where they clarify the main path, split mixed-responsibility functions, remove dead or duplicate branches, reduce shared mutable state, and keep helper names tied to domain rules rather than mechanical operations
6. rerun relevant tests
7. For `test`, `integrate`, and TDD-active `code` rounds that add or strengthen tests, run a small mutation sanity check on the specific branch those tests claim to verify when feasible: temporarily break that branch, confirm the new/changed test fails, and immediately restore. If the test still passes, treat that coverage claim as open in the next DIAGNOSE.
8. fix any valid issues immediately
9. for `code`, `test`, or `integrate`, update the issue closure ledger with status and evidence for every touched issue
10. append the round record to `.refine.log`, listing every selected, fixed, deferred, skipped, or rolled-back item
11. save the round diff against the snapshot when available; if the next SCORE is worse and the current file hashes still match the post-apply hashes, roll back only this round's patch as a batch. If hashes differ because of outside edits, stop automatic rollback and report the conflict.
12. start the next round at SCORE

Emit:

```text
APPLY_CHECK:
- review: <PASS|CAVEAT|FAIL> for batch; <item ids needing follow-up or n/a>; <one-line summary>
```

Round log shape:

```text
## Round <N> - <timestamp> (<MODE>)
- Target: <batch item ids and dimension/questions>
- Before: <state or score>
- After: <state or score>
- Delta: <change>
- Result: <KEEP|ROLLBACK|SKIP>
- Action: <one-line summary per item>
```

## Stop / Continue Rules

Allowed stop reasons:
- overall score >= target and no dimension below `70`
- no dimension is held at exactly `70` by an unresolved audit, verification, TDD, or ledger cap
- no doc:* stale active contract or unresolved contract-level back-question blocks completion
- for `code`, `test`, and `integrate`, all applicable issue closure ledger items are `integrated`, `not_applicable`, or `blocked` with evidence
- `MAX_ROUNDS` reached
- external dependency, denied approval, or missing requirement blocks further valid improvement

Forbidden stop reasons:
- "structural limitation" without trying focus shift or an alternative
- "low-cost improvements exhausted"
- "tool missing" without installation/configuration attempt or approval request
- "realistic upper bound" before `MAX_ROUNDS`
- asking "continue?" while `AUTO_CONTINUE=true`

Stall handling:
- if improvement is below `+3` for three consecutive rounds, change `FOCUS`
- if one dimension oscillates for four rounds, skip that dimension temporarily and continue

## Mode-Specific Rules

### code

- test pass rate below `100%` caps the overall score at `60`
- if a spec or acceptance criteria document exists and required behavior is not implemented, correctness for that item is `0`
- prefer feature completion over polish when missing implementation is the main gap
- every applicable reviewer/user/contract issue must be represented in the issue closure ledger before code scoring
- a code issue is not fixed until the patch location and a targeted verification command or search sweep are recorded
- when TDD is active, missing RED evidence for a behavior item caps Test Coverage at `70`
- run lint/formatter after each APPLY when available

### test

- do not modify source code unless the user expands scope
- compare tests against spec acceptance criteria
- every code-fixed issue must map to a regression test, existing test name, or explicit untestable rationale
- sync any test map or coverage mapping document if the project uses one
- unimplemented features can be marked untestable only with evidence from the source/spec
- before scoring stateful code, derive a compact state-machine/failure-mode table from the implementation: state/trigger/path/result, quiet-failure modes, and mapped tests. Any core transition or quiet-failure mode left as `NONE` blocks completion.

### integrate

- if integration tests are missing, create or wire them before polishing integration quality when feasible
- test pass rate combines unit and integration results
- zero integration tests caps integration readiness
- integration closure requires stale-term sweeps and contract checks across source, tests, migrations, API routes, and docs when the issue changes a public contract
- issue status should advance to `integrated` only after unit/integration evidence and contract compatibility evidence are both recorded
- score Error Resilience and Data Flow from tests that exercise real entrypoints and fault-injection paths. Static presence of retry/fallback/error code is insufficient; helper-only tests that bypass entrypoint wiring cap Data Flow until covered through the actual route, CLI, orchestrator, or service entrypoint.

### doc:skill

- validate that referenced files and paths exist where practical
- check that mandatory instructions have no bypass path
- loops must have at least two stop conditions
- tool/sub-agent usage must include enough shape or template detail to execute
- do not run project test/lint commands unless the skill update changes executable code

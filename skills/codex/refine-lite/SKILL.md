---
name: refine-lite
description: Fast lightweight refinement loop for small to medium code or test files. Use when Codex has just written or modified a focused module, PR-sized code file, or edge-case-sensitive test suite and should quickly score, batch-fix, verify, and report without the full multi-round /refine lifecycle, STATUS files, or document-mode audits. Use full refine for doc:* targets, large campaigns, cross-stage lifecycle work, or anything requiring persistent score history.
---

# Refine Lite

Refine Lite is the small-code sibling of `refine`: one independent score view, up to two batch-fix rounds by default, targeted verification, and one final adversarial review before reporting. It is for code/test work only.

## Scope

- Use `refine-lite` for a single code file, a tight set of related files, or a test suite where quick quality pressure is useful.
- Use direct implementation plus a normal code review for tiny changes such as one or two simple functions with obvious behavior.
- Use full `refine` for `doc:idea`, `doc:design`, `doc:spec`, `doc:plan`, `doc:skill`, `doc:test`, integrated project stages, ledger-backed issue closure, or more than two refinement rounds.

Do not create `.refine.log`, `STATUS.md`, lifecycle state, or persistent ledgers for this skill.

Do not use `MODEL_POLICY` or effort routing in `refine-lite`. It deliberately relies on the current Codex session plus the optional Claude review wrapper; role-specific `--model`/`--effort` routing belongs to the full `refine` skill's Codex companion task path.

## Parameters

Parse before doing other work:

- `PATH`: required target file or focused directory. If the path does not exist and the user clearly asked to create it, write the requested initial artifact as Round 0, then start scoring at Round 1.
- `MODE`: `code` or `test`. If omitted, infer `test` for `tests/`, `test_*`, `*_test.*`, or `*.test.*`; otherwise infer `code`.
- `TARGET_SCORE`: `--target N`, default `70`.
- `MAX_ROUNDS`: `--rounds N`, default `2`.

## Dimensions

Score every round with these fixed dimensions:

| Dimension | Weight | Criteria |
|-----------|--------|----------|
| Correctness | 40% | Implements the intended behavior, handles actual callers/contracts, and has no evident bug. |
| Test Coverage | 25% | Critical behavior is tested. In `test` mode, this means the target suite covers meaningful scenarios. |
| Simplicity | 20% | Keeps the main path easy to follow before edge cases. Avoids unnecessary abstractions, branches, state, indirection, dead code, future-only options, deep nesting, boolean-mode behavior, repeated negations, and long condition chains. |
| Edge Cases | 15% | Covers boundary, error, empty, large, stale-state, concurrency, or external-failure paths that apply. |

Anchors: `0-20` absent, `21-40` abstract only, `41-60` more than half unmet, `61-70` mostly there with important gaps, `71-85` solid with minor gaps, `86-95` complete with extra depth, `96-100` essentially complete. Be strict: `50` is not acceptable, and `71` is the start of good.

## Workflow

### Step 0: Target

Read the target and nearby conventions. If creating a missing file, implement the initial requested artifact first and record it mentally as Round 0; do not count it against `MAX_ROUNDS`.

Determine the most relevant verification command from local project files. Prefer existing package scripts, pytest config, test runner config, Makefile targets, or pre-commit config over inventing commands.

### Step 1: Score

Produce one baseline Codex score and one independent review score when practical:

- Preferred independent scorer: `$HOME/.codex/skills/refine/scripts/claude-review.sh` with a read-only prompt. Keep its default timeout unless the environment sets `CLAUDE_REVIEW_TIMEOUT_SECONDS`.
- Fallback: local Codex adversarial scorer that attempts to falsify the baseline score.

Never claim Claude reviewed unless the wrapper exits `0` and its output is actually used. If the wrapper is missing, Claude is not authenticated, the result is empty, or output is not score-like, write the reason as `independent scorer: codex fallback (<reason>)`.

Run the target verification command in parallel when feasible. For Python targets, run pre-commit only when a pre-commit configuration exists and the target is inside that project.

### Step 2: Gate

Pass only when all are true:

- verification command passes, if a faithful command exists
- Python pre-commit passes, if applicable
- weighted score is at least `TARGET_SCORE`
- no dimension is below `70`

If the gate passes, go to Step 4. If it fails and `ROUND < MAX_ROUNDS`, go to Step 3. If it fails at `MAX_ROUNDS`, go to Step 4 with remaining issues visible.

### Step 3: Batch Fix

Fix all selected issues in one batch, with failing tests first. In `test` mode, default to editing the test target; if a failure proves a source bug, fix the source too and say so.

For every code/test batch, include a small simplification pass when applicable: prefer guard clauses and early returns where they clarify the main path, split functions that mix parsing, branching, I/O, mutation, and formatting, remove dead or duplicate branches, reduce shared mutable state, and replace boolean flags or mode strings with named functions when behavior truly diverges. Do not add a new abstraction unless it removes real branch/state complexity.

After editing, rerun the relevant verification command and rescore only the dimensions affected by the diff while carrying unchanged dimensions forward. Increment the round and return to Step 2.

### Step 4: Final Review

Run one adversarial final review over the target or final diff. Include cognitive-complexity risks in the review prompt: deep nesting, callback chains, repeated negations, long condition chains, boolean-mode behavior, mixed responsibilities, unnecessary mutable state, dead branches, and future-only paths. Use local Codex review directly; if Claude independent scoring already identified unresolved concrete issues, include them in the review prompt.

Apply valid final-review findings immediately and rerun the verification command. Do not rescore after this final-review fix; report the last score as pre-final-review score if changes were made in this step.

### Step 5: Report

Report:

- start score to final score, with dimensions
- rounds used
- verification commands and results
- final-review summary or unavailable reason
- remaining issues with file/line references, if any

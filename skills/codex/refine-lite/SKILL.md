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

Require `gpt-5.6-sol:ultra` as the lite main route. Keep the graph bounded: Terra xhigh scores and writes, Sol xhigh performs the final review, and the Ultra main only orchestrates and decides gates. Verify the requested model/effort route is available before Step 0; if unavailable, record `BLOCKED` and do not replace an independent role with the main.

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

Read the target and nearby conventions. If creating a missing file, have the Terra writer implement the initial artifact as Round 0; do not count it against `MAX_ROUNDS`. For an existing target, snapshot it under a unique `/tmp/refine-lite-backup-<run>-<basename>` path and record pre-change hashes before the first edit.

Determine the most relevant verification command from local project files. Prefer existing package scripts, pytest config, test runner config, Makefile targets, or pre-commit config over inventing commands.

### Step 1: Score

Assign one reusable Terra xhigh scorer to score all four dimensions. A scorer failure may be retried once; a second failure is `BLOCKED`, not a main-session score. Run the verification command concurrently and run the project cognitive-complexity check, or `flake8 --select=CCR001 --max-cognitive-complexity=15 <targets>` when available; otherwise report `cc=not_available`.

- The independent scorer is the assigned Terra xhigh lane; it must produce evidence-backed scores separate from the Ultra main. Do not substitute a Claude wrapper or the main session for this role.

Run the target verification command in parallel when feasible. For Python targets, run pre-commit only when a pre-commit configuration exists and the target is inside that project.

### Step 2: Gate

Pass only when all are true:

- verification command passes, if a faithful command exists
- Python pre-commit passes, if applicable
- cognitive-complexity checks have no violations when available
- weighted score is at least `TARGET_SCORE`
- no dimension is below `70`

If the gate passes, go to Step 4. If it fails and `ROUND < MAX_ROUNDS`, go to Step 3. If it fails at `MAX_ROUNDS`, go to Step 4 with remaining issues visible.

### Step 3: Batch Fix

Fix all selected issues in one batch, with failing tests first. In `test` mode, default to editing the test target; if a failure proves a source bug, fix the source too and say so.

For every code/test batch, include a small simplification pass when applicable: prefer guard clauses and early returns where they clarify the main path, split functions that mix parsing, branching, I/O, mutation, and formatting, remove dead or duplicate branches, reduce shared mutable state, and replace boolean flags or mode strings with named functions when behavior truly diverges. Do not add a new abstraction unless it removes real branch/state complexity.

Assign one Terra xhigh writer to apply the whole compatible batch. Snapshot the batch and writer-output hashes; rerun verification, pre-commit, cognitive-complexity, and a full four-dimension rescore. If a check newly fails or any score regresses, restore only the batch when hashes still match; otherwise report the outside-edit conflict as `BLOCKED`. Increment the round and return to Step 2.

### Step 4: Final Review

Assign one Sol xhigh final reviewer over the target or final diff. Include cognitive-complexity risks in the review prompt: deep nesting, callback chains, repeated negations, long condition chains, boolean-mode behavior, mixed responsibilities, unnecessary mutable state, dead branches, and future-only paths. Apply valid findings through the same writer, rerun all checks, then request one full rescore before deciding the final gate.

Never preserve an earlier PASS after final-review changes fail verification, regress a score, or leave a blocking finding open.

### Step 5: Report

Report only after the post-final-review full rescore and gate evaluation:

- start score to final score, with dimensions
- rounds used
- verification commands and results
- pre-commit and cognitive-complexity commands and results
- configured versus effective routes and any unavailable lane
- final-review summary or unavailable reason
- remaining issues with file/line references, if any

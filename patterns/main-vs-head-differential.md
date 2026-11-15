# Main-vs-head differential and the parent-commit check

Kind: pattern.

## Problem

A reviewer reports a gap in the current code. Whether the change under review caused it decides between "fix or revert" and "file a follow-up", and re-reading the diff does not answer that.

## Context

- Classifiers, routers and policies whose changes are meant to only raise outputs.
- Any review that runs after merge, or a new reviewer pointed at merged code.

## The pattern

Run the same fixed input set through the base and the head, and compare pair by pair.

- Before merge, as a regression guard: run the corpus on main and on the PR head; count downgrades (head lower than main). For a "can only raise" change the count must be zero.
- After merge, as calibration: run the reported probe on the parent commit.

  ```sh
  git worktree add ../parent <merge-commit>^1
  ```

  Same result on the parent: the gap predates the change; record it as pre-existing and plan a follow-up, not a revert. Different result: it is a regression; fix or revert.

Keep the corpus in the repository so the next change runs the same comparison.

## Evidence

Observed: one routing classifier, 2026-11-14, from the review log.
- Regression guard: 0 downgrades in 2,076 main-vs-head prompt and agent pairs.
- Calibration: a post-merge review reported a blocking gap on a previous change; the parent commit gave the same result, so it was recorded as pre-existing and fixed in a follow-up change rather than a revert.

n = 2 uses, one component.

## When it does not hold

- Non-deterministic outputs (model calls) need repeated runs and a tolerance, or the differential measures noise.
- The guard is only as good as the corpus; it says nothing about inputs it does not contain. See [keyword-list-as-security-control](keyword-list-as-security-control.md).

## Related

- [prior-default-floor-regression-test](prior-default-floor-regression-test.md)
- [learn from escapes](../workflows/learn-from-escapes.md)

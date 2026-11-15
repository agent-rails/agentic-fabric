# A reviewer that hit its limit, logged as a clean pass

Kind: anti-pattern.

## Problem

An automated reviewer stops at its turn limit or a provider usage limit and returns no findings. The pipeline records that the same way as a reviewer that looked and found nothing.

## Context

Review pipelines with subagent reviewers that have `maxTurns`, run against a provider quota, or run in the background.

## What goes wrong

- "0 findings" now means two different things. Convergence rules that compare finding counts across cycles treat a stalled pass as a converged one.
- Coverage drops on exactly the passes that were meant to be the second opinion.
- A pass marked "not obtained" while it is still running in the background can later land the finding the decision depended on, after the decision.

## Do instead

- Log distinct statuses: `executed`, `not_obtained: <reason>`, `pending`. Never `executed` with zero findings for a stopped pass.
- If every reviewer path is exhausted, the review header says so, and the verdict rests only on what was reproduced.
- Ask reviewers to emit findings as they find them, so a stop loses only the tail.
- On a limit stop, resume with "report your findings now; run no new commands".
- Scope re-runs to a named commit range with a stated tool-call budget.
- Do not move the branch while a review is in flight.

## Evidence

Observed, from session transcripts (zero-token weekly report) and the review logs:
- 21 of 77 subagent runs (about 27%) stopped at their turn limit, four non-overlapping weekly reports, 2026-10-05 to 2026-11-02.
- 30 days to 2026-10-11: stopped runs averaged 0.7K output tokens against 2.7K for runs that finished (95 runs).
- One review session, 2026-09: 4 of 6 passes stopped at their limit; resuming with a report-only instruction recovered 3 of the 4.
- 2026-09-12 to 2026-11-14: 2 of 18 cross-vendor passes produced no review (a provider usage limit; a local permission classifier blocking the call). One "not obtained" status was retracted when the background pass finished with the finding the merge decision turned on.

## When it does not hold

A reviewer with no step limit that runs synchronously cannot stall this way, but errors still need their own status.

## Related

- [cross-vendor review](../workflows/cross-vendor-review.md)
- [silent-no-op-safety-configuration](silent-no-op-safety-configuration.md)

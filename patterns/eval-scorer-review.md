# Review the eval's scorer, not just the model

Kind: pattern.

## Problem

An eval harness is tooling, so a loose scoring function crashes nothing. It passes wrong behaviour, and every number the harness reports, and every doc that cites it, is wrong until the scorer is fixed and the suite rerun.

## Context

Any new or changed scorer or grader in an LLM eval, seeded-defect review suite or agent health check.

## The pattern

For each scorer, check:
- Affirmation vs denial: does it pass "no, that was not sold" when it looks for "sold"?
- Numbers: does it require the right unit and format, or any matching digits?
- Tool calls: does it require the exact call and parameters, or just "a call happened"? Are failure replies rejected?
- Scope: does an attempt to call a hidden or out-of-scope tool fail the case, or only get recorded?
- Trust: do credentials the harness accepts (a base URL, an API key) follow the production boundary?
- Model-controlled text: does acceptance key on the shape of text the model can write? See [shape-filters-on-model-controlled-text](shape-filters-on-model-controlled-text.md).
- Reach: is the fixture large or varied enough to exercise the path in dispute?
- Precision as well as recall: clean cases (no defect) and trap cases (looks like a defect, is safe) next to seeded ones.

Rerun the suite under the fixed scorer before any doc cites a number, and record the grader version with the score.

## Evidence

Observed:
- One eval harness review, 2026-09: scoring defects found in one pass included denials scored as passes, digit matching without units, split or mis-parameterised tool calls accepted, failure replies accepted, hidden-tool attempts not failing, and an API key sent to any base URL. All were fixed with 14 new unit tests and rerun before docs cited results. A later review found the committed fixture could not reach the disputed code path at all.
- A seeded-defect review suite for this project (unreleased): 11 cases, 7 seeded, 2 clean, 2 trap. Its 6 recorded runs on 2026-10-29 and 2026-10-30 scored between 0.20 and 0.95 overall while cases and graders were still changing; a score is comparable only under the same grader version.

## When it does not hold

Deterministic unit tests with exact expected outputs do not need this pass; their assertions are the scorer.

## Related

- [learn from escapes](../workflows/learn-from-escapes.md)
- [tool-call-health-check](tool-call-health-check.md)

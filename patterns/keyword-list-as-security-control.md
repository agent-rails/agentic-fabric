# A keyword list treated as the security control

Kind: anti-pattern.

## Problem

A fixed keyword or regex list decides whether free text describes security-sensitive work, and that decision is the only thing standing between the task and a cheaper or less-reviewed path.

## Context

Routers, classifiers and risk escalators that pick a model tier, a review depth or an approval step from a prompt or a task description.

## What goes wrong

- Recall has no ceiling. Natural language has more ways to describe a security task than any list holds.
- Every probing pass finds new phrasings; every fix adds terms and tests, so each pass looks like progress and coverage is overrated.
- Misses fail silently toward the cheaper path.
- More terms bring more false positives: text that quotes docs or guardrails gets flagged.

## Do instead

- Let detection only raise. Keep the floor in a default that does not depend on detection: security-tagged agents always get the strong tier, and an explicit caller choice is honoured.
- Test each change for downgrades with a [main-vs-head differential](main-vs-head-differential.md), not only that new terms hit.
- If the same change lowers a default, apply the [prior-default floor test](prior-default-floor-regression-test.md).
- Record a stop decision after a fixed number of vocabulary passes; reopen only on a regression against main.
- Measure the false-positive cost from the decision log instead of guessing it.

## Evidence

Observed, one keyword-based security classifier for subagent routing, 2026-11-14 to 2026-11-15, from the review log and the routing decision log joined to transcripts:
- Three successive review passes each found security phrasings the list missed. In one probe set, 15 of 17 out-of-vocabulary security prompts went to the lower tier; the parent commit gave the same result, so the gap predated that change.
- First reading of enforced routing, 2026-11-15, 15 spawns: 9 ran on the strong tier, 4 of them because of a keyword flag, and those 4 used 41% of the strong tier's uncached tokens. Too few spawns to decide on.

## When it does not hold

A closed vocabulary, where the list is the domain (tool names, file paths, command verbs), can be matched exhaustively.

## Related

- [shape-filters-on-model-controlled-text](shape-filters-on-model-controlled-text.md)
- [adjacent-shape-defeats-new-control](adjacent-shape-defeats-new-control.md)

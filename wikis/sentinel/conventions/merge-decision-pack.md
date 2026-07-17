---
title: Merge Decision Pack — the one-screen Type-1 merge gate
type: convention
status: active
---

## Why this exists

The merge decision is a Type-1 gate (irreversible) and stays with the human. But the human should not have to reconstruct context from 30 findings to make it. Sentinel emits a fixed one-screen pack at the top of every review so the gate decision costs seconds, not a re-read. It is decision support — it recommends, it never merges.

## The pack — emit at the top of every review presentation

```
### Merge Decision Pack — {owner}/{repo}#{n}  ·  {title}

VERDICT:  ✅ MERGE   |   ⚠️ MERGE + FOLLOW-UP   |   ⛔ HOLD
WHY:      <≤15 words: the call and its single load-bearing reason>

Grounding: head {short_sha} · {N} files · cascade: {sentinel only | + cross-vendor}
Scope:     +{adds}/-{dels} · {changedFiles} files · author {login} {risk: ≤4 words}

BLOCKERS ({n})        ← correctness / security / data-integrity ONLY
  • [{evidence_type}] {finding} — {file:line}
  (none → "none")

DECISION DRIVERS  (the 1–3 facts that actually determine the call)
  • {load-bearing fact}

NON-BLOCKING:  {k} medium · {m} low · {j} nits   → folded; full findings below

EXECUTED:  {what ran + result}   | or:  static only ({reason})

IF MERGE: {deploy target + blast radius}
IF HOLD:  {the single change that flips it to MERGE}
```

## Rules

- VERDICT and a one-line WHY come first. The decision is the headline.
- Brevity is load-bearing: WHY ≤ 15 words, the author risk note ≤ 4 words, DECISION DRIVERS ≤ 3 bullets. The pack is scannable, not prose.
- BLOCKERS are correctness / security / data-integrity only. Each carries its `evidence.type` (see [spock-evidence-contract](spock-evidence-contract.md)) — `unverified_hypothesis` is already capped below blocker, so the list is trustworthy by construction. No confident-wrong finding forces a HOLD.
- DECISION DRIVERS are the 1–3 load-bearing facts only. This is the anti-bottleneck core.
- NON-BLOCKING findings are folded to a count. Do not surface dropped minors into the gate (see [review-friction discipline](../anti-patterns/)) — full findings sit below the pack.
- The Grounding line carries the verified `head_sha`, file count, and cascade scope (the existing `GROUNDING_OK` check). Provenance in one line.
- EXECUTED states what ran (see [execute-before-review](execute-before-review.md)). "static only" must name a reason.
- IF MERGE / IF HOLD frame the consequence and make HOLD actionable — the single flip-condition.
- The pack RECOMMENDS. It adds no merge action. The merge moment stays an explicit human yes (ask-before-merging) — unchanged.

## Verdict taxonomy

| Verdict | Meaning |
|---|---|
| ✅ MERGE | No blockers; drivers support merging now. |
| ⚠️ MERGE + FOLLOW-UP | No blockers; a non-blocking gap worth a tracked follow-up, not a hold. |
| ⛔ HOLD | One or more blockers (correctness / security / data-integrity), each evidence-backed. |

## What this prevents

A Type-1 decision made slowly, or made on noise — 30 findings the human must re-rank, dropped minors resurfacing at the gate, or a confident-wrong hypothesis masquerading as a blocker.

## What this preserves

The merge gate itself. The pack speeds the decision; it never makes it.

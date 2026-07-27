---
title: Cross-vendor-reviewer evidence contract — calibrating cross-vendor severity by execution
type: convention
status: active
---

## Why this exists

In a single day, cross-vendor-reviewer (cross-vendor cascade) over-asserted three times:

1. **charts#73 cycle-3**: missed 5 chart bugs caught by a human reviewer running `helm unittest`. Cross-vendor-reviewer read statically and produced findings without running the tests itself.
2. **api-server#6035 (nginx CVE)**: claimed BLOCKER "supply-chain mismatch — `nginxinc/nginx-unprivileged` ships upstream nginx, not Alpine packages, so the 1.28.3-r1 fix doesn't apply." CI build proved the claim wrong empirically — `1.29-alpine` closed the CVE. Cross-vendor-reviewer asserted authoritatively from web search + Dockerfile parse without ever running `docker build` + scan.
3. Multiple smaller mis-calibrations the same day.

The common pattern: **cross-vendor-reviewer asserts BLOCKER from static reasoning + web search, doesn't execute, doesn't calibrate severity on absence of evidence.** Confident wrong findings burn review cycles and erode trust in the cross-vendor cascade.

## The contract

Every `CROSS_VENDOR_REVIEW` MUST include:

### 1. `execution_report:` block

A list of what was actually run in the codex sandbox, what succeeded, and what was skipped (with explicit reason). "I reasoned about it instead" is NOT a valid skip reason.

Valid skip reasons: `tool_unavailable`, `side_effect_only`, `egress_constraint`, `cost_too_high`, `depends_on_skipped_step`, `scoped_out`.

NOT valid: "I assumed the test would pass", "Static reasoning was sufficient", "I checked the docs instead".

### 2. `evidence:` field per finding

Every finding carries one evidence type:

| Type | Max severity |
|---|---|
| `execution_output` | BLOCKER |
| `source_quote` | HIGH |
| `external_doc` | HIGH (convergent with source_quote) / MEDIUM standalone |
| `unverified_hypothesis` | **MEDIUM** (cap) |

### 3. Severity calibration

PR-reviewer (and the orchestrator) read `evidence.type` per finding:

- BLOCKER with `unverified_hypothesis` → downgraded to MEDIUM, note added
- HIGH with `unverified_hypothesis` → downgraded to LOW
- MEDIUM with `unverified_hypothesis` → kept
- LOW / NICE-TO-HAVE → kept regardless

## What this prevents

The api-server#6035 false BLOCKER would have surfaced as MEDIUM (hypothesis, not execution-proven) instead of forcing a review cycle.

## What this preserves

Real BLOCKERs proven by execution stand. The convention is anti-bullshit, not anti-finding.

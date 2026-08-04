# ADR-0008 — Same-vendor fallback when the cross-vendor reviewer is unavailable

Status: Accepted · Applies principles: [Cross-vendor cascade](../DESIGN-PRINCIPLES.md#6-cross-vendor-cascade-for-reasoning-diversity)

## Context

Before this decision, `your-cross-vendor-reviewer`'s failure mode was `verdict: unavailable` — a clean, honest, non-blocking degradation (per [ADR-0005](0005-cross-vendor-cascade.md)), but a real coverage gap: with no second-vendor CLI installed (no `codex`, or whatever tool is wired in its place), a security-critical path got exactly one review pass instead of two, with nothing to correct for that pass's own blind spots or priming.

This is not a hypothetical gap. Reviewing this bundle's own history: two real bugs (a word-boundary regex bug and a token-verification gap, both in a separate but related project) were found specifically by a *second, unprimed* pass catching what a first pass — from the same author, in the same session — had missed. Losing the second pass entirely whenever a second vendor happens to be unavailable throws away real signal, not just theoretical diversity.

## Options

1. **Leave it as `unavailable`, no fallback (status quo).** Honest, simple, but a security-critical path with no second-vendor tooling gets zero adversarial second pass — worse coverage than the cascade design intends whenever that one dependency is missing.
2. **Retry `your-cross-vendor-reviewer` or block until a second vendor is installed.** Turns an optional dependency into a hard one, contradicting the "Optional, per feature" prerequisites design this bundle otherwise holds to.
3. **Spawn a same-vendor fallback reviewer, explicitly and permanently labeled as non-cross-vendor (chosen).** A fresh, unprimed, adversarial-framed pass from the same model family as `your-pr-reviewer`, invoked automatically in place of `your-cross-vendor-reviewer` — never silently, never mislabeled.

## Decision

Option 3. `your-same-vendor-reviewer`:

- Is invoked by the orchestrator only as a substitute for `your-cross-vendor-reviewer`, only when the latter returns `verdict: unavailable` — same `REVIEW_MODE`, same target diff/plan.
- Runs with **deliberately minimal shared context** (no wiki, no prior review framing), the same isolation mechanism that gives `your-cross-vendor-reviewer` its value — a fresh, unprimed pass, even without a different training distribution behind it.
- Follows the same evidence-calibration contract (BLOCKER/HIGH require execution or source-quote evidence; unverified claims cap at MEDIUM) so its findings carry the same discipline, not a lower bar because it's the fallback.
- Is **required to self-label `cross_vendor: false`** in every structured output, and `your-pr-reviewer`'s synthesis is required to tag its findings `(your-same-vendor-reviewer same-vendor)`, never `(cross-vendor)`. This is the load-bearing part of the decision: the value it adds (fresh-context adversarial framing) is real but categorically smaller than genuine vendor diversity, and conflating the two would quietly overstate review coverage exactly on the paths where that matters most.
- Its own system prompt names the specific failure modes a same-lineage reviewer is prone to (hallucinated citations, same-lineage defensiveness toward "house style" code) and requires an explicit falsification pass before any BLOCKER/HIGH finding — mitigations a genuinely different vendor gets for free from architectural diversity, that a same-family reviewer has to earn deliberately.

## Consequences

- Security-critical paths always get a second adversarial pass, regardless of what's installed on the machine — the cascade degrades in *quality* of the second opinion, never in whether one runs at all.
- The user-facing verdict must always distinguish "cross-vendor confirmed" from "same-vendor fallback ran" — never present the second as equivalent to the first. A synthesis that drops this distinction is a contract violation, not a minor omission.
- `your-same-vendor-reviewer` adds no new cost-bounding concern beyond the existing 3-cycle cap ([ADR-0005](0005-cross-vendor-cascade.md)) — it's a local pass, not a paid API call, so `cascade-default-policy.md`'s cost-bounded skip logic (written for real cross-vendor spend) doesn't need to bound it the same way.
- Convergence between `your-same-vendor-reviewer` and `your-pr-reviewer` is explicitly weaker evidence than convergence with a genuinely different vendor — the fallback's own review philosophy says so, so synthesis doesn't accidentally read agreement as triangulation it isn't.

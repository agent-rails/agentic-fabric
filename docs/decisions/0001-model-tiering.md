# ADR-0001 — Model tiering: opus for judgment, haiku/sonnet for mechanics

Status: Accepted · Applies principle: [Judgment on the big model, mechanics on cheap ones](../DESIGN-PRINCIPLES.md#1-judgment-on-the-big-model-mechanics-on-cheap-ones)

## Context

Every persona could run on the frontier model. That is simplest to reason about and maximizes quality per call — and it is expensive. A single triage or PR review touches many sub-tasks of wildly different difficulty: fetching messages, classifying them, drafting a reply, writing the result back to a wiki. Paying opus rates to concatenate strings in a fetcher or append a line to a log is waste; paying haiku rates to synthesize a review verdict is a quality hole.

The tasks split cleanly by *kind*:

- **Judgment** — classify, draft, synthesize, plan, root-cause. Reasoning depth is the whole value.
- **Research isolation** — read a lot, return a small digest. Throughput matters; reasoning depth barely does, because the output is a summary the caller re-reasons over.
- **Mechanics** — wiki writes, edit-only implementation, logging. Single perspective, no synthesis.

## Options

1. **Everything on opus.** Simplest mental model, highest quality, highest cost. Fetchers and scribes burn frontier tokens for zero added judgment.
2. **Everything on a cheap model.** Cheapest, but classification and review synthesis degrade — and a shallow review verdict is worse than none because it looks authoritative.
3. **Tier by task kind (chosen).** opus for judgment, haiku for fetch/research-isolation, sonnet for scribe/edit-only. Cost tracks difficulty.

## Decision

Tier by task kind (Option 3):

- **opus** — `voltage`, `sentinel`, cascade peers (`architect-review`, `ai-architect`, `spock`, `scotty`), `orchestrator`, `architect`, `tester`, `context-manager`.
- **haiku** — `voltage-fetcher`, `sentinel-fetcher`, built-in `Explore`. Large input, digest output.
- **sonnet** — `voltage-scribe`, `sentinel-scribe`, `voltage-reporter`, `researcher`, `implementer`, `senior-qa`, `debugger`. Mechanical or single-perspective.

The one guard that makes this safe: the **cascade peer gate**. A Pattern-3 peer's `model:` MUST be ≥ the synthesizer's tier. If sentinel is opus, every peer that feeds it is opus — a weak peer produces findings the synthesizer literally cannot recover, so the cascade degrades silently. Research isolation (Pattern 5) and sequential steps (Pattern 4) may use cheaper tiers because there is no peer-merge to poison.

## Consequences

- Cost tracks difficulty instead of being flat-frontier everywhere.
- More decisions to get right: each new agent needs an explicit `model:` justification, and the model-discipline table in [orchestration-patterns.md](../../shared-wiki/orchestration-patterns.md#model-discipline-cascade-peer-gate) must be re-audited when a cascade peer is added.
- A watch list is required. `debugger` runs sonnet but debugging often wants frontier reasoning — the standing note is to promote it if symptom-vs-cause regressions recur.
- Tiering is only sane because orchestration depth is shallow ([ADR-0002](0002-user-is-orchestrator.md)); a deep tree would make "which tier does what" untraceable.

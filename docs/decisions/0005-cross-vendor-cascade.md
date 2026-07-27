# ADR-0005 — Cross-vendor review cascade, bounded by a convergence cap

Status: Accepted · Applies principles: [Evidence-calibrated severity](../DESIGN-PRINCIPLES.md#5-evidence-calibrated-review-severity), [Cross-vendor cascade](../DESIGN-PRINCIPLES.md#6-cross-vendor-cascade-for-reasoning-diversity)

## Context

A single reviewer — however good — has systematic blind spots. Two reviewers from the *same* model family share most of them: same training data, same failure modes, correlated misses. On security-critical paths (hooks, auth, secrets, prod IaC, the classifier engine) a correlated miss is exactly the expensive kind.

Adding reviewers also has a cost curve that bends the wrong way: more reviewers → more findings → more review cycles → the loop can run forever as each cycle surfaces new nits. A review board with no convergence bound is a denial-of-service on the author.

Two problems to solve together: get *uncorrelated* review coverage, and stop the review from looping.

## Options

1. **Single reviewer.** Cheapest, fastest, correlated blind spots. Fine for low-stakes diffs, dangerous on security-critical ones.
2. **Multiple same-family reviewers.** More lenses (DevSecOps / architecture / AI-impact), but shared training means shared blind spots — diminishing returns on the misses that matter most.
3. **Add a different model family + bound the loop (chosen).** A codex-backed peer (`cross-vendor-reviewer`) reviews alongside the Claude-family peers, and the whole cascade is capped by a convergence mechanism.

## Decision

Option 3, structured as Pattern 3 (parallel fan-out with synthesizer):

- On security/architectural/AI-impact paths, `pr-reviewer` fans out **in parallel** to `architect-review` (architecture), `ai-architect` (LLM/agent-impact), and `cross-vendor-reviewer` (cross-vendor, codex-backed — a *different model family* for uncorrelated blind spots).
- `pr-reviewer` is the **synthesizer**: it merges all peer findings into one verdict, applying evidence-calibrated severity — an unverified BLOCKER gets downgraded, because "verified by reasoning" is not verification.
- The cascade is **cycle-bounded**: a 3-cycle cap, severity gating after cycle 1 (only real blockers can re-open), and finding-velocity convergence detection. This is what stops the board from looping as it grows.
- `cross-vendor-reviewer` is **never invoked directly by the orchestrator** — only by pr-reviewer, only when a path is genuinely security-critical. `patch-drafter` is its counterpart on the fix side: it *drafts* cross-vendor patches (via `/draft-pr-fixes`) and never applies them.

## Consequences

- Uncorrelated coverage where it pays: a second model family catches misses the Claude family shares. Spent only on security-critical paths — the cost is real, so it's targeted, not default-on.
- The convergence bound is load-bearing. Without the 3-cycle cap + severity gating + velocity detection, adding peers would make reviews slower without making them converge. Every new cascade peer must come with a model-tier justification and re-audit of the discipline table.
- Peer quality gate: every cascade peer must be ≥ the synthesizer's tier ([ADR-0001](0001-model-tiering.md)). A weak peer's shallow findings can't be recovered by the synthesizer — the cascade degrades silently, which is worse than a smaller board.
- This is the one place fan-out is allowed, and it's easy to mistake for the persona-calls-persona anti-pattern. It isn't: parallel peers, one synthesizer, bounded cycles, distinct lenses. The distinction is documented so it can't be cargo-culted into an unbounded chain — see [orchestration-patterns.md](../../shared-wiki/orchestration-patterns.md#cascade-clarification-pr-reviewer--anti-pattern-b).
- The verdict is trustworthy enough for a human to gate on ([ADR-0006](0006-outbound-human-gate.md)) without re-reviewing — which is the whole point of paying for the cascade.

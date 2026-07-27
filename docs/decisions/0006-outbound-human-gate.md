# ADR-0006 — Outbound actions are always human-gated

Status: Accepted · Applies principle: [Outbound actions are always human-gated](../DESIGN-PRINCIPLES.md#7-outbound-actions-are-always-human-gated)

## Context

The agents are good enough to draft a reply, classify a message, and produce a merge-ready review verdict. The tempting next step is to let them *act* — auto-send the reply, auto-merge the PR, auto-push the fix. That is where the risk profile changes completely. A wrong draft is a click away from being deleted. A wrong *send* is in someone's inbox. A wrong *merge* is in production. The convenience saved by automating the last step is small; the cost of the tail-risk wrong action is not.

This is a Type-1 (hard-to-reverse) boundary. The whole stack is designed so the irreversible step is the one place a human always stands.

## Options

1. **Full autonomy.** Agent sends, merges, pushes on its own. Maximum convenience, unbounded tail risk, and it removes the human exactly where judgment is most valuable.
2. **Confidence-thresholded autonomy.** Auto-act above some confidence score, gate below it. Moves the problem to calibrating the threshold — and the expensive failures are the confident-and-wrong ones, which is precisely where the threshold fails.
3. **Always gate outbound (chosen).** Agents draft, classify, surface. Every action that leaves the system or is hard to reverse stops at an explicit human decision.

## Decision

Option 3. Outbound is always a human decision:

- **Triage** presents every draft with `[Send] [Edit] [Skip]`. It never sends. The routing verdict work runs in *shadow mode* — it never hides an item and never touches sends; sending stays the explicit human gate even after a routing class "graduates."
- **PRs**: `gh pr create` is hooked to require `--draft` ([ADR-0004](0004-hooks-over-prompts.md)); flipping draft → ready is a separate, human step after review.
- **Fixes**: `patch-drafter` drafts patches and never applies them; the user reviews and cherry-picks. `implementer` makes edits but push/merge stays human.
- **Wiki**: agents write domain wikis, but shared-wiki promotion is human-only, and the gate pages are hook-protected from agent edits.

## Consequences

- The blast radius of an agent mistake is bounded to *drafts and local state*. Nothing an agent does autonomously reaches an inbox, production, or shared infra.
- Less automation, more clicks — accepted deliberately. The reversibility asymmetry (Type-1 vs Type-2) is the deciding factor, not a lack of capability. The agents *could* send; they're not allowed to.
- The gate is only real because it's enforced mechanically, not by prompt. Hooks make `gh pr create --draft` and the protected-page rules deterministic; a prompt-only gate would inherit the LLM miss rate exactly where a miss is irreversible.
- This is what lets the rest of the stack be aggressive about automation: fetch, classify, draft, synthesize, log — all can run at full speed *because* the one dangerous step is fenced. The human gate is what makes the automation safe to trust.
- Symmetry with the planning discipline: for Type-1 plans the closing decision sentence is written by the human, not the agent. Same principle — the human owns the irreversible commitment, at the plan boundary and at the send boundary.

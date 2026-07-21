# ADR-0007 — LLM judge for self-closing loops, fenced to the reversible side

Status: Proposed · Applies principles: [Evidence-calibrated severity](../DESIGN-PRINCIPLES.md#5-evidence-calibrated-review-severity), [Outbound actions are always human-gated](../DESIGN-PRINCIPLES.md#7-outbound-actions-are-always-human-gated)

## Context

Several loops in the stack currently stop on heuristics or a human: the test-green loop iterates until the suite passes, the review cascade stops on a 3-cycle cap + finding-velocity detection ([ADR-0005](0005-cross-vendor-cascade.md)), triage surfaces low-confidence items to a human. The proposal is to add an **LLM judge** — a model whose job is to grade another agent's output and decide whether a loop has converged, so some loops close themselves instead of asking a human or firing a blunt cap.

This is attractive (smarter stop conditions, less human babysitting) and dangerous (it moves a judgment call from a human to a model, and models can be gamed). It sits directly on top of the two principles the stack is most protective of: evidence-calibrated severity and the outbound human gate. So it gets an ADR before any code.

The deciding question is not "can an LLM judge?" — it can. It's "which loops may a judge close, and which must it never touch?"

## Options

1. **No judge.** Keep heuristic caps + human stops. Simple, no new failure modes, but leaves blunt caps (a fixed 3-cycle limit stops a converging-but-slow review too early or a runaway one too late) and keeps a human in loops that are genuinely reversible and low-stakes.
2. **Judge closes any loop, including outbound.** Judge decides "this reply is good, send it" / "this PR is clean, merge it." Maximum autonomy. Directly violates [ADR-0006](0006-outbound-human-gate.md) — and the failure mode is confident-and-wrong, which a same-family judge is least able to catch. Rejected for the same reason ADR-0006 rejected confidence-thresholded autonomy.
3. **Judge closes only reversible (Type-2) internal loops; never opens the outbound gate (chosen).** A judge may *stop* iterating; it may never *ship*. Every judge verdict is bounded, logged, and cross-vendor where it grades security-relevant output.

## Decision

Adopt Option 3. An LLM judge MAY be introduced, subject to four hard constraints:

- **Reversible loops only.** A judge may close a loop whose worst outcome is "we iterated one time too many/few" — test-green iteration, review-cascade convergence, triage routing confidence. A judge MUST NOT be the actor that sends a message, merges, pushes, or marks a PR ready. Those stay human ([ADR-0006](0006-outbound-human-gate.md)). The judge may *recommend* "ready"; a human still flips it.
- **Cross-vendor for security-relevant grading.** A judge from the same model family as the generator shares its blind spots — self-grading is theater. Where the judged output is security-relevant, the judge runs on a different model family (the `spock`/`scotty` cross-vendor pattern, [ADR-0005](0005-cross-vendor-cascade.md)).
- **Verifier immutability.** The judge MUST NOT be able to write what it grades. A judge that can edit the rubric, the tests, or the eval it scores against will drift toward passing itself. This is the exact threat `protect-gate-pages.sh` already defends ([ADR-0004](0004-hooks-over-prompts.md)); extend it to any judge-owned criteria.
- **Bounded and logged.** Every judge-closed loop keeps a hard iteration cap as a backstop (the judge tightens the stop, it does not remove the ceiling). Every verdict is logged with its inputs so judge quality is auditable and calibratable against periodic human sampling.

## Consequences

- Smarter stop conditions where they're safe: a converging-but-slow review can run to real convergence instead of hitting a fixed cap; a clearly-diverging one stops early. The cap becomes a backstop, not the primary signal.
- New failure modes to design against, named explicitly:
  - **Reward hacking** — the generator learns to satisfy the judge rather than the goal. Mitigated by cross-vendor judging, logging, and human-sampled calibration; never fully eliminated, which is why judges stay on the reversible side.
  - **Correlated blind spots** — same-family judge misses what the generator misses. Mitigated by the cross-vendor constraint.
  - **Verifier capture** — judge influences its own criteria. Mitigated by verifier-immutability (hook-enforced).
  - **Ground-truth drift** — no anchor, judge slowly redefines "good." Mitigated by periodic human calibration against sampled verdicts.
- The outbound gate is untouched. This ADR expands autonomy *behind* the gate and explicitly refuses to move the gate. That refusal is the point — it's what keeps the aggressive automation elsewhere safe to trust.
- Status stays **Proposed** until a first judge ships against one concrete reversible loop (candidate: review-cascade convergence, replacing the finding-velocity heuristic). Promote to Accepted only after that loop demonstrates the four constraints hold in practice, with logged verdicts to show it.

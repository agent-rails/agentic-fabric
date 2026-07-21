# ADR-0002 — The user (or a slash command) is the orchestrator

Status: Accepted · Applies principle: [The user is the orchestrator](../DESIGN-PRINCIPLES.md#4-the-user-is-the-orchestrator)

## Context

Multi-agent stacks drift toward a tempting shape: a "smart router" agent that reads the request, decides which specialist to call, calls it, and paraphrases the result back. It feels like the natural top of the tree. It is the single most common multi-agent anti-pattern, and it is expensive in ways that don't show up until you trace the tokens.

The work here is genuinely multi-persona — triage, review, cascade peers, build pipeline. Something has to compose them. The question is *what*: an LLM orchestrator, or the human plus saved prompts.

## Options

1. **Router / meta-orchestrator persona.** One agent decides which persona to call. Adds two paraphrasing hops (route-in, summarize-out) → information loss + ~2× token cost, and it replicates what a slash command already does. The user usually already knew they wanted a review — they could have said so.
2. **Sequential LLM orchestrator that runs the whole pipeline.** Calls review, then fixes, then pushes, on the user's behalf. Loses the human checkpoints that catch wrong-direction work early, accumulates summarization drift across the pipeline, doubles token cost per step, and removes agency exactly where judgment matters (which patches to cherry-pick).
3. **User (or slash command) as orchestrator (chosen).** Personas produce one perspective and hand back. Composition is the user running slash commands in sequence, with judgment between steps. The one allowed fan-out is Pattern 3 — parallel peers feeding a single synthesizer.

## Decision

Option 3. The governing rule: **personas do not invoke other personas, except as parallel peers feeding a synthesizer.** Slash commands are the orchestration layer; they are saved prompts, not routing agents. If a slash command's body is mostly "decide which persona to call," it should be deleted and the persona called directly.

The one intentional exception to depth-1 is the `orchestrator` agent for multi-step builds — and even it stays bounded by the cascade cycle cap.

## Consequences

- No paraphrasing tax, no lost checkpoints. Cost of the orchestration layer is effectively zero because there is no orchestration agent.
- Claude Code enforces this *by construction*: subagents cannot spawn subagents, and there are no nested teams. The router-persona, persona-calls-persona, and deep-tree anti-patterns literally fail to load. Contributors can't accidentally build them.
- The cost lands on the user: they must know the sequence (`/review-pr` → `/draft-pr-fixes` → cherry-pick → push). That knowledge is documented in the pattern catalog and the skills, not automated away — because automating it is exactly Option 2.
- Sentinel's cascade *looks* like persona-calls-persona but isn't: peers run in parallel, sentinel synthesizes, the cascade is cycle-bounded, and each peer has a distinct lens. The distinction is spelled out in [orchestration-patterns.md](../../shared-wiki/orchestration-patterns.md#cascade-clarification-sentinel--anti-pattern-b) so the exception can't be cargo-culted into a real violation.

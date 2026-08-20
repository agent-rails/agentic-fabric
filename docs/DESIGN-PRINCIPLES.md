# Design principles

The load-bearing whys. Each principle below has a cost — the point of writing them down is to make the tradeoff explicit so future changes are argued against it, not around it. The [decisions/](decisions/) records apply these principles to specific choices.

Two sources sit underneath this page and are worth reading directly:

- [shared-wiki/agent-principles.md](../shared-wiki/agent-principles.md) — the five principles that bind every persona's *work product*.
- [shared-wiki/orchestration-patterns.md](../shared-wiki/orchestration-patterns.md) — the patterns and anti-patterns for composing personas.

This page is the *system-design* layer sitting above both.

## 1. Judgment on the big model, mechanics on cheap ones

Opus does classification, drafting, synthesis, planning — anything needing judgment. Haiku fetches (large input, small digest — reasoning depth barely matters). Sonnet does scribing and edit-only implementation (mechanical, single-perspective).

- Tradeoff: more moving parts and more model-tier decisions to get right. A misrouted task (judgment on haiku) silently degrades quality.
- Guard: the model-tier gate — a cascade *peer* MUST match or exceed the synthesizer's tier, because a weak peer produces shallow findings the synthesizer can't recover. Fetchers and research-isolation subagents MAY be haiku. See [ADR-0001](decisions/0001-model-tiering.md).

## 2. Hooks over prompts for anything that must not be skipped

An LLM ignores a prompt instruction often enough (~1 in 5) that "the prompt says don't" is not a control. A PreToolUse hook is deterministic — the tool call is blocked at the harness, and the model physically cannot proceed.

- Use a hook when the rule is a hard gate: branch naming, draft-first PRs, protecting the review rubric from self-editing.
- Keep it in a prompt when the rule is judgment-shaped and a false block would be worse than an occasional miss.
- Tradeoff: hooks are code with their own failure modes. They must fail loud, never silently no-op (see `protect-gate-pages.sh`'s degraded-mode fallback). See [ADR-0004](decisions/0004-hooks-over-prompts.md).

## 3. Wikis as persistent memory

Sessions are stateless; the wiki is not. Every session reads relevant pages before acting and writes back after, via git. Memory compounds — triage starts with relationship context instead of cold-reading, review starts with repo/author history instead of first-principles every time.

- Agent wikis hold domain memory; shared-wiki holds only cross-cutting facts, gated by an explicit human promotion step so it stays small (~3-9 pages).
- Tradeoff: memory rots. Entity pages drift, pending items go stale within ~14 days. The relief valves are the auto-stale rule, the demotion path, and lint skills (`/wiki-lint`, `/memory-lint`). See [ADR-0003](decisions/0003-wiki-as-memory.md).

## 4. The user is the orchestrator

Personas produce one perspective and hand back. They do not call each other, except as parallel peers feeding a single synthesizer (Pattern 3). Composition happens through slash commands the user runs in sequence, with human judgment between steps.

- Why not an LLM "lifecycle orchestrator": it loses nuance at every hand-off (summarize-to-pass), skips the human checkpoints that catch wrong-direction work early, and roughly doubles token cost via paraphrasing turns.
- This is a prompt-level constraint, not a platform guarantee: subagents *can* spawn subagents (observed directly), so the router-persona / deep-tree anti-patterns are held off by convention and review, not by the harness. The depth-1 boundary is right; the belief that Claude Code enforced it "by construction" was wrong. See [ADR-0002](decisions/0002-user-is-orchestrator.md) and [ADR-0008](decisions/0008-orchestrator-depth-gate.md).

## 5. Evidence-calibrated review severity

A finding's severity is bounded by the evidence behind it. An unverified BLOCKER claim gets downgraded — "verified by reasoning" is a confession, not a status. A test plan is not a test until it has run.

- Applies the shared principle "verify before declaring done" to review output specifically.
- Keeps review noise down and keeps the BLOCKER label meaningful: if everything is a blocker, nothing is.

## 6. Cross-vendor cascade for reasoning diversity

On security-critical paths, a second model *family* (codex-backed `your-cross-vendor-reviewer`/`your-patch-drafter`) reviews alongside the Claude-family peers. Different training → different blind spots → findings one family would miss.

- Bounded on purpose: parallel peers, one synthesizer (your-pr-reviewer), a 3-cycle cap with severity gating and convergence detection — otherwise the cascade loops as the reviewer board grows.
- `your-cross-vendor-reviewer` is never invoked directly by the orchestrator — only by your-pr-reviewer, as a cascade step, when a path is genuinely security-critical. Cost is real; spend it where blind spots hurt. See [ADR-0005](decisions/0005-cross-vendor-cascade.md).
- **Honest degradation, not silent loss of coverage.** When no second-vendor CLI is reachable, the orchestrator does not just skip the cascade — it spawns `your-same-vendor-reviewer`, a same-model-family fallback that still runs a fresh, unprimed, adversarial pass with the same evidence-calibration discipline. It explicitly self-labels `cross_vendor: false` everywhere in its output, and your-pr-reviewer's synthesis tags its findings `(same-vendor)` rather than `(cross-vendor)`, so a genuine capability gap never gets quietly presented as full coverage.

## 7. Outbound actions are always human-gated

Anything leaving the system or hard to reverse — sending a message, merging, pushing, marking a PR ready — stops at an explicit human decision. Agents draft, classify, surface. The human commits.

- Triage presents `[Send] [Edit] [Skip]`; it never sends. The routing shadow-mode never hides an item and never touches sends.
- `gh pr create` is gated to `--draft`; flipping to ready is a separate human step.
- Tradeoff: less automation, more clicks. Accepted deliberately — the failure cost of an autonomous wrong send/merge dwarfs the convenience. See [ADR-0006](decisions/0006-outbound-human-gate.md).

## 8. Fail loud at the edge, trust the inside

Validate strictly at system boundaries (user input, external APIs, secrets, untrusted content). Trust internal callers and your own contracts. Defensive "just in case" capture *inside* the system introduces the failure modes it pretends to prevent.

- Named failure mode → handle it precisely. No named failure mode → drop the handling; it's debt.
- This is why the codebase avoids fallbacks: a silent fallback hides a broken assumption and turns a loud failure into a quiet wrong answer. From [agent-principles.md](../shared-wiki/agent-principles.md) §4.

## How these interact

The principles are not independent — they reinforce each other:

- *Model tiering* (1) only works because the *orchestration constraint* (4) keeps depth shallow enough to reason about which tier does what.
- *Wiki memory* (3) is what lets a cheap scribe do mechanical write-back while opus keeps the judgment — memory carries the context the cheap model would otherwise lack.
- *Hooks* (2) protect the *human gates* (7) and the *wiki rubric* (3) from being eroded by an agent that forgot the prompt.
- *Cross-vendor cascade* (6) and *evidence calibration* (5) both exist to make the review verdict trustworthy enough that a human can gate on it (7) without re-doing the work.

When a proposed change violates one principle to serve another, that's the signal to write an ADR, not to quietly pick a side.

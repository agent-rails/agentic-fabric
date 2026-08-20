# ADR-0010 — Orchestrator depth is prompt-enforced, not platform-mechanized

Status: Accepted · Applies principle: [The user is the orchestrator](../DESIGN-PRINCIPLES.md#4-the-user-is-the-orchestrator)

## Context

[ADR-0002](0002-user-is-orchestrator.md) sets orchestration depth at most 1: slash command → personas → synthesis in one designated agent, with a single intentional exception (the `orchestrator` agent for multi-step builds, bounded by the cascade cycle cap). Earlier revisions of the design docs claimed Claude Code guaranteed this "by construction" — that subagents could not spawn subagents. That claim is empirically false: nested subagent spawning has been observed directly this session. Correcting it (see the ADR-0002 and DESIGN-PRINCIPLES changes) surfaces a real question this record answers: with the platform *not* guaranteeing depth-1, what enforces it?

[Principle 2](../DESIGN-PRINCIPLES.md#2-hooks-over-prompts-for-anything-that-must-not-be-skipped) says a prompt is not a control for a hard gate — an LLM ignores an instruction often enough (~1 in 5) that "the prompt says don't" is not enforcement. By that principle's own logic, a depth constraint left to prompt compliance is a gate with no mechanism behind it. The honest options are to mechanize it or to document the gap plainly.

## Options

1. **Mechanize a depth gate.** A PreToolUse hook on the Task tool that counts call-nesting depth and blocks past the limit. This was the initial resolution. It requires a platform signal for how deep the current subagent sits in the call tree.
2. **A prompt-dependent stand-in.** Have the orchestrator set an env var when it spawns children, and gate on that. Rejected: this is the *opposite* trust model — it depends on the orchestrator prompt doing the right thing, degrades to the same ~1-in-5 miss rate, and would ship *false* mechanization. A gate that looks enforced but is prompt-dependent is worse than an honestly-labelled prompt rule, because it invites reliance it can't support.
3. **Document the gap honestly (chosen).** State plainly that depth-1 plus the orchestrator exception is prompt-enforced-only, record why it is not mechanized, and do not dress it up.

## Decision

Option 1 was attempted and found infeasible. Verified against the official Claude Code hook documentation: **no PreToolUse payload field exposes subagent call-nesting depth or lineage.** The documented payload carries `agent_id` / `agent_type` for the *current* subagent context only — no parent chain, no depth count, no ancestry anywhere in the schema. There is no signal to count against, so a real depth gate cannot be built today, and the prompt-dependent stand-in (Option 2) is a downgrade masquerading as an upgrade.

Therefore: **the depth-1 boundary and its one orchestrator exception are prompt-enforced only.** This is an accepted gap, documented here rather than mechanized or hidden. No depth-gate hook is built. When the platform exposes a nesting-depth or lineage signal, a real hook becomes buildable and this decision should be revisited.

Note the scope: this record is about *depth*. The irreversible *actions* at the leaves (create, merge, push, send) are gated independently at the point they happen — see [ADR-0006](0006-outbound-human-gate.md) and the PR-create / PR-merge gates — and do not depend on knowing call depth. A deep call tree cannot take an ungated outbound action even though depth itself is unmechanized.

## Consequences

- The constraint is honest about what it is: a convention held by prompt discipline, review, and the pattern catalog, not a harness guarantee. No reader is misled into trusting a control that does not exist.
- Contributors *can* build the deep-tree and persona-calls-persona anti-patterns; nothing in the harness stops them. The defense is the pattern catalog, review, and this record naming the risk — not construction-time impossibility.
- Blast radius is bounded not by depth enforcement but by the independent outbound-action gates: the expensive-to-reverse steps stop at a human regardless of how the call tree is shaped.
- A revisit trigger is named: a platform nesting-depth/lineage signal. Until then, mechanizing depth would require the weaker-trust env-var trick, which is explicitly rejected.

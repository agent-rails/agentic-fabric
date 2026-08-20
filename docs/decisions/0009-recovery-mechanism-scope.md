# ADR-0009 — Recovery mechanism scope: transcript-resume is canonical

Status: Accepted · Applies principle: [The user is the orchestrator](../DESIGN-PRINCIPLES.md#4-the-user-is-the-orchestrator)

## Context

Long-running and background work in this stack fails in one dominant way: the Claude session hits its usage limit mid-task. Two mechanisms could recover from it, and they are not interchangeable:

1. **Transcript-resume** — the operator sends the stalled or limited task a message (the harness `SendMessage` path) and a fresh instance continues from the existing transcript, keeping the full prior context.
2. **A vendor swap** — the sibling `provider-router` library, which on a matched usage-limit failure would route the *next* call to a second-vendor CLI, and on any failure of that, to a local model.

Left unnamed, these ship as two adjacent recovery mechanisms with no owner — the exact "adjacent-but-not-identical subsystems" smell the reconciliation plan set out to remove. This record names which one is canonical and scopes the other to the leg it actually owns.

## Options

1. **Vendor swap as primary recovery.** Let `provider-router`'s primary→second-vendor leg be the standard response to a Claude usage limit. Rejected: a vendor swap *loses the resumed instance's transcript* — the second vendor starts cold. It also cannot observe the failure that matters. As `provider-router`'s own design states, a Claude Code session cannot spawn itself as a callable, and a library cannot see the current session running out of quota from the inside. The primary→second-vendor leg is real, tested code, but it fires for spawned subagent-equivalent work detected from task-notification text — not for the interactive session that is where these limits actually get hit.
2. **Transcript-resume as canonical (chosen).** Recover a limited Claude task by resuming it from its own transcript. Proven 3/3 on real usage-limit failures this session; it preserves the full working context a vendor swap would discard.

## Decision

Option 2. **`SendMessage`-resume-from-transcript is the canonical recovery mechanism for a Claude session-limit failure.** It is what actually recovered every real limit hit, and it keeps the context that makes the resumed work correct.

`provider-router` is **scoped down to the one leg nothing else covers: second-vendor-CLI → local-model failover.** That leg fires on any failure of the second-vendor CLI and degrades to a slow local model as a last resort — a genuine gap with no other owner. Its primary→second-vendor leg (Claude → second vendor) is **deliberately left unused by this org's actual practice**: the interactive session where Claude limits are hit has no task-notification text for the library to trigger on, and transcript-resume both covers that case and preserves context the swap would lose. The library stays as-is; this decision is about which of its legs this stack relies on, not a change to the library.

## Consequences

- One named recovery path for the failure that dominates in practice, instead of two un-owned adjacent mechanisms. When a Claude task hits its limit, the answer is "resume it from transcript," full stop.
- **Resume-safety rests on operator discipline, not a mechanized check.** Resuming from a transcript re-enters work that may have partially completed; the operator must verify real state (git, remote, filesystem) before acting on a resumed instance's assumptions. This is an accepted gap, called out honestly rather than papered over — the same posture [ADR-0010](0010-orchestrator-depth-gate.md) takes on the depth constraint.
- The second-vendor-CLI → local-model leg keeps a real, tested last-resort path for spawned work, without pretending it is the recovery story for interactive Claude limits.
- If a Claude-invocable-as-callable primitive ever ships, this decision is worth revisiting — the vendor-swap leg becomes reconsiderable only when it can preserve context, which today it cannot.

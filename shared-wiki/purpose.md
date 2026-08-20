# Shared Wiki — Purpose

This file declares **why** the shared-wiki layer exists. For **how** the layer is structured, see `index.md`.

Every agent reads this file alongside `index.md` so it knows what shared-wiki is for, what gets promoted into it, and what stays in agent-specific wikis.

## Core purpose

Shared-wiki is the **cross-cutting convention layer** read by every agent on every invocation. It holds the small set of *principles and disciplines* that multiple agents must obey so each agent does not re-derive them or drift on them independently. In practice that is exactly four pages: `agent-principles.md`, `search-discipline.md`, `orchestration-patterns.md`, `engineering-pitfalls.md`.

It does **not** hold user/entity facts (who the user is, who they work with, what repos or projects exist). That role is filled by the Claude Code platform's own auto-memory (`~/.claude/projects/<project>/memory/`) — a set of topic files with a `MEMORY.md` index the harness loads automatically. Those facts are owned there, not here; shared-wiki cites them by reference when a convention needs one, but never keeps its own copy, because two copies of the same entity fact drift apart. Per-agent wikis hold domain-specific knowledge.

## What belongs here

A fact belongs in shared-wiki if and only if:

1. **Multiple agents need it.** A fact only one agent uses stays in that agent's wiki.
2. **It is stable.** Things that change daily belong in agent wikis or pending lists, not here.
3. **It is cross-cutting.** Facts about a specific PR, a specific Slack thread, a specific incident belong in the agent wiki that owns that surface.
4. **The user explicitly promoted it.** Shared-wiki never receives silent writes during task execution. Promotion is an explicit human decision.

## What does NOT belong here

- Triage history (lives in `~/your-triage-agent/wiki/people/`)
- PR review history (lives in `~/your-pr-reviewer/wiki/authors/` and `wiki/repos/`)
- Anti-patterns and patterns (live in agent wikis, cited by name from here only if cross-cutting)
- Daily / weekly reports (lives in `~/your-triage-agent/wiki/reports/`)
- Operational state, alerts, incidents in flight (live in your-triage-agent)
- Anything that would force a re-read on every invocation if it changed weekly

## Key questions this layer should answer

Any agent in any invocation should be able to answer these by reading shared-wiki alone, no agent-specific wiki required:

- What principles apply to every agent's behavior? (`agent-principles.md`)
- What search discipline applies when any agent uses Grep / Glob? (`search-discipline.md`)
- What patterns and anti-patterns apply to multi-agent orchestration? (`orchestration-patterns.md`)
- What recurring engineering pitfalls has this stack already paid for and codified? (`engineering-pitfalls.md`)

Questions about *who* — the user, the people they work with, the repos and projects in flight, their durable architectural decisions — are **not** answered here. Those live in the platform auto-memory (`~/.claude/projects/<project>/memory/`) and are read from there. If an agent needs an entity fact, it reads auto-memory; shared-wiki does not mirror it.

## Promotion path

Facts arrive in shared-wiki via one of two paths:

1. **From auto-memory (`~/.claude/projects/.../memory/`)** — a feedback rule or user fact that turns out to apply across multiple agents. The user says "promote this" and Claude moves it. Auto-memory becomes the staging ground.
2. **From an agent wiki** — a per-agent observation that turns out to be cross-cutting. The owning agent surfaces the candidate in its output; the user confirms; Claude promotes.

**Never automatic.** Scribes do not write to shared-wiki. Agents do not write to shared-wiki during task execution. The promotion gate is the discipline that keeps shared-wiki small and authoritative.

## Demotion path

If a fact in shared-wiki turns out to only matter to one agent, or becomes stale, or contradicts current reality:

1. Move the canonical copy into the agent wiki that actually uses it, or remove it entirely
2. Update any agent prompts that referenced it
3. Note the demotion in `~/your-triage-agent/wiki/log.md` so the audit trail is preserved

Shared-wiki bloat is the failure mode. Demotion is the relief valve.

## Evolving thesis

What this layer is learning over time:

- **Small is the point.** The whole layer is the four principle pages. Fewer means the disciplines drift back into agent wikis; more means the "read every invocation" cost stops being worth it. Entity facts do not count against this budget — they live in platform auto-memory, not here.
- **The value is entirely in the principles** (`agent-principles.md`, `search-discipline.md`, `orchestration-patterns.md`, `engineering-pitfalls.md`) — they shape behavior across every agent invocation without needing per-agent customization. That is why this layer earns a read on every invocation despite being small.
- **Entity drift is auto-memory's problem, not this layer's.** People/repos/projects decay into "the way things were when last edited" — but that decay is managed in `~/.claude/projects/<project>/memory/` (via `/memory-lint`), not here, precisely because those facts were never copied into shared-wiki.
- **The promotion gate is load-bearing.** Every time it has been relaxed historically, shared-wiki has grown faster than it improved review or triage quality.

## Read order for any agent

1. `~/.claude/shared-wiki/index.md` (~50 lines, always cheap)
2. `~/.claude/shared-wiki/purpose.md` (this file, once per session)
3. The 2–4 shared-wiki pages relevant to the task (per index.md's per-task reading list)
4. The agent's own `purpose.md` + `schema.md`
5. Agent-specific entity pages

If shared-wiki and an agent wiki disagree on a cross-cutting fact, **shared-wiki is authoritative**. Flag the disagreement so the user can resolve — don't paper over.

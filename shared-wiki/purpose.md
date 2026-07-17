# Shared Wiki — Purpose

This file declares **why** the shared-wiki layer exists. For **how** the layer is structured, see `index.md`.

Every agent reads this file alongside `index.md` so it knows what shared-wiki is for, what gets promoted into it, and what stays in agent-specific wikis.

## Core purpose

Shared-wiki is the **cross-cutting fact layer** read by every agent on every invocation. It holds the small set of facts that multiple agents need so each agent does not re-derive them, re-fetch them, or drift on them independently.

Without this layer, each agent's wiki would duplicate the same cross-cutting facts (who the user is, what repos exist, what the engineering principles are) and they would drift apart over time. With this layer, agents share a single source of truth for the facts that span their domains, and per-agent wikis hold only domain-specific knowledge.

## What belongs here

A fact belongs in shared-wiki if and only if:

1. **Multiple agents need it.** A fact only one agent uses stays in that agent's wiki.
2. **It is stable.** Things that change daily belong in agent wikis or pending lists, not here.
3. **It is cross-cutting.** Facts about a specific PR, a specific Slack thread, a specific incident belong in the agent wiki that owns that surface.
4. **The user explicitly promoted it.** Shared-wiki never receives silent writes during task execution. Promotion is an explicit human decision.

## What does NOT belong here

- Triage history (lives in `~/voltage/wiki/people/`)
- PR review history (lives in `~/sentinel/wiki/authors/` and `wiki/repos/`)
- Anti-patterns and patterns (live in agent wikis, cited by name from here only if cross-cutting)
- Daily / weekly reports (lives in `~/voltage/wiki/reports/`)
- Operational state, alerts, incidents in flight (live in voltage)
- Anything that would force a re-read on every invocation if it changed weekly

## Key questions this layer should answer

Any agent in any invocation should be able to answer these by reading shared-wiki alone, no agent-specific wiki required:

- Who is the user? What role, what preferences, what autonomy model, what communication style?
- Who are the people the user works with across agents? GitHub handles, Slack handles, primary repos, role.
- What repos does the user work on? Primary purpose, owner team, security posture.
- What ongoing projects / initiatives is the user driving? Status, stakeholders, deadlines.
- What durable architectural decisions must agents respect without relitigating?
- What principles apply to every agent's behavior? (`agent-principles.md`)
- What search discipline applies when any agent uses Grep / Glob? (`search-discipline.md`)
- What patterns and anti-patterns apply to multi-agent orchestration? (`orchestration-patterns.md`)

## Promotion path

Facts arrive in shared-wiki via one of two paths:

1. **From auto-memory (`~/.claude/projects/.../memory/`)** — a feedback rule or user fact that turns out to apply across multiple agents. The user says "promote this" and Claude moves it. Auto-memory becomes the staging ground.
2. **From an agent wiki** — a per-agent observation that turns out to be cross-cutting. The owning agent surfaces the candidate in its output; the user confirms; Claude promotes.

**Never automatic.** Scribes do not write to shared-wiki. Agents do not write to shared-wiki during task execution. The promotion gate is the discipline that keeps shared-wiki small and authoritative.

## Demotion path

If a fact in shared-wiki turns out to only matter to one agent, or becomes stale, or contradicts current reality:

1. Move the canonical copy into the agent wiki that actually uses it, or remove it entirely
2. Update any agent prompts that referenced it
3. Note the demotion in `~/voltage/wiki/log.md` so the audit trail is preserved

Shared-wiki bloat is the failure mode. Demotion is the relief valve.

## Evolving thesis

What this layer is learning over time:

- **Three to nine pages is the right size.** Fewer means duplication across agent wikis; more means the "read selectively per task" discipline breaks.
- **The most valuable pages are the principles** (`agent-principles.md`, `search-discipline.md`, `orchestration-patterns.md`) — they shape behavior across every agent invocation without needing per-agent customization.
- **Entity pages (people, repos, projects) are the most likely to drift.** They need explicit refresh discipline; otherwise they decay into "the way things were when this was last edited."
- **The promotion gate is load-bearing.** Every time it has been relaxed historically, shared-wiki has grown faster than it improved review or triage quality.

## Read order for any agent

1. `~/.claude/shared-wiki/index.md` (~50 lines, always cheap)
2. `~/.claude/shared-wiki/purpose.md` (this file, once per session)
3. The 2–4 shared-wiki pages relevant to the task (per index.md's per-task reading list)
4. The agent's own `purpose.md` + `schema.md`
5. Agent-specific entity pages

If shared-wiki and an agent wiki disagree on a cross-cutting fact, **shared-wiki is authoritative**. Flag the disagreement so the user can resolve — don't paper over.

# Triage-agent Wiki — Purpose

This file declares **why** the triage-agent wiki exists. For **how** the wiki is structured and maintained, see `schema.md`.

Every triage-agent and triage-scribe invocation reads this file alongside `schema.md` so the agent knows what to flag, what to ingest deeply, and what to let slide.

## Core purpose

Triage-agent is the persistent memory of a Principal DevOps / SRE engineer's communication and operations surface — Slack, email, calendar, incidents, alerts, and the people behind them. It exists to compound institutional knowledge over months and years so that:

- Each triage session starts with full relationship context instead of cold-reading every thread
- Recurring patterns (escalation paths, who-owns-what, channel norms, alert noise) get codified instead of re-learned every time
- Action items, waiting items, and decisions don't drop on the floor between conversations
- Visible work (PRs, incidents, alerts, decisions) is logged immediately so credit and audit trail are preserved
- The user's chief-of-staff function scales without the user re-explaining the same context to the agent

## Key questions this wiki should be able to answer

If triage-agent cannot answer these in <30 seconds from the wiki, the wiki has failed its purpose:

- Who is `{person}` and how have we interacted? What do they owe me / what do I owe them?
- What is `{channel}` for, who are the key people, and how should I respond to messages there?
- What is the status of `{project}` and who are the stakeholders?
- What recurring meetings / events does the user have, and what is the prep / agenda?
- What action items are open, sorted by deadline?
- What is the user waiting on from others, sorted by staleness?
- What happened in `{incident}` and what were the action items / lessons?
- What is the user's tone / communication preference for `{channel}` or `{person}`?

## What this wiki is NOT

- **Not a source of truth for live operational data.** For live cluster state, current PR status, real-time metrics — query the source system. The wiki holds the synthesis and history, not the live state.
- **Not a Notion replacement.** Notion remains the home for human-shaped long-form content (RFCs, design docs, meeting notes, onboarding). Triage-agent points AT Notion when relevant; it does not duplicate Notion.
- **Not an autonomous decision-maker.** Triage-agent drafts, classifies, and surfaces. The user decides. Anything reaching master / shared infra / external messages requires human-in-the-loop.

## Evolving thesis

What this wiki is learning over time, updated as patterns crystallise:

- **Triage compresses well**: most messages map to one of four tiers (skip / info_only / meeting_info / action_required), and the long tail is small enough that pattern pages cover it
- **People context decays slowly**: once a person page exists with relationship + tone + history, it stays useful for months with minimal upkeep
- **Pending items rot if not surfaced**: action / waiting / decision items go stale within 14 days if not touched; the auto-stale rule is load-bearing
- **Visible-work logging is the single highest-leverage habit**: missed log entries = missed credit; the discipline pays back compounding
- **Shared facts about people / repos / projects belong in `~/.claude/shared-wiki/`**, not duplicated here — triage-agent links out, doesn't fork the source of truth

## Promotion path

Facts in triage-agent that become cross-cutting (multiple agents need them) are candidates for promotion to `~/.claude/shared-wiki/`. Promotion requires explicit user direction — triage-scribe never writes to shared-wiki silently. When a promotion candidate appears (e.g., a stable cross-cutting fact about a person, repo, or project), triage-agent surfaces it in the triage output for the user to confirm.

## Read order for new pages / context

When the agent doesn't have prior context for a target entity, the canonical read order is:

1. `~/.claude/shared-wiki/index.md` → relevant cross-cutting pages
2. `~/triage-agent/purpose.md` (this file)
3. `~/triage-agent/schema.md`
4. `~/triage-agent/wiki/{type}/{entity}.md` — the specific entity page

If the entity-specific page does not exist, that is not an error; it just means no prior context. The scribe creates one on the next ingest.

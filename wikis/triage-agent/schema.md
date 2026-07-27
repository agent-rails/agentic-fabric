# Triage-agent Wiki — Schema

This document defines the structure, ingestion rules, and page templates for the LLM-maintained wiki. The wiki serves as the persistent knowledge layer for a Principal DevOps Architect who manages communications, infrastructure operations, and team coordination across Slack, email, calendar, and incident channels.

## Three-Layer Architecture

```
sources/     Immutable raw inputs. Never modified after ingestion.
wiki/        LLM-maintained markdown. Updated incrementally as sources arrive.
schema.md    This file. Defines structure, templates, and ingestion rules.
```

## Wiki Structure

```
wiki/
  index.md              Navigation hub — auto-generated list of all pages with last-updated dates
  log.md                Ingestion log — what source was processed, when, what pages were affected
  log.jsonl             Structured sidecar to log.md — one JSON object per scribe pass for jq-driven mining

  people/               One page per person. Relationship context, interaction history, pending items.
    _template.md        Template for new person pages

  channels/             One page per Slack channel or communication channel actively monitored.
    _template.md        Template for new channel pages

  services/             One page per service/system the architect owns or advises on.
    _template.md        Template for new service pages

  recurring/            One page per recurring meeting or event.
    _template.md        Template for new recurring pages

  pending/
    actions.md          Things the architect owes others. Sorted by deadline.
    waiting.md          Things others owe the architect. Sorted by staleness.
    decisions.md        Decisions awaiting input or approval.

  incidents/            One page per significant incident. Synthesized from postmortems, Slack threads, metrics.
    _template.md        Template for new incident pages

  patterns/
    communication.md    Tone rules, signatures, per-channel conventions (replaces SOUL.md)
    scheduling.md       Availability rules, timezone handling, free slot preferences
    escalation.md       When and how to escalate, who to loop in, SLA expectations
    triage.md           Message classification rules, priority ladder, routing logic
    infrastructure.md   Common infra patterns, debugging sequences, known failure modes
```

## Ingestion Rules

When a new source is added to `sources/`, the LLM:

1. Reads the source completely
2. Identifies entities: people, channels, services, incidents, meetings, action items
3. For each entity:
   - If a wiki page exists: update it with new information, append to interaction history
   - If no page exists: create one from the appropriate `_template.md`
4. Cross-reference: link related pages using `[[page-name]]` syntax
5. Update `pending/actions.md` and `pending/waiting.md` if action items are found
6. Append an entry to `wiki/log.md`
7. Regenerate `wiki/index.md`

### Conflict Resolution

- New information supplements, never replaces, unless explicitly contradictory
- When contradiction is found: note both versions with dates, flag for human review with `[CONFLICT]` tag
- Stale information (>90 days with no updates) gets marked `[STALE]` but not deleted

### Source Types

| Source type | Location | Entities extracted |
|---|---|---|
| Slack thread export | `sources/slack/` | People, channels, action items, decisions |
| Email thread | `sources/email/` | People, action items, meeting info, scheduling |
| Meeting notes/transcript | `sources/meetings/` | People, decisions, action items, recurring updates |
| Incident report/postmortem | `sources/incidents/` | Services, people, timeline, root cause, remediation |
| Postmortem | `sources/postmortems/` | Services, failure patterns, people, action items |

## Page Templates

### People (`people/_template.md`)

```markdown
# {Name}

## Identity
- Role:
- Team:
- Timezone:
- Preferred channel:

## Relationship Context
- How we interact:
- Tone: formal | casual | friendly
- Key context:

## Interaction History
<!-- Reverse chronological. One line per significant interaction. -->

| Date | Channel | Summary | Follow-up? |
|------|---------|---------|------------|

## Pending
- Owe them:
- They owe me:

## Notes
```

### Channels (`channels/_template.md`)

```markdown
# {Channel Name}

## Purpose
## Priority Level
<!-- URGENT | HIGH | MEDIUM | LOW -->
## Key Members
## Alert Patterns
<!-- What fires here, how often, what it usually means -->
## Response Conventions
<!-- Expected response time, who handles what, escalation path -->
## Recent Activity Summary
```

### Services (`services/_template.md`)

```markdown
# {Service Name}

## Overview
- Repo:
- Owner team:
- Environment: dev | stage | prod
- Cluster:

## Architecture
## Dependencies
## Common Issues
<!-- Recurring problems, known failure modes, debugging shortcuts -->
## Recent Incidents
## Contacts
<!-- Who to page, who knows this service best -->
```

### Recurring Events (`recurring/_template.md`)

```markdown
# {Event Name}

## Schedule
- Frequency:
- Time:
- Duration:
- Timezone:

## Attendees
## Format/Agenda
## Prep Required
## Notes History
<!-- Append after each occurrence -->
```

### Incidents (`incidents/_template.md`)

```markdown
# {Incident Title} — {Date}

## Timeline
## Services Affected
## Root Cause
## Resolution
## Action Items
## Lessons Learned
## Related Incidents
```

## Daily Report Format

Daily reports live in `wiki/reports/daily/{YYYY-MM-DD}.md`.

**Format applies to reports from 2026-04-25 onward.** Reports before that date remain in their original freeform style.

### Structure

```markdown
# YYYY-MM-DD

## {Topic / Project Header}

- Item
- Item
  - Sub-context (one level only)
- [wip] In-progress item
  - Blocking detail or sub-context

## Misc.

- One-off items that don't justify their own section

## Firefighting

- Incident-shaped work (omit section if none that day)
```

### Rules

1. The date is the H1 (`# 2026-04-26`). No other top-level heading.
2. Each `##` header is a descriptive topic or project — named for the actual work that day, not a stable category.
3. Every item is a `-` bullet under a `##` header. No freeform paragraphs.
4. Sub-context goes as nested `-` bullets, one level deep only.
5. `[wip]` is an inline prefix tag on the bullet for in-progress items. The old standalone `[WIP]` callout style is deprecated.
6. Two reserved sections always sit at the bottom when present:
   - `## Misc.` — catch-all for one-offs
   - `## Firefighting` — incident-shaped work
7. Items that were previously freeform WIP callouts at the end of a report are migrated to `[wip]` bullets under the appropriate topic header.

### Example

```markdown
# 2026-04-26

## EKS Cluster Config Drift

- Resolve config drift for staging EKS
- Resolve drift for dev EKS
- [wip] Continue working on access entries enablement on shared EKS cluster
  - Hitting issues due to config forcing replacement; looking into alternatives

## Misc.

- Ship the service-a base image bump from node20 to node24
- Update remote-config for service-b to the non-live domain
- [wip] Repeat for service-c non-live domain
- Rotate service-d credentials after DB restore
- Review PRs

## Mirror worker for service-e in dev

- Discuss and clarify the mirror worker setup with a teammate
- Flag some concerns
- Assist with metrics in the CDN dashboard

## Firefighting

- Investigate an asset issue reported by support
- Check Cloudflare metrics
- Attempt local repro and conclude it looked like a blip
```

## Maintenance Rules

- `wiki/index.md` is regenerated after every ingestion
- `wiki/log.md` is append-only
- `wiki/log.jsonl` is append-only — one JSON object per scribe pass, written in the same Edit pass as the matching `log.md` row. Schema lives in triage-scribe agent prompt (controlled vocab for `op` and `source`, integer counts).
- Pages in `pending/` are reviewed during every triage session
- `[STALE]` tags are added during weekly review (items >90 days untouched)
- `[CONFLICT]` tags require human resolution before the page is considered reliable

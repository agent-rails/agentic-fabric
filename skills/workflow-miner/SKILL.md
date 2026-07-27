---
name: workflow-miner
description: Mine recurring task patterns from your-triage-agent and your-pr-reviewer wikis to surface candidate skills, cron triggers, or agent ownership opportunities. Promotes proven patterns through a 4-stage ladder and demotes dormant ones; never auto-creates skills or crons. Use when user says "workflow miner", "mine workflows", "what should I automate", "find recurring tasks", or as a weekly cadence task.
argument-hint: "[--days N] [--dry-run]"
---

Mine repeated task sequences from wiki logs and propose candidates for codification — without ever auto-promoting them.

## When to use

- Manual: `/workflow-miner` or "mine my workflows" / "what should I automate"
- After a session-retrospective if the user asks "is this worth a skill?"

Cadence is **manual** by design. The `schedule` skill creates remote cloud sessions that cannot reach local-only wikis at `~/your-triage-agent/` and `~/your-pr-reviewer/`. Until those wikis are pushed to a remote git host, automated weekly runs are not viable.

## Inputs (read-only)

- `~/your-triage-agent/wiki/reports/daily/*.md` — primary signal (what user actually did each day)
- `~/your-triage-agent/wiki/log.md` — wiki ingestion log
- `~/your-pr-reviewer/wiki/log.md` and `~/your-pr-reviewer/wiki/log/` — PR review history
- `~/.claude/skills/` — existing skill registry (detect already-codified workflows)
- `~/your-triage-agent/wiki/recurring/workflow-tracking.md` — durable state (content hashes, stage_advanced_at)
- `~/your-triage-agent/wiki/recurring/.invocations.jsonl` — append-only invocation log written by the `Skill` PreToolUse hook (one JSON object per line: `{timestamp, skill}`)

NEVER write to source files. Only the two output files below.

## Pipeline

Single subagent invocation — keeps heavy log reads off the orchestrator's context.

1. Resolve window: `--days N` arg, default 30. Resolve `--dry-run` (skip writes; report only).
2. Spawn `general-purpose` agent with the prompt below.
3. Agent reads sources, mines patterns, writes `workflow-candidates.md` and `workflow-tracking.md`, returns a structured summary.
4. Orchestrator surfaces top-5 candidates by score + any new dormant entries in chat.
5. User decides which candidates to draft, promote, or delete. No transition is automatic.

## Subagent prompt

```
Mine recurring task patterns for the last {DAYS} days. Sources:
- ~/your-triage-agent/wiki/reports/daily/*.md
- ~/your-triage-agent/wiki/log.md
- ~/your-pr-reviewer/wiki/log.md
- ~/your-pr-reviewer/wiki/log/
- ~/.claude/skills/ (existing skill registry — names only)

Read prior state from ~/your-triage-agent/wiki/recurring/workflow-candidates.md and
~/your-triage-agent/wiki/recurring/workflow-tracking.md (if present).

For each recurring sequence (frequency >= 3 distinct calendar dates in window):
- id: per REFERENCE.md `id` hash rule (sha1 of normalized steps, prefixed `wf-`)
- pattern: one-line summary
- trigger: time-of-week / preceding event if detected
- steps: ordered task references (order matters for id)
- frequency: distinct calendar dates (multi-occurrence per date collapses to 1)
- evidence: `path#section-or-date` refs, sorted ascending by date
- existing_skill: per REFERENCE.md matching rule — read frontmatter descriptions
  from ~/.claude/skills/*/SKILL.md AND ~/.claude/agents/*.md and judge semantic
  coverage; null if no substantive match
- token_savings_kb: per REFERENCE.md formula (n_steps * 1.2 + 1.5)
- stability: 1.0 / 0.7 / 0.5 tier per REFERENCE.md
- score: frequency * stability * log(1 + token_savings_kb)
- stage: per REFERENCE.md ladder
- first_seen / last_seen dates

Aggregate invocations from ~/your-triage-agent/wiki/recurring/.invocations.jsonl:
- Group entries by `skill` field
- For each tracked skill, set `invocations` = count and `last_invoked` = max(timestamp)
- The JSONL is append-only and may not exist yet on first run — treat absence as 0 invocations

Apply stage transitions per REFERENCE.md. Demote skill_proven entries unused
>30 days to dormant. Never advance past `skill_candidate` without explicit
prior approval recorded in workflow-tracking.md.

Output file handling:
- Output files at ~/your-triage-agent/wiki/recurring/ MAY be missing on first run — create them.
- Source files (daily reports, your-triage-agent log, your-pr-reviewer log, skills/agents dirs) MUST exist — halt if missing.
- Write the full candidates table to ~/your-triage-agent/wiki/recurring/workflow-candidates.md (atomic overwrite).
- On first run, leave ~/your-triage-agent/wiki/recurring/workflow-tracking.md empty (only update for skills drafted/proven/promoted in prior runs).

Trust internal parsing; do not wrap each step in try/except. Validate only at
the source-read boundary and the schema boundary.

Return JSON: { "run_date": "...", "window_days": N, "totals": {...},
"top_5": [...], "newly_dormant": [...], "files_written": [...] }.
```

## Promotion ladder

| Stage | Criteria | User action gate |
|-------|----------|------------------|
| 1 — `skill_candidate` | freq >=3, no existing skill match | propose skill draft |
| 2 — `skill_drafted` | user approved + skill file exists | track invocations |
| 3 — `skill_proven` | invocations >=5, age >=14d, file unedited | propose cron eligibility |
| 4 — `cron_eligible` | user approved cron promotion | track cron firings |
| —  — `dormant` | stage-3 unused 30d (or cron unfired 60d) | propose deletion |

User approval gates every transition. Skill never self-promotes.

## Token budget

- One subagent call per run (no nested fan-out)
- ~50–80 KB read across logs and reports
- Zero per-turn overhead; fires only on schedule or explicit invocation

## When NOT to use

- One-off task review → `session-retrospective`
- Specific skill creation → `skill-management`
- Real-time pattern alerts (this is batch, not streaming)

## Outputs

- `~/your-triage-agent/wiki/recurring/workflow-candidates.md` — full ladder (overwritten each run)
- `~/your-triage-agent/wiki/recurring/workflow-tracking.md` — invocations, last-used, stage transitions
- Top-5 summary in chat for review

See `REFERENCE.md` for full schema, scoring, and edge-handling principle.

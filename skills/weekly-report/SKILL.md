---
name: weekly-report
description: Generate weekly status summary from daily reports and activity. Saves to voltage wiki and DMs via Slack. Use when user asks for "weekly report", "weekly summary", "weekly status", or "week in review".
argument-hint: "[YYYY-MM-DD] (defaults to this Friday)"
---

Generate a weekly status report using the voltage-reporter agent.

## Input

- `/weekly-report` — report for current week (uses this Friday's date)
- `/weekly-report 2026-04-11` — report for week ending on specific date

Default: this Friday's date.

## Execution

The voltage-reporter agent has read-only Slack search (for gathering) but NOT Slack send tools — it generates and persists; the orchestrator (main thread) delivers. This avoids the recurring stall pattern at the DM step.

1. Determine TARGET_DATE from arguments (or this Friday)
2. Resolve the user's Slack DM channel ID from `~/.claude/projects/-Users-youruser/memory/user_slack.md`.
3. Spawn `voltage-reporter` agent with:

```
Generate a weekly report for TARGET_DATE: {date}

1. Read user identity from user memory (Slack user ID, GitHub username)
2. First, generate today's daily report if not already saved
3. Read daily reports from ~/voltage/wiki/reports/daily/ for Mon-Fri of this week
4. For missing days, gather from GitHub and Slack directly via slack_search_public_and_private (read-only — you have no Slack SEND tools)
5. Synthesize into weekly format (grouped by theme, not by day)
6. Save to ~/voltage/wiki/reports/weekly/{TARGET_DATE}.md
7. Git commit in ~/voltage/
8. Return: file paths, commit SHA, and BOTH message bodies (daily + weekly) verbatim — do NOT attempt to DM (you have no Slack SEND tools; delivery is the orchestrator's job).
```

4. **Resilient delivery (queue-backed, self-healing).** Same model as `/daily-report` — generation is local, the Slack DMs need internet; never send-and-forget (an offline send-time moment must not silently drop the report). Queue → send → remove-on-success, draining stragglers first:

   a. **Drain first (backfill).** List `~/.claude/agents/voltage-reporter/pending-dm/`; for each stranded file in filename order, verify the Slack ID, `mcp__plugin_slack_slack__slack_send_message` its body, `rm` ONLY on a confirmed send. Recovers anything a prior offline run stranded.
   b. **Queue both messages** BEFORE sending, in send order: `pending-dm/weekly-{TARGET_DATE}-1-daily.md` then `pending-dm/weekly-{TARGET_DATE}-2-summary.md`.
   c. **Verify + send in order.** Verify the resolved Slack ID via `mcp__plugin_slack_slack__slack_read_user_profile` (mandatory), then `mcp__plugin_slack_slack__slack_send_message` the daily body, then the weekly-summary body.
   d. **Remove each on its own confirmed send.** On a send failure, LEAVE the unsent file(s) queued and report `DELIVERY DEFERRED — queued in pending-dm/, retries next run`; do NOT report success.
   e. Surface message links, file paths, commit SHA, and any drained/deferred items.

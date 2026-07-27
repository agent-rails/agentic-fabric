---
name: daily-report
description: Generate end-of-day report from GitHub, Slack, and K8s activity. Saves to triage-agent wiki and DMs via Slack. Use when user asks for "daily report", "eod report", "what did I do today", "daily update", or "end of day summary".
argument-hint: "[YYYY-MM-DD] (defaults to today)"
---

Generate a daily activity report using the triage-reporter agent.

## Input

- `/daily-report` — report for today
- `/daily-report 2026-04-11` — report for a specific date

Default: today's date.

## Execution

The triage-reporter agent has read-only Slack search (for gathering) but NOT Slack send tools — it generates and persists the report. The orchestrator (main thread, where the Slack send tool is loaded) handles delivery. Splitting like this avoids the recurring stall pattern where the agent reaches step 6 with no way to send.

1. Determine TARGET_DATE from arguments (or today)
2. Resolve the user's Slack DM channel ID from `~/.claude/projects/-Users-youruser/memory/user_slack.md` (DO NOT grep skill files for IDs — see triage-reporter agent docs for the misdelivery incident on 2026-04-29).
3. Spawn `triage-reporter` agent with:

```
Generate a daily report for TARGET_DATE: {date}

1. Read user identity from user memory (Slack user ID, GitHub username)
2. Gather GitHub activity (PRs, commits, issues) for TARGET_DATE
3. Gather Slack activity via slack_search_public_and_private (read-only Slack search — you have no Slack SEND tools)
4. Synthesize into daily report format
5. Save to ~/triage-agent/wiki/reports/daily/{TARGET_DATE}.md
6. Git commit in ~/triage-agent/
7. Return: report file path, commit SHA, and the full report body verbatim — do NOT attempt to DM (you have no Slack SEND tools; delivery is the orchestrator's job).
```

4. **Resilient delivery (queue-backed, self-healing).** Generation is local (offline-OK); the Slack DM needs internet. Never send-and-forget — an offline or Slack-down moment at send time must not silently drop the report (this is the 2026-05-29 failure: report written to the wiki, DM never sent, no retry). Queue → send → remove-on-success:

   a. **Drain first (backfill).** Before delivering today's, list `~/.claude/agents/triage-reporter/pending-dm/`. For each stranded file in filename order, verify the Slack ID, `mcp__plugin_slack_slack__slack_send_message` its body to the DM, and `rm` it ONLY on a confirmed send (message link returned). This auto-recovers any report a prior offline run stranded — no human action needed.
   b. **Queue today's** report body to `~/.claude/agents/triage-reporter/pending-dm/daily-{TARGET_DATE}.md` BEFORE attempting the send.
   c. **Verify + send.** Verify the resolved Slack ID via `mcp__plugin_slack_slack__slack_read_user_profile` (mandatory — see triage-reporter docs), then `mcp__plugin_slack_slack__slack_send_message` the body to the user's DM channel.
   d. **Remove on success only.** On a confirmed send, `rm` the queued file. On ANY send failure (no internet, Slack/MCP error), LEAVE the file queued and report `DELIVERY DEFERRED — queued in pending-dm/, retries next run`; do NOT report success. The queue + next-run drain is the recovery path for headless scheduled runs.
   e. Surface message link(s), file path, commit SHA, and any drained/deferred items.

## Critical Data Gathering Notes

These are hard-won learnings — do NOT remove:

- **Verify PR dates**: `gh search prs --updated` returns PRs with ANY update (bot comments, CI). For each PR, verify with `gh api repos/ORG/REPO/pulls/NUMBER --jq '{created_at, merged_at}'`. Only include PRs created or merged on TARGET_DATE.
- **GraphQL shell escaping**: `gh api graphql -f query='...'` with `$` vars gets mangled. Use file-based: `cat > /tmp/gh-query.graphql << 'GRAPHQL'` then `gh api graphql -F query=@/tmp/gh-query.graphql`
- **Bot account**: The authenticated `gh` user may be a bot (e.g. your-alt-account) with no commit contributions in GraphQL API. Use `gh search prs` and Slack as primary sources.
- **Slack pagination**: Active days have 40-80+ messages. Paginate ALL results using cursor.
- **Slack date filter**: Use `on:YYYY-MM-DD` (more precise than `after:/before:` for single-day)

## When NOT to Use

- Standup format → use /standup (yesterday + today's plan)
- Weekly reports → use /weekly-report
- Reports for other team members

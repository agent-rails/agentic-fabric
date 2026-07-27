#!/bin/bash
# SessionStart drain check for triage-agent daily reports.
#
# Why this exists: the 21:00 delivery cron (run.sh) + 4h catchup deliver via a
# headless `claude --print` Slack session, which CANNOT reach the claude.ai
# Slack OAuth connector (no browser/keychain under launchd) — confirmed
# SLACK_TOOLS_ABSENT. So reports generate + queue in pending-dm/ but never send.
#
# This hook runs at the start of an INTERACTIVE session (where Slack MCP works),
# detects queued reports, and injects an instruction for the live session to
# deliver + clear them. Delivery slips from 21:00 to "next interactive session".
#
# Guards:
#   - TRIAGE_AGENT_NO_DRAIN=1  → the cron sets this before its own `claude` calls, so
#     a headless generation/delivery session never gets hijacked by this drain.
#   - source == compact   → never inject mid-session (compaction is not a fresh
#     interactive start; injecting "go deliver" would interrupt active work).
#   - pending-dm empty     → emit nothing (no context injected).
set -eo pipefail

# Hooks may run with a minimal PATH; ensure jq (Homebrew/usr-local) is findable,
# else the drain would silently no-op and reports would pile up again.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

[ -n "${TRIAGE_AGENT_NO_DRAIN:-}" ] && exit 0

PENDING_DIR="$HOME/.claude/agents/triage-reporter/pending-dm"

input=$(cat 2>/dev/null || true)
source=$(printf '%s' "$input" | jq -r '.source // "startup"' 2>/dev/null || echo startup)
[ "$source" = "compact" ] && exit 0

shopt -s nullglob
pending_files=("$PENDING_DIR"/*.md)
shopt -u nullglob
count=${#pending_files[@]}
[ "$count" -eq 0 ] && exit 0

list=""
for f in "${pending_files[@]}"; do
    list="${list}- ${f}"$'\n'
done

ctx="${count} undelivered daily report(s) are queued in ${PENDING_DIR}. The scheduled delivery cron can't reach Slack from its headless session, so they're waiting for an interactive session (this one) to send.

Pending (oldest first):
${list}
Deliver each to the user's Slack self-DM channel YOUR_SLACK_DM_CHANNEL_ID. MANDATORY before sending: call slack_read_user_profile on user_id YOUR_SLACK_USER_ID and confirm the returned email is you@example.com — if it does NOT match, ABORT, send nothing, and tell the user. Send each report's full contents verbatim, then append a one-line footer: _(delivered late via session-start drain — the 21:00 cron can't reach Slack headlessly)_. After each successful send, rm that file from ${PENDING_DIR}. Report the permalinks briefly. Handle this before the user's request if it's quick, otherwise right after — don't drop it."

jq -cn --arg c "$ctx" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}'

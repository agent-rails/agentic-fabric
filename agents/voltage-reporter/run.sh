#!/bin/bash
set -euo pipefail

# Opt this cron's `claude` subprocesses out of the SessionStart drain hook
# (session-drain-check.sh) — else a headless generation/delivery session would
# get injected with "go deliver pending reports", derailing it. The interactive
# session is the one that should drain; this one only generates + queues.
export VOLTAGE_NO_DRAIN=1

LOGDIR="$HOME/.claude/agents/voltage-reporter/logs"
mkdir -p "$LOGDIR"

TARGET_DATE="${1:-$(date +%Y-%m-%d)}"
DOW=$(date -j -f "%Y-%m-%d" "$TARGET_DATE" +%u 2>/dev/null || date -d "$TARGET_DATE" +%u)

DAILY_FILE="$HOME/voltage/wiki/reports/daily/${TARGET_DATE}.md"
WEEKLY_FILE="$HOME/voltage/wiki/reports/weekly/${TARGET_DATE}.md"
PENDING_DIR="$HOME/.claude/agents/voltage-reporter/pending-dm"
mkdir -p "$PENDING_DIR"

if [ -f "$DAILY_FILE" ]; then
    echo "$(date -Iseconds) skip: report already exists for $TARGET_DATE" >> "$LOGDIR/run.log"
    exit 0
fi

IS_FRIDAY=false
[ "$DOW" = "5" ] && IS_FRIDAY=true

if [ "$IS_FRIDAY" = "true" ]; then
    GEN_PROMPT="Generate a weekly report for TARGET_DATE: ${TARGET_DATE}. This includes today's daily report plus the weekly summary. Read user identity from user memory. Save daily to ~/voltage/wiki/reports/daily/${TARGET_DATE}.md and weekly to ~/voltage/wiki/reports/weekly/${TARGET_DATE}.md. Do NOT attempt to DM via Slack — orchestrator handles delivery. Git commit in ~/voltage/."
else
    GEN_PROMPT="Generate a daily report for TARGET_DATE: ${TARGET_DATE}. Read user identity from user memory. Save to ~/voltage/wiki/reports/daily/${TARGET_DATE}.md. Do NOT attempt to DM via Slack — orchestrator handles delivery. Git commit in ~/voltage/."
fi

echo "$(date -Iseconds) run: $TARGET_DATE (friday=$IS_FRIDAY)" >> "$LOGDIR/run.log"

# Step 1: generate report (agent has no Slack tools by design)
claude --agent voltage-reporter --print --permission-mode auto --max-budget-usd 5 -p "$GEN_PROMPT" >> "$LOGDIR/run.log" 2>&1

# Step 2: orchestrator-side delivery (default claude session, full plugin access)
deliver_via_slack() {
    local file="$1"
    local label="$2"
    if [ ! -f "$file" ]; then
        echo "$(date -Iseconds) deliver-skip: $label file missing ($file)" >> "$LOGDIR/run.log"
        return 1
    fi

    # Disambiguate daily vs weekly in the queue: both share the basename
    # {date}.md, so a bare basename would collide and lose one of them.
    local pending="$PENDING_DIR/${label}-$(basename "$file")"

    local DELIVER_PROMPT="DM the FULL contents of ${file} to Slack channel YOUR_SLACK_DM_CHANNEL_ID. \
MANDATORY identity check first: call slack_read_user_profile on the channel's user (user_id YOUR_SLACK_USER_ID) and confirm the returned email is you@example.com. \
If email does not match, ABORT and output SLACK_IDENTITY_MISMATCH with details — do not send. \
On success, output only the message permalink on a single line prefixed with SLACK_DM_OK: \
On failure (no MCP, no permalink), output SLACK_DM_FAIL with reason."

    # Capture THIS invocation's output — not a tail of the shared log. A stale
    # SLACK_DM_OK from a prior run in the last 100 lines could otherwise
    # false-positive a delivery and rm an undelivered report. || true keeps a
    # non-zero claude exit from aborting under set -e; the marker is the truth.
    local out
    out=$(claude --print --permission-mode auto --max-budget-usd 1 -p "$DELIVER_PROMPT" 2>&1) || true
    printf '%s\n' "$out" >> "$LOGDIR/run.log"

    if printf '%s' "$out" | grep -q "SLACK_DM_OK:"; then
        echo "$(date -Iseconds) deliver-ok: $label" >> "$LOGDIR/run.log"
        rm -f "$pending"
        return 0
    fi

    echo "$(date -Iseconds) deliver-fail: $label — no SLACK_DM_OK; queued at $pending for catchup drain" >> "$LOGDIR/run.log"
    cp "$file" "$pending"
    return 1
}

# || true: a delivery failure must NOT abort the script under set -e — else a
# failed daily send (Friday) skips the weekly send entirely and the report sits
# undelivered. Failures queue in pending-dm/; catchup.sh drains them.
deliver_via_slack "$DAILY_FILE" "daily" || true
if [ "$IS_FRIDAY" = "true" ] && [ -f "$WEEKLY_FILE" ]; then
    deliver_via_slack "$WEEKLY_FILE" "weekly" || true
fi

echo "$(date -Iseconds) done: $TARGET_DATE" >> "$LOGDIR/run.log"

#!/bin/bash
set -euo pipefail

# Opt this cron's `claude` subprocesses out of the SessionStart drain hook
# (session-drain-check.sh) — the interactive session drains the queue, not this
# headless one. Without this, the drain/generation `claude --print` calls below
# would be injected with "go deliver pending reports" and hijacked.
export VOLTAGE_NO_DRAIN=1

LOGDIR="$HOME/.claude/agents/voltage-reporter/logs"
REPORTS_DIR="$HOME/voltage/wiki/reports/daily"
RUNNER="$HOME/.claude/agents/voltage-reporter/run.sh"

mkdir -p "$LOGDIR" "$REPORTS_DIR"

# --- Drain undelivered reports (the real backfill) ---
# A report can generate fine (local write, works offline) but fail to DM
# (needs internet + Slack). run.sh queues those in pending-dm/. The missed-DAYS
# loop below only spots a missing report FILE, never a missing DELIVERY — so a
# generated-but-undelivered report (the 2026-05-29 case) would sit forever.
# This loop drains the queue every catchup tick (every 4h + at load), so a
# delivery stranded by an offline window self-heals on the next online tick.
PENDING_DIR="$HOME/.claude/agents/voltage-reporter/pending-dm"
mkdir -p "$PENDING_DIR"
shopt -s nullglob
for pending in "$PENDING_DIR"/*.md; do
    base=$(basename "$pending")
    DRAIN_PROMPT="DM the FULL contents of ${pending} to Slack channel YOUR_SLACK_DM_CHANNEL_ID. \
MANDATORY identity check first: call slack_read_user_profile on user_id YOUR_SLACK_USER_ID and confirm the returned email is you@example.com. \
If email does not match, ABORT and output SLACK_IDENTITY_MISMATCH — do not send. \
On success, output only the message permalink prefixed with SLACK_DM_OK: \
On failure, output SLACK_DM_FAIL with reason."
    out=$(claude --print --permission-mode auto --max-budget-usd 1 -p "$DRAIN_PROMPT" 2>&1) || true
    printf '%s\n' "$out" >> "$LOGDIR/catchup.log"
    if printf '%s' "$out" | grep -q "SLACK_DM_OK:"; then
        echo "$(date -Iseconds) catchup: drained + delivered $base" >> "$LOGDIR/catchup.log"
        rm -f "$pending"
    else
        echo "$(date -Iseconds) catchup: $base still undelivered — left queued for next tick" >> "$LOGDIR/catchup.log"
    fi
done
shopt -u nullglob

echo "$(date -Iseconds) catchup: checking for missed days" >> "$LOGDIR/catchup.log"

MISSED=0
for i in 1 2 3 4 5; do
    DATE=$(date -v-${i}d +%Y-%m-%d 2>/dev/null || date -d "-${i} days" +%Y-%m-%d)
    DOW=$(date -j -f "%Y-%m-%d" "$DATE" +%u 2>/dev/null || date -d "$DATE" +%u)

    # Skip weekends
    [ "$DOW" = "6" ] || [ "$DOW" = "7" ] && continue

    if [ ! -f "$REPORTS_DIR/${DATE}.md" ]; then
        echo "$(date -Iseconds) catchup: generating missed report for $DATE" >> "$LOGDIR/catchup.log"
        bash "$RUNNER" "$DATE"
        MISSED=$((MISSED + 1))
        sleep 5
    fi
done

if [ "$MISSED" -eq 0 ]; then
    echo "$(date -Iseconds) catchup: no missed days" >> "$LOGDIR/catchup.log"
else
    echo "$(date -Iseconds) catchup: generated $MISSED missed reports" >> "$LOGDIR/catchup.log"
fi

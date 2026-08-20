#!/usr/bin/env bash
# PostToolUse(Agent) hook — auto-create a continuation record at dispatch time.
#
# Thin wrapper: pipes the raw hook payload to the Python extractor, which lives
# next to this script (portable in-repo and when deployed to ~/.claude/scripts).
# Fail-open by design: a PostToolUse hook must never crash the dispatch it fired
# on, so any error exits 0 and writes no record.

input=$(cat)
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

printf '%s' "$input" | python3 "$SCRIPT_DIR/auto-create-task-record.py" 2>/dev/null || exit 0

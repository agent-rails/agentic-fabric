#!/usr/bin/env bash
# PreToolUse(Bash) gate for `gh pr create`. Thin wrapper around the Python checker next to
# this script. Unlike the naming-convention hooks this one fails closed: a missing
# python3 or a command it cannot parse denies rather than allows.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if ! command -v python3 >/dev/null 2>&1; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"gh-pr-create-gate: python3 not found, cannot check this command (fail-closed). Install python3 and retry."}}'
  exit 0
fi

exec python3 "$SCRIPT_DIR/gh-pr-create-gate.py"

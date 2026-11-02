#!/usr/bin/env bash
# PreToolUse(Bash) gate for `gh pr merge`. Wrapper around the Python checker next to this script.
# Fails closed: a missing python3, a crash of the checker, or a command it cannot parse denies.
# A command with no "g", optional quote or backslash characters, then "h" cannot spell gh,
# so it skips Python entirely (about 6 ms instead of about 47 ms).

SCRIPT_DIR=${BASH_SOURCE[0]%/*}
[ "$SCRIPT_DIR" != "${BASH_SOURCE[0]}" ] || SCRIPT_DIR=.

deny() {
  printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"gh-pr-merge-gate: $1\"}}"
  exit 0
}

IFS= read -r -d '' input || true
GH_SPELLING="g[\\'\"n]*h|\\\\u"
[[ $input =~ $GH_SPELLING ]] || exit 0

command -v python3 >/dev/null 2>&1 || deny "python3 not found, cannot check this command (fail-closed). Install python3 and retry."

out=$(printf '%s' "$input" | python3 -I -S "$SCRIPT_DIR/gh-pr-merge-gate.py" 2>/dev/null) || deny "the checker crashed, so this command is denied (fail-closed)."
[ -z "$out" ] || printf '%s\n' "$out"

#!/usr/bin/env bash
# PreToolUse gate for `gh pr create` — enforces draft-first review workflow.
#
# Blocks Claude attempts to run `gh pr create` (or its alias `gh pr new`) without
# `--draft` / `-d`; `--draft=false` is denied. The command must be one plain
# invocation (see pr_command.py); any other form that mentions it is denied.
# Allows:
#   - gh pr create --draft ...   (draft PRs, the recommended path)
#   - gh pr ready <number>       (flipping draft to ready after review)
#   - everything else
#
# User-typed commands in the terminal are unaffected — hooks only fire on
# Claude tool calls.

set -euo pipefail

GATE_PAYLOAD=$(cat)
_gate_log_lib="$(dirname "${BASH_SOURCE[0]}")/gate-decision-log.sh"
if [ -r "$_gate_log_lib" ]; then . "$_gate_log_lib"; else log_gate_decision() { return 0; }; fi
if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"PR create gate: jq is not installed, so this command cannot be checked (fail-closed). Install jq, or run the command from your own terminal."}}'
  exit 0
fi
if ! cmd=$(printf '%s' "$GATE_PAYLOAD" | jq -er 'if (.tool_input.command // "") | type == "string" then (.tool_input.command // "") else error("command is not a string") end' 2>/dev/null); then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"PR create gate: the hook payload could not be read, so this command cannot be checked (fail-closed)."}}'
  exit 0
fi

deny() {
  jq -nc --arg r "$2" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  log_gate_decision gh-pr-create-gate deny "$1"
  exit 0
}

# The parser decides whether this is one plain `gh pr create|new` it can check;
# anything it cannot vouch for that mentions the command is denied.
verdict=$(printf '%s' "$cmd" | python3 -I -S "$(dirname "${BASH_SOURCE[0]}")/pr_command.py" create 2>/dev/null) || \
  deny parser-failed "PR create gate: the command parser failed, so this command cannot be checked (fail-closed). Run gh pr create from your own terminal."
action=$(printf '%s' "$verdict" | jq -r '.action // empty' 2>/dev/null)
case "$action" in
  ignore) exit 0 ;;
  deny) deny "$(printf '%s' "$verdict" | jq -r '.code')" "PR create gate: $(printf '%s' "$verdict" | jq -r '.reason')" ;;
  check) ;;
  *) deny parser-failed "PR create gate: the command parser returned no decision (fail-closed)." ;;
esac

case "$(printf '%s' "$verdict" | jq -r '.draft')" in
  yes) log_gate_decision gh-pr-create-gate allow draft ;;
  false) deny draft-false "Review-first PR workflow required: --draft=false is not a draft. Use 'gh pr create --draft ...'." ;;
  *) deny no-draft "Review-first PR workflow required. Use 'gh pr create --draft ...' first, then review the draft, address findings (force-push if needed), then 'gh pr ready <number>' to mark merge-ready." ;;
esac

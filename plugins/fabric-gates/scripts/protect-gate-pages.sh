#!/usr/bin/env bash
# PreToolUse guard: review-gate/convention pages are human-approved-edit only.
#
# Verifier-immutability principle: agents that are graded by a gate must not
# be able to edit the gate. The scribe maintains the wiki, and the conventions
# pages in that wiki ARE the review rubric — without this guard, a scribe pass
# can silently weaken the rules every future review is graded against.
#
# Protected paths (gate artifacts and the enforcement layer itself):
#   ~/.claude/scripts, policies, agents, rules, skills, plugins (code and data),
#   settings.json, settings.local.json, gate-decisions.jsonl
#                                    — the hooks, policies and definitions that enforce the rest
#   ~/.config/agentic-fabric/**      — this layer's own settings
#   **/evals/review-convergence/**   — immutable judge rubric and schemas
#   fabric-gates protected_paths     — your review rubrics, standards and logs
#   ~/.claude/gate-unlock           — the marker itself: never editable through these
#                                    tools, even while unlocked
#
# The list lives in protected-path-match.py, which compares file identity (device
# and inode) rather than spelling, so case, Unicode, ~, .., symlink and firmlink
# aliases are the same case, as are hard links of the listed protected files. It runs
# as `python3 -I -S` so a file the agent writes into a Python startup location
# cannot disable it. It trusts the python3 and jq found on PATH.
#
# Denies Edit/Write/NotebookEdit to protected paths unless a fresh human
# unlock marker exists: run `touch ~/.claude/gate-unlock`, then retry. The marker
# is valid for the fabric-gates gate_unlock_minutes setting (default 15, clamped
# to 1-60).
#
# Failure posture: fail closed. If jq or the path check cannot run, every edit is
# denied until the unlock marker is touched from the user's terminal.
#
# Known limit: this covers the Edit/Write/NotebookEdit tools only. An agent with the
# Bash tool can still write these files or create the unlock marker. It defends
# against accidental or silent drift, not a deliberate Bash-capable bypass.
#
# To wire this hook in your Claude Code settings, add to ~/.claude/settings.json:
#
#   {
#     "hooks": {
#       "PreToolUse": [
#         {
#           "matcher": "Edit|Write|NotebookEdit",
#           "hooks": [
#             {
#               "type": "command",
#               "command": "~/.claude/scripts/protect-gate-pages.sh",
#               "timeout": 5
#             }
#           ]
#         }
#       ]
#     }
#   }
#
set -uo pipefail

input=$(cat)
GATE_PAYLOAD=$input
_gate_log_lib="$(dirname "${BASH_SOURCE[0]}")/gate-decision-log.sh"
if [ -r "$_gate_log_lib" ]; then . "$_gate_log_lib"; else log_gate_decision() { return 0; }; fi

deny() {
  jq -n --arg reason "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}' 2>/dev/null \
    || printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Gate page protected (human-approved edits only). Run `touch ~/.claude/gate-unlock` (valid for gate_unlock_minutes, default 15) and retry."}}\n'
}

unlock_minutes() {
  local minutes
  minutes=$(python3 -I -S "$(dirname "${BASH_SOURCE[0]}")/fabric_config.py" get fabric-gates gate_unlock_minutes --default 15 2>/dev/null) || minutes=15
  case "$minutes" in ''|*[!0-9]*) minutes=15 ;; esac
  [ "$minutes" -lt 1 ] && minutes=1
  [ "$minutes" -gt 60 ] && minutes=60
  printf '%s' "$minutes"
}

unlock_fresh() {
  # Portable: -mmin works on both GNU and BSD find; prints the path only if
  # the marker is fresh. Any failure -> empty -> stays locked.
  [ -n "$(find "$HOME/.claude/gate-unlock" -mmin "-$(unlock_minutes)" 2>/dev/null)" ]
}

if ! command -v jq >/dev/null 2>&1; then
  case "$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]')" in
    *gate-unlock*) ;;
    *) unlock_fresh && exit 0 ;;
  esac
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"protect-gate-pages: jq is unavailable, so this edit cannot be checked (fail-closed). Install jq, or run `touch ~/.claude/gate-unlock` in your own terminal (valid for gate_unlock_minutes, default 15) and retry."}}\n'
  exit 0
fi

fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
if [ -z "$fp" ]; then
  deny "protect-gate-pages: the edit names no file path, so it cannot be checked (fail-closed)."
  log_gate_decision protect-gate-pages deny "no file path in payload"
  exit 0
fi

resolved=$(python3 -I -S "$(dirname "${BASH_SOURCE[0]}")/protected-path-match.py" "$fp" 2>/dev/null)
case $? in
  10) exit 0 ;;
  11)
    deny "The unlock marker cannot be created or changed with these tools. Run \`touch ~/.claude/gate-unlock\` in your own terminal (valid for gate_unlock_minutes, default 15)."
    log_gate_decision protect-gate-pages deny "unlock marker is not editable: ${resolved}"
    exit 0
    ;;
  0)
    reason="protected path: ${resolved}"
    message="Gate page protected (human-approved edits only): ${resolved}. Review-gate, convention, hook and policy artifacts must not be edited by the agents they govern. To edit deliberately: run \`touch ~/.claude/gate-unlock\` (valid for gate_unlock_minutes, default 15) and retry."
    ;;
  *)
    case "$(printf '%s' "$fp" | tr '[:upper:]' '[:lower:]')" in
      *gate-unlock*)
        deny "The unlock marker cannot be created or changed with these tools. Run \`touch ~/.claude/gate-unlock\` in your own terminal (valid for gate_unlock_minutes, default 15)."
        log_gate_decision protect-gate-pages deny "unlock marker is not editable: ${fp}"
        exit 0
        ;;
    esac
    resolved="$fp"
    reason="path check could not run (fail-closed): ${fp}"
    message="protect-gate-pages: the path check could not run (is python3 working?), so every edit is blocked. Fix python3, or run \`touch ~/.claude/gate-unlock\` in your own terminal (valid for gate_unlock_minutes, default 15)."
    ;;
esac

if unlock_fresh; then
  log_gate_decision protect-gate-pages allow "unlock marker fresh: ${resolved}"
  exit 0
fi
deny "$message"
log_gate_decision protect-gate-pages deny "$reason"
exit 0

#!/usr/bin/env bash
# PreToolUse guard: review-gate/convention pages are human-approved-edit only.
#
# Verifier-immutability principle: agents that are graded by a gate must not
# be able to edit the gate. The scribe maintains the wiki, and the conventions
# pages in that wiki ARE the review rubric — without this guard, a scribe pass
# can silently weaken the rules every future review is graded against.
#
# Protected paths (both are gate artifacts):
#   ~/sentinel/wiki/conventions/**   — the review rubric (cascade policy,
#                                      evidence contract, execution rules)
#   ~/.claude/shared-wiki/**         — authoritative copies of cross-agent
#                                      principles referenced by review agents
#
# Denies Edit/Write/NotebookEdit to protected paths unless a fresh human
# unlock marker exists: run `touch ~/.claude/gate-unlock` (valid 15 minutes),
# then retry.
#
# Failure posture: if jq is unavailable the hook cannot parse the payload —
# it falls back to a raw substring match on the protected paths (deny on hit)
# and emits a degraded-mode warning otherwise. It never silently no-ops.
#
# Known limit: this defends against ACCIDENTAL/silent gate drift, not a
# deliberate bypass by a Bash-capable agent. Same trust model as keeping an
# evaluator script out of the training loop's write scope.
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

deny() {
  jq -n --arg reason "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}' 2>/dev/null \
    || printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Gate page protected (human-approved edits only). Run `touch ~/.claude/gate-unlock` (valid 15 min) and retry."}}\n'
}

unlock_fresh() {
  # Portable: -mmin works on both GNU and BSD find; prints the path only if
  # the marker was modified <15 min ago. Any failure -> empty -> stays locked.
  [ -n "$(find "$HOME/.claude/gate-unlock" -mmin -15 2>/dev/null)" ]
}

if ! command -v jq >/dev/null 2>&1; then
  # Degraded mode: cannot parse the payload. Fail closed for gate paths via
  # raw substring match; warn loudly otherwise instead of silently no-opping.
  case "$input" in
    *"/sentinel/wiki/conventions/"*|*"/.claude/shared-wiki/"*)
      unlock_fresh && exit 0
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"protect-gate-pages: jq unavailable; payload matched a protected gate path (fail-closed). Install jq, or run `touch ~/.claude/gate-unlock` (valid 15 min) and retry."}}\n'
      exit 0
      ;;
    *)
      printf '{"systemMessage":"protect-gate-pages hook degraded: jq not found — gate-page matching is substring-only until jq is installed."}\n'
      exit 0
      ;;
  esac
fi

fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
if [ -z "$fp" ]; then
  exit 0
fi

case "$fp" in
  "$HOME/sentinel/wiki/conventions/"*|"$HOME/.claude/shared-wiki/"*)
    unlock_fresh && exit 0
    deny "Gate page protected (human-approved edits only): ${fp}. Review-gate/convention artifacts must not be edited by the agents they govern. To edit deliberately: run \`touch ~/.claude/gate-unlock\` (valid 15 min) and retry."
    ;;
esac
exit 0

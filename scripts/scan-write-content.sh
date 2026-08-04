#!/usr/bin/env bash
# PreToolUse guard: pre-write malicious-content check via agent-guard
# (https://github.com/voltagebots/agent-guard — a separate, real dependency,
# not part of this bundle; install with pipx, see the Prerequisites section
# of README.md).
#
# Frames a Write/Edit/NotebookEdit call as {"tool":"write","args":{"content":...}}
# (content only -- never path, see policies/write-content-scan.yaml's header for
# why) and evaluates it through `guard check` against agent-guard's
# deterministic, tested Policy engine -- the same one it uses for tool-call
# authorization, just on written content instead of tool calls. `guard
# check --audit` writes the decision record in the same call, so this hook
# does both the security decision and the audit write atomically.
#
# Already wired into settings.hooks.example.json's Edit|Write|NotebookEdit
# PreToolUse matcher, alongside protect-gate-pages.sh.
#
# Failure posture: `guard` missing from PATH, or a crash/non-JSON verdict,
# fails CLOSED (deny) with the cause named in the reason -- never a silent
# allow. A `require_human` verdict is treated the same as `deny` -- there is
# no hook-level "pause and ask" mechanism in this bundle, so a decision
# meant to pause must not fall through to a silent allow just because it
# is not a hard policy violation.
set -uo pipefail

# Claude Code spawns PreToolUse hooks with a minimal PATH that may not
# include ~/.local/bin (where pipx installs guard's console script) even
# when it's on PATH in an interactive shell. Extend it here rather than
# assume the caller's environment already has it.
export PATH="$HOME/.local/bin:$PATH"

POLICY="${SCAN_WRITE_CONTENT_POLICY:-$HOME/.claude/policies/write-content-scan.yaml}"
AUDIT_LOG="${SCAN_WRITE_CONTENT_AUDIT:-$HOME/your-triage-agent/wiki/recurring/.write-decisions.jsonl}"

deny() {
  jq -n --arg reason "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}' 2>/dev/null \
    || printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$1"
}

if ! command -v jq >/dev/null 2>&1; then
  printf '{"systemMessage":"scan-write-content hook degraded: jq not found -- cannot parse payload, failing closed on all Edit/Write/NotebookEdit until jq is installed."}\n'
  deny "scan-write-content: jq unavailable, cannot evaluate write content (fail-closed). Install jq and retry."
  exit 0
fi

input=$(cat)

tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')
path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')

if [ -z "$path" ]; then
  exit 0
fi

case "$tool" in
  Write)
    content=$(printf '%s' "$input" | jq -r '.tool_input.content // empty')
    ;;
  Edit)
    content=$(printf '%s' "$input" | jq -r '.tool_input.new_string // empty')
    ;;
  NotebookEdit)
    content=$(printf '%s' "$input" | jq -r '.tool_input.new_source // empty')
    ;;
  *)
    exit 0
    ;;
esac

if [ -z "$content" ]; then
  exit 0
fi

if ! command -v guard >/dev/null 2>&1; then
  deny "scan-write-content: 'guard' not found on PATH. Install with: pipx install \"agentguard[yaml] @ git+https://github.com/voltagebots/agent-guard.git\" (then: pipx inject agentguard pyyaml)."
  exit 0
fi

mkdir -p "$(dirname "$AUDIT_LOG")" 2>/dev/null || true

call_json=$(jq -nc --arg content "$content" '{tool:"write",args:{content:$content}}')
verdict_json=$(printf '%s' "$call_json" | guard check --policy "$POLICY" --audit "$AUDIT_LOG" --json 2>&1)
guard_exit=$?

if [ "$guard_exit" -eq 1 ]; then
  deny "scan-write-content: guard crashed evaluating this write (fail-closed). Raw output: ${verdict_json}"
  exit 0
fi

decision=$(printf '%s' "$verdict_json" | jq -r '.decision // empty' 2>/dev/null)
reason=$(printf '%s' "$verdict_json" | jq -r '.reason // empty' 2>/dev/null)

if [ -z "$decision" ]; then
  deny "scan-write-content: guard produced no parseable verdict (fail-closed). Raw output: ${verdict_json}"
  exit 0
fi

if [ "$decision" = "deny" ]; then
  deny "$reason"
  exit 0
fi

if [ "$decision" = "require_human" ]; then
  deny "scan-write-content: flagged for human review, not auto-blocked outright — ${reason}"
  exit 0
fi

exit 0

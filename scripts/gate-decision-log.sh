#!/usr/bin/env bash
# Sourced by PreToolUse gates. Appends one JSON line per gate decision to
# ~/.claude/gate-decisions.jsonl.
#
# A gate must behave the same with or without logging, even under `set -eu`:
# every step is guarded, and a missing jq, an unset HOME, or a log path that is
# not a plain file (a symlink, FIFO or directory) skips the record.
#
# A record holds the hook name, the decision, a short reason code, ids from the
# payload and a SHA-256 of the payload. It holds no command text or file
# content. protect-gate-pages is the one hook that records a path (the
# protected path it matched), and its record says so in the reason.
#
# Usage: GATE_PAYLOAD=$input; log_gate_decision <hook> <allow|deny> <reason-code>

log_gate_decision() {
  local hook="$1" decision="$2" reason="${3:-}" payload="${GATE_PAYLOAD:-}"
  local digest="" ts="" log=""
  [ -n "${HOME:-}" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  log="$HOME/.claude/gate-decisions.jsonl"
  if [ -L "$log" ] || { [ -e "$log" ] && [ ! -f "$log" ]; }; then
    return 0
  fi
  digest=$(printf '%s' "$payload" | shasum -a 256 2>/dev/null | cut -d' ' -f1) || digest=""
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ) || ts=""
  mkdir -p "$HOME/.claude" 2>/dev/null || true
  [ -e "$log" ] || (umask 077; : >> "$log") 2>/dev/null || true
  {
    printf '%s' "$payload" | jq -cn --arg hook "$hook" --arg decision "$decision" \
      --arg reason "${reason:0:240}" --arg digest "$digest" --arg ts "$ts" \
      '(first(inputs) // {}) as $p | {ts:$ts,hook:$hook,decision:$decision,reason:$reason,tool:($p.tool_name // null),session_id:($p.session_id // null),tool_use_id:($p.tool_use_id // null),payload_sha256:$digest}' \
    || jq -nc --arg hook "$hook" --arg decision "$decision" \
      --arg reason "${reason:0:240}" --arg digest "$digest" --arg ts "$ts" \
      '{ts:$ts,hook:$hook,decision:$decision,reason:$reason,tool:null,session_id:null,tool_use_id:null,payload_sha256:$digest}'
  } 2>/dev/null >> "$log" || true
  return 0
}

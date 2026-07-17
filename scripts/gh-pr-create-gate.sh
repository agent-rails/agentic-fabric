#!/usr/bin/env bash
# PreToolUse gate for `gh pr create` — enforces draft-first review workflow.
#
# Blocks Claude attempts to run `gh pr create` without `--draft`. Allows:
#   - gh pr create --draft ...   (draft PRs, the recommended path)
#   - gh pr ready <number>       (flipping draft to ready after review)
#   - everything else
#
# User-typed commands in the terminal are unaffected — hooks only fire on
# Claude tool calls.

set -euo pipefail

cmd=$(jq -r '.tool_input.command // ""')

# Strip heredoc bodies so the regex doesn't match `gh pr create` substrings
# inside review/PR-body content. Recognises <<EOF, <<'EOF', <<"EOF", <<-EOF.
cmd_stripped=$(printf '%s\n' "$cmd" | awk '
  in_h && $0 ~ heredoc_close { in_h=0; next }
  in_h { next }
  match($0, /<<-?[[:space:]]*[\047"]?[A-Za-z_][A-Za-z0-9_]*[\047"]?/) {
    tag = substr($0, RSTART, RLENGTH)
    gsub(/^<<-?[[:space:]]*[\047"]?|[\047"]?$/, "", tag)
    heredoc_close = "^" tag "$"
    in_h = 1
    sub(/<<-?[[:space:]]*[\047"]?[A-Za-z_][A-Za-z0-9_]*[\047"]?.*$/, "")
    print
    next
  }
  { print }
')

if echo "$cmd_stripped" | grep -qE 'gh[[:space:]]+pr[[:space:]]+create' \
  && ! echo "$cmd_stripped" | grep -qE -- '--draft'; then
  cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Review-first PR workflow required. Use 'gh pr create --draft ...' first, then '/review-pr <url>' against the draft, address findings (force-push if needed), then 'gh pr ready <number>' to mark merge-ready."}}
JSON
fi

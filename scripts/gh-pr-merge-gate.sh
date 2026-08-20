#!/usr/bin/env bash
# PreToolUse gate for `gh pr merge` — enforces the draft-first review workflow.
#
# Blocks Claude attempts to run `gh pr merge` while the target PR is still a
# draft (i.e. hasn't been marked merge-ready after review). Marking a PR ready
# (`gh pr ready`) is the human decision point — the same point the PR-create
# gate steers toward. Allows:
#   - gh pr merge <ready PR>   (already marked ready by a human)
#   - everything else
#
# User-typed commands in the terminal are unaffected — hooks only fire on
# Claude tool calls.

set -euo pipefail

cmd=$(jq -r '.tool_input.command // ""')

# Strip heredoc bodies so the regex doesn't match `gh pr merge` substrings
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

deny() {
  cat <<JSON
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"$1"}}
JSON
  exit 0
}

if echo "$cmd_stripped" | grep -qE 'gh[[:space:]]+pr[[:space:]]+merge'; then
  # First non-flag token after `merge` is the PR (number/url/branch), if given.
  rest=$(echo "$cmd_stripped" | sed -E 's/.*gh[[:space:]]+pr[[:space:]]+merge//')
  target=$(printf '%s\n' $rest | grep -vE '^-|^$' | head -1 || true)

  is_draft=$(gh pr view $target --json isDraft --jq '.isDraft' 2>/dev/null || true)

  if [ "$is_draft" = "true" ]; then
    deny "Review-first PR workflow required. This PR is still a draft — mark it ready only after review: run '/review-pr <url>', address findings, then 'gh pr ready <number>' before merging."
  fi
  if [ -z "$is_draft" ]; then
    deny "Could not confirm the target PR is marked ready (gh pr view returned no draft state). Verify the PR has been reviewed and marked ready, then merge manually."
  fi
fi

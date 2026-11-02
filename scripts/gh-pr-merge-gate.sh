#!/usr/bin/env bash
# PreToolUse gate for `gh pr merge` — enforces the draft-first review workflow
# and refuses to merge a PR whose head has fallen behind its branch.
#
# Blocks Claude attempts to run `gh pr merge` when:
#   - the target PR is still a draft (not yet marked merge-ready), or
#   - GitHub's PR head sha is behind the branch ref (merging would silently
#     drop pushed commits — a PR has merged with one
#     commit while its branch had two), or
#   - PR state cannot be determined at all (fail closed, and say why).
#
# Every denial names its actual cause. A failed probe and a genuine draft are
# different problems and must never produce the same message.
#
# User-typed commands in the terminal are unaffected — hooks only fire on
# Claude tool calls.

set -uo pipefail

GATE_PAYLOAD=$(cat)
_gate_log_lib="$(dirname "${BASH_SOURCE[0]}")/gate-decision-log.sh"
if [ -r "$_gate_log_lib" ]; then . "$_gate_log_lib"; else log_gate_decision() { return 0; }; fi
cmd=$(printf '%s' "$GATE_PAYLOAD" | jq -r '.tool_input.command // ""')

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

# Build JSON with jq so a reason containing quotes/newlines cannot corrupt it.
deny() {
  jq -nc --arg r "$2" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  log_gate_decision gh-pr-merge-gate deny "$1"
  exit 0
}

echo "$cmd_stripped" | grep -qE 'gh[[:space:]]+pr[[:space:]]+merge' || exit 0

# First non-flag token after `merge` is the PR (number/url/branch), if given.
# Parse ONLY the line that contains the merge, not the whole command. A multi-line
# command previously leaked its first token (e.g. `cd`) in as the PR target.
merge_line=$(printf '%s\n' "$cmd_stripped" | grep -E 'gh[[:space:]]+pr[[:space:]]+merge' | head -1)
rest=$(printf '%s\n' "$merge_line" | sed -E 's/.*gh[[:space:]]+pr[[:space:]]+merge//')
# Stop at a shell operator so redirects/pipes are never mistaken for the target.
rest=$(printf '%s\n' "$rest" | sed -E 's/[|;&>].*$//')
target=$(printf '%s\n' $rest | grep -vE '^-|^$' | head -1 || true)

# Honour an explicit --repo/-R, read only from the merge's own arguments (before
# any shell operator). Quotes or more than one repo flag make the target ambiguous.
args_unquoted=$(printf '%s\n' "$rest" | sed -E "s/'[^']*'/QUOTED/g; s/\"[^\"]*\"/QUOTED/g")
repo_count=$(printf '%s\n' "$args_unquoted" | grep -oE '(^|[[:space:]])(--repo|-R)([= ]|$)' | wc -l | tr -d ' ')
repo_flag=$(printf '%s\n' "$args_unquoted" | grep -oE '(^|[[:space:]])(--repo|-R)[= ]+[^ ]+' | head -1 | sed -E 's/^[[:space:]]*(--repo|-R)[= ]+//')
case "$rest" in
  *\\*) printf '%s\n' "$rest" | grep -qE -- '(--repo|-R)' && repo_count=2 ;;
esac
if [ "$repo_count" -gt 1 ] || { [ "$repo_count" -eq 1 ] && { [ -z "$repo_flag" ] || [ "$repo_flag" = QUOTED ]; }; }; then
  deny ambiguous-repo "merge gate: the merge names its repository more than once or in quotes, so the PR to check is ambiguous. Run 'gh pr merge <number> --repo owner/name' with a single unquoted --repo."
fi
repo_args=()
[ -n "$repo_flag" ] && repo_args=(--repo "$repo_flag")

command -v gh >/dev/null 2>&1 || \
  deny gh-missing "merge gate: 'gh' is not on the hook's PATH, so PR state cannot be verified. Fix the hook's environment, or merge from your own terminal."

# One probe, stderr captured — never discarded.
probe_err=$(mktemp)
pr_json=$(gh pr view ${target:+"$target"} ${repo_args[@]+"${repo_args[@]}"} \
            --json isDraft,headRefOid,headRefName,url,isCrossRepository 2>"$probe_err")
rc=$?
[ $rc -eq 0 ] || pr_json="$pr_json $(cat "$probe_err")"
rm -f "$probe_err"

if [ $rc -ne 0 ] || [ -z "$pr_json" ]; then
  deny probe-failed "merge gate: PROBE FAILED (this is not a draft check). 'gh pr view ${target:-<no target>}' exited ${rc} saying: $(printf '%s' "$pr_json" | tr '\n' ' ' | head -c 400). Pass --repo owner/name, or merge from your own terminal."
fi

# No `// empty` here: isDraft is a boolean and jq's `//` treats `false` as absent,
# which denied every ready PR.
is_draft=$(printf '%s' "$pr_json" | jq -r 'if has("isDraft") then (.isDraft|tostring) else "" end' 2>/dev/null)
head_oid=$(printf '%s' "$pr_json" | jq -r '.headRefOid // empty' 2>/dev/null)
head_ref=$(printf '%s' "$pr_json" | jq -r '.headRefName // empty' 2>/dev/null)
pr_url=$(printf '%s' "$pr_json" | jq -r '.url // empty' 2>/dev/null)
cross_repo=$(printf '%s' "$pr_json" | jq -r 'if has("isCrossRepository") then (.isCrossRepository|tostring) else "" end' 2>/dev/null)

[ -n "$is_draft" ] || \
  deny probe-empty "merge gate: PROBE PARSED EMPTY (this is not a draft check). gh returned: $(printf '%s' "$pr_json" | tr '\n' ' ' | head -c 300)"

[ "$is_draft" = "true" ] && \
  deny draft "merge gate: PR IS STILL A DRAFT. Review first: run '/review-pr ${pr_url:-$target}', address findings, then 'gh pr ready' before merging."

# Stale-head check: GitHub's PR head can lag the branch ref, and merging then
# silently drops the commits GitHub has not picked up. A fork PR's branch lives
# in the fork, so it is not looked up in the base repository.
if [ "$cross_repo" != "true" ]; then
  owner_repo=$(printf '%s' "$pr_url" | sed -nE 's#^https://[^/]+/([^/]+/[^/]+)/pull/[0-9]+$#\1#p')
  [ -n "$owner_repo" ] && [ -n "$head_ref" ] && [ -n "$head_oid" ] || \
    deny tip-unknown "merge gate: could not read the PR's repository, branch or head from gh, so the stale-head check cannot run. Merge from your own terminal."
  branch_oid=$(gh api "repos/${owner_repo}/commits/${head_ref}" --jq '.sha' 2>/dev/null) || branch_oid=""
  [[ $branch_oid =~ ^[0-9a-f]{40}$ ]] || \
    deny tip-unknown "merge gate: could not read the tip of branch '${head_ref}', so the stale-head check cannot run. Check the branch exists, or merge from your own terminal."
  [ "$branch_oid" = "$head_oid" ] || \
    deny stale-head "merge gate: STALE PR HEAD. GitHub shows the PR at ${head_oid:0:7} but branch '${head_ref}' is at ${branch_oid:0:7}. Merging now would drop the commits GitHub has not picked up. Wait for the PR to catch up, or close and reopen it to force a resync, then merge."
fi

log_gate_decision gh-pr-merge-gate allow merge-permitted
exit 0

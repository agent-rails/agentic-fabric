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
if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"merge gate: jq is not installed, so this command cannot be checked (fail-closed). Install jq, or run the command from your own terminal."}}'
  exit 0
fi
if ! cmd=$(printf '%s' "$GATE_PAYLOAD" | jq -er 'if (.tool_input.command // "") | type == "string" then (.tool_input.command // "") else error("command is not a string") end' 2>/dev/null); then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"merge gate: the hook payload could not be read, so this command cannot be checked (fail-closed)."}}'
  exit 0
fi

# Build JSON with jq so a reason containing quotes/newlines cannot corrupt it.
deny() {
  jq -nc --arg r "$2" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  log_gate_decision gh-pr-merge-gate deny "$1"
  exit 0
}

# The parser decides whether this is one plain `gh pr merge` it can check, and
# which PR and repository it names; anything else that mentions a merge is denied.
verdict=$(printf '%s' "$cmd" | python3 -I -S "$(dirname "${BASH_SOURCE[0]}")/pr_command.py" merge 2>/dev/null) || \
  deny parser-failed "merge gate: the command parser failed, so this merge cannot be checked (fail-closed). Merge from your own terminal."
action=$(printf '%s' "$verdict" | jq -r '.action // empty' 2>/dev/null)
case "$action" in
  ignore) exit 0 ;;
  deny) deny "$(printf '%s' "$verdict" | jq -r '.code')" "merge gate: $(printf '%s' "$verdict" | jq -r '.reason')" ;;
  check) ;;
  *) deny parser-failed "merge gate: the command parser returned no decision (fail-closed)." ;;
esac
target=$(printf '%s' "$verdict" | jq -r '.target // empty')
repo_flag=$(printf '%s' "$verdict" | jq -r '.repo // empty')
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

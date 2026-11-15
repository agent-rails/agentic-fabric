#!/usr/bin/env bash
# Tests for the fabric-gates hooks that read configuration: branch prefix,
# gate-page protection, unlock window and decision-log location, plus the
# draft-first PR create gate. Run directly: bash gates.test.sh

set -euo pipefail

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
[ -f "$DIR/../scripts/protect-gate-pages.sh" ] && DIR=$(cd "$DIR/../scripts" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
export HOME=$WORK/home
mkdir -p "$HOME/.claude" "$HOME/.config/agentic-fabric"
export AGENTIC_FABRIC_CONFIG=$HOME/.config/agentic-fabric/config.json
unset CLAUDE_PLUGIN_OPTION_BRANCH_PREFIX CLAUDE_PLUGIN_OPTION_PROTECTED_PATHS CLAUDE_PLUGIN_OPTION_GATE_UNLOCK_MINUTES CLAUDE_PLUGIN_DATA || true

pass=0
fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { pass=$((pass + 1)); echo "ok - $*"; }
bash_payload() { jq -nc --arg c "$1" '{tool_name:"Bash",session_id:"s",tool_use_id:"t",tool_input:{command:$c}}'; }
edit_payload() { jq -nc --arg p "$1" '{tool_name:"Write",session_id:"s",tool_use_id:"t",tool_input:{file_path:$p,content:"x"}}'; }
config() { printf '%s\n' "$1" > "$AGENTIC_FABRIC_CONFIG"; }

expect() {
  local want=$1 needle=$2 out=$3 label=$4
  if [ "$want" = allow ]; then
    [ -z "$out" ] || fail "$label: expected allow, got: $out"
  else
    printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null || fail "$label: expected deny, got: $out"
    printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason' | grep -qF -- "$needle" || fail "$label: deny reason lacks '$needle': $out"
  fi
  ok "$label"
}

prefix() { bash_payload "$1" | bash "$DIR/enforce-branch-prefix.sh"; }
protect() { edit_payload "$1" | bash "$DIR/protect-gate-pages.sh"; }
create() { bash_payload "$1" | bash "$DIR/gh-pr-create-gate.sh"; }

rm -f "$AGENTIC_FABRIC_CONFIG"
expect allow "" "$(prefix 'ls -la')" "no setting: ordinary commands are not touched"
expect deny "branch prefix is set" "$(prefix 'git checkout -b feature')" "no setting: branch creation is blocked with the fix"

config '{"fabric-gates": {"branch_prefix": "me/"}}'
expect deny 'prefixed "me/"' "$(prefix 'git checkout -b feature')" "config file prefix enforced on checkout -b"
expect deny 'prefixed "me/"' "$(prefix 'cd x && git switch -c feature')" "config file prefix enforced on switch -c in a chain"
expect allow "" "$(prefix 'git checkout -b me/feature')" "prefixed branch allowed"
expect allow "" "$(prefix 'git branch -d feature')" "branch delete is not creation"
expect deny 'prefixed "env/"' "$(CLAUDE_PLUGIN_OPTION_BRANCH_PREFIX=env/ prefix 'git branch feature')" "plugin option wins over config file"

config '{not json'
expect deny "not valid JSON" "$(prefix 'git worktree add -b x ../x')" "unreadable config blocks branch creation"

config '{}'
expect deny "protected" "$(protect "$HOME/.claude/settings.json")" "settings.json protected by default"
expect deny "protected" "$(protect "$HOME/.config/agentic-fabric/config.json")" "agentic-fabric config protected"
expect deny "protected" "$(protect "$HOME/.claude/plugins/data/fabric-gates/gate-decisions.jsonl")" "plugin data protected"
expect deny "protected" "$(protect "$HOME/.claude/agents/new.md")" "agent definitions protected (path does not exist yet)"
expect allow "" "$(protect "$HOME/notes/today.md")" "unprotected path allowed"  # leak-scan: fixture
expect deny "names no file path" "$(jq -nc '{tool_name:"Write",tool_input:{content:"x"}}' | bash "$DIR/protect-gate-pages.sh")" "edit with no file path denied"  # leak-scan: fixture
expect deny "cannot be created" "$(protect "$HOME/.claude/gate-unlock")" "unlock marker never editable"

config '{"fabric-gates": {"protected_paths": "notes/rubric, standards/review.md"}}'
expect deny "protected" "$(protect "$HOME/notes/rubric/cascade.md")" "configured directory protected"  # leak-scan: fixture
expect deny "protected" "$(protect "$HOME/standards/review.md")" "configured file protected"  # leak-scan: fixture
expect allow "" "$(protect "$HOME/notes/today.md")" "sibling of configured directory allowed"  # leak-scan: fixture

config '{"fabric-gates": {"protected_paths": "/etc"}}'
expect deny "could not run" "$(protect "$HOME/notes/today.md")" "absolute protected_paths entry fails closed"  # leak-scan: fixture

config '{"fabric-gates": {"gate_unlock_minutes": 5}}'
touch -t "$(date -v-30M +%Y%m%d%H%M 2>/dev/null || date -d '-30 min' +%Y%m%d%H%M)" "$HOME/.claude/gate-unlock"
expect deny "protected" "$(protect "$HOME/.claude/settings.json")" "marker older than the window stays locked"
config '{"fabric-gates": {"gate_unlock_minutes": 999}}'
expect allow "" "$(protect "$HOME/.claude/settings.json")" "window clamps to 60 minutes, so a 30-minute marker unlocks"
touch -t "$(date -v-90M +%Y%m%d%H%M 2>/dev/null || date -d '-90 min' +%Y%m%d%H%M)" "$HOME/.claude/gate-unlock"
expect deny "protected" "$(protect "$HOME/.claude/settings.json")" "clamped window still expires after 60 minutes"
config '{"fabric-gates": {"gate_unlock_minutes": "abc"}}'
touch "$HOME/.claude/gate-unlock"
expect allow "" "$(protect "$HOME/.claude/settings.json")" "invalid window falls back to 15 minutes"
rm -f "$HOME/.claude/gate-unlock"

config '{}'
rm -f "$HOME/.claude/gate-decisions.jsonl"
export CLAUDE_PLUGIN_DATA=$WORK/plugin-data
protect "$HOME/.claude/settings.json" >/dev/null
[ -s "$CLAUDE_PLUGIN_DATA/gate-decisions.jsonl" ] || fail "decision not logged in plugin data dir"
[ ! -e "$HOME/.claude/gate-decisions.jsonl" ] || fail "decision also logged under ~/.claude"
ok "decisions log to the plugin data directory when it is set"
unset CLAUDE_PLUGIN_DATA

expect deny "Review-first" "$(create 'gh pr create --title x')" "pr create without --draft denied"
expect allow "" "$(create 'gh pr create --draft --title x')" "draft pr create allowed"
expect allow "" "$(create 'gh pr create -d --fill')" "short draft flag allowed"
expect deny "Review-first" "$(create 'gh pr new --fill')" "gh pr new alias without --draft denied"
expect allow "" "$(create 'gh pr new --draft --fill')" "gh pr new alias with --draft allowed"
expect deny "not a draft" "$(create 'gh pr create --draft=false --fill')" "--draft=false denied"
expect deny "Review-first" "$(create 'gh pr create --title "not --draft" --fill')" "--draft inside a quoted title does not count"
expect deny "Review-first" "$(create "gh pr create --body 'use --draft next time'")" "--draft inside a single-quoted body does not count"
expect deny "one plain command" "$(create "bash -c 'gh pr create -t x'")" "create through bash -c denied"
expect deny "one plain command" "$(create 'eval "gh pr create -t x"')" "create through eval denied"
expect deny "Review-first" "$(create 'gh pr create -t x --body -d')" "-d as the value of --body is not a draft flag"
expect deny "one plain command" "$(create 'gh pr create --dry-run -d && gh pr create -t y')" "second create chained after a draft one denied"
expect deny "one plain command" "$(create 'gh pr create --title x; echo --draft')" "--draft in a later command does not count"
expect deny "one plain command" "$(create 'git push && gh pr create --draft --fill')" "create chained after push denied (run it alone)"
heredoc_create=$(printf 'cat <<EOF >/dev/null; gh pr create -t x\nbody\nEOF')
expect deny "one plain command" "$(create "$heredoc_create")" "create on the same line as a heredoc denied"
expect deny "one plain command" "$(create 'GH_REPO=o/r gh pr create --draft')" "env prefix before create denied"
expect deny "does not know the flag" "$(create 'gh pr create --draft --frobnicate')" "unknown flag denied"
expect allow "" "$(create 'gh pr create -dt "a title"')" "combined short flags parsed"
expect allow "" "$(create 'gh pr create --draft --title x 2>&1')" "a trailing redirect is allowed"
expect allow "" "$(create 'git commit -m "gate: gh pr create needs --draft"')" "a mention inside a commit message is data"
for form in '{ gh pr create -t x; }' 'if true; then gh pr create -t x; fi' 'for i in 1; do gh pr create -t x; done' '! gh pr create -t x' 'caffeinate gh pr create -t x' 'stdbuf -o0 gh pr create -t x' 'find . -maxdepth 0 -exec gh pr create -t x ;' 'G=gh; $G pr create -t x' '"$HOME/bin/gh" pr create -t x'; do  # leak-scan: fixture
  expect deny "" "$(create "$form")" "not plain, denied: $form"
done
expect deny "gh alias" "$(create 'gh alias set prc "pr create -t x"')" "gh alias expanding to pr create denied"
expect deny "Review-first" "$(create "g''h pr create -t x")" "quote-split program name is parsed as gh"
expect deny "Review-first" "$(create 'gh pr create -t x # --draft')" "--draft inside a comment does not count"
expect allow "" "$(create 'gh pr create -t x --draft=1')" "--draft=1 is a draft"
prose=$(printf '%s\n' "cat >> notes.md <<'EOF'" 'Run gh pr create --draft, never gh pr create alone.' 'EOF')
expect deny "heredoc" "$(create "$prose")" "any heredoc in a command that mentions it is denied; write prose with an editor tool"
to_shell=$(printf "bash <<'EOF'\\ngh pr create -t x\\nEOF")
expect deny "heredoc" "$(create "$to_shell")" "heredoc fed to a shell is denied"
expanded=$(printf '%s\n' 'cat > notes.md <<EOF' '$(gh pr create -t x)' 'EOF')
expect deny "" "$(create "$expanded")" "substitution inside an unquoted heredoc is denied"
expect deny "" "$(create 'bash <<< "gh pr create -t x"')" "here-string fed to a shell is denied"
expect deny 'prefixed "me/"' "$(CLAUDE_PLUGIN_OPTION_BRANCH_PREFIX=me/ prefix 'git checkout -bfeature')" "attached -b value enforced"
expect deny 'prefixed "me/"' "$(CLAUDE_PLUGIN_OPTION_BRANCH_PREFIX=me/ prefix 'git switch -cfeature')" "attached -c value enforced"
expect allow "" "$(CLAUDE_PLUGIN_OPTION_BRANCH_PREFIX=me/ prefix 'git checkout -bme/feature')" "attached prefixed value allowed"
expect deny "Review-first" "$(create "gh pr cre''ate -t x")" "quote-split subcommand is parsed, not missed"
continued=$(printf 'gh pr \\\ncreate -t x')
expect deny "Review-first" "$(create "$continued")" "line continuation is parsed, not missed"
expect deny "one plain" "$(create 'x=create; gh pr $x -t x')" "subcommand from a variable denied"
expect deny "no value other than true" "$(create 'gh pr create -t x --draft=no')" "--draft=no is not a draft"
expect deny "not 'gh api'" "$(create 'gh api repos/o/r/pulls -f title=x -f head=b -f base=main')" "creating a PR through gh api denied"
expect allow "" "$(create 'gh api repos/o/r/pulls --jq ".[].number"')" "reading PRs through gh api allowed"
merge_api="gh api -X PUT repos/o/r/pulls/7/$(printf mer)ge"
expect deny "not 'gh api'" "$(bash_payload "$merge_api" | bash "$DIR/gh-pr-merge-gate.sh")" "merging a PR through gh api denied"

expect deny 'prefixed "me/"' "$(CLAUDE_PLUGIN_OPTION_BRANCH_PREFIX=me/ prefix 'git switch --create feature')" "switch --create enforced"
expect deny 'prefixed "me/"' "$(CLAUDE_PLUGIN_OPTION_BRANCH_PREFIX=me/ prefix 'git checkout --orphan feature')" "checkout --orphan enforced"
expect deny 'prefixed "me/"' "$(CLAUDE_PLUGIN_OPTION_BRANCH_PREFIX=me/ prefix 'git worktree add ../feature')" "implicit worktree branch enforced"
expect allow "" "$(CLAUDE_PLUGIN_OPTION_BRANCH_PREFIX=me/ prefix 'git worktree add ../me-review main')" "worktree on an existing commit-ish creates no branch"
expect allow "" "$(CLAUDE_PLUGIN_OPTION_BRANCH_PREFIX=me/ prefix 'git worktree add --detach ../scratch')" "detached worktree creates no branch"
heredoc_cmd=$(printf 'cat > notes.md <<%sEOF%s\nUse a git %s prefix, always.\nEOF' "'" "'" "branch")
expect allow "" "$(CLAUDE_PLUGIN_OPTION_BRANCH_PREFIX=me/ prefix "$heredoc_cmd")" "prose inside a heredoc is not parsed as a command"

NOJQ=$WORK/nojq
mkdir -p "$NOJQ"
for tool in bash cat grep sed awk head tr printf dirname date mkdir shasum cut python3 wc env; do
  found=$(command -v "$tool" 2>/dev/null) && ln -sf "$found" "$NOJQ/$tool"
done
merge_cmd="gh pr $(printf mer)ge 5 --repo o/r --squash"
payload_merge=$(jq -nc --arg c "$merge_cmd" '{tool_name:"Bash",tool_input:{command:$c}}')
payload_create=$(jq -nc --arg c 'gh pr create --fill' '{tool_name:"Bash",tool_input:{command:$c}}')
expect deny "jq is not installed" "$(printf '%s' "$payload_merge" | PATH=$NOJQ bash "$DIR/gh-pr-merge-gate.sh")" "merge gate denies when jq is missing"
expect deny "jq is not installed" "$(printf '%s' "$payload_create" | PATH=$NOJQ bash "$DIR/gh-pr-create-gate.sh")" "create gate denies when jq is missing"


# Round-3 cross-vendor probes: every form must be denied.
expect deny "" "$(bash_payload $'echo "<<\'EOF\'"\ngh pr create -t x\nEOF' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "round-3 probe denied"
expect deny "" "$(bash_payload $'# <<\'EOF\'\ngh pr create -t x\nEOF' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "round-3 probe denied"
expect deny "" "$(bash_payload $'echo \'<<EOF\'\ngh pr create -t x\nEOF' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "round-3 probe denied"
expect deny "" "$(bash_payload $'true <<\'EOF\'\nEOF\ngh pr create -t x' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "round-3 probe denied"
expect deny "" "$(bash_payload $'cat <<\'EOF\' | bash\ngh pr create -t x\nEOF' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "round-3 probe denied"
expect deny "" "$(bash_payload $'<<\'EOF\' bash\ngh pr create -t x\nEOF' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "round-3 probe denied"
expect deny "" "$(bash_payload $'env bash <<\'EOF\'\ngh pr create -t x\nEOF' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "round-3 probe denied"
expect deny "" "$(bash_payload $'command bash <<\'EOF\'\ngh pr create -t x\nEOF' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "round-3 probe denied"
expect deny "" "$(bash_payload $'{ bash; } <<\'EOF\'\ngh pr create -t x\nEOF' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "round-3 probe denied"
expect deny "" "$(bash_payload $'source /dev/stdin <<\'EOF\'\ngh pr create -t x\nEOF' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "round-3 probe denied"
expect deny "" "$(bash_payload $'bash -c "$(cat <<\'EOF\'\ngh pr create -t x\nEOF\n)"' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "round-3 probe denied"
expect deny "" "$(bash_payload $'bash<<\'EOF\'\ngh pr create -t x\nEOF' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "round-3 probe denied"
expect deny "" "$(bash_payload $'bash <<\'EOF\'\ng\'\'h pr cre\'\'ate -t x\nEOF' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "round-3 probe denied"
expect deny "" "$(bash_payload $'bash <<-\'EOF\'\n	gh pr create -t x\n	EOF' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "round-3 probe denied"
expect deny "" "$(bash_payload $'cat <<A <<\'B\'\nx\nA\ngh pr create -t x\nB' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "round-3 probe denied"
expect deny "" "$(bash_payload $'bash <<\'A\' 3<<\'B\'\ngh pr create -t x\nA\nB' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "round-3 probe denied"
expect deny "" "$(bash_payload $'cat <<\'EOF\' > /dev/null; gh pr create -t x\nbody\nEOF' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "round-3 probe denied"
expect deny "" "$(bash_payload $'cat <<EOF\n$(echo hi)\ngh pr create -t x\nEOF' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "round-3 probe denied"
expect deny "" "$(bash_payload $'cat <<EOF\n`gh pr create -t x`\nEOF' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "round-3 probe denied"
expect deny "" "$(bash_payload $'bash <<< \'gh pr create -t x\'' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "round-3 probe denied"
expect deny "" "$(bash_payload $'x=$(cat <<\'EOF\'\ngh pr create -t x\nEOF\n); $x' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "round-3 probe denied"
expect deny "" "$(bash_payload $'cat <<\'EOF\' | sh\ngh pr create -t x --draft\nEOF' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "round-3 probe denied"
expect deny "" "$(bash_payload $'git commit -m "$(cat <<\'EOF\'\nfix: gh pr create -t x docs\nEOF\n)"' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "round-3 probe denied"
expect deny "" "$(bash_payload $'gh pr create -t x --draft -F - <<\'EOF\'\nbody gh pr create -t x\nEOF' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "round-3 probe denied"
expect deny "" "$(bash_payload $'echo "<<\'EOF\'"\ngh pr merge 5\nEOF' | STUB_DRAFT=false bash "$DIR/gh-pr-merge-gate.sh")" "round-3 probe denied"
expect deny "" "$(bash_payload $'cat <<\'EOF\' | bash\ngh pr merge 5\nEOF' | STUB_DRAFT=false bash "$DIR/gh-pr-merge-gate.sh")" "round-3 probe denied"
expect deny "" "$(bash_payload $'git -c alias.z=\'!gh pr create -t x\' z' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "round-3 probe denied"
expect deny "" "$(bash_payload $'awk \'BEGIN{system("gh pr create -t x")}\'' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "round-3 probe denied"


# Fix-verification probes: words built by shell expansion must be denied.
expect deny "" "$(bash_payload $'gh pr cre$()ate -t x' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "expansion probe denied"
expect deny "" "$(bash_payload $'gh pr cre${x}ate -t x' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "expansion probe denied"
expect deny "" "$(bash_payload $'gh pr cre$\'\'ate -t x' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "expansion probe denied"
expect deny "" "$(bash_payload $'gh pr c$\'r\'eate -t x' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "expansion probe denied"
expect deny "" "$(bash_payload $'gh pr {create,} -t x' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "expansion probe denied"
expect deny "" "$(bash_payload $'gh {pr,} create -t x' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "expansion probe denied"
expect deny "" "$(bash_payload $'gh pr cre$@ate -t x' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "expansion probe denied"
expect deny "" "$(bash_payload $'gh pr cre$""ate -t x' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "expansion probe denied"
expect deny "" "$(bash_payload $'gh p${z}r create -t x' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "expansion probe denied"
expect deny "" "$(bash_payload $'gh pr mer$()ge 5' | STUB_DRAFT=false bash "$DIR/gh-pr-merge-gate.sh")" "expansion probe denied"
expect deny "" "$(bash_payload $'gh pr mer${x}ge 7' | STUB_DRAFT=false bash "$DIR/gh-pr-merge-gate.sh")" "expansion probe denied"
expect deny "" "$(bash_payload $'gh pr {merge,} 7' | STUB_DRAFT=false bash "$DIR/gh-pr-merge-gate.sh")" "expansion probe denied"
expect deny "" "$(bash_payload $'gh pr create -t x <<<y' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "expansion probe denied"
expect deny "" "$(bash_payload $'x=$((1<<2)); echo gh pr create' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "expansion probe denied"
expect deny "" "$(bash_payload $'g${u}h pr create -t x' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "expansion probe denied"
expect deny "" "$(bash_payload $'gh pr cr$(printf e)ate -t x' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "expansion probe denied"
expect deny "" "$(bash_payload $'gh pr create --draft=true --draft=false -t x' | STUB_DRAFT=false bash "$DIR/gh-pr-create-gate.sh")" "expansion probe denied"
expect deny "" "$(bash_payload $'g${u}h pr merge 7' | STUB_DRAFT=false bash "$DIR/gh-pr-merge-gate.sh")" "expansion probe denied"
expect allow "" "$(bash_payload $'gh pr view "$N" --json state' | bash "$DIR/gh-pr-create-gate.sh")" "everyday gh command with $ or braces allowed"
expect allow "" "$(bash_payload $'gh pr view "$N" --json state' | bash "$DIR/gh-pr-merge-gate.sh")" "everyday gh command with $ or braces allowed"
expect allow "" "$(bash_payload $'gh pr list --json number --jq \'.[] | {n: .number}\'' | bash "$DIR/gh-pr-create-gate.sh")" "everyday gh command with $ or braces allowed"
expect allow "" "$(bash_payload $'gh pr list --json number --jq \'.[] | {n: .number}\'' | bash "$DIR/gh-pr-merge-gate.sh")" "everyday gh command with $ or braces allowed"
expect allow "" "$(bash_payload $'gh api repos/{owner}/{repo}/pulls --jq \'.[].number\'' | bash "$DIR/gh-pr-create-gate.sh")" "everyday gh command with $ or braces allowed"
expect allow "" "$(bash_payload $'gh api repos/{owner}/{repo}/pulls --jq \'.[].number\'' | bash "$DIR/gh-pr-merge-gate.sh")" "everyday gh command with $ or braces allowed"
expect allow "" "$(bash_payload $'gh pr checks $PR --watch' | bash "$DIR/gh-pr-create-gate.sh")" "everyday gh command with $ or braces allowed"
expect allow "" "$(bash_payload $'gh pr checks $PR --watch' | bash "$DIR/gh-pr-merge-gate.sh")" "everyday gh command with $ or braces allowed"
expect allow "" "$(bash_payload $'gh pr diff ${PR}' | bash "$DIR/gh-pr-create-gate.sh")" "everyday gh command with $ or braces allowed"
expect allow "" "$(bash_payload $'gh pr diff ${PR}' | bash "$DIR/gh-pr-merge-gate.sh")" "everyday gh command with $ or braces allowed"

echo "all $pass tests passed"

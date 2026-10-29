#!/usr/bin/env bash
# Tests for gh-pr-merge-gate.sh / .py, with a stub `gh` on PATH. Run directly:
#   bash scripts/gh-pr-merge-gate.test.sh
# Exits non-zero on first failure.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HOOK=$SCRIPT_DIR/gh-pr-merge-gate.sh

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
export GH_LOG=$WORK/gh.log
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$GH_LOG"
case "${STUB_DRAFT:-}" in
  fail) exit 1 ;;
  *) printf '%s\n' "${STUB_DRAFT:-}" ;;
esac
STUB
chmod +x "$WORK/bin/gh"
export PATH="$WORK/bin:$PATH"

pass=0
fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { pass=$((pass + 1)); echo "ok - $*"; }

payload() { python3 -c 'import json,sys; print(json.dumps({"tool_input":{"command":sys.argv[1]}}))' "$1"; }

check() {
  local want=$1 state=$2 cmd=$3 out
  : > "$GH_LOG"
  out=$(payload "$cmd" | STUB_DRAFT=$state bash "$HOOK")
  if echo "$out" | grep -q '"permissionDecision": *"deny"'; then
    [ "$want" = deny ] || fail "expected allow, got deny (draft=$state): $cmd"
  else
    [ "$want" = allow ] || fail "expected deny, got allow (draft=$state): $cmd"
    [ -z "$out" ] || fail "allow must be silent, got: $out"
  fi
  ok "$want [draft=$state] - $cmd"
}

check deny  true  'gh pr merge 5'
check deny  true  'gh pr merge 5 --squash --delete-branch'
check deny  true  'gh pr merge --auto --squash 5'
check allow false 'gh pr merge 5'
check allow false 'gh pr merge 5 --squash'
check deny  ''    'gh pr merge 5'
check deny  fail  'gh pr merge 5'
check deny  true  'gh pr merge --repo o/r 5'
check deny  true  'gh -R o/r pr merge 5'
check allow false 'gh pr merge --repo o/r 5'
check deny  true  'cd x && gh pr merge 5'
check deny  true  'bash -c "gh pr merge 5"'
check deny  true  $'echo hi\ngh pr merge 5'
check deny  true  $'cat <<EOF && gh pr merge 5\nbody\nEOF'
check allow true  $'gh pr comment 5 --body-file - <<EOF\ngh pr merge 5 is only text here\nEOF'
check deny  false 'gh api -X PUT repos/o/r/pulls/5/merge'
check deny  false 'gh api --method PUT /repos/o/r/pulls/5/merge -f merge_method=squash'
check deny  false 'gh api graphql -f query="mutation { mergePullRequest(input: {pullRequestId: \"x\"}) { clientMutationId } }"'
check allow true  'gh api repos/o/r/pulls/5'
check allow true  'gh pr view 5'
check allow true  'gh pr ready 5'
check allow true  'echo "gh pr merge is mentioned in text"'
check allow true  'git push origin HEAD'
check deny  false 'gh pr merge 5 --body "unterminated'
check deny  true  '"g"h pr merge 5'
check deny  true  'g\h pr merge 5'

: > "$GH_LOG"
payload 'gh pr merge --repo o/r 7' | STUB_DRAFT=false bash "$HOOK" > /dev/null
grep -q -- 'pr view 7 --repo o/r' "$GH_LOG" || fail "draft state must be read from the --repo target, got: $(cat "$GH_LOG")"
ok "draft lookup is scoped to --repo and the PR number"

out=$(printf '%s' 'not json but mentions gh' | bash "$HOOK")
echo "$out" | grep -q '"permissionDecision": *"deny"' || fail "malformed payload that mentions gh should deny, got: $out"
ok "deny - malformed payload fails closed"

out=$(printf '%s' 'not json and nothing to guard' | bash "$HOOK")
[ -z "$out" ] || fail "a payload that cannot spell gh should pass untouched, got: $out"
ok "allow - payload that cannot spell gh is not inspected"

CRASH=$(mktemp -d)
trap 'rm -rf "$CRASH"' EXIT
cp -R "$SCRIPT_DIR/." "$CRASH/"
echo "raise RuntimeError('injected crash')" >> "$CRASH/gh_command.py"
out=$(payload 'gh pr merge 5' | bash "$CRASH/gh-pr-merge-gate.sh")
echo "$out" | grep -q '"permissionDecision": *"deny"' || fail "a crashing checker must deny, got: $out"
echo "$out" | grep -q 'crashed' || fail "crash deny must say why, got: $out"
ok "deny - checker crash fails closed"

SPY=$(mktemp -d)
printf '#!/bin/sh\necho spawned >> "%s/calls"\nexec "%s" "$@"\n' "$SPY" "$(command -v python3)" > "$SPY/python3"
chmod +x "$SPY/python3"
: > "$SPY/calls"
for c in 'ls -la /tmp' 'git status' 'git push origin HEAD' 'npm test' 'cat README.md'; do
  payload "$c" | PATH="$SPY:$PATH" bash "$HOOK" > /dev/null
done
[ ! -s "$SPY/calls" ] || fail "commands that cannot spell gh must not start python, got $(wc -l < "$SPY/calls") spawns"
ok "allow - commands that cannot spell gh skip python"
payload 'gh pr merge 5' | PATH="$SPY:$PATH" bash "$HOOK" > /dev/null
[ "$(wc -l < "$SPY/calls" | tr -d ' ')" = 1 ] || fail "a gh command must start python once"
ok "allow - a gh command is inspected"
rm -rf "$SPY"

echo "all $pass tests passed"

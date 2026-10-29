#!/usr/bin/env bash
# Tests for gh-pr-create-gate.sh / .py. Run directly: bash scripts/gh-pr-create-gate.test.sh
# Exits non-zero on first failure.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HOOK=$SCRIPT_DIR/gh-pr-create-gate.sh

pass=0
fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { pass=$((pass + 1)); echo "ok - $*"; }

payload() { python3 -c 'import json,sys; print(json.dumps({"tool_input":{"command":sys.argv[1]}}))' "$1"; }

check() {
  local want=$1 cmd=$2 out
  out=$(payload "$cmd" | bash "$HOOK")
  if echo "$out" | grep -q '"permissionDecision": *"deny"'; then
    [ "$want" = deny ] || fail "expected allow, got deny: $cmd"
    echo "$out" | grep -q 'Review-first\|Could not parse' || fail "deny without a reason: $cmd"
  else
    [ "$want" = allow ] || fail "expected deny, got allow: $cmd"
    [ -z "$out" ] || fail "allow must be silent, got: $out"
  fi
  ok "$want - $cmd"
}

check deny  'gh pr create --title t --body b'
check allow 'gh pr create --draft --title t'
check allow 'gh pr create -d --title t'
check allow 'gh pr create --draft=true --title t'
check deny  'gh pr create --draft=false --title t'
check deny  'gh pr create --title "no --draft here" --body b'
check deny  'gh pr create --body "see --draft docs"'
check deny  'gh pr create --title --draft'
check deny  'gh -R org/repo pr create --title t'
check allow 'gh -R org/repo pr create --draft --title t'
check deny  'gh  pr   create --title t'
check deny  'cd x && gh pr create --title t'
check deny  'cd x; gh pr create --title t'
check deny  'true || gh pr create --title t'
check deny  '(gh pr create --title t)'
check deny  '/usr/local/bin/gh pr create --title t'
check deny  'FOO=1 gh pr create --title t'
check deny  'command gh pr create --title t'
check deny  'bash -c "gh pr create --title t"'
check allow 'bash -c "gh pr create --draft --title t"'
check deny  $'echo hi\ngh pr create --title t'
check deny  $'cat <<EOF && gh pr create --title t\nbody\nEOF'
check allow $'gh pr create --draft --title t --body "$(cat <<\'EOF\'\ngh pr create --body mentioned in text\nEOF\n)"'
check allow $'gh pr create --draft --body-file - <<EOF\ngh pr create without draft is just text here\nEOF'
check deny  'gh api repos/o/r/pulls -f title=t -f head=b -f base=main'
check deny  'gh api -X POST /repos/o/r/pulls -f title=t'
check allow 'gh api -X POST repos/o/r/pulls -f title=t -F draft=true'
check allow 'gh api repos/o/r/pulls'
check allow 'gh api repos/o/r/pulls/5'
check allow 'gh pr ready 5'
check allow 'gh pr view 5'
check allow 'gh pr list --draft'
check allow 'gh issue create --title t'
check allow 'git push origin HEAD'
check allow 'echo "gh pr create is mentioned in text"'
check deny  'gh pr create --title "unterminated'

out=$(printf '%s' 'not json' | bash "$HOOK")
echo "$out" | grep -q '"permissionDecision": *"deny"' || fail "malformed payload should deny, got: $out"
ok "deny - malformed payload fails closed"

echo "all $pass tests passed"

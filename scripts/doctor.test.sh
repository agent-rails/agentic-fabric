#!/usr/bin/env bash
# Tests for doctor.sh. Run directly: bash scripts/doctor.test.sh
# Exits non-zero on first failure.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOCTOR=$SCRIPT_DIR/doctor.sh
BASH_BIN=$(command -v bash)

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

pass=0
fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { pass=$((pass + 1)); echo "ok - $*"; }

BIN=$WORK/bin
HOME_DIR=$WORK/home
CLAUDE=$HOME_DIR/.claude
mkdir -p "$BIN" "$CLAUDE/scripts" "$HOME_DIR/.local/bin"
for t in jq python3 grep sort cmp; do ln -s "$(command -v $t)" "$BIN/$t"; done
for t in git gh; do printf '#!/bin/sh\nexit 0\n' > "$BIN/$t"; chmod +x "$BIN/$t"; done

make_hook() { printf '#!/bin/sh\nexit 0\n' > "$1"; chmod +x "$1"; }
settings() {
  jq -n --args '{hooks:{PreToolUse:[{matcher:"Bash",hooks:($ARGS.positional|map({type:"command",command:.}))}]}}' "$@" > "$CLAUDE/settings.json"
}
run() { HOME=$HOME_DIR PATH=$BIN "$BASH_BIN" "$DOCTOR" --claude-dir "$CLAUDE" 2>&1; }

expect_pass() {
  local out rc=0
  out=$(run) || rc=$?
  [ "$rc" -eq 0 ] || fail "$1: expected pass, got rc=$rc: $out"
  echo "$out" | grep -q 'all checks passed' || fail "$1: missing success line: $out"
  ok "$1"
}
expect_fail() {
  local name=$1 needle=$2 out rc=0
  out=$(run) || rc=$?
  [ "$rc" -ne 0 ] || fail "$name: expected failure, got pass: $out"
  echo "$out" | grep -q "FAIL.*$needle" || fail "$name: expected a FAIL mentioning '$needle', got: $out"
  ok "$name"
}

rm -f "$CLAUDE/settings.json"
expect_fail "missing settings.json fails" "not found"

printf 'not json' > "$CLAUDE/settings.json"
expect_fail "invalid JSON fails" "not valid JSON"

make_hook "$CLAUDE/scripts/gh-pr-create-gate.sh"
settings "$CLAUDE/scripts/gh-pr-create-gate.sh"
expect_pass "wired executable hook passes"

settings "/Users/youruser/.claude/scripts/gh-pr-create-gate.sh"
expect_fail "placeholder path fails" "placeholder left"

settings "your-pretool-hook"
expect_fail "placeholder command name fails" "placeholder left"

settings "$CLAUDE/scripts/does-not-exist.sh"
expect_fail "missing hook file fails" "hook file missing"

printf '#!/bin/sh\n' > "$CLAUDE/scripts/not-exec.sh"
settings "$CLAUDE/scripts/not-exec.sh"
expect_fail "non-executable hook fails" "not executable"

settings "nosuchcommand"
expect_fail "bare command not on PATH fails" "hook command not found"

ln -sf "$BASH_BIN" "$BIN/bash"
settings "bash $CLAUDE/scripts/nonexistent-hook.sh"
expect_fail "interpreter with a missing script fails" "hook script missing"

settings "bash \"$CLAUDE/scripts/gh-pr-create-gate.sh\""
expect_pass "interpreter with a present quoted script passes"

settings 'bash "$CLAUDE_PROJECT_DIR/hooks/x.sh"'
expect_pass "script path built from a variable is not checked"

mkdir -p "$CLAUDE/my hooks"
settings "bash \"$CLAUDE/my hooks/gone.sh\""
expect_fail "missing quoted script path with a space fails" "hook script missing: $CLAUDE/my hooks/gone.sh"

make_hook "$CLAUDE/my hooks/here.sh"
settings "bash \"$CLAUDE/my hooks/here.sh\""
expect_pass "present quoted script path with a space passes"

make_hook "$CLAUDE/scripts/gh-pr-create-gate.sh"
settings "$CLAUDE/scripts/gh-pr-create-gate.sh"
out=$(run) || true
echo "$out" | grep -q "warn - drift: $CLAUDE/scripts/gh-pr-create-gate.sh differs" || fail "a deployed script that differs from the repo must warn: $out"
echo "$out" | grep -q 'all checks passed' || fail "drift must warn, not fail: $out"
ok "drifted deployed script warns"

cp "$SCRIPT_DIR/gh-pr-create-gate.sh" "$CLAUDE/scripts/gh-pr-create-gate.sh"
out=$(run) || true
echo "$out" | grep -q 'ok   - deployed scripts match the repo copies (1 compared)' || fail "an identical deployed script must not warn: $out"
ok "matching deployed script passes the drift check"

printf '\n' >> "$CLAUDE/scripts/gh-pr-create-gate.sh"
out=$(run) || true
echo "$out" | grep -q "warn - drift: $CLAUDE/scripts/gh-pr-create-gate.sh differs" || fail "a trailing-newline difference must count as drift: $out"
ok "trailing-newline difference is drift"
cp "$SCRIPT_DIR/gh-pr-create-gate.sh" "$CLAUDE/scripts/gh-pr-create-gate.sh"

cp "$DOCTOR" "$CLAUDE/scripts/doctor.sh"
out=$(HOME=$HOME_DIR PATH=$BIN "$BASH_BIN" "$CLAUDE/scripts/doctor.sh" --claude-dir "$CLAUDE" 2>&1) || true
echo "$out" | grep -q 'drift not checked: doctor.sh is running from the deployed copy' || fail "doctor run from the deployed copy must not claim a match: $out"
ok "doctor run from the deployed copy does not claim a match"
rm "$CLAUDE/scripts/doctor.sh"

settings "bash \"$CLAUDE/scripts/unclosed.sh"
expect_fail "unbalanced quotes in a hook command fail" "could not split"

make_hook "$CLAUDE/scripts/scan-write-content.sh"
settings "$CLAUDE/scripts/scan-write-content.sh"
expect_fail "write scan without guard fails" "guard is not installed"
make_hook "$HOME_DIR/.local/bin/guard"
expect_pass "write scan with guard passes"
rm -f "$HOME_DIR/.local/bin/guard"

make_hook "$CLAUDE/scripts/enforce-branch-prefix.sh"
settings "$CLAUDE/scripts/enforce-branch-prefix.sh"
expect_fail "branch hook without its python file fails" "is missing"
printf 'REQUIRED_PREFIX = "youralias/"\n' > "$CLAUDE/scripts/enforce-branch-prefix.py"
expect_fail "branch hook with placeholder prefix fails" "still youralias/"
printf 'REQUIRED_PREFIX = "me/"\n' > "$CLAUDE/scripts/enforce-branch-prefix.py"
expect_pass "branch hook with a real prefix passes"

settings "$CLAUDE/scripts/gh-pr-create-gate.sh"
rm "$BIN/jq"
expect_fail "missing jq fails" "jq"

echo "all $pass tests passed"

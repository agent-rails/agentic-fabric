#!/usr/bin/env bash
# Tests for enforce-resume-constraints.sh / .py. No test framework in this repo —
# self-contained bash harness, run directly:
#   bash scripts/enforce-resume-constraints.test.sh
# Exits non-zero on first failure.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HOOK=$SCRIPT_DIR/enforce-resume-constraints.sh

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
export AGENT_TASKS_DIR="$WORK/tasks"

pass=0
fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { pass=$((pass + 1)); echo "ok - $*"; }

write_record() {
  mkdir -p "$AGENT_TASKS_DIR"
  printf '%s' "$2" > "$AGENT_TASKS_DIR/$1.json"
}

run() { printf '%s' "{\"tool_input\":{\"to\":\"$1\"}}" | bash "$HOOK"; }

is_deny() { echo "$1" | grep -q '"permissionDecision": *"deny"'; }

# 1. Record with empty constraints -> DENY.
rm -rf "$AGENT_TASKS_DIR"
write_record empty '{"agent_id":"empty","goal":"g","constraints":[],"decisions_so_far":[],"next_action":null,"status":"active"}'
out=$(run empty)
is_deny "$out" || fail "expected deny for empty constraints, got: $out"
echo "$out" | grep -q 'no recorded constraints for empty' || fail "deny message missing/incorrect"
ok "empty constraints -> deny"

# 2. Record with non-empty constraints -> allow (silent, no deny JSON).
rm -rf "$AGENT_TASKS_DIR"
write_record full '{"agent_id":"full","goal":"g","constraints":["do not touch prod"],"decisions_so_far":[],"next_action":null,"status":"active"}'
out=$(run full)
is_deny "$out" && fail "should not deny when constraints present: $out"
[ -z "$out" ] || fail "expected silent allow, got output: $out"
ok "non-empty constraints -> allow (silent)"

# 3. No record for target -> allow (silent). Fail-open for name-based/untracked resume.
rm -rf "$AGENT_TASKS_DIR"
mkdir -p "$AGENT_TASKS_DIR"
out=$(run someName)
is_deny "$out" && fail "should not deny when no record exists: $out"
[ -z "$out" ] || fail "expected silent allow for no record, got: $out"
ok "no record -> allow (silent)"

# 4. No `to` in payload -> allow (silent).
rm -rf "$AGENT_TASKS_DIR"
out=$(printf '%s' '{"tool_input":{}}' | bash "$HOOK")
is_deny "$out" && fail "should not deny when no target: $out"
[ -z "$out" ] || fail "expected silent allow for missing target, got: $out"
ok "missing target -> allow (silent)"

# 5. Malformed stdin -> allow (silent, fail open, exit 0).
rm -rf "$AGENT_TASKS_DIR"
set +e
out=$(printf '%s' 'not json' | bash "$HOOK"); rc=$?
set -e
[ "$rc" -eq 0 ] || fail "malformed stdin should exit 0, got $rc"
is_deny "$out" && fail "malformed stdin should not deny: $out"
ok "malformed stdin -> allow (silent), exits 0"

echo "all $pass tests passed"

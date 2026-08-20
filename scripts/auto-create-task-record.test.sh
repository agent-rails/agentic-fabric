#!/usr/bin/env bash
# Tests for auto-create-task-record.sh / .py. No test framework in this repo —
# self-contained bash harness, run directly:
#   bash scripts/auto-create-task-record.test.sh
# Exits non-zero on first failure.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HOOK=$SCRIPT_DIR/auto-create-task-record.sh

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
export AGENT_TASKS_DIR="$WORK/tasks"

pass=0
fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { pass=$((pass + 1)); echo "ok - $*"; }

field() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' "$1" "$2"; }
constraints_json() { python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1]))["constraints"]))' "$1"; }

# 1. agentId + HARD CONSTRAINTS section -> record with constraints populated.
rm -rf "$AGENT_TASKS_DIR"
printf '%s' '{"tool_input":{"prompt":"Do the thing.\n\nHARD CONSTRAINTS:\n- do not touch live config\n- stop before the PR\n\nOther text."},"tool_response":{"status":"async_launched","agentId":"aaa111"}}' | bash "$HOOK"
rec="$AGENT_TASKS_DIR/aaa111.json"
[ -f "$rec" ] || fail "record not created for aaa111"
[ "$(field "$rec" agent_id)" = "aaa111" ] || fail "agent_id wrong"
[ "$(field "$rec" status)" = "active" ] || fail "status not active"
[ "$(constraints_json "$rec")" = '["do not touch live config", "stop before the PR"]' ] || fail "constraints not parsed: $(constraints_json "$rec")"
ok "creates record with parsed HARD CONSTRAINTS (background dispatch)"

# 2. no HARD CONSTRAINTS section -> constraints: []
rm -rf "$AGENT_TASKS_DIR"
printf '%s' '{"tool_input":{"prompt":"Just do it, no constraints stated."},"tool_response":{"status":"completed","agentId":"bbb222"}}' | bash "$HOOK"
rec="$AGENT_TASKS_DIR/bbb222.json"
[ -f "$rec" ] || fail "record not created for bbb222"
[ "$(constraints_json "$rec")" = '[]' ] || fail "expected empty constraints, got $(constraints_json "$rec")"
ok "empty constraints when no HARD CONSTRAINTS section"

# 3. no agentId in tool_response -> no record, exit 0 (fail open, don't crash)
rm -rf "$AGENT_TASKS_DIR"
set +e
printf '%s' '{"tool_input":{"prompt":"x"},"tool_response":{"status":"completed"}}' | bash "$HOOK"
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "expected exit 0 on missing agentId, got $rc"
[ -z "$(ls -A "$AGENT_TASKS_DIR" 2>/dev/null || true)" ] || fail "a record was written despite no agentId"
ok "no agentId -> writes nothing, exits 0"

# 4. record already exists -> not overwritten, exit 0
rm -rf "$AGENT_TASKS_DIR"
mkdir -p "$AGENT_TASKS_DIR"
printf '%s' '{"preexisting":true}' > "$AGENT_TASKS_DIR/ccc333.json"
set +e
printf '%s' '{"tool_input":{"prompt":"new goal\n\nHARD CONSTRAINTS:\n- x"},"tool_response":{"status":"completed","agentId":"ccc333"}}' | bash "$HOOK"
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "expected exit 0 when record exists, got $rc"
grep -q 'preexisting' "$AGENT_TASKS_DIR/ccc333.json" || fail "existing record was overwritten"
ok "existing record not overwritten, exits 0"

# 5. inline constraint on the marker line, plus a following bullet, plus a next
#    section marker that must terminate the list.
rm -rf "$AGENT_TASKS_DIR"
printf '%s' '{"tool_input":{"prompt":"Task.\nHARD CONSTRAINTS: never delete prod\n- also never force-push\nDELIVERABLES:\n- a report"},"tool_response":{"status":"completed","agentId":"ddd444"}}' | bash "$HOOK"
rec="$AGENT_TASKS_DIR/ddd444.json"
[ "$(constraints_json "$rec")" = '["never delete prod", "also never force-push"]' ] || fail "inline+bullet+terminator parse wrong: $(constraints_json "$rec")"
ok "parses inline constraint and terminates at next section marker"

echo "all $pass tests passed"

#!/usr/bin/env bash
# Tests for task-record.sh / .py. No test framework in this repo —
# self-contained bash harness, run directly:
#   bash scripts/task-record.test.sh
# Exits non-zero on first failure.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CLI=$SCRIPT_DIR/task-record.sh

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
export AGENT_TASKS_DIR="$WORK/tasks"

pass=0
fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { pass=$((pass + 1)); echo "ok - $*"; }

seed() {
  rm -rf "$AGENT_TASKS_DIR"
  mkdir -p "$AGENT_TASKS_DIR"
  printf '%s' '{"agent_id":"a1","goal":"g","constraints":[],"decisions_so_far":[],"next_action":null,"status":"active"}' \
    > "$AGENT_TASKS_DIR/a1.json"
}

# 1. read returns the record for an existing agent_id.
seed
out=$(bash "$CLI" read a1)
echo "$out" | grep -q '"agent_id": "a1"\|"agent_id":"a1"' || fail "read did not return the record"
ok "read returns an existing record"

# 2. read on a missing record: empty output, exit 0 (never crash).
seed
set +e
out=$(bash "$CLI" read nope); rc=$?
set -e
[ "$rc" -eq 0 ] || fail "read on missing record exited $rc"
[ -z "$out" ] || fail "read on missing record printed: $out"
ok "read on missing record is empty and exits 0"

# 3. append-decision appends and persists.
seed
bash "$CLI" append-decision a1 "chose option B"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["decisions_so_far"]==["chose option B"], d' "$AGENT_TASKS_DIR/a1.json" || fail "decision not appended"
bash "$CLI" append-decision a1 "then option C"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["decisions_so_far"]==["chose option B","then option C"], d' "$AGENT_TASKS_DIR/a1.json" || fail "second decision not appended"
ok "append-decision appends in order and persists"

# 4. append-decision on a missing record fails loud (non-zero).
seed
set +e
bash "$CLI" append-decision ghost "x" 2>/dev/null; rc=$?
set -e
[ "$rc" -ne 0 ] || fail "append-decision on missing record should fail non-zero"
ok "append-decision on missing record fails loud"

# 5. complete deletes the record.
seed
bash "$CLI" complete a1
[ ! -f "$AGENT_TASKS_DIR/a1.json" ] || fail "complete did not delete the record"
ok "complete deletes the record"

# 6. complete on a missing record is a no-op, exit 0.
seed
set +e
bash "$CLI" complete ghost; rc=$?
set -e
[ "$rc" -eq 0 ] || fail "complete on missing record exited $rc"
ok "complete on missing record is a no-op, exits 0"

echo "all $pass tests passed"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
VALIDATOR=$SCRIPT_DIR/validate-judge-verdict.sh
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

pass=0
fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { pass=$((pass + 1)); echo "ok - $*"; }

valid='{"schema_version":1,"verdict":"converged","confidence":0.83,"blocking_dimensions":[],"evidence_refs":["check:test"],"reason":"All required evidence is present."}'
out=$(printf '%s' "$valid" | bash "$VALIDATOR")
python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["verdict"] == "converged"' "$out" || fail "valid verdict changed"
ok "accepts a valid verdict"

set +e
out=$(printf '%s' 'not-json' | bash "$VALIDATOR"); rc=$?
set -e
[ "$rc" -eq 3 ] || fail "malformed JSON exited $rc"
python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["verdict"] == "human_review" and d["confidence"] == 0' "$out" || fail "malformed JSON did not fail closed"
ok "malformed JSON fails closed"

set +e
out=$(printf '%s' '{"schema_version":1,"verdict":"converged","confidence":1,"blocking_dimensions":["evidence"],"evidence_refs":[],"reason":"contradiction"}' | bash "$VALIDATOR"); rc=$?
set -e
[ "$rc" -eq 3 ] || fail "contradictory verdict exited $rc"
echo "$out" | grep -q 'human_review' || fail "contradictory verdict did not fail closed"
ok "converged with blockers fails closed"

set +e
out=$(printf '%s' '{"schema_version":1,"verdict":"ALLOW","confidence":1,"blocking_dimensions":[],"evidence_refs":[],"reason":"ship it"}' | bash "$VALIDATOR"); rc=$?
set -e
[ "$rc" -eq 3 ] || fail "unknown verdict exited $rc"
echo "$out" | grep -q 'human_review' || fail "unknown verdict did not fail closed"
ok "outbound-style verdict is rejected"

set +e
out=$(printf '%s' '{"schema_version":1,"verdict":"continue","confidence":true,"blocking_dimensions":[],"evidence_refs":[],"reason":"boolean is not a score"}' | bash "$VALIDATOR"); rc=$?
set -e
[ "$rc" -eq 3 ] || fail "boolean confidence exited $rc"
echo "$out" | grep -q 'human_review' || fail "boolean confidence did not fail closed"
ok "boolean confidence is rejected"

set +e
out=$(printf '%s' '{"schema_version":1,"verdict":"continue","confidence":0.5,"blocking_dimensions":[{}],"evidence_refs":[],"reason":"nested attacker-controlled value"}' | bash "$VALIDATOR"); rc=$?
set -e
[ "$rc" -eq 3 ] || fail "object dimension exited $rc"
echo "$out" | grep -q 'human_review' || fail "object dimension did not fail closed"
ok "unhashable attacker-controlled values fail closed"

set +e
out=$(printf '%s' '{"schema_version":true,"verdict":"continue","confidence":0.5,"blocking_dimensions":[],"evidence_refs":[],"reason":"boolean schema version"}' | bash "$VALIDATOR"); rc=$?
set -e
[ "$rc" -eq 3 ] || fail "boolean schema version exited $rc"
echo "$out" | grep -q 'human_review' || fail "boolean schema version did not fail closed"
ok "boolean schema version is rejected"

echo "all $pass tests passed"

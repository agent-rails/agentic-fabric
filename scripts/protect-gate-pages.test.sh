#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HOOK=$SCRIPT_DIR/protect-gate-pages.sh
pass=0
fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { pass=$((pass + 1)); echo "ok - $*"; }

payload() {
  python3 -c 'import json,sys; print(json.dumps({"tool_input":{"file_path":sys.argv[1]}}))' "$1"
}

out=$(payload "/tmp/repo/evals/review-convergence/rubric.md" | bash "$HOOK")
decision=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // empty')
[ "$decision" = "deny" ] || fail "judge rubric was not protected"
ok "judge rubric is protected"

out=$(payload "/tmp/repo/src/app.py" | bash "$HOOK")
[ -z "$out" ] || fail "ordinary file unexpectedly denied: $out"
ok "ordinary files remain writable"

echo "all $pass tests passed"

#!/usr/bin/env bash
# Tests for gh-pr-merge-gate.sh with a stub `gh` on PATH. Run directly:
#   bash scripts/gh-pr-merge-gate.test.sh
# Exits non-zero on first failure.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
[ -f "$SCRIPT_DIR/../scripts/gh-pr-merge-gate.sh" ] && SCRIPT_DIR=$(cd "$SCRIPT_DIR/../scripts" && pwd)
HOOK=$SCRIPT_DIR/gh-pr-merge-gate.sh

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/home"
export HOME=$WORK/home
export GH_LOG=$WORK/gh.log
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$GH_LOG"
if [ "$1" = api ]; then
  [ "${STUB_TIP:-}" = fail ] && exit 1
  printf '%s\n' "${STUB_TIP:-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}"
  exit 0
fi
[ "${STUB_DRAFT:-}" = fail ] && { echo "not found" >&2; exit 1; }
[ -n "${STUB_WARN:-}" ] && echo "warning: newer gh available" >&2
printf '{"isDraft":%s,"headRefOid":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","headRefName":"feat/x","url":"https://github.com/o/r/pull/5","isCrossRepository":%s}\n' "$STUB_DRAFT" "${STUB_CROSS:-false}"  # leak-scan: fixture
STUB
chmod +x "$WORK/bin/gh"
export PATH="$WORK/bin:$PATH"

pass=0
fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { pass=$((pass + 1)); echo "ok - $*"; }
payload() { jq -nc --arg c "$1" '{tool_name:"Bash",session_id:"s",tool_use_id:"t",tool_input:{command:$c}}'; }

check() {
  local want=$1 needle=$2 cmd=$3 out
  out=$(payload "$cmd" | bash "$HOOK")
  if [ "$want" = allow ]; then
    [ -z "$out" ] || fail "expected allow, got: $out ($cmd)"
  else
    echo "$out" | grep -q '"permissionDecision":"deny"' || fail "expected deny, got: $out ($cmd)"
    echo "$out" | grep -q "$needle" || fail "deny must say '$needle', got: $out"
  fi
  ok "$want - $cmd [draft=${STUB_DRAFT:-} tip=${STUB_TIP:-}]"
}

STUB_DRAFT=true check deny "STILL A DRAFT" 'gh pr merge 5 --squash'
STUB_DRAFT=false check allow "" 'gh pr merge 5 --squash'
STUB_DRAFT=fail check deny "PROBE FAILED" 'gh pr merge 5'
STUB_DRAFT=false STUB_TIP=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb check deny "STALE PR HEAD" 'gh pr merge 5'
STUB_DRAFT=false STUB_TIP=fail check deny "could not read the tip" 'gh pr merge 5'
STUB_DRAFT=false STUB_TIP=not-a-sha check deny "could not read the tip" 'gh pr merge 5'
STUB_DRAFT=false STUB_CROSS=true STUB_TIP=fail check allow "" 'gh pr merge 5'
STUB_DRAFT=false STUB_WARN=1 check allow "" 'gh pr merge 5'
STUB_DRAFT=false check deny "ambiguous" 'gh pr merge 5 --repo a/b --repo c/d'
STUB_DRAFT=false check deny "one plain command" 'gh pr merge 5; echo --repo other/ready'
STUB_DRAFT=false check deny "one plain command" 'gh pr merge 7 && gh pr merge 5'
STUB_DRAFT=false check deny "ambiguous" 'gh pr merge 7 5'
STUB_DRAFT=false check deny "one plain command" 'GH_REPO=o/other gh pr merge 5'
STUB_DRAFT=false check deny "one plain command" 'cd /tmp && gh pr merge 5'
STUB_DRAFT=false check deny "one plain command" "bash -c 'gh pr merge 5'"
STUB_DRAFT=false check deny "one plain command" 'cat <<EOF >/dev/null; gh pr merge 5'
STUB_DRAFT=false check deny "does not know the flag" 'gh pr merge 5 --frobnicate'
STUB_DRAFT=false check deny "one plain" '{ gh pr merge 5; }'
STUB_DRAFT=false check deny "one plain" 'caffeinate gh pr merge 5'
STUB_DRAFT=false check deny "one plain" 'if true; then gh pr merge 5; fi'
STUB_DRAFT=true check deny "DRAFT" "g\\h pr merge 7"

repo_probe() {
  : > "$GH_LOG"
  payload "$1" | STUB_DRAFT=true bash "$HOOK" > /dev/null
  grep -m1 '^pr view' "$GH_LOG"
}
[ "$(repo_probe 'gh pr merge 5 --repo "o/r"')" = "pr view 5 --repo o/r --json isDraft,headRefOid,headRefName,url,isCrossRepository" ] || fail "a quoted --repo must be parsed, not rejected: $(cat "$GH_LOG")"
ok "a quoted --repo value is parsed"
[ "$(repo_probe 'gh pr merge --subject ready 7')" = "pr view 7 --json isDraft,headRefOid,headRefName,url,isCrossRepository" ] || fail "a flag value must not be taken as the PR: $(cat "$GH_LOG")"
ok "a flag value is never taken as the PR"
[ "$(repo_probe 'gh pr merge -t 5 7')" = "pr view 7 --json isDraft,headRefOid,headRefName,url,isCrossRepository" ] || fail "-t takes a value: $(cat "$GH_LOG")"
ok "-t value is skipped"
[ "$(repo_probe 'gh pr merge 5 --body "a \" --repo other/ready \""')" = "pr view 5 --json isDraft,headRefOid,headRefName,url,isCrossRepository" ] || fail "--repo inside an escaped body must not scope the lookup: $(cat "$GH_LOG")"
ok "--repo inside an escaped body value is ignored"
[ "$(repo_probe "gh pr merge 5 --body 'see --repo other/ready'")" = "pr view 5 --json isDraft,headRefOid,headRefName,url,isCrossRepository" ] || fail "--repo inside quotes must not scope the lookup: $(cat "$GH_LOG")"
ok "--repo inside a quoted value is ignored"
[ "$(repo_probe 'gh pr merge 5 -R o/r --subject "fix it"')" = "pr view 5 --repo o/r --json isDraft,headRefOid,headRefName,url,isCrossRepository" ] || fail "-R must scope the lookup: $(cat "$GH_LOG")"
ok "-R scopes the lookup alongside a quoted subject"
STUB_DRAFT=true check allow "" 'gh pr view 5'

payload 'gh pr merge 5' | STUB_DRAFT=true bash "$HOOK" > /dev/null
payload 'gh pr merge 5' | STUB_DRAFT=false bash "$HOOK" > /dev/null
log=$HOME/.claude/gate-decisions.jsonl
[ "$(jq -r '.decision + " " + .reason' "$log" | tail -2 | tr '\n' '|')" = "deny draft|allow merge-permitted|" ] || fail "decision log mismatch: $(cat "$log")"
grep -q 'gh pr merge' "$log" && fail "decision log must not store command text"
ok "decisions logged without command text"

NOLOG=$(mktemp -d)
cp "$HOOK" "$NOLOG/"
out=$(payload 'gh pr merge 5' | STUB_DRAFT=true bash "$NOLOG/gh-pr-merge-gate.sh")
rm -rf "$NOLOG"
echo "$out" | grep -q '"permissionDecision":"deny"' || fail "gate must still deny without the log library, got: $out"
ok "gate decides the same without the log library"

echo "all $pass tests passed"

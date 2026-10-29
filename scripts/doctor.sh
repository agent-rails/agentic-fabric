#!/usr/bin/env bash
# Checks an installed copy of this stack: required tools, hook wiring in settings.json,
# unreplaced placeholders, and the dependencies the wired hooks fail closed without.
# Usage: bash scripts/doctor.sh [--claude-dir DIR]   (default: ~/.claude)
# Exits 1 if any check fails.

set -uo pipefail

CLAUDE_DIR="$HOME/.claude"
if [ "${1:-}" = "--claude-dir" ]; then
  CLAUDE_DIR=${2:?--claude-dir needs a directory}
fi
SETTINGS="$CLAUDE_DIR/settings.json"

failures=0
ok() { echo "ok   - $*"; }
warn() { echo "warn - $*"; }
bad() { echo "FAIL - $*"; failures=$((failures + 1)); }

for tool in git gh python3 jq; do
  if command -v "$tool" >/dev/null 2>&1; then ok "$tool on PATH"; else bad "$tool not found on PATH"; fi
done
command -v codex >/dev/null 2>&1 && ok "codex on PATH (cross-vendor reviewer available)" \
  || warn "codex not on PATH: the same-vendor reviewer runs in its place"

if [ ! -f "$SETTINGS" ]; then
  bad "$SETTINGS not found: hooks are not wired"
  echo "$failures check(s) failed"
  exit 1
fi
if ! command -v jq >/dev/null 2>&1 || ! jq -e . "$SETTINGS" >/dev/null 2>&1; then
  bad "$SETTINGS is not valid JSON (or jq is missing)"
  echo "$failures check(s) failed"
  exit 1
fi
ok "$SETTINGS parses"

wired=$(jq -r '.. | objects | select(.type? == "command") | .command' "$SETTINGS" 2>/dev/null | sort -u)
if [ -z "$wired" ]; then
  warn "no hook commands wired in $SETTINGS"
fi

while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  exe=${cmd%% *}
  exe=${exe/#\~/$HOME}
  case "$cmd" in
    *youruser*|*your-*|*youralias*|*YOUR_*) bad "placeholder left in hook command: $cmd"; continue ;;
  esac
  case "$exe" in
    /*)
      if [ ! -e "$exe" ]; then bad "hook file missing: $exe"
      elif [ ! -x "$exe" ]; then bad "hook file not executable: $exe"
      else ok "hook present: $exe"; fi
      ;;
    *)
      if command -v "$exe" >/dev/null 2>&1; then ok "hook command on PATH: $exe"; else bad "hook command not found: $exe"; fi
      ;;
  esac
done <<< "$wired"

if grep -q 'scan-write-content.sh' <<< "$wired"; then
  if PATH="$HOME/.local/bin:$PATH" command -v guard >/dev/null 2>&1; then
    ok "guard on PATH (needed by scan-write-content.sh)"
  else
    bad "scan-write-content.sh is wired but guard is not installed: every Write/Edit will be denied (see README Prerequisites)"
  fi
fi

if grep -q 'enforce-branch-prefix.sh' <<< "$wired"; then
  prefix_file="$CLAUDE_DIR/scripts/enforce-branch-prefix.py"
  if [ ! -f "$prefix_file" ]; then
    bad "enforce-branch-prefix.sh is wired but $prefix_file is missing"
  elif grep -q 'REQUIRED_PREFIX = "youralias/"' "$prefix_file"; then
    bad "REQUIRED_PREFIX is still youralias/ in $prefix_file: new branches are denied unless named youralias/..."
  else
    ok "branch prefix set"
  fi
fi

if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"

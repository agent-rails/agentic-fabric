#!/usr/bin/env bash
# Reproduces the evidence in docs/decisions/0002-fail-closed-hooks.md.
#
# Builds four throwaway plugins whose PreToolUse(Bash) hook fails in a different
# way, asks a non-interactive Claude Code session to run one `touch`, and reports
# whether the file appeared. Loads each plugin with --plugin-dir for that session
# only; your installed plugins and settings are not changed.
#
# Costs four short model calls (haiku). Requires the claude CLI, logged in.
# Usage: bash docs/evidence/onfailure-check.sh

set -euo pipefail

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

make_plugin() {
  local name=$1 body=$2 on_failure=$3 dir="$WORK/$1"
  mkdir -p "$dir/.claude-plugin" "$dir/scripts"
  printf '#!/bin/sh\ncat >/dev/null\n%s\n' "$body" > "$dir/scripts/hook.sh"
  chmod +x "$dir/scripts/hook.sh"
  local extra=""
  [ "$on_failure" = block ] && extra=', "onFailure": "block"'
  cat > "$dir/.claude-plugin/plugin.json" <<JSON
{"name":"onfailure-check","version":"0.0.1","description":"check","author":{"name":"check"},
 "hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"\"\${CLAUDE_PLUGIN_ROOT}\"/scripts/hook.sh","timeout":2$extra}]}]}}
JSON
}

make_plugin exit1-no-onfailure 'exit 1' none
make_plugin exit1-block 'exit 1' block
make_plugin timeout-block 'sleep 10' block
make_plugin malformed-exit0-block 'echo "{not json"; exit 0' block

printf '%-24s %s\n' case result
for case in exit1-no-onfailure exit1-block timeout-block malformed-exit0-block; do
  marker="$WORK/marker-$case"
  echo "Run exactly this one bash command and nothing else: touch $marker" \
    | claude -p --plugin-dir "$WORK/$case" --model haiku --max-turns 3 --allowedTools "Bash(touch:*)" > "$WORK/out-$case.txt" 2>&1 || true
  if [ -e "$marker" ]; then result="call ran"; else result="call blocked"; fi
  printf '%-24s %s\n' "$case" "$result"
done
echo "claude $(claude --version 2>/dev/null | head -1)"

#!/usr/bin/env bash
# PreToolUse(Bash) gate — enforce the configured prefix on git branch creation.
#
# Fast prefilter: a cheap grep on the raw hook payload. Normal Bash calls that
# can't be creating a branch exit here immediately (no python spawn), so this
# adds ~nothing to everyday shell commands. Only plausible branch-creation
# commands fall through to the precise per-subcommand parser.
#
# Fail-open by design: this enforces a naming convention, not a security
# boundary — any unexpected error should allow the command, never wedge the CLI.

input=$(cat)

printf '%s' "$input" | grep -qE 'checkout[[:space:]]+-[bB]|switch[[:space:]]+-[cC]|worktree[[:space:]]+add|switch[[:space:]]+--(force-)?create|checkout[[:space:]]+--orphan|switch[[:space:]]+--orphan|git[[:space:]]+branch[[:space:]]' || exit 0

out=$(printf '%s' "$input" | python3 "$(dirname "${BASH_SOURCE[0]}")/enforce-branch-prefix.py" 2>/dev/null) || exit 0
[ -n "$out" ] || exit 0

printf '%s\n' "$out"

GATE_PAYLOAD=$input
_gate_log_lib="$(dirname "${BASH_SOURCE[0]}")/gate-decision-log.sh"
if [ -r "$_gate_log_lib" ]; then . "$_gate_log_lib"; else log_gate_decision() { return 0; }; fi
log_gate_decision enforce-branch-prefix deny missing-prefix

#!/usr/bin/env bash
# PreToolUse(Bash) gate — enforce the `youralias/` prefix on git branch creation.
#
# Fast prefilter: a cheap grep on the raw hook payload. Normal Bash calls that
# can't be creating a branch exit here immediately (no python spawn), so this
# adds ~nothing to everyday shell commands. Only plausible branch-creation
# commands fall through to the precise per-subcommand parser.
#
# Fail-open by design: this enforces a naming convention, not a security
# boundary — any unexpected error should allow the command, never wedge the CLI.

input=$(cat)

printf '%s' "$input" | grep -qE 'checkout[[:space:]]+-[bB]|switch[[:space:]]+-[cC]|worktree[[:space:]]+add|git[[:space:]]+branch[[:space:]]' || exit 0

printf '%s' "$input" | python3 "$HOME/.claude/scripts/enforce-branch-prefix.py" 2>/dev/null || exit 0

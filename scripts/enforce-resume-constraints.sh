#!/usr/bin/env bash
# PreToolUse(SendMessage) hook — fail loud when resuming a task whose recorded
# constraints are empty (ADR-0011).
#
# Thin wrapper: pipes the raw hook payload to the Python checker next to this
# script. The checker prints a deny JSON only in the narrow fail-loud window and
# otherwise stays silent. Fail-open by design: any wrapper-level error exits 0
# (allow), never wedges a resume.

input=$(cat)
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

printf '%s' "$input" | python3 "$SCRIPT_DIR/enforce-resume-constraints.py" 2>/dev/null || exit 0

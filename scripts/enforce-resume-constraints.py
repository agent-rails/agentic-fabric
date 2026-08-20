#!/usr/bin/env python3
"""PreToolUse(SendMessage) hook: fail loud when resuming a task whose recorded
constraints are empty.

Reads the PreToolUse hook JSON on stdin, takes `tool_input.to` as the resume
target, and asks `task-record.py read <target>` for that target's record.

Fail-loud fires only in one narrow window (ADR-0011):
  - no record                     -> allow, silently (covers name-based resume
                                     with no matching agentId file, and any
                                     untracked/pre-mechanism resume)
  - record with non-empty constraints -> allow
  - record with `constraints: []` -> DENY: verify before acting

Everything outside that window is fail-open, consistent with this repo's hook
convention. Deny uses the standard mechanism: a hookSpecificOutput deny JSON on
stdout, exit 0.
"""
import json
import subprocess
import sys
from pathlib import Path
from typing import NoReturn


def allow() -> NoReturn:
    sys.exit(0)


def deny(agent_id: str) -> NoReturn:
    reason = (
        f"no recorded constraints for {agent_id} — verify before acting, "
        f"do not assume none exist"
    )
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)


def read_record(target: str) -> dict | None:
    reader = Path(__file__).resolve().parent / "task-record.py"
    try:
        result = subprocess.run(
            [sys.executable, str(reader), "read", target],
            capture_output=True,
            text=True,
            timeout=5,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    output = result.stdout.strip()
    if not output:
        return None
    try:
        parsed = json.loads(output)
    except json.JSONDecodeError:
        return None
    return parsed if isinstance(parsed, dict) else None


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        allow()

    target = (data.get("tool_input") or {}).get("to")
    if not target:
        allow()

    record = read_record(target)
    if record is None:
        allow()

    if record.get("constraints"):
        allow()

    deny(target)


if __name__ == "__main__":
    main()

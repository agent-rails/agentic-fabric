#!/usr/bin/env python3
"""PostToolUse(Agent) hook: auto-create a continuation record at dispatch time.

Reads the PostToolUse hook JSON on stdin. Extracts the spawned `agentId` from
`tool_response` (present for both `"status":"completed"` foreground dispatch and
`"status":"async_launched"` background dispatch — verified by live spike, see
ADR-0011) and the dispatch prompt from `tool_input.prompt`. Writes
`<tasks_dir>/<agent_id>.json` with the goal and any `HARD CONSTRAINTS:` section
parsed structurally from the prompt.

Creation is mechanized here, not a remembered manual step (ADR-0004 / Principle
2). This hook cannot block a dispatch and must never crash one: every failure
case logs a warning and exits 0 (fail open).

Only fires for background dispatches (`tool_input.run_in_background == true`).
A foreground `Agent` call blocks until it returns and is never `SendMessage`-
resumed, so creating a record for it is pure overhead with no matching resume
path to protect -- it would only produce empty-constraints records that could
spuriously deny a resume nobody would ever attempt.

Failure cases:
  - not a background dispatch     -> skip silently, exit 0 (not a failure, the common case)
  - no agentId in tool_response   -> log warning, write nothing, exit 0
  - record already exists         -> do not overwrite, log warning, exit 0
"""
import json
import os
import sys
from pathlib import Path

GOAL_MAX = 500
CONSTRAINTS_MARKER = "HARD CONSTRAINTS:"
BULLET_PREFIXES = ("- ", "* ", "• ")


def tasks_dir() -> Path:
    return Path(os.environ.get("AGENT_TASKS_DIR", ".agents/tasks"))


def warn(message: str) -> None:
    print(f"auto-create-task-record: {message}", file=sys.stderr)


def strip_bullet(line: str) -> str:
    text = line.strip()
    for prefix in BULLET_PREFIXES:
        if text.startswith(prefix):
            return text[len(prefix):].strip()
    if text[:1].isdigit() and "." in text[:4]:
        return text.split(".", 1)[1].strip()
    return text


def is_section_marker(line: str) -> bool:
    text = line.strip()
    if ":" not in text:
        return False
    head = text.split(":", 1)[0].strip()
    return bool(head) and head == head.upper() and any(c.isalpha() for c in head)


def parse_constraints(prompt: str) -> list[str]:
    """Extract items under a `HARD CONSTRAINTS:` marker until a blank line or the
    next section marker. Structural extraction, not NLP."""
    lines = prompt.splitlines()
    constraints: list[str] = []
    index = None
    for i, line in enumerate(lines):
        if line.strip().startswith(CONSTRAINTS_MARKER):
            index = i
            break
    if index is None:
        return []

    inline = lines[index].strip()[len(CONSTRAINTS_MARKER):].strip()
    if inline:
        constraints.append(inline)

    for line in lines[index + 1:]:
        if not line.strip():
            break
        if is_section_marker(line):
            break
        item = strip_bullet(line)
        if item:
            constraints.append(item)
    return constraints


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        warn("could not parse stdin JSON")
        sys.exit(0)

    tool_input = data.get("tool_input") or {}
    if not tool_input.get("run_in_background"):
        sys.exit(0)

    tool_response = data.get("tool_response")
    if not isinstance(tool_response, dict):
        warn("no tool_response object; nothing to key on")
        sys.exit(0)

    agent_id = tool_response.get("agentId")
    if not agent_id:
        warn("no agentId in tool_response; cannot create a record")
        sys.exit(0)

    prompt = tool_input.get("prompt") or ""

    record_path = tasks_dir() / f"{agent_id}.json"
    if record_path.exists():
        warn(f"record already exists for {agent_id}; not overwriting")
        sys.exit(0)

    record = {
        "agent_id": agent_id,
        "goal": prompt[:GOAL_MAX],
        "constraints": parse_constraints(prompt),
        "decisions_so_far": [],
        "next_action": None,
        "status": "active",
    }

    record_path.parent.mkdir(parents=True, exist_ok=True)
    record_path.write_text(json.dumps(record, indent=2) + "\n")
    sys.exit(0)


if __name__ == "__main__":
    main()

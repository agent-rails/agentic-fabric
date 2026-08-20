#!/usr/bin/env python3
"""Continuation-record CLI — the read/append/complete side of the mechanism.

Creation is NOT here: records are auto-created by the PostToolUse(Agent) hook
(`auto-create-task-record.py`) at dispatch time (ADR-0011). This CLI owns the
three post-creation operations:

  append-decision <agent_id> <text>   append to decisions_so_far; fail loud
                                      (non-zero) if the record is missing
  read <agent_id>                     print the record JSON, or nothing if
                                      missing; never crashes on a missing record
  complete <agent_id>                 delete the record; no-op if already gone

`read` is the single reader other tooling (the resume-constraints hook) shells
out to, so the on-disk path convention lives in exactly one other place
(the creation hook) and here.
"""
import json
import os
import sys
from pathlib import Path


def tasks_dir() -> Path:
    return Path(os.environ.get("AGENT_TASKS_DIR", ".agents/tasks"))


def record_path(agent_id: str) -> Path:
    return tasks_dir() / f"{agent_id}.json"


def die(message: str) -> None:
    print(f"task-record: {message}", file=sys.stderr)
    sys.exit(1)


def append_decision(agent_id: str, text: str) -> None:
    path = record_path(agent_id)
    if not path.exists():
        die(f"no record for {agent_id}; cannot append to an untracked task")
    record = json.loads(path.read_text())
    record["decisions_so_far"].append(text)
    path.write_text(json.dumps(record, indent=2) + "\n")


def read(agent_id: str) -> None:
    path = record_path(agent_id)
    if not path.exists():
        return
    sys.stdout.write(path.read_text())


def complete(agent_id: str) -> None:
    record_path(agent_id).unlink(missing_ok=True)


def main() -> None:
    args = sys.argv[1:]
    if not args:
        die("usage: task-record.py <append-decision|read|complete> <agent_id> [text]")

    command = args[0]
    if command == "append-decision":
        if len(args) < 3:
            die("usage: task-record.py append-decision <agent_id> <text>")
        append_decision(args[1], args[2])
    elif command == "read":
        if len(args) < 2:
            die("usage: task-record.py read <agent_id>")
        read(args[1])
    elif command == "complete":
        if len(args) < 2:
            die("usage: task-record.py complete <agent_id>")
        complete(args[1])
    else:
        die(f"unknown command: {command}")


if __name__ == "__main__":
    main()

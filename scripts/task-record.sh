#!/usr/bin/env bash
# Continuation-record CLI wrapper — read/append/complete a task record.
# Not a hook: a plain CLI. Passes args through and propagates the exit code
# (append-decision fails loud / non-zero on a missing record).

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
exec python3 "$SCRIPT_DIR/task-record.py" "$@"

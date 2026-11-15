#!/usr/bin/env python3
"""Decide whether a path is part of the enforcement layer the agents must not edit.

Exit 0 and print the resolved path: protected.
Exit 10: not protected.
Exit 11 and print the resolved path: the unlock marker, which is never editable.
Any other exit status is an error, and the caller fails closed.

Protection is decided by file identity (device and inode), not by spelling. The
target is protected when it, or the nearest existing ancestor of a path that does
not exist yet, is a protected directory or a protected file. That holds for every
alias the volume resolves to the same inode: case and Unicode variants, ~, .., //,
symlinks (including a symlinked protected root) and firmlinks, and a hard link to one of
the listed protected files. A hard link to a file inside a protected directory, or to the
unlock marker, needs the Bash tool to create and is not matched.
A folded string comparison is added for protected paths that do not exist yet, since
the Write tool creates missing parent directories and there is no inode to compare.

Built-in protection covers Claude Code's own configuration, installed plugins and
their data, and the agentic-fabric config. The fabric-gates `protected_paths`
setting adds home-relative paths (comma-separated); each is protected as a
directory tree and as a file. A config that cannot be read is an error, so the
caller fails closed.
"""
import os
import sys
import unicodedata

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fabric_config  # noqa: E402

BUILTIN_DIRS = (
    ".claude/scripts",
    ".claude/policies",
    ".claude/agents",
    ".claude/rules",
    ".claude/skills",
    ".claude/plugins",
    ".config/agentic-fabric",
)
PROTECTED_FILES = (
    ".claude/settings.json",
    ".claude/settings.local.json",
    ".claude/gate-decisions.jsonl",
)
UNLOCK_MARKER = ".claude/gate-unlock"
EVALS_SEGMENT = "/evals/review-convergence/"


def fold(name):
    return unicodedata.normalize("NFD", name).casefold()


def identity(path):
    try:
        info = os.stat(path)
    except OSError:
        return None
    return (info.st_dev, info.st_ino)


def is_file_named(target, relative):
    wanted_parent, wanted_name = os.path.split(os.path.join(os.path.expanduser("~"), relative))
    parent = identity(os.path.dirname(target))
    if parent is None or parent != identity(wanted_parent):
        return False
    return fold(os.path.basename(target)) == fold(wanted_name)


def matches_spelling(target, relatives, directory):
    folded = fold(target)
    for home in {os.path.expanduser("~"), os.path.realpath(os.path.expanduser("~"))}:
        for relative in relatives:
            root = fold(os.path.join(home, relative))
            if folded == root or (directory and folded.startswith(root + "/")):
                return True
    return False


def is_under(target, directory_ids):
    path = target
    while True:
        if identity(path) in directory_ids:
            return True
        parent = os.path.dirname(path)
        if parent == path:
            return False
        path = parent


def configured_paths():
    raw = fabric_config.get("fabric-gates", "protected_paths", default="")
    entries = [entry.strip() for entry in raw.split(",") if entry.strip()]
    for entry in entries:
        if os.path.isabs(entry) or ".." in entry.split("/") or entry.startswith("~"):
            raise ValueError(f"protected_paths entries must be relative to your home directory: {entry!r}")
    return tuple(entry.rstrip("/") for entry in entries)


def main():
    home = os.path.expanduser("~")
    PROTECTED_DIRS = BUILTIN_DIRS + configured_paths()
    target = os.path.realpath(os.path.expanduser(sys.argv[1]))
    if is_file_named(target, UNLOCK_MARKER) or matches_spelling(target, (UNLOCK_MARKER,), False):
        print(target)
        return 11
    directory_ids = {identity(os.path.join(home, relative)) for relative in PROTECTED_DIRS} - {None}
    file_ids = {identity(os.path.join(home, relative)) for relative in PROTECTED_FILES} - {None}
    protected = (
        is_under(target, directory_ids)
        or identity(target) in file_ids
        or any(is_file_named(target, relative) for relative in PROTECTED_FILES)
        or matches_spelling(target, PROTECTED_DIRS, True)
        or matches_spelling(target, PROTECTED_FILES, False)
        or EVALS_SEGMENT in fold(target + "/")
    )
    if protected:
        print(target)
        return 0
    return 10


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        sys.exit(2)

#!/usr/bin/env python3
"""PreToolUse(Bash) gate: enforce the `youralias/` prefix on git branch creation.

Reads the PreToolUse hook JSON on stdin. If the Bash command creates a branch
whose name does not start with `youralias/`, emits a deny decision; otherwise emits
nothing and exits 0 (normal permission flow proceeds).

Per-subcommand scoping (via shlex + segment splitting on shell operators) so we
don't false-positive on e.g. `git branch -c old new` (copy) or `git checkout x`.
Fail-open: any parse error → allow (the convention is enforced, not a security
boundary).
"""
import sys
import json
import shlex
import re

REQUIRED_PREFIX = "youralias/"


def deny(name: str, why: str) -> None:
    reason = (
        f'Branch "{name}" must be prefixed "{REQUIRED_PREFIX}" '
        f"(e.g. {REQUIRED_PREFIX}<topic>). The branch alias is \"youralias\" — "
        f'NOT the GitHub handle "your-github-handle". Re-run with an {REQUIRED_PREFIX} name. '
        f"(matched: git {why})"
    )
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)


def flag_value(args, flags):
    """Return the value of the first matching flag (-b name | -b=name)."""
    for i, a in enumerate(args):
        for f in flags:
            if a == f and i + 1 < len(args):
                return args[i + 1]
            if a.startswith(f + "="):
                return a[len(f) + 1:]
    return None


BRANCH_MODIFIERS = {
    "-d", "-D", "--delete", "-m", "-M", "--move", "-c", "-C", "--copy",
    "--list", "-l", "-a", "--all", "-r", "--remotes", "-v", "-vv", "--verbose",
    "--edit-description", "-u", "--set-upstream-to", "--unset-upstream",
    "--show-current", "--contains", "--merged", "--no-merged", "--points-at",
}


def branch_create_name(args):
    """For `git branch ...`: the new-branch name iff this is a creation
    (no delete/move/copy/list/info modifier present). Else None."""
    name = None
    for a in args:
        if a in BRANCH_MODIFIERS or a.startswith(("--set-upstream-to=", "--contains=", "--points-at=")):
            return None
        if not a.startswith("-") and name is None:
            name = a
    return name


GLOBAL_OPTS_WITH_ARG = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path"}


def candidate_for_segment(toks):
    """Given the tokens of one shell segment, return a new-branch name to check,
    scoped by git subcommand, or None."""
    if "git" not in toks:
        return None
    rest = toks[toks.index("git") + 1:]
    # Skip leading global options to find the subcommand.
    sub = None
    k = 0
    while k < len(rest):
        t = rest[k]
        if t in GLOBAL_OPTS_WITH_ARG:
            k += 2
            continue
        if t.startswith("-") or "=" in t and t.startswith("--"):
            k += 1
            continue
        sub = t
        break
    if sub is None:
        return None
    args = rest[k + 1:]

    if sub == "checkout":
        return flag_value(args, ("-b", "-B"))
    if sub == "switch":
        return flag_value(args, ("-c", "-C"))
    if sub == "worktree":
        if args and args[0] == "add":
            return flag_value(args[1:], ("-b", "-B"))
        return None
    if sub == "branch":
        return branch_create_name(args)
    return None


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)
    cmd = (data.get("tool_input") or {}).get("command") or ""
    if "git" not in cmd:
        sys.exit(0)

    # Split on shell control operators so each git invocation is parsed alone.
    for seg in re.split(r"&&|\|\||;|\||\n", cmd):
        try:
            toks = shlex.split(seg)
        except ValueError:
            continue
        if not toks:
            continue
        name = candidate_for_segment(toks)
        if name and not name.startswith(REQUIRED_PREFIX):
            # locate which subcommand for the message
            sub = next((s for s in ("checkout", "switch", "worktree", "branch") if s in toks), "branch")
            deny(name, sub)

    sys.exit(0)


if __name__ == "__main__":
    main()

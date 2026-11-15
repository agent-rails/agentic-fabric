#!/usr/bin/env python3
"""PreToolUse(Bash) gate: enforce the configured prefix on git branch creation.

Reads the PreToolUse hook JSON on stdin. If the Bash command creates a branch
whose name does not start with the fabric-gates `branch_prefix` setting, emits a
deny decision; otherwise emits nothing and exits 0 (normal permission flow
proceeds). The setting is read only once a branch-creating command is found, so
a missing setting blocks branch creation (with the fix) and nothing else.

Per-subcommand scoping (via shlex + segment splitting on shell operators) so we
don't false-positive on e.g. `git branch -c old new` (copy) or `git checkout x`.
Fail-open: any parse error → allow (the convention is enforced, not a security
boundary).
"""
import json
import os
import re
import shlex
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fabric_config  # noqa: E402


def emit_deny(reason: str) -> None:
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)


def deny(name: str, why: str, prefix: str) -> None:
    emit_deny(
        f'Branch "{name}" must be prefixed "{prefix}" (e.g. {prefix}<topic>). '
        f"Re-run with a {prefix} name. (matched: git {why})"
    )


def required_prefix() -> str:
    try:
        return fabric_config.get("fabric-gates", "branch_prefix", required=True)
    except fabric_config.ConfigError as err:
        emit_deny(f"Branch creation is blocked until the branch prefix is set: {err}")


def flag_value(args, flags):
    """Return the value of the first matching flag (-b name | -b=name)."""
    for i, a in enumerate(args):
        for f in flags:
            if a == f and i + 1 < len(args):
                return args[i + 1]
            if a.startswith(f + "="):
                return a[len(f) + 1:]
            if len(f) == 2 and a.startswith(f) and len(a) > 2 and not a.startswith("--"):
                return a[2:]
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


WORKTREE_OPTS_WITH_ARG = {"--reason"}


def implicit_worktree_branch(args):
    """`git worktree add <path>` with no commit-ish creates a branch named after the path."""
    if any(a in ("--detach", "-d") for a in args):
        return None
    positional, skip = [], False
    for a in args:
        if skip:
            skip = False
            continue
        if a in WORKTREE_OPTS_WITH_ARG:
            skip = True
            continue
        if not a.startswith("-"):
            positional.append(a)
    if len(positional) != 1:
        return None
    return positional[0].rstrip("/").rsplit("/", 1)[-1] or None


HEREDOC = re.compile(r"<<-?\s*['\"]?([A-Za-z_][A-Za-z0-9_]*)['\"]?")


def heredoc_operator(line):
    """The heredoc operator's match when `<<` is a real shell operator on this line, not text inside quotes or a comment.

    When the line cannot be tokenized (an unclosed quote, as in
    `git commit -m "$(cat <<'EOF'`), the first textual match is used, as before.
    Otherwise the match must carry the same delimiter as a real `<<` token.
    """
    matches = list(HEREDOC.finditer(line))
    if not matches:
        return None
    lexer = shlex.shlex(line, posix=False, punctuation_chars=True)
    lexer.whitespace_split = True
    try:
        tokens = list(lexer)
    except ValueError:
        return matches[0]
    delimiters = set()
    for index, token in enumerate(tokens):
        if token.startswith("<<") and not token.startswith("<<<"):
            rest = token.lstrip("<-")
            if not rest and index + 1 < len(tokens):
                rest = tokens[index + 1]
            delimiters.add(rest.strip("'\""))
    real = [match for match in matches if match.group(1) in delimiters]
    return real[-1] if real else None


def strip_heredocs(cmd):
    """Drop heredoc bodies so prose inside them is not parsed as commands.

    Only a `<<` the shell would treat as an operator starts a heredoc. A marker
    inside quotes or a comment does not, so the lines after it are still checked.
    """
    kept, closing = [], None
    for line in cmd.split("\n"):
        if closing is not None:
            if line.strip() == closing:
                closing = None
            continue
        match = heredoc_operator(line)
        if match:
            closing = match.group(1)
            line = line[: match.start()]
        kept.append(line)
    return "\n".join(kept)


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
        return flag_value(args, ("-b", "-B", "--orphan"))
    if sub == "switch":
        return flag_value(args, ("-c", "-C", "--create", "--force-create", "--orphan"))
    if sub == "worktree":
        if args and args[0] == "add":
            return flag_value(args[1:], ("-b", "-B")) or implicit_worktree_branch(args[1:])
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
    for seg in re.split(r"&&|\|\||;|\||\n", strip_heredocs(cmd)):
        try:
            toks = shlex.split(seg)
        except ValueError:
            continue
        if not toks:
            continue
        name = candidate_for_segment(toks)
        if not name:
            continue
        prefix = required_prefix()
        if not name.startswith(prefix):
            sub = next((s for s in ("checkout", "switch", "worktree", "branch") if s in toks), "branch")
            deny(name, sub, prefix)

    sys.exit(0)


if __name__ == "__main__":
    main()

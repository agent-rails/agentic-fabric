#!/usr/bin/env python3
"""Decide whether a Bash command is a plain `gh pr create|new|merge` the PR gates can check.

The PR gates do not try to understand every shell construct. A command that
mentions one of these subcommands is checked only when it is exactly one plain
invocation: no `&&`, `;`, pipes, subshells, `$(...)` or backticks, heredocs,
environment prefixes, `cd`, or wrappers such as `bash -c`, `eval`, `env`,
`xargs` or an interpreter. Anything else that mentions them is denied with a
request to run the command on its own. A mention inside the arguments of an
ordinary program (a commit message, an `echo`) is data and is ignored.

Usage: pr_command.py create|merge  (command text on stdin)
Prints one JSON object:
  {"action": "ignore"}                                   not a create/merge command
  {"action": "deny", "code": ..., "reason": ...}         refuse, with the reason
  {"action": "check", "draft": "yes"|"no"|"false"}        create: what the flags say
  {"action": "check", "target": str|null, "repo": str|null}   merge: which PR
Any other outcome (an exception, exit status other than 0) must be treated as a
deny by the caller.
"""

from __future__ import annotations

import json
import os
import re
import shlex
import sys

TRIGGERS = {
    "create": re.compile(r"\bpr\s+(?:create|new)\b"),
    "merge": re.compile(r"\bpr\s+merge\b"),
}
SUBCOMMANDS = {"create": ("create", "new"), "merge": ("merge",)}
GH = re.compile(r"\bgh\b")
SEPARATORS = {"&&", "||", ";", "|", "&", "|&", ";;", "(", ")", "\n"}
REDIRECTS = {">", ">>", ">&", "&>", "<", ">|"}
WRAPPERS = {
    "bash", "sh", "zsh", "dash", "ksh", "fish", "eval", "su", "ssh", "script", "tmux", "screen", "watch",
    "python", "python3", "node", "perl", "ruby", "osascript", "source", ".", "expect", "parallel",
    "awk", "gawk", "mawk", "nawk",
}
ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
VARIABLE_SUBCOMMAND = re.compile(r"\bpr\s+\$")
GH_API_OR_ALIAS = re.compile(r"\bgh\s+(?:api|alias)\b")
SUBSTITUTION = re.compile(r"\$\(|`|<\(|>\(")

CREATE_VALUE = {"-t", "--title", "-b", "--body", "-F", "--body-file", "-B", "--base", "-H", "--head", "-a", "--assignee",
                "-l", "--label", "-m", "--milestone", "-p", "--project", "-r", "--reviewer", "-T", "--template",
                "--recover", "-R", "--repo"}
CREATE_BOOL = {"-d", "--draft", "-f", "--fill", "--fill-first", "--fill-verbose", "-w", "--web", "--dry-run",
               "--no-maintainer-edit", "-e", "--editor"}
MERGE_VALUE = {"-t", "--subject", "-b", "--body", "-F", "--body-file", "-A", "--author-email", "--match-head-commit",
               "-R", "--repo"}
MERGE_BOOL = {"--admin", "--auto", "--disable-auto", "-d", "--delete-branch", "-m", "--merge", "-r", "--rebase",
              "-s", "--squash"}
MAX_COMMAND = 20000
PLAIN = "Run it on its own as one plain command (no &&, ;, pipes, subshells, heredocs, env prefixes, cd or wrappers)."


class Deny(Exception):
    def __init__(self, code: str, reason: str):
        super().__init__(reason)
        self.code, self.reason = code, reason


def tokenize(command: str) -> list[str]:
    lexer = shlex.shlex(command.replace("\\\n", " ").replace("\n", " ; "), posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    try:
        return list(lexer)
    except ValueError as err:
        raise Deny("unparseable", f"the command could not be parsed ({err}). {PLAIN}") from err


def simple_commands(tokens: list[str]) -> list[list[str]]:
    commands, current = [], []
    for token in tokens:
        if token in SEPARATORS:
            if current:
                commands.append(current)
            current = []
            if token in ("(", ")"):
                commands.append(["("])
            continue
        current.append(token)
    if current:
        commands.append(current)
    return commands


def strip_redirects(argv: list[str]) -> list[str]:
    kept, skip = [], False
    for index, token in enumerate(argv):
        if skip:
            skip = False
            continue
        if token in REDIRECTS:
            skip = True
            if kept and kept[-1].isdigit() and index > 0 and argv[index - 1] == kept[-1]:
                kept.pop()
            continue
        if token.startswith("<<"):
            raise Deny("heredoc", f"the command uses a heredoc. {PLAIN}")
        kept.append(token)
    return kept


def parse_flags(args: list[str], value_flags: set[str], bool_flags: set[str]) -> tuple[dict[str, list[str]], list[str]]:
    flags: dict[str, list[str]] = {}
    positional: list[str] = []
    index = 0
    while index < len(args):
        token = args[index]
        index += 1
        if token == "--":
            positional.extend(args[index:])
            break
        if token.startswith("--"):
            name, has_value, value = token.partition("=")
            if name in value_flags:
                if not has_value:
                    if index >= len(args):
                        raise Deny("missing-value", f"{name} needs a value. {PLAIN}")
                    value = args[index]
                    index += 1
                flags.setdefault(name, []).append(value)
            elif name in bool_flags:
                flags.setdefault(name, []).append(value if has_value else "true")
            else:
                raise Deny("unknown-flag", f"the gate does not know the flag {name}, so it cannot check this command. {PLAIN}")
            continue
        if token.startswith("-") and len(token) > 1:
            letters = token[1:]
            for position, letter in enumerate(letters):
                name = "-" + letter
                if name in value_flags:
                    value = letters[position + 1 :]
                    if not value:
                        if index >= len(args):
                            raise Deny("missing-value", f"{name} needs a value. {PLAIN}")
                        value = args[index]
                        index += 1
                    flags.setdefault(name, []).append(value)
                    break
                if name in bool_flags:
                    flags.setdefault(name, []).append("true")
                    continue
                raise Deny("unknown-flag", f"the gate does not know the flag {name}, so it cannot check this command. {PLAIN}")
            continue
        positional.append(token)
    return flags, positional


API_TARGETS = {"create": re.compile(r"/pulls/?$"), "merge": re.compile(r"/pulls/\d+/merge/?$")}
API_WRITE_FLAGS = {"-f", "-F", "--field", "--raw-field", "--input"}
TRUE_VALUES = {"true", "t", "1"}
FALSE_VALUES = {"false", "f", "0"}


def is_api_write(argv: list[str], kind: str) -> bool:
    if len(argv) < 2 or argv[1] != "api":
        return False
    if not any(API_TARGETS[kind].search(token) for token in argv[2:]):
        return False
    methods = [argv[i + 1].upper() for i, token in enumerate(argv[:-1]) if token in ("-X", "--method")]
    methods += [token.split("=", 1)[1].upper() for token in argv if token.startswith("--method=")]
    writes = any(token in API_WRITE_FLAGS or token.split("=", 1)[0] in API_WRITE_FLAGS for token in argv)
    return writes or any(method in ("POST", "PUT", "PATCH") for method in methods)


def mentions(argv: list[str], kind: str) -> bool:
    return bool(TRIGGERS[kind].search(" ".join(argv)))


def flatten(command: str) -> str:
    """The command with quotes and backslashes removed, so `g''h pr cre\\ate` reads as `gh pr create`."""
    return re.sub(r"[\\'\"]", "", command)


def is_program_token(token: str) -> bool:
    return os.path.basename(token) == "gh" or token.startswith("$")


def runs_subcommand(argv: list[str], kind: str) -> bool:
    """True when argv holds gh (or a variable) followed later by `pr <sub>` as separate words. One pass."""
    seen_program = False
    for index, token in enumerate(argv[:-1]):
        if is_program_token(token):
            seen_program = True
        nxt = argv[index + 1]
        if seen_program and token == "pr" and (nxt in SUBCOMMANDS[kind] or nxt.startswith("$")):
            return True
    return False


EXPANSION_CHARS = set("$`{}")
EXPANSION_SPANS = re.compile(r"\$\{[^}]*\}|\$\([^)]*\)|`[^`]*`")


def skeleton(word: str) -> str:
    """A word with expansions and quoting removed: `g${u}h` and `{gh,}` both read as `gh`."""
    return re.sub(r"[\\'\"${}(),`]", "", EXPANSION_SPANS.sub("", word))


def expands_gh_words(argv: list[str]) -> bool:
    """True when gh, `pr` or the pr subcommand is built by shell expansion, so the gate cannot read it."""
    if not argv or os.path.basename(skeleton(argv[0])) != "gh":
        return False
    words = argv[:2]
    if len(argv) >= 3 and skeleton(argv[1]) == "pr":
        words = argv[:3]
    return any(EXPANSION_CHARS & set(word) for word in words)


def find_invocation(command: str, kind: str) -> list[str] | None:
    """Return the argv after `gh pr <sub>` for the single plain invocation, or None when the command is unrelated.

    Any command that mentions the subcommand but is not exactly one plain
    invocation is denied: the gate never guesses what a shell will run.
    """
    flat = flatten(command)
    mentioned = bool(TRIGGERS[kind].search(flat) or (GH.search(flat) and VARIABLE_SUBCOMMAND.search(flat)))
    if EXPANSION_CHARS & set(command) and re.search(r"g\S*h", command):
        for argv in simple_commands(tokenize(command)):
            if expands_gh_words(argv):
                raise Deny("expansion", f"gh, 'pr' or the pr subcommand is built by shell expansion. {PLAIN}")
    if not (mentioned or GH_API_OR_ALIAS.search(flat)):
        return None
    if mentioned and len(command) > MAX_COMMAND:
        raise Deny("too-long", f"the command is longer than {MAX_COMMAND} characters. {PLAIN}")
    commands = simple_commands(tokenize(command))
    executes, plain = False, None
    for argv in commands:
        if not argv:
            continue
        program = os.path.basename(argv[0])
        if program == "gh" and len(argv) >= 2 and argv[1] == "api" and is_api_write(argv, kind):
            raise Deny("api-write", f"pull requests must be created or merged with 'gh pr', not 'gh api'. {PLAIN}")
        if program == "gh" and len(argv) >= 2 and argv[1] == "alias" and mentions(argv, kind):
            raise Deny("gh-alias", f"a gh alias must not expand to 'pr {SUBCOMMANDS[kind][0]}'. {PLAIN}")
        if runs_subcommand(argv, kind):
            executes = True
            if program == "gh" and argv[1:2] == ["pr"] and argv[2] in SUBCOMMANDS[kind] and not any("$" in t for t in argv):
                plain = argv
            continue
        if program == "git" and any(t.startswith("alias.") and "=!" in t for t in argv) and mentions(argv, kind):
            raise Deny("git-alias", f"a git alias must not run 'gh pr {SUBCOMMANDS[kind][0]}'. {PLAIN}")
        if program in WRAPPERS and mentions(argv, kind):
            raise Deny("wrapped", f"the command runs gh through a shell, wrapper or interpreter. {PLAIN}")
    if not mentioned:
        return None
    if SUBSTITUTION.search(command):
        raise Deny("substitution", f"the command uses command or process substitution. {PLAIN}")
    if "<<" in command:
        raise Deny("heredoc", f"the command uses a heredoc. {PLAIN}")
    if not executes:
        return None
    if plain is None or len(commands) != 1:
        raise Deny("not-plain", f"the command is not one plain 'gh pr {SUBCOMMANDS[kind][0]}' invocation. {PLAIN}")
    if ASSIGNMENT.match(command.strip()):
        raise Deny("env-prefix", f"the command sets environment variables before gh. {PLAIN}")
    return strip_redirects(plain)[3:]


def decide(command: str, kind: str) -> dict:
    try:
        args = find_invocation(command, kind)
        if args is None:
            return {"action": "ignore"}
        if kind == "create":
            flags, positional = parse_flags(args, CREATE_VALUE, CREATE_BOOL)
            if positional:
                raise Deny("unexpected-argument", f"gh pr create takes no positional arguments, got {positional[0]!r}. {PLAIN}")
            values = [value.lower() for value in flags.get("--draft", []) + flags.get("-d", [])]
            if any(value in FALSE_VALUES for value in values):
                return {"action": "check", "draft": "false"}
            if any(value not in TRUE_VALUES for value in values):
                raise Deny("draft-value", f"--draft takes no value other than true. {PLAIN}")
            return {"action": "check", "draft": "yes" if values else "no"}
        flags, positional = parse_flags(args, MERGE_VALUE, MERGE_BOOL)
        if len(positional) > 1:
            raise Deny("ambiguous-target", f"the target is ambiguous: the merge names more than one PR ({', '.join(positional)}). {PLAIN}")
        repos = flags.get("--repo", []) + flags.get("-R", [])
        if len(repos) > 1:
            raise Deny("ambiguous-repo", f"the repository is ambiguous: the merge names it more than once. {PLAIN}")
        return {"action": "check", "target": positional[0] if positional else None, "repo": repos[0] if repos else None}
    except Deny as deny:
        return {"action": "deny", "code": deny.code, "reason": deny.reason}


if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in TRIGGERS:
        print("usage: pr_command.py create|merge < command", file=sys.stderr)
        sys.exit(2)
    print(json.dumps(decide(sys.stdin.read(), sys.argv[1])))

import os
import re
import shlex
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple, Union

HEREDOC_MARKER = re.compile(r"<<-?[ \t]*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")
SEPARATOR_CHARS = set("();<>|&")
WRAPPERS = {"command", "env", "exec", "time", "nohup"}
SHELLS = {"bash", "sh", "zsh"}
GH_GLOBAL_VALUE_FLAGS = {"-R", "--repo", "--hostname"}
TRUE_VALUES = {"1", "t", "T", "TRUE", "true", "True"}
MAX_NESTING = 3


class ParseError(Exception):
    pass


@dataclass
class Invocation:
    path: Tuple[str, ...]
    flags: Dict[str, Union[str, bool]] = field(default_factory=dict)
    positionals: List[str] = field(default_factory=list)

    def flag(self, *names: str) -> Union[str, bool, None]:
        for name in names:
            if name in self.flags:
                return self.flags[name]
        return None


def strip_heredocs(cmd: str) -> str:
    out = []
    pending = []
    for line in cmd.split("\n"):
        if pending:
            if line.strip() == pending[0]:
                pending.pop(0)
            continue
        tags = [m.group(2) for m in HEREDOC_MARKER.finditer(line)]
        out.append(HEREDOC_MARKER.sub("", line))
        pending.extend(tags)
    return "\n".join(out)


def newlines_to_separators(cmd: str) -> str:
    out = []
    quote = None
    escaped = False
    for ch in cmd:
        if escaped:
            out.append(ch)
            escaped = False
            continue
        if ch == "\\" and quote != "'":
            out.append(ch)
            escaped = True
            continue
        if quote:
            if ch == quote:
                quote = None
            out.append(ch)
            continue
        if ch in "'\"":
            quote = ch
            out.append(ch)
            continue
        out.append(" ; " if ch == "\n" else ch)
    return "".join(out)


def tokenize(cmd: str) -> List[str]:
    lexer = shlex.shlex(newlines_to_separators(cmd), posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    try:
        return list(lexer)
    except ValueError as e:
        raise ParseError(str(e))


def split_segments(tokens: List[str]) -> List[List[str]]:
    segments = [[]]
    for tok in tokens:
        if tok and set(tok) <= SEPARATOR_CHARS:
            segments.append([])
        else:
            segments[-1].append(tok)
    return [s for s in segments if s]


def shell_script_arg(tokens: List[str]) -> Optional[str]:
    if os.path.basename(tokens[0]) not in SHELLS:
        return None
    for i, tok in enumerate(tokens[1:], start=1):
        if tok.startswith("-") and not tok.startswith("--") and tok.endswith("c"):
            return tokens[i + 1] if i + 1 < len(tokens) else None
    return None


def gh_tokens(segment: List[str]) -> Optional[List[str]]:
    i = 0
    while i < len(segment):
        tok = segment[i]
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", tok) or tok in WRAPPERS:
            i += 1
            continue
        if os.path.basename(tok) == "gh":
            return segment[i + 1:]
        return None
    return None


def parse_flags(tokens: List[str], value_flags: set) -> Tuple[Dict[str, Union[str, bool]], List[str]]:
    flags = {}
    positionals = []
    i = 0
    while i < len(tokens):
        tok = tokens[i]
        if tok == "--":
            positionals.extend(tokens[i + 1:])
            break
        if tok.startswith("--"):
            name, eq, value = tok.partition("=")
            if eq:
                flags[name[2:]] = value
            elif name in value_flags and i + 1 < len(tokens):
                flags[name[2:]] = tokens[i + 1]
                i += 1
            else:
                flags[name[2:]] = True
        elif tok.startswith("-") and len(tok) > 1:
            letters = tok[1:]
            for j, letter in enumerate(letters):
                if f"-{letter}" in value_flags:
                    rest = letters[j + 1:]
                    if rest:
                        flags[letter] = rest
                    elif i + 1 < len(tokens):
                        flags[letter] = tokens[i + 1]
                        i += 1
                    break
                flags[letter] = True
        else:
            positionals.append(tok)
        i += 1
    return flags, positionals


PR_VALUE_FLAGS = {
    "-R", "--repo", "-t", "--title", "-b", "--body", "-F", "--body-file",
    "-B", "--base", "-H", "--head", "-l", "--label", "-a", "--assignee",
    "-m", "--milestone", "-p", "--project", "-r", "--reviewer", "--template",
    "-A", "--author-email", "--match-head-commit", "-T", "--subject",
}
API_VALUE_FLAGS = {
    "-X", "--method", "-f", "--raw-field", "-F", "--field", "-H", "--header",
    "--input", "--jq", "-q", "-t", "--template", "--cache", "--hostname",
}


def invocation_from(args: List[str]) -> Optional[Invocation]:
    i = 0
    flags = {}
    while i < len(args) and args[i].startswith("-"):
        name, eq, value = args[i].partition("=")
        if eq:
            flags[name.lstrip("-")] = value
        elif name in GH_GLOBAL_VALUE_FLAGS and i + 1 < len(args):
            flags[name.lstrip("-")] = args[i + 1]
            i += 1
        i += 1
    args = args[i:]
    if not args:
        return None
    if args[0] == "api":
        parsed, positionals = parse_flags(args[1:], API_VALUE_FLAGS)
        inv = Invocation(("api",), parsed, positionals)
    elif len(args) >= 2 and args[0] == "pr":
        parsed, positionals = parse_flags(args[2:], PR_VALUE_FLAGS)
        inv = Invocation(("pr", args[1]), parsed, positionals)
    else:
        return None
    for k, v in flags.items():
        inv.flags.setdefault(k, v)
    return inv


def gh_invocations(cmd: str, depth: int = 0) -> List[Invocation]:
    if depth > MAX_NESTING:
        raise ParseError("shell nesting too deep to inspect")
    found = []
    for segment in split_segments(tokenize(strip_heredocs(cmd))):
        script = shell_script_arg(segment)
        if script is not None:
            found.extend(gh_invocations(script, depth + 1))
            continue
        args = gh_tokens(segment)
        if args is None:
            continue
        inv = invocation_from(args)
        if inv is not None:
            found.append(inv)
    return found


def is_true(value: Union[str, bool, None]) -> bool:
    return value is True or value in TRUE_VALUES


def api_method(inv: Invocation) -> str:
    method = inv.flag("X", "method")
    if method:
        return method.upper()
    if inv.flag("f", "raw-field", "F", "field", "input"):
        return "POST"
    return "GET"


def api_fields(inv: Invocation) -> Dict[str, str]:
    fields = {}
    for key in ("f", "raw-field", "F", "field"):
        value = inv.flags.get(key)
        if isinstance(value, str) and "=" in value:
            name, _, val = value.partition("=")
            fields[name] = val
    return fields

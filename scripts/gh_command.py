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
    env: Dict[str, str] = field(default_factory=dict)

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
            if ch == "\n":
                out.pop()
            else:
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
    lexer.commenters = ""
    try:
        return list(lexer)
    except ValueError as e:
        raise ParseError(str(e))


def split_segments(tokens: List[str]) -> List[List[str]]:
    segments = [[]]
    in_comment = False
    for tok in tokens:
        if tok and set(tok) <= SEPARATOR_CHARS:
            segments.append([])
            in_comment = False
        elif in_comment or tok.startswith("#"):
            in_comment = True
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


def gh_tokens(segment: List[str]) -> Optional[Tuple[List[str], Dict[str, str]]]:
    env = {}
    i = 0
    while i < len(segment):
        tok = segment[i]
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", tok):
            name, _, value = tok.partition("=")
            env[name] = value
            i += 1
            continue
        if tok in WRAPPERS:
            i += 1
            continue
        if os.path.basename(tok) == "gh":
            return segment[i + 1:], env
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
        elif tok.startswith("-") and len(tok) > 2 and tok[2] == "=":
            flags[tok[1]] = tok[3:]
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
PR_ALIASES = {"new": "create"}
API_VALUE_FLAGS = {
    "-X", "--method", "-f", "--raw-field", "-F", "--field", "-H", "--header",
    "--input", "--jq", "-q", "-t", "--template", "--cache", "--hostname",
}


def leading_flags(args: List[str]) -> Tuple[Dict[str, str], List[str]]:
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
    return flags, args[i:]


def invocation_from(args: List[str]) -> Optional[Invocation]:
    flags, args = leading_flags(args)
    if not args:
        return None
    if args[0] == "api":
        parsed, positionals = parse_flags(args[1:], API_VALUE_FLAGS)
        inv = Invocation(("api",), parsed, positionals)
    elif args[0] == "pr":
        pr_flags, rest = leading_flags(args[1:])
        if not rest:
            return None
        flags.update(pr_flags)
        sub = PR_ALIASES.get(rest[0], rest[0])
        parsed, positionals = parse_flags(rest[1:], PR_VALUE_FLAGS)
        inv = Invocation(("pr", sub), parsed, positionals)
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
        parsed = gh_tokens(segment)
        if parsed is None:
            continue
        args, env = parsed
        inv = invocation_from(args)
        if inv is not None:
            inv.env = env
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


def api_endpoint(inv: Invocation) -> str:
    endpoint = inv.positionals[0] if inv.positionals else ""
    endpoint = re.sub(r"^https?://[^/]+", "", endpoint).split("?", 1)[0]
    return re.sub(r"/{2,}", "/", endpoint)


def api_reads_from_file(inv: Invocation) -> bool:
    if inv.flag("input"):
        return True
    return any(
        isinstance(v, str) and "=@" in v for k, v in inv.flags.items() if k in ("F", "field")
    )


def text_mentions(cmd: str, subcommands: str) -> int:
    pattern = rf"gh\s+pr\s+(?:-\S+\s+\S+\s+)*(?:{subcommands})\b"
    return len(re.findall(pattern, strip_heredocs(cmd)))

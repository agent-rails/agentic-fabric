#!/usr/bin/env python3
"""Refuse to publish text that identifies a person, a machine, an employer or a private repository.

Scans what git will actually publish, not the working directory: the blobs,
paths and modes of a tree ID, and the identities and messages of commits and
tags. Text is NFKC-normalised and stripped of format characters first, so a
zero-width space cannot split a match.

Rules are structural (repository references, PR numbers, emails, hostnames,
home paths, Slack IDs, private addresses, credential shapes). Names that only
a person knows are private (a real name, a handle, an employer) come from an
optional denylist file that never leaves the owner's machine.

A line in a file under a tests/ directory may carry the fixture marker
(FIXTURE_MARKER below) to
exempt that one line from the structural rules. The marker never exempts a
credential shape or a denylist entry, and anywhere else it is itself a finding.

Threat model: an accidental leak by the owner. Encoded or deliberately split
content is out of scope.

Usage:
  leak-scan.py tree <tree-ish> [--repo DIR] [--denylist FILE] [--identity EMAIL ...]
  leak-scan.py commits <rev-range> [--repo DIR] [--denylist FILE] [--identity EMAIL ...]
  leak-scan.py tags [--repo DIR] [--denylist FILE] [--identity EMAIL ...]
  leak-scan.py text FILE [--denylist FILE] [--identity EMAIL ...]
Exit 0: clean. Exit 1: findings, printed as location: rule. Exit 2: usage or git error.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import unicodedata
from dataclasses import dataclass
from pathlib import Path

FIXTURE_MARKER = "leak-scan: " + "fixture"
FIXTURE_DIR = "tests/"
EXAMPLE_DOMAINS = ("example.com", "example.org", "example.net")
SYMLINK_MODE, SUBMODULE_MODE = "120000", "160000"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
PNG_TEXT_CHUNKS = (b"tEXt", b"iTXt", b"zTXt", b"eXIf")

STRUCTURAL = (
    ("repo-reference", re.compile(r"(?<![\w/.-])[A-Za-z0-9][\w.-]*/[\w.-]+#\d+\b")),
    ("bare-repo-reference", re.compile(r"(?<![\w/.#-])[A-Za-z][\w.-]*-[\w.-]*#\d+\b")),
    ("pr-number", re.compile(r"\b(?:PR|pull request|issue)\s*#?\d+\b|#\d+\s+cycle", re.IGNORECASE)),
    ("pull-or-issue-link", re.compile(r"/(?:pull|issues)/\d+")),
    ("hostname", re.compile(r"\b[\w-]+\.(?:local|internal|corp|lan)\b(?![.\w-])|\b[\w-]+\.ts\.net\b", re.IGNORECASE)),
    ("home-path", re.compile(r"(?:/Users|/home)/(?!you\b|youruser\b)[\w.-]+|[A-Za-z]:\\Users\\(?!you\b)[\w.-]+")),
    ("temp-path", re.compile(r"/private/(?:tmp|var)/[\w.-]+|/var/folders/[\w.-]+")),
    ("home-relative-path", re.compile(r"(?:~|\$HOME|\$\{HOME\})/(?!\.)[\w-]+")),
    ("home-path-slug", re.compile(r"-Users-\w+")),
    ("slack-id", re.compile(r"\b[UCDWG]0[A-Z0-9]{7,10}\b")),
    ("private-address", re.compile(r"\b(?:10\.\d{1,3}|192\.168|172\.(?:1[6-9]|2\d|3[01]))\.\d{1,3}\.\d{1,3}\b")),
)
CREDENTIAL = (
    ("private-key", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("github-token", re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{10,}|github_pat_\w{10,})")),
    ("openai-style-key", re.compile(r"\bsk-[A-Za-z0-9_-]{12,}")),
    ("slack-token", re.compile(r"\bxox[abpr]-[A-Za-z0-9-]{10,}")),
    ("aws-access-key", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("aws-account-arn", re.compile(r"arn:aws:[\w-]*:[\w-]*:\d{12}:")),
)
EMAIL = re.compile(r"[\w.+-]+@[\w-]+(?:\.[\w-]+)*\.[A-Za-z]{2,}\b")
GITATTRIBUTES_DANGER = re.compile(r"\b(?:filter|export-subst|export-ignore)\b")


@dataclass(frozen=True)
class Finding:
    location: str
    rule: str

    def __str__(self) -> str:
        return f"{self.location}: {self.rule}"


class GitError(Exception):
    pass


def normalise(text: str) -> str:
    folded = unicodedata.normalize("NFKC", text)
    return "".join(c for c in folded if unicodedata.category(c) != "Cf")


def load_denylist(path: Path | None) -> list[str]:
    if path is None:
        return []
    entries = [normalise(line.strip()).casefold() for line in path.read_text().splitlines()]
    return [entry for entry in entries if entry and not entry.startswith("#")]


def _allowed_tokens(identities: frozenset[str]) -> list[str]:
    tokens = set(identities)
    for identity in identities:
        local = identity.split("@", 1)[0]
        tokens.add(local.split("+", 1)[-1])
    return sorted(tokens, key=len, reverse=True)


def _email_allowed(email: str, identities: frozenset[str]) -> bool:
    lowered = email.casefold()
    return lowered in identities or lowered.rsplit("@", 1)[-1] in EXAMPLE_DOMAINS


def scan_text(text: str, where: str, denylist: list[str], identities: frozenset[str]) -> list[Finding]:
    findings: list[Finding] = []
    normalised_where = "/" + where.replace("\\", "/")
    in_fixtures = "/" + FIXTURE_DIR in normalised_where
    for number, raw in enumerate(text.splitlines() or [text], start=1):
        line = normalise(raw)
        location = f"{where}:{number}"
        exempt = FIXTURE_MARKER in line and in_fixtures
        if FIXTURE_MARKER in line and not in_fixtures:
            findings.append(Finding(location, "fixture-marker-outside-fixtures"))
        folded = line.casefold()
        for token in _allowed_tokens(identities):
            folded = folded.replace(token, " ")
        findings.extend(Finding(location, "denylist") for entry in denylist if entry in folded)
        findings.extend(Finding(location, rule) for rule, pattern in CREDENTIAL if pattern.search(line))
        if exempt:
            continue
        findings.extend(Finding(location, rule) for rule, pattern in STRUCTURAL if pattern.search(line))
        if any(not _email_allowed(match, identities) for match in EMAIL.findall(line)):
            findings.append(Finding(location, "email"))
    return findings


def _git(repo: Path, *args: str) -> bytes:
    result = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, check=False)
    if result.returncode != 0:
        raise GitError(f"git {' '.join(args)}: {result.stderr.decode(errors='replace').strip()}")
    return result.stdout


def _png_has_text(blob: bytes) -> bool:
    position = len(PNG_SIGNATURE)
    while position + 8 <= len(blob):
        length = int.from_bytes(blob[position : position + 4], "big")
        if blob[position + 4 : position + 8] in PNG_TEXT_CHUNKS:
            return True
        position += 12 + length
    return False


def scan_blob(blob: bytes, path: str, denylist: list[str], identities: frozenset[str]) -> list[Finding]:
    if blob.startswith(PNG_SIGNATURE):
        return [Finding(path, "png-text-chunk")] if _png_has_text(blob) else []
    if b"\x00" in blob:
        return [Finding(path, "binary-file")]
    try:
        text = blob.decode("utf-8")
    except UnicodeDecodeError:
        return [Finding(path, "not-utf8")]
    findings = scan_text(text, path, denylist, identities)
    if path.rsplit("/", 1)[-1] == ".gitattributes":
        findings.extend(
            Finding(f"{path}:{number}", "gitattributes-filter")
            for number, line in enumerate(text.splitlines(), start=1)
            if GITATTRIBUTES_DANGER.search(line)
        )
    return findings


def scan_tree(repo: Path, tree: str, denylist: list[str], identities: frozenset[str]) -> list[Finding]:
    findings: list[Finding] = []
    listing = _git(repo, "ls-tree", "-r", "-z", "--full-tree", tree)
    for entry in filter(None, listing.split(b"\x00")):
        meta, path_bytes = entry.split(b"\t", 1)
        mode, kind, sha = meta.decode().split()
        path = path_bytes.decode("utf-8", errors="replace")
        findings.extend(Finding(f"path {path}", f.rule) for f in scan_text(path, "path", denylist, identities))
        if mode == SYMLINK_MODE:
            findings.append(Finding(path, "symlink"))
            continue
        if mode == SUBMODULE_MODE or kind != "blob":
            findings.append(Finding(path, "submodule"))
            continue
        findings.extend(scan_blob(_git(repo, "cat-file", "blob", sha), path, denylist, identities))
    return findings


def scan_commits(repo: Path, rev_range: str, denylist: list[str], identities: frozenset[str]) -> list[Finding]:
    findings: list[Finding] = []
    log = _git(repo, "log", "--format=%H%x00%an%x00%ae%x00%cn%x00%ce%x00%B%x1e", rev_range).decode("utf-8", errors="replace")
    for record in filter(str.strip, log.split("\x1e")):
        sha, author, author_email, committer, committer_email, message = record.strip("\n").split("\x00", 5)
        where = f"commit {sha[:12]}"
        for role, email in (("author", author_email), ("committer", committer_email)):
            if email.casefold() not in identities:
                findings.append(Finding(where, f"{role}-identity-not-allowed"))
        findings.extend(Finding(where, f.rule) for f in scan_text(f"{author}\n{committer}", "identity", denylist, identities))
        findings.extend(Finding(f"{where} message", f.rule) for f in scan_text(message, "message", denylist, identities))
    return findings


def scan_tags(repo: Path, denylist: list[str], identities: frozenset[str]) -> list[Finding]:
    findings: list[Finding] = []
    refs = _git(repo, "for-each-ref", "refs/tags", "--format=%(refname:short)%00%(objecttype)%00%(taggeremail:trim)%00%(contents)%1e")
    for record in filter(str.strip, refs.decode("utf-8", errors="replace").split("\x1e")):
        name, kind, email, contents = record.strip("\n").split("\x00", 3)
        where = f"tag {name}"
        findings.extend(Finding(where, f.rule) for f in scan_text(name, "name", denylist, identities))
        if kind == "tag":
            if email.casefold() not in identities:
                findings.append(Finding(where, "tagger-identity-not-allowed"))
            findings.extend(Finding(f"{where} message", f.rule) for f in scan_text(contents, "message", denylist, identities))
    return findings


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("mode", choices=("tree", "commits", "tags", "text"))
    parser.add_argument("target", nargs="?")
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--denylist", type=Path)
    parser.add_argument("--identity", action="append", default=[])
    args = parser.parse_args(argv)
    if args.mode != "tags" and not args.target:
        parser.error(f"{args.mode} needs a target")
    denylist = load_denylist(args.denylist)
    identities = frozenset(identity.casefold() for identity in args.identity)
    try:
        if args.mode == "tree":
            findings = scan_tree(args.repo, args.target, denylist, identities)
        elif args.mode == "commits":
            findings = scan_commits(args.repo, args.target, denylist, identities)
        elif args.mode == "tags":
            findings = scan_tags(args.repo, denylist, identities)
        else:
            findings = scan_blob(Path(args.target).read_bytes(), args.target, denylist, identities)
    except (GitError, OSError) as err:
        print(f"leak-scan: {err}", file=sys.stderr)
        return 2
    for finding in findings:
        print(finding)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from gh_command import (
    Invocation,
    ParseError,
    api_endpoint,
    api_fields,
    api_method,
    api_reads_from_file,
    gh_invocations,
    is_true,
    text_mentions,
)

PULLS_ENDPOINT = re.compile(r"^/?repos/[^/]+/[^/]+/pulls/?$")

GH_SPELLING = re.compile(r"g[\\'\"\n]*h")

DENY_REASON = (
    "Review-first PR workflow required. Use 'gh pr create --draft ...' first, then "
    "'/review-pr <url>' against the draft, address findings (force-push if needed), "
    "then 'gh pr ready <number>' to mark merge-ready."
)


def deny(reason: str) -> None:
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)


UNPARSED_REASON = (
    "This command mentions 'gh pr create' in a form the gate cannot parse (a wrapper, group, "
    "substitution or quoted text). Run 'gh pr create --draft ...' as a plain command, and put "
    "text that mentions it in a file or heredoc."
)


def creates_non_draft_pr(inv: Invocation) -> bool:
    if inv.path == ("pr", "create"):
        return not is_true(inv.flag("draft", "d"))
    if inv.path != ("api",):
        return False
    endpoint = api_endpoint(inv)
    if endpoint == "graphql":
        if api_reads_from_file(inv):
            return True
        query = " ".join(api_fields(inv).values())
        return "createPullRequest" in query and not re.search(r"draft\s*:\s*true", query)
    if api_method(inv) != "POST" or not PULLS_ENDPOINT.match(endpoint):
        return False
    return api_reads_from_file(inv) or not is_true(api_fields(inv).get("draft"))


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        deny(f"Could not read the hook payload ({e}); failing closed.")
    cmd = (payload.get("tool_input") or {}).get("command") or ""
    if not GH_SPELLING.search(cmd):
        return
    try:
        invocations = gh_invocations(cmd)
    except ParseError as e:
        deny(f"Could not parse this command, so the draft-first check cannot run ({e}). Simplify the command and retry.")
    if any(creates_non_draft_pr(inv) for inv in invocations):
        deny(DENY_REASON)
    if text_mentions(cmd, "create|new") > sum(inv.path == ("pr", "create") for inv in invocations):
        deny(UNPARSED_REASON)


if __name__ == "__main__":
    main()

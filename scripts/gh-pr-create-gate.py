import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from gh_command import Invocation, ParseError, api_fields, api_method, gh_invocations, is_true

PULLS_ENDPOINT = re.compile(r"^/?repos/[^/]+/[^/]+/pulls/?$")

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


def creates_non_draft_pr(inv: Invocation) -> bool:
    if inv.path == ("pr", "create"):
        return not is_true(inv.flag("draft", "d"))
    if inv.path != ("api",) or api_method(inv) != "POST":
        return False
    if not inv.positionals or not PULLS_ENDPOINT.match(inv.positionals[0]):
        return False
    return not is_true(api_fields(inv).get("draft"))


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        deny(f"Could not read the hook payload ({e}); failing closed.")
    cmd = (payload.get("tool_input") or {}).get("command") or ""
    if not re.search(r"\bgh\b", cmd):
        return
    try:
        invocations = gh_invocations(cmd)
    except ParseError as e:
        deny(f"Could not parse this command, so the draft-first check cannot run ({e}). Simplify the command and retry.")
    if any(creates_non_draft_pr(inv) for inv in invocations):
        deny(DENY_REASON)


if __name__ == "__main__":
    main()

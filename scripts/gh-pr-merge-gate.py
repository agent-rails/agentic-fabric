import json
import os
import re
import subprocess
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
    text_mentions,
)

GH_SPELLING = re.compile(r"g[\\'\"\n]*h")
MERGE_ENDPOINT = re.compile(r"^/?repos/[^/]+/[^/]+/pulls/[^/]+/merge/?$")
VIEW_TIMEOUT_SECONDS = 8

DRAFT_REASON = (
    "Review-first PR workflow required. This PR is still a draft — mark it ready only after "
    "review: run '/review-pr <url>', address findings, then 'gh pr ready <number>' before merging."
)
UNCONFIRMED_REASON = (
    "Could not confirm the target PR is marked ready (gh pr view returned no draft state). "
    "Verify the PR has been reviewed and marked ready, then merge manually."
)
API_REASON = (
    "Merging through 'gh api' cannot be checked against the PR's draft state. Use 'gh pr merge' "
    "on a PR that has been reviewed and marked ready."
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
    "This command mentions 'gh pr merge' in a form the gate cannot parse (a wrapper, group, "
    "substitution or quoted text), so the ready-to-merge check cannot run. Run 'gh pr merge <number> "
    "--repo owner/name' as a plain command, and put text that mentions it in a file or heredoc."
)
MERGE_MUTATIONS = ("mergePullRequest", "enablePullRequestAutoMerge")


def merges_through_api(inv: Invocation) -> bool:
    if inv.path != ("api",):
        return False
    endpoint = api_endpoint(inv)
    if endpoint == "graphql":
        if api_reads_from_file(inv):
            return True
        return any(m in v for v in api_fields(inv).values() for m in MERGE_MUTATIONS)
    return MERGE_ENDPOINT.match(endpoint) is not None and api_method(inv) != "GET"


def draft_state(inv: Invocation) -> str:
    cmd = ["gh", "pr", "view"]
    if inv.positionals:
        cmd.append(inv.positionals[0])
    repo = inv.flag("R", "repo") or inv.env.get("GH_REPO")
    if isinstance(repo, str):
        cmd.extend(["--repo", repo])
    cmd.extend(["--json", "isDraft", "--jq", ".isDraft"])
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=VIEW_TIMEOUT_SECONDS)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return result.stdout.strip() if result.returncode == 0 else ""


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
        deny(f"Could not parse this command, so the ready-to-merge check cannot run ({e}). Simplify the command and retry.")
    if text_mentions(cmd, "merge") > sum(inv.path == ("pr", "merge") for inv in invocations):
        deny(UNPARSED_REASON)
    for inv in invocations:
        if merges_through_api(inv):
            deny(API_REASON)
        if inv.path != ("pr", "merge"):
            continue
        state = draft_state(inv)
        if state == "true":
            deny(DRAFT_REASON)
        if state != "false":
            deny(UNCONFIRMED_REASON)


if __name__ == "__main__":
    main()

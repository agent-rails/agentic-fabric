---
name: github-pr-review
description: GitHub PR review operations using gh CLI and gh api. Use when replying to inline comments, creating reviews, resolving threads, or managing PR conversations. Trigger phrases include "reply to comment", "pr review", "inline comment", "resolve thread", "react to comment".
---

# GitHub PR Review Operations

Use `gh` CLI and `gh api` for PR review operations. These patterns work reliably for managing PR conversations.

## Get repo owner/name

Before using `gh api` with `{owner}/{repo}`, get the correct values:

```bash
# From git remote (recommended)
git remote get-url origin | sed -E 's/.*[:/]([^/]+)\/([^.]+)(\.git)?$/\1\/\2/'

# Or use gh to get repo info
gh repo view --json nameWithOwner -q .nameWithOwner
```

Common mistake: Using wrong org name (e.g., `anomalyco` vs `your-org`) causes 404 errors.

## Get PR inline review comments

```bash
# List all inline review comments on a PR
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments | jq -r '.[] | "\(.id)|\(.path)|\(.user.login)|\(.body)"'

# Get comment IDs with file context
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments | jq -r '.[] | "---\n**\(.user.login)** on `\(.path)` (line \(.line // .original_line)):\n\(.body)\n"'
```

## Reply to inline review comments

```bash
# Reply to a specific inline comment (use in_reply_to_id)
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies \
  -X POST \
  -f body="Your reply message here"
```

Important: Use the `/replies` endpoint, not creating a new comment. The comment_id is the `id` field from the comment you're replying to.

## Create a new inline comment

Warning: The single-comment endpoint is finicky. Prefer the batch review method below.

```bash
# Single comment (often fails with validation errors)
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments \
  -X POST \
  -f body="Your comment" \
  -f commit_id="abc123" \
  -f path="path/to/file.ts" \
  -F line=42 \
  -f side="RIGHT"
```

### Recommended: Batch inline comments via reviews API

This method is more reliable. Use `position` (line in diff), not `line` (line in file).

```bash
COMMIT_ID=$(gh pr view {pr_number} --json headRefOid -q .headRefOid)

gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews -X POST --input - << EOF
{
  "commit_id": "$COMMIT_ID",
  "event": "COMMENT",
  "comments": [
    {"path": "src/file.ts", "position": 10, "body": "First comment"},
    {"path": "src/file.ts", "position": 25, "body": "Second comment"}
  ]
}
EOF
```

Understanding `position` vs `line`:
- `position`: Line number in the diff output (count from `@@` hunk header, 1-indexed)
- `line`: Line number in the file (only works with `subject_type=line` which has other requirements)

To find position: Run `gh pr diff {pr}` and count lines from the `@@` marker.

## Get PR general comments (not inline)

```bash
# These are issue-style comments, not code review comments
gh pr view {pr_number} --comments --json comments | jq -r '.comments[] | "---\n**\(.author.login)** (\(.createdAt)):\n\(.body)\n"'
```

## Add a general PR comment

```bash
gh pr comment {pr_number} --body "Your comment here"
```

## Create a PR review

```bash
# Approve
gh pr review {pr_number} --approve --body "LGTM!"

# Request changes
gh pr review {pr_number} --request-changes --body "Please fix X"

# Just comment (no approval/rejection)
gh pr review {pr_number} --comment --body "Some thoughts..."
```

## React to a comment

```bash
gh api repos/{owner}/{repo}/pulls/comments/{comment_id}/reactions \
  -X POST \
  -f content="+1"  # or: -1, laugh, confused, heart, hooray, rocket, eyes
```

## Resolve/unresolve a review thread

```bash
# Get the thread ID first
gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            comments(first: 1) {
              nodes { body }
            }
          }
        }
      }
    }
  }
' -f owner="{owner}" -f repo="{repo}" -F pr={pr_number}

# Resolve a thread
gh api graphql -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: {threadId: $threadId}) {
      thread { isResolved }
    }
  }
' -f threadId="THREAD_ID"
```

## Common patterns

### Reply to all pending review comments
```bash
# Get all comment IDs, then loop
for id in $(gh api repos/{owner}/{repo}/pulls/{pr}/comments | jq -r '.[].id'); do
  gh api repos/{owner}/{repo}/pulls/{pr}/comments/$id/replies -X POST -f body="Fixed in commit abc123"
done
```

### Check if you have pending review comments to address
```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments | jq '[.[] | select(.user.login != "YOUR_USERNAME")] | length'
```

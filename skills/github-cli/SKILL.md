---
name: github-cli
description: GitHub CLI (gh) and API operations for branches, PRs, issues, releases, workflows, and GraphQL queries. Use when creating branches, opening PRs, managing issues, viewing releases, triggering workflows, or using gh api. Trigger phrases include "create PR", "gh api", "list issues", "merge PR", "create branch", "gh command".
---

# GitHub CLI Operations

Comprehensive guide for `gh` CLI and `gh api` operations.

## Issues

### List issues
```bash
gh issue list                           # Open issues
gh issue list --state all               # All issues
gh issue list --author @me              # Your issues
gh issue list --assignee @me            # Assigned to you
gh issue list --label "bug"             # By label
gh issue list --json number,title,state # JSON output
```

### Create issue
```bash
gh issue create --title "Title" --body "Description"
gh issue create --title "Title" --body "Body" --label "bug" --assignee "@me"
```

### View/Edit issue
```bash
gh issue view 123                       # View issue
gh issue view 123 --json body,comments  # JSON with comments
gh issue edit 123 --title "New title"
gh issue close 123
gh issue reopen 123
```

## Pull Requests

### List PRs
```bash
gh pr list                              # Open PRs
gh pr list --author @me                 # Your PRs
gh pr list --state all --json number,title,state,url
```

### Create PR
```bash
gh pr create --title "Title" --body "Description"
gh pr create --title "Title" --body "$(cat <<'EOF'
## Summary
- Change 1
- Change 2
EOF
)"
gh pr create --draft                    # Draft PR
gh pr create --base main --head feature # Explicit branches
```

### View/Edit PR
```bash
gh pr view 123
gh pr view 123 --json body,comments,reviews
gh pr edit 123 --title "New title" --body "New body"
gh pr edit 123 --add-label "ready"
```

### PR Review
```bash
gh pr review 123 --approve
gh pr review 123 --approve --body "LGTM!"
gh pr review 123 --request-changes --body "Please fix X"
gh pr review 123 --comment --body "Thoughts..."
```

### PR Actions
```bash
gh pr merge 123                         # Default merge
gh pr merge 123 --squash                # Squash merge
gh pr merge 123 --rebase                # Rebase merge
gh pr merge 123 --auto                  # Auto-merge when ready
gh pr close 123
gh pr reopen 123
gh pr ready 123                         # Mark ready for review
```

### PR Comments
```bash
gh pr comment 123 --body "Comment text"
```

## Releases

### List releases
```bash
gh release list
gh release view v1.0.0
```

### Create release
```bash
gh release create v1.0.0 --title "v1.0.0" --notes "Release notes"
gh release create v1.0.0 --generate-notes  # Auto-generate from commits
gh release create v1.0.0 ./dist/*.tar.gz   # With assets
```

## Actions/Workflows

### List/View runs
```bash
gh run list                             # Recent runs
gh run list --workflow=ci.yml           # Specific workflow
gh run view 12345                       # View run details
gh run view 12345 --log                 # View logs
```

### Trigger workflow
```bash
gh workflow run ci.yml
gh workflow run ci.yml --ref feature-branch
gh workflow run ci.yml -f input1=value1
```

### Re-run failed
```bash
gh run rerun 12345
gh run rerun 12345 --failed              # Only failed jobs
```

## gh api - Direct API Access

### GET requests
```bash
gh api repos/{owner}/{repo}
gh api repos/{owner}/{repo}/issues
gh api repos/{owner}/{repo}/pulls/123/comments
gh api user
```

### POST requests
```bash
gh api repos/{owner}/{repo}/issues -X POST -f title="Title" -f body="Body"
gh api repos/{owner}/{repo}/issues/123/comments -X POST -f body="Comment"
```

### With JSON body
```bash
gh api repos/{owner}/{repo}/dispatches -X POST --input - <<< '{"event_type":"deploy"}'
```

### Pagination
```bash
gh api repos/{owner}/{repo}/issues --paginate | jq '.[].title'
```

### GraphQL
```bash
gh api graphql -f query='
  query($owner: String!, $repo: String!) {
    repository(owner: $owner, name: $repo) {
      issues(first: 10) {
        nodes { title number }
      }
    }
  }
' -f owner="owner" -f repo="repo"
```

## Repository

```bash
gh repo view                            # Current repo
gh repo view owner/repo
gh repo clone owner/repo
gh repo create my-repo --public
gh repo fork owner/repo
gh repo sync                            # Sync fork
```

## Authentication

```bash
gh auth status                          # Check auth
gh auth login                           # Login
gh auth token                           # Get token
```

## Current User

### Get GitHub username
```bash
gh api user --jq '.login'               # Just username
gh api user --jq '.login, .name'        # Username and display name
```

### Branch naming convention
Many repos use `{username}/{type}/{description}` pattern:
```bash
# Get GitHub username (don't assume from directory paths or git config)
gh api user --jq '.login'

# Check existing branch patterns
git branch -r | head -10

# Create branch with correct pattern
git checkout -b username/feat/add-feature
git checkout -b username/fix/resolve-bug
git checkout -b username/docs/update-readme
```
Always check existing branches to match the repo's convention before creating new ones.

## Common Patterns

### Get current repo owner/name
```bash
gh repo view --json owner,name -q '.owner.login + "/" + .name'
```

### Check if PR is mergeable
```bash
gh pr view 123 --json mergeable -q '.mergeable'
```

### Get PR review status
```bash
gh pr view 123 --json reviewDecision -q '.reviewDecision'
```

### List PR files changed
```bash
gh pr view 123 --json files -q '.files[].path'
```

### Check CI status
```bash
gh pr checks 123
gh pr checks 123 --watch                # Wait for completion
```

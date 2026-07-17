---
description: Load GitHub issue into context and create implementation plan
argument-hint: [issue-number]
---

# Work on GitHub Issue

## Context
- Current branch: !`git branch --show-current`
- Repo: !`gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "unknown"`

Load GitHub issue #$ARGUMENTS into context and create an implementation plan.

## Instructions

When invoked with an issue number (e.g., `/x_work_issue 123`):

### 1. Fetch issue details
```bash
gh issue view <issue_number> --json title,body,labels,comments,assignees
```

### 2. Understand the issue
- Summarize what needs to be done in 2-3 bullet points
- Identify acceptance criteria (explicit or implied)
- Note any constraints or requirements from comments

### 3. Explore the codebase
- Search for files related to the issue's domain
- Identify the entry points and key files that will need changes
- Note relevant patterns, abstractions, and conventions in use

### 4. Create implementation plan
Present a concrete plan:

```
## Issue Summary
[1-2 sentence summary]

## Files to modify
- `path/to/file.ts` - [what changes needed]
- `path/to/other.ts` - [what changes needed]

## Implementation steps
1. [First concrete step]
2. [Second concrete step]
3. [...]

## Testing approach
- [How to verify the changes work]
```

### 5. Create branch (if needed)
Check if already on a feature branch. If on the default branch, offer to create one:
- Get GitHub username: `gh api user --jq '.login'`
- Format: `<username>/<type>/<short-description>` (e.g., `your-github-handle/feat/add-auth`)
- `git checkout -b <branch> && git push -u origin <branch>`

### 6. Start implementing
"Ready to start implementing? Or would you like me to explore any part of the codebase first?"

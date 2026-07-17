---
name: standup
description: Generate daily standup summaries for Slack from git commits and GitHub activity. Use when user asks for standup, daily update, status report, yesterday's work, or today's plans. Trigger phrases include "standup", "daily update", "what did I work on", "status report", "yesterday's commits".
---

## When to Use

- When user asks for a standup, daily update, or status report
- When user wants to summarize yesterday's work and today's plans
- When preparing for daily/weekly team sync meetings

## Pattern

### 1. Get User Identity & Dates

```bash
# Git user info
GIT_EMAIL=$(git config --global user.email)
GIT_NAME=$(git config --global user.name)

# GitHub username
GH_USER=$(gh api user --jq '.login')

# Current date
TODAY=$(date +%Y-%m-%d)

# Yesterday's date (cross-platform)
SINCE_DATE=$(date -d yesterday +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d)

# Monday handling: gather from Friday if today is Monday
if [ "$(date +%u)" = "1" ]; then
  SINCE_DATE=$(date -d "last friday" +%Y-%m-%d 2>/dev/null || date -v-fri +%Y-%m-%d)
fi
```

### 2. Discover Repos with Recent Activity

GitHub PRs (last 7 days):
```bash
gh search prs --author="@me" --updated=">$(date -d '7 days ago' +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d)" --json repository --limit 50 2>/dev/null | \
  jq -r '.[].repository.nameWithOwner' | sort -u
```

Known local repos (faster):
```bash
for repo in ~/Work/*/; do
  if [ -d "$repo/.git" ]; then
    count=$(git -C "$repo" log --since="$SINCE_DATE" --author="$GIT_EMAIL" --oneline 2>/dev/null | wc -l)
    if [ "$count" -gt 0 ]; then
      basename "$repo"
    fi
  fi
done
```

### 3. Gather Yesterday's Work

Local git commits:
```bash
git -C /path/to/repo log --since="$SINCE_DATE" --until="$TODAY" --author="$GIT_EMAIL" --oneline
```

Merged PRs:
```bash
gh search prs --author="@me" --merged --updated=">$SINCE_DATE" --json repository,title,number --limit 20 | \
  jq -r '.[] | "[\(.repository.nameWithOwner) #\(.number)](https://github.com/\(.repository.nameWithOwner)/pull/\(.number)): \(.title) [MERGED]"'
```

Open PRs updated yesterday (work in progress):
```bash
gh search prs --author="@me" --state=open --updated=">$SINCE_DATE" --json repository,title,number,isDraft --limit 20 | \
  jq -r '.[] | "[\(.repository.nameWithOwner) #\(.number)](https://github.com/\(.repository.nameWithOwner)/pull/\(.number)): \(.title) [UPDATED]"'
```

Code reviews (optional):
```bash
gh api graphql -f query='
  query($login: String!, $since: DateTime!) {
    user(login: $login) {
      contributionsCollection(from: $since) {
        pullRequestReviewContributions(first: 20) {
          nodes {
            pullRequest {
              number
              title
              repository { nameWithOwner }
            }
          }
        }
      }
    }
  }
' -f login="$GH_USER" -f since="${SINCE_DATE}T00:00:00Z" \
  --jq '.data.user.contributionsCollection.pullRequestReviewContributions.nodes[] | "Reviewed [\(.pullRequest.repository.nameWithOwner) #\(.pullRequest.number)](https://github.com/\(.pullRequest.repository.nameWithOwner)/pull/\(.pullRequest.number)): \(.pullRequest.title)"'
```

### 4. Gather Today's Work

Assigned issues:
```bash
gh search issues --assignee="@me" --state=open --json repository,title,number --limit 30 | \
  jq -r '.[] | "[\(.repository.nameWithOwner) #\(.number)](https://github.com/\(.repository.nameWithOwner)/issues/\(.number)): \(.title)"'
```

Open PRs:
```bash
gh search prs --author="@me" --state=open --json repository,title,number,isDraft --limit 20 | \
  jq -r '.[] | "[\(.repository.nameWithOwner) #\(.number)](https://github.com/\(.repository.nameWithOwner)/pull/\(.number)): \(.title) [\(if .isDraft then "DRAFT" else "OPEN" end)]"'
```

### 5. Format & Save Standup

Save to `/tmp/YYYY-MM-DD.md` in this format:

```markdown
*Yesterday (YYYY-MM-DD)*

*repo-name*
* Completed work item
* Merged [#XX](URL): title

*Today (YYYY-MM-DD)*

*repo-name*
* Working on [#XXX](URL): description
  * Goal: What you aim to achieve

*Blockers* (if any)
* Description of blocker
```

### 6. Provide Copy Instructions

```
Standup saved to: /tmp/YYYY-MM-DD.md

To copy for Slack:
1. Open file in VSCode
2. Press Cmd+Shift+V (macOS) or Ctrl+Shift+V (Linux/Windows) for preview
3. Select all and copy from preview pane
4. Paste into Slack
```

## Formatting Guidelines

Yesterday:
- Past tense: Completed, Fixed, Created, Merged, Reviewed
- Highlight merged PRs (completed deliverables)
- Include linked PR/issue numbers

Today:
- Include issue numbers and links
- Add Goal sub-bullet explaining objective
- Use present tense or "Working on"

Blockers (optional):
- Only include if there are actual blockers
- Be specific about what/who you're waiting on

## Troubleshooting

Date commands:
- Linux: `date -d "yesterday"`
- macOS: `date -v-1d`
- Always use fallback: `cmd 2>/dev/null || fallback`

GraphQL errors:
- Use `-f variable="value"` not string interpolation
- Use `$variable` in query, not shell variables

gh search prs fields:
- Use `isDraft` not `reviewDecision`
- Available: assignees, author, body, createdAt, id, isDraft, labels, number, repository, state, title, updatedAt, url

## When NOT to Use

- User wants detailed commit analysis (use git log directly)
- Generating reports for specific date ranges beyond yesterday
- Non-standup reporting formats
- When user specifies different output format

## Why

- Automates tedious standup preparation
- Ensures comprehensive coverage of all repos
- Produces Slack-ready formatted output
- Handles cross-platform date differences

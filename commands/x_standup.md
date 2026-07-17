---
description: Generate daily standup summaries for Slack from git commits and GitHub activity
---

# Daily Standup

Generate daily standup summaries for Slack posts tracking yesterday's work and today's plans.

## Instructions

### Workflow Overview

1. Get user identity and calculate dates
2. Discover repos with recent activity
3. Gather yesterday's work (commits, merged PRs, reviews)
4. Identify today's planned work (assigned issues, open PRs)
5. Format standup in markdown
6. Save to /tmp/YYYY-MM-DD.md
7. Open markdown preview in VSCode (Cmd+Shift+V / Ctrl+Shift+V)
8. Copy from preview and paste into Slack

**Important Notes:**
- Use cross-platform date commands with fallbacks (`2>/dev/null || fallback`)
- GraphQL queries must use variables (not string interpolation)
- Use `--merged` flag without date comparison for merged PRs
- JSON fields: use `isDraft` not `reviewDecision` for PR status
- Save files to `/tmp/` not `~/tmp/` or `~/standups/`
- Add error suppression (`2>/dev/null`) to optional commands
- **Use VSCode markdown preview** - simplest universal solution
  - Open file in VSCode, press Cmd+Shift+V (macOS) or Ctrl+Shift+V (Windows/Linux)
  - Copy from preview pane - includes formatting for Slack
  - Works on any platform with VSCode

**Quick Tip for Known Repos:**
If you know which repos to check, skip discovery and directly query them:
```bash
# Check known local repos
for repo in repo-one repo-two repo-three; do
  REPO_PATH="$HOME/repos/$repo"
  if [ -d "$REPO_PATH/.git" ]; then
    echo "=== $repo ==="
    git -C "$REPO_PATH" log --since="$SINCE_DATE" --until="$TODAY" --author="$GIT_EMAIL" --oneline
  fi
done
```

### 1. Get User Identity & Dates

Get the current user's git and GitHub identity:
```bash
# Git user info
git config --global user.email
git config --global user.name

# GitHub username (from gh CLI)
gh api user --jq '.login'

# Current date
date +%Y-%m-%d

# Yesterday's date (cross-platform)
date -d yesterday +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d
```

**Monday Handling:** If today is Monday, gather work from Friday through Sunday:
```bash
# Check if today is Monday (1 = Monday)
if [ "$(date +%u)" = "1" ]; then
  # Linux: Friday's date
  date -d "last friday" +%Y-%m-%d
  # macOS: Friday's date
  date -v-fri +%Y-%m-%d
fi
```

Store these for use in subsequent commands:
- `GIT_EMAIL`: The git email address
- `GH_USER`: The GitHub username
- `TODAY`: Today's date (YYYY-MM-DD)
- `SINCE_DATE`: Yesterday (or Friday if Monday)

### 2. Discover Repos with Recent Activity

Find repos where the user has recent commits or PRs:

**Search GitHub for recent PRs (last 7 days):**
```bash
gh search prs --author="@me" --created=">$(date -d '7 days ago' +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d)" --json repository,title,number,state,createdAt --limit 50 2>/dev/null | \
  jq -r '.[].repository.nameWithOwner' | sort -u
```

**Search GitHub for recent commits:**
```bash
SINCE_DATE="$(date -d '7 days ago' +%Y-%m-%dT00:00:00Z 2>/dev/null || date -v-7d +%Y-%m-%dT00:00:00Z)" && \
gh api graphql -f query='
  query($login: String!, $since: DateTime!) {
    user(login: $login) {
      contributionsCollection(from: $since) {
        commitContributionsByRepository(maxRepositories: 20) {
          repository {
            nameWithOwner
          }
          contributions {
            totalCount
          }
        }
      }
    }
  }
' -f login="$(gh api user --jq '.login')" -f since="$SINCE_DATE" --jq '.data.user.contributionsCollection.commitContributionsByRepository[].repository.nameWithOwner'
```

**Check local repos for recent commits (optional - scan a parent directory):**
```bash
# Scan repos in current directory's parent, or specify a path:
REPO_ROOT="${REPO_ROOT:-$(dirname $(pwd))}"
for repo in "$REPO_ROOT"/*/; do
  if [ -d "$repo/.git" ]; then
    count=$(git -C "$repo" log --since="$SINCE_DATE" --author="$(git config --global user.email)" --oneline 2>/dev/null | wc -l)
    if [ "$count" -gt 0 ]; then
      basename "$repo"
    fi
  fi
done
```

### 3. Gather Yesterday's Work

For each discovered repo, collect git commits from yesterday:

**From local repos (recommended - more reliable):**
```bash
git -C /path/to/repo log --since="$SINCE_DATE" --until="$TODAY" --author="$(git config --global user.email)" --oneline
```

**From GitHub API (alternative if repo not cloned locally):**
```bash
# Replace OWNER/REPO with actual repo
gh api "repos/OWNER/REPO/commits?author=$(gh api user --jq '.login')&since=${SINCE_DATE}T00:00:00Z&until=${TODAY}T00:00:00Z" \
  --jq '.[].commit.message' | head -20
```

**Check recent PRs across all repos:**
```bash
gh search prs --author="@me" --updated=">$SINCE_DATE" --json repository,title,number,state --limit 20 | \
  jq -r '.[] | "[\(.repository.nameWithOwner) #\(.number)](https://github.com/\(.repository.nameWithOwner)/pull/\(.number)): \(.title) [\(.state)]"'
```

**PRs merged yesterday (key accomplishments):**
```bash
gh search prs --author="@me" --merged --updated=">$SINCE_DATE" --json repository,title,number --limit 20 | \
  jq -r '.[] | "[\(.repository.nameWithOwner) #\(.number)](https://github.com/\(.repository.nameWithOwner)/pull/\(.number)): \(.title) [MERGED]"'
```

**Code reviews completed (optional - shows contributions to others' work):**
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
' -f login="$(gh api user --jq '.login')" -f since="${SINCE_DATE}T00:00:00Z" \
  --jq '.data.user.contributionsCollection.pullRequestReviewContributions.nodes[] | "[\(.pullRequest.repository.nameWithOwner) #\(.pullRequest.number)](https://github.com/\(.pullRequest.repository.nameWithOwner)/pull/\(.pullRequest.number)): \(.pullRequest.title)"'
```

### 4. Gather Today's Work

**Find assigned issues across GitHub:**
```bash
gh search issues --assignee="@me" --state=open --json repository,title,number --limit 30 | \
  jq -r '.[] | "[\(.repository.nameWithOwner) #\(.number)](https://github.com/\(.repository.nameWithOwner)/issues/\(.number)): \(.title)"'
```

**Check GitHub project board for In Progress items (if using a project):**
```bash
# First, find your project ID if needed:
gh project list --owner ORGANIZATION --format json | jq '.projects[] | {number, title}'

# Then list items assigned to you:
gh project item-list PROJECT_NUMBER --owner ORGANIZATION --format json --limit 200 | \
  jq -r --arg user "$(gh api user --jq '.login')" '.items[] | select(.assignees and (.assignees[] == $user)) | select(.status == "In Progress") | if .content.repository.nameWithOwner then "[\(.content.repository.nameWithOwner) #\(.content.number)](https://github.com/\(.content.repository.nameWithOwner)/issues/\(.content.number)): \(.content.title)" else "\(.content.number): \(.content.title)" end'
```

**Check PRs awaiting review or action:**
```bash
gh search prs --author="@me" --state=open --json repository,title,number,isDraft --limit 20 | \
  jq -r '.[] | "[\(.repository.nameWithOwner) #\(.number)](https://github.com/\(.repository.nameWithOwner)/pull/\(.number)): \(.title) [\(if .isDraft then "DRAFT" else "OPEN" end)]"'
```

### 5. Format Standup

Generate standup in Slack format (for manual paste into Slack client):

```
*Yesterday (YYYY-MM-DD)*
(or *Friday-Sunday* if today is Monday)

*repo-name-1*
* [Completed work item 1]
* [Completed work item 2]
* Merged [#XX](https://github.com/owner/repo/pull/XX): [title]

*repo-name-2*
* [Completed work item 1]
  * [Key detail or sub-task]
* Reviewed [#YY](https://github.com/owner/repo/pull/YY): [title] (optional)

*Today (YYYY-MM-DD)*

*repo-name-1*
* Working on [#XXX](https://github.com/owner/repo/issues/XXX): [Brief description]
  * Goal: [What you aim to achieve]

*repo-name-2*
* Working on [#XXX](https://github.com/owner/repo/issues/XXX): [Brief description]
  * Goal: [What you aim to achieve]

*Blockers* (if any)
* [Description of blocker]
  * Waiting on: [person/team/dependency]
```

### 6. Open in VSCode and Copy

```bash
STANDUP_FILE="/tmp/$(date +%Y-%m-%d).md"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Standup saved to: $STANDUP_FILE"
echo ""
echo "To copy for Slack:"
echo "  1. Open $STANDUP_FILE in VSCode"
echo "  2. Press Cmd+Shift+V (macOS) or Ctrl+Shift+V (Windows/Linux) for markdown preview"
echo "  3. Select all (Cmd+A / Ctrl+A) in the preview pane"
echo "  4. Copy (Cmd+C / Ctrl+C)"
echo "  5. Paste into Slack"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

**Why This Works:**
- Standard markdown format: `* ` for bullets, `[text](URL)` for links, `*text*` for bold
- VSCode markdown preview renders as formatted HTML
- Copying from preview includes formatting metadata
- Slack accepts this formatted clipboard content
- **Enable markup mode in Slack** for best results: Preferences → Advanced → Input options → Format messages with markup

## Formatting Guidelines

**Structure:**
- Use standard markdown: `*text*` for bold, `* ` for bullets, `[text](URL)` for links
- Organize by repository (use repo name without org prefix)
- Two sections: Yesterday and Today
- Include dates in section headers

**Yesterday Section:**
- Use past tense: Completed, Fixed, Created, Merged, Reviewed
- Be specific about accomplishments
- Highlight merged PRs (these are completed deliverables)
- Include linked PR/issue numbers: `[repo #123](https://github.com/owner/repo/pull/123)`
- Use nested bullets (2 spaces + `* `) for details
- Code reviews are optional but show collaboration

**Today Section:**
- Include issue numbers (#XXX)
- Add Goal sub-bullet explaining objective
- Use present tense or "Working on"
- Link issues/PRs: `[repo #123](https://github.com/owner/repo/issues/123)`

**Blockers Section (optional):**
- Only include if there are actual blockers
- Be specific about what/who you're waiting on
- Helps team identify where to assist

**Writing Style:**
- Keep it concise and skimmable
- Use action verbs
- Include specific deliverables
- Mention deployment/approval status when relevant
- Group related work under nested bullets

## Repository Ordering

Order repositories by activity level (most commits/PRs first) or alphabetically.
Omit repositories with no updates.

## Example Output

```
*Yesterday (2025-11-10)*

*my-cli-tool*
* Completed improved error detection in sync command
* Added unit tests for config handler
* Merged [acme/my-cli-tool #42](https://github.com/acme/my-cli-tool/pull/42): Add verbose logging flag

*backend-api*
* Fixed authentication bug in user service
* Created CloudWatch dashboards for API monitoring
  * Tracks response times, critical errors, throughput
  * Deployed to AWS with visual alert thresholds
* Reviewed [acme/backend-api #198](https://github.com/acme/backend-api/pull/198): Database connection pooling

*Today (2025-11-11)*

*backend-api*
* Working on [acme/backend-api #221](https://github.com/acme/backend-api/issues/221): implement rate limiting
  * Goal: Prevent API abuse and improve stability

*my-cli-tool*
* Create PR for new export command ([acme/my-cli-tool #45](https://github.com/acme/my-cli-tool/issues/45))
  * Goal: Allow users to export data in multiple formats
```

**Monday Example (covering Friday-Sunday):**
```
*Friday-Sunday (2025-11-07 to 2025-11-09)*

*backend-api*
* Friday: Completed API endpoint refactoring
* Friday: Merged [acme/backend-api #195](https://github.com/acme/backend-api/pull/195): Add caching layer

*Today (2025-11-10)*

*backend-api*
* Working on [acme/backend-api #221](https://github.com/acme/backend-api/issues/221): implement rate limiting
  * Goal: Complete initial implementation
```

## Notes

**Private Repositories:**
GitHub search may not find all private repos. For comprehensive coverage:
- Use the local repo scanning method for repos you have cloned
- Or explicitly query specific org repos you know you work on

**Code Reviews:**
Including code reviews in standups is optional but shows collaboration. Skip if your team doesn't track this.

## Troubleshooting

**GitHub CLI Not Authenticated:**
```bash
gh auth login
gh auth status
```

**GitHub API Rate Limits:**
```bash
gh api rate_limit
```

**Project Board Access:**
```bash
gh auth refresh -s read:project
gh auth status
```

Ensure token has `read:project` scope.

**Date Command Differences:**
- Linux uses GNU date: `date -d "yesterday"`
- macOS uses BSD date: `date -v-1d`
- Always use fallback pattern: `date -d yesterday +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d`

**Common Errors:**

1. **GraphQL: Expected VAR_SIGN, actual: UNKNOWN_CHAR**
   - Cause: String interpolation in GraphQL query
   - Fix: Use `-f variableName="value"` and `$variableName` in query
   - Example: `-f since="$SINCE_DATE"` and `contributionsCollection(from: $since)`

2. **"invalid argument for --merged flag"**
   - Cause: Using `--merged=">date"` syntax
   - Fix: Use `--merged` alone with `--updated=">date"`
   - Correct: `gh search prs --author="@me" --merged --updated=">$SINCE_DATE"`

3. **"Unknown JSON field: reviewDecision"**
   - Cause: Field not available in `gh search prs` output
   - Fix: Use `isDraft` field instead
   - Available fields: assignees, author, body, createdAt, id, isDraft, labels, number, repository, state, title, updatedAt, url

4. **Empty results from GitHub search**
   - Cause: Private repos may not be indexed
   - Fix: Query local git repos directly with `git -C /path/to/repo log`


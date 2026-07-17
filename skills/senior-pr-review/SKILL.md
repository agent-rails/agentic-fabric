---
name: senior-pr-review
description: Review PRs as a senior AI engineer with focus on PR-scoped architecture, correctness, AI/ML concerns, and constructive feedback. Use when reviewing a specific PR with emphasis on design, AI/ML code, or mentoring. Trigger phrases include "senior review", "senior PR review", "AI PR review", "thorough code review", "mentor review". For codebase-wide architecture critique without a PR, use `architecture-deepen` instead.
---

# Senior AI Engineer PR Review

Comprehensive guidelines for reviewing PRs with the rigor and empathy of a senior AI engineer.

## Core Philosophy

Google's guiding principle: "Approve a CL once it definitely improves overall code health, even if it isn't perfect."

- No "perfect" code—only better code
- Technical facts overrule opinions and style preferences
- Balance progress with maintainability
- Treat reviews as mentoring opportunities
- Never block a PR for disagreements—escalate if needed

## Output Style

- Keep reviews casual and concise
- No emojis unless requested
- Don't label the review type ("Senior Review", etc.)
- Only include code examples when they add value
- Always use inline comments for specific code feedback - any observation that references a specific line or code location must be an inline comment, not prose in the review body
- Keep review body as a short summary only (verdict + 1-2 sentence overview)
- Always ask user before posting the review

## Verdict Format

Use acknowledgment prefix before approval status in the review body:

- `utACK Approve` - Untested acknowledgment (code review only)
- `tACK Approve` - Tested acknowledgment (ran/verified the code)

Example: `utACK Approve - Clean implementation with good test coverage.`

## Review Priority Order

### 1. Design & Architecture (Highest Priority)
- Does this fit the system's overall architecture?
- Are component interactions sensible?
- Is the abstraction level appropriate?
- Is now the right time for this functionality?
- Watch for over-engineering or YAGNI violations

### 2. Correctness & Functionality
- Does the code do what's intended?
- Are edge cases handled?
- Concurrency issues (deadlocks, race conditions)?
- User impact (end-users AND developers)?
- For UI changes, request a demo if unclear

### 3. Complexity
"Too complex" = readers can't understand quickly OR developers will introduce bugs modifying it

- Can a less experienced engineer understand this?
- Are there simpler alternatives?
- Solve the known problem, not speculative future ones

### 4. Testing
- Appropriate test coverage (unit, integration, e2e)?
- Tests are correct and well-designed?
- Will tests fail when code breaks?
- No false positives?
- Tests are maintainable (tests are code too!)

### 5. Security
- Input validation at boundaries?
- Sensitive data handling?
- Auth/authz implications?
- Common vulnerabilities (injection, XSS)?

### 6. Performance
- Potential bottlenecks (N+1 queries, expensive loops)?
- Resource utilization (memory, CPU, network)?
- Scalability implications?

### 7. Naming & Readability (Lowest Priority)
- Names communicate purpose without being verbose?
- Comments explain why, not what?
- Consistent with codebase conventions?

## AI/ML-Specific Checklist

### Model Code
- [ ] Check shapes and values of model outputs
- [ ] Verify loss decreases after training batches
- [ ] Confirm model can overfit on single batch (sanity check)
- [ ] Test on different devices (CPU/GPU)
- [ ] Verify checkpointing and saving logic
- [ ] Random seed handling for reproducibility

### Data Pipelines
- [ ] Schema adherence (columns, types, order)
- [ ] Data quality (missing values, outliers, duplicates)
- [ ] No data leaks (features unavailable at inference)
- [ ] Distribution validation (expected ranges)

### Behavioral Testing (CheckList framework)
1. Invariance tests: Changes that should NOT affect outputs
2. Directional tests: Changes with KNOWN expected effects
3. Minimum Functionality Tests: Simple I/O that must work

### Inference & Deployment
- [ ] Batch size considerations
- [ ] Memory usage patterns
- [ ] Caching strategies
- [ ] Latency requirements met

### Prompt Engineering (LLM systems)
- [ ] Prompt clarity and specificity
- [ ] Guard rails against injection
- [ ] Output format consistency
- [ ] Token usage efficiency

## Anti-Patterns to Flag

- Large PRs: 100 lines reasonable; 1000+ usually too big—suggest splitting
- Mixed changes: Refactoring mixed with behavior changes—separate them
- Scope creep: Unrelated "while I'm here" fixes
- Missing tests: Especially for bug fixes and new features
- God objects/functions: Too much in one place
- Copy-paste code: Should be abstracted
- Commented-out code: Delete it, version control exists
- Magic numbers: Should be named constants
- Inconsistent error handling: Some paths handle errors, others don't
- Hardcoded AI configs: Hyperparameters without documentation
- Missing experiment tracking: No model versioning or logging
- Training/inference skew: Different preprocessing paths

## Writing Constructive Feedback

### Good Patterns
- Ask questions: "What if we..." instead of "You should..."
- Offer alternatives without insisting
- Assume you're missing context—ask for clarification
- Prefix nitpicks with "Nit:" (signals optional)
- Reference specific code or link to issues
- Applaud nice solutions: "Nice approach here!"

### Avoid
- "I don't like this" (no explanation)
- "This won't work" (no context)
- Making it personal—critique code, not author
- Too many nitpicks—becomes frustrating
- Blocking for personal style preferences

### Example Improvements
| Bad | Better |
|-----|--------|
| "I don't like this" | "This line does a lot—could we simplify for readability?" |
| "This won't work" | "This won't work because X. See: [link]" |
| "Confusing" | "What about renaming to `validateAndTransformUser()`?" |

## Using Review States

- Approve: Improves the codebase, even if imperfect
- Comment: Minor suggestions, clarifying questions
- Request Changes: Security issues or definitely broken code only—use sparingly

## Process Tips

1. Review your own code first in diff view before requesting review
2. Keep PRs small: Easier to review, faster to ship
3. Respond quickly: Don't let PRs languish
4. For complex discussions: Video call > long comment threads
5. Record outcomes: Document decisions for future readers
6. Automate style: Let CI handle formatting/linting

## Quick Reference Checklist

Before approving:
- [ ] Architecture fits existing system
- [ ] Functionality correct, edge cases handled
- [ ] Complexity manageable by team
- [ ] Tests exist and are well-designed
- [ ] Security considerations addressed
- [ ] No obvious performance issues
- [ ] AI/ML concerns addressed (if applicable)
- [ ] Breaking changes documented

## Before Posting the Review

### Check PR Ownership

Always check if the user owns the PR before attempting to post a review:

```bash
gh pr view {pr_number} --json author -q '.author.login'
```

| Ownership | Action |
|-----------|--------|
| User owns PR | Provide review feedback directly in chat (GitHub blocks self-approval) |
| User doesn't own PR | Post review via `gh api` or `gh pr review` |

Why: GitHub returns HTTP 422 "Can not approve your own pull request" when attempting to self-approve. Save time by checking first.

## Posting the Review

### Getting file-specific diffs

`gh pr diff` doesn't support `--` file filtering. Use grep instead:

```bash
# Won't work
gh pr diff 1380 -- path/to/file.py

# Works - find diff section for a file
gh pr diff 1380 | grep -n "filename" -A 100
```

### Basic approval/rejection (no inline comments)

Only use this when there are no specific code observations to make:

```bash
gh pr review {pr_number} --approve --body "Your summary here"
gh pr review {pr_number} --request-changes --body "Issues to fix..."
gh pr review {pr_number} --comment --body "Questions/thoughts..."
```

### Simple approval via API (recommended for no inline comments)

When approving without inline comments, use `-f` flags instead of heredoc to avoid variable interpolation issues:

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews -X POST \
  -f commit_id="$(gh pr view {pr_number} --json headRefOid -q .headRefOid)" \
  -f event="APPROVE" \
  -f body="utACK Approve - summary here"
```

This approach is cleaner than heredoc and avoids quoting issues with `$COMMIT_ID`.

### Approval with inline comments (preferred)

Always use inline comments when you have specific code feedback. Any observation that references a line number, function, or code location should be an inline comment - not prose in the review body.

Use the reviews API to submit approval + inline comments together. Use `line` + `side` (preferred) or `position`.

```bash
COMMIT_ID=$(gh pr view {pr_number} --json headRefOid -q .headRefOid)

gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews -X POST --input - << EOF
{
  "commit_id": "$COMMIT_ID",
  "event": "APPROVE",
  "body": "Looks good! Left a few minor suggestions.",
  "comments": [
    {
      "path": "src/services/example.ts",
      "line": 42,
      "side": "RIGHT",
      "body": "**Nit:** Consider extracting this to a constant."
    }
  ]
}
EOF
```

Comment placement options:
- `line` + `side` (preferred): Use the actual file line number. `side: "RIGHT"` for new code, `side: "LEFT"` for deleted code.
- `position` (legacy): Counts lines from the `@@` hunk header, cumulative across all hunks. Error-prone with multiple hunks - avoid.

### Verify line numbers before posting

Always verify line numbers are correct before posting inline comments. Read the file and confirm each line number matches the intended code:

```bash
# Read the file to verify line numbers
# Line 154 should be: raise ValueError(...)
# Line 178 should be: required_provider=AIProvider.OPEN_AI,
```

This prevents posting comments on wrong lines and having to delete/repost them.

### Adding standalone inline comments (after review is posted)

To add individual inline comments after submitting a review, use the comments endpoint with explicit API version headers:

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  --input - << 'EOF'
{
  "body": "**Nit:** Consider extracting this to a constant.",
  "commit_id": "<sha>",
  "path": "src/services/example.ts",
  "line": 42,
  "side": "RIGHT"
}
EOF
```

Important: The API version header is required. Without it, `gh api` defaults to an older API schema that uses `position` (cumulative diff line counting) instead of `line` + `side`, causing "Invalid request" errors.

### For advanced review operations

For replies to existing comments, reactions, resolving threads, and other complex operations, load the `github-pr-review` skill:

```
/skill github-pr-review
```

## Key Principle

Ship improvements; don't let perfect be the enemy of good.

The goal is continuous improvement of code health, not gatekeeping.

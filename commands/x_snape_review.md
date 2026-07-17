---
description: Comprehensive PR review with structured feedback on validation, auth, errors, and testing
---

# PR Review Command

## Context
- Current branch: !`git branch --show-current`
- Changed files: !`git diff master...HEAD --name-only 2>/dev/null | head -20`

## Overview
Conduct a comprehensive, technology-agnostic PR review using general best practices.

## Review Process

### 1. Get into the PR context
- Ensure your local repository is synced with remote.
- Open the PR in your code host or check out the PR branch locally.

```bash
git fetch origin
git checkout <pr-branch>
```

### 2. Identify the change scope
- Use your code host’s Files changed view, or run:
```bash
git diff <base-branch>...HEAD --name-status
```

### 3. Review each file
Focus on:
- **Validation and sanitization**: validate all external inputs.
- **Transactions and consistency**: clear boundaries; avoid partial writes; idempotency where needed.
- **Authorization and access control**: least privilege; tenant/user scoping when applicable.
- **Error handling and statuses**: appropriate status mapping; actionable messages without leaking internals.
- **Null/undefined handling and invariants**: guard clauses; defensive checks.
- **Separation of concerns**: avoid mixing layers; stable interfaces between modules.
- **PII protection and logging**: no UUIDs/emails/secrets in logs; prefer opaque IDs.
- **Duplicate or dead code**: remove redundancy; simplify complex logic.
- **Performance risks**: N+1 patterns, excessive loops, unnecessary sync I/O.
- **Tests**: coverage of critical paths and edge cases; meaningful assertions.

### 4. Feedback format requirements
Structure feedback with the following elements for EACH issue found:

```markdown
# PR Review: [PR title or branch]
**Date:** [YYYY-MM-DD]
**Branch:** [full branch name]
**Reviewer:** [Your Name]

## Summary
[Brief overview of the changes and overall assessment]

## Issues Found

### Issue 1: [Issue Title]

**File:** `path/to/file.ext`

**Original Code from PR (lines X–Y):**
```lang
// The code exactly as it appears in the PR
```

**Suggested Change:**
```lang
// Your recommended improvement with concise inline comments explaining why
```

**Explanation:**
- What is the problem and why it matters
- Impact and risk level
- How the suggestion addresses it
- Alignment with standards or prior patterns

**To Post:**
[One-sentence suggestion suitable for an inline PR comment]
```

### 5. Example review items
- **Validation**: ensure all external inputs are validated and sanitized.
- **Transactions/consistency**: define transaction boundaries; avoid partial writes.
- **Access control**: verify authorization checks and proper scoping.
- **Error handling**: map errors to appropriate statuses; avoid leaking internals.
- **Observability**: log actionable context without PII/secrets.
- **Testing**: request missing tests for critical paths and edge cases.

### 6. Code review best practices
- **Evidence-based concerns**: demonstrate concrete flows or diffs; avoid hypotheticals.
- **Data-flow tracing**: follow values across functions/modules before concluding.
- **CI verification**: rely on CI for builds/tests/lints; run locally only when needed for understanding.
- **Focus on logic and maintainability**: limit style nits unless they impact readability.

### 7. Guidelines for shared/critical code
- Avoid broad changes in shared or foundational modules without strong justification.
- Prefer minimal, targeted edits that achieve the objective.
- Do not surface unrelated latent issues; stay within the PR’s scope.
- Ensure features are complete; otherwise suggest removing or feature-flagging incomplete parts.

### 8. Inline comment examples
Generic examples for clarity:

```lang
// ADD: Validate input to prevent injection
if (!isValidAttributeName(attributeName)) {
  throw new Error(`Invalid attribute name: ${attributeName}`);
}

// CHANGED: Use parameterized query instead of string concatenation
const sql = 'UPDATE ... WHERE id = ?';
db.execute(sql, [id]);
```

```lang
// ADD: Guard against null/undefined
function getUser(id) {
  if (id == null) throw new Error('id is required');
  return userRepository.findById(id);
}
```

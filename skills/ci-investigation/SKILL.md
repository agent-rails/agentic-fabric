---
name: ci-investigation
description: Investigate CI/CD failures on PRs using subagents for parallel log analysis. Use when CI fails, build breaks, tests fail in pipeline, or user asks about failing checks. Trigger phrases include "CI failed", "build failed", "pipeline error", "failing checks", "why did CI fail".
---

## When to Use

When a user asks about CI failures on a PR or branch.

## Pattern

1. Spawn an `explore` agent for failure analysis:
   ```
   "Investigate CI failures for PR #<number>. Get all failing check logs, 
   identify root causes, and summarize: failing jobs, error messages, root cause."
   ```

2. In parallel, gather PR metadata yourself (title, commits, changed files)

3. Synthesize agent findings with context to determine fix

## When NOT to Use

- Local test failures (use tester agent directly)
- Simple type errors visible in editor
- When CI is passing
- Single-job failures with obvious errors

## Why

- CI logs are verbose and require parsing multiple sources
- Agent investigates all failures in parallel
- Main context stays focused on decision-making, not log parsing

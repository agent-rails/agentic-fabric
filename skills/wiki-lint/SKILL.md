---
name: wiki-lint
description: Health-check the LLM wikis (voltage, sentinel, shared-wiki). Surfaces stale pages, orphans, contradictions, broken cross-links, and frontmatter gaps. Read-only — never auto-edits. Use when user asks for "wiki lint", "wiki health", "wiki audit", "stale wiki pages", or as a weekly cadence task. Pair with the regular triage / review cadence to keep institutional knowledge from rotting.
argument-hint: "[voltage|sentinel|shared|all] (defaults to all)"
---

Health-check the LLM wiki layers and surface drift before it compounds. This is the named version of the `[STALE]` / `[CONFLICT]` discipline already documented in each wiki's `schema.md` — promoted to an explicit operation per the nashsu/llm_wiki lint pattern.

## Input

- `/wiki-lint` — lint all three layers (`voltage`, `sentinel`, `shared-wiki`)
- `/wiki-lint voltage` — lint only `~/voltage/`
- `/wiki-lint sentinel` — lint only `~/sentinel/`
- `/wiki-lint shared` — lint only `~/.claude/shared-wiki/`

Default: all.

## What the lint checks

For each wiki in scope, run the following passes. **Read-only.** Never edits a page — surfaces findings for the user to triage.

### 1. Staleness pass

A page is `[STALE]` candidate if any of:

- Frontmatter `last_verified` is older than 90 days (compute against today).
- No frontmatter present AND `git log -1 --format=%ad -- <path>` is older than 90 days.
- Page is in `pending/` (actions.md, waiting.md, decisions.md, follow-ups.md, tech-debt.md) AND has rows where `Date Flagged` is older than 14 days with no `Resolved` status. Report the row, not the file.

### 2. Conflict pass

- Grep `[CONFLICT]` across each wiki. List every hit with file:line + the conflict line.
- Conflicts require human resolution and must not rot.

### 3. Orphan pass

A page is an orphan if no other page in the SAME wiki links to it via `[[page-name]]`. Skip:

- `index.md`, `log.md`, `log.jsonl`, `purpose.md`, `schema.md` (always reachable, never orphan candidates)
- `_template.md` files
- Pages in `pending/` (they are queues, not link targets)
- Pages in `reports/daily/` and `reports/weekly/` (they are time-series, not link targets)

Cross-wiki links do not count for orphan detection — a sentinel page linked only from voltage is still considered orphan within sentinel.

### 4. Frontmatter gap pass

For every page that is not in the skip list above:

- Missing `---` YAML frontmatter → list as `[FRONTMATTER-MISSING]`
- Missing `last_verified` field → list as `[VERIFIED-MISSING]`
- Missing `sources: []` field (or empty) → list as `[SOURCES-MISSING]`

These are retrofit-on-touch — do not block on these; surface counts only.

### 5. Cross-link integrity pass

- Grep all `[[<name>]]` references in each wiki.
- For each reference, check whether the target page exists in the same wiki.
- Broken references → list as `[BROKEN-LINK]` with file:line + target.

### 6. Purpose drift pass

- Read each wiki's `purpose.md`.
- If `purpose.md` does not exist for a wiki, list as `[PURPOSE-MISSING]`.
- If `purpose.md` exists but has not been touched in 180 days (git log), list as `[PURPOSE-STALE]` — the agent should review whether the wiki's purpose has drifted from what is written.

## Execution

1. Determine the target wikis from arguments.
2. For each target wiki, run all six passes in parallel where possible (each is read-only).
3. Aggregate findings grouped by wiki then by pass.
4. Print a summary table:

```
| Wiki | Stale | Conflicts | Orphans | Frontmatter Gaps | Broken Links | Purpose |
|------|-------|-----------|---------|------------------|--------------|---------|
| voltage  | N | N | N | N | N | OK / STALE / MISSING |
| sentinel | N | N | N | N | N | OK / STALE / MISSING |
| shared   | N | N | N | N | N | OK / STALE / MISSING |
```

5. Print full findings under each wiki section. Use `file:line` format so the user can navigate.

6. Do NOT auto-edit anything. Do NOT promote to shared-wiki. Do NOT delete orphans. Surface only.

7. At the end, suggest the highest-leverage triage actions (≤5):

   - "Resolve [CONFLICT] in X (oldest)"
   - "Close or escalate N pending items in voltage/pending/actions.md (>14d)"
   - "Decide on N orphans in sentinel/wiki/anti-patterns/ (link or delete)"
   - "Refresh last_verified on N stale repo pages"

## Cadence

Run weekly, paired with the weekly-report cadence. Add `/wiki-lint` invocation to the weekly cron if one exists; otherwise the user runs it on Friday alongside `/weekly-report`.

## Output format

```
# Wiki Lint — YYYY-MM-DD

## Summary
| Wiki | Stale | Conflicts | Orphans | Frontmatter Gaps | Broken Links | Purpose |
|------|-------|-----------|---------|------------------|--------------|---------|
...

## voltage
### Stale (N)
- `~/voltage/wiki/people/example.md` — last_verified 2026-01-15 (134 days)
- ...

### Conflicts (N)
- `~/voltage/wiki/services/example.md:42` — [CONFLICT] description here

### Orphans (N)
- ...

### Frontmatter Gaps (N)
- ...

### Broken Links (N)
- ...

### Purpose: OK | STALE | MISSING

## sentinel
...

## shared
...

## Suggested triage (top 5 by leverage)
1. ...
```

## Non-goals

- This skill does NOT auto-fix anything.
- This skill does NOT cross-promote between layers.
- This skill does NOT enforce frontmatter on pages (scribes do that on touch).
- This skill does NOT consult `~/.claude/projects/.../memory/` (auto-memory is not a wiki) — use the `memory-lint` skill for that (its sibling; the two do not overlap).

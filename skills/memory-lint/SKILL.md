---
name: memory-lint
description: Health-check the auto-memory dir (MEMORY.md + topic files). Surfaces bloat, low-confidence/expired prune candidates, project->global promote candidates, mis-scoped globals, stale facts, and duplicates. Read-only — never auto-edits. Use when user asks for "memory lint", "memory audit", "memory health", "prune memory", "is MEMORY.md too big", or as a weekly/monthly cadence task. Sibling of wiki-lint (which covers the wikis, NOT auto-memory).
argument-hint: "(no args — lints the auto-memory dir)"
---

Health-check the auto-memory dir and surface drift/bloat before it forces a panic compaction. Operationalizes the [[memory-lifecycle]] discipline (confidence / scope / evidence / TTL / promote — adopted from ECC's instinct model, human-gated). Auto-memory analog of `wiki-lint`; the two do not overlap.

## Target

`~/.claude/projects/-Users-youruser/memory/` — `MEMORY.md` (the always-loaded index) + the `*.md` topic files. Nothing else.

## What the lint checks

Run all passes. **Read-only.** Never edits or deletes — surfaces findings for the user to triage.

### 1. Bloat pass (highest leverage)
- `MEMORY.md` byte size vs the **24.4KB harness load limit**. Flag `[BLOAT]` if > 17KB (content beyond ~24.4KB is silently dropped at load — surface the actual risk).
- List the 10 longest `MEMORY.md` index lines (candidates to compress to a one-line hook + push detail into the topic file).
- Flag any index line whose detail clearly duplicates its topic file (the line should be a hook, not a copy).

### 2. Confidence / TTL prune pass
- Topic files with `confidence < 0.6` AND `review` date in the past → `[PRUNE]` candidate (confirm-or-delete).
- `confidence < 0.6` with no `review` date → `[TTL-MISSING]` (set a review date).
- Files missing lifecycle frontmatter (`scope`/`confidence`) → `[LIFECYCLE-MISSING]`, count only (retrofit-on-touch, don't block).

### 3. Scope / promote pass
- `project:<repo>` facts referenced by — or clearly relevant to — a 2nd repo → `[PROMOTE]` candidate (raise to `scope: global`, bump confidence). This is the ECC promote-on-2-projects rule; pairs with workflow-miner.
- `scope: global` (or unscoped) entries that are actually about one repo → `[SCOPE-FIX]` candidate (re-scope `project:<repo>` to keep the index lean).

### 4. Staleness pass (verify-before-recommend)
- Project memories naming a specific file / flag / PR / branch: spot-check the highest-confidence load-bearing ones — if the named artifact no longer exists (git/gh/k8s), flag `[STALE]`. Do NOT exhaustively verify all; sample the load-bearing claims per the primary-source rule.
- Memories with an explicit "DONE/MERGED/RELEASED" terminal state that are no longer actionable → `[ARCHIVE]` candidate (collapse to a one-line hook or drop).

### 5. Duplication pass
- Entries whose `description`/topic overlap materially → `[MERGE]` candidate. List the pair + which is canonical.

## Execution

1. Read `MEMORY.md` + stat all topic files (sizes, frontmatter).
2. Run the five passes (read-only).
3. Print a summary table:

```
| Pass | Count | Worst offender |
|------|-------|----------------|
| Bloat        | MEMORY.md NkB (limit 24.4) | <longest line> |
| Prune        | N | <file> |
| Promote      | N | <file> |
| Scope-fix    | N | <file> |
| Stale        | N | <file> |
| Merge        | N | <pair> |
```

4. Print full findings per pass with `file` / `MEMORY.md:line` so the user can navigate.
5. Do NOT auto-edit, delete, or promote. Surface only.
6. End with the top-5 highest-leverage triage actions (lead with bloat if MEMORY.md is near the limit).

## Cadence

Run monthly, paired with `tool-pruning-loop`; or on-demand when MEMORY.md approaches the load limit. Cheap, read-only.

## Non-goals

- Does NOT auto-fix, prune, or promote — surfaces for human gate (we keep promotion human-gated; we did NOT adopt ECC's auto-capture/auto-evolve).
- Does NOT touch the wikis — that is `wiki-lint`.
- Does NOT add an observer/background-capture loop — our failure mode is over-capture, not under-capture.

# ADR-0003 — Git-backed markdown wikis as persistent agent memory

Status: Accepted · Applies principle: [Wikis as persistent memory](../DESIGN-PRINCIPLES.md#3-wikis-as-persistent-memory)

## Context

Agent sessions are stateless. Without memory, every triage cold-reads every thread and every PR review re-derives repo conventions and author history from scratch. The value of a chief-of-staff or a reviewer is almost entirely in the accumulated context — who owes whom, what this repo's rollback story is, which author keeps shipping the same anti-pattern. That context has to persist across sessions and be cheap to read at the start of each one.

The storage question: where does durable agent memory live?

## Options

1. **No persistent memory.** Re-derive everything each session. Simple, but throws away the compounding value that is the entire point.
2. **A database / vector store.** Structured, queryable, scales to large corpora. But it's opaque to the human, needs infrastructure, hides its state behind a query layer, and makes "what does the agent believe about this person?" a query instead of a file you can open.
3. **Git-backed markdown wikis (chosen).** Human-readable, diff-able, versioned, greppable, zero infra. The agent reads pages before acting and writes them back after; git is the audit trail.

## Decision

Option 3. Two tiers:

- **Agent wikis** (`~/voltage/`, `~/sentinel/`) — domain memory. Voltage: people, channels, pending items, reports. Sentinel: repos, authors, patterns, review log. Structured by a `schema.md`, seeded from templates in this repo (`wikis/*/`). Only the machinery ships; the *data* fills itself through use and is excluded from the repo.
- **shared-wiki** (`~/.claude/shared-wiki/`) — the cross-cutting fact layer every agent reads on every invocation: user identity, people, repos, projects, and the principle pages. Kept to ~3-9 pages.

Memory writes are done by cheap sonnet scribes, not the opus lead — the lead keeps the judgment, the scribe does the mechanical write-back. This only works *because* the wiki carries the context the cheap model would otherwise lack.

## Consequences

- Compounding context: triage opens with relationship history, review opens with repo/author patterns. The stated bar — voltage must answer "who is this person and what do we owe each other?" in <30s from the wiki — is only meetable with persistent memory.
- Human-inspectable by default. State is files you can open, diff, and correct. No query layer between you and what the agent believes.
- **Memory rots — this is the main cost.** Entity pages drift into "the way things were when last edited"; pending items go stale within ~14 days. Mitigations are load-bearing, not optional: the auto-stale rule, the `/wiki-lint` and `/memory-lint` skills, and the promotion/demotion discipline for shared-wiki.
- **shared-wiki bloat is the failure mode.** The relief valve is a hard rule: scribes never write to shared-wiki; promotion is an explicit human decision. Every historical relaxation of that gate grew shared-wiki faster than it improved output. Demotion moves single-agent facts back down.
- The gate pages (review rubric, shared-wiki) are protected from agent self-editing by a hook — see [ADR-0004](0004-hooks-over-prompts.md). An agent graded by a rubric must not be able to weaken the rubric.

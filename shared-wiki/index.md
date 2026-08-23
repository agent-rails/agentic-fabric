# Shared Wiki — Index

Cross-cutting fact layer read by every agent. See `purpose.md` for why
this layer exists and the promotion/demotion gate. This file is the
**how** — page map + per-task reading list.

## Pages

| Page | Read when |
|---|---|
| [purpose.md](purpose.md) | Once per session, before anything else here |
| [agent-principles.md](agent-principles.md) | Any code change, review, or fix — the 5 binding principles |
| [search-discipline.md](search-discipline.md) | Any Grep/Glob before reasoning about a codebase |
| [orchestration-patterns.md](orchestration-patterns.md) | Before one agent invokes another agent |
| [engineering-pitfalls.md](engineering-pitfalls.md) | Security review, "never raises" test-writing, PyPI/package naming |

## Read order for any agent

1. `index.md` (this file)
2. `purpose.md`, once per session
3. The 2-4 pages above relevant to the current task
4. The agent's own `purpose.md` + `schema.md`
5. Agent-specific entity pages

## Size discipline

Three to nine pages is the target (see `purpose.md`'s evolving thesis).
Currently 5. New pages require explicit user promotion — no scribe or
agent writes here during task execution.

If this file and an agent wiki disagree on a cross-cutting fact,
shared-wiki wins. Flag the disagreement, don't paper over it.

Last updated: 2026-08-07.

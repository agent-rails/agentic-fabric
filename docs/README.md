# Design docs

Why this stack is shaped the way it is — the internals, the principles, and the decisions behind them. Start here, then follow the links.

- [ARCHITECTURE.md](ARCHITECTURE.md) — how the pieces fit: agent families, control/data flow, where memory lives, how a request moves through the system.
- [DESIGN-PRINCIPLES.md](DESIGN-PRINCIPLES.md) — the load-bearing whys and their tradeoffs. The rules everything else derives from.
- [decisions/](decisions/) — Architecture Decision Records. One file per load-bearing choice: the context, the options weighed, what was picked, and what it costs.

The source-of-truth for behavior is still the prompts (`agents/`, `skills/`, `rules/`) and the wiki machinery (`wikis/`, `shared-wiki/`). These docs explain that material — they don't replace it. When a doc and a prompt disagree, the prompt wins and the doc is stale; fix it.

## Reading order for a newcomer

1. Repo [README](../README.md) — what's in the box.
2. [ARCHITECTURE.md](ARCHITECTURE.md) — the map.
3. [DESIGN-PRINCIPLES.md](DESIGN-PRINCIPLES.md) — the rules of the road.
4. [shared-wiki/orchestration-patterns.md](../shared-wiki/orchestration-patterns.md) — the pattern catalog every agent is measured against.
5. [decisions/](decisions/) — dip in when you want to know *why* a specific thing is the way it is.

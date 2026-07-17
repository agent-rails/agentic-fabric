---
name: architecture-deepen
description: Surface architectural friction and propose deepening opportunities — refactors that turn shallow modules into deep ones using explicit vocabulary (module, interface, seam, adapter, depth, leverage, locality) and the deletion test. Use when user wants architecture review, refactoring opportunities, finding shallow modules, deciding seam placement, improving testability, applying the deletion test, or designing alternative interfaces. Trigger phrases include "architecture review", "find refactoring opportunities", "is this module deep enough", "where should the seam be", "shallow module", "deletion test", "design it twice", "deepen this".
---

## When to use

- Architecture review or refactoring sweeps
- PR reviews where the diff introduces new modules or moves seams
- "Should this module exist" / "where's the right seam" questions
- Pairs with `senior-pr-review` and `review-pr` as a vocabulary source

Complementary to the DDD-flavored refactoring patterns in `~/.claude/rules/general.md` (Value Objects, Domain Services, Use Cases). Those say *what kinds* of modules to create. This skill says *whether* a module should exist and *how deep* it is.

## Vocabulary

Use the terms in [LANGUAGE.md](LANGUAGE.md) exactly. Don't drift into "component", "service", "API", or "boundary".

Core terms:
- Module — interface + implementation. Scale-agnostic (function, class, package, slice).
- Interface — everything a caller must know (types, invariants, ordering, error modes, config).
- Seam — where the interface lives. Behaviour-alteration point.
- Depth — leverage at the interface. Deep = much behaviour, small interface.
- Adapter — concrete satisfier of an interface at a seam.
- Leverage — callers' gain from depth.
- Locality — maintainers' gain from depth (change, bugs, knowledge concentrate).

Key rules:
- Deletion test — delete the module mentally. Complexity vanishes → pass-through. Complexity reappears across N callers → earning its keep.
- Interface is the test surface.
- One adapter = hypothetical seam. Two adapters = real seam.

## Process

### 1. Explore

Use `Agent` with `subagent_type=Explore` to walk the codebase. Note friction:
- Bouncing between many small modules to understand one concept
- Shallow modules — interface as complex as implementation
- Pure functions extracted only for testability; real bugs live in callers (no locality)
- Tightly-coupled modules leaking across seams
- Untested or hard-to-test through current interface

Apply the deletion test to suspected shallow modules.

### 2. Present candidates

Numbered list. For each:
- Files involved
- Problem — why the current shape causes friction
- Solution — plain English
- Benefits — in terms of leverage, locality, and test improvement

Do NOT propose interfaces yet. Ask user which to explore.

### 3. Design (chosen candidate)

- Classify dependencies per [DEEPENING.md](DEEPENING.md). Category determines test strategy.
- Walk the design tree with the user — constraints, dependencies, module shape, what sits behind the seam, surviving tests.

If user wants alternative interfaces, run design-it-twice.

### Design-it-twice (parallel subagents)

Spawn 3+ `Agent` calls in parallel via the Task tool. Each gets a different constraint:
- Agent 1: minimise the interface (1-3 entry points). Maximise leverage per entry.
- Agent 2: maximise flexibility — many use cases, extension points.
- Agent 3: optimise the most common caller — make the default trivial.
- Agent 4 (optional): ports & adapters for cross-seam dependencies.

Each agent outputs:
1. Interface — types, methods, params, invariants, ordering, error modes
2. Usage example
3. What sits behind the seam
4. Dependency strategy and adapters (per [DEEPENING.md](DEEPENING.md))
5. Trade-offs — where leverage is high, where it's thin

Present sequentially. Compare by depth, locality, seam placement. Give an opinionated recommendation. Hybrids welcome.

## References

- [LANGUAGE.md](LANGUAGE.md) — full vocabulary and principles
- [DEEPENING.md](DEEPENING.md) — dependency categories and test strategy
